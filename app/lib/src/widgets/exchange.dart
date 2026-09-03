import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../handover/sender.dart';

/// The copy-out half of the round trip.
///
/// On a phone this is the whole transport: the document goes into the Claude
/// app and the reply comes back. Most of what goes through here fits in one
/// message and is one tap.
///
/// Some of it does not. The compiled brief is around twenty thousand
/// characters and the red-team pass carries the brief inside it, and a chat
/// input cuts an oversized paste off without saying so. Splitting those into
/// numbered parts made each paste correct but the process no better — the
/// brief and the red-team pass together came to eight trips through the app
/// switcher. So an oversized document leaves as a **file** instead: attached
/// to a share, or written out to be attached by hand. Only the covering
/// instruction goes in the message, and it always fits.
///
/// Copying in parts survives underneath, because it is the only route that
/// depends on nothing at all.
class MpOutbound extends StatefulWidget {
  const MpOutbound({
    required this.title,
    required this.document,
    this.note = '',
    this.fileName = 'handover.md',
    this.subtitle,
    this.trailing,
    this.limit = HandoverSplitter.defaultLimit,
    this.sender,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// The artifact. Becomes the attachment when it is too long to paste.
  final String document;

  /// The covering instruction, which goes in the message beside the file.
  final String note;

  /// What the attachment is called in the chat and on disk.
  final String fileName;

  final Widget? trailing;

  /// Characters that fit in one paste. From settings, because only the person
  /// holding the phone can find out what the real ceiling is.
  final int limit;

  /// Injected by tests; the real one talks to the platform channel.
  final HandoverSender? sender;

  @override
  State<MpOutbound> createState() => _MpOutboundState();
}

class _MpOutboundState extends State<MpOutbound> {
  late final HandoverSender _sender = widget.sender ?? HandoverSender();

  /// Which part is next, or [Handover.count] once they have all been sent.
  int _at = 0;
  bool _busy = false;

  Handover get _handover => HandoverSplitter(
    limit: widget.limit,
  ).plan(widget.document, note: widget.note, fileName: widget.fileName);

  @override
  void didUpdateWidget(MpOutbound old) {
    super.didUpdateWidget(old);
    // A regenerated brief is a different document; carrying "you are on part
    // three of four" across it would send the wrong three thousand characters.
    if (old.document != widget.document || old.note != widget.note) _at = 0;
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _send(Handover h) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _say(switch (await _sender.share(h)) {
        SendOutcome.shared =>
          'Pick Claude. The brief goes as an attachment, '
              'so nothing is cut off.',
        SendOutcome.unsupported =>
          'Sharing is not available here. Save the file instead.',
        _ => 'Could not open the share sheet. Save the file instead.',
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Handover h) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _say(switch (await _sender.save(h)) {
        SaveOutcome.toDownloads =>
          'Saved to Downloads as ${h.fileName}. Attach it in Claude.',
        SaveOutcome.toChosenFolder =>
          'Saved as ${h.fileName}. Attach it in Claude.',
        SaveOutcome.cancelled => 'Nothing saved.',
        SaveOutcome.failed => 'Could not write the file.',
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyPart(Handover h) async {
    // Cycling back to the start belongs to the stepper. On a document with one
    // part it meant every second tap of Copy copied nothing at all, silently,
    // with the label unchanged to say so.
    if (h.isSplit && _at >= h.count) {
      setState(() => _at = 0);
      return;
    }
    if (!h.isSplit) _at = 0;
    final HandoverPart part = h.parts[_at];
    await Clipboard.setData(ClipboardData(text: part.text));
    if (!mounted) return;
    setState(() => _at++);

    // No toast between parts. It sits at the bottom of the screen directly
    // over the button you need next, so on a sequence of eight it is in the
    // way seven times — and the step indicator and the button's own label
    // already say where you are. A single-part copy has neither, so it keeps
    // its confirmation.
    if (part.isOnly) {
      _say('Copied. Paste it into Claude, then bring the reply back.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Handover h = _handover;
    final int tokens = (h.whole.length / 3.6).ceil();

    return MpPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(MpSpace.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: MpType.heading.copyWith(color: c.ink),
                      ),
                      if (widget.subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: MpType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '~$tokens tokens',
                  style: MpType.numeric.copyWith(
                    color: c.inkFaint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const MpRule(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(MpSpace.md),
                child: SelectableText(
                  h.whole,
                  style: MpType.mono.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ),
          const MpRule(),
          Padding(
            padding: const EdgeInsets.all(MpSpace.sm + 2),
            child: h.isSplit ? _oversized(c, h) : _fits(h),
          ),
          if (h.isSplit)
            MpDisclosure(
              label: 'Copy it instead',
              trailingNote: '${h.count} parts',
              child: _Stepper(
                handover: h,
                at: _at,
                onCopy: () => _copyPart(h),
                onRestart: () => setState(() => _at = 0),
              ),
            ),
        ],
      ),
    );
  }

  /// The ordinary case: one message, one tap, nothing to explain.
  Widget _fits(Handover h) => Row(
    children: <Widget>[
      Expanded(
        child: MpButton(
          label: 'Copy for Claude',
          icon: Icons.content_copy,
          kind: MpButtonKind.primary,
          expand: true,
          onPressed: () => _copyPart(h),
        ),
      ),
      if (widget.trailing != null) ...<Widget>[
        const SizedBox(width: MpSpace.sm),
        widget.trailing!,
      ],
    ],
  );

  /// Too long to paste, so it leaves as a file.
  ///
  /// Saving leads and sharing is second. A share always opens a *new* chat —
  /// the receiving app decides that, and an Android share intent carries no
  /// way to name a conversation — so the one-tap route takes the choice away.
  /// A saved file can be attached to whichever chat you want.
  Widget _oversized(MpColors c, Handover h) {
    final bool share = _sender.canShare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MpButton(
                label: _busy ? 'Working…' : 'Save the file',
                icon: Icons.save_alt,
                kind: MpButtonKind.primary,
                expand: true,
                onPressed: _busy ? null : () => _save(h),
              ),
            ),
            if (share) ...<Widget>[
              const SizedBox(width: MpSpace.sm),
              MpButton(
                label: 'Send',
                icon: Icons.ios_share,
                onPressed: _busy ? null : () => _send(h),
              ),
            ],
            if (widget.trailing != null) ...<Widget>[
              const SizedBox(width: MpSpace.sm),
              widget.trailing!,
            ],
          ],
        ),
        const SizedBox(height: MpSpace.sm),
        Text(
          share
              ? 'Too long to paste, so it goes as a file. Save it and attach '
                    'it to whichever chat you want — sending it straight to '
                    'Claude always opens a new one.'
              : 'Too long to paste, so it is written out as a file for you to '
                    'attach.',
          style: MpType.caption.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}

/// The fallback that depends on nothing: one part per tap, in order.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.handover,
    required this.at,
    required this.onCopy,
    required this.onRestart,
  });

  final Handover handover;
  final int at;
  final VoidCallback onCopy;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool done = at >= handover.count;
    final HandoverPart showing = handover.parts[done ? handover.count - 1 : at];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            MpSteps(
              step: done ? handover.count : at + 1,
              total: handover.count,
            ),
            const SizedBox(width: MpSpace.md),
            Expanded(
              child: Text(
                done
                    ? 'All ${handover.count} parts sent.'
                    : 'Paste each part into the same chat; Claude replies "ok" '
                          'until the last one.',
                style: MpType.caption.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: MpSpace.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: Scrollbar(
            child: SingleChildScrollView(
              key: ValueKey<int>(showing.index),
              child: SelectableText(
                showing.text,
                style: MpType.mono.copyWith(color: c.inkFaint),
              ),
            ),
          ),
        ),
        const SizedBox(height: MpSpace.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: MpButton(
                label: done
                    ? 'Start over'
                    : 'Copy part ${at + 1} of ${handover.count}',
                icon: done ? Icons.refresh : Icons.content_copy,
                expand: true,
                onPressed: onCopy,
              ),
            ),
            if (!done && at > 0) ...<Widget>[
              const SizedBox(width: MpSpace.sm),
              MpButton(
                label: 'Restart',
                kind: MpButtonKind.quiet,
                onPressed: onRestart,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The paste-back half of the round trip.
class MpInbound extends StatefulWidget {
  const MpInbound({
    required this.onSubmit,
    this.hint = "Paste Claude's reply here",
    this.actionLabel = 'Apply reply',
    super.key,
  });

  final Future<void> Function(String text) onSubmit;
  final String hint;
  final String actionLabel;

  @override
  State<MpInbound> createState() => _MpInboundState();
}

class _MpInboundState extends State<MpInbound> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final ClipboardData? d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) {
      setState(() => _controller.text = d!.text!);
    }
  }

  Future<void> _submit() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return MpPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'REPLY',
                  style: MpType.eyebrow.copyWith(color: c.inkFaint),
                ),
              ),
              MpButton(
                label: 'Paste',
                icon: Icons.content_paste,
                kind: MpButtonKind.quiet,
                onPressed: _paste,
              ),
            ],
          ),
          const SizedBox(height: MpSpace.sm),
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 3,
            style: MpType.mono.copyWith(color: c.ink),
            decoration: InputDecoration(hintText: widget.hint),
          ),
          const SizedBox(height: MpSpace.sm),
          MpButton(
            label: _busy ? 'Working…' : widget.actionLabel,
            kind: MpButtonKind.primary,
            expand: true,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
