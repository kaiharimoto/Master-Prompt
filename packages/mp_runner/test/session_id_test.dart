import 'dart:io';

import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

void main() {
  group('the id the CLI is handed', () {
    test('is a valid UUID, which is the whole requirement', () {
      // The shipped bug produced `65add9e6-e7b6e-4000-8000-65add9e60000` —
      // 8-5-4-4-12 — because microsecondsSinceEpoch is thirteen hex digits and
      // the code assumed twelve. The CLI answers "invalid session ID. Must be
      // a valid UUID" and the turn never starts.
      for (int i = 0; i < 1000; i++) {
        final String id = newSessionId();
        expect(
          sessionIdPattern.hasMatch(id),
          isTrue,
          reason:
              '$id is not a UUID, so the CLI would refuse the session outright',
        );
      }
    });

    test('carries the version and variant a strict parser looks for', () {
      // Sixteen random bytes wearing a UUID's punctuation is not a v4, and a
      // parser is entitled to say so. Group three opens with 4; group four
      // opens with 8, 9, a or b.
      for (int i = 0; i < 500; i++) {
        final List<String> g = newSessionId().split('-');
        expect(g, hasLength(5));
        expect(<int>[8, 4, 4, 4, 12], g.map((String s) => s.length).toList());
        expect(g[2][0], '4');
        expect(<String>['8', '9', 'a', 'b'], contains(g[3][0]));
      }
    });

    test('does not repeat, even when called as fast as possible', () {
      // The generator it replaces was seeded from the clock, so two calls in
      // the same microsecond collided — and resuming the wrong session is a
      // worse failure than refusing to open one.
      final Set<String> seen = <String>{};
      for (int i = 0; i < 20000; i++) {
        seen.add(newSessionId());
      }
      expect(seen, hasLength(20000));
    });
  });

  group('running a candidate Windows cannot start directly', () {
    test('a .cmd goes through a shell, and only on Windows', () {
      expect(
        needsShell(r'C:\Users\k\AppData\Roaming\npm\claude.cmd'),
        Platform.isWindows,
        reason:
            'the shell is a Windows workaround; using one elsewhere would '
            'change quoting for no reason',
      );
      expect(needsShell(r'C:\x\claude.BAT'), Platform.isWindows);
      expect(needsShell('/usr/local/bin/claude'), isFalse);
      expect(needsShell('claude.exe'), isFalse);
    });
  });
}
