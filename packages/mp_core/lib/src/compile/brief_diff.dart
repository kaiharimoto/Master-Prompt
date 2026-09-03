import 'package:meta/meta.dart';

import 'brief_document.dart';

/// What happened to one line between two compilations.
enum LineChange { same, added, removed }

@immutable
class DiffLine {
  const DiffLine(this.change, this.text);
  final LineChange change;
  final String text;
}

/// What one accepted round did to the brief.
///
/// The compiler is pure and deterministic — same spec, same bytes — so a plain
/// text diff of two compilations is an exact account of the change, with no
/// need for the spec to report on itself.
@immutable
class BriefDiff {
  const BriefDiff({
    required this.lines,
    required this.changedLines,
    required this.added,
    required this.removed,
  });

  /// Every line of the new brief in order, plus the removed lines in place.
  final List<DiffLine> lines;

  /// Indices into the *new* body that are new or altered.
  final Set<int> changedLines;

  final int added;
  final int removed;

  bool get isEmpty => added == 0 && removed == 0;

  /// True when any line of [block] is new. A block is the unit the reader
  /// sees, so this is what a mark in the margin actually means.
  bool marks(BriefBlock block) {
    for (int i = block.firstLine; i <= block.lastLine; i++) {
      if (changedLines.contains(i)) return true;
    }
    return false;
  }

  /// The empty diff, for a brief with no baseline to compare against.
  static const BriefDiff none = BriefDiff(
    lines: <DiffLine>[],
    changedLines: <int>{},
    added: 0,
    removed: 0,
  );

  static BriefDiff between(String before, String after) {
    final List<String> a = before.split('\n');
    final List<String> b = after.split('\n');

    // Longest common subsequence over lines. The brief is around four hundred
    // lines, so the quadratic table is a fraction of a millisecond and worth
    // it for an exact answer rather than a heuristic one.
    final List<List<int>> table = List<List<int>>.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
      growable: false,
    );
    for (int i = a.length - 1; i >= 0; i--) {
      for (int j = b.length - 1; j >= 0; j--) {
        table[i][j] = a[i] == b[j]
            ? table[i + 1][j + 1] + 1
            : (table[i + 1][j] >= table[i][j + 1]
                  ? table[i + 1][j]
                  : table[i][j + 1]);
      }
    }

    final List<DiffLine> out = <DiffLine>[];
    final Set<int> changed = <int>{};
    int added = 0;
    int removed = 0;
    int i = 0;
    int j = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        out.add(DiffLine(LineChange.same, b[j]));
        i++;
        j++;
      } else if (table[i + 1][j] >= table[i][j + 1]) {
        out.add(DiffLine(LineChange.removed, a[i]));
        if (a[i].trim().isNotEmpty) removed++;
        i++;
      } else {
        out.add(DiffLine(LineChange.added, b[j]));
        // Blank lines shift around whenever anything is inserted, and marking
        // them would put a change bar beside every gap in the document.
        if (b[j].trim().isNotEmpty) {
          changed.add(j);
          added++;
        }
        j++;
      }
    }
    while (i < a.length) {
      out.add(DiffLine(LineChange.removed, a[i]));
      if (a[i].trim().isNotEmpty) removed++;
      i++;
    }
    while (j < b.length) {
      out.add(DiffLine(LineChange.added, b[j]));
      if (b[j].trim().isNotEmpty) {
        changed.add(j);
        added++;
      }
      j++;
    }

    return BriefDiff(
      lines: List<DiffLine>.unmodifiable(out),
      changedLines: Set<int>.unmodifiable(changed),
      added: added,
      removed: removed,
    );
  }

  /// One line saying what moved, for a heading or a summary page.
  String get summary {
    if (isEmpty) return 'Nothing changed.';
    final List<String> parts = <String>[
      if (added > 0) '$added line${added == 1 ? '' : 's'} added or rewritten',
      if (removed > 0) '$removed removed',
    ];
    return parts.join(', ');
  }
}
