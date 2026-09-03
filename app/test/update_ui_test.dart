import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/update/release.dart';
import 'package:master_prompt/src/update/updater.dart';
import 'package:mp_design/mp_design.dart';

import 'updater_test.dart' show FakeTransport;

Widget wrap(Widget child) => MaterialApp(
  theme: buildMpTheme(MpColors.light, dark: false),
  home: MpTheme(colors: MpColors.light, isDark: false, child: child),
);

void main() {
  late Directory tmp;
  late FakeTransport transport;
  late AppStore store;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mp-update-ui');
    transport = FakeTransport(tmp);
    store = AppStore(inMemory: true);
    await store.load();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<Updater> ready(WidgetTester tester, {required String build}) async {
    final Updater u = Updater(
      transport: transport,
      platform: UpdatePlatform.android,
      currentBuild: build,
    );
    addTearDown(u.dispose);
    await tester.runAsync(u.runCheck);
    await tester.pumpWidget(wrap(HomeScreen(store: store, updater: u)));
    await tester.pumpAndSettle();
    return u;
  }

  testWidgets('the menu says nothing when there is nothing to say', (
    WidgetTester tester,
  ) async {
    await ready(tester, build: '57');

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(
      find.text('Update'),
      findsNothing,
      reason:
          'the mark has to mean one thing only, so it cannot be present on a '
          'build that is already current',
    );
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('an available build surfaces, and one tap opens it', (
    WidgetTester tester,
  ) async {
    await ready(tester, build: '42');

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(
      find.text('Update'),
      findsOneWidget,
      reason: 'nothing else on screen would tell you a newer build exists',
    );

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.text('Build 57 is waiting'), findsOneWidget);
    expect(
      find.text('Download 12 B'),
      findsOneWidget,
      reason:
          'the size is the whole reason to say no on a phone, so it belongs '
          'on the button rather than a line under it — twelve bytes because '
          'the fake keeps its payload small, not because a build is',
    );
    expect(
      find.text('Install'),
      findsNothing,
      reason: 'one action at a time: install is not offered before it exists',
    );
  });

  testWidgets('downloading leads to an install button', (
    WidgetTester tester,
  ) async {
    final Updater u = await ready(tester, build: '42');

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    await tester.runAsync(u.download);
    await tester.pumpAndSettle();

    expect(find.text('Ready to install'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
    expect(
      find.textContaining('Download'),
      findsNothing,
      reason: 'the finished step stops being offered',
    );
  });
}
