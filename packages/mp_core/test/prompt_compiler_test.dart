import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

import 'reference_spec.dart';

void main() {
  group('PromptCompiler reproduces the reference brief', () {
    final MissionSpec spec = referenceSkylineSpec();
    final CompiledPrompt out = const PromptCompiler().compile(spec);
    final String body = out.body;

    test('emits every numbered section in order', () {
      const List<String> sections = <String>[
        '00 / RUNTIME',
        '01 / TASK',
        '02 / PROTOCOL',
        '03 / BUILD ORDER',
        '04 / REVIEW LOOP',
        '05 / RUBRIC',
        '06 / VALIDATION',
        '07 / BRIEF',
        '08 / DELIVERABLES',
        '09 / FAILURE CONDITIONS',
      ];
      int previous = -1;
      for (final String s in sections) {
        final int at = body.indexOf('## $s');
        expect(at, greaterThan(previous), reason: '$s missing or out of order');
        previous = at;
      }
      expect(out.sectionOffsets.keys, containsAll(sections));
    });

    test('carries the full 100-point rubric with a 90 exit threshold', () {
      expect(spec.rubric.isBalanced, isTrue,
          reason: 'reference rubric weights must sum to 100');
      expect(body, contains('Exit threshold — 90 / 100'));
      for (final RubricCategory c in spec.rubric.categories) {
        expect(body, contains(c.name));
        expect(body, contains(c.criteria));
      }
      // Per-category minimums must survive into the prompt; an agent scoring
      // itself without them can pass overall while a category is unbuilt.
      expect(body, contains('12.8'));
      expect(body, contains('17'));
      expect(body, contains('4.3'));
    });

    test('lists all sixteen evidence artifacts with their filenames', () {
      expect(spec.evidence, hasLength(16));
      for (final EvidenceArtifact e in spec.evidence) {
        expect(body, contains(e.fileName), reason: '${e.fileName} missing');
        expect(body, contains(e.proves));
      }
      expect(body, contains('the fixed judgeset'));
    });

    test('designates exactly one hero artifact at the higher minimum', () {
      final List<EvidenceArtifact> heroes =
          spec.evidence.where((EvidenceArtifact e) => e.isHero).toList();
      expect(heroes, hasLength(1));
      expect(heroes.single.fileName, '03_restaurant_hero.png');
      expect(body, contains('2560x1440'));
      expect(body, contains('This is the hero artifact.'));
      expect(spec.heroEvidence, same(heroes.single));
    });

    test('names all six fresh-context critics with their briefs', () {
      expect(spec.review.critics, hasLength(6));
      for (final Critic c in spec.review.critics) {
        expect(body, contains(c.name));
        expect(body, contains(c.judges));
      }
      expect(body, contains('fresh-context subagent'));
      expect(body, contains('never the build history'));
    });

    test('states the minimum review cycle count and the loop shape', () {
      expect(body, contains('at least **4 complete cycles**'));
      expect(body, contains('re-capture the identical set'));
      expect(body, contains('improved, unchanged, or regressed'));
      expect(body, contains('structural pass'));
    });

    test('carries every required zone and the relationships between them', () {
      for (final ScopeRegion r in spec.regions) {
        expect(body, contains(r.name));
        expect(body, contains(r.purpose));
      }
      expect(body, contains('No required part may exist only as a label.'));
      for (final String rel in spec.relationships) {
        expect(body, contains(rel));
      }
    });

    test('carries component family minimum counts', () {
      expect(body, contains('At least 130.'));
      expect(body, contains('At least 500.'));
    });

    test('carries the avoid list and every failure condition', () {
      for (final String a in spec.quality.avoid) {
        expect(body, contains(a));
      }
      expect(spec.failureConditions, hasLength(11));
      for (final FailureCondition f in spec.failureConditions) {
        expect(body, contains(f.text));
      }
    });

    test('mandates the working documents and the resume clause', () {
      expect(body, contains('TASK_STATE.md'));
      expect(body, contains('checkpoints/'));
      expect(body, contains('If context is compacted or work resumes later'));
      expect(body, contains('continue from the recorded next action'));
    });

    test('mandates the mpstate heartbeat on every reply', () {
      expect(body, contains('```mpstate'));
      expect(body, contains('task=skyline-restaurant-bar'));
      expect(body, contains('next=<the single next action>'));
    });

    test('states the autonomy protocol that makes the run unattended', () {
      expect(body, contains('Do not answer with only a plan'));
      expect(body, contains('The user may be unavailable.'));
      expect(body, contains('Stop only for credentials'));
      expect(body, contains('not merely until the first working result exists'));
    });

    test('requires cold-start validation and an honest final report', () {
      expect(body, contains('reopened'));
      expect(body, contains('skyline_restaurant_bar_final.blend'));
      expect(body, contains('remaining non-critical limitations honestly'));
    });

    test('produces a complete brief with no compiler warnings', () {
      expect(
        out.warnings,
        isEmpty,
        reason: 'reference spec should compile cleanly, got: ${out.warnings}',
      );
    });

    test('is substantial — a real brief, not a summary', () {
      // The reference PDF is ~24k characters of prose across 15 pages.
      expect(out.characterCount, greaterThan(12000));
      expect(out.estimatedTokens, greaterThan(3000));
    });
  });

  group('determinism and identity', () {
    test('the same spec compiles to byte-identical output', () {
      final MissionSpec spec = referenceSkylineSpec();
      final CompiledPrompt a = const PromptCompiler().compile(spec);
      final CompiledPrompt b = const PromptCompiler().compile(spec);
      expect(a.body, b.body);
      expect(a.hash, b.hash);
    });

    test('the paste profile differs from the cli profile', () {
      final MissionSpec spec = referenceSkylineSpec();
      final CompiledPrompt cli =
          const PromptCompiler().compile(spec, profile: TransportProfile.cli);
      final CompiledPrompt paste =
          const PromptCompiler().compile(spec, profile: TransportProfile.paste);
      expect(cli.hash, isNot(paste.hash));
      expect(paste.body, contains('no tool access and no filesystem'));
      expect(cli.body, isNot(contains('no tool access and no filesystem')));
    });

    test('spec content hash ignores timestamps but tracks content', () {
      final MissionSpec a = referenceSkylineSpec();
      final MissionSpec b = referenceSkylineSpec()
          .copyWith(updatedAt: DateTime.utc(2030));
      expect(a.contentHash(), b.contentHash());

      final MissionSpec changed = a.copyWith(title: 'Something else');
      expect(changed.contentHash(), isNot(a.contentHash()));
    });

    test('spec survives a JSON round trip', () {
      final MissionSpec a = referenceSkylineSpec();
      final MissionSpec b = MissionSpec.fromJson(a.toJson());
      expect(b.contentHash(), a.contentHash());
      expect(b.evidence, hasLength(16));
      expect(b.rubric.categories, hasLength(7));
      expect(b.review.critics, hasLength(6));
    });

    test('sections can be extracted individually for capsule assembly', () {
      final CompiledPrompt out =
          const PromptCompiler().compile(referenceSkylineSpec());
      final String? rubric = out.section('05 / RUBRIC');
      expect(rubric, isNotNull);
      expect(rubric, contains('Exit threshold'));
      expect(rubric, isNot(contains('## 06 / VALIDATION')));
    });
  });

  group('the compiler warns about what would stall an unattended run', () {
    test('flags a missing rubric, evidence set, critics and failure list', () {
      const MissionSpec bare = MissionSpec(
        id: 'x',
        taskId: 'bare',
        title: 'Bare',
        presetId: 'generic',
      );
      final CompiledPrompt out = const PromptCompiler().compile(bare);
      final String sections =
          out.warnings.map((CompileWarning w) => w.section).join(' ');
      expect(sections, contains('05 / RUBRIC'));
      expect(sections, contains('08 / DELIVERABLES'));
      expect(sections, contains('04 / REVIEW LOOP'));
      expect(sections, contains('09 / FAILURE CONDITIONS'));
      expect(sections, contains('07 / BRIEF'));
    });

    test('flags an unbalanced rubric rather than emitting it silently', () {
      final MissionSpec spec = referenceSkylineSpec().copyWith(
        rubric: const Rubric(
          categories: <RubricCategory>[
            RubricCategory(id: 'a', name: 'A', weight: 40, criteria: 'x'),
            RubricCategory(id: 'b', name: 'B', weight: 30, criteria: 'y'),
          ],
        ),
      );
      final CompiledPrompt out = const PromptCompiler().compile(spec);
      expect(
        out.warnings.any((CompileWarning w) => w.message.contains('sum to 70')),
        isTrue,
      );
    });
  });
}
