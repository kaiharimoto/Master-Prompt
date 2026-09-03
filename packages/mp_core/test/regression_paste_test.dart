import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

const MissionSpec blank = MissionSpec(
  id: 'x',
  taskId: 't',
  title: 'T',
  presetId: 'generic',
);

/// Verbatim from the device, pasted without a fence because the Claude app's
/// code-block copy button copies the block's contents, not the backticks.
const String pastedWithoutFence = '''
mission=A private two-person messaging app for a couple, built as a native Android app plus an iOS-installable PWA, communicating peer-to-peer over Tailscale with no accounts, no cloud, and no server beyond the two devices. It replaces the couple's everyday messaging entirely — text, photos, voice all work — but conventional messaging is the substrate, not the point. The primary surface is an emotional one: a vocabulary of taps, pings, and felt signals that let one person transmit a feeling to the other with almost no effort and no expectation of a reply. The pair is hardcoded; this is built for exactly two known people, not for general distribution.
story=A shared nervous system between two bodies in different places. You feel something, you tap, and within seconds they feel it — no composing, no reading, no obligation to answer.
scale=Two shipped clients — an Android app and an iOS-installable PWA — running live on the two real devices over Tailscale. Roughly 5-7 screens.
audience=Judged by the builder at the moment of reveal to their partner. The pass mark is the first five minutes.
''';

void main() {
  test('the reply that was rejected on the device now applies', () {
    final SpecPatchResult r = const SpecPatchParser().parse(
      pastedWithoutFence,
      blank,
    );

    expect(r.found, isTrue, reason: 'diagnostic was: ${r.diagnostic}');
    expect(r.applied, hasLength(4));
    expect(r.spec.missionStatement.value, contains('Tailscale'));
    expect(r.spec.definingStory.value, contains('shared nervous system'));
    expect(r.spec.scale.value, contains('5-7 screens'));
    expect(r.spec.audience.value, contains('first five minutes'));
    // Em-dashes, colons and semicolons inside values must survive intact.
    expect(r.spec.missionStatement.value, contains('—'));
    expect(r.spec.missionStatement.value, contains('hardcoded;'));
  });

  group('the ladder accepts every shape a reply actually arrives in', () {
    void expectSameSpec(SpecPatchResult r, {required String reason}) {
      expect(r.found, isTrue, reason: '$reason — ${r.diagnostic}');
      expect(r.spec.regions, hasLength(2), reason: reason);
      expect(r.spec.regions.first.name, 'Signal surface', reason: reason);
      expect(r.spec.regions.first.requirements, contains('haptics'));
      expect(r.spec.families.single.minimumCount, 8, reason: reason);
      expect(r.spec.rubric.categories.single.weight, 60, reason: reason);
      expect(r.spec.rubric.categories.single.minimum, 51, reason: reason);
      expect(r.spec.quality.avoid, hasLength(1), reason: reason);
      expect(r.spec.failureConditions, hasLength(1), reason: reason);
    }

    test('fenced json', () {
      expectSameSpec(
        const SpecPatchParser().parse(jsonReply, blank),
        reason: 'fenced',
      );
    });

    test(
      'json with the fence stripped, which is what the copy button gives',
      () {
        final String bare = jsonReply
            .replaceAll('```json\n', '')
            .replaceAll('\n```', '');
        expectSameSpec(
          const SpecPatchParser().parse(bare, blank),
          reason: 'unfenced',
        );
      },
    );

    test('json alone, with no prose around it at all', () {
      final int a = jsonReply.indexOf('{');
      final int b = jsonReply.lastIndexOf('}');
      expectSameSpec(
        const SpecPatchParser().parse(jsonReply.substring(a, b + 1), blank),
        reason: 'json only',
      );
    });

    test('json with a trailing comma, which models emit', () {
      final String sloppy = jsonReply.replaceAll(
        '"A generic chat clone"]',
        '"A generic chat clone",]',
      );
      final SpecPatchResult r = const SpecPatchParser().parse(sloppy, blank);
      expect(r.found, isTrue, reason: '${r.diagnostic}');
      expect(r.spec.quality.avoid, hasLength(1));
    });

    test('json with smart quotes substituted by a chat UI', () {
      final String curly = jsonReply.replaceAll(
        '"mission"',
        '\u201cmission\u201d',
      );
      final SpecPatchResult r = const SpecPatchParser().parse(curly, blank);
      expect(r.found, isTrue, reason: '${r.diagnostic}');
      expect(r.spec.missionStatement.value, isNotNull);
    });

    test('a value containing braces does not end the object early', () {
      const String tricky =
          '{"mission": "Uses {curly} braces in prose", '
          '"story": "and a } here too"}';
      final SpecPatchResult r = const SpecPatchParser().parse(tricky, blank);
      expect(r.found, isTrue);
      expect(r.spec.missionStatement.value, contains('{curly}'));
      expect(r.spec.definingStory.value, contains('} here'));
    });

    test('the old fenced line grammar still works', () {
      const String lines =
          '```mpspec\n'
          'mission=Still supported\n'
          'region+=Bar | drinks\n'
          '```';
      final SpecPatchResult r = const SpecPatchParser().parse(lines, blank);
      expect(r.found, isTrue);
      expect(r.spec.missionStatement.value, 'Still supported');
      expect(r.spec.regions, hasLength(1));
    });
  });

  group('nothing is accepted that should not be', () {
    test('plain prose settles nothing and says something useful', () {
      final SpecPatchResult r = const SpecPatchParser().parse(
        'Sure! What sort of atmosphere are you going for?',
        blank,
      );
      expect(r.found, isFalse);
      expect(r.hasChanges, isFalse);
      expect(r.diagnostic, isNotNull);
      expect(r.prose, contains('atmosphere'));
    });

    test('a sentence with an equals sign is not mistaken for a patch', () {
      final SpecPatchResult r = const SpecPatchParser().parse(
        'The formula is e=mc2 and speed=distance/time.',
        blank,
      );
      expect(r.found, isFalse);
    });

    test(
      'truncated json is reported as cut off rather than silently ignored',
      () {
        final SpecPatchResult r = const SpecPatchParser().parse(
          '{"mission": "half a repl',
          blank,
        );
        expect(r.found, isFalse);
        expect(r.diagnostic, contains('cut off'));
      },
    );

    test('unknown json keys are surfaced, not dropped', () {
      final SpecPatchResult r = const SpecPatchParser().parse(
        '{"mission": "ok", "nonsense": "what"}',
        blank,
      );
      expect(r.found, isTrue);
      expect(r.rejected, contains('nonsense'));
      expect(r.spec.missionStatement.value, 'ok');
    });
  });
}

/// The shape the reworked prompt asks for.
const String jsonReply = '''
Good — here is what we settled.

```json
{
  "mission": "A private two-person messaging app.",
  "regions": [
    {"name": "Signal surface", "purpose": "Taps and pings", "requirements": ["haptics", "8-12 types"]},
    {"name": "Fallback messaging", "purpose": "Text, photos, voice"}
  ],
  "families": [{"name": "Emotion types", "description": "Felt signals", "min": 8}],
  "rubric": [{"name": "Delight", "weight": 60, "criteria": "First five minutes", "min": 51}],
  "avoid": ["A generic chat clone"],
  "failures": ["A dropped message the day after the reveal."]
}
```
''';
