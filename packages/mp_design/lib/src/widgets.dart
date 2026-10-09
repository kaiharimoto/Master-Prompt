import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

/// `01`, `02` — the index that numbers pages, sections, rows and steps.
///
/// The family's signature (`master-ui/MASTER-UI.md` §3): mono, 11px, at 45%.
String mpNumeral(int n) => n.toString().padLeft(2, '0');

class MpNumeral extends StatelessWidget {
  const MpNumeral(this.n, {this.color, super.key});

  final int n;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Text(
      mpNumeral(n),
      style: MpType.numeral.copyWith(color: color ?? c.ink45),
    );
  }
}

/// A numbered section title: the numeral, then the title in `.t-h2`, over a
/// structural rule. Sections are divided by rules, never put in cards.
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.only(bottom: MpSpace.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.ink)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(number, style: MpType.numeral.copyWith(color: c.ink45)),
              const SizedBox(width: MpSpace.smd),
              Expanded(
                child: Text(
                  title,
                  style: MpType.heading.copyWith(color: c.ink),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: MpSpace.smd),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MpSpace.readingWidth),
            child: Text(subtitle!, style: MpType.body.copyWith(color: c.ink70)),
          ),
        ],
      ],
    );
  }
}

/// A rule. Hairline between rows; [strong] for the structural rule that
/// divides regions; [heavy] for the 2px rule over an action bar, and nowhere
/// else.
class MpRule extends StatelessWidget {
  const MpRule({this.strong = false, this.heavy = false, super.key});

  final bool strong;
  final bool heavy;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Container(
      height: heavy ? 2 : 1,
      color: strong || heavy ? c.ink : c.ink12,
    );
  }
}

/// A frame. Cards do not exist in the family; frames do, sparingly.
///
/// A plain panel is a hairline frame on paper. An [accent]ed one — something
/// that needs attention — is an ink frame, the family's outlined notice: the
/// colour passed is ignored, because there is no colour to pass. It used to
/// be a 2px bar down the leading edge inside an `IntrinsicHeight`, which
/// overflowed three separate screens; a border has no height to measure.
class MpPanel extends StatelessWidget {
  const MpPanel({
    required this.child,
    this.padding = const EdgeInsets.all(MpSpace.md),
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Marks the panel as a notice. Any value; only its presence counts.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: accent == null ? c.ink12 : c.ink),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The app's button. One shape, three weights of emphasis.
///
/// [primary] is an ink block that inverts on hover; [secondary] is an ink
/// frame that fills on hover; [quiet] is the ghost — no frame, 70% ink, a wash
/// on hover. Labels are micro caps, so the string is upper-cased here and the
/// sentence-case original goes to the screen reader.
///
/// A forward arrow trails (`Begin →`) and a back arrow leads (`← Back`), as
/// text glyphs; any other icon leads.
enum MpButtonKind { primary, secondary, quiet }

class MpButton extends StatefulWidget {
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
  State<MpButton> createState() => _MpButtonState();
}

class _MpButtonState extends State<MpButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool enabled = widget.onPressed != null;
    final bool hot = enabled && _hover;

    final (Color bg, Color fg, Color edge) = switch (widget.kind) {
      MpButtonKind.primary =>
        hot ? (c.paper, c.ink, c.ink) : (c.ink, c.paper, c.ink),
      MpButtonKind.secondary =>
        hot ? (c.ink, c.paper, c.ink) : (c.paper, c.ink, c.ink),
      MpButtonKind.quiet =>
        hot
            ? (c.ink06, c.ink, Colors.transparent)
            : (Colors.transparent, c.ink70, Colors.transparent),
    };

    final IconData? icon = widget.icon;
    final bool forward = icon == Icons.arrow_forward;
    final bool back = icon == Icons.arrow_back;
    final TextStyle style = MpType.eyebrow.copyWith(
      fontSize: 13,
      letterSpacing: 1.04,
      color: fg,
    );

    final Widget label = Text(
      widget.label.toUpperCase(),
      semanticsLabel: widget.label,
      style: style,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (back) ...<Widget>[
          ExcludeSemantics(child: Text('←', style: style)),
          const SizedBox(width: MpSpace.sm),
        ] else if (icon != null && !forward) ...<Widget>[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: MpSpace.sm),
        ],
        Flexible(child: label),
        if (forward) ...<Widget>[
          const SizedBox(width: MpSpace.sm),
          ExcludeSemantics(child: Text('→', style: style)),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.3,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onPressed,
            onHover: (bool v) => setState(() => _hover = v),
            onFocusChange: (bool v) => setState(() => _focus = v),
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: MpMotion.fast,
              curve: MpMotion.ease,
              constraints: const BoxConstraints(minHeight: MpSpace.tapTarget),
              padding: const EdgeInsets.symmetric(
                horizontal: MpSpace.lg,
                vertical: MpSpace.smd,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: edge),
              ),
              foregroundDecoration: _focus
                  ? BoxDecoration(border: Border.all(color: c.ink, width: 2))
                  : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// A badge: a micro-caps word in a square frame. A phase, a status, a kind.
///
/// [tone] is accepted and ignored — badges have no colours to be in. [invert]
/// is the one emphasis a badge gets.
class MpTag extends StatelessWidget {
  const MpTag(this.text, {this.tone, this.invert = false, super.key});

  final String text;
  final Color? tone;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: invert ? c.ink : Colors.transparent,
        border: Border.all(color: invert ? c.ink : c.ink25),
      ),
      child: Text(
        text.toUpperCase(),
        style: MpType.eyebrow.copyWith(color: invert ? c.paper : c.ink70),
      ),
    );
  }
}

/// A ratio: a 3px ink fill on a hairline track. Always paired with a number
/// somewhere near it. [tone] is accepted and ignored.
class MpMeter extends StatelessWidget {
  const MpMeter({required this.value, this.tone, super.key});

  /// 0..1
  final double value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return SizedBox(
      height: 3,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: c.ink12),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0, 1),
            child: ColoredBox(color: c.ink),
          ),
        ],
      ),
    );
  }
}

/// A label above a value. The label is micro caps at 70%, above, never
/// beside.
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
          style: MpType.eyebrow.copyWith(color: c.ink70),
        ),
        const SizedBox(height: MpSpace.sm),
        child,
      ],
    );
  }
}

/// An empty state: a short sentence with a full stop in `.t-display`, one
/// line under it, and at most one action. Never an icon or an illustration.
class MpEmpty extends StatelessWidget {
  const MpEmpty({required this.title, this.detail, this.action, super.key});

  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool narrow = MediaQuery.sizeOf(context).width < 480;
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? MpSpace.lg : MpSpace.xl,
          vertical: MpSpace.xxxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: MpType.display.copyWith(
                  color: c.ink,
                  fontSize: narrow ? 40 : 56,
                ),
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: MpSpace.proseWidth,
                  ),
                  child: Text(
                    detail!,
                    style: MpType.body.copyWith(color: c.ink70),
                  ),
                ),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: MpSpace.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsed row that opens in place.
///
/// The device by which this app keeps its promise that nothing is removed, only
/// deferred. Everything the first build printed on screen is still here — it
/// waits behind one of these until asked for. Set as a list row: a hairline
/// under it, a wash on hover, a `▼` that turns.
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

class _MpDisclosureState extends State<MpDisclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.ink12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _open,
            label: widget.label,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: MpSpace.smd,
                  horizontal: MpSpace.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.label,
                        style: MpType.label.copyWith(
                          color: _open ? c.ink : c.ink70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.trailingNote != null) ...<Widget>[
                      Text(
                        widget.trailingNote!,
                        style: MpType.numeral.copyWith(color: c.ink45),
                      ),
                      const SizedBox(width: MpSpace.smd),
                    ],
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: MpMotion.fast,
                      curve: MpMotion.ease,
                      child: Text(
                        '▼',
                        style: MpType.numeral.copyWith(
                          fontSize: 10,
                          color: c.ink70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Built only when open. A cross-fade keeps both subtrees alive,
          // which means a closed disclosure still lays out its contents and
          // still announces them to a screen reader — so "hidden" would only
          // be true visually, which is not what was promised.
          AnimatedSize(
            alignment: Alignment.topCenter,
            duration: MpMotion.normal,
            curve: MpMotion.ease,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MpSpace.xs,
                      MpSpace.xs,
                      MpSpace.xs,
                      MpSpace.md,
                    ),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
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

    final Widget mark = Icon(Icons.info_outline, size: 16, color: c.ink45);

    if (pointer) {
      return Tooltip(message: body, child: mark);
    }

    return Semantics(
      button: true,
      label: 'About $title',
      child: InkResponse(
        radius: 22,
        onTap: () => showModalBottomSheet<void>(
          context: context,
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
                  Text(title, style: MpType.heading.copyWith(color: c.ink)),
                  const SizedBox(height: MpSpace.smd),
                  Text(body, style: MpType.body.copyWith(color: c.ink70)),
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
///
/// Set as a Master UI page: a micro-caps kicker, the question in `.t-h1`, a
/// line of prose capped at a readable measure, then the working area — with
/// the actions in a sticky bar under a 2px rule, so the one thing to do next is
/// on screen however long the reply above it runs.
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
    this.maxWidth = MpSpace.readingWidth,
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

  /// The measure. One question wants a reading column; a conversation with a
  /// composer under it wants a little more.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < 600;
        final double gutter = narrow ? MpSpace.lg : MpSpace.xl;

        Widget column(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );

        final Widget page = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            narrow ? MpSpace.xl : MpSpace.xxl,
            gutter,
            MpSpace.xl,
          ),
          child: column(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: MpType.eyebrow.copyWith(color: c.ink45),
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
                        padding: const EdgeInsets.only(top: MpSpace.sm),
                        child: info,
                      ),
                    ],
                  ],
                ),
                if (supporting != null) ...<Widget>[
                  const SizedBox(height: MpSpace.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 512),
                      child: Text(
                        supporting!,
                        style: MpType.body.copyWith(color: c.ink70),
                      ),
                    ),
                  ),
                ],
                if (body != null) ...<Widget>[
                  const SizedBox(height: MpSpace.xl),
                  body!,
                ],
                if (disclosures.isNotEmpty) ...<Widget>[
                  const SizedBox(height: MpSpace.xl),
                  const MpRule(strong: true),
                  ...disclosures,
                ],
              ],
            ),
          ),
        );

        if (primary == null && secondary == null) return page;

        final Widget actions = narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ?primary,
                  if (primary != null && secondary != null)
                    const SizedBox(height: MpSpace.sm),
                  ?secondary,
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(child: secondary ?? const SizedBox.shrink()),
                  const SizedBox(width: MpSpace.smd),
                  Expanded(child: primary ?? const SizedBox.shrink()),
                ],
              );

        return Column(
          children: <Widget>[
            Expanded(child: page),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.paper,
                border: Border(top: BorderSide(color: c.ink, width: 2)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: gutter,
                  vertical: MpSpace.smd,
                ),
                child: column(actions),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Where in a sequence: one ink frame of numbered cells, the current one
/// inverted, the ones before it in ink and the ones after at 45%.
class MpSteps extends StatelessWidget {
  const MpSteps({required this.step, required this.total, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Semantics(
      label: 'Step $step of $total',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: c.ink)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 1; i <= total; i++)
                Container(
                  width: 24,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == step ? c.ink : c.paper,
                    border: i == 1
                        ? null
                        : Border(left: BorderSide(color: c.ink)),
                  ),
                  child: Text(
                    mpNumeral(i),
                    style: MpType.numeral.copyWith(
                      fontSize: 10,
                      color: i == step
                          ? c.paper
                          : i < step
                          ? c.ink
                          : c.ink45,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square switch: an ink frame, a square thumb, filled ink when on.
///
/// The stock switch is a stadium and nothing in its theme can square it.
class MpSwitch extends StatelessWidget {
  const MpSwitch({required this.value, this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.3,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: AnimatedContainer(
              duration: MpMotion.fast,
              curve: MpMotion.ease,
              width: 36,
              height: 18,
              decoration: BoxDecoration(
                color: value ? c.ink : c.paper,
                border: Border.all(color: c.ink),
              ),
              child: AnimatedAlign(
                duration: MpMotion.fast,
                curve: MpMotion.ease,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 12,
                    height: 12,
                    color: value ? c.paper : c.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 6px square that breathes while something runs. Never on text, never
/// larger. Still under reduced motion.
class MpLiveSquare extends StatefulWidget {
  const MpLiveSquare({this.color, this.live = true, super.key});

  final Color? color;

  /// Whether it breathes. A square that is still means "waiting".
  final bool live;

  @override
  State<MpLiveSquare> createState() => _MpLiveSquareState();
}

class _MpLiveSquareState extends State<MpLiveSquare> {
  /// Half a breath. The fade takes most of it and the square rests for the
  /// remainder.
  ///
  /// A breath driven by a repeating controller schedules a frame forever, so
  /// anything that waits for the screen to settle — every widget test with a
  /// run going — waits forever too. A timer that turns the fade around, with a
  /// rest between, looks the same and lets the frame pipeline go idle.
  static const Duration _half = Duration(milliseconds: 1200);
  static const Duration _fade = Duration(milliseconds: 1000);

  Timer? _timer;
  bool _dim = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MpLiveSquare old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.live && !still) {
      _timer ??= Timer.periodic(_half, (_) {
        if (mounted) setState(() => _dim = !_dim);
      });
    } else {
      _timer?.cancel();
      _timer = null;
      _dim = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color colour = widget.color ?? MpTheme.colorsOf(context).ink;
    return AnimatedOpacity(
      opacity: _dim ? 0.35 : 1,
      duration: _fade,
      curve: Curves.easeInOut,
      child: Container(width: 6, height: 6, color: colour),
    );
  }
}

/// The mark: an ink square carrying a paper diagram of what the app acts on.
///
/// Master Prompt acts on a prompt, so the mark is the most reduced diagram of
/// one — a caret and the line waiting after it (`master-ui/guides/MARK.md`).
/// Two elements, 45° diagonals and a bar, on the 100-unit grid with the field
/// inset 16. It inverts with the theme for free, because the square is ink and
/// the drawing paper.
class MpMark extends StatelessWidget {
  const MpMark({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: MpMarkPainter(ink: c.ink, paper: c.paper),
      ),
    );
  }
}

class MpMarkPainter extends CustomPainter {
  const MpMarkPainter({required this.ink, required this.paper});

  final Color ink;
  final Color paper;

  /// The caret: two 45° strokes meeting at a point, 16 units wide.
  static const List<Offset> caret = <Offset>[
    Offset(16, 22),
    Offset(32, 22),
    Offset(58, 48),
    Offset(32, 74),
    Offset(16, 74),
    Offset(42, 48),
  ];

  /// The line after it, sitting on the caret's baseline.
  static const Rect line = Rect.fromLTWH(60, 62, 24, 12);

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 100;
    canvas.drawRect(Offset.zero & size, Paint()..color = ink);
    final Paint p = Paint()
      ..color = paper
      ..isAntiAlias = true;
    canvas.drawPath(
      Path()..addPolygon(<Offset>[for (final Offset o in caret) o * k], true),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        line.left * k,
        line.top * k,
        line.width * k,
        line.height * k,
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(MpMarkPainter old) => old.ink != ink || old.paper != paper;
}

/// The mark and the name, as the title bar carries them.
class MpWordmark extends StatelessWidget {
  const MpWordmark({this.name = 'Master Prompt', super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const MpMark(),
        const SizedBox(width: MpSpace.sm + 2),
        Text(
          name.toUpperCase(),
          style: MpType.body.copyWith(
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.26,
            color: c.ink,
          ),
        ),
      ],
    );
  }
}

/// A notice bar, full width.
///
/// [failed] is the family's only treatment for a problem: the bar inverts —
/// an ink block, paper text, a `✕` kicker — where another app would turn
/// something red. Otherwise it is outlined, for information.
class MpNotice extends StatelessWidget {
  const MpNotice(this.message, {this.kicker, this.failed = false, super.key});

  final String message;

  /// The word above the message, in micro caps: `✕ Failed`, `Engine`.
  final String? kicker;

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Color fg = failed ? c.paper : c.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: MpSpace.md,
        vertical: MpSpace.smd,
      ),
      decoration: BoxDecoration(
        color: failed ? c.ink : c.paper,
        border: Border.all(color: c.ink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (kicker != null) ...<Widget>[
            Text(
              kicker!.toUpperCase(),
              style: MpType.eyebrow.copyWith(color: fg),
            ),
            const SizedBox(height: MpSpace.xs),
          ],
          SelectableText(
            message,
            style: MpType.label.copyWith(
              color: failed ? c.paper.withValues(alpha: 0.8) : c.ink70,
            ),
          ),
        ],
      ),
    );
  }
}
