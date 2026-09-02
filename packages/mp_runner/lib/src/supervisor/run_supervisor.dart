import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../cli/capability_profile.dart';
import '../cli/launch_plan.dart';
import '../stream/cli_event.dart';
import 'clock.dart';
import 'limit_detector.dart';
import 'run_record.dart';

/// Something the supervisor wants the UI to know, as it happens.
class SupervisorEvent {
  SupervisorEvent(this.kind, this.message, {this.record, this.cliEvent});

  final String kind;
  final String message;
  final RunRecord? record;
  final CliEvent? cliEvent;

  @override
  String toString() => '[$kind] $message';
}

/// Drives the CLI through as many attempts as it takes, surviving usage limits.
///
/// The governing idea: **the model's context is a cache; the run record is the
/// truth.** A usage-limit pause, a compaction, a crash and a reboot are the
/// same failure — the working memory vanished, the mission did not — so they
/// share one recovery path.
class RunSupervisor {
  RunSupervisor({
    required this.executable,
    required this.capabilities,
    required this.store,
    this.clock = const SystemClock(),
    this.detector = const LimitDetector(),
    this.maxAttempts = 40,
    this.maxNoProgressResumes = 3,
    this.environmentOverrides = const <String, String>{},
  });

  final String executable;
  final CapabilityProfile capabilities;
  final RunStore store;
  final Clock clock;
  final LimitDetector detector;

  /// Ceiling on total attempts, so a pathological loop cannot run forever.
  final int maxAttempts;

  /// Resumes that succeed but change nothing before the run is declared stalled.
  /// Distinguishes "resumed twenty times" from "made progress".
  final int maxNoProgressResumes;

  final Map<String, String> environmentOverrides;

  final StreamController<SupervisorEvent> _events =
      StreamController<SupervisorEvent>.broadcast();

  Stream<SupervisorEvent> get events => _events.stream;

  Process? _current;
  bool _cancelled = false;

  /// Ask the running process to stop. The record is left resumable.
  Future<void> cancel() async {
    _cancelled = true;
    _current?.kill();
  }

  void _emit(String kind, String message, {RunRecord? record, CliEvent? e}) {
    if (!_events.isClosed) {
      _events.add(SupervisorEvent(kind, message, record: record, cliEvent: e));
    }
  }

  /// Run to completion, waiting out usage limits as they occur.
  Future<RunRecord> execute(RunRecord initial, {String? resumeNudge}) async {
    RunRecord record = initial.copyWith(
      blockStartedAt: initial.blockStartedAt ?? clock.nowUtc(),
    );
    await store.save(record);

    LaunchIntent intent = record.sessionId == null
        ? LaunchIntent.fresh
        : LaunchIntent.resume;
    String? pinnedId = record.sessionId ?? _uuid();
    bool forkNext = false;

    while (!record.isFinished) {
      if (_cancelled) {
        record = record.copyWith(conclusion: RunConclusion.cancelled);
        break;
      }
      if (record.attempts.length >= maxAttempts) {
        _emit('stalled', 'Reached the attempt ceiling of $maxAttempts.');
        record = record.copyWith(conclusion: RunConclusion.exhausted);
        break;
      }

      // A resume must never be launched with an empty prompt; the continuation
      // directive is what tells the model not to start over.
      final String prompt = intent == LaunchIntent.fresh
          ? record.prompt
          : (resumeNudge ?? _defaultNudge(record));

      final LaunchRequest request = LaunchRequest(
        prompt: prompt,
        workingDirectory: record.workingDirectory,
        intent: forkNext ? LaunchIntent.forkResume : intent,
        sessionId: pinnedId,
        resumeSessionId: record.sessionId,
      );

      final LaunchPlan plan;
      try {
        plan = const LaunchPlanBuilder().build(
          executable: executable,
          capabilities: capabilities,
          request: request,
        );
      } on LaunchPlanError catch (e) {
        _emit('stalled', 'Cannot launch: ${e.message}');
        record = record.copyWith(conclusion: RunConclusion.stalled);
        break;
      }

      for (final String note in plan.notes) {
        _emit('degraded', note);
      }

      final _AttemptResult r = await _runOnce(plan, record);
      record = record.copyWith(
        attempts: <RunAttempt>[...record.attempts, r.attempt],
        sessionId: r.attempt.sessionId ?? record.sessionId,
      );

      if (r.attempt.succeeded) {
        final bool progressed = r.madeProgress;
        record = record.copyWith(
          consecutiveNoProgress: progressed
              ? 0
              : record.consecutiveNoProgress + 1,
          clearSchedule: true,
        );
        if (r.completed) {
          record = record.copyWith(conclusion: RunConclusion.completed);
          _emit('completed', 'Run finished successfully.', record: record);
          break;
        }
        if (record.consecutiveNoProgress >= maxNoProgressResumes) {
          _emit(
            'stalled',
            'Resumed ${record.consecutiveNoProgress} times without progress. '
                'Stopping so this does not loop silently.',
          );
          record = record.copyWith(conclusion: RunConclusion.stalled);
          break;
        }
        // Succeeded but not finished: continue in the same session.
        intent = LaunchIntent.resume;
        forkNext = false;
        pinnedId = null;
        await store.save(record);
        continue;
      }

      // --- the attempt failed -------------------------------------------
      final LimitVerdict v = r.attempt.verdict ?? LimitVerdict.clear;
      record = record.copyWith(lastVerdict: v);

      // A rejected resume is a step on the ladder, not a terminal condition, so
      // it is handled before the waitable check. It classifies as `unknown` —
      // there is no limit involved — and would otherwise stall the run when the
      // fix is simply to fork or restart cold.
      if (r.resumeRejected) {
        if (!forkNext && capabilities.has('--fork-session')) {
          _emit(
            'resume',
            'The session could not be reattached; forking from its transcript.',
          );
          forkNext = true;
          pinnedId = _uuid();
          await store.save(record);
          continue;
        }
        _emit(
          'resume',
          'The session cannot be reattached. Restarting cold from the mission '
              'brief and the recorded state.',
        );
        intent = LaunchIntent.fresh;
        forkNext = false;
        pinnedId = _uuid();
        record = record.copyWith(sessionId: null);
        await store.save(record);
        continue;
      }

      if (!v.kind.isWaitable) {
        _emit('stalled', switch (v.kind) {
          LimitKind.auth =>
            'Authentication failed. Sign in again, then resume this run.',
          LimitKind.overage =>
            'A spend or credit limit was reached. This needs a billing '
                'decision, not time.',
          LimitKind.fatal => 'Unrecoverable: ${v.evidence.join('; ')}',
          _ => 'Stopped: ${v.evidence.join('; ')}',
        }, record: record);
        record = record.copyWith(conclusion: RunConclusion.stalled);
        break;
      }

      final DateTime resumeAt =
          v.resetAt ?? clock.nowUtc().add(const Duration(minutes: 15));
      record = record.copyWith(scheduledResumeAt: resumeAt);
      await store.save(record);

      _emit(
        'limited',
        '${_describe(v.kind)} Resuming at ${resumeAt.toIso8601String()} '
            '(${v.source.name}).',
        record: record,
      );

      await clock.waitUntil(resumeAt);
      if (_cancelled) {
        record = record.copyWith(conclusion: RunConclusion.cancelled);
        break;
      }

      // A five-hour window that has elapsed starts a new block.
      record = record.copyWith(
        blockStartedAt: clock.nowUtc(),
        clearSchedule: true,
      );
      intent = record.sessionId == null
          ? LaunchIntent.fresh
          : LaunchIntent.resume;
      forkNext = false;
      pinnedId = record.sessionId == null ? _uuid() : null;
    }

    await store.save(record);
    return record;
  }

  String _describe(LimitKind kind) => switch (kind) {
    LimitKind.fiveHour => 'Session limit reached.',
    LimitKind.sevenDay =>
      'Weekly limit reached. This is account-wide, so another device will not '
          'help.',
    LimitKind.sevenDayOpus =>
      'Weekly Opus limit reached. A smaller model may still work.',
    LimitKind.sevenDaySonnet => 'Weekly Sonnet limit reached.',
    LimitKind.transient => 'A temporary failure.',
    _ => 'Paused.',
  };

  String _defaultNudge(RunRecord record) =>
      'Resume the mission "${record.taskId}". Re-read the mission brief, '
      'DIRECTION.md and TASK_STATE.md, open the latest checkpoint, and continue '
      'from the recorded next action. Do not restart the work and do not '
      're-plan. End your reply with the mpstate block.';

  Future<_AttemptResult> _runOnce(LaunchPlan plan, RunRecord record) async {
    final DateTime started = clock.nowUtc();
    final int index = record.attempts.length + 1;
    _emit('launch', 'Attempt $index: ${plan.arguments.join(' ')}');

    final Map<String, String> env = <String, String>{
      ...Platform.environment,
      ...environmentOverrides,
    };
    for (final MapEntry<String, String?> e in plan.environment.entries) {
      if (e.value == null) {
        env.remove(e.key);
      } else {
        env[e.key] = e.value!;
      }
    }

    final Process process = await Process.start(
      plan.executable,
      plan.arguments,
      workingDirectory: plan.workingDirectory,
      environment: env,
      includeParentEnvironment: false,
    );
    _current = process;

    final List<CliEvent> events = <CliEvent>[];
    final StringBuffer assistantText = StringBuffer();
    final StringBuffer stderrBuffer = StringBuffer();
    String? sessionId;
    ResultEvent? result;

    final Future<void> outDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          if (line.trim().isEmpty) return;
          final CliEvent e = CliEvent.parse(line);
          events.add(e);
          sessionId ??= e.sessionId;
          if (e is AssistantEvent && !e.isSubagent) {
            assistantText.write(e.text);
          }
          if (e is ResultEvent) result = e;
          if (e is CompactionEvent) {
            _emit(
              'compaction',
              'Context was compacted at ${e.preTokens ?? 'an unknown number of'} '
                  'tokens. The next turn will be reoriented from the run record.',
              e: e,
            );
          }
          _emit('event', line, e: e);
        })
        .asFuture<void>();

    final Future<void> errDone = process.stderr.transform(utf8.decoder).listen((
      String chunk,
    ) {
      // stderr is a first-class channel: the human-readable limit message
      // exists nowhere else, because Error.message is non-enumerable and
      // the CLI serialises events with a plain JSON.stringify.
      stderrBuffer.write(chunk);
      _emit('stderr', chunk.trimRight());
    }).asFuture<void>();

    final int exitCode = await process.exitCode;
    await Future.wait<void>(<Future<void>>[outDone, errDone]);
    _current = null;

    final String stderrText = stderrBuffer.toString();
    final LimitVerdict verdict = exitCode == 0
        ? LimitVerdict.clear
        : detector.detect(
            LimitSignals(
              stderr: stderrText,
              events: events,
              exitCode: exitCode,
              blockStartedAt: record.blockStartedAt,
              now: clock.nowUtc(),
            ),
          );

    final bool resumeRejected =
        exitCode != 0 &&
        RegExp(
          r'no conversation found|session .*not found|cannot resume',
          caseSensitive: false,
        ).hasMatch(stderrText);

    return _AttemptResult(
      attempt: RunAttempt(
        index: index,
        startedAt: started,
        endedAt: clock.nowUtc(),
        exitCode: exitCode,
        sessionId: sessionId ?? plan.sessionId,
        strategy: plan.arguments.contains('--fork-session')
            ? 'fork-resume'
            : plan.arguments.contains('--resume')
            ? 'resume'
            : 'fresh',
        verdict: verdict,
        assistantText: assistantText.toString(),
        eventCount: events.length,
        costUsd: result?.costUsd,
      ),
      completed: result?.isSuccess ?? false,
      madeProgress: assistantText.isNotEmpty,
      resumeRejected: resumeRejected,
    );
  }

  Future<void> dispose() async => _events.close();

  static int _counter = 0;

  /// A v4-shaped identifier. The CLI only requires a valid UUID; this avoids a
  /// dependency for something with no security role.
  static String _uuid() {
    final int n = DateTime.now().microsecondsSinceEpoch + (_counter++);
    final String hex = n.toRadixString(16).padLeft(16, '0');
    final String tail = (n * 2654435761 & 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '4${hex.substring(13, 16)}-a${tail.substring(0, 3)}-${tail.substring(0, 12)}';
  }
}

class _AttemptResult {
  const _AttemptResult({
    required this.attempt,
    required this.completed,
    required this.madeProgress,
    required this.resumeRejected,
  });

  final RunAttempt attempt;
  final bool completed;
  final bool madeProgress;
  final bool resumeRejected;
}
