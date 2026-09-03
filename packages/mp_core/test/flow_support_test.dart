import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

void main() {
  group('every stage asks something a person can answer', () {
    test('each working stage has a distinct question', () {
      final Set<String> seen = <String>{};
      for (final InterviewStage s in InterviewStage.values) {
        expect(s.question, isNotEmpty, reason: '${s.name} has no question');
        expect(
          seen.add(s.question),
          isTrue,
          reason: '${s.name} repeats a question',
        );
      }
    });

    test('questions are short enough for the focal line', () {
      for (final InterviewStage s in InterviewStage.values) {
        // Anything longer stops being a question and becomes a paragraph, which
        // is the density problem this replaces.
        expect(s.question.length, lessThan(45), reason: s.name);
        expect(s.question, endsWith(s == InterviewStage.ready ? '.' : '?'));
      }
    });

    test('the step indicator counts stages, not requirements', () {
      // The point of the redesign: nine stages to walk, not twenty-one
      // checkboxes to stare at.
      expect(InterviewStage.stepCount, 9);
      expect(InterviewStage.seed.step, 1);
      expect(InterviewStage.acceptance.step, 9);
    });
  });

  group('accepting a round in one act', () {
    MissionSpec withProposals() =>
        const MissionSpec(
          id: 'x',
          taskId: 't',
          title: 'T',
          presetId: 'generic',
        ).copyWith(
          missionStatement: const SpecField<String>.empty().propose(
            'a mission',
          ),
          definingStory: const SpecField<String>.empty().propose('a story'),
        );

    test('proposed becomes confirmed, and the gate opens', () {
      final MissionSpec before = withProposals();
      expect(before.missionStatement.isSettled, isFalse);
      expect(before.proposedCount, 2);

      final MissionSpec after = before.confirmProposals();
      expect(after.missionStatement.resolution, FieldResolution.confirmed);
      expect(after.definingStory.resolution, FieldResolution.confirmed);
      expect(after.missionStatement.isSettled, isTrue);
      expect(after.proposedCount, 0);
      expect(after.missionStatement.value, 'a mission');
    });

    test('a waived field is left alone', () {
      // A waiver is a decision already made; re-confirming it would silently
      // erase the recorded reason for handing the choice to the agent.
      final MissionSpec s = withProposals().copyWith(
        scale: const SpecField<String>.empty().waive('the agent should decide'),
      );
      final MissionSpec after = s.confirmProposals();
      expect(after.scale.resolution, FieldResolution.waived);
      expect(after.scale.note, 'the agent should decide');
    });

    test('an unresolved field stays unresolved', () {
      final MissionSpec after = withProposals().confirmProposals();
      expect(after.audience.resolution, FieldResolution.unresolved);
      expect(after.audience.hasValue, isFalse);
    });

    test('confirming is idempotent', () {
      final MissionSpec once = withProposals().confirmProposals();
      final MissionSpec twice = once.confirmProposals();
      expect(twice.contentHash(), once.contentHash());
    });

    test('nothing proposed means nothing to accept', () {
      const MissionSpec blank = MissionSpec(
        id: 'x',
        taskId: 't',
        title: 'T',
        presetId: 'generic',
      );
      expect(blank.proposedCount, 0);
      expect(blank.confirmProposals().contentHash(), blank.contentHash());
    });
  });

  group('the flow walks the same stages the gate reports', () {
    test('a blank spec starts at the first stage', () {
      const MissionSpec blank = MissionSpec(
        id: 'x',
        taskId: 't',
        title: 'T',
        presetId: 'generic',
      );
      final ReadinessReport r = const ReadinessGate().evaluate(blank);
      expect(r.currentStage, InterviewStage.seed);
      expect(r.currentStage.question, 'What are you building?');
    });

    test('accepting a round can move the flow to the next stage', () {
      // The gate is the itinerary: settle a stage's items and it advances.
      MissionSpec s =
          const MissionSpec(
            id: 'x',
            taskId: 't',
            title: 'T',
            presetId: 'generic',
          ).copyWith(
            missionStatement: const SpecField<String>.empty().propose(
              'a mission',
            ),
          );
      expect(
        const ReadinessGate().evaluate(s).currentStage,
        InterviewStage.seed,
      );

      s = s.confirmProposals();
      expect(
        const ReadinessGate().evaluate(s).currentStage,
        InterviewStage.intent,
      );
    });
  });
}
