import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'limit_detector.dart';

/// Why a run stopped.
enum RunConclusion {
  /// Finished, with a success result.
  completed,

  /// Gave up after exhausting the resume ladder or the retry budget.
  exhausted,

  /// Stopped and needs the user: auth, billing, or an unrecoverable fault.
  stalled,

  /// Cancelled from the UI.
  cancelled,
}

/// One attempt at running the CLI.
@immutable
class RunAttempt {
  const RunAttempt({
    required this.index,
    required this.startedAt,
    required this.endedAt,
    required this.exitCode,
    required this.sessionId,
    required this.strategy,
    this.verdict,
    this.assistantText = '',
    this.eventCount = 0,
    this.costUsd,
  });

  final int index;
  final DateTime startedAt;
  final DateTime endedAt;
  final int exitCode;
  final String? sessionId;

  /// How this attempt was launched, for the run log.
  final String strategy;

  final LimitVerdict? verdict;
  final String assistantText;
  final int eventCount;
  final double? costUsd;

  bool get succeeded => exitCode == 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'exitCode': exitCode,
    'sessionId': sessionId,
    'strategy': strategy,
    'verdict': verdict?.kind.name,
    'resetAt': verdict?.resetAt?.toIso8601String(),
    'eventCount': eventCount,
    'costUsd': costUsd,
  };

  /// The assistant's own text is deliberately not persisted — a twelve-hour
  /// run's worth of it would dwarf the record, and the full stream is already
  /// on disk beside it.
  static RunAttempt fromJson(Map<String, Object?> j) => RunAttempt(
    index: (j['index'] as num?)?.toInt() ?? 0,
    startedAt: RunRecord._date(j['startedAt']) ?? DateTime.utc(1970),
    endedAt: RunRecord._date(j['endedAt']) ?? DateTime.utc(1970),
    exitCode: (j['exitCode'] as num?)?.toInt() ?? 0,
    sessionId: j['sessionId'] as String?,
    strategy: '${j['strategy'] ?? 'unknown'}',
    verdict: _verdict(j['verdict'], j['resetAt']),
    eventCount: (j['eventCount'] as num?)?.toInt() ?? 0,
    costUsd: (j['costUsd'] as num?)?.toDouble(),
  );

  static LimitVerdict? _verdict(Object? kind, Object? resetAt) {
    if (kind == null) return null;
    for (final LimitKind k in LimitKind.values) {
      if (k.name == kind) {
        return LimitVerdict(kind: k, resetAt: RunRecord._date(resetAt));
      }
    }
    return null;
  }
}

/// The durable record of a run, written to disk after every transition.
///
/// This is the file that makes a scheduled resume survive closing the app and
/// rebooting the machine. It is deliberately a plain JSON document rather than
/// a database row: it must be readable, repairable by hand, and recoverable
/// even if the app will not start.
@immutable
class RunRecord {
  const RunRecord({
    required this.runId,
    required this.taskId,
    required this.workingDirectory,
    required this.prompt,
    this.sessionId,
    this.attempts = const <RunAttempt>[],
    this.scheduledResumeAt,
    this.blockStartedAt,
    this.conclusion,
    this.lastVerdict,
    this.consecutiveNoProgress = 0,
    this.createdAt,
  });

  final String runId;
  final String taskId;
  final String workingDirectory;

  /// The compiled master prompt. Kept so a cold reseed can rebuild the run
  /// without needing the app's database.
  final String prompt;

  final String? sessionId;
  final List<RunAttempt> attempts;

  /// When the supervisor intends to try again. Re-armed on every app launch.
  final DateTime? scheduledResumeAt;

  /// Start of the current five-hour usage block, for reset inference.
  final DateTime? blockStartedAt;

  final RunConclusion? conclusion;
  final LimitVerdict? lastVerdict;

  /// Resumes that succeeded but produced no forward progress. A run that
  /// re-attaches twenty times and does nothing is failing, even though every
  /// individual attempt "worked".
  final int consecutiveNoProgress;

  final DateTime? createdAt;

  bool get isFinished => conclusion != null;

  RunRecord copyWith({
    String? sessionId,
    List<RunAttempt>? attempts,
    DateTime? scheduledResumeAt,
    bool clearSchedule = false,
    bool clearConclusion = false,
    DateTime? blockStartedAt,
    RunConclusion? conclusion,
    LimitVerdict? lastVerdict,
    int? consecutiveNoProgress,
  }) => RunRecord(
    runId: runId,
    taskId: taskId,
    workingDirectory: workingDirectory,
    prompt: prompt,
    sessionId: sessionId ?? this.sessionId,
    attempts: attempts ?? this.attempts,
    scheduledResumeAt: clearSchedule
        ? null
        : (scheduledResumeAt ?? this.scheduledResumeAt),
    blockStartedAt: blockStartedAt ?? this.blockStartedAt,
    // A resumed run is not finished any more, and `isFinished` is what the
    // supervisor's loop condition reads — a stopped record handed back for
    // resume would otherwise be over before it started.
    conclusion: clearConclusion ? null : (conclusion ?? this.conclusion),
    lastVerdict: lastVerdict ?? this.lastVerdict,
    consecutiveNoProgress: consecutiveNoProgress ?? this.consecutiveNoProgress,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'runId': runId,
    'taskId': taskId,
    'workingDirectory': workingDirectory,
    'prompt': prompt,
    'sessionId': sessionId,
    'attempts': attempts.map((RunAttempt a) => a.toJson()).toList(),
    'scheduledResumeAt': scheduledResumeAt?.toIso8601String(),
    'blockStartedAt': blockStartedAt?.toIso8601String(),
    'conclusion': conclusion?.name,
    'lastLimitKind': lastVerdict?.kind.name,
    'lastLimitResetAt': lastVerdict?.resetAt?.toIso8601String(),
    'lastLimitEvidence': lastVerdict?.evidence,
    'consecutiveNoProgress': consecutiveNoProgress,
    'createdAt': createdAt?.toIso8601String(),
  };

  /// The inverse of [toJson], and it has to be exact.
  ///
  /// `attempts` and `lastVerdict` were written and never read back. The
  /// attempt ceiling exists so a pathological loop cannot run forever, and it
  /// is counted from `attempts.length` — so a run reloaded from disk started
  /// again from zero, and the ceiling reset every time the app was restarted.
  /// The verdict is the other half: it is what the screen uses to say *why*
  /// the run is paused, and a reloaded run could only say that it was.
  static RunRecord fromJson(Map<String, Object?> j) => RunRecord(
    runId: '${j['runId']}',
    taskId: '${j['taskId']}',
    workingDirectory: '${j['workingDirectory']}',
    prompt: '${j['prompt']}',
    sessionId: j['sessionId'] as String?,
    attempts: <RunAttempt>[
      for (final Object? a in (j['attempts'] as List<Object?>?) ?? const [])
        if (a is Map<String, Object?>) RunAttempt.fromJson(a),
    ],
    scheduledResumeAt: _date(j['scheduledResumeAt']),
    blockStartedAt: _date(j['blockStartedAt']),
    conclusion: _conclusion(j['conclusion']),
    lastVerdict: _lastVerdict(j),
    consecutiveNoProgress: (j['consecutiveNoProgress'] as num?)?.toInt() ?? 0,
    createdAt: _date(j['createdAt']),
  );

  static LimitVerdict? _lastVerdict(Map<String, Object?> j) {
    final Object? kind = j['lastLimitKind'];
    if (kind == null) return null;
    for (final LimitKind k in LimitKind.values) {
      if (k.name == kind) {
        return LimitVerdict(
          kind: k,
          resetAt: _date(j['lastLimitResetAt']),
          evidence: <String>[
            for (final Object? e
                in (j['lastLimitEvidence'] as List<Object?>?) ?? const [])
              '$e',
          ],
        );
      }
    }
    return null;
  }

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse('$v')?.toUtc();

  static RunConclusion? _conclusion(Object? v) {
    for (final RunConclusion c in RunConclusion.values) {
      if (c.name == v) return c;
    }
    return null;
  }
}

/// Reads and writes [RunRecord]s as JSON files.
///
/// Writes are atomic — to a temporary file, then renamed — because the moment
/// this file is most likely to be written is also the moment the machine is
/// most likely to be shut down.
class RunStore {
  RunStore(this.directory);

  final Directory directory;

  File fileFor(String runId) =>
      File('${directory.path}${Platform.pathSeparator}$runId.json');

  Future<void> save(RunRecord record) async {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final File target = fileFor(record.runId);
    final File temp = File('${target.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
      flush: true,
    );
    await temp.rename(target.path);
  }

  Future<RunRecord?> load(String runId) async {
    final File f = fileFor(runId);
    if (!f.existsSync()) return null;
    try {
      final Object? j = jsonDecode(await f.readAsString());
      if (j is Map<String, Object?>) return RunRecord.fromJson(j);
    } on FormatException {
      return null;
    }
    return null;
  }

  /// Every run that could be picked up again.
  ///
  /// Broader than [pendingResumes] on purpose, and the difference is the whole
  /// point. That one answers "which runs are waiting on a clock", and a run
  /// whose app was closed or whose machine rebooted mid-attempt has no
  /// scheduled time at all — which is exactly the case a resume is most wanted
  /// for. A run stopped by hand counts too, because Stop says the run is saved
  /// and can be resumed and that had better be true.
  ///
  /// [now] is a parameter rather than a call to the clock so the staleness
  /// window is testable; a record from three weeks ago is not an offer worth
  /// making.
  Future<List<RunRecord>> resumable({
    Duration within = const Duration(days: 7),
    DateTime? now,
  }) async {
    final DateTime at = now ?? DateTime.now().toUtc();
    final List<RunRecord> out = <RunRecord>[];
    for (final RunRecord r in await _all()) {
      final bool open =
          !r.isFinished || r.conclusion == RunConclusion.cancelled;
      if (!open) continue;
      final DateTime? made = r.createdAt;
      if (made != null && at.difference(made) > within) continue;
      out.add(r);
    }
    out.sort(
      (RunRecord a, RunRecord b) => (b.createdAt ?? DateTime.utc(1970))
          .compareTo(a.createdAt ?? DateTime.utc(1970)),
    );
    return out;
  }

  Future<List<RunRecord>> _all() async {
    if (!directory.existsSync()) return <RunRecord>[];
    final List<RunRecord> out = <RunRecord>[];
    for (final FileSystemEntity e in directory.listSync()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final Object? j = jsonDecode(await e.readAsString());
        if (j is Map<String, Object?>) out.add(RunRecord.fromJson(j));
      } on FormatException {
        continue;
      }
    }
    return out;
  }

  /// Every run that is waiting for a scheduled resume.
  ///
  /// Called on every app launch. This sweep — not the in-process timer — is
  /// what actually guarantees a resume happens: if the app was closed or the
  /// machine rebooted through the reset time, opening the app fixes it.
  Future<List<RunRecord>> pendingResumes() async {
    if (!directory.existsSync()) return <RunRecord>[];
    final List<RunRecord> out = <RunRecord>[];
    for (final FileSystemEntity e in directory.listSync()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final Object? j = jsonDecode(await e.readAsString());
        if (j is! Map<String, Object?>) continue;
        final RunRecord r = RunRecord.fromJson(j);
        if (!r.isFinished && r.scheduledResumeAt != null) out.add(r);
      } on FormatException {
        continue;
      }
    }
    out.sort(
      (RunRecord a, RunRecord b) =>
          a.scheduledResumeAt!.compareTo(b.scheduledResumeAt!),
    );
    return out;
  }
}
