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
  static const double readingWidth = 720;
}

abstract final class MpRadius {
  static const Radius sm = Radius.circular(4);
  static const Radius md = Radius.circular(8);
  static const BorderRadius card = BorderRadius.all(md);
  static const BorderRadius chip = BorderRadius.all(sm);
}

/// Type scale, in Inter.
///
/// Medium (500) is the working weight throughout — the request was
/// "minimalistic medium weight", and Inter is the neo-grotesque that actually
/// ships a real 500. Regular is reserved for long prose, where medium is too
/// heavy to read at length.
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

  /// Section numbers and eyebrow labels: `00 / RUNTIME`.
  static TextStyle get eyebrow => _base.copyWith(
    fontSize: 11,
    letterSpacing: 1.1,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get display =>
      _base.copyWith(fontSize: 28, height: 1.2, letterSpacing: -0.4);

  static TextStyle get title =>
      _base.copyWith(fontSize: 20, height: 1.25, letterSpacing: -0.2);

  static TextStyle get heading =>
      _base.copyWith(fontSize: 15, height: 1.3, letterSpacing: -0.1);

  static TextStyle get body => _base.copyWith(fontSize: 14);

  /// Long-form reading: regular weight, looser line height.
  static TextStyle get prose =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);

  static TextStyle get label =>
      _base.copyWith(fontSize: 12, height: 1.3, letterSpacing: 0.1);

  static TextStyle get caption =>
      _base.copyWith(fontSize: 11, height: 1.35, fontWeight: FontWeight.w400);

  /// Counters and durations. Tabular figures so digits do not jitter as they
  /// tick — a countdown that shifts sideways every second is maddening.
  static TextStyle get numeric => _base.copyWith(
    fontSize: 13,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  static TextStyle get mono =>
      const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5);
}
