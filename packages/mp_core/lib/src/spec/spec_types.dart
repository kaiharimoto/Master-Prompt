import 'package:meta/meta.dart';

/// Helpers shared by the value types below.
List<String> _stringList(Object? raw) =>
    (raw as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList();

E _byName<E extends Enum>(List<E> values, Object? name, E fallback) {
  for (final E v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// A named part of the work that must exist, be reachable, and be shown.
///
/// Generalises the reference brief's "required zones": in a 3D scene this is a
/// room, in a software project a subsystem, in a report a chapter. The rule
/// carried over verbatim is that a region may never exist only as a label —
/// hence [mustBeLegible].
@immutable
class ScopeRegion {
  const ScopeRegion({
    required this.id,
    required this.name,
    required this.purpose,
    this.requirements = const <String>[],
    this.mustBeLegible = true,
  });

  final String id;
  final String name;

  /// One sentence on what this region is for.
  final String purpose;

  /// Specific things that must be present inside it.
  final List<String> requirements;

  /// When true the compiler emits the "may not exist only as a name on a closed
  /// door" clause for this region.
  final bool mustBeLegible;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'purpose': purpose,
    'requirements': requirements,
    'mustBeLegible': mustBeLegible,
  };

  static ScopeRegion fromJson(Map<String, Object?> j) => ScopeRegion(
    id: '${j['id']}',
    name: '${j['name']}',
    purpose: '${j['purpose'] ?? ''}',
    requirements: _stringList(j['requirements']),
    mustBeLegible: j['mustBeLegible'] as bool? ?? true,
  );
}

/// A coherent family of repeated things, with a floor on how many are required.
///
/// Generalises "asset families". The cardinality is what stops an agent from
/// building one of something and calling the family done; [variationRule] is
/// what stops it from copy-pasting the same one N times.
@immutable
class ComponentFamily {
  const ComponentFamily({
    required this.id,
    required this.name,
    required this.description,
    this.minimumCount,
    this.members = const <String>[],
    this.variationRule,
  });

  final String id;
  final String name;
  final String description;

  /// Explicit floor. Null means "no numeric floor stated".
  final int? minimumCount;

  /// Named members the family must contain.
  final List<String> members;

  /// How instances must differ from one another.
  final String? variationRule;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    if (minimumCount != null) 'minimumCount': minimumCount,
    'members': members,
    if (variationRule != null) 'variationRule': variationRule,
  };

  static ComponentFamily fromJson(Map<String, Object?> j) => ComponentFamily(
    id: '${j['id']}',
    name: '${j['name']}',
    description: '${j['description'] ?? ''}',
    minimumCount: (j['minimumCount'] as num?)?.toInt(),
    members: _stringList(j['members']),
    variationRule: j['variationRule'] as String?,
  );
}

/// How a piece of evidence gets captured.
enum EvidenceKind {
  render,
  screenshot,
  testReport,
  logExcerpt,
  document,
  dataExtract,
  recording,
  other,
}

/// One numbered artifact the run must produce.
///
/// This is the generalisation of the reference brief's sixteen fixed cameras.
/// The essential property is not that it is an image — it is that the set is
/// *fixed in advance*, *numbered*, and *collectively proves coverage*, so the
/// review loop re-captures identical evidence every cycle and regressions are
/// visible by comparison.
@immutable
class EvidenceArtifact {
  const EvidenceArtifact({
    required this.ordinal,
    required this.name,
    required this.fileName,
    required this.proves,
    this.kind = EvidenceKind.render,
    this.acceptance,
    this.minimumSpec,
    this.isHero = false,
  });

  /// 1-based position in the fixed evidence set.
  final int ordinal;

  final String name;

  /// Exact output filename, so re-captures overwrite rather than accumulate.
  final String fileName;

  /// What this artifact is meant to demonstrate.
  final String proves;

  final EvidenceKind kind;

  /// The predicate a critic checks this artifact against.
  final String? acceptance;

  /// Resolution, sample count, duration — whatever "big enough" means here.
  final String? minimumSpec;

  /// The single most important view. Gets the strictest minimum spec and is the
  /// one re-captured during cold-start validation.
  final bool isHero;

  Map<String, Object?> toJson() => <String, Object?>{
    'ordinal': ordinal,
    'name': name,
    'fileName': fileName,
    'proves': proves,
    'kind': kind.name,
    if (acceptance != null) 'acceptance': acceptance,
    if (minimumSpec != null) 'minimumSpec': minimumSpec,
    'isHero': isHero,
  };

  static EvidenceArtifact fromJson(Map<String, Object?> j) => EvidenceArtifact(
    ordinal: (j['ordinal'] as num).toInt(),
    name: '${j['name']}',
    fileName: '${j['fileName']}',
    proves: '${j['proves'] ?? ''}',
    kind: _byName(EvidenceKind.values, j['kind'], EvidenceKind.other),
    acceptance: j['acceptance'] as String?,
    minimumSpec: j['minimumSpec'] as String?,
    isHero: j['isHero'] as bool? ?? false,
  );
}

/// One weighted line of the scoring rubric.
@immutable
class RubricCategory {
  const RubricCategory({
    required this.id,
    required this.name,
    required this.weight,
    required this.criteria,
    this.minimum,
  });

  final String id;
  final String name;

  /// Points out of the rubric total.
  final int weight;

  /// What is being judged.
  final String criteria;

  /// Per-category floor. A run can sit above the exit threshold overall and
  /// still fail because one category is below its minimum.
  final double? minimum;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'weight': weight,
    'criteria': criteria,
    if (minimum != null) 'minimum': minimum,
  };

  static RubricCategory fromJson(Map<String, Object?> j) => RubricCategory(
    id: '${j['id']}',
    name: '${j['name']}',
    weight: (j['weight'] as num).toInt(),
    criteria: '${j['criteria'] ?? ''}',
    minimum: (j['minimum'] as num?)?.toDouble(),
  );
}

/// The scoring contract for the run.
@immutable
class Rubric {
  const Rubric({
    required this.categories,
    this.exitThreshold = 90,
    this.total = 100,
  });

  final List<RubricCategory> categories;

  /// Score at or above which the run may exit the review loop.
  final int exitThreshold;

  /// Points the weights are expected to sum to.
  final int total;

  int get weightSum =>
      categories.fold<int>(0, (int a, RubricCategory c) => a + c.weight);

  /// True when the weights add up to [total]. The compiler refuses to emit an
  /// inconsistent rubric, because an agent scoring itself against weights that
  /// do not sum is scoring against nothing.
  bool get isBalanced => weightSum == total;

  Map<String, Object?> toJson() => <String, Object?>{
    'categories': categories.map((RubricCategory c) => c.toJson()).toList(),
    'exitThreshold': exitThreshold,
    'total': total,
  };

  static Rubric fromJson(Map<String, Object?> j) => Rubric(
    categories: (j['categories'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => RubricCategory.fromJson(e! as Map<String, Object?>))
        .toList(),
    exitThreshold: (j['exitThreshold'] as num?)?.toInt() ?? 90,
    total: (j['total'] as num?)?.toInt() ?? 100,
  );
}

/// A fresh-context reviewer with one job.
@immutable
class Critic {
  const Critic({
    required this.id,
    required this.name,
    required this.judges,
    this.freshContext = true,
  });

  final String id;
  final String name;

  /// The one-line brief: exactly what this critic is looking at.
  final String judges;

  /// Whether this critic must be spawned without the builder's context. Fresh
  /// context is the point — a critic that watched the build inherits its
  /// rationalisations.
  final bool freshContext;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'judges': judges,
    'freshContext': freshContext,
  };

  static Critic fromJson(Map<String, Object?> j) => Critic(
    id: '${j['id']}',
    name: '${j['name']}',
    judges: '${j['judges'] ?? ''}',
    freshContext: j['freshContext'] as bool? ?? true,
  );
}

/// One ordered stage of construction.
@immutable
class BuildStep {
  const BuildStep({
    required this.ordinal,
    required this.name,
    required this.instruction,
    this.producesEvidence = const <int>[],
  });

  final int ordinal;
  final String name;
  final String instruction;

  /// Ordinals from the evidence set this step is expected to make capturable.
  final List<int> producesEvidence;

  Map<String, Object?> toJson() => <String, Object?>{
    'ordinal': ordinal,
    'name': name,
    'instruction': instruction,
    'producesEvidence': producesEvidence,
  };

  static BuildStep fromJson(Map<String, Object?> j) => BuildStep(
    ordinal: (j['ordinal'] as num).toInt(),
    name: '${j['name']}',
    instruction: '${j['instruction'] ?? ''}',
    producesEvidence:
        (j['producesEvidence'] as List<Object?>? ?? const <Object?>[])
            .map((Object? e) => (e! as num).toInt())
            .toList(),
  );
}

/// A condition that makes the delivered artifact unacceptable.
@immutable
class FailureCondition {
  const FailureCondition({required this.text, this.severity = 'blocking'});

  final String text;
  final String severity;

  Map<String, Object?> toJson() => <String, Object?>{
    'text': text,
    'severity': severity,
  };

  static FailureCondition fromJson(Map<String, Object?> j) => FailureCondition(
    text: '${j['text']}',
    severity: '${j['severity'] ?? 'blocking'}',
  );
}
