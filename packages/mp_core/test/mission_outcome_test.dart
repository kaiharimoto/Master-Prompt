import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

MissionSpec specWith({
  int evidence = 3,
  int exitThreshold = 90,
  int minimumCycles = 4,
  int critics = 2,
}) => MissionSpec(
  id: 'p',
  taskId: 'cocktail_bar',
  title: 'Cocktail bar',
  presetId: 'generic',
  evidence: <EvidenceArtifact>[
    for (int i = 1; i <= evidence; i++)
      EvidenceArtifact(
        ordinal: i,
        name: 'Shot $i',
        fileName: '0$i.png',
        proves: 'coverage',
      ),
  ],
  review: ReviewLoopSpec(
    minimumCycles: minimumCycles,
    critics: <Critic>[
      for (int i = 0; i < critics; i++)
        Critic(id: 'c$i', name: 'Critic $i', judges: 'whether it holds up'),
    ],
  ),
  rubric: Rubric(
    categories: const <RubricCategory>[
      RubricCategory(
        id: 'craft',
        name: 'Craft',
        weight: 100,
        criteria: 'Holds up at 4K.',
      ),
    ],
    exitThreshold: exitThreshold,
  ),
);

MpState said({double score = 61, int cycle = 1}) =>
    MpState(taskId: 'cocktail_bar', score: score, cycle: cycle);

void main() {
  group('finished is not the same as done', () {
    test('a run that met every gate says so', () {
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(),
        filesPresent: <String>{
          '01.png',
          '02.png',
          '03.png',
          ...MissionCheck.directiveFiles,
        },
        reported: said(score: 93, cycle: 4),
        criticsSeen: 2,
      );

      expect(o.met, isTrue);
      expect(o.shortfalls, isEmpty);
    });

    test('a green run that produced a third of the artifacts is not done', () {
      // The case the screen used to hide entirely: the supervisor's
      // `completed` means the process exited zero and the CLI said `success`.
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(),
        filesPresent: <String>{'01.png', ...MissionCheck.directiveFiles},
        reported: said(score: 93, cycle: 4),
        criticsSeen: 2,
      );

      expect(o.met, isFalse);
      expect(o.missing, <String>['02.png', '03.png']);
      expect(o.shortfalls.first.detail, contains('02.png'));
    });

    test('scoring below the exit threshold is a shortfall, and says the '
        'numbers', () {
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(),
        filesPresent: <String>{
          '01.png',
          '02.png',
          '03.png',
          ...MissionCheck.directiveFiles,
        },
        reported: said(score: 61, cycle: 4),
        criticsSeen: 2,
      );

      expect(o.scoreMet, isFalse);
      expect(o.met, isFalse);
      expect(o.shortfalls.single.what, contains('61'));
      expect(o.shortfalls.single.what, contains('90'));
    });

    test('a run that never reported a score cannot be called done', () {
      // Unknown is not the same as failed, and it is not the same as passed
      // either. Nothing checked the threshold, so nothing may claim it.
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(),
        filesPresent: <String>{
          '01.png',
          '02.png',
          '03.png',
          ...MissionCheck.directiveFiles,
        },
        criticsSeen: 2,
      );

      expect(o.scoreMet, isNull);
      expect(o.met, isFalse);
      expect(o.shortfalls.first.what, contains('never reported a score'));
    });

    test('a review loop that ran once of four is counted', () {
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(),
        filesPresent: <String>{
          '01.png',
          '02.png',
          '03.png',
          ...MissionCheck.directiveFiles,
        },
        reported: said(score: 93, cycle: 1),
        criticsSeen: 2,
      );

      expect(o.cyclesMet, isFalse);
      expect(o.shortfalls.single.what, contains('1 review cycles of 4'));
    });

    test('an empty file is not a produced artifact', () {
      // A zero-byte render is the shape a crashed export leaves behind, and
      // counting it would make the check worse than nothing.
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(evidence: 1),
        // The caller filters by length; this is the contract that says so.
        filesPresent: const <String>{},
        reported: said(score: 93, cycle: 4),
        criticsSeen: 2,
      );
      expect(o.missing, <String>['01.png']);
    });

    test('a review nobody independent did is a shortfall', () {
      // The brief names critics and asks for a fresh context per critic — one
      // that reviews from a context that never built the thing. `isSubagent`
      // has always distinguished that traffic and was used only to keep it out
      // of the log, so a review that never happened looked like one that did.
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(critics: 3),
        filesPresent: <String>{
          '01.png',
          '02.png',
          '03.png',
          ...MissionCheck.directiveFiles,
        },
        reported: said(score: 93, cycle: 4),
      );

      expect(o.criticsMet, isFalse);
      expect(o.met, isFalse);
      expect(o.shortfalls.single.what, contains('No fresh-context critic'));
    });

    test('the working files the brief asks for are checked', () {
      // DIRECTION.md and TASK_STATE.md are what a resumed session is told to
      // re-read, so their absence is also the resume being hollow.
      final MissionOutcome o = MissionCheck.inspect(
        spec: specWith(),
        filesPresent: <String>{
          '01.png',
          '02.png',
          '03.png',
          'DIRECTION.md',
          'PLAN.md',
        },
        reported: said(score: 93, cycle: 4),
        criticsSeen: 2,
      );

      expect(o.directivesMet, isFalse);
      expect(o.shortfalls.single.detail, contains('TASK_STATE.md'));
      expect(o.shortfalls.single.detail, contains('INVENTORY.md'));
    });

    test('a mission with no gates is not judged', () {
      // Not every mission fixes an evidence set or a rubric. Inventing a
      // verdict for one that did not ask for one is its own kind of wrong.
      final MissionOutcome o = MissionCheck.inspect(
        spec: MissionSpec(
          id: 'p',
          taskId: 't',
          title: 'T',
          presetId: 'generic',
          review: const ReviewLoopSpec(minimumCycles: 0, critics: <Critic>[]),
          rubric: const Rubric(categories: <RubricCategory>[]),
        ),
        filesPresent: const <String>{},
      );

      expect(o.hasGates, isFalse);
    });
  });
}
