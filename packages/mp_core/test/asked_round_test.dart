import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

const MissionSpec blank = MissionSpec(
  id: 'x',
  taskId: 't',
  title: 'T',
  presetId: 'generic',
);

/// A round shaped the way a real one arrives: prose carrying the reasoning,
/// and a terse block at the end indexing it.
const String realRound = '''
Good — "intimate rooftop bar" gives me the through-line. Two things to settle
before I can write the intent section down.

**1. How many seats should the room hold?**

This decides whether the bar or the dining is the subject.

1. **Twelve** — a private room, and the pass can stay open to the guests.
2. **Twenty** *(recommended — the brief already says "intimate", and forty
   would contradict it)*
3. **Forty** — a proper restaurant, and the bar stops being the point.

**2. Real service depth behind the bar, or a facade?**

1. **Real depth** *(recommended)* — every bottle and tool modelled.
2. **Facade** — reads at distance, falls apart in close-ups.

```mpask
q1=How many seats should the room hold?
q1a=Twelve|a private room, and the pass can stay open
q1b=Twenty|the brief already says intimate|recommended
q1c=Forty|a proper restaurant, and the bar stops being the point
q2=Real service depth behind the bar, or a facade?
q2a=Real depth|every bottle and tool modelled|recommended
q2b=Facade|reads at distance, falls apart in close-ups
```
''';

void main() {
  const AskedRoundParser parser = AskedRoundParser();

  group('reading the questions a round asked', () {
    test('turns a real round into something tappable', () {
      final AskedRound r = parser.parse(realRound);

      expect(r.found, isTrue);
      expect(r.questions, hasLength(2));
      expect(r.questions.first.text, contains('How many seats'));
      expect(r.questions.first.options.map((AskedOption o) => o.key), <String>[
        'a',
        'b',
        'c',
      ]);
      expect(r.questions.first.options[1].label, 'Twenty');
      expect(
        r.questions.first.options[1].consequence,
        'the brief already says intimate',
        reason:
            'the prompt asks for the consequence rather than the label '
            'restated, and that line is the whole reason a choice is makeable',
      );
    });

    test('marks the recommendation without choosing it', () {
      final AskedRound r = parser.parse(realRound);
      final List<AskedOption> first = r.questions.first.options;

      expect(first[1].recommended, isTrue);
      expect(
        first.where((AskedOption o) => o.recommended),
        hasLength(1),
        reason:
            'a recommendation is not an answer, so exactly one is marked and '
            'nothing about the parse decides anything',
      );
    });

    test('keeps the reply whether or not it could read it', () {
      expect(parser.parse(realRound).raw, realRound);
      expect(parser.parse('Nothing structured here.').raw, isNotEmpty);
    });

    test('a round that settled everything asks nothing, and says why', () {
      final AskedRound r = parser.parse('All settled. Here is the patch.');

      expect(r.found, isFalse);
      expect(
        r.diagnostic,
        contains('answered in your own words'),
        reason:
            'no questions is the normal end of an interview, not a failure, '
            'and the free-text box is still there',
      );
    });

    test('a block cut off mid-way keeps the options that arrived', () {
      final AskedRound r = parser.parse('''
Here you go.

```mpask
q1=How many seats?
q1a=Twelve|a private room
q1b=Twenty|intimate|recommen''');

      expect(
        r.questions,
        hasLength(1),
        reason:
            'a truncated line grammar costs one option; a truncated JSON '
            'object would have cost the whole round',
      );
      expect(r.questions.single.options, hasLength(2));
    });

    test('a question with nothing to pick from is left in the prose', () {
      final AskedRound r = parser.parse('''
```mpask
q1=What should I call it?
q1a=Only one option
```''');

      expect(
        r.found,
        isFalse,
        reason: 'a single-option card is a sentence wearing a button',
      );
    });

    test('survives the shapes a real paste turns out to be', () {
      // No fence at all, because a chat app's copy button takes the contents
      // and leaves the backticks behind — the exact case that forced the
      // patch parser to brace-match.
      expect(
        parser.parse('''
q1=Seats?
q1a=Twelve
q1b=Twenty|recommended
''').found,
        isTrue,
      );

      // Quoted, because the reply was forwarded.
      expect(
        parser.parse('''
> q1=Seats?
> q1a=Twelve
> q1b=Twenty
''').found,
        isTrue,
      );

      // Loose spacing and capitals.
      expect(
        parser.parse('''
Q1 = Seats?
Q1A = Twelve
Q1B = Twenty
''').found,
        isTrue,
      );
    });

    test('an option written before its question still belongs to it', () {
      final AskedRound r = parser.parse('''
q1a=Twelve
q1b=Twenty
q1=Seats?
''');
      expect(r.questions.single.text, 'Seats?');
      expect(r.questions.single.options, hasLength(2));
    });
  });

  group('the questions block cannot be mistaken for a patch', () {
    test('a reply with both yields the patch from one and questions from the '
        'other', () {
      const String both = '''
Two settled, two still open.

```mpask
q1=Seats?
q1a=Twelve
q1b=Twenty|recommended
```

```json
{"mission": "A rooftop bar above a city at night."}
```
''';

      final AskedRound asked = parser.parse(both);
      expect(asked.questions, hasLength(1));

      final SpecPatchResult patch = const SpecPatchParser().parse(both, blank);
      expect(patch.found, isTrue);
      expect(
        patch.applied,
        isNotEmpty,
        reason: 'the patch parser still finds its own block',
      );
    });

    test('a questions-only reply is not read as a patch', () {
      // The reason the block is line-oriented. `SpecPatchParser` brace-matches
      // with no fence at all, so a questions block written as JSON would come
      // back as answers to questions nobody had agreed to yet.
      final SpecPatchResult patch = const SpecPatchParser().parse(
        realRound,
        blank,
      );
      expect(
        patch.hasChanges,
        isFalse,
        reason: 'asking is not settling, and must never look like it',
      );
    });
  });

  group('composing the answer that goes back', () {
    test('sends the key and the label, not a bare number', () {
      final AskedRound r = parser.parse(realRound);
      final ComposedAnswer a = AnswerComposer.compose(r, <String, Choice>{
        '1': const Choice.option('b'),
        '2': const Choice.option('a'),
      });

      expect(a.answered, 2);
      expect(a.text, contains('1. (b) Twenty'));
      expect(
        a.text,
        contains('2. (a) Real depth'),
        reason:
            'a bare "1, 2" depends on the model recalling exactly what it '
            'offered five thousand characters ago',
      );
    });

    test('your own words are sent as your own words', () {
      final AskedRound r = parser.parse(realRound);
      final ComposedAnswer a = AnswerComposer.compose(r, <String, Choice>{
        '1': const Choice.ownWords('Sixteen, with a mezzanine.'),
      });

      expect(a.text, contains('1. Sixteen, with a mezzanine.'));
      expect(a.answered, 1);
    });

    test('deferring is an answer the user gave, not one the model assumed', () {
      final AskedRound r = parser.parse(realRound);
      final ComposedAnswer a = AnswerComposer.compose(r, <String, Choice>{
        '1': const Choice.deferred(),
      });

      expect(a.text, contains('No preference'));
      expect(
        a.answered,
        1,
        reason:
            'the user chose to defer; the value still comes back proposed and '
            'still has to be accepted, so the gate is untouched',
      );
    });

    test('a note rides along with the choices', () {
      final AskedRound r = parser.parse(realRound);
      final ComposedAnswer a = AnswerComposer.compose(r, <String, Choice>{
        '1': const Choice.option('a'),
      }, note: 'Keep the lighting warm throughout.');

      expect(a.text, contains('1. (a) Twelve'));
      expect(a.text, contains('Keep the lighting warm'));
    });

    test('an unanswered question is counted, so the screen can say so', () {
      final AskedRound r = parser.parse(realRound);
      final ComposedAnswer a = AnswerComposer.compose(r, <String, Choice>{
        '1': const Choice.option('a'),
      });

      expect(a.answered, 1);
      expect(r.questions.length, 2);
    });
  });
}
