import 'package:meta/meta.dart';

import 'spec_types.dart';

List<String> _strings(Object? raw) =>
    (raw as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList();

/// Section 00 — the machine, the tools, and how much rope the agent gets.
@immutable
class RuntimeProfile {
  const RuntimeProfile({
    this.compute = '',
    this.primaryTool = '',
    this.harness = '',
    this.startingAssets =
        'Nothing pre-made. Everything is generated from scratch.',
    this.tokenBudget = '100 million tokens',
    this.wallClock = '',
    this.autonomy =
        'Fully autonomous, zero human intervention until the quality gates are met.',
    this.subagentsRequired = true,
    this.constraints = const <String>[],
  });

  /// Hardware and environment facts the agent should not have to discover.
  final String compute;

  /// The tool the work is actually done with.
  final String primaryTool;

  /// What orchestration is available — subagents, parallelism, MCP.
  final String harness;

  final String startingAssets;
  final String tokenBudget;
  final String wallClock;
  final String autonomy;

  /// Whether the review loop's critics must be separate agents.
  final bool subagentsRequired;

  final List<String> constraints;

  Map<String, Object?> toJson() => <String, Object?>{
    'compute': compute,
    'primaryTool': primaryTool,
    'harness': harness,
    'startingAssets': startingAssets,
    'tokenBudget': tokenBudget,
    'wallClock': wallClock,
    'autonomy': autonomy,
    'subagentsRequired': subagentsRequired,
    'constraints': constraints,
  };

  static RuntimeProfile fromJson(Map<String, Object?> j) => RuntimeProfile(
    compute: '${j['compute'] ?? ''}',
    primaryTool: '${j['primaryTool'] ?? ''}',
    harness: '${j['harness'] ?? ''}',
    startingAssets: '${j['startingAssets'] ?? ''}',
    tokenBudget: '${j['tokenBudget'] ?? ''}',
    wallClock: '${j['wallClock'] ?? ''}',
    autonomy: '${j['autonomy'] ?? ''}',
    subagentsRequired: j['subagentsRequired'] as bool? ?? true,
    constraints: _strings(j['constraints']),
  );
}

/// The vocabulary of "good" for this mission, plus what to steer away from.
///
/// The session report behind this project singled this out: describing what a
/// good result *looks like* mattered more than instructing how to build it.
@immutable
class QualityLanguage {
  const QualityLanguage({
    this.palette = const <String>[],
    this.materials = const <String>[],
    this.atmosphere = '',
    this.compositionRules = const <String>[],
    this.detailStandard = '',
    this.storytelling = const <String>[],
    this.avoid = const <String>[],
  });

  /// The governing set of colours, tones, or stylistic anchors.
  final List<String> palette;

  /// Surfaces, textures, or in a non-visual domain, the equivalent substance
  /// vocabulary — tone of voice, code idiom, data shape.
  final List<String> materials;

  final String atmosphere;
  final List<String> compositionRules;

  /// How close an inspection the work must survive.
  final String detailStandard;

  /// Evidence of use, occupancy, or real operation.
  final List<String> storytelling;

  /// Explicit anti-goals. The reference brief's "avoid these interpretations"
  /// list did as much work as any positive instruction.
  final List<String> avoid;

  Map<String, Object?> toJson() => <String, Object?>{
    'palette': palette,
    'materials': materials,
    'atmosphere': atmosphere,
    'compositionRules': compositionRules,
    'detailStandard': detailStandard,
    'storytelling': storytelling,
    'avoid': avoid,
  };

  static QualityLanguage fromJson(Map<String, Object?> j) => QualityLanguage(
    palette: _strings(j['palette']),
    materials: _strings(j['materials']),
    atmosphere: '${j['atmosphere'] ?? ''}',
    compositionRules: _strings(j['compositionRules']),
    detailStandard: '${j['detailStandard'] ?? ''}',
    storytelling: _strings(j['storytelling']),
    avoid: _strings(j['avoid']),
  );
}

/// Section 04 — how the work gets criticised and repaired.
@immutable
class ReviewLoopSpec {
  const ReviewLoopSpec({
    this.minimumCycles = 4,
    this.critics = const <Critic>[],
    this.evidenceRule =
        'Criticism must be based on the captured evidence — not on code, the '
        'object tree, descriptions, or the builder\'s own summary.',
    this.regressionPolicy =
        'After every repair cycle, compare each artifact against the preceding '
        'version and label it improved, unchanged, or regressed. Fix or roll '
        'back regressions before continuing.',
    this.plateauRule =
        'If the score is below the exit threshold and improves by less than one '
        'point across two consecutive complete cycles, perform a structural '
        'pass instead of adding more small detail.',
  });

  final int minimumCycles;
  final List<Critic> critics;
  final String evidenceRule;
  final String regressionPolicy;
  final String plateauRule;

  Map<String, Object?> toJson() => <String, Object?>{
    'minimumCycles': minimumCycles,
    'critics': critics.map((Critic c) => c.toJson()).toList(),
    'evidenceRule': evidenceRule,
    'regressionPolicy': regressionPolicy,
    'plateauRule': plateauRule,
  };

  static ReviewLoopSpec fromJson(Map<String, Object?> j) => ReviewLoopSpec(
    minimumCycles: (j['minimumCycles'] as num?)?.toInt() ?? 4,
    critics: (j['critics'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Critic.fromJson(e! as Map<String, Object?>))
        .toList(),
    evidenceRule: '${j['evidenceRule'] ?? ''}',
    regressionPolicy: '${j['regressionPolicy'] ?? ''}',
    plateauRule: '${j['plateauRule'] ?? ''}',
  );
}

/// Section 06 — proving the result survives being reopened cold.
@immutable
class ValidationPlan {
  const ValidationPlan({
    this.coldStartProcedure = '',
    this.checks = const <String>[],
    this.reportContract =
        'The final response must list actual project and output paths, the '
        'evidence-backed rubric result, and any remaining non-critical '
        'limitations honestly.',
  });

  /// How to reopen the work from nothing and confirm it still functions.
  final String coldStartProcedure;

  final List<String> checks;
  final String reportContract;

  Map<String, Object?> toJson() => <String, Object?>{
    'coldStartProcedure': coldStartProcedure,
    'checks': checks,
    'reportContract': reportContract,
  };

  static ValidationPlan fromJson(Map<String, Object?> j) => ValidationPlan(
    coldStartProcedure: '${j['coldStartProcedure'] ?? ''}',
    checks: _strings(j['checks']),
    reportContract: '${j['reportContract'] ?? ''}',
  );
}

/// Section 08 — what lands on disk, and how it is organised.
@immutable
class DeliverablePlan {
  const DeliverablePlan({
    this.projectDirectory = '',
    this.tree = const <String, String>{},
    this.namingRules = const <String>[],
    this.portabilityRules = const <String>[],
  });

  final String projectDirectory;

  /// Path to one-line purpose. Rendered as an annotated tree.
  final Map<String, String> tree;

  final List<String> namingRules;
  final List<String> portabilityRules;

  Map<String, Object?> toJson() => <String, Object?>{
    'projectDirectory': projectDirectory,
    'tree': tree,
    'namingRules': namingRules,
    'portabilityRules': portabilityRules,
  };

  static DeliverablePlan fromJson(Map<String, Object?> j) => DeliverablePlan(
    projectDirectory: '${j['projectDirectory'] ?? ''}',
    tree: (j['tree'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
        .map((Object? k, Object? v) => MapEntry<String, String>('$k', '$v')),
    namingRules: _strings(j['namingRules']),
    portabilityRules: _strings(j['portabilityRules']),
  );
}
