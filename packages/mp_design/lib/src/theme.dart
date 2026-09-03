import 'package:flutter/material.dart';

import 'tokens.dart';

/// Makes the palette available below it without threading it through every
/// widget constructor.
class MpTheme extends InheritedWidget {
  const MpTheme({
    required this.colors,
    required this.isDark,
    required super.child,
    super.key,
  });

  final MpColors colors;
  final bool isDark;

  static MpTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MpTheme>();

  /// The palette for this subtree.
  ///
  /// Falls back to deriving from the ambient [Theme] brightness rather than
  /// asserting. Dialogs, bottom sheets and pushed routes are built from the
  /// [Navigator], which can sit above wherever [MpTheme] was inserted — an
  /// assertion there turns a layout detail into a crash in exactly the places
  /// that are hardest to reach in a test.
  static MpColors colorsOf(BuildContext context) {
    final MpTheme? t = maybeOf(context);
    if (t != null) return t.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? MpColors.dark
        : MpColors.light;
  }

  @override
  bool updateShouldNotify(MpTheme oldWidget) =>
      oldWidget.colors != colors || oldWidget.isDark != isDark;
}

/// Builds the Material theme from the tokens, so stock widgets inherit the
/// same typography and palette as the custom ones.
ThemeData buildMpTheme(MpColors c, {required bool dark}) {
  final TextTheme text = TextTheme(
    displaySmall: MpType.display.copyWith(color: c.ink),
    titleLarge: MpType.title.copyWith(color: c.ink),
    titleMedium: MpType.heading.copyWith(color: c.ink),
    bodyMedium: MpType.body.copyWith(color: c.ink),
    bodySmall: MpType.caption.copyWith(color: c.inkMuted),
    labelMedium: MpType.label.copyWith(color: c.inkMuted),
    labelSmall: MpType.eyebrow.copyWith(color: c.inkMuted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    fontFamily: MpType.family,
    fontFamilyFallback: const <String>['Roboto', 'Segoe UI', 'sans-serif'],
    textTheme: text,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.inkMuted,
      onSecondary: c.canvas,
      error: c.danger,
      onError: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // Structure comes from hairlines and spacing, never from drop shadows.
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: MpRadius.card,
        side: BorderSide(color: c.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: MpType.body.copyWith(color: c.inkFaint),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MpSpace.md,
        vertical: MpSpace.sm + 2,
      ),
      border: OutlineInputBorder(
        borderRadius: MpRadius.card,
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: MpRadius.card,
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: MpRadius.card,
        borderSide: BorderSide(color: c.lineStrong, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: MpType.body.copyWith(color: c.canvas),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
