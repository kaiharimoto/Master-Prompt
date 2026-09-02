import 'package:meta/meta.dart';

import '../spec/mission_spec.dart';
import '../spec/spec_types.dart';

/// The ordered stages of the pre-build discussion.
///
/// The order is the point. The session report this project is modelled on was
/// explicit that establishing *what* before *how* is what lets the model end up
/// knowing the goal better than the author did. Runtime and build mechanics
/// come late deliberately: deciding them early anchors the whole brief to an
/// implementation before anyone has agreed what "good" means.
enum InterviewStage {
  /// One line about the idea, and which domain preset fits.
  seed,

  /// What is being made, for whom, and what makes it succeed.
  intent,

  /// The parts it must have, and how they relate.
  shape,

  /// What "good" looks like — the vocabulary, and the anti-goals.
  quality,

  /// The fixed, numbered artifacts that will prove completeness.
  evidence,

  /// Machine, tools, budget, autonomy.
  runtime,

  /// Weighted categories, exit threshold, per-category floors.
  rubric,

  /// How many cycles, and which critics.
  review,

  /// What makes the result unacceptable, and how completion is verified.
  acceptance,

  /// Everything required is settled; the prompt can be compiled.
  ready;

  String get title => switch (this) {
    InterviewStage.seed => 'The idea',
    InterviewStage.intent => 'Intent',
    InterviewStage.shape => 'Shape',
    InterviewStage.quality => 'Quality',
    InterviewStage.evidence => 'Evidence',
    InterviewStage.runtime => 'Runtime',
    InterviewStage.rubric => 'Rubric',
    InterviewStage.review => 'Review',
    InterviewStage.acceptance => 'Acceptance',
    InterviewStage.ready => 'Ready',
  };

  /// What this stage is trying to settle, shown above the questions.
  String get purpose => switch (this) {
    InterviewStage.seed =>
      'Establish what is being built, in one or two sentences.',
    InterviewStage.intent =>
      'Pin down the goal, who judges the result, and the through-line that '
          'holds it together.',
    InterviewStage.shape =>
      'Enumerate the parts that must exist and the relationships between them.',
    InterviewStage.quality =>
      'Build the vocabulary of good — and, just as importantly, the list of '
          'interpretations to avoid.',
    InterviewStage.evidence =>
      'Fix the numbered set of artifacts that will prove every part is '
          'finished. This set never changes once the build starts.',
    InterviewStage.runtime =>
      'State the machine, the tools, the budget, and how much autonomy the '
          'agent has.',
    InterviewStage.rubric =>
      'Define how the work scores itself and when it is allowed to stop.',
    InterviewStage.review =>
      'Decide how many review cycles run and which critics judge them.',
    InterviewStage.acceptance =>
      'Name what would make the result unacceptable, and how completion is '
          'verified from a cold start.',
    InterviewStage.ready => 'Everything required is settled.',
  };

  InterviewStage? get next {
    final int i = index + 1;
    return i < InterviewStage.values.length ? InterviewStage.values[i] : null;
  }
}

/// One thing the interview needs to settle.
@immutable
class SpecRequirement {
  const SpecRequirement({
    required this.key,
    required this.stage,
    required this.label,
    required this.why,
    this.required_ = true,
    this.waivable = true,
  });

  /// Stable identifier, used by the patch format.
  final String key;

  final InterviewStage stage;
  final String label;

  /// What goes wrong in an unattended run if this is left unresolved. Shown in
  /// the readiness panel, because "you must fill this in" is much less
  /// persuasive than "without this the agent will stop and ask".
  final String why;

  final bool required_;

  /// Whether the user may hand this decision to the agent instead of deciding.
  final bool waivable;

  /// Whether the spec currently satisfies this requirement.
  bool isSatisfiedBy(MissionSpec spec) => _resolvers[key]?.call(spec) ?? true;
}

typedef _Resolver = bool Function(MissionSpec);

/// How each requirement reads its answer out of the spec.
final Map<String, _Resolver> _resolvers = <String, _Resolver>{
  'mission': (MissionSpec s) => s.missionStatement.isSettled,
  'story': (MissionSpec s) => s.definingStory.isSettled,
  'scale': (MissionSpec s) => s.scale.isSettled,
  'audience': (MissionSpec s) => s.audience.isSettled,
  'regions': (MissionSpec s) => s.regions.isNotEmpty,
  'relationships': (MissionSpec s) => s.relationships.isNotEmpty,
  'families': (MissionSpec s) => s.families.isNotEmpty,
  'avoid': (MissionSpec s) => s.quality.avoid.isNotEmpty,
  'quality': (MissionSpec s) =>
      s.quality.palette.isNotEmpty ||
      s.quality.materials.isNotEmpty ||
      s.quality.detailStandard.isNotEmpty,
  'evidence': (MissionSpec s) => s.evidence.isNotEmpty,
  'hero': (MissionSpec s) => s.evidence.any((EvidenceArtifact e) => e.isHero),
  'runtime_tool': (MissionSpec s) => s.runtime.primaryTool.trim().isNotEmpty,
  'runtime_budget': (MissionSpec s) => s.runtime.tokenBudget.trim().isNotEmpty,
  'buildOrder': (MissionSpec s) => s.buildOrder.isNotEmpty,
  'rubric': (MissionSpec s) => s.rubric.categories.isNotEmpty,
  'rubric_balanced': (MissionSpec s) => s.rubric.isBalanced,
  'critics': (MissionSpec s) => s.review.critics.isNotEmpty,
  'failures': (MissionSpec s) => s.failureConditions.isNotEmpty,
  'validation': (MissionSpec s) =>
      s.validation.coldStartProcedure.trim().isNotEmpty ||
      s.validation.checks.isNotEmpty,
  'deliverables': (MissionSpec s) =>
      s.deliverables.projectDirectory.trim().isNotEmpty,
};

/// Everything the interview tries to settle, in stage order.
const List<SpecRequirement> kRequirements = <SpecRequirement>[
  SpecRequirement(
    key: 'mission',
    stage: InterviewStage.seed,
    label: 'Mission statement',
    why:
        'Without it the agent has no single sentence to check its work against.',
  ),
  SpecRequirement(
    key: 'audience',
    stage: InterviewStage.intent,
    label: 'Who judges the result',
    why: 'Determines the standard. "Good" is meaningless without it.',
  ),
  SpecRequirement(
    key: 'story',
    stage: InterviewStage.intent,
    label: 'Defining story',
    why:
        'Without a through-line the agent optimises each part in isolation and '
        'the result reads as assembled rather than designed.',
  ),
  SpecRequirement(
    key: 'scale',
    stage: InterviewStage.intent,
    label: 'Scale',
    why: 'Concrete extent stops the agent from guessing how much to build.',
  ),
  SpecRequirement(
    key: 'regions',
    stage: InterviewStage.shape,
    label: 'Required parts',
    why:
        'Coverage cannot be checked without them, and the agent will build only '
        'what the hero artifact shows.',
  ),
  SpecRequirement(
    key: 'relationships',
    stage: InterviewStage.shape,
    label: 'Relationships between parts',
    why: 'Parts that exist but do not connect produce an incoherent result.',
    required_: false,
  ),
  SpecRequirement(
    key: 'families',
    stage: InterviewStage.shape,
    label: 'Component families with minimum counts',
    why:
        'Explicit floors are what stop the agent building one of something and '
        'calling the family done.',
  ),
  SpecRequirement(
    key: 'avoid',
    stage: InterviewStage.quality,
    label: 'Interpretations to avoid',
    why:
        'The anti-goal list does as much work as any positive instruction. It '
        'closes off the cliché the agent would otherwise drift toward.',
  ),
  SpecRequirement(
    key: 'quality',
    stage: InterviewStage.quality,
    label: 'Quality language',
    why:
        'Describing what a good result looks like matters more than describing '
        'how to build it.',
  ),
  SpecRequirement(
    key: 'evidence',
    stage: InterviewStage.evidence,
    label: 'Evidence set',
    why:
        'Nothing fixes what the review loop re-captures each cycle, so '
        'regressions cannot be detected by comparison.',
  ),
  SpecRequirement(
    key: 'hero',
    stage: InterviewStage.evidence,
    label: 'Hero artifact',
    why:
        'One artifact must carry the strictest standard and the cold-start check.',
    required_: false,
  ),
  SpecRequirement(
    key: 'runtime_tool',
    stage: InterviewStage.runtime,
    label: 'Primary tool',
    why:
        'The agent will otherwise spend its first turns discovering the '
        'environment instead of building.',
  ),
  SpecRequirement(
    key: 'runtime_budget',
    stage: InterviewStage.runtime,
    label: 'Budget',
    why: 'Sets how much exploration and rework the agent may spend.',
  ),
  SpecRequirement(
    key: 'buildOrder',
    stage: InterviewStage.runtime,
    label: 'Build order',
    why:
        'Without it the agent chooses its own sequencing, which usually means '
        'detail before structure.',
    required_: false,
  ),
  SpecRequirement(
    key: 'rubric',
    stage: InterviewStage.rubric,
    label: 'Rubric categories',
    why:
        'Without a rubric the agent cannot decide when it is finished, and the '
        'review loop has no exit condition.',
    waivable: false,
  ),
  SpecRequirement(
    key: 'rubric_balanced',
    stage: InterviewStage.rubric,
    label: 'Rubric weights that sum correctly',
    why:
        'Scores computed against weights that do not sum are not interpretable.',
    waivable: false,
  ),
  SpecRequirement(
    key: 'critics',
    stage: InterviewStage.review,
    label: 'Critics',
    why:
        'Self-review by the builder reliably misses what the builder '
        'rationalised while building.',
  ),
  SpecRequirement(
    key: 'failures',
    stage: InterviewStage.acceptance,
    label: 'Failure conditions',
    why:
        'These do more than the rubric to prevent the specific shortcuts an '
        'agent reaches for under time pressure.',
  ),
  SpecRequirement(
    key: 'validation',
    stage: InterviewStage.acceptance,
    label: 'Cold-start validation',
    why: 'Proves the result survives being reopened from nothing.',
  ),
  SpecRequirement(
    key: 'deliverables',
    stage: InterviewStage.acceptance,
    label: 'Project directory',
    why: 'The agent needs one unambiguous place to put its work.',
    required_: false,
  ),
];
