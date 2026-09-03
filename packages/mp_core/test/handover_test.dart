import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

import 'reference_spec.dart';

/// Reassembles what the model would see across the whole sequence, with the
/// part headers stripped — the thing that has to survive splitting.
String rejoin(Handover h) => h.parts
    .map(
      (HandoverPart p) => p.text.contains('\n---\n')
          ? p.text.substring(p.text.indexOf('\n---\n') + 5)
          : p.text,
    )
    .map((String s) => s.trim())
    .join('\n\n');

String paragraphs(int n) => List<String>.generate(
  n,
  (int i) => 'Paragraph $i. ${'word ' * 40}',
).join('\n\n');

void main() {
  group('a message that fits is left alone', () {
    test('no header, no parts, nothing to explain', () {
      final Handover h = const HandoverSplitter().plan('Short enough.');

      expect(h.isSplit, isFalse);
      expect(h.count, 1);
      expect(
        h.only.text,
        'Short enough.',
        reason:
            'the overwhelming majority of handovers fit, and wrapping those '
            'in "part 1 of 1" would make the common case worse to serve the '
            'rare one',
      );
    });
  });

  group('a message too long to paste', () {
    test('every part fits under the limit', () {
      for (final int limit in <int>[1000, 4000, 8000, 16000]) {
        final Handover h = HandoverSplitter(limit: limit).plan(paragraphs(400));
        for (final HandoverPart p in h.parts) {
          expect(
            p.text.length,
            lessThanOrEqualTo(limit),
            reason:
                'a part over the limit is the original bug — the header '
                'budget has to cover the longest header this writes',
          );
        }
      }
    });

    test('nothing is lost between the parts', () {
      final String body = paragraphs(300);
      final Handover h = HandoverSplitter(limit: 3000).plan(body);

      expect(h.isSplit, isTrue);
      expect(
        rejoin(h).replaceAll(RegExp(r'\s+'), ' '),
        body.replaceAll(RegExp(r'\s+'), ' ').trim(),
        reason:
            'splitting that drops a paragraph is worse than not splitting: '
            'the run starts anyway and nothing says what went missing',
      );
    });

    test('every part says where it is and what to do', () {
      final Handover h = HandoverSplitter(limit: 3000).plan(paragraphs(200));

      for (final HandoverPart p in h.parts) {
        expect(p.text, contains('Part ${p.index} of ${p.of}'));
      }
      for (final HandoverPart p in h.parts.where(
        (HandoverPart p) => !p.isLast,
      )) {
        expect(
          p.text,
          contains('`ok`'),
          reason:
              'without it the model answers the first third of a brief and '
              'has committed to a reading of it before the rest arrives',
        );
      }
      expect(
        h.parts.last.text,
        contains('Go ahead'),
        reason: 'something has to release it, or it waits forever',
      );
    });

    test('cuts land on section headings when one is in reach', () {
      final String body = <String>[
        for (int i = 0; i < 12; i++) '## 0$i / SECTION\n\n${'word ' * 120}',
      ].join('\n\n');
      final Handover h = HandoverSplitter(limit: 3000).plan(body);

      for (final HandoverPart p in h.parts.skip(1)) {
        final String content = p.text.split('\n---\n').last.trim();
        expect(
          content,
          startsWith('## '),
          reason:
              'a part that opens mid-sentence reads as a different document, '
              'and the seams should fall where the brief already has them',
        );
      }
    });

    test('a fenced block is never left open', () {
      final String body =
          '${paragraphs(40)}\n\n```mpstate\nphase=build\ncycle=3\n```\n\n'
          '${paragraphs(40)}';
      final Handover h = HandoverSplitter(limit: 1200).plan(body);

      for (final HandoverPart p in h.parts) {
        expect(
          RegExp('^```', multiLine: true).allMatches(p.text).length.isEven,
          isTrue,
          reason:
              'an unclosed fence turns the rest of that message into a code '
              'block, and half an mpstate template is an instruction the '
              'agent follows wrongly rather than failing on',
        );
      }
    });

    test('a fence longer than a part is closed and reopened in kind', () {
      final String body =
          'Intro.\n\n```json\n${List<String>.generate(200, (int i) => '  "key$i": "value $i",').join('\n')}\n```\n\nOutro.';
      final Handover h = HandoverSplitter(limit: 1200).plan(body);

      expect(h.isSplit, isTrue);
      for (final HandoverPart p in h.parts) {
        expect(
          RegExp('^```', multiLine: true).allMatches(p.text).length.isEven,
          isTrue,
        );
      }
      expect(
        h.parts.skip(1).any((HandoverPart p) => p.text.contains('```json')),
        isTrue,
        reason: 'the reopened fence keeps its language, not just its backticks',
      );
    });

    test('one enormous line is cut rather than dropped', () {
      final Handover h = HandoverSplitter(limit: 1000).plan('x' * 9000);

      expect(h.count, greaterThan(1));
      expect(
        h.parts
            .map((HandoverPart p) => p.text.length)
            .reduce((int a, int b) => a + b),
        greaterThan(9000),
        reason: 'there is no good seam in it, but losing it silently is worse',
      );
    });
  });

  group('the two handovers that actually overflow', () {
    test('the red-team pass on the reference mission', () {
      final MissionSpec spec = referenceSkylineSpec();
      final CompiledPrompt cli = const PromptCompiler().compile(spec);
      final InterviewTurn red = const InterviewEngine().redTeamTurn(spec, cli);

      expect(
        red.text.length,
        greaterThan(HandoverSplitter.defaultLimit),
        reason:
            'this is the message that was reported cut off on a phone; if it '
            'ever fits in one paste, this whole mechanism can go',
      );

      final Handover h = const HandoverSplitter().plan(red.text);
      expect(h.isSplit, isTrue);
      for (final HandoverPart p in h.parts) {
        expect(p.text.length, lessThanOrEqualTo(HandoverSplitter.defaultLimit));
      }
      expect(
        rejoin(h),
        contains('Red-team this mission brief'),
        reason: 'the instruction has to survive into part one',
      );
    });

    test('the brief itself, which has the same problem unnoticed', () {
      final CompiledPrompt paste = const PromptCompiler().compile(
        referenceSkylineSpec(),
        profile: TransportProfile.paste,
      );

      expect(
        paste.body.length,
        greaterThan(HandoverSplitter.defaultLimit),
        reason:
            'a truncated brief is the worst case of all — the agent runs on '
            'half a spec and nothing reports which half arrived',
      );
      expect(const HandoverSplitter().plan(paste.body).isSplit, isTrue);
    });

    test('an interview turn never needs splitting', () {
      const MissionSpec blank = MissionSpec(
        id: 'x',
        taskId: 'thing',
        title: 'Untitled mission',
        presetId: 'generic',
      );

      expect(
        const InterviewEngine().nextTurn(blank).text.length,
        lessThan(HandoverSplitter.defaultLimit ~/ 2),
        reason:
            'the flow copies these with a plain button and no stepper, which '
            'is only safe while they stay far under the limit — if this ever '
            'fails, that screen needs the mechanism too',
      );
    });
  });
}
