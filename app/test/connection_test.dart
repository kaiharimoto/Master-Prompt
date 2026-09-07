import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/store/desktop_runner.dart';
import 'package:master_prompt/src/widgets/connection_panel.dart';
import 'package:mp_runner/mp_runner.dart';

import 'widget_test.dart' show wrap;

/// The panel is a fragment; on its own it has no Material ancestor and no
/// bounded height, both of which its text fields need.
Widget panel(AppStore store, DesktopRunner runner) => wrap(
  Scaffold(
    body: SingleChildScrollView(
      child: ConnectionPanel(store: store, runner: runner),
    ),
  ),
);

/// A CLI that is found, or is not, without one existing.
///
/// Probing runs real processes, which cannot complete inside the tester's
/// fake-async zone, so the panel could not otherwise be shown in either state.
class FakeLocator extends CliLocator {
  const FakeLocator({this.install, this.failure});

  final ClaudeInstall? install;
  final ClaudeNotFound? failure;

  @override
  Future<ClaudeInstall> locate({
    String? explicitPath,
    List<ProbeAttempt>? attempts,
  }) async {
    attempts
      ?..clear()
      ..addAll(failure?.attempts ?? _found);
    if (install != null) return install!;
    throw failure ?? ClaudeNotFound('nothing', attempts: _found);
  }

  static const List<ProbeAttempt> _found = <ProbeAttempt>[
    ProbeAttempt('claude', ProbeOutcome.found, '2.1.42 (Claude Code)'),
  ];
}

ClaudeInstall fakeInstall({
  ClaudeAuthMode auth = ClaudeAuthMode.subscription,
}) => ClaudeInstall(
  path: '/usr/local/bin/claude',
  capabilities: const HelpParser().parse(
    helpText: '''
Options:
  -p, --print
  --output-format <format>   (choices: "text", "json", "stream-json")
  --verbose
  --session-id <uuid>
  -r, --resume [value]
  --effort <level>           (low, medium, high)
''',
    version: '2.1.42 (Claude Code)',
    fingerprint: 'test',
  ),
  authMode: auth,
);

void main() {
  testWidgets('a connected CLI is named, with its version and credential', (
    WidgetTester tester,
  ) async {
    final AppStore store = AppStore(inMemory: true);
    await store.load();
    final DesktopRunner runner = DesktopRunner(
      locator: FakeLocator(install: fakeInstall()),
    );

    await tester.pumpWidget(panel(store, runner));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.textContaining('2.1.42'), findsOneWidget);
    expect(
      find.textContaining('subscription'),
      findsOneWidget,
      reason:
          'which credential is in use decides whether a limit is worth '
          'waiting out, so it is stated rather than left to be found',
    );
    expect(find.text('/usr/local/bin/claude'), findsOneWidget);
  });

  testWidgets('the panel answers on its own, without being asked', (
    WidgetTester tester,
  ) async {
    final AppStore store = AppStore(inMemory: true);
    await store.load();
    final DesktopRunner runner = DesktopRunner(
      locator: FakeLocator(install: fakeInstall()),
    );

    await tester.pumpWidget(panel(store, runner));
    await tester.pumpAndSettle();

    expect(
      runner.install,
      isNotNull,
      reason:
          'arriving at a panel that says nothing until you press something is '
          'the problem it replaces',
    );
  });

  testWidgets('a failed search names every candidate and what became of it', (
    WidgetTester tester,
  ) async {
    final AppStore store = AppStore(inMemory: true);
    await store.load();
    final DesktopRunner runner = DesktopRunner(
      locator: FakeLocator(
        failure: ClaudeNotFound(
          'The Claude Code CLI could not be found.',
          attempts: const <ProbeAttempt>[
            ProbeAttempt('claude', ProbeOutcome.missing),
            ProbeAttempt(
              r'C:\Users\k\AppData\Roaming\npm\claude.cmd',
              ProbeOutcome.notExecutable,
              'CreateProcess',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(panel(store, runner));
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.textContaining('could not be found'), findsOneWidget);

    await tester.tap(find.text('Where it looked'));
    await tester.pumpAndSettle();

    expect(find.text('claude'), findsOneWidget);
    expect(
      find.textContaining('could not be run'),
      findsOneWidget,
      reason:
          'an npm install reported as simply missing was the original bug; '
          'the reason has to reach the screen',
    );
  });

  testWidgets('testing the connection saves the path that was typed', (
    WidgetTester tester,
  ) async {
    final AppStore store = AppStore(inMemory: true);
    await store.load();
    final DesktopRunner runner = DesktopRunner(
      locator: FakeLocator(install: fakeInstall()),
    );

    await tester.pumpWidget(panel(store, runner));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '/opt/claude');
    await tester.tap(find.text('Test the connection'));
    await tester.pumpAndSettle();

    expect(
      store.settings.claudePath,
      '/opt/claude',
      reason:
          'the field would otherwise test a path it never kept, and the next '
          'launch would search again',
    );
  });
}
