import 'package:flutter/widgets.dart';

/// The palette.
///
/// Near-monochrome on purpose. This is a tool for writing long, dense
/// documents; colour is reserved for the few things that genuinely need to
/// interrupt — a blocked run, a limit countdown, an unresolved requirement.
/// Everything else earns attention through spacing and weight.
@immutable
class MpColors {
  const MpColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.accentInk,
    required this.warning,
    required this.danger,
    required this.success,
  });

  /// The page.
  final Color canvas;

  /// Panels sitting on the page.
  final Color surface;

  /// Something lifted above a panel — a menu, a dialog.
  final Color surfaceRaised;

  /// Hairline rules. Structure comes from these, not from shadows.
  final Color line;
  final Color lineStrong;

  /// Primary text.
  final Color ink;

  /// Secondary text: labels, captions, metadata.
  final Color inkMuted;

  /// Tertiary: placeholders, disabled.
  final Color inkFaint;

  /// The single accent. Used sparingly enough that it always means something.
  final Color accent;
  final Color accentInk;

  final Color warning;
  final Color danger;
  final Color success;

  static const MpColors light = MpColors(
    canvas: Color(0xFFFBFBFA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    line: Color(0xFFE6E5E1),
    lineStrong: Color(0xFFCFCEC8),
    ink: Color(0xFF17181A),
    inkMuted: Color(0xFF6B6C70),
    inkFaint: Color(0xFF9B9CA0),
    accent: Color(0xFF1A1B1E),
    accentInk: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5A00),
    danger: Color(0xFF9B2C1F),
    success: Color(0xFF1F6B3C),
  );

  static const MpColors dark = MpColors(
    canvas: Color(0xFF0E0F11),
    surface: Color(0xFF16181B),
    surfaceRaised: Color(0xFF1D2024),
    line: Color(0xFF262A2F),
    lineStrong: Color(0xFF3A3F46),
    ink: Color(0xFFECEDEE),
    inkMuted: Color(0xFF9DA1A7),
    inkFaint: Color(0xFF6A6E75),
    accent: Color(0xFFECEDEE),
    accentInk: Color(0xFF0E0F11),
    warning: Color(0xFFE0A93C),
    danger: Color(0xFFE0705F),
    success: Color(0xFF5FBF8A),
  );
}

/// An 8-point spacing scale. Every gap in the app is one of these.
abstract final class MpSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Comfortable measure for long prose. Beyond this, lines get hard to track.
  /// Narrower than before: the type is larger, so fewer characters fit before a
  /// line becomes tiring to track back from.
  static const double readingWidth = 620;

  /// Minimum height of anything tappable. Comfortably above the 48dp floor,
  /// because the primary action on a screen should be hard to miss.
  static const double tapTarget = 56;
}

abstract final class MpRadius {
  static const Radius sm = Radius.circular(4);
  static const Radius md = Radius.circular(8);
  static const BorderRadius card = BorderRadius.all(md);
  static const BorderRadius chip = BorderRadius.all(sm);
}

/// Type scale, in Inter.
///
/// Sized for a phone held at arm's length rather than a desktop leaned into.
/// The first build was set at 14px body with 11px secondary text, which read as
/// a dashboard shrunk onto a handset; everything here is roughly a fifth larger
/// with weight to match, so a screen carries less and says it more plainly.
///
/// Medium (500) is the working weight and the reason Inter was chosen — it is
/// the neo-grotesque that actually ships a real 500. Regular is kept for long
/// prose, where medium is tiring to read at length.
abstract final class MpType {
  static const String family = 'Inter';
  static const String package = 'mp_design';

  static const TextStyle _base = TextStyle(
    fontFamily: family,
    package: package,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0,
  );

  /// The one line a screen is actually about. Never more than a sentence.
  static TextStyle get question => _base.copyWith(
    fontSize: 30,
    height: 1.16,
    letterSpacing: -0.7,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get display => _base.copyWith(
    fontSize: 26,
    height: 1.2,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get title => _base.copyWith(
    fontSize: 21,
    height: 1.25,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get heading => _base.copyWith(
    fontSize: 17,
    height: 1.3,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get body => _base.copyWith(fontSize: 17, height: 1.4);

  /// Long-form reading: regular weight, looser leading.
  static TextStyle get prose =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6);

  static TextStyle get label =>
      _base.copyWith(fontSize: 14, height: 1.35, letterSpacing: 0.05);

  static TextStyle get caption =>
      _base.copyWith(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400);

  /// Step indicators and section marks. Tracked, because it is set in caps.
  static TextStyle get eyebrow => _base.copyWith(
    fontSize: 12,
    letterSpacing: 1.2,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  /// Counters and durations. Tabular figures so digits do not jitter as they
  /// tick — a countdown that shifts sideways every second is maddening.
  static TextStyle get numeric => _base.copyWith(
    fontSize: 16,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  static TextStyle get mono =>
      const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5);
}
