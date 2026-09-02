import 'package:meta/meta.dart';

import '../spec/mission_spec.dart';
import 'interview_stage.dart';

/// One unmet requirement, with the consequence of leaving it unmet.
@immutable
class ReadinessGap {
  const ReadinessGap({required this.requirement, required this.blocking});

  final SpecRequirement requirement;

  /// Whether this stops the prompt from being compiled.
  final bool blocking;

  String get label => requirement.label;

  String get why => requirement.why;

  InterviewStage get stage => requirement.stage;
}

/// Whether a spec is complete enough to compile into an autonomous brief.
@immutable
class ReadinessReport {
  const ReadinessReport({
    required this.gaps,
    required this.satisfied,
    required this.totalRequired,
  });

  final List<ReadinessGap> gaps;

  /// How many required items are settled.
  final int satisfied;

  final int totalRequired;

  List<ReadinessGap> get blocking =>
      gaps.where((ReadinessGap g) => g.blocking).toList();

  List<ReadinessGap> get advisory =>
      gaps.where((ReadinessGap g) => !g.blocking).toList();

  /// The gate. Compilation is refused while anything required is unresolved.
  ///
  /// This is the mechanism that makes the eventual build autonomous: a brief
  /// with holes in it produces an agent that stops to ask, and the whole point
  /// is that it should never need to.
  bool get canCompile => blocking.isEmpty;

  /// 0..1, for the progress meter.
  double get completion =>
      totalRequired == 0 ? 1 : (satisfied / totalRequired).clamp(0, 1);

  /// The earliest stage that still has an unmet requirement — where the
  /// interview should resume.
  InterviewStage get currentStage {
    for (final InterviewStage s in InterviewStage.values) {
      if (gaps.any((ReadinessGap g) => g.stage == s)) return s;
    }
    return InterviewStage.ready;
  }

  @override
  String toString() =>
      'ReadinessReport($satisfied/$totalRequired, '
      '${blocking.length} blocking)';
}

/// Evaluates a spec against the interview's requirements.
class ReadinessGate {
  const ReadinessGate({this.requirements = kRequirements});

  final List<SpecRequirement> requirements;

  ReadinessReport evaluate(MissionSpec spec) {
    final List<ReadinessGap> gaps = <ReadinessGap>[];
    int satisfied = 0;
    int totalRequired = 0;

    for (final SpecRequirement r in requirements) {
      if (r.required_) totalRequired++;
      if (r.isSatisfiedBy(spec)) {
        if (r.required_) satisfied++;
        continue;
      }
      gaps.add(ReadinessGap(requirement: r, blocking: r.required_));
    }

    return ReadinessReport(
      gaps: List<ReadinessGap>.unmodifiable(gaps),
      satisfied: satisfied,
      totalRequired: totalRequired,
    );
  }
}
