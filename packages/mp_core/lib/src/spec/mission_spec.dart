import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'spec_field.dart';
import 'spec_sections.dart';
import 'spec_types.dart';

/// The complete, typed description of a mission, filled in by the interview and
/// compiled into a master prompt.
///
/// Everything the compiler needs lives here. Nothing about *how* the prompt is
/// worded lives here — that is the compiler's business, so the same spec can be
/// rendered differently for the CLI transport and the copy-paste transport.
@immutable
class MissionSpec {
  const MissionSpec({
    required this.id,
    required this.taskId,
    required this.title,
    required this.presetId,
    this.schemaVersion = 1,
    this.missionStatement = const SpecField<String>.empty(),
    this.definingStory = const SpecField<String>.empty(),
    this.scale = const SpecField<String>.empty(),
    this.audience = const SpecField<String>.empty(),
    this.runtime = const RuntimeProfile(),
    this.regions = const <ScopeRegion>[],
    this.relationships = const <String>[],
    this.families = const <ComponentFamily>[],
    this.evidence = const <EvidenceArtifact>[],
    this.quality = const QualityLanguage(),
    this.buildOrder = const <BuildStep>[],
    this.review = const ReviewLoopSpec(),
    this.rubric = const Rubric(categories: <RubricCategory>[]),
    this.validation = const ValidationPlan(),
    this.deliverables = const DeliverablePlan(),
    this.failureConditions = const <FailureCondition>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Short kebab-case identifier used for directories and state files.
  final String taskId;

  final String title;

  /// Which domain preset seeded this spec.
  final String presetId;

  final int schemaVersion;

  // ---- Section 01 / TASK -------------------------------------------------
  /// One paragraph: what is being built and what makes it succeed.
  final SpecField<String> missionStatement;

  /// The through-line a viewer or user should experience.
  final SpecField<String> definingStory;

  /// Size, extent, or scope in concrete units.
  final SpecField<String> scale;

  /// Who judges the result, and by what standard.
  final SpecField<String> audience;

  // ---- Sections 00 and 07 ------------------------------------------------
  final RuntimeProfile runtime;
  final List<ScopeRegion> regions;

  /// Rules the regions must obey relative to one another.
  final List<String> relationships;

  final List<ComponentFamily> families;
  final List<EvidenceArtifact> evidence;
  final QualityLanguage quality;

  // ---- Sections 03 to 06 -------------------------------------------------
  final List<BuildStep> buildOrder;
  final ReviewLoopSpec review;
  final Rubric rubric;
  final ValidationPlan validation;

  // ---- Sections 08 and 09 ------------------------------------------------
  final DeliverablePlan deliverables;
  final List<FailureCondition> failureConditions;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The hero evidence artifact, if one is designated.
  EvidenceArtifact? get heroEvidence {
    for (final EvidenceArtifact e in evidence) {
      if (e.isHero) return e;
    }
    return evidence.isEmpty ? null : evidence.first;
  }

  MissionSpec copyWith({
    String? title,
    String? presetId,
    SpecField<String>? missionStatement,
    SpecField<String>? definingStory,
    SpecField<String>? scale,
    SpecField<String>? audience,
    RuntimeProfile? runtime,
    List<ScopeRegion>? regions,
    List<String>? relationships,
    List<ComponentFamily>? families,
    List<EvidenceArtifact>? evidence,
    QualityLanguage? quality,
    List<BuildStep>? buildOrder,
    ReviewLoopSpec? review,
    Rubric? rubric,
    ValidationPlan? validation,
    DeliverablePlan? deliverables,
    List<FailureCondition>? failureConditions,
    DateTime? updatedAt,
  }) => MissionSpec(
    id: id,
    taskId: taskId,
    title: title ?? this.title,
    presetId: presetId ?? this.presetId,
    schemaVersion: schemaVersion,
    missionStatement: missionStatement ?? this.missionStatement,
    definingStory: definingStory ?? this.definingStory,
    scale: scale ?? this.scale,
    audience: audience ?? this.audience,
    runtime: runtime ?? this.runtime,
    regions: regions ?? this.regions,
    relationships: relationships ?? this.relationships,
    families: families ?? this.families,
    evidence: evidence ?? this.evidence,
    quality: quality ?? this.quality,
    buildOrder: buildOrder ?? this.buildOrder,
    review: review ?? this.review,
    rubric: rubric ?? this.rubric,
    validation: validation ?? this.validation,
    deliverables: deliverables ?? this.deliverables,
    failureConditions: failureConditions ?? this.failureConditions,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'id': id,
    'taskId': taskId,
    'title': title,
    'presetId': presetId,
    'missionStatement': missionStatement.toJson((String v) => v),
    'definingStory': definingStory.toJson((String v) => v),
    'scale': scale.toJson((String v) => v),
    'audience': audience.toJson((String v) => v),
    'runtime': runtime.toJson(),
    'regions': regions.map((ScopeRegion r) => r.toJson()).toList(),
    'relationships': relationships,
    'families': families.map((ComponentFamily f) => f.toJson()).toList(),
    'evidence': evidence.map((EvidenceArtifact e) => e.toJson()).toList(),
    'quality': quality.toJson(),
    'buildOrder': buildOrder.map((BuildStep s) => s.toJson()).toList(),
    'review': review.toJson(),
    'rubric': rubric.toJson(),
    'validation': validation.toJson(),
    'deliverables': deliverables.toJson(),
    'failureConditions': failureConditions
        .map((FailureCondition f) => f.toJson())
        .toList(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  static MissionSpec fromJson(Map<String, Object?> j) => MissionSpec(
    id: '${j['id']}',
    taskId: '${j['taskId']}',
    title: '${j['title']}',
    presetId: '${j['presetId'] ?? 'generic'}',
    schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
    missionStatement: SpecField.fromJson<String>(
      j['missionStatement'] as Map<String, Object?>?,
      (Object? v) => '$v',
    ),
    definingStory: SpecField.fromJson<String>(
      j['definingStory'] as Map<String, Object?>?,
      (Object? v) => '$v',
    ),
    scale: SpecField.fromJson<String>(
      j['scale'] as Map<String, Object?>?,
      (Object? v) => '$v',
    ),
    audience: SpecField.fromJson<String>(
      j['audience'] as Map<String, Object?>?,
      (Object? v) => '$v',
    ),
    runtime: RuntimeProfile.fromJson(
      j['runtime'] as Map<String, Object?>? ?? const <String, Object?>{},
    ),
    regions: (j['regions'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => ScopeRegion.fromJson(e! as Map<String, Object?>))
        .toList(),
    relationships: (j['relationships'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList(),
    families: (j['families'] as List<Object?>? ?? const <Object?>[])
        .map(
          (Object? e) => ComponentFamily.fromJson(e! as Map<String, Object?>),
        )
        .toList(),
    evidence: (j['evidence'] as List<Object?>? ?? const <Object?>[])
        .map(
          (Object? e) => EvidenceArtifact.fromJson(e! as Map<String, Object?>),
        )
        .toList(),
    quality: QualityLanguage.fromJson(
      j['quality'] as Map<String, Object?>? ?? const <String, Object?>{},
    ),
    buildOrder: (j['buildOrder'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => BuildStep.fromJson(e! as Map<String, Object?>))
        .toList(),
    review: ReviewLoopSpec.fromJson(
      j['review'] as Map<String, Object?>? ?? const <String, Object?>{},
    ),
    rubric: Rubric.fromJson(
      j['rubric'] as Map<String, Object?>? ?? const <String, Object?>{},
    ),
    validation: ValidationPlan.fromJson(
      j['validation'] as Map<String, Object?>? ?? const <String, Object?>{},
    ),
    deliverables: DeliverablePlan.fromJson(
      j['deliverables'] as Map<String, Object?>? ?? const <String, Object?>{},
    ),
    failureConditions:
        (j['failureConditions'] as List<Object?>? ?? const <Object?>[])
            .map(
              (Object? e) =>
                  FailureCondition.fromJson(e! as Map<String, Object?>),
            )
            .toList(),
    createdAt: j['createdAt'] == null
        ? null
        : DateTime.tryParse('${j['createdAt']}'),
    updatedAt: j['updatedAt'] == null
        ? null
        : DateTime.tryParse('${j['updatedAt']}'),
  );

  /// Stable content hash, used to tell whether a compiled prompt is still
  /// current and to key the bundle manifest. Timestamps are excluded so that
  /// merely reopening a spec does not invalidate its compiled output.
  String contentHash() {
    final Map<String, Object?> j = toJson()
      ..remove('createdAt')
      ..remove('updatedAt');
    return sha256
        .convert(utf8.encode(_canonical(j)))
        .toString()
        .substring(0, 16);
  }

  static String _canonical(Object? value) {
    if (value is Map) {
      final List<String> keys = value.keys.map((Object? k) => '$k').toList()
        ..sort();
      return '{${keys.map((String k) => '"$k":${_canonical(value[k])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonical).join(',')}]';
    }
    return jsonEncode(value);
  }
}
