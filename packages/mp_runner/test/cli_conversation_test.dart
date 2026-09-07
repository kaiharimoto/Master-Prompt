import 'dart:io';

import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

/// The capability set of the binary that was actually verified, so a plan
/// built here is one the real CLI would accept.
final CapabilityProfile full = const HelpParser().parse(
  helpText: '''
Options:
  -p, --print                 Print response and exit
  --output-format <format>    Output format (choices: "text", "json", "stream-json")
  --verbose                   Override verbose mode
  --session-id <uuid>         Use a specific session ID
  --fork-session              When resuming, create a new session ID
  -r, --resume [value]        Resume a conversation by session ID
  --model <model>             Model for the current session
  --effort <level>            Effort level (low, medium, high)
  --permission-mode <mode>    Permission mode (choices: "acceptEdits", "bypassPermissions", "default", "plan")
''',
  version: '2.1.42',
  fingerprint: 'test',
);

/// Records what would have been run and answers with a canned stream.
class _Recorder {
  final List<LaunchPlan> plans = <LaunchPlan>[];
  String session = 'aaaaaaaa-bbbb-4000-8000-cccccccccccc';
  String reply = 'Here is a question for you.';
  String stderr = '';
  int exitCode = 0;

  Future<ProcessResult> run(LaunchPlan plan) async {
    plans.add(plan);
    final String out =
        '{"type":"system","subtype":"init","session_id":"$session"}\n'
        '{"type":"assistant","session_id":"$session",'
        '"message":{"content":[{"type":"text","text":"$reply"}]}}\n'
        '{"type":"result","session_id":"$session","subtype":"success"}';
    return ProcessResult(0, exitCode, exitCode == 0 ? out : '', stderr);
  }
}

void main() {
  late _Recorder cli;
  CliConversation conversation() => CliConversation(
    executable: 'claude',
    capabilities: full,
    workingDirectory: Directory.systemTemp.path,
    model: 'claude-opus-5',
    newSessionId: () => 'fixed-id-0000-4000-8000-000000000000',
    runner: cli.run,
  );

  setUp(() => cli = _Recorder());

  test('the first turn opens a session and the next resumes it', () async {
    final CliConversation c = conversation();

    final ConversationReply first = await c.ask('Round one.');
    expect(first.ok, isTrue);
    expect(first.text, 'Here is a question for you.');
    expect(
      cli.plans.first.arguments,
      containsAllInOrder(<String>[
        '--session-id',
        'fixed-id-0000-4000-8000-000000000000',
      ]),
    );

    await c.ask('Round two.');
    expect(
      cli.plans.last.arguments,
      containsAllInOrder(<String>['--resume', cli.session]),
      reason:
          'the interview assumes one continuing chat, and on desktop the app '
          'has to maintain that rather than the user',
    );
    expect(
      cli.plans.last.arguments,
      isNot(contains('--session-id')),
      reason:
          'the CLI rejects a pinned id on a plain resume unless the session '
          'is also forked — verified against the binary',
    );
  });

  test('an interview turn never inherits bypassPermissions', () async {
    await conversation().ask('Round one.');

    final List<String> args = cli.plans.single.arguments;
    expect(
      args,
      containsAllInOrder(<String>['--permission-mode', 'default']),
      reason:
          'bypassPermissions exists so an unattended build does not stop to '
          'ask. An interview turn is a question about what to build and needs '
          'no tools, so the failure direction has to be refusal rather than '
          'something happening on disk nobody asked for',
    );
    expect(args, isNot(contains('--dangerously-skip-permissions')));
  });

  test('the turn is driven headlessly, with events readable', () async {
    await conversation().ask('Round one.');
    final List<String> args = cli.plans.single.arguments;

    expect(args.first, '--print', reason: 'or the CLI waits for a terminal');
    expect(
      args,
      containsAllInOrder(<String>['--output-format', 'stream-json']),
    );
    expect(
      args,
      contains('--verbose'),
      reason:
          'stream-json writes nothing at all without it, which is '
          'indistinguishable from a hang',
    );
    expect(args.last, 'Round one.', reason: 'the prompt goes last');
  });

  test('model and effort follow the settings', () async {
    await conversation().ask('Round one.');
    expect(
      cli.plans.single.arguments,
      containsAllInOrder(<String>['--model', 'claude-opus-5']),
    );
    expect(
      cli.plans.single.arguments,
      containsAllInOrder(<String>['--effort', 'high']),
    );
  });

  test('a silent CLI is reported rather than shown as an empty reply', () async {
    cli
      ..exitCode = 1
      ..stderr = 'Credit balance is too low';

    final ConversationReply r = await conversation().ask('Round one.');

    expect(r.ok, isFalse);
    expect(
      r.error,
      contains('Credit balance'),
      reason:
          'stderr is the only channel carrying a limit or auth failure — the '
          'CLI serialises errors with a plain JSON.stringify and Error.message '
          'is non-enumerable, so it never reaches the stdout stream',
    );
  });

  test(
    'a reset starts a new session rather than resuming the old one',
    () async {
      final CliConversation c = conversation();
      await c.ask('Round one.');
      expect(c.sessionId, isNotNull);

      c.reset();
      await c.ask('A fresh start.');

      expect(cli.plans.last.arguments, isNot(contains('--resume')));
      expect(c.turns, hasLength(2), reason: 'the transcript starts over too');
    },
  );

  test('the transcript keeps both sides in order', () async {
    final CliConversation c = conversation();
    await c.ask('Round one.');

    expect(c.turns.map((ChatTurn t) => t.fromUser), <bool>[true, false]);
    expect(c.turns.first.text, 'Round one.');
    expect(c.turns.last.text, 'Here is a question for you.');
  });
}
