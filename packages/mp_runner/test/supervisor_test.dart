import 'dart:async';
import 'dart:io';

import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

/// Compiled once; a real binary, so the supervisor's process handling, stream
/// decoding and stderr capture are all exercised for real.
late String fakeClaude;
late Directory tmp;

CapabilityProfile profileFor(String exe) {
  final ProcessResult help = Process.runSync(exe, <String>['--help']);
  return const HelpParser().parse(
    helpText: help.stdout as String,
    version: '2.1.42',
    fingerprint: 'fake',
  );
}

RunRecord newRun(String scenario) => RunRecord(
  runId: 'run-$scenario',
  taskId: 'skyline-restaurant-bar',
  workingDirectory: tmp.path,
  prompt: 'Build the mission.',
  createdAt: DateTime.utc(2026, 9, 2, 12),
);

RunSupervisor supervisorFor(
  String scenario, {
  required TestClock clock,
  required RunStore store,
  required String stateKey,
  int maxNoProgressResumes = 3,
  int maxAttempts = 40,
}) => RunSupervisor(
  executable: fakeClaude,
  capabilities: profileFor(fakeClaude),
  store: store,
  clock: clock,
  maxAttempts: maxAttempts,
  maxNoProgressResumes: maxNoProgressResumes,
  environmentOverrides: <String, String>{
    'FAKE_CLAUDE_SCENARIO': scenario,
    // Unique per test: the fake counts attempts in this file, so sharing it
    // would leak one test's attempts into the next.
    'FAKE_CLAUDE_STATE': '${tmp.path}/state-$stateKey',
  },
);

void main() {
  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('mp_supervisor_');
    fakeClaude = '${tmp.path}/fake_claude';
    final ProcessResult r = Process.runSync(
      Platform.resolvedExecutable,
      <String>['compile', 'exe', 'tool/fake_claude.dart', '-o', fakeClaude],
    );
    if (r.exitCode != 0) {
      throw StateError('could not build the fake CLI: ${r.stderr}');
    }
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('a clean run', () {
    test('completes on the first attempt and records the session', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store1'));
      final RunSupervisor s = supervisorFor(
        'success',
        clock: clock,
        store: store,
        stateKey: 'clean',
      );

      final RunRecord out = await s.execute(newRun('success'));
      await s.dispose();

      expect(out.conclusion, RunConclusion.completed);
      expect(out.attempts, hasLength(1));
      expect(out.attempts.single.strategy, 'fresh');
      expect(out.sessionId, isNotNull);
      expect(out.attempts.single.costUsd, 0.42);
      expect(clock.waitedUntil, isEmpty, reason: 'nothing to wait for');
    });

    test('says nothing on stderr, so the log stays worth reading', () async {
      // `Process.start` leaves the child's stdin open where `Process.run`
      // closes it. Left open, every launch and every resume of a twelve-hour
      // run began by waiting three seconds for input that was never coming,
      // then writing a warning about redirecting stdin into the run log.
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store-stderr'));
      final RunSupervisor s = supervisorFor(
        'success',
        clock: clock,
        store: store,
        stateKey: 'stderr',
      );

      final List<String> noise = <String>[];
      s.events
          .where((SupervisorEvent e) => e.kind == 'stderr')
          .listen((SupervisorEvent e) => noise.add(e.message));

      await s.execute(newRun('success'));
      await s.dispose();

      expect(
        noise,
        isEmpty,
        reason:
            'a run that logs a warning on every attempt teaches you to skim '
            'the one channel a usage limit is reported on',
      );
    });
  });

  group('a session limit is a pause, not a failure', () {
    test('detects the limit, waits, resumes, and finishes', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store2'));
      final RunSupervisor s = supervisorFor(
        'limit_then_success',
        clock: clock,
        store: store,
        stateKey: 'pause',
      );

      final List<SupervisorEvent> log = <SupervisorEvent>[];
      s.events.listen(log.add);

      final RunRecord out = await s.execute(newRun('limit_then_success'));
      await s.dispose();

      expect(out.conclusion, RunConclusion.completed);
      expect(out.attempts, hasLength(2));

      final RunAttempt first = out.attempts.first;
      expect(first.exitCode, 1);
      expect(first.verdict!.kind, LimitKind.fiveHour);

      final RunAttempt second = out.attempts[1];
      expect(
        second.strategy,
        'resume',
        reason: 'must reattach to the same session, not start over',
      );
      expect(second.succeeded, isTrue);

      // It actually waited, and for the right kind of interval.
      expect(clock.waitedUntil, hasLength(1));
      expect(
        clock.waitedUntil.single.difference(DateTime.utc(2026, 9, 2, 12)),
        greaterThan(const Duration(hours: 4)),
      );

      expect(
        log.any((SupervisorEvent e) => e.kind == 'limited'),
        isTrue,
        reason: 'the user must be told the run is paused, not stuck',
      );
    });

    test('the resume prompt tells the model not to start over', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store2b'));
      final RunSupervisor s = supervisorFor(
        'limit_then_success',
        clock: clock,
        store: store,
        stateKey: 'nudge',
      );
      final List<String> launches = <String>[];
      s.events
          .where((SupervisorEvent e) => e.kind == 'launch')
          .listen((SupervisorEvent e) => launches.add(e.message));

      await s.execute(newRun('limit_then_success'));
      await s.dispose();

      expect(launches, hasLength(2));
      expect(launches[1], contains('--resume'));
      expect(launches[1], contains('Do not restart'));
      expect(launches[1], contains('TASK_STATE.md'));
    });

    test('the schedule reaches disk before the wait begins', () async {
      // The moment that matters is *during* the wait: if the machine is shut
      // down then, the schedule must already be durable.
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final Directory dir = Directory('${tmp.path}/store3');
      final RunStore store = RunStore(dir);
      final RunSupervisor s = supervisorFor(
        'always_limit',
        clock: clock,
        store: store,
        stateKey: 'persist',
        maxAttempts: 2,
      );

      final List<RunRecord> whileWaiting = <RunRecord>[];
      s.events.where((SupervisorEvent e) => e.kind == 'limited').listen((
        SupervisorEvent e,
      ) async {
        final RunRecord? onDisk = await RunStore(dir).load('run-always_limit');
        if (onDisk != null) whileWaiting.add(onDisk);
      });

      await s.execute(newRun('always_limit'));
      await s.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(whileWaiting, isNotEmpty);
      final RunRecord paused = whileWaiting.first;
      expect(paused.scheduledResumeAt, isNotNull);
      expect(paused.isFinished, isFalse);
      expect(
        paused.prompt,
        'Build the mission.',
        reason: 'a cold reseed must be possible from the record alone',
      );
    });

    test(
      'a run interrupted mid-wait is offered for resume on next launch',
      () async {
        final Directory dir = Directory('${tmp.path}/store3b');
        // Exactly the state the app would find after being killed while waiting.
        await RunStore(dir).save(
          RunRecord(
            runId: 'interrupted',
            taskId: 'skyline-restaurant-bar',
            workingDirectory: tmp.path,
            prompt: 'Build the mission.',
            sessionId: 'sess-1',
            scheduledResumeAt: DateTime.utc(2026, 9, 2, 17),
          ),
        );

        final List<RunRecord> pending = await RunStore(dir).pendingResumes();
        expect(pending, hasLength(1));
        expect(pending.single.runId, 'interrupted');
        expect(pending.single.sessionId, 'sess-1');
      },
    );
  });

  group('the resume ladder', () {
    test(
      'falls back to forking when the session cannot be reattached',
      () async {
        final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
        final RunStore store = RunStore(Directory('${tmp.path}/store4'));
        final RunSupervisor s = supervisorFor(
          'resume_rejected',
          clock: clock,
          store: store,
          stateKey: 'ladder',
        );
        final List<SupervisorEvent> log = <SupervisorEvent>[];
        s.events.listen(log.add);

        final RunRecord out = await s.execute(newRun('resume_rejected'));
        await s.dispose();

        expect(out.conclusion, RunConclusion.completed);
        final List<String> strategies = out.attempts
            .map((RunAttempt a) => a.strategy)
            .toList();
        expect(strategies, contains('fork-resume'));
        expect(
          log.any((SupervisorEvent e) => e.message.contains('forking')),
          isTrue,
        );
        // A rejected resume must not burn a five-hour wait.
        expect(clock.waitedUntil, isEmpty);
      },
    );
  });

  group('failures that time cannot fix stop immediately', () {
    test('an auth failure stalls without waiting or retrying', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store5'));
      final RunSupervisor s = supervisorFor(
        'auth_failure',
        clock: clock,
        store: store,
        stateKey: 'auth',
      );
      final List<SupervisorEvent> log = <SupervisorEvent>[];
      s.events.listen(log.add);

      final RunRecord out = await s.execute(newRun('auth_failure'));
      await s.dispose();

      expect(out.conclusion, RunConclusion.stalled);
      expect(out.attempts, hasLength(1), reason: 'must not retry auth');
      expect(clock.waitedUntil, isEmpty);
      expect(
        log.any((SupervisorEvent e) => e.message.contains('Sign in again')),
        isTrue,
      );
    });

    test('a weekly limit is reported as account-wide', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store6'));
      final RunSupervisor s = RunSupervisor(
        executable: fakeClaude,
        capabilities: profileFor(fakeClaude),
        store: store,
        clock: clock,
        maxAttempts: 1,
        environmentOverrides: <String, String>{
          'FAKE_CLAUDE_SCENARIO': 'weekly_limit',
          'FAKE_CLAUDE_STATE': '${tmp.path}/state-weekly',
        },
      );
      final List<SupervisorEvent> log = <SupervisorEvent>[];
      s.events.listen(log.add);

      final RunRecord out = await s.execute(newRun('weekly_limit'));
      await s.dispose();

      expect(out.lastVerdict!.kind, LimitKind.sevenDay);
      expect(out.lastVerdict!.kind.isAccountWide, isTrue);
      expect(
        log.any(
          (SupervisorEvent e) =>
              e.message.contains('another device will not help'),
        ),
        isTrue,
        reason: 'sending the user to their phone would waste their time',
      );
    });
  });

  group('progress, not liveness, decides whether a run is healthy', () {
    test('resuming repeatedly without progress stalls the run', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store7'));
      // die_midstream exits nonzero with no result and no assistant text.
      final RunSupervisor s = RunSupervisor(
        executable: fakeClaude,
        capabilities: profileFor(fakeClaude),
        store: store,
        clock: clock,
        maxAttempts: 6,
        environmentOverrides: <String, String>{
          'FAKE_CLAUDE_SCENARIO': 'die_midstream',
          'FAKE_CLAUDE_STATE': '${tmp.path}/state-die',
        },
      );
      final RunRecord out = await s.execute(newRun('die_midstream'));
      await s.dispose();

      // It must terminate rather than looping forever.
      expect(out.isFinished, isTrue);
      expect(out.attempts.length, lessThanOrEqualTo(6));
    });
  });

  group('the run record is the truth', () {
    test('every attempt is durably recorded and reloadable', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final Directory dir = Directory('${tmp.path}/store8');
      final RunStore store = RunStore(dir);
      final RunSupervisor s = supervisorFor(
        'limit_then_success',
        clock: clock,
        store: store,
        stateKey: 'record',
      );
      final RunRecord out = await s.execute(newRun('limit_then_success'));
      await s.dispose();

      final RunRecord? reloaded = await RunStore(dir).load(out.runId);
      expect(reloaded, isNotNull);
      expect(reloaded!.conclusion, RunConclusion.completed);
      expect(reloaded.sessionId, out.sessionId);
      expect(reloaded.taskId, 'skyline-restaurant-bar');
    });

    test('a completed run is not offered for resume', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final Directory dir = Directory('${tmp.path}/store9');
      final RunStore store = RunStore(dir);
      final RunSupervisor s = supervisorFor(
        'success',
        clock: clock,
        store: store,
        stateKey: 'notpending',
      );
      await s.execute(newRun('success'));
      await s.dispose();

      expect(await RunStore(dir).pendingResumes(), isEmpty);
    });
  });

  group('stopping is something the user did, not something that failed', () {
    test('Stop is felt inside a limit pause, not five hours later', () async {
      // The worst state this program could put someone in. `_current` is null
      // throughout a pause, so `kill()` reached nothing, and the only
      // cancellation check ran after the wait returned. `paused` counts as
      // busy, so Run stayed disabled and Stop went on doing nothing — for up
      // to five hours, with no way out but killing the app.
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store-stopwait'));
      final RunSupervisor s = supervisorFor(
        'always_limit',
        clock: clock,
        store: store,
        stateKey: 'stopwait',
      );

      s.events
          .where((SupervisorEvent e) => e.kind == 'limited')
          .take(1)
          .listen((_) => s.cancel());

      final RunRecord out = await s.execute(newRun('always_limit'));
      await s.dispose();

      expect(
        clock.wasInterrupted,
        isTrue,
        reason:
            'the conclusion alone would be the same if the wait were served '
            'out in full, so this is the assertion that proves Stop reaches '
            'inside it',
      );
      expect(out.conclusion, RunConclusion.cancelled);
    });

    test('a stop mid-attempt is not written down as a stall', () async {
      // A killed process exits non-zero, which the detector reads as
      // `unknown`, which is not waitable — so a deliberate stop was recorded
      // as `stalled` and painted red with `process exited with -15` in it.
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final RunStore store = RunStore(Directory('${tmp.path}/store-stopmid'));
      final RunSupervisor s = RunSupervisor(
        executable: fakeClaude,
        capabilities: profileFor(fakeClaude),
        store: store,
        clock: clock,
        environmentOverrides: <String, String>{
          'FAKE_CLAUDE_SCENARIO': 'slow',
          'FAKE_CLAUDE_STATE': '${tmp.path}/state-stopmid',
          'FAKE_CLAUDE_SLEEP_MS': '30000',
        },
      );

      final List<String> kinds = <String>[];
      s.events.listen((SupervisorEvent e) => kinds.add(e.kind));
      s.events
          .where((SupervisorEvent e) => e.kind == 'launch')
          .take(1)
          .listen((_) => s.cancel());

      final RunRecord out = await s.execute(newRun('slow'));
      await s.dispose();

      expect(out.conclusion, RunConclusion.cancelled);
      expect(
        kinds,
        isNot(contains('stalled')),
        reason:
            'a stall is a diagnosis about the run; a stop is a fact about the '
            'user, and reporting one as the other sends them looking for a '
            'fault that is not there',
      );
    });

    test('a stopped run is still offered for resume', () async {
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final Directory dir = Directory('${tmp.path}/store-stopresume');
      final RunSupervisor s = supervisorFor(
        'always_limit',
        clock: clock,
        store: RunStore(dir),
        stateKey: 'stopresume',
      );
      s.events
          .where((SupervisorEvent e) => e.kind == 'limited')
          .take(1)
          .listen((_) => s.cancel());

      final RunRecord out = await s.execute(newRun('always_limit'));
      await s.dispose();

      final RunRecord? reloaded = await RunStore(dir).load(out.runId);
      expect(
        reloaded!.sessionId,
        isNotNull,
        reason:
            'Stop says "the run is saved and can be resumed", and the session '
            'id is the whole of what makes that true',
      );
    });
  });

  group('the record on disk is the record that comes back', () {
    test('a reloaded run remembers its attempts and why it paused', () async {
      // The ceiling that stops a pathological loop is counted from
      // `attempts.length`, and the verdict is what the screen uses to say why
      // a run is paused. Both were written by `toJson` and dropped by
      // `fromJson`, so every restart reset the ceiling to zero and every
      // reloaded pause could say only that it was paused.
      final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
      final Directory dir = Directory('${tmp.path}/store-roundtrip');
      final RunSupervisor s = supervisorFor(
        'limit_then_success',
        clock: clock,
        store: RunStore(dir),
        stateKey: 'roundtrip',
      );

      final RunRecord out = await s.execute(newRun('limit_then_success'));
      await s.dispose();
      final RunRecord reloaded = (await RunStore(dir).load(out.runId))!;

      expect(out.attempts, hasLength(greaterThan(1)));
      expect(reloaded.attempts, hasLength(out.attempts.length));
      expect(
        reloaded.attempts.first.exitCode,
        out.attempts.first.exitCode,
        reason: 'an attempt that is back but empty counts the same as gone',
      );
      expect(reloaded.lastVerdict?.kind, out.lastVerdict?.kind);
    });
  });

  group('a run left open is offered back', () {
    test('a run interrupted mid-attempt is resumable, though nothing '
        'scheduled it', () async {
      // The case a resume is most wanted for, and the one `pendingResumes`
      // cannot see: the app was closed or the machine rebooted partway
      // through, so there is no scheduled time to be waiting for.
      final Directory dir = Directory('${tmp.path}/store-open');
      final RunStore store = RunStore(dir);
      final DateTime now = DateTime.utc(2026, 9, 2, 12);
      await store.save(
        RunRecord(
          runId: 'interrupted',
          taskId: 'skyline-restaurant-bar',
          workingDirectory: tmp.path,
          prompt: 'Build it.',
          sessionId: 'a0000000-0000-4000-8000-000000000000',
          createdAt: now,
        ),
      );

      final List<RunRecord> open = await store.resumable(now: now);
      expect(await store.pendingResumes(), isEmpty);
      expect(open, hasLength(1));
      expect(
        open.single.sessionId,
        isNotNull,
        reason:
            'the session id is the difference between reattaching and sending '
            'the whole brief again as a new conversation',
      );
    });

    test(
      'a run stopped by hand is offered, and a finished one is not',
      () async {
        final Directory dir = Directory('${tmp.path}/store-stopped');
        final RunStore store = RunStore(dir);
        final DateTime now = DateTime.utc(2026, 9, 2, 12);
        RunRecord base(String id, RunConclusion? c) => RunRecord(
          runId: id,
          taskId: 't',
          workingDirectory: tmp.path,
          prompt: 'p',
          conclusion: c,
          createdAt: now,
        );

        await store.save(base('stopped', RunConclusion.cancelled));
        await store.save(base('done', RunConclusion.completed));
        await store.save(base('stalled', RunConclusion.stalled));

        final List<String> ids = <String>[
          for (final RunRecord r in await store.resumable(now: now)) r.runId,
        ];
        expect(
          ids,
          contains('stopped'),
          reason: 'Stop says the run can be resumed, so it had better be',
        );
        expect(ids, isNot(contains('done')));
      },
    );

    test('a run from three weeks ago is not an offer worth making', () async {
      final Directory dir = Directory('${tmp.path}/store-stale');
      final RunStore store = RunStore(dir);
      final DateTime now = DateTime.utc(2026, 9, 2, 12);
      await store.save(
        RunRecord(
          runId: 'ancient',
          taskId: 't',
          workingDirectory: tmp.path,
          prompt: 'p',
          createdAt: now.subtract(const Duration(days: 21)),
        ),
      );

      expect(await store.resumable(now: now), isEmpty);
      expect(
        await store.resumable(now: now, within: const Duration(days: 30)),
        hasLength(1),
        reason: 'the window is a judgement, so it is a parameter',
      );
    });

    test('a resumed record is not finished before it starts', () async {
      // `isFinished` is the supervisor's loop condition, and a stopped record
      // handed straight back would break out of the loop on the first check.
      final RunRecord stopped = RunRecord(
        runId: 'r',
        taskId: 't',
        workingDirectory: tmp.path,
        prompt: 'p',
        conclusion: RunConclusion.cancelled,
      );

      expect(stopped.isFinished, isTrue);
      expect(stopped.copyWith(clearConclusion: true).isFinished, isFalse);
    });

    test('the newest is offered first', () async {
      final Directory dir = Directory('${tmp.path}/store-order');
      final RunStore store = RunStore(dir);
      final DateTime now = DateTime.utc(2026, 9, 2, 12);
      for (int i = 0; i < 3; i++) {
        await store.save(
          RunRecord(
            runId: 'r$i',
            taskId: 't',
            workingDirectory: tmp.path,
            prompt: 'p',
            createdAt: now.subtract(Duration(hours: i)),
          ),
        );
      }
      expect((await store.resumable(now: now)).first.runId, 'r0');
    });
  });

  group('the clock that actually waits', () {
    test('cuts a long wait short the moment Stop arrives', () async {
      // TestClock is a stand-in; this is the implementation that will be
      // holding a real five-hour pause, and its slice loop is where the
      // interrupt has to be honoured.
      const SystemClock clock = SystemClock();
      final Completer<void> stop = Completer<void>();
      final Stopwatch watch = Stopwatch()..start();

      final Future<void> waiting = clock.waitUntil(
        DateTime.now().toUtc().add(const Duration(hours: 5)),
        interrupted: stop.future,
      );
      stop.complete();
      await waiting;

      expect(
        watch.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: 'the alternative is five hours',
      );
    });

    test('waits out a short one when nothing interrupts', () async {
      const SystemClock clock = SystemClock();
      final Completer<void> never = Completer<void>();
      final Stopwatch watch = Stopwatch()..start();

      await clock.waitUntil(
        DateTime.now().toUtc().add(const Duration(milliseconds: 120)),
        interrupted: never.future,
      );

      expect(
        watch.elapsedMilliseconds,
        greaterThanOrEqualTo(100),
        reason:
            'an interrupt that is never signalled must not turn every pause '
            'into no pause at all',
      );
    });
  });
}
