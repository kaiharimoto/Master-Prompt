import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

import 'reference_spec.dart';

void main() {
  final MissionSpec spec = referenceSkylineSpec();
  final CompiledPrompt compiled = const PromptCompiler().compile(spec);
  const ResumeCapsuleBuilder builder = ResumeCapsuleBuilder();

  const MpState midRun = MpState(
    taskId: 'skyline-restaurant-bar',
    phase: MissionPhase.review,
    step: 'diagnosing backbar reflections',
    cycle: 3,
    score: 78,
    next: 'Re-render cameras 04 and 05 after fixing the backbar glow',
  );

  group('a capsule carries what a fresh chat must not re-derive', () {
    final ResumeCapsule c = builder.build(
      spec: spec,
      state: midRun,
      compiled: compiled,
      producedArtifacts: <String>[
        '01_lift_lobby_arrival.png',
        '03_restaurant_hero.png',
      ],
      openFindings: <String>['Stool contact shadows missing in 15'],
      completedSteps: <String>['Graybox complete', 'Asset families pass 1'],
    );

    test('tells the new session not to start over', () {
      expect(c.text, contains('Do not start over'));
      expect(c.text, contains('do not re-plan'));
      expect(c.text, contains('task-id: skyline-restaurant-bar'));
    });

    test('carries the current position and the single next action', () {
      expect(c.text, contains('review'));
      expect(c.text, contains('diagnosing backbar reflections'));
      expect(c.text, contains('Review cycle** — 3'));
      expect(c.text, contains('78'));
      expect(c.text, contains('The next action is:'));
      expect(c.text, contains('Re-render cameras 04 and 05'));
    });

    test('carries the rubric verbatim, never summarised', () {
      for (final RubricCategory cat in spec.rubric.categories) {
        expect(c.text, contains(cat.name));
        expect(c.text, contains(cat.criteria));
      }
      expect(c.text, contains('exit at 90'));
    });

    test('carries every failure condition', () {
      for (final FailureCondition f in spec.failureConditions) {
        expect(c.text, contains(f.text));
      }
    });

    test('carries the evidence ledger with what is already done', () {
      expect(c.text, contains('[x] `01_lift_lobby_arrival.png`'));
      expect(c.text, contains('[x] `03_restaurant_hero.png`'));
      expect(c.text, contains('[ ] `16_ceiling_and_reverse_audit.png`'));
      expect(c.text, contains('2 of 16 recorded as produced'));
    });

    test('carries open findings and completed steps', () {
      expect(c.text, contains('Stool contact shadows missing in 15'));
      expect(c.text, contains('Graybox complete'));
    });

    test('restates the heartbeat contract so the next cut is survivable', () {
      expect(c.text, contains('```mpstate'));
      expect(c.text, contains('task=skyline-restaurant-bar'));
    });

    test('wraps the inner fence in tildes so pasting cannot break it', () {
      // The capsule is itself pasted into a chat. A backtick fence around a
      // backtick fence terminates early and mangles the block.
      final int tilde = c.text.indexOf('~~~');
      final int inner = c.text.indexOf('```mpstate');
      expect(tilde, greaterThan(0));
      expect(inner, greaterThan(tilde));
      expect('~~~'.allMatches(c.text).length, 2);
    });
  });

  group('degradation drops content by priority, never by summarising', () {
    test('a tight budget steps down tiers rather than truncating', () {
      final ResumeCapsule tight = builder.build(
        spec: spec,
        state: midRun,
        compiled: compiled,
        tier: CapsuleTier.full,
        budget: 3500,
      );
      expect(tight.tier, CapsuleTier.minimal);
      expect(tight.droppedSections, isNotEmpty);
      // The invariants survive at every tier — that is the whole point.
      expect(tight.text, contains('exit at 90'));
      expect(tight.text, contains('The next action is:'));
      expect(tight.text, contains('```mpstate'));
      expect(tight.text, contains('Do not start over'));
    });

    test('full tier includes the domain brief, standard does not', () {
      final ResumeCapsule full = builder.build(
        spec: spec,
        state: midRun,
        compiled: compiled,
        tier: CapsuleTier.full,
        budget: 100000,
      );
      final ResumeCapsule std = builder.build(
        spec: spec,
        state: midRun,
        compiled: compiled,
        budget: 100000,
      );
      expect(full.text, contains('Required parts'));
      expect(full.text.length, greaterThan(std.text.length));
      expect(std.droppedSections, contains('full domain brief (section 07)'));
    });

    test('a capsule with no recorded state says so rather than inventing one', () {
      final ResumeCapsule none =
          builder.build(spec: spec, state: null, compiled: compiled);
      expect(none.text, contains('No state was recorded'));
      expect(none.text, contains('establish the current position'));
    });
  });

  group('chunking for chat apps with paste limits', () {
    test('short capsules are a single part', () {
      final ResumeCapsule c =
          builder.build(spec: spec, state: midRun, tier: CapsuleTier.minimal);
      expect(c.chunk(maxCharacters: 100000), hasLength(1));
    });

    test('long capsules split into labelled, self-sequencing parts', () {
      final ResumeCapsule c = builder.build(
        spec: spec,
        state: midRun,
        compiled: compiled,
        tier: CapsuleTier.full,
        budget: 100000,
      );
      final List<String> parts = c.chunk(maxCharacters: 3000);
      expect(parts.length, greaterThan(1));
      for (int i = 0; i < parts.length; i++) {
        expect(parts[i], contains('part ${i + 1} of ${parts.length}'));
      }
      // Every part but the last must tell the assistant to wait, or it will
      // start acting on half a mission.
      for (int i = 0; i < parts.length - 1; i++) {
        expect(parts[i], contains('Do not act yet'));
      }
      expect(parts.last, contains('This is the final part'));
      expect(parts.last, contains('continue the mission'));
    });
  });

  group('the capsule feeds back into the parser', () {
    test('a reply following the capsule template parses cleanly', () {
      final ResumeCapsule c = builder.build(spec: spec, state: midRun);
      // Simulate the assistant following the contract the capsule states.
      final String reply = 'Done. Re-rendered 04 and 05.\n\n'
          '```mpstate\n${midRun.copyWith(cycle: 4, score: 83).render()}\n```';
      final StateParseResult r = const StateParser()
          .parse(reply, expectedTaskId: c.taskId);
      expect(r.status, StateParseStatus.accepted);
      expect(r.state!.cycle, 4);
      expect(r.state!.score, 83);
    });
  });
}
