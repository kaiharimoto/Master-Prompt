import 'dart:io';

import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

void main() {
  // Captured verbatim from a real install. Parsing must be validated against
  // what the binary actually prints, not against a hand-written sample.
  final String help =
      File('test/fixtures/help_2.1.42.txt').readAsStringSync();

  final CapabilityProfile p = const HelpParser().parse(
    helpText: help,
    version: '2.1.42',
    fingerprint: 'test',
  );

  group('parses the real help output of claude 2.1.42', () {
    test('finds the flags the runner depends on', () {
      for (final String f in const <String>[
        '--print',
        '--output-format',
        '--verbose',
        '--session-id',
        '--fork-session',
        '--resume',
        '--continue',
        '--model',
        '--effort',
        '--permission-mode',
        '--append-system-prompt',
        '--add-dir',
        '--settings',
        '--fallback-model',
        '--max-budget-usd',
        '--include-partial-messages',
        '--dangerously-skip-permissions',
      ]) {
        expect(p.has(f), isTrue, reason: '$f should be detected');
      }
    });

    test('finds short-flag aliases too', () {
      expect(p.has('--print'), isTrue); // declared as "-p, --print"
      expect(p.has('--continue'), isTrue); // "-c, --continue"
      expect(p.has('--resume'), isTrue); // "-r, --resume"
    });

    test('finds comma-separated long aliases', () {
      // Declared as "--allowedTools, --allowed-tools <tools...>"
      expect(p.has('--allowedTools'), isTrue);
      expect(p.has('--allowed-tools'), isTrue);
    });

    test('reads enumerated choices for output-format', () {
      expect(
        p.choices['--output-format'],
        containsAll(<String>['text', 'json', 'stream-json']),
      );
      expect(p.supportsValue('--output-format', 'stream-json'), isTrue);
      expect(p.supportsValue('--output-format', 'yaml'), isFalse);
    });

    test('reads permission modes, including bypassPermissions', () {
      expect(
        p.choices['--permission-mode'],
        containsAll(<String>[
          'acceptEdits',
          'bypassPermissions',
          'default',
          'dontAsk',
          'plan',
        ]),
      );
    });

    test('reads the real effort range, which is narrower than documented', () {
      // The published docs list low/medium/high/xhigh/max/ultracode. This build
      // accepts three. Detecting that is the entire point of the probe.
      expect(p.choices['--effort'], <String>['low', 'medium', 'high']);
      expect(p.supportsValue('--effort', 'high'), isTrue);
      expect(p.supportsValue('--effort', 'xhigh'), isFalse);
      expect(p.supportsValue('--effort', 'max'), isFalse);
    });

    test('does not invent flags that this build lacks', () {
      expect(p.has('--autocompact'), isFalse);
      expect(p.has('--bare'), isFalse);
    });

    test('finds subcommands', () {
      expect(p.subcommands, containsAll(<String>['auth', 'mcp', 'setup-token']));
    });

    test('does not read prose in parentheses as an enumeration', () {
      // "--fallback-model <model>  ... (only works with --print)"
      expect(p.choices.containsKey('--fallback-model'), isFalse);
      // "--max-budget-usd <amount> ... (only works with --print)"
      expect(p.choices.containsKey('--max-budget-usd'), isFalse);
    });
  });

  group('degrading gracefully across versions', () {
    test('bestValue steps down to a supported effort level', () {
      expect(
        p.bestValue('--effort', <String>['max', 'xhigh', 'high']),
        'high',
        reason: 'should skip values this build rejects',
      );
    });

    test('bestValue returns null for a flag the build lacks', () {
      expect(p.bestValue('--autocompact', <String>['500k']), isNull);
    });

    test('an unenumerated flag accepts anything', () {
      expect(p.supportsValue('--model', 'claude-opus-5'), isTrue);
      expect(p.supportsValue('--model', 'something-new-in-2027'), isTrue);
    });

    test('survives a JSON round trip', () {
      final CapabilityProfile b = CapabilityProfile.fromJson(p.toJson());
      expect(b.flags, p.flags);
      expect(b.choices['--effort'], p.choices['--effort']);
      expect(b.version, '2.1.42');
    });
  });
}
