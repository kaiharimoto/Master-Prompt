import 'package:meta/meta.dart';

import '../spec/mission_spec.dart';
import '../spec/spec_field.dart';
import '../spec/spec_sections.dart';
import '../spec/spec_types.dart';

/// The result of reading an `mpspec` patch out of a model reply.
@immutable
class SpecPatchResult {
  const SpecPatchResult({
    required this.spec,
    required this.applied,
    this.rejected = const <String>[],
    this.found = false,
    this.prose,
  });

  /// The spec with the patch applied.
  final MissionSpec spec;

  /// Human-readable list of what changed, shown to the user before they accept.
  final List<String> applied;

  /// Lines that could not be understood, kept so nothing vanishes silently.
  final List<String> rejected;

  /// Whether a patch block was present at all.
  final bool found;

  /// The reply with the patch removed — the conversational part.
  final String? prose;

  bool get hasChanges => applied.isNotEmpty;
}

/// Reads and applies `mpspec` patches.
///
/// The format is line-oriented for the same reason the state heartbeat is:
/// it travels through a chat UI and a clipboard, where JSON reliably acquires
/// smart quotes and reflowed lines. `key=value` sets a scalar; `key+=value`
/// appends to a list; fields within a value are separated by `|`.
///
/// Everything the model proposes lands as [FieldResolution.proposed], never
/// [FieldResolution.confirmed]. A required field is only satisfied once the
/// user accepts it. Without that rule an inferred requirement can reach an
/// unattended twelve-hour run without anyone having agreed to it.
class SpecPatchParser {
  const SpecPatchParser();

  static const String fenceTag = 'mpspec';

  SpecPatchResult parse(String reply, MissionSpec current) {
    final List<String> lines = reply.replaceAll('\r\n', '\n').split('\n');

    final RegExp open = RegExp(
      r'^[ \t]*(?:>[ \t]*)?```[ \t]*mp[-_]?spec[ \t]*$',
      caseSensitive: false,
    );
    final RegExp close = RegExp(r'^[ \t]*(?:>[ \t]*)?```[ \t]*$');

    int openAt = -1;
    for (int i = 0; i < lines.length; i++) {
      if (open.hasMatch(lines[i])) openAt = i;
    }

    List<String> body;
    String prose;
    if (openAt >= 0) {
      int closeAt = lines.length;
      for (int i = openAt + 1; i < lines.length; i++) {
        if (close.hasMatch(lines[i])) {
          closeAt = i;
          break;
        }
      }
      body = lines.sublist(openAt + 1, closeAt);
      prose = <String>[
        ...lines.sublist(0, openAt),
        if (closeAt < lines.length) ...lines.sublist(closeAt + 1),
      ].join('\n').trim();
    } else {
      return SpecPatchResult(
        spec: current,
        applied: const <String>[],
        prose: reply.trim(),
      );
    }

    return _apply(body, current, prose);
  }

  static final RegExp _line = RegExp(
    r'^[ \t]*(?:>[ \t]*)?(?:\*\*|__)?([a-zA-Z_][a-zA-Z0-9_]*)(?:\*\*|__)?[ \t]*(\+?=)[ \t]*(.*)$',
  );

  SpecPatchResult _apply(List<String> body, MissionSpec spec, String prose) {
    final List<String> applied = <String>[];
    final List<String> rejected = <String>[];

    final List<ScopeRegion> regions = <ScopeRegion>[...spec.regions];
    final List<String> relationships = <String>[...spec.relationships];
    final List<ComponentFamily> families = <ComponentFamily>[...spec.families];
    final List<EvidenceArtifact> evidence = <EvidenceArtifact>[
      ...spec.evidence,
    ];
    final List<BuildStep> steps = <BuildStep>[...spec.buildOrder];
    final List<RubricCategory> rubric = <RubricCategory>[
      ...spec.rubric.categories,
    ];
    final List<Critic> critics = <Critic>[...spec.review.critics];
    final List<FailureCondition> failures = <FailureCondition>[
      ...spec.failureConditions,
    ];
    final List<String> avoid = <String>[...spec.quality.avoid];
    final List<String> palette = <String>[...spec.quality.palette];
    final List<String> materials = <String>[...spec.quality.materials];
    final List<String> storytelling = <String>[...spec.quality.storytelling];
    final List<String> checks = <String>[...spec.validation.checks];

    MissionSpec out = spec;
    QualityLanguage q = spec.quality;
    RuntimeProfile rt = spec.runtime;
    ValidationPlan val = spec.validation;
    DeliverablePlan del = spec.deliverables;
    ReviewLoopSpec rev = spec.review;
    int exitThreshold = spec.rubric.exitThreshold;
    int rubricTotal = spec.rubric.total;

    for (final String raw in body) {
      if (raw.trim().isEmpty || raw.trim() == '```') continue;
      final RegExpMatch? m = _line.firstMatch(raw);
      if (m == null) {
        rejected.add(raw.trim());
        continue;
      }
      final String key = m.group(1)!.toLowerCase();
      final bool append = m.group(2) == '+=';
      final String value = m.group(3)!.trim();
      if (value.isEmpty) continue;

      final List<String> parts = value
          .split('|')
          .map((String s) => s.trim())
          .toList();

      switch (key) {
        case 'mission':
          out = out.copyWith(missionStatement: _proposed(value));
          applied.add('Mission statement set.');
        case 'story':
          out = out.copyWith(definingStory: _proposed(value));
          applied.add('Defining story set.');
        case 'scale':
          out = out.copyWith(scale: _proposed(value));
          applied.add('Scale set.');
        case 'audience':
          out = out.copyWith(audience: _proposed(value));
          applied.add('Audience set.');
        case 'title':
          out = out.copyWith(title: value);
          applied.add('Title set to "$value".');

        case 'region':
          regions.add(
            ScopeRegion(
              id: 'region_${regions.length + 1}',
              name: parts.first,
              purpose: parts.length > 1 ? parts[1] : '',
              requirements: parts.length > 2
                  ? parts.sublist(2).where((String s) => s.isNotEmpty).toList()
                  : const <String>[],
            ),
          );
          applied.add('Required part: ${parts.first}');

        case 'relationship':
          relationships.add(value);
          applied.add('Relationship recorded.');

        case 'family':
          families.add(
            ComponentFamily(
              id: 'family_${families.length + 1}',
              name: parts.first,
              description: parts.length > 1 ? parts[1] : '',
              minimumCount: _numberedOption(parts, 'min'),
              variationRule: _textOption(parts, 'vary'),
            ),
          );
          applied.add('Component family: ${parts.first}');

        case 'evidence':
          final int ordinal = parts.isNotEmpty
              ? (int.tryParse(parts.first) ?? evidence.length + 1)
              : evidence.length + 1;
          final bool hero = parts.any((String p) => p.toLowerCase() == 'hero');
          evidence.add(
            EvidenceArtifact(
              ordinal: ordinal,
              fileName: parts.length > 1 ? parts[1] : 'artifact_$ordinal',
              name: parts.length > 2 ? parts[2] : 'Artifact $ordinal',
              proves: parts.length > 3 ? parts[3] : '',
              minimumSpec: _textOption(parts, 'min'),
              isHero: hero,
            ),
          );
          applied.add(
            'Evidence ${_pad(ordinal)}: ${parts.length > 1 ? parts[1] : ''}',
          );

        case 'step':
          final int ordinal = int.tryParse(parts.first) ?? (steps.length + 1);
          steps.add(
            BuildStep(
              ordinal: ordinal,
              name: parts.length > 1 ? parts[1] : 'Step $ordinal',
              instruction: parts.length > 2 ? parts[2] : '',
            ),
          );
          applied.add('Build step ${_pad(ordinal)}.');

        case 'rubric':
          final int weight = parts.length > 1
              ? (int.tryParse(parts[1]) ?? 0)
              : 0;
          rubric.add(
            RubricCategory(
              id: 'r${rubric.length + 1}',
              name: parts.first,
              weight: weight,
              criteria: parts.length > 2 ? parts[2] : '',
              minimum: _decimalOption(parts, 'min'),
            ),
          );
          applied.add('Rubric category: ${parts.first} ($weight)');

        case 'exit':
          exitThreshold = int.tryParse(value) ?? exitThreshold;
          applied.add('Exit threshold set to $exitThreshold.');

        case 'total':
          rubricTotal = int.tryParse(value) ?? rubricTotal;
          applied.add('Rubric total set to $rubricTotal.');

        case 'critic':
          critics.add(
            Critic(
              id: 'c${critics.length + 1}',
              name: parts.first,
              judges: parts.length > 1 ? parts[1] : '',
            ),
          );
          applied.add('Critic: ${parts.first}');

        case 'cycles':
          rev = ReviewLoopSpec(
            minimumCycles: int.tryParse(value) ?? rev.minimumCycles,
            critics: rev.critics,
            evidenceRule: rev.evidenceRule,
            regressionPolicy: rev.regressionPolicy,
            plateauRule: rev.plateauRule,
          );
          applied.add('Minimum review cycles set to ${rev.minimumCycles}.');

        case 'failure':
          failures.add(FailureCondition(text: value));
          applied.add('Failure condition recorded.');

        case 'avoid':
          avoid.add(value);
          applied.add('Anti-goal: $value');
        case 'palette':
          palette.add(value);
          applied.add('Palette entry recorded.');
        case 'material':
          materials.add(value);
          applied.add('Material entry recorded.');
        case 'atmosphere':
          q = _quality(q, atmosphere: value);
          applied.add('Atmosphere set.');
        case 'detail':
          q = _quality(q, detailStandard: value);
          applied.add('Detail standard set.');
        case 'evidence_of_use':
        case 'storytelling':
          storytelling.add(value);
          applied.add('Evidence-of-use detail recorded.');

        case 'compute':
          rt = _runtime(rt, compute: value);
          applied.add('Compute environment set.');
        case 'tool':
          rt = _runtime(rt, primaryTool: value);
          applied.add('Primary tool set.');
        case 'harness':
          rt = _runtime(rt, harness: value);
          applied.add('Harness set.');
        case 'budget':
          rt = _runtime(rt, tokenBudget: value);
          applied.add('Budget set to $value.');
        case 'wallclock':
          rt = _runtime(rt, wallClock: value);
          applied.add('Wall-clock budget set.');

        case 'coldstart':
          val = ValidationPlan(
            coldStartProcedure: value,
            checks: val.checks,
            reportContract: val.reportContract,
          );
          applied.add('Cold-start procedure set.');
        case 'check':
          checks.add(value);
          applied.add('Validation check recorded.');

        case 'dir':
          del = DeliverablePlan(
            projectDirectory: value,
            tree: del.tree,
            namingRules: del.namingRules,
            portabilityRules: del.portabilityRules,
          );
          applied.add('Project directory set to $value.');
        case 'file':
          del = DeliverablePlan(
            projectDirectory: del.projectDirectory,
            tree: <String, String>{
              ...del.tree,
              parts.first: parts.length > 1 ? parts[1] : '',
            },
            namingRules: del.namingRules,
            portabilityRules: del.portabilityRules,
          );
          applied.add('Deliverable: ${parts.first}');

        default:
          rejected.add(raw.trim());
      }
      // `append` is accepted on every list key and ignored on scalars; the
      // distinction is documented for the model but must not cause a rejection
      // if it uses the wrong one.
      if (!append && _listKeys.contains(key)) continue;
    }

    out = out.copyWith(
      regions: regions,
      relationships: relationships,
      families: families,
      evidence: evidence
        ..sort(
          (EvidenceArtifact a, EvidenceArtifact b) =>
              a.ordinal.compareTo(b.ordinal),
        ),
      buildOrder: steps
        ..sort((BuildStep a, BuildStep b) => a.ordinal.compareTo(b.ordinal)),
      rubric: Rubric(
        categories: rubric,
        exitThreshold: exitThreshold,
        total: rubricTotal,
      ),
      review: ReviewLoopSpec(
        minimumCycles: rev.minimumCycles,
        critics: critics,
        evidenceRule: rev.evidenceRule,
        regressionPolicy: rev.regressionPolicy,
        plateauRule: rev.plateauRule,
      ),
      failureConditions: failures,
      quality: _quality(
        q,
        avoid: avoid,
        palette: palette,
        materials: materials,
        storytelling: storytelling,
      ),
      runtime: rt,
      validation: ValidationPlan(
        coldStartProcedure: val.coldStartProcedure,
        checks: checks,
        reportContract: val.reportContract,
      ),
      deliverables: del,
    );

    return SpecPatchResult(
      spec: out,
      applied: List<String>.unmodifiable(applied),
      rejected: List<String>.unmodifiable(rejected),
      found: true,
      prose: prose,
    );
  }

  static const Set<String> _listKeys = <String>{
    'region',
    'relationship',
    'family',
    'evidence',
    'step',
    'rubric',
    'critic',
    'failure',
    'avoid',
    'palette',
    'material',
    'check',
    'file',
    'storytelling',
    'evidence_of_use',
  };

  SpecField<String> _proposed(String v) => SpecField<String>(
    value: v,
    resolution: FieldResolution.proposed,
    provenance: FieldProvenance.model,
    updatedAt: DateTime.now().toUtc(),
  );

  QualityLanguage _quality(
    QualityLanguage q, {
    List<String>? palette,
    List<String>? materials,
    String? atmosphere,
    List<String>? compositionRules,
    String? detailStandard,
    List<String>? storytelling,
    List<String>? avoid,
  }) => QualityLanguage(
    palette: palette ?? q.palette,
    materials: materials ?? q.materials,
    atmosphere: atmosphere ?? q.atmosphere,
    compositionRules: compositionRules ?? q.compositionRules,
    detailStandard: detailStandard ?? q.detailStandard,
    storytelling: storytelling ?? q.storytelling,
    avoid: avoid ?? q.avoid,
  );

  RuntimeProfile _runtime(
    RuntimeProfile r, {
    String? compute,
    String? primaryTool,
    String? harness,
    String? tokenBudget,
    String? wallClock,
  }) => RuntimeProfile(
    compute: compute ?? r.compute,
    primaryTool: primaryTool ?? r.primaryTool,
    harness: harness ?? r.harness,
    startingAssets: r.startingAssets,
    tokenBudget: tokenBudget ?? r.tokenBudget,
    wallClock: wallClock ?? r.wallClock,
    autonomy: r.autonomy,
    subagentsRequired: r.subagentsRequired,
    constraints: r.constraints,
  );

  static int? _numberedOption(List<String> parts, String name) {
    final String? v = _textOption(parts, name);
    return v == null ? null : int.tryParse(v);
  }

  static double? _decimalOption(List<String> parts, String name) {
    final String? v = _textOption(parts, name);
    return v == null ? null : double.tryParse(v);
  }

  static String? _textOption(List<String> parts, String name) {
    for (final String p in parts) {
      final int eq = p.indexOf('=');
      if (eq > 0 && p.substring(0, eq).trim().toLowerCase() == name) {
        return p.substring(eq + 1).trim();
      }
    }
    return null;
  }

  static String _pad(int n) => n < 10 ? '0$n' : '$n';
}
