import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

const String task = 'skyline-restaurant-bar';

String beat({
  String phase = 'build',
  String score = '61',
  String next = 'Light the backbar',
  String blocked = 'none',
  String ask = 'none',
}) =>
    '```mpstate\n'
    'v=1\n'
    'task=$task\n'
    'phase=$phase\n'
    'step=working\n'
    'cycle=1\n'
    'score=$score\n'
    'next=$next\n'
    'blocked=$blocked\n'
    'ask=$ask\n'
    '```';

void main() {
  group('reading a run that reports on itself', () {
    test('takes the heartbeat out of an ordinary reply', () {
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task);

      expect(h.read('Rendering camera 04.'), isNull);
      final MpState? s = h.read('Done.\n\n${beat(score: '61')}');

      expect(s, isNotNull);
      expect(s!.score, 61);
      expect(h.state!.phase, MissionPhase.build);
    });

    test('a block finished in the next message is still read', () {
      // The reason this reads a rolling tail rather than one message. A
      // heartbeat lost to a message boundary is indistinguishable from a model
      // that never sent one, and the difference matters: one is a formatting
      // problem and the other is a run going quiet.
      //
      // The chunks are whole messages and are joined with a newline between
      // them, which is what stops the end of one message being glued to the
      // start of the next into a line neither of them wrote.
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task);

      expect(h.read('Done.\n\n```mpstate\nv=1\ntask=$task'), isNull);
      expect(h.read('phase=build\nscore=44\nnext=Keep going\n```'), isNotNull);
      expect(h.state!.score, 44);
    });

    test('the same block is not read twice', () {
      // Without clearing the tail, a run that stopped reporting would go on
      // looking healthy from the last thing it said, on every chunk, forever.
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task);

      expect(h.read(beat(score: '61')), isNotNull);
      expect(
        h.read('Still working on the glassware.'),
        isNull,
        reason: 'prose after a heartbeat is not another heartbeat',
      );
      expect(h.state!.score, 61, reason: 'the last one still stands');
    });

    test('a newer heartbeat replaces an older one', () {
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task);
      h.read(beat(score: '61'));
      h.read(beat(score: '86', phase: 'validation'));

      expect(h.state!.score, 86);
      expect(h.state!.phase, MissionPhase.validation);
    });

    test('a block for another mission is refused', () {
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task);
      expect(
        h.read(
          '```mpstate\nv=1\ntask=some-other-thing\nphase=build\n'
          'score=99\nnext=x\n```',
        ),
        isNull,
        reason:
            'two missions can run from one machine, and adopting the wrong '
            "run's score would be worse than showing none",
      );
      expect(h.state, isNull);
    });

    test('what is blocked and what it wants to ask both come through', () {
      // The two fields with nowhere else to appear. If the agent stops and
      // asks something through the heartbeat, the supervisor sees a clean exit
      // and the run looks finished.
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task);
      h.read(
        beat(blocked: 'No reference for the backbar', ask: 'Brass or steel?'),
      );

      expect(h.state!.isBlocked, isTrue);
      expect(h.state!.hasQuestion, isTrue);
      expect(h.state!.ask, contains('Brass'));
    });

    test('the tail does not grow with the run', () {
      // Twelve hours of output through a reader that keeps all of it is a
      // memory leak with a parse on top.
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task, window: 400);
      for (int i = 0; i < 200; i++) {
        h.read('Line $i of an agent that talks a great deal about nothing.');
      }
      expect(h.read(beat(score: '70')), isNotNull);
      expect(h.state!.score, 70);
    });

    test('a reset forgets the run that ended', () {
      final RunHeartbeat h = RunHeartbeat(expectedTaskId: task);
      h.read(beat(score: '61'));
      h.reset();
      expect(
        h.state,
        isNull,
        reason: "a second run must not open on the first run's score",
      );
    });
  });
}
