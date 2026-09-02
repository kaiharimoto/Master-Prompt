import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

import 'reference_spec.dart';

const MissionSpec blank = MissionSpec(
  id: 'x',
  taskId: 'new-thing',
  title: 'Untitled mission',
  presetId: 'generic',
);

void main() {
  const InterviewEngine engine = InterviewEngine();
  const ReadinessGate gate = ReadinessGate();
  const SpecPatchParser patcher = SpecPatchParser();

  group('the readiness gate blocks an incomplete brief', () {
    test('a blank spec cannot be compiled and says why', () {
      final ReadinessReport r = gate.evaluate(blank);
      expect(r.canCompile, isFalse);
      expect(r.blocking, isNotEmpty);
      expect(r.completion, lessThan(0.2));
      // Every gap explains the consequence, not just the omission.
      for (final ReadinessGap g in r.gaps) {
        expect(g.why, isNotEmpty);
        expect(g.label, isNotEmpty);
      }
    });

    test('the fully specified reference brief passes the gate', () {
      final ReadinessReport r = gate.evaluate(referenceSkylineSpec());
      expect(
        r.canCompile,
        isTrue,
        reason: 'blocking gaps: ${r.blocking.map((ReadinessGap g) => g.label)}',
      );
      expect(r.completion, 1.0);
      expect(r.currentStage, InterviewStage.ready);
    });

    test('an unbalanced rubric blocks compilation', () {
      final MissionSpec bad = referenceSkylineSpec().copyWith(
        rubric: const Rubric(
          categories: <RubricCategory>[
            RubricCategory(id: 'a', name: 'A', weight: 10, criteria: 'x'),
          ],
        ),
      );
      final ReadinessReport r = gate.evaluate(bad);
      expect(r.canCompile, isFalse);
      expect(
        r.blocking.any((ReadinessGap g) => g.label.contains('sum correctly')),
        isTrue,
      );
    });

    test('advisory gaps do not block', () {
      final MissionSpec s = referenceSkylineSpec().copyWith(
        relationships: const <String>[],
      );
      final ReadinessReport r = gate.evaluate(s);
      expect(r.canCompile, isTrue);
      expect(r.advisory, isNotEmpty);
    });
  });

  group('a model-proposed value never satisfies the gate on its own', () {
    test('proposed is not enough; confirmed is', () {
      const String reply =
          'Here is what I suggest.\n\n'
          '```mpspec\n'
          'mission=Build a rooftop bar environment.\n'
          '```';
      final SpecPatchResult r = patcher.parse(reply, blank);
      expect(r.found, isTrue);
      expect(r.spec.missionStatement.value, isNotNull);
      expect(r.spec.missionStatement.resolution, FieldResolution.proposed);
      expect(
        r.spec.missionStatement.isSettled,
        isFalse,
        reason:
            'a requirement inferred by the model must be accepted by a human '
            'before it can reach an unattended run',
      );

      final MissionSpec confirmed = r.spec.copyWith(
        missionStatement: r.spec.missionStatement.confirm(
          r.spec.missionStatement.value!,
        ),
      );
      expect(confirmed.missionStatement.isSettled, isTrue);
    });

    test('a waived field satisfies the gate and records the reason', () {
      final MissionSpec s = blank.copyWith(
        missionStatement: const SpecField<String>.empty().waive(
          'The agent should decide the framing.',
        ),
      );
      expect(s.missionStatement.isSettled, isTrue);
      expect(s.missionStatement.note, contains('agent should decide'));
    });
  });

  group('turns ask about what, before how', () {
    test('an empty spec starts at the beginning', () {
      final InterviewTurn t = engine.nextTurn(blank);
      expect(t.stage, InterviewStage.seed);
      expect(t.text, contains('two to four'));
      expect(t.text, contains('not how to build it'));
      expect(t.text, contains('```mpspec'));
      expect(t.gaps, isNotEmpty);
    });

    test('runtime is asked late, after the shape is settled', () {
      expect(
        InterviewStage.runtime.index,
        greaterThan(InterviewStage.shape.index),
      );
      expect(
        InterviewStage.runtime.index,
        greaterThan(InterviewStage.quality.index),
      );
    });

    test('the turn shows what is already settled so nothing is re-asked', () {
      final MissionSpec partial = blank.copyWith(
        missionStatement: const SpecField<String>.empty().confirm(
          'A rooftop bar.',
        ),
        audience: const SpecField<String>.empty().confirm('Architects.'),
        scale: const SpecField<String>.empty().confirm('1200 m2.'),
        definingStory: const SpecField<String>.empty().confirm(
          'Arrival to view.',
        ),
      );
      final InterviewTurn t = engine.nextTurn(partial);
      expect(t.text, contains('A rooftop bar.'));
      expect(t.text, contains('Do not ask about anything already settled'));
      expect(t.stage, InterviewStage.shape);
    });

    test('the patch grammar offered matches the stage being asked about', () {
      final InterviewTurn shape = engine.nextTurn(
        blank.copyWith(
          missionStatement: const SpecField<String>.empty().confirm('m'),
          audience: const SpecField<String>.empty().confirm('a'),
          scale: const SpecField<String>.empty().confirm('s'),
          definingStory: const SpecField<String>.empty().confirm('d'),
        ),
      );
      expect(shape.text, contains('region+='));
      expect(shape.text, contains('family+='));
      expect(shape.text, isNot(contains('rubric+=')));
    });

    test('a complete spec yields a ready summary, not another question', () {
      final InterviewTurn t = engine.nextTurn(referenceSkylineSpec());
      expect(t.stage, InterviewStage.ready);
      expect(t.text, contains('can be compiled'));
      expect(t.text, contains('16 evidence artifacts'));
      expect(t.text, isNot(contains('```mpspec')));
    });
  });

  group('the patch parser understands the whole grammar', () {
    test('builds a substantial spec from one patch', () {
      const String reply = '''
Good — here is what we settled.

```mpspec
mission=A rooftop restaurant and bar above a dense city at night.
story=Guests move from a compressed arrival toward panoramic windows.
scale=1200 square metres on one floor.
audience=Judged as premium architectural visualisation.
region+=Cocktail bar | Twenty seats with real service depth | backbar | ice well
region+=Open kitchen | Visible hot line and plating pass
relationship+=Kitchen circulation never crosses guest paths.
family+=Dining furniture | tables, chairs, banquettes | min=130 | vary=wear and setting state
avoid+=A generic hotel lounge
palette+=book-matched dark stone
atmosphere=Blue hour turning to night.
detail=Must survive close inspection of joins and hardware.
evidence+=01 | 01_arrival.png | Arrival | The compressed threshold | min=1920x1080
evidence+=03 | 03_hero.png | Hero | Bar, dining and city together | hero | min=2560x1440
tool=Blender via the command line
budget=100 million tokens
step+=01 | Direction | Turn the brief into an art bible
rubric+=Circulation | 40 | Arrival, covers, service routes | min=34
rubric+=Craft | 60 | Materials and construction | min=51
total=100
exit=90
cycles=4
critic+=Circulation critic | Guest arrival and clearances
failure+=Any required part built as a camera-facing shell.
coldstart=Reopen the file from a clean invocation and re-render the hero.
check+=All dependencies resolve.
dir=rooftop_bar
file+=renders/final/ | the numbered final image set
```
''';
      final SpecPatchResult r = patcher.parse(reply, blank);

      expect(r.found, isTrue);
      expect(r.rejected, isEmpty, reason: 'rejected: ${r.rejected}');
      expect(r.prose, contains('here is what we settled'));
      expect(r.prose, isNot(contains('mpspec')));

      final MissionSpec s = r.spec;
      expect(s.regions, hasLength(2));
      expect(s.regions.first.requirements, contains('backbar'));
      expect(s.relationships, hasLength(1));
      expect(s.families.single.minimumCount, 130);
      expect(s.families.single.variationRule, contains('wear'));
      expect(s.evidence, hasLength(2));
      expect(s.evidence.last.isHero, isTrue);
      expect(s.evidence.last.minimumSpec, '2560x1440');
      expect(s.rubric.categories, hasLength(2));
      expect(s.rubric.isBalanced, isTrue);
      expect(s.rubric.categories.first.minimum, 34);
      expect(s.rubric.exitThreshold, 90);
      expect(s.review.critics, hasLength(1));
      expect(s.review.minimumCycles, 4);
      expect(s.failureConditions, hasLength(1));
      expect(s.quality.avoid, hasLength(1));
      expect(s.quality.atmosphere, contains('Blue hour'));
      expect(s.runtime.primaryTool, contains('Blender'));
      expect(s.runtime.tokenBudget, '100 million tokens');
      expect(s.buildOrder, hasLength(1));
      expect(s.validation.checks, hasLength(1));
      expect(s.deliverables.projectDirectory, 'rooftop_bar');
      expect(s.deliverables.tree.containsKey('renders/final/'), isTrue);
      expect(r.applied.length, greaterThan(20));
    });

    test('patches accumulate across rounds rather than replacing', () {
      const String first = '```mpspec\nregion+=Bar | drinks\n```';
      const String second = '```mpspec\nregion+=Kitchen | food\n```';
      final SpecPatchResult a = patcher.parse(first, blank);
      final SpecPatchResult b = patcher.parse(second, a.spec);
      expect(b.spec.regions, hasLength(2));
      expect(
        b.spec.regions.map((ScopeRegion r) => r.name),
        containsAll(<String>['Bar', 'Kitchen']),
      );
    });

    test('unknown lines are surfaced, never silently dropped', () {
      const String reply =
          '```mpspec\nmission=fine\nnonsense_key=whatever\njust some prose\n```';
      final SpecPatchResult r = patcher.parse(reply, blank);
      expect(r.rejected, hasLength(2));
      expect(r.spec.missionStatement.value, 'fine');
    });

    test('a reply with no patch block changes nothing', () {
      final SpecPatchResult r = patcher.parse(
        'Just some questions for you.',
        blank,
      );
      expect(r.found, isFalse);
      expect(r.hasChanges, isFalse);
      expect(r.spec.contentHash(), blank.contentHash());
      expect(r.prose, 'Just some questions for you.');
    });

    test('tolerates markdown emphasis and blockquoting', () {
      const String reply =
          '> ```mpspec\n'
          '> **mission**=A bar\n'
          '> **region**+=Kitchen | food\n'
          '> ```';
      final SpecPatchResult r = patcher.parse(reply, blank);
      expect(r.spec.missionStatement.value, 'A bar');
      expect(r.spec.regions, hasLength(1));
    });
  });

  group('the red-team pass attacks the compiled brief', () {
    test('names the specific failure modes worth hunting', () {
      final MissionSpec spec = referenceSkylineSpec();
      final CompiledPrompt compiled = const PromptCompiler().compile(spec);
      final InterviewTurn t = engine.redTeamTurn(spec, compiled);

      expect(t.text, contains('Ambiguities'));
      expect(t.text, contains('Unmeasurable criteria'));
      expect(t.text, contains('Coverage holes'));
      expect(t.text, contains('Cheap escapes'));
      expect(t.text, contains('cannot ask questions'));
      expect(t.text, contains('Do not praise the brief'));
      // It must carry the actual brief, or there is nothing to attack.
      expect(t.text, contains('## 05 / RUBRIC'));
      expect(t.text, contains('```mpspec'));
    });
  });

  group('end to end: interview to compilable brief', () {
    test('a spec assembled purely from patches compiles cleanly', () {
      // Everything the reference brief contains, delivered as patch lines the
      // way a real conversation would produce them.
      final MissionSpec ref = referenceSkylineSpec();
      final StringBuffer p = StringBuffer('```mpspec\n')
        ..writeln('mission=${ref.missionStatement.value}')
        ..writeln('story=${ref.definingStory.value}')
        ..writeln('scale=${ref.scale.value}')
        ..writeln('audience=${ref.audience.value}')
        ..writeln('compute=${ref.runtime.compute}')
        ..writeln('harness=${ref.runtime.harness}')
        ..writeln('wallclock=${ref.runtime.wallClock}')
        ..writeln('tool=${ref.runtime.primaryTool}')
        ..writeln('budget=${ref.runtime.tokenBudget}')
        ..writeln('coldstart=${ref.validation.coldStartProcedure}')
        ..writeln('dir=${ref.deliverables.projectDirectory}')
        ..writeln('total=100')
        ..writeln('exit=90');
      for (final ScopeRegion r in ref.regions) {
        p.writeln('region+=${r.name} | ${r.purpose}');
      }
      for (final String r in ref.relationships) {
        p.writeln('relationship+=$r');
      }
      for (final ComponentFamily f in ref.families) {
        p.writeln(
          'family+=${f.name} | ${f.description}'
          '${f.minimumCount == null ? '' : ' | min=${f.minimumCount}'}',
        );
      }
      for (final EvidenceArtifact e in ref.evidence) {
        p.writeln(
          'evidence+=${e.ordinal} | ${e.fileName} | ${e.name} | ${e.proves}'
          '${e.isHero ? ' | hero' : ''}',
        );
      }
      for (final BuildStep b in ref.buildOrder) {
        p.writeln('step+=${b.ordinal} | ${b.name} | ${b.instruction}');
      }
      for (final RubricCategory c in ref.rubric.categories) {
        p.writeln('rubric+=${c.name} | ${c.weight} | ${c.criteria}');
      }
      for (final Critic c in ref.review.critics) {
        p.writeln('critic+=${c.name} | ${c.judges}');
      }
      for (final FailureCondition f in ref.failureConditions) {
        p.writeln('failure+=${f.text}');
      }
      for (final String a in ref.quality.avoid) {
        p.writeln('avoid+=$a');
      }
      for (final String c in ref.quality.palette) {
        p.writeln('palette+=$c');
      }
      for (final String m in ref.quality.materials) {
        p.writeln('material+=$m');
      }
      for (final String t in ref.quality.storytelling) {
        p.writeln('storytelling+=$t');
      }
      p
        ..writeln('atmosphere=${ref.quality.atmosphere}')
        ..writeln('detail=${ref.quality.detailStandard}');
      for (final String c in ref.validation.checks) {
        p.writeln('check+=$c');
      }
      p.writeln('```');

      final SpecPatchResult r = patcher.parse(p.toString(), blank);
      expect(r.rejected, isEmpty, reason: 'rejected: ${r.rejected}');

      // Promote the model's proposals the way a user accepting them would.
      MissionSpec s = r.spec;
      s = s.copyWith(
        missionStatement: s.missionStatement.confirm(s.missionStatement.value!),
        definingStory: s.definingStory.confirm(s.definingStory.value!),
        scale: s.scale.confirm(s.scale.value!),
        audience: s.audience.confirm(s.audience.value!),
      );

      final ReadinessReport report = gate.evaluate(s);
      expect(
        report.canCompile,
        isTrue,
        reason: 'blocking: ${report.blocking.map((ReadinessGap g) => g.label)}',
      );

      final CompiledPrompt out = const PromptCompiler().compile(s);
      expect(out.warnings, isEmpty, reason: '${out.warnings}');
      expect(out.body, contains('## 09 / FAILURE CONDITIONS'));
      expect(out.body, contains('16_ceiling_and_reverse_audit.png'));
      expect(out.characterCount, greaterThan(10000));
    });
  });
}
