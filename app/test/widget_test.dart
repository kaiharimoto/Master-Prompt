import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:mp_design/mp_design.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: buildMpTheme(MpColors.light, dark: false),
  home: MpTheme(colors: MpColors.light, isDark: false, child: child),
);

void main() {
  late Directory tmp;
  late AppStore store;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mp_app_');
    store = AppStore(root: tmp);
    await store.load();
  });

  tearDown(() {
    store.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('persistence', () {
    // A plain test, not testWidgets: real file I/O cannot complete inside the
    // widget tester's fake-async zone.
    test('projects survive a reload from disk', () async {
      await store.create(title: 'Skyline bar');
      expect(store.projects, hasLength(1));

      final AppStore reopened = AppStore(root: tmp);
      await reopened.load();
      expect(reopened.projects, hasLength(1));
      expect(reopened.projects.single.title, 'Skyline bar');
      expect(reopened.projects.single.spec.taskId, 'skyline-bar');
      reopened.dispose();
    });

    test('a corrupt project file does not stop the others loading', () async {
      await store.create(title: 'Good one');
      File('${tmp.path}/broken.json').writeAsStringSync('{not json');

      final AppStore reopened = AppStore(root: tmp);
      await reopened.load();
      expect(reopened.projects, hasLength(1));
      expect(reopened.projects.single.title, 'Good one');
      reopened.dispose();
    });
  });

  group('the shell', () {
    testWidgets('with no missions, it invites you to start one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pump();

      expect(find.text('No missions yet'), findsOneWidget);
      expect(find.text('Start a mission'), findsOneWidget);
    });

    testWidgets('a mission opens on the discussion, showing the gate', (
      WidgetTester tester,
    ) async {
      // Created outside the fake-async zone so the write actually completes.
      await tester.runAsync(() => store.create(title: 'Test mission'));

      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pump();

      expect(find.text('READINESS'), findsOneWidget);
      expect(find.textContaining('cannot be compiled yet'), findsOneWidget);
      expect(find.text('Copy for Claude'), findsOneWidget);
    });

    testWidgets('the readiness gate blocks the brief until it is settled', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => store.create(title: 'Test mission'));

      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pump();

      await tester.tap(find.text('Brief'));
      await tester.pump();

      expect(find.text('The brief is not ready to compile'), findsOneWidget);
    });

    testWidgets('the wide layout shows the mission rail instead of a tab bar', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => store.create(title: 'Skyline bar'));
      // Above the 900px threshold the app switches to the desktop shell.
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pump();

      expect(find.text('MASTER PROMPT'), findsOneWidget);
      expect(find.text('New mission'), findsOneWidget);
      expect(find.text('Skyline bar'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the run view refuses to start an unfinished mission', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => store.create(title: 'Test mission'));

      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pump();

      await tester.tap(find.text('Run'));
      await tester.pump();

      expect(find.text('Nothing to run yet'), findsOneWidget);
    });
  });
}
