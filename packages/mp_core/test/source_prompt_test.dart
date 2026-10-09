import 'dart:convert';

import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

/// A prompt of the kind people actually arrive with: a goal, a few
/// constraints, some house rules, and nothing about how it is judged.
const String pasted = '''
# Rooftop bar

Build a photorealistic rooftop cocktail bar above a city at night in Blender.
It seats about twenty. Use Cycles. Always keep the scene under 2 GB of VRAM.
Never use stock HDRIs for the skyline.
''';

const MissionSpec blank = MissionSpec(
  id: 'x',
  taskId: 'rooftop-bar',
  title: 'Rooftop bar',
  presetId: 'generic',
);

MissionSpec get unread =>
    blank.copyWith(source: const SourcePrompt(text: pasted));

void main() {
  const InterviewEngine engine = InterviewEngine();

  group('the reading round', () {
    test('comes first, and carries the prompt it reads', () {
      final InterviewTurn t = engine.nextTurn(unread);

      expect(t.reading, isTrue, reason: 'nothing is asked before it is read');
      expect(
        t.text,
        contains('Never use stock HDRIs for the skyline.'),
        reason: 'a chat cannot read a prompt it was never shown',
      );
      expect(
        t.document,
        startsWith('<original_prompt>'),
        reason:
            'the prompt is the attachment when the round is too long to '
            'paste, and the tags keep it from reading as instructions',
      );
      expect(
        t.text,
        endsWith('${t.document}\n'),
        reason: 'the paste and the attachment must carry the same prompt',
      );
      expect(t.note, isNot(contains('Never use stock HDRIs')));
    });

    test('measures the prompt against every requirement, not one stage', () {
      final InterviewTurn t = engine.nextTurn(unread);
      for (final SpecRequirement r in kRequirements) {
        expect(
          t.text,
          contains(r.label),
          reason:
              '"${r.label}" is something an unattended run needs, so the '
              'reading has to say whether the prompt settles it',
        );
      }
    });

    test('is standalone even when a continuing turn is asked for', () {
      final InterviewTurn t = engine.nextTurn(
        unread,
        style: TurnStyle.continuing,
      );
      expect(t.reading, isTrue);
      expect(t.style, TurnStyle.standalone);
      expect(t.text, contains('Never use stock HDRIs'));
    });

    test('asks nothing, and forbids filling gaps', () {
      final String text = engine.nextTurn(unread).text;
      expect(text, isNot(contains('```mpask')));
      expect(text, contains('do not ask'));
      expect(
        text,
        contains('leave the key out'),
        reason:
            'a reading that guesses reaches an unattended run looking like '
            'something the author wrote',
      );
    });

    test('offers a schema the parser reads in full', () {
      // The schema is the only description of the format the model gets, so
      // a key in it the parser does not know is a reply the app cannot use.
      final String text = engine.nextTurn(unread).text;
      final int open = text.lastIndexOf('```json');
      final int close = text.indexOf('```', open + 7);
      final String schema = text.substring(open + 7, close).trim();

      final Object? decoded = jsonDecode(schema);
      expect(decoded, isA<Map<String, Object?>>(), reason: 'it must be JSON');

      final SpecPatchResult r = const SpecPatchParser().parse(schema, unread);
      expect(r.found, isTrue);
      expect(
        r.rejected,
        isEmpty,
        reason: 'every key offered must be one the parser understands',
      );
      for (final String key in <String>[
        'title',
        'mission',
        'regions',
        'families',
        'avoid',
        'evidence',
        'tool',
        'rubric',
        'critics',
        'failures',
        'carry',
      ]) {
        expect(
          (decoded! as Map<String, Object?>).containsKey(key),
          isTrue,
          reason: '"$key" belongs to a stage the prompt may already settle',
        );
      }
      expect(r.spec.standingInstructions, isNotEmpty);
      expect(r.spec.regions, isNotEmpty);
    });

    test('what it takes is proposed, so it still has to be accepted', () {
      const String reply = '''
Your prompt settles the subject, the scale and the tool. It says nothing about
who judges the result, how it is scored, or what proves it is finished.

```json
{
  "title": "Rooftop bar",
  "mission": "A photorealistic rooftop cocktail bar above a city at night.",
  "scale": "One rooftop seating about twenty.",
  "tool": "Blender with Cycles.",
  "carry": [
    "Always keep the scene under 2 GB of VRAM.",
    "Never use stock HDRIs for the skyline."
  ]
}
```
''';
      final SpecPatchResult r = const SpecPatchParser().parse(reply, unread);

      expect(r.spec.missionStatement.resolution, FieldResolution.proposed);
      expect(
        const ReadinessGate().evaluate(r.spec).currentStage,
        InterviewStage.seed,
        reason: 'a reading is still a model inferring until it is accepted',
      );
      expect(r.spec.standingInstructions, <String>[
        'Always keep the scene under 2 GB of VRAM.',
        'Never use stock HDRIs for the skyline.',
      ]);
      expect(
        r.applied,
        contains(
          'Standing instruction: Never use stock HDRIs for the skyline.',
        ),
        reason: 'what was carried over is named, not counted',
      );

      final MissionSpec accepted = r.spec.confirmProposals().markSourceRead();
      expect(accepted.missionStatement.isSettled, isTrue);
      expect(engine.nextTurn(accepted).reading, isFalse);
    });
  });

  group('the rounds after it', () {
    MissionSpec read() => unread
        .copyWith(
          missionStatement: const SpecField<String>(
            value: 'A photorealistic rooftop bar.',
            resolution: FieldResolution.confirmed,
          ),
        )
        .markSourceRead();

    test('a fresh chat is shown the prompt again', () {
      final InterviewTurn t = engine.nextTurn(read());
      expect(t.reading, isFalse);
      expect(t.stage, InterviewStage.intent);
      expect(
        t.text,
        contains('Never use stock HDRIs'),
        reason:
            'a chat restarted after a limit has never seen the prompt its '
            'questions are meant to be about',
      );
      expect(t.text, contains('Ground every question in my original prompt'));
      expect(t.document, contains('<original_prompt>'));
    });

    test('the running chat is not sent it twice', () {
      final InterviewTurn t = engine.nextTurn(
        read(),
        style: TurnStyle.continuing,
      );
      expect(t.text, isNot(contains('Never use stock HDRIs')));
      expect(t.document, isEmpty);
      expect(
        t.text,
        contains('original prompt'),
        reason: 'one line keeps nine rounds from drifting away from it',
      );
    });

    test('a mission begun from a sentence is untouched', () {
      final MissionSpec spec = blank.copyWith(
        missionStatement: const SpecField<String>(
          value: 'A rooftop bar.',
          resolution: FieldResolution.confirmed,
        ),
      );
      final InterviewTurn t = engine.nextTurn(spec);
      expect(t.reading, isFalse);
      expect(t.document, isEmpty);
      expect(t.text, isNot(contains('original_prompt')));
      expect(t.text, isNot(contains('Ground every question')));
    });
  });

  group('the spec', () {
    test('keeps the prompt, whether it was read, and what it carried', () {
      final MissionSpec spec = unread.markSourceRead().copyWith(
        standingInstructions: <String>['Never use stock HDRIs.'],
      );
      final MissionSpec back = MissionSpec.fromJson(
        jsonDecode(jsonEncode(spec.toJson())) as Map<String, Object?>,
      );
      expect(back.source, const SourcePrompt(text: pasted, read: true));
      expect(back.standingInstructions, <String>['Never use stock HDRIs.']);
    });

    test('a spec without either serialises as it always did', () {
      final Map<String, Object?> j = blank.toJson();
      expect(
        j.containsKey('source') || j.containsKey('standingInstructions'),
        isFalse,
        reason:
            'the content hash is taken over this map, so a new key on every '
            'existing mission would mark every compiled brief stale',
      );
    });

    test('marking it read is a no-op without a prompt, and idempotent', () {
      expect(blank.markSourceRead().source, isNull);
      final MissionSpec once = unread.markSourceRead();
      expect(identical(once.markSourceRead(), once), isTrue);
    });

    test('a blank prompt does not survive a reload as a prompt', () {
      expect(SourcePrompt.fromJson(<String, Object?>{'text': '  '}), isNull);
      expect(SourcePrompt.fromJson('nonsense'), isNull);
    });
  });

  group('standing instructions in the brief', () {
    test('are compiled under the task, and only when there are some', () {
      final String without = const PromptCompiler().compile(blank).body;
      expect(without, isNot(contains('Standing instructions')));

      final String withThem = const PromptCompiler()
          .compile(
            blank.copyWith(
              standingInstructions: <String>['Never use stock HDRIs.'],
            ),
          )
          .body;
      final int task = withThem.indexOf('01 / TASK');
      final int protocol = withThem.indexOf('02 / PROTOCOL');
      final int at = withThem.indexOf('**Standing instructions**');
      expect(at, greaterThan(task));
      expect(at, lessThan(protocol));
      expect(withThem, contains('- Never use stock HDRIs.'));
    });

    test('arrive from the line grammar too', () {
      final SpecPatchResult r = const SpecPatchParser().parse(
        '```mpspec\ncarry=Never use stock HDRIs.\nscale=Twenty seats.\n```',
        blank,
      );
      expect(r.spec.standingInstructions, <String>['Never use stock HDRIs.']);
    });

    test('a single instruction sent as a string is still taken', () {
      final SpecPatchResult r = const SpecPatchParser().parse(
        '{"carry": "Never use stock HDRIs."}',
        blank,
      );
      expect(r.spec.standingInstructions, <String>['Never use stock HDRIs.']);
    });
  });
}
