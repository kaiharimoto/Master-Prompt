import 'package:meta/meta.dart';

/// What a line of the compiled brief is.
enum BriefBlockKind {
  /// The `#` line: the mission's name.
  title,

  /// A `## 04 / REVIEW LOOP` section heading.
  section,

  /// Ordinary prose.
  paragraph,

  /// A `- ` item.
  bullet,

  /// A pipe table, header row included.
  table,

  /// A fenced block, kept verbatim.
  code,

  /// A `---` divider.
  rule,
}

/// A run of text with one style. Bold and code spans are the only inline
/// marks the compiler emits, so they are the only two read back.
enum BriefSpanKind { plain, strong, code }

@immutable
class BriefSpan {
  const BriefSpan(this.kind, this.text);
  final BriefSpanKind kind;
  final String text;
}

@immutable
class BriefBlock {
  const BriefBlock({
    required this.kind,
    required this.firstLine,
    required this.lastLine,
    this.spans = const <BriefSpan>[],
    this.rows = const <List<String>>[],
    this.text = '',
  });

  final BriefBlockKind kind;

  /// Inclusive line numbers in the body this was read from, which is what
  /// lets a line-level diff be shown as a mark on a rendered block.
  final int firstLine;
  final int lastLine;

  /// Styled runs, for everything but a table or a fenced block.
  final List<BriefSpan> spans;

  /// Cells, for a table. The first row is the header.
  final List<List<String>> rows;

  /// Verbatim contents, for a fenced block.
  final String text;

  /// The plain reading of this block, for a section index or a search.
  String get plain => spans.map((BriefSpan s) => s.text).join();
}

/// The compiled brief, read back into blocks that can be laid out.
///
/// Deliberately a reader over the compiled text rather than a second renderer
/// driven from the spec. The brief is the artifact — it is what the agent is
/// handed — and a preview generated from the spec instead would be a parallel
/// implementation free to drift from it. Anything shown here is something the
/// agent will read.
@immutable
class BriefDocument {
  const BriefDocument({required this.blocks, required this.lines});

  final List<BriefBlock> blocks;

  /// The source, so a diff can be taken against another compilation.
  final List<String> lines;

  List<String> get sections => blocks
      .where((BriefBlock b) => b.kind == BriefBlockKind.section)
      .map((BriefBlock b) => b.plain)
      .toList(growable: false);

  static BriefDocument parse(String body) {
    final List<String> lines = body.split('\n');
    final List<BriefBlock> blocks = <BriefBlock>[];
    int i = 0;

    while (i < lines.length) {
      final String line = lines[i];
      final String trimmed = line.trimRight();

      if (trimmed.trim().isEmpty) {
        i++;
        continue;
      }

      if (trimmed.trim() == '---') {
        blocks.add(
          BriefBlock(kind: BriefBlockKind.rule, firstLine: i, lastLine: i),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('```')) {
        final int start = i;
        final StringBuffer body = StringBuffer();
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          body.writeln(lines[i]);
          i++;
        }
        // An unterminated fence still ends the block, rather than swallowing
        // the rest of the document into code.
        if (i < lines.length) i++;
        blocks.add(
          BriefBlock(
            kind: BriefBlockKind.code,
            firstLine: start,
            lastLine: i - 1,
            text: body.toString().trimRight(),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('| ') || trimmed.startsWith('|-')) {
        final int start = i;
        final List<List<String>> rows = <List<String>>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          final String row = lines[i].trim();
          // The `|---|---:|` alignment row carries no content.
          if (!RegExp(r'^\|[\s:|-]+\|$').hasMatch(row)) {
            rows.add(_cells(row));
          }
          i++;
        }
        blocks.add(
          BriefBlock(
            kind: BriefBlockKind.table,
            firstLine: start,
            lastLine: i - 1,
            rows: List<List<String>>.unmodifiable(rows),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('## ')) {
        blocks.add(
          BriefBlock(
            kind: BriefBlockKind.section,
            firstLine: i,
            lastLine: i,
            spans: inlineSpans(trimmed.substring(3).trim()),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('# ')) {
        blocks.add(
          BriefBlock(
            kind: BriefBlockKind.title,
            firstLine: i,
            lastLine: i,
            spans: inlineSpans(trimmed.substring(2).trim()),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('- ')) {
        blocks.add(
          BriefBlock(
            kind: BriefBlockKind.bullet,
            firstLine: i,
            lastLine: i,
            spans: inlineSpans(trimmed.substring(2).trim()),
          ),
        );
        i++;
        continue;
      }

      // A paragraph runs to the next blank line, so a wrapped sentence is one
      // block rather than one per line.
      final int start = i;
      final List<String> run = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !_startsSomethingElse(lines[i])) {
        run.add(lines[i].trim());
        i++;
      }
      blocks.add(
        BriefBlock(
          kind: BriefBlockKind.paragraph,
          firstLine: start,
          lastLine: i - 1,
          spans: inlineSpans(run.join(' ')),
        ),
      );
    }

    return BriefDocument(
      blocks: List<BriefBlock>.unmodifiable(blocks),
      lines: List<String>.unmodifiable(lines),
    );
  }

  static bool _startsSomethingElse(String line) {
    final String t = line.trimLeft();
    return t.startsWith('#') ||
        t.startsWith('- ') ||
        t.startsWith('|') ||
        t.startsWith('```') ||
        t.trim() == '---';
  }

  static List<String> _cells(String row) {
    final String inner = row.substring(
      1,
      row.length - (row.endsWith('|') ? 1 : 0),
    );
    return inner.split('|').map((String c) => c.trim()).toList(growable: false);
  }
}

/// Splits `**bold**` and `` `code` `` out of a line.
///
/// Deliberately not a markdown parser: the compiler emits these two and
/// nothing else, and a general one would invent structure the brief does not
/// have.
List<BriefSpan> inlineSpans(String text) {
  final List<BriefSpan> out = <BriefSpan>[];
  final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  int at = 0;
  for (final RegExpMatch m in pattern.allMatches(text)) {
    if (m.start > at) {
      out.add(BriefSpan(BriefSpanKind.plain, text.substring(at, m.start)));
    }
    out.add(
      m.group(1) != null
          ? BriefSpan(BriefSpanKind.strong, m.group(1)!)
          : BriefSpan(BriefSpanKind.code, m.group(2)!),
    );
    at = m.end;
  }
  if (at < text.length) {
    out.add(BriefSpan(BriefSpanKind.plain, text.substring(at)));
  }
  return List<BriefSpan>.unmodifiable(out);
}
