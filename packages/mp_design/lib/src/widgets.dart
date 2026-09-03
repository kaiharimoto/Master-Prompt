import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

/// A numbered section header, echoing the typographic voice of the documents
/// this app produces: `00 / RUNTIME`.
class MpSectionHeader extends StatelessWidget {
  const MpSectionHeader({
    required this.number,
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String number;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              '$number  /',
              style: MpType.eyebrow.copyWith(color: c.inkFaint),
            ),
            const SizedBox(width: MpSpace.sm),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: MpType.eyebrow.copyWith(color: c.inkMuted),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: MpSpace.sm),
          Text(subtitle!, style: MpType.prose.copyWith(color: c.inkMuted)),
        ],
      ],
    );
  }
}

/// A hairline rule. The app's main structural device.
class MpRule extends StatelessWidget {
  const MpRule({this.strong = false, super.key});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Container(height: 1, color: strong ? c.lineStrong : c.line);
  }
}

/// A bordered panel. No shadow, no fill contrast beyond one step.
class MpPanel extends StatelessWidget {
  const MpPanel({
    required this.child,
    this.padding = const EdgeInsets.all(MpSpace.md),
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  /// When set, a 2px bar down the leading edge. Used to mark state that needs
  /// attention without resorting to a coloured background.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Widget body = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MpRadius.card,
        border: Border.all(color: c.line),
      ),
      // Without an accent there is no Row at all. A stretch Row would demand a
      // bounded height, which it never has inside a scroll view.
      child: accent == null
          ? body
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: MpRadius.md,
                      ),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
    );
  }
}

/// The app's button. One shape, three weights of emphasis.
enum MpButtonKind { primary, secondary, quiet }

class MpButton extends StatelessWidget {
  const MpButton({
    required this.label,
    this.onPressed,
    this.kind = MpButtonKind.secondary,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final MpButtonKind kind;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool enabled = onPressed != null;

    final Color fg = switch (kind) {
      MpButtonKind.primary => c.accentInk,
      _ => enabled ? c.ink : c.inkFaint,
    };
    final Color bg = switch (kind) {
      MpButtonKind.primary => enabled ? c.accent : c.lineStrong,
      MpButtonKind.secondary => c.surface,
      MpButtonKind.quiet => Colors.transparent,
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: bg,
        borderRadius: MpRadius.card,
        child: InkWell(
          onTap: onPressed,
          borderRadius: MpRadius.card,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: MpRadius.card,
              border: Border.all(
                color: kind == MpButtonKind.secondary
                    ? c.lineStrong
                    : Colors.transparent,
              ),
            ),
            constraints: const BoxConstraints(minHeight: MpSpace.tapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: MpSpace.lg,
              vertical: MpSpace.sm + 4,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: MpSpace.sm + 2),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: MpType.heading.copyWith(color: fg),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small status marker: a phase, a limit type, a parse outcome.
class MpTag extends StatelessWidget {
  const MpTag(this.text, {this.tone, super.key});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Color colour = tone ?? c.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MpSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: MpRadius.chip,
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Text(
        text.toUpperCase(),
        style: MpType.eyebrow.copyWith(color: colour),
      ),
    );
  }
}

/// A thin progress bar, used for readiness and for rubric score.
class MpMeter extends StatelessWidget {
  const MpMeter({required this.value, this.tone, super.key});

  /// 0..1
  final double value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: <Widget>[
            Container(color: c.line),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(color: tone ?? c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled row of key and value, used throughout the detail panels.
class MpField extends StatelessWidget {
  const MpField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: MpType.eyebrow.copyWith(color: c.inkFaint),
        ),
        const SizedBox(height: MpSpace.xs + 2),
        child,
      ],
    );
  }
}

/// Shown when a list is empty, instead of blank space.
class MpEmpty extends StatelessWidget {
  const MpEmpty({required this.title, this.detail, this.action, super.key});

  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: MpType.heading.copyWith(color: c.ink),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...<Widget>[
              const SizedBox(height: MpSpace.sm),
              Text(
                detail!,
                style: MpType.prose.copyWith(color: c.inkMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: MpSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A collapsed row that opens in place.
///
/// The device by which this app keeps its promise that nothing is removed, only
/// deferred. Everything the first build printed on screen is still here — it
/// waits behind one of these until asked for.
class MpDisclosure extends StatefulWidget {
  const MpDisclosure({
    required this.label,
    required this.child,
    this.initiallyOpen = false,
    this.trailingNote,
    super.key,
  });

  final String label;
  final Widget child;
  final bool initiallyOpen;

  /// A count or hint shown on the closed row, so the user can judge whether it
  /// is worth opening without opening it.
  final String? trailingNote;

  @override
  State<MpDisclosure> createState() => _MpDisclosureState();
}

class _MpDisclosureState extends State<MpDisclosure>
    with SingleTickerProviderStateMixin {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _open,
          label: widget.label,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: MpRadius.card,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MpSpace.sm + 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.label,
                      style: MpType.label.copyWith(color: c.inkMuted),
                    ),
                  ),
                  if (widget.trailingNote != null) ...<Widget>[
                    Text(
                      widget.trailingNote!,
                      style: MpType.caption.copyWith(color: c.inkFaint),
                    ),
                    const SizedBox(width: MpSpace.sm),
                  ],
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: c.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Built only when open. A cross-fade keeps both subtrees alive, which
        // means a closed disclosure still lays out its contents and still
        // announces them to a screen reader — so "hidden" would only be true
        // visually, which is not what was promised.
        AnimatedSize(
          alignment: Alignment.topCenter,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: MpSpace.sm),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A small mark that explains a term without spending a line on it.
///
/// A long-press tooltip would be undiscoverable on a phone, so this is a
/// visible, tappable target that opens a sheet on touch and shows a plain
/// tooltip where there is a pointer.
class MpInfo extends StatelessWidget {
  const MpInfo({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool pointer = MediaQuery.sizeOf(context).width >= 900;

    final Widget mark = Icon(Icons.info_outline, size: 18, color: c.inkFaint);

    if (pointer) {
      return Tooltip(
        message: body,
        textStyle: MpType.caption.copyWith(color: c.canvas),
        padding: const EdgeInsets.all(MpSpace.sm + 2),
        margin: const EdgeInsets.all(MpSpace.md),
        child: mark,
      );
    }

    return Semantics(
      button: true,
      label: 'About $title',
      child: InkResponse(
        radius: 22,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: c.surfaceRaised,
          showDragHandle: true,
          builder: (BuildContext context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MpSpace.lg,
                0,
                MpSpace.lg,
                MpSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: MpType.title.copyWith(color: c.ink)),
                  const SizedBox(height: MpSpace.sm + 4),
                  Text(body, style: MpType.prose.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(MpSpace.xs), child: mark),
      ),
    );
  }
}

/// The container a flow screen is built from: one subject, one action.
///
/// Deliberately rigid about structure. The first build let any screen grow
/// another panel, and eight of them ended up stacked on a phone; this type has
/// room for exactly one question, one supporting line, one primary action, and
/// whatever is folded away beneath.
class MpFocal extends StatelessWidget {
  const MpFocal({
    required this.question,
    this.eyebrow,
    this.supporting,
    this.info,
    this.body,
    this.primary,
    this.secondary,
    this.disclosures = const <Widget>[],
    super.key,
  });

  /// The one line the screen is about.
  final String question;

  /// Where the user is, set small and quiet above the question.
  final String? eyebrow;

  /// A single line of orientation. Never a paragraph.
  final String? supporting;

  /// An optional explanation of a term used in the question.
  final MpInfo? info;

  /// The screen's working area, if it has one — a field, a summary, a preview.
  final Widget? body;

  final Widget? primary;
  final Widget? secondary;

  /// Everything deferred, folded away at the bottom.
  final List<Widget> disclosures;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            MpSpace.lg,
            MpSpace.lg,
            MpSpace.lg,
            MpSpace.xl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 72),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: MpSpace.readingWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (eyebrow != null) ...<Widget>[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: MpType.eyebrow.copyWith(color: c.inkFaint),
                      ),
                      const SizedBox(height: MpSpace.md),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            question,
                            style: MpType.question.copyWith(color: c.ink),
                          ),
                        ),
                        if (info != null) ...<Widget>[
                          const SizedBox(width: MpSpace.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: MpSpace.xs),
                            child: info,
                          ),
                        ],
                      ],
                    ),
                    if (supporting != null) ...<Widget>[
                      const SizedBox(height: MpSpace.md),
                      Text(
                        supporting!,
                        style: MpType.prose.copyWith(color: c.inkMuted),
                      ),
                    ],
                    if (body != null) ...<Widget>[
                      const SizedBox(height: MpSpace.xl),
                      body!,
                    ],
                    const SizedBox(height: MpSpace.xl),
                    ?primary,
                    if (secondary != null) ...<Widget>[
                      const SizedBox(height: MpSpace.sm),
                      secondary!,
                    ],
                    if (disclosures.isNotEmpty) ...<Widget>[
                      const SizedBox(height: MpSpace.lg),
                      const MpRule(),
                      ...disclosures,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A quiet progress mark: how far through the stages, without listing them.
class MpSteps extends StatelessWidget {
  const MpSteps({required this.step, required this.total, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= total; i++)
          Container(
            width: i == step ? 16 : 5,
            height: 5,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i <= step ? c.ink : c.line,
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
      ],
    );
  }
}
