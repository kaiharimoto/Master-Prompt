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

/// Builds the Material theme from the tokens, so every stock widget the app
/// still uses — a dialog, a menu, a snack bar, a segmented control — obeys the
/// same laws as the custom ones: paper and ink, square, flat, no splash.
ThemeData buildMpTheme(MpColors c, {required bool dark}) {
  final TextTheme text = TextTheme(
    displaySmall: MpType.display.copyWith(color: c.ink),
    headlineMedium: MpType.question.copyWith(color: c.ink),
    titleLarge: MpType.heading.copyWith(color: c.ink),
    titleMedium: MpType.rowTitle.copyWith(color: c.ink),
    bodyLarge: MpType.body.copyWith(color: c.ink),
    bodyMedium: MpType.body.copyWith(color: c.ink),
    bodySmall: MpType.caption.copyWith(color: c.ink70),
    labelLarge: MpType.eyebrow.copyWith(color: c.ink),
    labelMedium: MpType.label.copyWith(color: c.ink70),
    labelSmall: MpType.eyebrow.copyWith(color: c.ink45),
  );

  const OutlinedBorder square = RoundedRectangleBorder();
  final BorderSide frame = BorderSide(color: c.ink);

  final ButtonStyle flat = ButtonStyle(
    shape: const WidgetStatePropertyAll<OutlinedBorder>(square),
    elevation: const WidgetStatePropertyAll<double>(0),
    shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    splashFactory: NoSplash.splashFactory,
    overlayColor: WidgetStateProperty.resolveWith(
      (Set<WidgetState> s) =>
          s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
          ? c.ink06
          : Colors.transparent,
    ),
    textStyle: WidgetStatePropertyAll<TextStyle>(MpType.eyebrow),
    foregroundColor: WidgetStateProperty.resolveWith(
      (Set<WidgetState> s) =>
          s.contains(WidgetState.disabled) ? c.ink25 : c.ink,
    ),
    animationDuration: MpMotion.fast,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.paper,
    canvasColor: c.paper,
    cardColor: c.paper,
    fontFamily: MpType.family,
    fontFamilyFallback: const <String>[
      'Neue Haas Grotesk Display Pro',
      'Helvetica Neue',
      'Helvetica',
      'Arial',
      'sans-serif',
    ],
    textTheme: text,
    primaryTextTheme: text,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: c.ink,
      onPrimary: c.paper,
      primaryContainer: c.ink,
      onPrimaryContainer: c.paper,
      secondary: c.ink,
      onSecondary: c.paper,
      secondaryContainer: c.ink,
      onSecondaryContainer: c.paper,
      tertiary: c.ink,
      onTertiary: c.paper,
      error: c.ink,
      onError: c.paper,
      surface: c.paper,
      onSurface: c.ink,
      onSurfaceVariant: c.ink70,
      surfaceContainerLowest: c.paper,
      surfaceContainerLow: c.paper,
      surfaceContainer: c.paper,
      surfaceContainerHigh: c.paper,
      surfaceContainerHighest: c.paper,
      outline: c.ink25,
      outlineVariant: c.ink12,
      shadow: Colors.transparent,
      scrim: c.overlay,
      surfaceTint: Colors.transparent,
      inverseSurface: c.ink,
      onInverseSurface: c.paper,
    ),
    // No ripples, no highlight flash. Hover is a wash; press is nothing.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: c.ink06,
    focusColor: c.ink12,
    dividerColor: c.ink12,
    dividerTheme: DividerThemeData(color: c.ink12, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: c.ink, size: 16),
    appBarTheme: AppBarTheme(
      backgroundColor: c.paper,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 48,
      iconTheme: IconThemeData(color: c.ink, size: 20),
      titleTextStyle: MpType.eyebrow.copyWith(color: c.ink),
    ),
    // There are no cards. A frame, where one is needed, is drawn by MpPanel.
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.paper,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.ink12)),
      margin: EdgeInsets.zero,
    ),
    // Text areas are boxed; the border goes to full ink on focus. No fill.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      hintStyle: MpType.body.copyWith(color: c.ink45),
      labelStyle: MpType.eyebrow.copyWith(color: c.ink70),
      helperStyle: MpType.caption.copyWith(color: c.ink45),
      errorStyle: MpType.caption.copyWith(color: c.ink),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MpSpace.smd,
        vertical: MpSpace.sm + 2,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.ink25),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.ink25),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.ink12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.ink),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.ink),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.ink, width: 2),
      ),
      suffixIconColor: c.ink45,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.ink,
      selectionColor: c.ink25,
      selectionHandleColor: c.ink,
    ),
    // A toast is an ink box: no colour for success or failure, no radius.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: MpType.label.copyWith(color: c.paper),
      actionTextColor: c.paper,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.ink),
      textStyle: MpType.caption.copyWith(color: c.paper),
      padding: const EdgeInsets.symmetric(
        horizontal: MpSpace.smd,
        vertical: MpSpace.sm,
      ),
      waitDuration: const Duration(milliseconds: 300),
      verticalOffset: 18,
    ),
    // Dialogs: an ink frame on paper, over paper at 85%.
    dialogTheme: DialogThemeData(
      backgroundColor: c.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      barrierColor: c.overlay,
      shape: RoundedRectangleBorder(side: frame),
      titleTextStyle: MpType.heading.copyWith(color: c.ink),
      contentTextStyle: MpType.label.copyWith(color: c.ink70),
      actionsPadding: const EdgeInsets.fromLTRB(
        MpSpace.lg,
        0,
        MpSpace.lg,
        MpSpace.lg,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.paper,
      modalBackgroundColor: c.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shadowColor: Colors.transparent,
      modalBarrierColor: c.overlay,
      shape: Border(top: frame),
      dragHandleColor: c.ink25,
      dragHandleSize: const Size(32, 4),
    ),
    // Menus: an ink frame, hairlines between rows, the highlighted row
    // inverted.
    popupMenuTheme: PopupMenuThemeData(
      color: c.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(side: frame),
      textStyle: MpType.label.copyWith(color: c.ink),
      menuPadding: EdgeInsets.zero,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(c.paper),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(0),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(side: frame),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: flat),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: flat.copyWith(side: WidgetStatePropertyAll<BorderSide>(frame)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: flat.copyWith(
        backgroundColor: WidgetStatePropertyAll<Color>(c.ink),
        foregroundColor: WidgetStatePropertyAll<Color>(c.paper),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: flat.copyWith(
        backgroundColor: WidgetStatePropertyAll<Color>(c.ink),
        foregroundColor: WidgetStatePropertyAll<Color>(c.paper),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll<OutlinedBorder>(square),
        splashFactory: NoSplash.splashFactory,
        foregroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.disabled) ? c.ink25 : c.ink70,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
              ? c.ink06
              : Colors.transparent,
        ),
        iconSize: const WidgetStatePropertyAll<double>(18),
      ),
    ),
    // Segmented: one ink frame, ink rules between cells, the selected cell
    // inverted. No tick: inversion already says which.
    segmentedButtonTheme: SegmentedButtonThemeData(
      selectedIcon: const SizedBox.shrink(),
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll<OutlinedBorder>(square),
        side: WidgetStatePropertyAll<BorderSide>(frame),
        splashFactory: NoSplash.splashFactory,
        textStyle: WidgetStatePropertyAll<TextStyle>(MpType.eyebrow),
        backgroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? c.ink : c.paper,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.disabled)
              ? c.ink25
              : s.contains(WidgetState.selected)
              ? c.paper
              : c.ink,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.hovered) &&
                  !s.contains(WidgetState.selected)
              ? c.ink06
              : Colors.transparent,
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(),
      side: BorderSide(color: c.ink),
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll<Color>(c.paper),
      splashRadius: 0,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStatePropertyAll<Color>(c.ink),
      splashRadius: 0,
    ),
    // The stock switch is a stadium and cannot be squared from a theme; the
    // app uses MpSwitch. This keeps any stray one in ink at least.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.paper : c.ink,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.ink : c.paper,
      ),
      trackOutlineColor: WidgetStatePropertyAll<Color>(c.ink),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.ink,
      linearTrackColor: c.ink12,
      circularTrackColor: Colors.transparent,
      linearMinHeight: 3,
      borderRadius: BorderRadius.zero,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll<double>(8),
      radius: Radius.zero,
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> s) =>
            s.contains(WidgetState.hovered) || s.contains(WidgetState.dragged)
            ? c.ink
            : c.ink25,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(),
      selectedColor: c.paper,
      selectedTileColor: c.ink,
      iconColor: c.ink70,
      textColor: c.ink,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(side: BorderSide(color: c.ink25)),
      backgroundColor: c.paper,
      selectedColor: c.ink,
      labelStyle: MpType.caption.copyWith(color: c.ink70),
      side: BorderSide(color: c.ink25),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: RoundedRectangleBorder(),
      collapsedShape: RoundedRectangleBorder(),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _FadeTransitions(),
        TargetPlatform.windows: _FadeTransitions(),
        TargetPlatform.linux: _FadeTransitions(),
        TargetPlatform.macOS: _FadeTransitions(),
        TargetPlatform.iOS: _FadeTransitions(),
      },
    ),
  );
}

/// Pages swap with a fade (§7). No slide, no zoom, no scale.
class _FadeTransitions extends PageTransitionsBuilder {
  const _FadeTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: MpMotion.ease),
    child: child,
  );
}
