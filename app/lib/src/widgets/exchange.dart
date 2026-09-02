import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_design/mp_design.dart';

/// The copy-out half of the round trip.
///
/// On a phone this is the whole transport: the user copies this text, pastes it
/// into the Claude app, and brings the reply back. Making that two taps instead
/// of a selection drag is most of the usability of the mobile experience.
class MpOutbound extends StatelessWidget {
  const MpOutbound({
    required this.title,
    required this.text,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
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
                          subtitle!,
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
                  text,
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
                    label: 'Copy for Claude',
                    icon: Icons.content_copy,
                    kind: MpButtonKind.primary,
                    expand: true,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Copied. Paste it into Claude, then bring the '
                              'reply back.',
                            ),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: MpSpace.sm),
                  trailing!,
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
