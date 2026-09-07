import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/destinations.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';

import 'widget_test.dart' show wrap;

/// The wide branch of `home.dart` had **no test coverage at all**.
///
/// `isDesktop(context)` is a 900px gate and every widget test runs at the
/// default 800×600, so every existing test — including `desktop_flow_test.dart`,
/// despite its name — exercised the phone layout. A fresh desktop install had
/// no way to reach Settings, and nothing here would have said so.
void main() {
  late AppStore store;

  setUp(() async {
    store = AppStore(inMemory: true);
    await store.load();
  });

  tearDown(() => store.dispose());

  /// A window wide enough to take the desktop branch, restored afterwards so
  /// one test cannot leak a surface size into the next.
  Future<void> desktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(HomeScreen(store: store)));
    await tester.pump();
  }

  testWidgets('the menu is there before there is a mission', (
    WidgetTester tester,
  ) async {
    await desktop(tester);

    expect(
      find.byIcon(Icons.more_horiz),
      findsOneWidget,
      reason:
          'the header was built only when a mission was selected, so a fresh '
          'install had no menu — and therefore no way to reach Settings and '
          'connect the CLI, which is the first thing a desktop user has to do',
    );
  });

  testWidgets('Settings is reachable with nothing open', (
    WidgetTester tester,
  ) async {
    await desktop(tester);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    final Finder item = find.ancestor(
      of: find.text('Settings'),
      matching: find.byType(PopupMenuItem<AppDestination>),
    );
    expect(
      tester.widget<PopupMenuItem<AppDestination>>(item).enabled,
      isTrue,
      reason:
          'Settings and Update are the two destinations that do not need a '
          'mission, and they are exactly the two a new user needs first',
    );
  });

  testWidgets('a mission-only destination stays disabled until there is one', (
    WidgetTester tester,
  ) async {
    await desktop(tester);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    final Finder item = find.ancestor(
      of: find.text('Brief'),
      matching: find.byType(PopupMenuItem<AppDestination>),
    );
    expect(
      tester.widget<PopupMenuItem<AppDestination>>(item).enabled,
      isFalse,
      reason: 'offering it would open a screen with nothing to show',
    );
  });

  testWidgets('the rail is present and the phone app bar is not', (
    WidgetTester tester,
  ) async {
    await desktop(tester);

    expect(find.text('MASTER PROMPT'), findsOneWidget);
    expect(
      find.byType(AppBar),
      findsNothing,
      reason: 'the wide layout carries its own header instead',
    );
    expect(find.text('New mission'), findsOneWidget);
  });

  testWidgets('the opening question is still the one thing on screen', (
    WidgetTester tester,
  ) async {
    await desktop(tester);

    expect(find.text('What are you building?'), findsOneWidget);
    expect(
      find.text('READINESS'),
      findsNothing,
      reason: 'a wider window is not a licence to put everything back',
    );
  });
}
