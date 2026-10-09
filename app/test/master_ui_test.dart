import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Master UI laws, held over the Dart source the way `master-ui/check.mjs`
/// holds them over CSS and TSX.
///
/// The kit's own linter reads web files only, so pointed at this repository it
/// would find nothing and pass forever — a check that cannot fail. This one
/// reads the app and the design package, and errs on exactly what the kit
/// errs on: a radius, a shadow, a gradient, a colour that is not paper or ink,
/// a 600 weight, an exclamation mark. A line carrying `master-ui: allow` is
/// skipped, as in the kit.
///
/// The exported PDF is left out on purpose: it is a printed document set in
/// its own faces, not the interface.
void main() {
  final List<_Source> sources = <_Source>[
    ..._read(Directory('lib')),
    ..._read(Directory('../packages/mp_design/lib')),
  ].where((_Source s) => !s.path.contains('/export/')).toList();

  test('the sources were found', () {
    expect(
      sources.length,
      greaterThan(20),
      reason: 'a law checked over no files is not checked at all',
    );
  });

  void law(
    String name,
    RegExp breach,
    String why, {
    bool Function(String)? except,
  }) {
    test(name, () {
      final List<String> found = <String>[
        for (final _Source s in sources)
          for (int i = 0; i < s.lines.length; i++)
            if (!s.lines[i].contains('master-ui: allow') &&
                !s.lines[i].trimLeft().startsWith('//') &&
                breach.hasMatch(s.lines[i]) &&
                !(except?.call(s.lines[i]) ?? false))
              '${s.path}:${i + 1}: ${s.lines[i].trim()}',
      ];
      expect(found, isEmpty, reason: why);
    });
  }

  law(
    'nothing is rounded',
    RegExp(
      r'(Radius|BorderRadius)\.circular\(|StadiumBorder\(|BoxShape\.circle',
    ),
    'Law 2: zero radius. Not a button, not a chip, not a dot.',
  );

  law(
    'nothing casts a shadow',
    RegExp(r'BoxShadow\(|Shadow\(|elevation:\s*[1-9]'),
    'Law 3: no depth tricks. Layers are separated by rules.',
  );

  law(
    'nothing is a gradient',
    RegExp(r'(Linear|Radial|Sweep)Gradient\('),
    'Law 3: the 45° hatch is the only pattern.',
  );

  law(
    'there is no colour but paper and ink',
    RegExp(r'(?<![A-Za-z])Colors\.(?!transparent\b)[a-z]\w*'),
    'Law 1: two fills. Every colour comes from MpColors, which holds paper, '
        'ink and ink at a fixed set of alphas.',
  );

  law(
    'colour is defined in one place',
    RegExp(r'Color\(0x'),
    'A literal colour outside the tokens is a third colour waiting to happen.',
  );

  law(
    'there is no 600',
    RegExp(r'FontWeight\.w(600|800|900)'),
    'Weights are 400, 500 and 700. 600 does not exist in the family.',
  );

  law(
    'nothing is exclaimed',
    RegExp(r"""'[^']*[A-Za-z][^']*!'"""),
    'Voice: no exclamation marks, anywhere a person reads.',
  );
}

class _Source {
  _Source(this.path, this.lines);

  final String path;
  final List<String> lines;
}

/// Paths with forward slashes whatever the platform. CI runs this suite on
/// Windows too, where every exclusion written with `/` would silently stop
/// matching and the tokens file would fail its own law.
List<_Source> _read(Directory root) => <_Source>[
  for (final FileSystemEntity e in root.listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart'))
      // The tokens are where paper and ink are defined, so they are the one
      // file allowed to write a colour down.
      if (!_slashed(e.path).endsWith('mp_design/lib/src/tokens.dart'))
        _Source(_slashed(e.path), e.readAsLinesSync()),
];

String _slashed(String path) => path.replaceAll(r'\', '/');
