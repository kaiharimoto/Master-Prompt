import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

const MissionSpec blank = MissionSpec(
  id: 'x',
  taskId: 'cocktail-bar',
  title: 'Cocktail bar',
  presetId: 'generic',
);

/// A mission four fields in, which is where the preamble starts to dominate.
MissionSpec get midway => blank.copyWith(
  missionStatement: const SpecField<String>(
    value: 'A late-night bar interior that survives close inspection.',
    resolution: FieldResolution.confirmed,
  ),
  definingStory: const SpecField<String>(
    value: 'Arriving alone at midnight and deciding to stay.',
    resolution: FieldResolution.confirmed,
  ),
  scale: const SpecField<String>(
    value: 'One room, 120 square metres, seating twenty.',
    resolution: FieldResolution.confirmed,
  ),
  audience: const SpecField<String>(
    value: 'An interior architect who has built one.',
    resolution: FieldResolution.confirmed,
  ),
);

void main() {
  const InterviewEngine engine = InterviewEngine();

  group('a turn for a chat that has been running', () {
    test('carries the round and drops the preamble', () {
      final InterviewTurn t = engine.nextTurn(
        midway,
        style: TurnStyle.continuing,
      );

      expect(
        t.text,
        contains(t.stage.title),
        reason: 'the round still has to say which round it is',
      );
      for (final ReadinessGap g in t.gaps) {
        expect(
          t.text,
          contains(g.label),
          reason: 'what is unsettled is the whole subject of the round',
        );
      }
      expect(
        t.text,
        contains('```json'),
        reason:
            'the schema changes per stage, so it is the one piece of format '
            'that cannot be assumed known',
      );

      expect(
        t.text,
        isNot(contains('You are helping me specify')),
        reason: 'the chat was told who it is nine rounds ago',
      );
      expect(
        t.text,
        isNot(contains('The mission so far')),
        reason:
            're-sending everything settled is re-telling the chat what it '
            'itself worked out, and it grows every round',
      );
      expect(
        t.text,
        isNot(contains('Judged by:')),
        reason: 'no settled value should be restated',
      );
    });

    test('keeps the rules a reply has to obey', () {
      final String text = engine
          .nextTurn(midway, style: TurnStyle.continuing)
          .text;

      expect(
        text,
        contains('numbered options'),
        reason:
            'answering by number is the thing that makes this usable on a '
            'phone, and models drop it within a couple of rounds',
      );
      expect(
        text,
        contains('recommended with a'),
        reason:
            'the round-to-round prompt is the one that has to keep working; '
            'an instruction that survives only in the first message of a nine '
            'round interview has been dropped, not kept',
      );
      expect(
        text,
        contains('nothing in the block I have not picked'),
        reason:
            'the guard against a recommendation being treated as an answer '
            'matters most in the terse turn, where there is least room for the '
            'model to be reminded of anything',
      );
      expect(
        text,
        allOf(contains('one fenced `json` block'), contains('nothing after')),
        reason:
            'format drift over nine rounds ends in a reply the parser cannot '
            'read, which is the failure this whole round-trip exists to avoid',
      );
    });

    test('is less than half the size of the standalone turn', () {
      final InterviewTurn full = engine.nextTurn(midway);
      final InterviewTurn brief = engine.nextTurn(
        midway,
        style: TurnStyle.continuing,
      );

      expect(
        brief.text.length,
        lessThan(full.text.length ~/ 2),
        reason:
            'the saving is the point: on a plan with session limits, three '
            'screens of preamble per round is spend that buys nothing',
      );
    });

    test('standalone is what a caller gets without asking', () {
      expect(
        engine.nextTurn(midway).style,
        TurnStyle.standalone,
        reason:
            'a standalone turn is merely wasteful in a running chat, whereas '
            'a continuing turn in a fresh chat is unusable — so the safe one '
            'has to be the default',
      );
    });

    test('the first round is worth sending in full', () {
      final InterviewTurn first = engine.nextTurn(blank);

      expect(
        first.text,
        allOf(
          contains('You are helping me specify'),
          contains('autonomous agent'),
        ),
        reason:
            'nothing has been said yet, so this is the only turn that has to '
            'establish what the conversation is for',
      );
    });

    test('the ready turn is the same either way', () {
      final MissionSpec ready = midway;
      expect(
        engine.nextTurn(ready, style: TurnStyle.continuing).stage,
        engine.nextTurn(ready).stage,
        reason: 'style changes how much is said, never which round it is',
      );
    });
  });
}
