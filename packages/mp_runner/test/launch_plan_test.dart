import 'dart:io';

import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

CapabilityProfile realProfile() => const HelpParser().parse(
  helpText: File('test/fixtures/help_2.1.42.txt').readAsStringSync(),
  version: '2.1.42',
  fingerprint: 'test',
);

CapabilityProfile minimal(
  Set<String> flags, {
  Map<String, List<String>> choices = const <String, List<String>>{},
}) => CapabilityProfile(
  version: 'test',
  fingerprint: 'test',
  flags: flags,
  choices: choices,
);

void main() {
  const LaunchPlanBuilder builder = LaunchPlanBuilder();
  final CapabilityProfile real = realProfile();

  const LaunchRequest base = LaunchRequest(
    prompt: 'Begin the mission.',
    workingDirectory: '/work/skyline',
    sessionId: '11111111-2222-3333-4444-555555555555',
  );

  group('against the real 2.1.42 capability set', () {
    final LaunchPlan p = builder.build(
      executable: 'claude',
      capabilities: real,
      request: base,
    );

    test('always runs non-interactively with a full event stream', () {
      expect(p.arguments, contains('--print'));
      expect(p.telemetry, TelemetryTier.streamJson);
      final int i = p.arguments.indexOf('--output-format');
      expect(p.arguments[i + 1], 'stream-json');
    });

    test('includes --verbose, without which stream-json emits nothing', () {
      expect(p.arguments, contains('--verbose'));
    });

    test(
      'pre-assigns the session id so a run is resumable before it starts',
      () {
        expect(p.sessionId, base.sessionId);
        final int i = p.arguments.indexOf('--session-id');
        expect(i, greaterThanOrEqualTo(0));
        expect(p.arguments[i + 1], base.sessionId);
      },
    );

    test('applies bypassPermissions as the unattended default', () {
      final int i = p.arguments.indexOf('--permission-mode');
      expect(p.arguments[i + 1], 'bypassPermissions');
    });

    test('degrades effort to what this build accepts, and says so', () {
      final LaunchPlan hi = builder.build(
        executable: 'claude',
        capabilities: real,
        request: const LaunchRequest(
          prompt: 'x',
          workingDirectory: '/w',
          effortPreference: <String>['max', 'xhigh', 'high'],
        ),
      );
      final int i = hi.arguments.indexOf('--effort');
      expect(
        hi.arguments[i + 1],
        'high',
        reason: '2.1.42 accepts only low/medium/high',
      );
      expect(hi.notes.any((String n) => n.contains('Effort reduced')), isTrue);
    });

    test('strips the nested-session guard from the child environment', () {
      expect(p.environment.containsKey('CLAUDECODE'), isTrue);
      expect(p.environment['CLAUDECODE'], isNull);
      expect(p.environment['CLAUDE_CODE_ENTRYPOINT'], isNull);
    });

    test('puts the prompt last, as a positional argument', () {
      expect(p.arguments.last, 'Begin the mission.');
    });
  });

  group('resume shapes', () {
    test(
      'a plain resume drops the pinned id rather than building an error',
      () {
        // Verified from the binary: --session-id with --resume is rejected
        // unless --fork-session is present.
        final LaunchPlan p = builder.build(
          executable: 'claude',
          capabilities: real,
          request: const LaunchRequest(
            prompt: 'Continue.',
            workingDirectory: '/w',
            intent: LaunchIntent.resume,
            resumeSessionId: 'abc',
            sessionId: 'def',
          ),
        );
        expect(p.arguments, contains('--resume'));
        expect(p.arguments, isNot(contains('--session-id')));
        expect(p.notes.any((String n) => n.contains('not pinned')), isTrue);
      },
    );

    test('a fork resume may pin a new id', () {
      final LaunchPlan p = builder.build(
        executable: 'claude',
        capabilities: real,
        request: const LaunchRequest(
          prompt: 'Continue.',
          workingDirectory: '/w',
          intent: LaunchIntent.forkResume,
          resumeSessionId: 'abc',
          sessionId: 'def',
        ),
      );
      expect(p.arguments, containsAll(<String>['--resume', '--fork-session']));
      expect(p.sessionId, 'def');
    });

    test('resuming without a session id is refused', () {
      expect(
        () => builder.build(
          executable: 'claude',
          capabilities: real,
          request: const LaunchRequest(
            prompt: 'x',
            workingDirectory: '/w',
            intent: LaunchIntent.resume,
          ),
        ),
        throwsA(isA<LaunchPlanError>()),
      );
    });
  });

  group('degrading across unknown CLI builds', () {
    test('refuses to launch a build with no --print', () {
      expect(
        () => builder.build(
          executable: 'claude',
          capabilities: minimal(<String>{'--model'}),
          request: base,
        ),
        throwsA(
          isA<LaunchPlanError>().having(
            (LaunchPlanError e) => e.message,
            'message',
            contains('non-interactively'),
          ),
        ),
      );
    });

    test('falls back to json when stream-json is unavailable', () {
      final LaunchPlan p = builder.build(
        executable: 'claude',
        capabilities: minimal(
          <String>{'--print', '--output-format'},
          choices: <String, List<String>>{
            '--output-format': <String>['text', 'json'],
          },
        ),
        request: base,
      );
      expect(p.telemetry, TelemetryTier.json);
      expect(p.notes.any((String n) => n.contains('not visible')), isTrue);
    });

    test('falls back to text and warns that resume is unavailable', () {
      final LaunchPlan p = builder.build(
        executable: 'claude',
        capabilities: minimal(<String>{'--print'}),
        request: base,
      );
      expect(p.telemetry, TelemetryTier.text);
      expect(
        p.notes.any(
          (String n) => n.contains('automatic resume is unavailable'),
        ),
        isTrue,
      );
    });

    test(
      'uses the legacy skip-permissions flag when the mode is unsupported',
      () {
        final LaunchPlan p = builder.build(
          executable: 'claude',
          capabilities: minimal(<String>{
            '--print',
            '--dangerously-skip-permissions',
          }),
          request: base,
        );
        expect(p.arguments, contains('--dangerously-skip-permissions'));
      },
    );

    test('steps down to acceptEdits and warns the run may stall', () {
      final LaunchPlan p = builder.build(
        executable: 'claude',
        capabilities: minimal(
          <String>{'--print', '--permission-mode'},
          choices: <String, List<String>>{
            '--permission-mode': <String>['default', 'acceptEdits'],
          },
        ),
        request: base,
      );
      final int i = p.arguments.indexOf('--permission-mode');
      expect(p.arguments[i + 1], 'acceptEdits');
      expect(p.notes.any((String n) => n.contains('stop to ask')), isTrue);
    });

    test('omits unknown optional flags silently rather than failing', () {
      final LaunchPlan p = builder.build(
        executable: 'claude',
        capabilities: minimal(<String>{'--print'}),
        request: const LaunchRequest(
          prompt: 'x',
          workingDirectory: '/w',
          model: 'claude-opus-5',
          appendSystemPrompt: 'extra',
          settingsPath: '/s.json',
          fallbackModel: 'sonnet',
          maxBudgetUsd: 5,
          additionalDirectories: <String>['/lib'],
        ),
      );
      expect(p.arguments, isNot(contains('--model')));
      expect(p.arguments, isNot(contains('--add-dir')));
      expect(p.arguments.last, 'x');
    });
  });

  group('invariants that must never be violated', () {
    test('stream-json is never emitted without --verbose', () {
      // A build advertising --output-format with stream-json but no --verbose
      // must not select the streaming tier.
      final LaunchPlan p = builder.build(
        executable: 'claude',
        capabilities: minimal(
          <String>{'--print', '--output-format'},
          choices: <String, List<String>>{
            '--output-format': <String>['text', 'json', 'stream-json'],
          },
        ),
        request: base,
      );
      expect(p.telemetry, isNot(TelemetryTier.streamJson));
      final int i = p.arguments.indexOf('--output-format');
      expect(p.arguments[i + 1], isNot('stream-json'));
    });
  });
}
