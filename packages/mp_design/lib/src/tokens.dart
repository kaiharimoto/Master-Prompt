import 'package:flutter/widgets.dart';

/// The palette: paper and ink, and nothing else.
///
/// Master UI (`master-ui/MASTER-UI.md` §2): two fills, and ink at 70, 45, 25,
/// 12 and 6 percent for secondary text, borders and washes. There is no third
/// colour — not for errors, not for success, not for a run that is waiting.
/// State is carried by inversion, weight, a glyph or motion instead, which is
/// why the semantic names below ([warning], [danger], [success]) all resolve
/// to ink: they survive so a call site still says what it *means*, while the
/// family's law decides what that looks like.
///
/// Dark is the exact inversion. Swap paper and ink; nothing else changes.
@immutable
class MpColors {
  const MpColors({
    required this.paper,
    required this.ink,
    required this.ink70,
    required this.ink45,
    required this.ink25,
    required this.ink12,
    required this.ink06,
    required this.overlay,
  });

  /// Every background.
  final Color paper;

  /// Text, structural rules, fills, inversion.
  final Color ink;

  /// Secondary text and labels.
  final Color ink70;

  /// Meta lines, hints, numerals, placeholders, field borders at rest. Named
  /// for its history: the kit raised it to 60% (50% in dark) for contrast.
  final Color ink45;

  /// Field borders, scrollbar thumbs.
  final Color ink25;

  /// Hairlines between rows, progress tracks.
  final Color ink12;

  /// The hover wash.
  final Color ink06;

  /// Behind dialogs and sheets: paper at 85%, never a dark scrim.
  final Color overlay;

  // -- the vocabulary the screens were written in --------------------------

  /// The page.
  Color get canvas => paper;

  /// Anything on the page. There are no cards, so it is the page.
  Color get surface => paper;

  /// A menu or a dialog. Separated by its ink frame, not by a lighter fill.
  Color get surfaceRaised => paper;

  /// The hairline.
  Color get line => ink12;

  /// The structural rule: page header, section top, frame, rail edge.
  Color get lineStrong => ink;

  Color get inkMuted => ink70;

  Color get inkFaint => ink45;

  /// What a primary action is filled with. Inversion is the only emphasis.
  Color get accent => ink;

  /// Text on [accent].
  Color get accentInk => paper;

  /// Something to look at. Ink, set off by an outlined frame or a `—`.
  Color get warning => ink;

  /// Something that failed. Ink, set off by inversion and a `✕`.
  Color get danger => ink;

  /// Something that worked. Ink, and a `✓`.
  Color get success => ink;

  static const MpColors light = MpColors(
    paper: Color(0xFFFFFFFF),
    ink: Color(0xFF000000),
    ink70: Color(0xB3000000),
    ink45: Color(0x99000000),
    ink25: Color(0x40000000),
    ink12: Color(0x1F000000),
    ink06: Color(0x0F000000),
    overlay: Color(0xD9FFFFFF),
  );

  static const MpColors dark = MpColors(
    paper: Color(0xFF000000),
    ink: Color(0xFFFFFFFF),
    ink70: Color(0xB3FFFFFF),
    ink45: Color(0x80FFFFFF),
    ink25: Color(0x40FFFFFF),
    ink12: Color(0x1FFFFFFF),
    ink06: Color(0x0FFFFFFF),
    overlay: Color(0xD9000000),
  );
}

/// The spacing scale: 4, 8, 12, 16, 24, 32, 48, 64. Nothing in between.
abstract final class MpSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Comfortable measure for long prose. Beyond this, lines get hard to track.
  static const double readingWidth = 640;

  /// For a screen that is a conversation rather than a single question.
  ///
  /// Still a measure you can read a paragraph across, but not a phone column
  /// stranded in the middle of a widescreen window with a composer, a reply
  /// and a set of notices all sharing it.
  static const double conversationWidth = 832;

  /// A line of supporting prose under a title (`max-w-md`).
  static const double proseWidth = 448;

  /// Height of the large button, the one primary action on a screen (`h-12`).
  static const double tapTarget = 48;

  /// The index rail on a desktop.
  static const double railWidth = 232;

  /// The title bar.
  static const double titleBar = 40;
}

/// Nothing is ever rounded. Kept as names so a call site that once asked for
/// a radius gets the family's answer rather than a compile error.
abstract final class MpRadius {
  static const Radius sm = Radius.zero;
  static const Radius md = Radius.zero;
  static const BorderRadius card = BorderRadius.zero;
  static const BorderRadius chip = BorderRadius.zero;
}

/// Motion: one easing, three durations (§7). Nothing bounces.
abstract final class MpMotion {
  static const Curve ease = Cubic(0.2, 0, 0, 1);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 320);
}

/// The type scale (§3): 56 / 32 / 20 / 14 / 12 / 11, in Inter with `ss01` and
/// `cv11` so it sits closer to Neue Haas, and tabular figures throughout.
///
/// Three treatments do the work colour would otherwise do: tight-tracked
/// display, micro caps for every label, and mono for every number. Weights are
/// 400, 500 and 700 only; 600 does not exist in the family.
abstract final class MpType {
  static const String family = 'Inter';
  static const String package = 'mp_design';

  /// Named first so a machine with it installed renders it, as the kit does.
  static const List<String> monoFamily = <String>[
    'Cascadia Mono',
    'Consolas',
    'JetBrains Mono',
    'Menlo',
    'monospace',
  ];

  static const List<FontFeature> _features = <FontFeature>[
    FontFeature.enable('ss01'),
    FontFeature.enable('cv11'),
    FontFeature.tabularFigures(),
  ];

  static const TextStyle _base = TextStyle(
    fontFamily: family,
    package: package,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0,
    fontFeatures: _features,
  );

  /// One sentence on an empty screen, or a one-word state (`Ready.`).
  static TextStyle get display => _base.copyWith(
    fontSize: 56,
    height: 0.92,
    letterSpacing: -1.68,
    fontWeight: FontWeight.w700,
  );

  /// The one line a screen is about (`.t-h1`).
  static TextStyle get question => _base.copyWith(
    fontSize: 32,
    height: 1.05,
    letterSpacing: -0.64,
    fontWeight: FontWeight.w500,
  );

  /// A page title. The same face as [question].
  static TextStyle get title => question;

  /// A section title, a dialog title, a rail item (`.t-h2`).
  static TextStyle get heading => _base.copyWith(
    fontSize: 20,
    height: 1.15,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w500,
  );

  /// The name on a row: a mission, a part. Between body and heading.
  static TextStyle get rowTitle =>
      _base.copyWith(fontSize: 15, height: 1.3, fontWeight: FontWeight.w500);

  static TextStyle get body => _base.copyWith(fontSize: 14, height: 1.45);

  /// Long-form reading. The family sets prose at body size.
  static TextStyle get prose => body;

  /// Rows, menus, dialog descriptions.
  static TextStyle get label => _base.copyWith(fontSize: 13, height: 1.4);

  /// A secondary line under a title (`.t-small`).
  static TextStyle get caption => _base.copyWith(fontSize: 12, height: 1.4);

  /// Micro caps (`.t-micro`): labels, kickers, tabs, badges, button text.
  /// Callers upper-case the string; a style cannot.
  static TextStyle get eyebrow => _base.copyWith(
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.88,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get micro => eyebrow;

  /// Every number: counts, durations, indexes, paths, seeds.
  static TextStyle get numeric => mono;

  /// Data, never prose.
  static TextStyle get mono => const TextStyle(
    fontFamily: 'Cascadia Mono',
    fontFamilyFallback: monoFamily,
    fontSize: 13,
    height: 1.55,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The `01` that numbers pages, sections, rows and steps — the family's
  /// signature.
  static TextStyle get numeral => mono.copyWith(fontSize: 11, height: 1.2);
}
