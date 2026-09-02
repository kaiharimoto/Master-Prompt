import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

const StateParser parser = StateParser();

String block({
  String task = 'skyline-restaurant-bar',
  String phase = 'review',
  String step = 'diagnosing bar lighting',
  String cycle = '3',
  String score = '78',
  String next = 'Re-render cameras 04 and 05 after fixing backbar glow',
  String blocked = 'none',
  String ask = 'none',
}) =>
    '```mpstate\n'
    'v=1\n'
    'task=$task\n'
    'phase=$phase\n'
    'step=$step\n'
    'cycle=$cycle\n'
    'score=$score\n'
    'next=$next\n'
    'blocked=$blocked\n'
    'ask=$ask\n'
    '```';

void main() {
  group('the happy path', () {
    test('reads a clean block', () {
      final StateParseResult r = parser.parse(
        'I fixed the backbar reflections.\n\n${block()}',
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.status, StateParseStatus.accepted);
      expect(r.canAdvanceState, isTrue);
      expect(r.state!.phase, MissionPhase.review);
      expect(r.state!.cycle, 3);
      expect(r.state!.score, 78);
      expect(r.state!.next, contains('Re-render cameras'));
      expect(r.state!.isBlocked, isFalse);
      expect(r.state!.hasQuestion, isFalse);
      expect(r.prose, contains('I fixed the backbar reflections.'));
      expect(r.prose, isNot(contains('mpstate')));
    });

    test('round trips through render()', () {
      final MpState a = parser
          .parse(block(), expectedTaskId: 'skyline-restaurant-bar')
          .state!;
      final MpState b = parser
          .parse(
            '```mpstate\n${a.render()}\n```',
            expectedTaskId: 'skyline-restaurant-bar',
          )
          .state!;
      expect(b.phase, a.phase);
      expect(b.cycle, a.cycle);
      expect(b.score, a.score);
      expect(b.next, a.next);
    });
  });

  group('survives what a chat UI and a clipboard do to text', () {
    test('smart quotes and non-breaking spaces', () {
      final String mangled = block(
        step: 'the “hero” camera',
      ).replaceAll(' ', ' ').replaceAll('"', '“');
      final StateParseResult r = parser.parse(
        mangled,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.canAdvanceState, isTrue);
      expect(r.repairs, isNotEmpty);
    });

    test('zero-width characters', () {
      final StateParseResult r = parser.parse(
        block().replaceAll('phase=', 'phase​='),
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.canAdvanceState, isTrue);
      expect(r.state!.phase, MissionPhase.review);
    });

    test('the fence was stripped by copy-as-plain-text', () {
      final String noFence = block()
          .replaceAll('```mpstate\n', '')
          .replaceAll('\n```', '');
      final StateParseResult r = parser.parse(
        'Some prose first.\n\n$noFence',
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.canAdvanceState, isTrue);
      expect(r.state!.next, contains('Re-render'));
      expect(r.repairs.any((String s) => s.contains('fence')), isTrue);
    });

    test('markdown emphasis applied to the keys', () {
      const String bolded =
          '```mpstate\n'
          '**v**=1\n'
          '**task**=skyline-restaurant-bar\n'
          '**phase**=build\n'
          '**step**=modelling the pass\n'
          '**cycle**=0\n'
          '**score**=0\n'
          '**next**=Block out the kitchen line\n'
          '**blocked**=none\n'
          '**ask**=none\n'
          '```';
      final StateParseResult r = parser.parse(
        bolded,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.canAdvanceState, isTrue);
      expect(r.state!.phase, MissionPhase.build);
      expect(r.state!.next, 'Block out the kitchen line');
    });

    test('quoted as a blockquote', () {
      final String quoted = block()
          .split('\n')
          .map((String l) => '> $l')
          .join('\n');
      final StateParseResult r = parser.parse(
        quoted,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.canAdvanceState, isTrue);
      expect(r.state!.cycle, 3);
    });

    test('colon separators instead of equals', () {
      final String colons = block().replaceAll('=', ': ');
      final StateParseResult r = parser.parse(
        colons,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.canAdvanceState, isTrue);
      expect(r.state!.phase, MissionPhase.review);
    });

    test('a long value reflowed onto a second line is rejoined', () {
      const String reflowed =
          '```mpstate\n'
          'v=1\n'
          'task=skyline-restaurant-bar\n'
          'phase=review\n'
          'step=diagnosing\n'
          'cycle=2\n'
          'score=71\n'
          'next=Re-render cameras 04 and 05 after fixing the backbar\n'
          '  glow and the stool contact shadows\n'
          'blocked=none\n'
          'ask=none\n'
          '```';
      final StateParseResult r = parser.parse(
        reflowed,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.canAdvanceState, isTrue);
      expect(r.state!.next, contains('contact shadows'));
      expect(r.repairs.any((String s) => s.contains('wrapped')), isTrue);
    });

    test('the model elaborated the phase value', () {
      final StateParseResult r = parser.parse(
        block(phase: 'review:cycle3:diagnose'),
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.state!.phase, MissionPhase.review);
    });

    test('score given with units or prose around it', () {
      final StateParseResult r = parser.parse(
        block(score: '78.5 / 100'),
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.state!.score, 78.5);
    });
  });

  group('refuses to advance on a truncated paste', () {
    test('the block was cut off mid-way', () {
      const String cut =
          'Work so far...\n\n```mpstate\n'
          'v=1\n'
          'task=skyline-restaurant-bar\n'
          'phase=review\n'
          'step=diagnosing bar ligh';
      final StateParseResult r = parser.parse(
        cut,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.status, StateParseStatus.truncated);
      expect(
        r.canAdvanceState,
        isFalse,
        reason: 'next= was cut off, so advancing would use a stale action',
      );
      expect(r.diagnostic, contains('cut off'));
      expect(r.rawText, cut, reason: 'the paste is never discarded');
    });

    test(
      'a closed block missing only optional tail fields is still usable',
      () {
        const String noAsk =
            '```mpstate\n'
            'v=1\n'
            'task=skyline-restaurant-bar\n'
            'phase=build\n'
            'step=modelling\n'
            'next=Continue the graybox\n'
            'ask=none\n'
            '```';
        final StateParseResult r = parser.parse(
          noAsk,
          expectedTaskId: 'skyline-restaurant-bar',
        );
        expect(r.canAdvanceState, isTrue);
      },
    );
  });

  group('catches the wrong conversation', () {
    test('a block from another mission is rejected loudly', () {
      final StateParseResult r = parser.parse(
        block(task: 'some-other-project'),
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.status, StateParseStatus.foreign);
      expect(r.canAdvanceState, isFalse);
      expect(r.diagnostic, contains('different conversation'));
      expect(r.state, isNotNull, reason: 'still parsed, for the user to see');
    });

    test('without an expected id, any task is accepted', () {
      final StateParseResult r = parser.parse(block(task: 'anything'));
      expect(r.status, StateParseStatus.accepted);
      expect(r.state!.taskId, 'anything');
    });
  });

  group('never loses a paste', () {
    test('plain prose with no block at all', () {
      const String prose = 'I have finished the bar. What next?';
      final StateParseResult r = parser.parse(
        prose,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.status, StateParseStatus.unusable);
      expect(r.canAdvanceState, isFalse);
      expect(r.rawText, prose);
      expect(r.prose, prose);
      expect(r.diagnostic, isNotNull);
    });

    test('empty paste', () {
      final StateParseResult r = parser.parse('');
      expect(r.status, StateParseStatus.unusable);
      expect(r.rawText, '');
    });

    test('a block with only junk between the fences', () {
      const String junk = '```mpstate\nnot a field at all\n```';
      final StateParseResult r = parser.parse(junk);
      expect(r.status, StateParseStatus.unusable);
      expect(r.rawText, junk);
    });

    test('random text is never mistaken for a block', () {
      const List<String> notBlocks = <String>[
        'Here is some code: x = 1',
        'The ratio is 3:4 and the total is 7',
        'v=1 is the version we use',
      ];
      for (final String s in notBlocks) {
        final StateParseResult r = parser.parse(s, expectedTaskId: 'anything');
        expect(r.canAdvanceState, isFalse, reason: 'should not accept: $s');
      }
    });
  });

  group('resilience details that matter in practice', () {
    test('the last block wins when the reply quotes the template first', () {
      final String twice =
          'As a reminder the format is:\n\n${block(phase: 'bootstrap', cycle: '0')}\n\n'
          'And here is my actual state:\n\n${block(phase: 'validation', cycle: '5')}';
      final StateParseResult r = parser.parse(
        twice,
        expectedTaskId: 'skyline-restaurant-bar',
      );
      expect(r.state!.phase, MissionPhase.validation);
      expect(r.state!.cycle, 5);
    });

    test('unknown keys are preserved for forward compatibility', () {
      const String withExtra =
          '```mpstate\n'
          'v=1\n'
          'task=t\n'
          'phase=build\n'
          'next=go\n'
          'artifacts=1,2,3\n'
          'future_field=hello\n'
          '```';
      final StateParseResult r = parser.parse(withExtra);
      expect(r.state!.extra['artifacts'], '1,2,3');
      expect(r.state!.extra['future_field'], 'hello');
    });

    test('blocked and ask recognise their empty forms', () {
      for (final String empty in <String>['none', 'None', 'n/a', '-', '']) {
        final StateParseResult r = parser.parse(
          block(blocked: empty, ask: empty),
        );
        expect(r.state!.isBlocked, isFalse, reason: 'blocked="$empty"');
        expect(r.state!.hasQuestion, isFalse, reason: 'ask="$empty"');
      }
      final StateParseResult r = parser.parse(
        block(blocked: 'GPU out of memory'),
      );
      expect(r.state!.isBlocked, isTrue);
      expect(r.state!.blocked, 'GPU out of memory');
    });

    test('alternate fence spellings are accepted', () {
      for (final String tag in <String>[
        'mpstate',
        'mp-state',
        'mp_state',
        'MPSTATE',
      ]) {
        final String s = block().replaceFirst('mpstate', tag);
        final StateParseResult r = parser.parse(s);
        expect(r.canAdvanceState, isTrue, reason: 'tag: $tag');
      }
    });

    test('done is recognised as terminal', () {
      final StateParseResult r = parser.parse(block(phase: 'done'));
      expect(r.state!.isComplete, isTrue);
    });
  });
}
