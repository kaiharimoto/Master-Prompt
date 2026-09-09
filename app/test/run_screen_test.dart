import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/run_screen.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/store/desktop_runner.dart';
import 'dart:io';

import 'package:master_prompt/src/store/project.dart';
import 'package:master_prompt/src/store/settings.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_runner/mp_runner.dart';

import 'connection_test.dart' show fakeInstall;
import 'red_team_test.dart' show seedPatch, tapVisible, wrap;

/// A runner in a state a test can put it in.
///
/// Every state that matters here — running, paused on a limit, unable to find
/// the CLI — is reached by starting a real process and waiting hours, none of
/// which happens inside the tester's fake-async zone. The run screen therefore
/// had no coverage at all: not the log, not the paused state, not Stop.
class StubRunner extends DesktopRunner {
  StubRunner({
    this.stubStatus = DesktopRunStatus.running,
    this.stubInstall = true,
    this.stubState,
    this.stubAttempt = 0,
    this.stubCost,
    this.stubSession,
    this.stubResumeAt,
    this.stubLimit,
    this.stubError,
    this.stubAttempts = const <ProbeAttempt>[],
    this.stubLog = const <String>[],
    this.stubElapsed = Duration.zero,
    this.stubDirectory,
    this.stubOutcome,
    this.stubResumable,
    this.stubAwake = true,
  });

  final DesktopRunStatus stubStatus;
  final bool stubInstall;
  final MpState? stubState;
  final int stubAttempt;
  final double? stubCost;
  final String? stubSession;
  final DateTime? stubResumeAt;
  final LimitKind? stubLimit;
  final String? stubError;
  final List<ProbeAttempt> stubAttempts;
  final List<String> stubLog;
  final Duration stubElapsed;
  final String? stubDirectory;
  final MissionOutcome? stubOutcome;
  final RunRecord? stubResumable;
  final bool stubAwake;

  @override
  DesktopRunStatus get status => stubStatus;
  @override
  bool get isBusy =>
      stubStatus == DesktopRunStatus.running ||
      stubStatus == DesktopRunStatus.paused;
  @override
  ClaudeInstall? get install => stubInstall ? fakeInstall() : null;
  @override
  MpState? get state => stubState;
  @override
  int get attempt => stubAttempt;
  @override
  double? get costUsd => stubCost;
  @override
  String? get sessionId => stubSession;
  @override
  DateTime? get resumeAt => stubResumeAt;
  @override
  LimitKind? get limitKind => stubLimit;
  @override
  String? get error => stubError;
  @override
  List<ProbeAttempt> get attempts => stubAttempts;
  @override
  List<String> get log => stubLog;
  @override
  Duration get elapsed => stubElapsed;
  @override
  String? get workingDirectory => stubDirectory;
  @override
  MissionOutcome? get outcome => stubOutcome;
  @override
  RunRecord? get resumable => stubResumable;
  @override
  bool get holdingAwake => stubAwake;

  /// The screen sweeps the store on arrival. There is no store here.
  @override
  Future<void> lookForResumable({
    required Project project,
    required Directory stateDirectory,
  }) async {}

  /// The screen probes on arrival. There is nothing to probe here, and a real
  /// one cannot complete in the tester's zone.
  @override
  Future<void> detect(AppSettings settings) async {}
}

MpState beat({
  double score = 61,
  MissionPhase phase = MissionPhase.build,
  String next = 'Light the backbar',
  String? blocked,
  String? ask,
  int cycle = 2,
}) => MpState(
  taskId: 'cocktail_bar',
  phase: phase,
  step: 'modelling the stools',
  cycle: cycle,
  score: score,
  next: next,
  blocked: blocked,
  ask: ask,
);

void main() {
  late AppStore store;
  late Project project;

  setUp(() async {
    store = AppStore(inMemory: true);
    await store.load();
    final SpecPatchResult seeded = const SpecPatchParser().parse(
      seedPatch,
      const MissionSpec(
        id: 'p',
        taskId: 'cocktail_bar',
        title: 'Cocktail bar',
        presetId: 'generic',
      ),
    );
    project = Project(id: 'p', spec: seeded.spec.confirmProposals());
  });

  tearDown(() => store.dispose());

  Future<void> show(WidgetTester tester, DesktopRunner runner) async {
    await tester.pumpWidget(
      wrap(RunScreen(store: store, project: project, runner: runner)),
    );
    await tester.pumpAndSettle();
  }

  group('a run says what it is doing', () {
    testWidgets('the score the run reported reaches the screen', (
      WidgetTester tester,
    ) async {
      // The whole Progress section was dead on desktop. The brief demands an
      // mpstate heartbeat on every reply; nothing parsed it, so for twelve
      // hours this panel said "nothing recorded yet" while the run reported
      // its score every turn.
      await show(tester, StubRunner(stubState: beat(score: 61)));

      expect(find.textContaining('Nothing recorded yet'), findsNothing);
      expect(find.text('61 / 100'), findsOneWidget);
      expect(find.text('BUILD'), findsOneWidget);
      expect(find.text('Light the backbar'), findsOneWidget);
    });

    testWidgets('what it is blocked on, and what it wants to ask', (
      WidgetTester tester,
    ) async {
      // Both have nowhere else to appear: if the agent stops and asks through
      // the heartbeat, the supervisor sees a clean exit and the run looks
      // finished.
      await show(
        tester,
        StubRunner(
          stubState: beat(
            blocked: 'No reference for the backbar',
            ask: 'Brass or steel?',
          ),
        ),
      );

      expect(find.text('No reference for the backbar'), findsOneWidget);
      expect(find.text('Brass or steel?'), findsOneWidget);
    });

    testWidgets('elapsed, attempt and spend are on screen', (
      WidgetTester tester,
    ) async {
      // All three were computed, written to JSON, and dropped before they
      // reached a widget. A run on its seventh resume looked exactly like one
      // that had just started.
      await show(
        tester,
        StubRunner(
          stubElapsed: const Duration(hours: 2, minutes: 14),
          stubAttempt: 7,
          stubCost: 4.2,
          stubSession: 'b2f1c0de-0000-4000-8000-000000000000',
        ),
      );

      expect(find.text('2h 14m'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text(r'$4.20'), findsOneWidget);
      expect(
        find.textContaining('b2f1c0de'),
        findsOneWidget,
        reason: 'the session id is what makes a resume a resume',
      );
    });

    testWidgets('a machine that will sleep through the run says so', (
      WidgetTester tester,
    ) async {
      // The failure is total and silent — a run that ends at hour three did
      // not fail, it stopped — so the absence of the hold is worth knowing
      // before the night rather than after it.
      await show(tester, StubRunner(stubAwake: false));
      expect(find.text('not held'), findsOneWidget);
    });

    testWidgets('a machine being held awake says that too', (
      WidgetTester tester,
    ) async {
      await show(tester, StubRunner());
      expect(find.text('held off'), findsOneWidget);
    });

    testWidgets('the working directory is named, not alluded to', (
      WidgetTester tester,
    ) async {
      await show(tester, StubRunner(stubDirectory: '/home/k/missions/bar'));
      expect(find.textContaining('/home/k/missions/bar'), findsOneWidget);
    });
  });

  group('a run left open is offered back', () {
    testWidgets('an interrupted run is offered, not silently abandoned', (
      WidgetTester tester,
    ) async {
      // Reopening the app used to show the Run screen exactly as it was before
      // anything happened — idle, empty log, one button reading "Run this
      // mission" — which minted a fresh id with no session and sent the whole
      // brief again, while the panel promised that closing the app was safe.
      await show(
        tester,
        StubRunner(
          stubStatus: DesktopRunStatus.idle,
          stubResumable: RunRecord(
            runId: 'r',
            taskId: 'cocktail_bar',
            workingDirectory: '/tmp/bar',
            prompt: 'Build it.',
            sessionId: 'a0000000-0000-4000-8000-000000000000',
            attempts: <RunAttempt>[
              RunAttempt(
                index: 1,
                startedAt: DateTime.utc(2026),
                endedAt: DateTime.utc(2026),
                exitCode: 0,
                sessionId: 'a0000000-0000-4000-8000-000000000000',
                strategy: 'fresh',
              ),
            ],
            createdAt: DateTime.utc(2026),
          ),
        ),
      );

      expect(find.text('A run was left unfinished.'), findsOneWidget);
      expect(find.text('Continue this run'), findsOneWidget);
      expect(find.textContaining('a0000000'), findsOneWidget);
      expect(
        find.text('Start over'),
        findsOneWidget,
        reason:
            'starting again is still offered, and is now named for what it '
            'actually does rather than being the only choice',
      );
    });

    testWidgets('a run with no session says what continuing would cost', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        StubRunner(
          stubStatus: DesktopRunStatus.idle,
          stubResumable: RunRecord(
            runId: 'r',
            taskId: 'cocktail_bar',
            workingDirectory: '/tmp/bar',
            prompt: 'Build it.',
            createdAt: DateTime.utc(2026),
          ),
        ),
      );

      expect(find.textContaining('no session to reattach to'), findsOneWidget);
    });

    testWidgets('nothing is offered while a run is going', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        StubRunner(
          stubResumable: RunRecord(
            runId: 'r',
            taskId: 'cocktail_bar',
            workingDirectory: '/tmp/bar',
            prompt: 'p',
            createdAt: DateTime.utc(2026),
          ),
        ),
      );
      expect(find.text('Continue this run'), findsNothing);
    });
  });

  group('finished is not the same as done', () {
    testWidgets('a run that missed the brief is not painted as a success', (
      WidgetTester tester,
    ) async {
      // The supervisor's `completed` means the process exited zero and the
      // CLI said `success`. A run that produced one of three artifacts and
      // scored 61 against a threshold of 90 used to be the same green as one
      // that met every gate.
      await show(
        tester,
        StubRunner(
          stubStatus: DesktopRunStatus.finished,
          stubOutcome: MissionCheck.inspect(
            spec: project.spec,
            filesPresent: const <String>{},
            reported: beat(score: 61),
          ),
        ),
      );

      expect(
        find.textContaining('not everything the brief asked for'),
        findsOneWidget,
      );
      expect(find.textContaining('exit threshold of 90'), findsOneWidget);
      expect(find.textContaining('01_arrival.png'), findsOneWidget);
    });

    testWidgets('a run that met the brief says so plainly', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        StubRunner(
          stubStatus: DesktopRunStatus.finished,
          stubOutcome: MissionCheck.inspect(
            spec: project.spec,
            filesPresent: <String>{
              '01_arrival.png',
              ...MissionCheck.directiveFiles,
            },
            reported: beat(score: 96, phase: MissionPhase.done, cycle: 4),
            // The seed brief names one critic, and a review nobody
            // independent did is a review the builder gave itself.
            criticsSeen: 1,
          ),
        ),
      );

      expect(find.text('It met the brief.'), findsOneWidget);
    });
  });

  group('a pause is a pause, and a failure says where to go', () {
    testWidgets('a limit counts down instead of naming a distant time', (
      WidgetTester tester,
    ) async {
      // A static timestamp five hours out is indistinguishable from a hang,
      // and it used to be printed with microseconds on it.
      await show(
        tester,
        StubRunner(
          stubStatus: DesktopRunStatus.paused,
          stubResumeAt: DateTime.now().toUtc().add(
            const Duration(hours: 4, minutes: 30),
          ),
          stubLimit: LimitKind.fiveHour,
        ),
      );

      expect(find.textContaining('in 4h 29m'), findsOneWidget);
      expect(find.textContaining('.000'), findsNothing);
    });

    testWidgets('a CLI that was not found says where it looked', (
      WidgetTester tester,
    ) async {
      // The list exists so someone who does not know how they installed the
      // CLI is told rather than asked. It was reachable only from Settings, so
      // from here you got one sentence and nowhere to go.
      await show(
        tester,
        StubRunner(
          stubStatus: DesktopRunStatus.failed,
          stubInstall: false,
          stubError: 'Claude Code was not found.',
          stubAttempts: const <ProbeAttempt>[
            ProbeAttempt(
              r'%APPDATA%\npm\claude.cmd',
              ProbeOutcome.missing,
              'no such file',
            ),
          ],
        ),
      );

      expect(find.text('Claude Code was not found.'), findsOneWidget);
      await tapVisible(tester, find.text('Where it looked'));
      expect(find.textContaining('claude.cmd'), findsOneWidget);
    });

    testWidgets('Stop is offered while a limit is being waited out', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        StubRunner(
          stubStatus: DesktopRunStatus.paused,
          stubResumeAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          stubLimit: LimitKind.fiveHour,
        ),
      );
      expect(
        find.text('Stop'),
        findsOneWidget,
        reason:
            'a pause is the state Stop was inert in, so it had better be '
            'reachable there',
      );
    });
  });
}
