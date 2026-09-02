import 'package:meta/meta.dart';

/// Where a run is in the mission, independent of whether it is currently
/// running, paused or waiting on a paste.
///
/// Keeping this separate from run *lifecycle* is deliberate. Conflating them
/// makes "paused by a usage limit, during review cycle 3, mid-diagnosis"
/// inexpressible — and that is exactly the state a Pro-plan run spends its
/// time in.
enum MissionPhase {
  bootstrap,
  build,
  review,
  validation,
  done,
  unknown;

  static MissionPhase parse(String? raw) {
    if (raw == null) return MissionPhase.unknown;
    final String s = raw.trim().toLowerCase();
    for (final MissionPhase p in MissionPhase.values) {
      if (s == p.name) return p;
    }
    // Tolerate the model elaborating, e.g. "review:cycle3:diagnose".
    for (final MissionPhase p in MissionPhase.values) {
      if (p != MissionPhase.unknown && s.startsWith(p.name)) return p;
    }
    const Map<String, MissionPhase> aliases = <String, MissionPhase>{
      'boot': MissionPhase.bootstrap,
      'setup': MissionPhase.bootstrap,
      'planning': MissionPhase.bootstrap,
      'building': MissionPhase.build,
      'construct': MissionPhase.build,
      'reviewing': MissionPhase.review,
      'critique': MissionPhase.review,
      'validate': MissionPhase.validation,
      'validating': MissionPhase.validation,
      'complete': MissionPhase.done,
      'finished': MissionPhase.done,
    };
    return aliases[s] ?? MissionPhase.unknown;
  }
}

/// The model's own claim about where the mission stands, as carried by the
/// `mpstate` block at the end of every reply.
///
/// This is a *claim*, never the source of truth. The app's own projection is
/// authoritative; this exists so that (a) a copy-paste conversation can be
/// resumed at all, and (b) a divergence between what the model believes and
/// what the app recorded can be detected — which on the desktop is the only
/// available signal that context was silently compacted.
@immutable
class MpState {
  const MpState({
    required this.taskId,
    this.version = 1,
    this.phase = MissionPhase.unknown,
    this.step = '',
    this.cycle = 0,
    this.score = 0,
    this.next = '',
    this.blocked,
    this.ask,
    this.extra = const <String, String>{},
  });

  final int version;
  final String taskId;
  final MissionPhase phase;

  /// A few words on what is happening right now.
  final String step;

  /// Review cycle number; 0 before the review loop begins.
  final int cycle;

  /// Current rubric score, on the rubric's own scale.
  final double score;

  /// The single next action. This is what a resumed session acts on.
  final String next;

  /// What is blocking, if anything. Null and "none" are equivalent.
  final String? blocked;

  /// A question for the user, if the agent genuinely needs one. A well-formed
  /// mission brief should make this rare — that is the point of the readiness
  /// gate.
  final String? ask;

  /// Unrecognised keys, kept so a newer app version's fields survive a round
  /// trip through an older one.
  final Map<String, String> extra;

  bool get isBlocked => _meaningful(blocked);

  bool get hasQuestion => _meaningful(ask);

  bool get isComplete => phase == MissionPhase.done;

  static bool _meaningful(String? v) {
    if (v == null) return false;
    final String s = v.trim().toLowerCase();
    return s.isNotEmpty && s != 'none' && s != 'n/a' && s != '-' && s != 'null';
  }

  MpState copyWith({
    MissionPhase? phase,
    String? step,
    int? cycle,
    double? score,
    String? next,
    String? blocked,
    String? ask,
  }) => MpState(
    version: version,
    taskId: taskId,
    phase: phase ?? this.phase,
    step: step ?? this.step,
    cycle: cycle ?? this.cycle,
    score: score ?? this.score,
    next: next ?? this.next,
    blocked: blocked ?? this.blocked,
    ask: ask ?? this.ask,
    extra: extra,
  );

  /// Render back to the wire format. Used when seeding a resume capsule with
  /// the last known state.
  String render() {
    final StringBuffer b = StringBuffer()
      ..writeln('v=$version')
      ..writeln('task=$taskId')
      ..writeln('phase=${phase.name}')
      ..writeln('step=$step')
      ..writeln('cycle=$cycle')
      ..writeln('score=${_num(score)}')
      ..writeln('next=$next')
      ..writeln('blocked=${isBlocked ? blocked : 'none'}')
      ..write('ask=${hasQuestion ? ask : 'none'}');
    return b.toString();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'taskId': taskId,
    'phase': phase.name,
    'step': step,
    'cycle': cycle,
    'score': score,
    'next': next,
    if (blocked != null) 'blocked': blocked,
    if (ask != null) 'ask': ask,
    if (extra.isNotEmpty) 'extra': extra,
  };

  static MpState fromJson(Map<String, Object?> j) => MpState(
    version: (j['version'] as num?)?.toInt() ?? 1,
    taskId: '${j['taskId']}',
    phase: MissionPhase.parse(j['phase'] as String?),
    step: '${j['step'] ?? ''}',
    cycle: (j['cycle'] as num?)?.toInt() ?? 0,
    score: (j['score'] as num?)?.toDouble() ?? 0,
    next: '${j['next'] ?? ''}',
    blocked: j['blocked'] as String?,
    ask: j['ask'] as String?,
    extra: (j['extra'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
        .map((Object? k, Object? v) => MapEntry<String, String>('$k', '$v')),
  );

  @override
  String toString() =>
      'MpState(${phase.name}, cycle $cycle, score ${_num(score)}, next: $next)';
}
