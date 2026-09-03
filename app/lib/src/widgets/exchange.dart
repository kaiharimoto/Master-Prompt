import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

/// The copy-out half of the round trip.
///
/// On a phone this is the whole transport: the user copies this text, pastes it
/// into the Claude app, and brings the reply back. Making that two taps instead
/// of a selection drag is most of the usability of the mobile experience.
///
/// Some of what goes through here does not fit in one message — the compiled
/// brief runs to twenty thousand characters and the red-team pass carries the
/// brief inside it — and a chat app cuts an oversized paste off without saying
/// so. When that happens the panel becomes a sequence: one part per copy, in
/// order, each telling the model to wait for the rest.
class MpOutbound extends StatefulWidget {
  const MpOutbound({
    required this.title,
    required this.text,
    this.subtitle,
    this.trailing,
    this.limit = HandoverSplitter.defaultLimit,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String text;
  final Widget? trailing;

  /// Characters that fit in one paste. From settings, because only the person
  /// holding the phone can find out what the real ceiling is.
  final int limit;

  @override
  State<MpOutbound> createState() => _MpOutboundState();
}

class _MpOutboundState extends State<MpOutbound> {
  /// Which part is next, or [Handover.count] once they have all been sent.
  int _at = 0;

  Handover get _handover =>
      HandoverSplitter(limit: widget.limit).plan(widget.text);

  @override
  void didUpdateWidget(MpOutbound old) {
    super.didUpdateWidget(old);
    // A regenerated brief is a different document; carrying "you are on part
    // three of four" across it would send the wrong three thousand characters.
    if (old.text != widget.text) _at = 0;
  }

  Future<void> _copy(Handover h) async {
    if (_at >= h.count) {
      setState(() => _at = 0);
      return;
    }
    final HandoverPart part = h.parts[_at];
    await Clipboard.setData(ClipboardData(text: part.text));
    if (!mounted) return;
    setState(() => _at++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(switch (part) {
          final HandoverPart p when p.isOnly =>
            'Copied. Paste it into Claude, then bring the reply back.',
          final HandoverPart p when p.isLast =>
            'Last part copied. Paste it and Claude will answer properly.',
          final HandoverPart p =>
            'Part ${p.index} of ${p.of} copied. Paste it, wait for "ok", '
                'then come back for the next.',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Handover h = _handover;
    final bool done = _at >= h.count;
    final HandoverPart showing = h.parts[done ? h.count - 1 : _at];
    final String text = widget.text;
    final String title = widget.title;
    final String? subtitle = widget.subtitle;
    final Widget? trailing = widget.trailing;
    final int tokens = (text.length / 3.6).ceil();

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
                      Text(title, style: MpType.heading.copyWith(color: c.ink)),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: MpType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  h.isSplit
                      ? '~$tokens tokens · ${h.count} parts'
                      : '~$tokens tokens',
                  style: MpType.numeric.copyWith(
                    color: c.inkFaint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (h.isSplit) ...<Widget>[
            const MpRule(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MpSpace.md,
                vertical: MpSpace.sm + 2,
              ),
              child: Row(
                children: <Widget>[
                  MpSteps(step: done ? h.count : _at + 1, total: h.count),
                  const SizedBox(width: MpSpace.md),
                  Expanded(
                    child: Text(
                      done
                          ? 'All ${h.count} parts sent.'
                          : 'Too long for one message. Paste each part into '
                                'the same chat; Claude replies "ok" until the '
                                'last one.',
                      style: MpType.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const MpRule(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Scrollbar(
              child: SingleChildScrollView(
                // The part about to be copied, not the whole document: the
                // preview is there to show what the next tap puts on the
                // clipboard.
                key: ValueKey<int>(showing.index),
                padding: const EdgeInsets.all(MpSpace.md),
                child: SelectableText(
                  showing.text,
                  style: MpType.mono.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ),
          const MpRule(),
          Padding(
            padding: const EdgeInsets.all(MpSpace.sm + 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: MpButton(
                    label: switch ((done, h.isSplit)) {
                      (true, _) => 'Start over',
                      (false, true) => 'Copy part ${_at + 1} of ${h.count}',
                      (false, false) => 'Copy for Claude',
                    },
                    icon: done ? Icons.refresh : Icons.content_copy,
                    kind: MpButtonKind.primary,
                    expand: true,
                    onPressed: () => _copy(h),
                  ),
                ),
                if (h.isSplit && !done && _at > 0) ...<Widget>[
                  const SizedBox(width: MpSpace.sm),
                  MpButton(
                    label: 'Restart',
                    kind: MpButtonKind.quiet,
                    onPressed: () => setState(() => _at = 0),
                  ),
                ],
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: MpSpace.sm),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
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
