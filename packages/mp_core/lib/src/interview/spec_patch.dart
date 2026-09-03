import 'dart:convert';

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
    this.diagnostic,
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

  /// Why nothing could be read, when nothing could. Written to be shown to the
  /// user rather than logged: "it may have been cut off" is actionable,
  /// "parse failed" is not.
  final String? diagnostic;

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
    final String text = _normalise(reply);

    // The ladder exists because the one-tap path strips the delimiter. Tapping
    // copy on a fenced code block in a chat app copies the block's *contents*,
    // not the backticks — so the format's happy path arrives without the fence
    // the parser used to require, and a perfectly good reply was rejected.
    //
    // JSON first, because it is self-delimiting: `{...}` can be found by brace
    // matching with no fence at all, which fixes that structurally rather than
    // with more heuristics.
    final _Found? json = _locateJson(text);
    if (json != null) {
      final Object? decoded = _decodeLenient(json.body);
      if (decoded is Map<String, Object?>) {
        final List<String> unreadable = <String>[];
        final List<_Directive> ds = _jsonToDirectives(decoded, unreadable);
        if (ds.isNotEmpty) {
          return _apply(ds, current, json.prose, unreadable: unreadable);
        }
      }
    }

    // Then the line grammar, fenced or bare, for replies written the old way.
    final _Found? lines = _locateLines(text);
    if (lines != null) {
      final List<String> unreadable = <String>[];
      final List<_Directive> ds = _linesToDirectives(lines.body, unreadable);
      if (ds.isNotEmpty) {
        return _apply(ds, current, lines.prose, unreadable: unreadable);
      }
    }

    return SpecPatchResult(
      spec: current,
      applied: const <String>[],
      prose: reply.trim(),
      diagnostic: _diagnose(text),
    );
  }

  /// Why nothing could be read, in terms the user can act on.
  String _diagnose(String text) {
    if (text.trim().isEmpty) return 'Nothing was pasted.';
    if (text.contains('{')) {
      return 'There is a block that looks like JSON, but it could not be read. '
          'It may have been cut off part way — try copying it again.';
    }
    if (RegExp(r'^\s*\w+\s*=', multiLine: true).hasMatch(text)) {
      return 'There are lines that look like settings, but none used a name '
          'this app recognises.';
    }
    return 'No settled answers in that reply. If Claude asked you questions, '
        'answer them in the same chat and bring its next reply back.';
  }

  /// Straighten what a chat UI and a clipboard introduce, so a JSON decode is
  /// not defeated by a typographic quote.
  String _normalise(String input) => input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u200b', '')
      .replaceAll('\ufeff', '');

  // -- locating ------------------------------------------------------------

  /// Find a JSON object: inside a fence if there is one, otherwise anywhere.
  _Found? _locateJson(String text) {
    final List<String> lines = text.split('\n');
    final RegExp open = RegExp(
      r'^[ \t]*(?:>[ \t]*)?```[ \t]*(?:json|mp[-_]?spec)?[ \t]*$',
      caseSensitive: false,
    );
    final RegExp close = RegExp(r'^[ \t]*(?:>[ \t]*)?```[ \t]*$');

    for (int i = lines.length - 1; i >= 0; i--) {
      if (!open.hasMatch(lines[i])) continue;
      int closeAt = lines.length;
      for (int j = i + 1; j < lines.length; j++) {
        if (close.hasMatch(lines[j])) {
          closeAt = j;
          break;
        }
      }
      final String body = lines.sublist(i + 1, closeAt).join('\n');
      if (body.trimLeft().startsWith('{')) {
        return _Found(
          body: body,
          prose: <String>[
            ...lines.sublist(0, i),
            if (closeAt < lines.length) ...lines.sublist(closeAt + 1),
          ].join('\n').trim(),
        );
      }
    }

    // No usable fence. Brace-match instead — this is the case that matters,
    // because it is what the copy button produces.
    final int open1 = text.indexOf('{');
    if (open1 < 0) return null;
    final int close1 = _matchBrace(text, open1);
    if (close1 < 0) return null;
    return _Found(
      body: text.substring(open1, close1 + 1),
      prose: (text.substring(0, open1) + text.substring(close1 + 1)).trim(),
    );
  }

  /// Index of the `}` closing the `{` at [start], ignoring braces inside
  /// strings so a value containing one does not end the object early.
  static int _matchBrace(String s, int start) {
    int depth = 0;
    bool inString = false;
    bool escaped = false;
    for (int i = start; i < s.length; i++) {
      final String ch = s[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Strict decode first; then forgive the two mistakes a model actually makes.
  static Object? _decodeLenient(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      // Trailing commas, and `//` line comments that are not inside a string.
      final String cleaned = body
          .replaceAllMapped(RegExp(r',(\s*[}\]])'), (Match m) => m.group(1)!)
          .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
      try {
        return jsonDecode(cleaned);
      } on FormatException {
        return null;
      }
    }
  }

  /// Find `key=value` lines: inside a fence, or as a bare run.
  _Found? _locateLines(String text) {
    final List<String> lines = text.split('\n');
    final RegExp open = RegExp(
      r'^[ \t]*(?:>[ \t]*)?```[ \t]*mp[-_]?spec[ \t]*$',
      caseSensitive: false,
    );
    final RegExp close = RegExp(r'^[ \t]*(?:>[ \t]*)?```[ \t]*$');

    int openAt = -1;
    for (int i = 0; i < lines.length; i++) {
      if (open.hasMatch(lines[i])) openAt = i;
    }
    if (openAt >= 0) {
      int closeAt = lines.length;
      for (int i = openAt + 1; i < lines.length; i++) {
        if (close.hasMatch(lines[i])) {
          closeAt = i;
          break;
        }
      }
      return _Found(
        body: lines.sublist(openAt + 1, closeAt).join('\n'),
        prose: <String>[
          ...lines.sublist(0, openAt),
          if (closeAt < lines.length) ...lines.sublist(closeAt + 1),
        ].join('\n').trim(),
      );
    }

    // Bare run: keep only lines that name a key this app understands, so a
    // sentence containing an equals sign cannot masquerade as a patch.
    final List<String> kept = <String>[];
    final List<int> keptAt = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final RegExpMatch? m = _line.firstMatch(lines[i]);
      if (m == null) continue;
      if (!_knownKeys.contains(m.group(1)!.toLowerCase())) continue;
      kept.add(lines[i]);
      keptAt.add(i);
    }
    if (kept.length < 2) return null;
    final Set<int> used = keptAt.toSet();
    return _Found(
      body: kept.join('\n'),
      prose: <String>[
        for (int i = 0; i < lines.length; i++)
          if (!used.contains(i)) lines[i],
      ].join('\n').trim(),
    );
  }

  // -- front ends ----------------------------------------------------------

  List<_Directive> _linesToDirectives(String body, List<String> unreadable) {
    final List<_Directive> out = <_Directive>[];
    for (final String raw in body.split('\n')) {
      if (raw.trim().isEmpty || raw.trim() == '```') continue;
      final RegExpMatch? m = _line.firstMatch(raw);
      if (m == null) {
        unreadable.add(raw.trim());
        continue;
      }
      final String value = m.group(3)!.trim();
      if (value.isEmpty) continue;
      out.add(
        _Directive(
          key: m.group(1)!.toLowerCase(),
          append: m.group(2) == '+=',
          value: value,
          parts: value.split('|').map((String s) => s.trim()).toList(),
          source: raw.trim(),
        ),
      );
    }
    return out;
  }

  /// Turn the JSON shape into the same directives the line grammar produces,
  /// so there is exactly one applier to keep correct.
  List<_Directive> _jsonToDirectives(
    Map<String, Object?> json,
    List<String> unreadable,
  ) {
    final List<_Directive> out = <_Directive>[];

    void scalar(String key, Object? v) {
      if (v == null) return;
      final String s = '$v'.trim();
      if (s.isEmpty) return;
      out.add(_Directive(key: key, value: s, parts: <String>[s], source: key));
    }

    void strings(String key, Object? v) {
      if (v is! List) return;
      for (final Object? e in v) {
        final String s = '$e'.trim();
        if (s.isEmpty) continue;
        out.add(
          _Directive(
            key: key,
            append: true,
            value: s,
            parts: <String>[s],
            source: key,
          ),
        );
      }
    }

    void objects(
      String key,
      Object? v,
      List<String> Function(Map<String, Object?>) toParts,
    ) {
      if (v is! List) return;
      for (final Object? e in v) {
        if (e is! Map) {
          // A bare string where an object was expected still carries a name.
          final String s = '$e'.trim();
          if (s.isEmpty) continue;
          out.add(
            _Directive(
              key: key,
              append: true,
              value: s,
              parts: <String>[s],
              source: key,
            ),
          );
          continue;
        }
        final Map<String, Object?> m = <String, Object?>{
          for (final MapEntry<Object?, Object?> x in e.entries)
            '${x.key}': x.value,
        };
        final List<String> parts = toParts(
          m,
        ).where((String s) => s.isNotEmpty).toList();
        if (parts.isEmpty) continue;
        out.add(
          _Directive(
            key: key,
            append: true,
            value: parts.first,
            parts: parts,
            source: key,
          ),
        );
      }
    }

    String str(Map<String, Object?> m, List<String> names) {
      for (final String n in names) {
        final Object? v = m[n];
        if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
      }
      return '';
    }

    for (final MapEntry<String, Object?> e in json.entries) {
      final String k = e.key.toLowerCase();
      switch (k) {
        case 'mission':
        case 'story':
        case 'scale':
        case 'audience':
        case 'title':
        case 'atmosphere':
        case 'detail':
        case 'compute':
        case 'tool':
        case 'harness':
        case 'budget':
        case 'wallclock':
        case 'coldstart':
        case 'dir':
        case 'exit':
        case 'total':
        case 'cycles':
          scalar(k, e.value);

        case 'relationships':
        case 'relationship':
          strings('relationship', e.value);
        case 'avoid':
          strings('avoid', e.value);
        case 'palette':
          strings('palette', e.value);
        case 'materials':
        case 'material':
          strings('material', e.value);
        case 'storytelling':
          strings('storytelling', e.value);
        case 'failures':
        case 'failure':
          strings('failure', e.value);
        case 'checks':
        case 'check':
          strings('check', e.value);

        case 'regions':
        case 'region':
          objects(
            'region',
            e.value,
            (Map<String, Object?> m) => <String>[
              str(m, <String>['name', 'id']),
              str(m, <String>['purpose', 'description']),
              ...(m['requirements'] is List
                  ? (m['requirements']! as List<Object?>).map(
                      (Object? r) => '$r'.trim(),
                    )
                  : const <String>[]),
            ],
          );

        case 'families':
        case 'family':
          objects(
            'family',
            e.value,
            (Map<String, Object?> m) => <String>[
              str(m, <String>['name']),
              str(m, <String>['description', 'purpose']),
              if (m['min'] != null) 'min=${m['min']}',
              if (m['minimum'] != null) 'min=${m['minimum']}',
              if (str(m, <String>['vary', 'variation']).isNotEmpty)
                'vary=${str(m, <String>['vary', 'variation'])}',
            ],
          );

        case 'evidence':
        case 'artifacts':
          objects(
            'evidence',
            e.value,
            (Map<String, Object?> m) => <String>[
              '${m['ordinal'] ?? m['n'] ?? ''}',
              str(m, <String>['file', 'fileName', 'filename']),
              str(m, <String>['name', 'title']),
              str(m, <String>['proves', 'description']),
              if (m['hero'] == true) 'hero',
              if (str(m, <String>['min', 'minimum']).isNotEmpty)
                'min=${str(m, <String>['min', 'minimum'])}',
            ],
          );

        case 'steps':
        case 'step':
        case 'buildorder':
          objects(
            'step',
            e.value,
            (Map<String, Object?> m) => <String>[
              '${m['ordinal'] ?? m['n'] ?? ''}',
              str(m, <String>['name', 'title']),
              str(m, <String>['instruction', 'description']),
            ],
          );

        case 'rubric':
        case 'rubrics':
        case 'categories':
          objects(
            'rubric',
            e.value,
            (Map<String, Object?> m) => <String>[
              str(m, <String>['name', 'category']),
              '${m['weight'] ?? ''}',
              str(m, <String>['criteria', 'description']),
              if (m['min'] != null) 'min=${m['min']}',
              if (m['minimum'] != null) 'min=${m['minimum']}',
            ],
          );

        case 'critics':
        case 'critic':
          objects(
            'critic',
            e.value,
            (Map<String, Object?> m) => <String>[
              str(m, <String>['name', 'role']),
              str(m, <String>['judges', 'description', 'brief']),
            ],
          );

        case 'files':
          if (e.value is Map) {
            for (final MapEntry<Object?, Object?> f
                in (e.value! as Map<Object?, Object?>).entries) {
              out.add(
                _Directive(
                  key: 'file',
                  append: true,
                  value: '${f.key}',
                  parts: <String>['${f.key}', '${f.value}'],
                  source: 'files',
                ),
              );
            }
          }

        default:
          // Unknown keys are surfaced rather than dropped, the same as an
          // unreadable line.
          unreadable.add(e.key);
      }
    }
    return out;
  }

  /// Keys the bare-line recovery will accept, so prose cannot be mistaken for
  /// a patch.
  static const Set<String> _knownKeys = <String>{
    'mission',
    'story',
    'scale',
    'audience',
    'title',
    'region',
    'relationship',
    'family',
    'evidence',
    'step',
    'rubric',
    'exit',
    'total',
    'critic',
    'cycles',
    'failure',
    'avoid',
    'palette',
    'material',
    'atmosphere',
    'detail',
    'storytelling',
    'evidence_of_use',
    'compute',
    'tool',
    'harness',
    'budget',
    'wallclock',
    'coldstart',
    'check',
    'dir',
    'file',
  };

  static final RegExp _line = RegExp(
    r'^[ \t]*(?:>[ \t]*)?(?:\*\*|__)?([a-zA-Z_][a-zA-Z0-9_]*)(?:\*\*|__)?[ \t]*(\+?=)[ \t]*(.*)$',
  );

  SpecPatchResult _apply(
    List<_Directive> directives,
    MissionSpec spec,
    String prose, {
    List<String> unreadable = const <String>[],
  }) {
    final List<String> applied = <String>[];
    final List<String> rejected = <String>[...unreadable];

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

    for (final _Directive d in directives) {
      final String key = d.key;
      final bool append = d.append;
      final String value = d.value;
      final List<String> parts = d.parts;
      if (value.isEmpty && parts.isEmpty) continue;

      switch (key) {
        case 'mission':
          out = out.copyWith(missionStatement: _proposed(value));
          applied.add(_said('Mission statement', value));
        case 'story':
          out = out.copyWith(definingStory: _proposed(value));
          applied.add(_said('Defining story', value));
        case 'scale':
          out = out.copyWith(scale: _proposed(value));
          applied.add(_said('Scale', value));
        case 'audience':
          out = out.copyWith(audience: _proposed(value));
          applied.add(_said('Judged by', value));
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
          applied.add(_said('Relationship', value));

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
          applied.add(_said('Failure condition', value));

        case 'avoid':
          avoid.add(value);
          applied.add('Anti-goal: $value');
        case 'palette':
          palette.add(value);
          applied.add(_said('Palette', value));
        case 'material':
          materials.add(value);
          applied.add(_said('Material', value));
        case 'atmosphere':
          q = _quality(q, atmosphere: value);
          applied.add(_said('Atmosphere', value));
        case 'detail':
          q = _quality(q, detailStandard: value);
          applied.add(_said('Detail standard', value));
        case 'evidence_of_use':
        case 'storytelling':
          storytelling.add(value);
          applied.add(_said('Evidence of use', value));

        case 'compute':
          rt = _runtime(rt, compute: value);
          applied.add(_said('Compute', value));
        case 'tool':
          rt = _runtime(rt, primaryTool: value);
          applied.add(_said('Primary tool', value));
        case 'harness':
          rt = _runtime(rt, harness: value);
          applied.add(_said('Harness', value));
        case 'budget':
          rt = _runtime(rt, tokenBudget: value);
          applied.add('Budget set to $value.');
        case 'wallclock':
          rt = _runtime(rt, wallClock: value);
          applied.add(_said('Wall clock', value));

        case 'coldstart':
          val = ValidationPlan(
            coldStartProcedure: value,
            checks: val.checks,
            reportContract: val.reportContract,
          );
          applied.add(_said('Cold start', value));
        case 'check':
          checks.add(value);
          applied.add(_said('Validation check', value));

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
          rejected.add(d.source);
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

/// One instruction to change the spec, however it was expressed.
///
/// Both front ends produce these, so JSON and the line grammar share a single
/// applier rather than drifting apart.
@immutable
class _Directive {
  const _Directive({
    required this.key,
    required this.value,
    required this.parts,
    required this.source,
    this.append = false,
  });

  final String key;
  final bool append;

  /// The whole value, for keys that take one.
  final String value;

  /// The value split into fields, for keys that take several.
  final List<String> parts;

  /// What it looked like before parsing, for reporting what was not understood.
  final String source;
}

/// A located block and whatever surrounded it.
/// One line of "what changed", carrying the value rather than only its kind.
///
/// A red-team pass can propose eighty fixes at once, and thirty lines reading
/// "Failure condition recorded." answer the question no better than the count
/// did. Truncated, because these are read as a list and some values are a
/// paragraph.
String _said(String label, String value) {
  final String v = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (v.isEmpty) return '$label set.';
  return v.length <= 88 ? '$label: $v' : '$label: ${v.substring(0, 87)}…';
}

@immutable
class _Found {
  const _Found({required this.body, required this.prose});

  final String body;
  final String prose;
}
