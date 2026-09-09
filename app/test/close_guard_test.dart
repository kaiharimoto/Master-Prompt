import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/store/desktop_runner.dart';
import 'package:master_prompt/src/store/settings.dart';
import 'package:mp_runner/mp_runner.dart';

import 'connection_test.dart' show GatedLocator, fakeInstall;
import 'widget_test.dart' show wrap;

/// Closing the window mid-run used to be a one-click unconfirmed kill.
///
/// The Windows embedder consumes the first `WM_CLOSE` precisely so the
/// framework can answer, but only when something has registered for
/// `didRequestAppExit`. Nothing had. The fix is pure Dart, so unlike the rest
/// of the unattended-run work it can be proven here rather than only compiled.
void main() {
  late AppStore store;

  setUp(() async {
    store = AppStore(inMemory: true);
    await store.load();
  });

  tearDown(() => store.dispose());

  Future<DesktopRunner> busyRunner(
    WidgetTester tester,
    Completer<ClaudeInstall> gate, {
    required bool busy,
  }) async {
    final DesktopRunner runner = DesktopRunner(locator: GatedLocator(gate));
    addTearDown(runner.dispose);
    await tester.pumpWidget(wrap(HomeScreen(store: store, runner: runner)));
    await tester.pump();
    if (busy) {
      // `locating` is a busy state a test can reach; `running` needs a real
      // process, and the guard reads the same getter either way.
      unawaited(runner.detect(const AppSettings()));
      await tester.pump();
      expect(runner.isBusy, isTrue);
    }
    return runner;
  }

  testWidgets('closing with nothing running just closes', (
    WidgetTester tester,
  ) async {
    final Completer<ClaudeInstall> gate = Completer<ClaudeInstall>();
    await busyRunner(tester, gate, busy: false);

    final AppExitResponse r = await WidgetsBinding.instance
        .handleRequestAppExit();

    expect(r, AppExitResponse.exit);
    expect(
      find.text('A run is still going'),
      findsNothing,
      reason: 'a confirmation nobody needs is the fastest way to be ignored',
    );
    gate.complete(fakeInstall());
  });

  testWidgets(
    'closing mid-run asks, and keeping it running cancels the close',
    (WidgetTester tester) async {
      final Completer<ClaudeInstall> gate = Completer<ClaudeInstall>();
      await busyRunner(tester, gate, busy: true);

      final Future<AppExitResponse> asked = WidgetsBinding.instance
          .handleRequestAppExit();
      await tester.pumpAndSettle();

      expect(find.text('A run is still going'), findsOneWidget);
      await tester.tap(find.text('Keep running'));
      await tester.pumpAndSettle();

      expect(
        await asked,
        AppExitResponse.cancel,
        reason:
            'the run most worth keeping is one paused for a five-hour limit — '
            'hours of waiting, ended by a click on the wrong corner',
      );
      gate.complete(fakeInstall());
    },
  );

  testWidgets('closing anyway is still allowed', (WidgetTester tester) async {
    // The guard says what it would cost; it does not take the decision away.
    final Completer<ClaudeInstall> gate = Completer<ClaudeInstall>();
    await busyRunner(tester, gate, busy: true);

    final Future<AppExitResponse> asked = WidgetsBinding.instance
        .handleRequestAppExit();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close anyway'));
    await tester.pumpAndSettle();

    expect(await asked, AppExitResponse.exit);
    gate.complete(fakeInstall());
  });
}
