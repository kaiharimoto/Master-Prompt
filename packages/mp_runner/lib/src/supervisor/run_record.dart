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
    scheduledResumeAt:
        clearSchedule ? null : (scheduledResumeAt ?? this.scheduledResumeAt),
    blockStartedAt: blockStartedAt ?? this.blockStartedAt,
    conclusion: conclusion ?? this.conclusion,
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
    'consecutiveNoProgress': consecutiveNoProgress,
    'createdAt': createdAt?.toIso8601String(),
  };

  static RunRecord fromJson(Map<String, Object?> j) => RunRecord(
    runId: '${j['runId']}',
    taskId: '${j['taskId']}',
    workingDirectory: '${j['workingDirectory']}',
    prompt: '${j['prompt']}',
    sessionId: j['sessionId'] as String?,
    scheduledResumeAt: _date(j['scheduledResumeAt']),
    blockStartedAt: _date(j['blockStartedAt']),
    conclusion: _conclusion(j['conclusion']),
    consecutiveNoProgress: (j['consecutiveNoProgress'] as num?)?.toInt() ?? 0,
    createdAt: _date(j['createdAt']),
  );

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
