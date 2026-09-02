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
            padding: const EdgeInsets.symmetric(
              horizontal: MpSpace.md,
              vertical: MpSpace.sm + 4,
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: MpSpace.sm),
                ],
                Text(label, style: MpType.body.copyWith(color: fg)),
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
