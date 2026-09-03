import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

import 'reference_spec.dart';

void main() {
  final MissionSpec spec = referenceSkylineSpec();
  final String body = const PromptCompiler().compile(spec).body;

  group('reading the compiled brief back', () {
    test('every shape the compiler emits comes back as a block', () {
      final BriefDocument d = BriefDocument.parse(body);
      final Set<BriefBlockKind> kinds = d.blocks
          .map((BriefBlock b) => b.kind)
          .toSet();

      expect(
        kinds,
        containsAll(<BriefBlockKind>[
          BriefBlockKind.title,
          BriefBlockKind.section,
          BriefBlockKind.paragraph,
          BriefBlockKind.bullet,
          BriefBlockKind.table,
          BriefBlockKind.code,
          BriefBlockKind.rule,
        ]),
        reason:
            'anything the compiler emits and the reader does not know about '
            'would silently vanish from the preview, which is worse than an '
            'ugly rendering of it',
      );
    });

    test('the sections are the ten the brief is built from', () {
      final BriefDocument d = BriefDocument.parse(body);

      expect(d.sections, hasLength(10));
      expect(d.sections.first, '00 / RUNTIME');
      expect(d.sections.last, '09 / FAILURE CONDITIONS');
    });

    test('no text is lost between the source and the blocks', () {
      final BriefDocument d = BriefDocument.parse(body);
      final String flattened = d.blocks
          .map(
            (BriefBlock b) => switch (b.kind) {
              BriefBlockKind.table =>
                b.rows.expand((List<String> r) => r).join(' '),
              BriefBlockKind.code => b.text,
              BriefBlockKind.rule => '',
              _ => b.plain,
            },
          )
          .join(' ')
          .replaceAll(RegExp(r'[\s|*`#-]+'), '');

      // Every word of the brief has to survive into something renderable. A
      // preview that quietly drops a requirement is worse than no preview.
      for (final String probe in <String>[
        'skyline_restaurant_bar',
        'cold-start',
        'Circulation',
      ]) {
        expect(
          flattened,
          contains(probe.replaceAll(RegExp(r'[\s|*`#-]+'), '')),
          reason: '"$probe" is in the brief and has to reach the reader',
        );
      }
    });

    test('a table keeps its header and drops the alignment row', () {
      final BriefBlock table = BriefDocument.parse(
        body,
      ).blocks.firstWhere((BriefBlock b) => b.kind == BriefBlockKind.table);

      expect(table.rows.first, contains('Category'));
      expect(
        table.rows.every((List<String> r) => !r.join().contains('---')),
        isTrue,
        reason: 'the |---|---:| row is markdown plumbing, not content',
      );
    });

    test('bold and code spans are read, and nothing else is invented', () {
      final List<BriefSpan> spans = inlineSpans(
        'A **strong** claim about `task-id` and nothing more.',
      );

      expect(spans.map((BriefSpan s) => s.kind), <BriefSpanKind>[
        BriefSpanKind.plain,
        BriefSpanKind.strong,
        BriefSpanKind.plain,
        BriefSpanKind.code,
        BriefSpanKind.plain,
      ]);
      expect(spans[1].text, 'strong');
      expect(spans[3].text, 'task-id');
    });

    test('an unterminated fence does not swallow the document', () {
      final BriefDocument d = BriefDocument.parse('# T\n\n```\nopen\n');

      expect(
        d.blocks.where((BriefBlock b) => b.kind == BriefBlockKind.code),
        hasLength(1),
      );
      expect(d.blocks.first.kind, BriefBlockKind.title);
    });
  });

  group('what the exported document depends on', () {
    test('nothing typographic is ever set in monospace', () {
      final BriefDocument d = BriefDocument.parse(body);
      final List<String> offenders = <String>[];

      void check(String where, String text) {
        for (final int rune in text.runes) {
          if (rune > 127) {
            offenders.add('$where: U+${rune.toRadixString(16)}');
          }
        }
      }

      for (final BriefBlock b in d.blocks) {
        if (b.kind == BriefBlockKind.code) check('fence', b.text);
        for (final BriefSpan s in b.spans) {
          if (s.kind == BriefSpanKind.code) check('code span', s.text);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'the exported PDF sets code in Courier, which is built into every '
            'reader and carries no Unicode. A middle dot or an em dash inside '
            'a fence would be dropped from the document silently — so the '
            'compiler keeping code ASCII is a contract, not a coincidence',
      );
    });
  });

  group('what a round changed', () {
    test('an unchanged brief marks nothing', () {
      final BriefDiff d = BriefDiff.between(body, body);

      expect(d.isEmpty, isTrue);
      expect(d.changedLines, isEmpty);
      expect(d.summary, 'Nothing changed.');
    });

    test('a replaced value marks its block and no other', () {
      final MissionSpec after = spec.copyWith(
        missionStatement: spec.missionStatement.confirm(
          'A different mission entirely, stated in one line.',
        ),
      );
      final String updated = const PromptCompiler().compile(after).body;
      final BriefDiff d = BriefDiff.between(body, updated);
      final BriefDocument doc = BriefDocument.parse(updated);

      expect(d.isEmpty, isFalse);
      final Iterable<BriefBlock> marked = doc.blocks.where(d.marks);
      expect(
        marked.any((BriefBlock b) => b.plain.contains('different mission')),
        isTrue,
        reason: 'the block carrying the new text has to be one of the marked',
      );
      expect(
        marked.length,
        lessThan(doc.blocks.length ~/ 4),
        reason:
            'a diff that marks a quarter of the document for a one-line '
            'change is telling you nothing — the marks have to be worth '
            'looking at',
      );
    });

    test('a blank line moving is not a change', () {
      final BriefDiff d = BriefDiff.between('a\n\nb', 'a\n\n\nb');

      expect(
        d.changedLines,
        isEmpty,
        reason:
            'blank lines shift whenever anything is inserted, and marking '
            'them puts a change bar beside every gap in the document',
      );
    });

    test('an addition and a removal are counted apart', () {
      final BriefDiff d = BriefDiff.between('keep\ndrop', 'keep\nadd\nmore');

      expect(d.added, 2);
      expect(d.removed, 1);
      expect(d.summary, contains('2 lines added'));
      expect(d.summary, contains('1 removed'));
    });

    test('the marks index the new brief, not the old one', () {
      final BriefDiff d = BriefDiff.between('a\nb\nc', 'a\nNEW\nb\nc');

      expect(
        d.changedLines,
        <int>{1},
        reason:
            'the reader renders the new body, so a mark that pointed into the '
            'old one would land on the wrong block',
      );
    });
  });
}
