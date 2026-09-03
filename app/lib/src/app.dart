import 'package:flutter/material.dart';
import 'package:mp_design/mp_design.dart';

import 'screens/home.dart';
import 'store/app_store.dart';
import 'update/updater.dart';

/// True where the app can drive the Claude Code CLI as a subprocess.
///
/// On a phone there is no CLI, so the whole experience is the copy-paste loop
/// with the Claude app instead. Everything above the transport is shared.
bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

class MasterPromptApp extends StatefulWidget {
  const MasterPromptApp({super.key});

  @override
  State<MasterPromptApp> createState() => _MasterPromptAppState();
}

class _MasterPromptAppState extends State<MasterPromptApp> {
  final AppStore _store = AppStore();
  final Updater _updater = Updater();

  @override
  void initState() {
    super.initState();
    unawaitedLoad();
    // Silent on purpose. Someone opening the app to write a brief should not
    // be met by a network error; the menu grows a mark if there is anything
    // to say and stays quiet if there is not.
    _updater.checkQuietly();
  }

  void unawaitedLoad() {
    _store.load().catchError((Object _) {});
  }

  @override
  void dispose() {
    _updater.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (BuildContext context, _) {
        return MaterialApp(
          title: 'Master Prompt',
          debugShowCheckedModeBanner: false,
          themeMode: _store.settings.themeMode,
          theme: buildMpTheme(MpColors.light, dark: false),
          darkTheme: buildMpTheme(MpColors.dark, dark: true),
          builder: (BuildContext context, Widget? child) {
            final bool dark = Theme.of(context).brightness == Brightness.dark;
            return MpTheme(
              colors: dark ? MpColors.dark : MpColors.light,
              isDark: dark,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeScreen(store: _store, updater: _updater),
        );
      },
    );
  }
}
