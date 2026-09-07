import 'dart:async';
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

void main() {
  // ---------------------------------------------------------------------
  // Composition: provable without a process, so proven without one.
  // ---------------------------------------------------------------------
  group('what the conversation would run', () {
    CliConversation composed() => CliConversation(
      executable: 'claude',
      capabilities: full,
      workingDirectory: Directory.systemTemp.path,
      model: 'opus',
      newSessionId: () => '3f2a1b4c-5d6e-4f70-8a9b-0c1d2e3f4a5b',
    );

    test('an interview turn never inherits bypassPermissions', () {
      final List<String> args = composed().planFor('Round one.').arguments;
      expect(
        args,
        containsAllInOrder(<String>['--permission-mode', 'default']),
        reason:
            'bypassPermissions exists so an unattended build does not stop to '
            'ask. An interview turn is a question about what to build and '
            'needs no tools, so the failure direction has to be refusal rather '
            'than something happening on disk nobody asked for',
      );
      expect(args, isNot(contains('--dangerously-skip-permissions')));
    });

    test('the turn is driven headlessly, with events readable', () {
      final List<String> args = composed().planFor('Round one.').arguments;
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
    });

    test('the prompt is an operand, not an argument list', () {
      final List<String> args = composed().planFor('- twenty seats').arguments;
      expect(args[args.length - 2], '--');
      expect(args.last, '- twenty seats');
    });

    test('model and effort follow the settings', () {
      final List<String> args = composed().planFor('Round one.').arguments;
      expect(args, containsAllInOrder(<String>['--model', 'opus']));
      expect(args, containsAllInOrder(<String>['--effort', 'high']));
    });

    test('no model setting means no --model at all', () {
      final CliConversation c = CliConversation(
        executable: 'claude',
        capabilities: full,
        workingDirectory: Directory.systemTemp.path,
      );
      expect(
        c.planFor('Round one.').arguments,
        isNot(contains('--model')),
        reason:
            'omitting it leaves the CLI on whatever the user already chose, '
            'which cannot be a value this build rejects',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Behaviour: against a real process, because that is where it broke.
  // ---------------------------------------------------------------------
  group('driven against a real binary', () {
    late Directory tmp;
    late String fake;

    setUpAll(() {
      tmp = Directory.systemTemp.createTempSync('mp_conv_');
      fake = '${tmp.path}/claude';
      final ProcessResult r = Process.runSync(
        Platform.resolvedExecutable,
        <String>['compile', 'exe', 'tool/fake_claude.dart', '-o', fake],
      );
      if (r.exitCode != 0) throw StateError('build failed: ${r.stderr}');
    });

    tearDownAll(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    CapabilityProfile profile() => const HelpParser().parse(
      helpText: Process.runSync(fake, <String>['--help']).stdout as String,
      version: '2.1.42',
      fingerprint: 'fake',
    );

    /// An older build: `--print` and nothing else. The launch plan degrades to
    /// plain text, so there are no events and no session id to read back.
    final CapabilityProfile textOnly = const HelpParser().parse(
      helpText: '''
Options:
  -p, --print                 Print response and exit
''',
      version: '1.0.0',
      fingerprint: 'old',
    );

    CliConversation live({
      String scenario = 'success',
      String? model,
      Duration timeout = const Duration(minutes: 1),
      CapabilityProfile? capabilities,
    }) => CliConversation(
      executable: fake,
      capabilities: capabilities ?? profile(),
      workingDirectory: tmp.path,
      model: model,
      timeout: timeout,
      environment: <String, String>{'FAKE_CLAUDE_SCENARIO': scenario},
    );

    test('the session id it generates is one the CLI accepts', () async {
      // The test that was missing. Every previous test injected both the
      // runner and the id, so the generator was never executed and the id it
      // produced — 8-5-4-4-12 — was rejected by the first real CLI it met.
      final ConversationReply r = await live().ask('Round one.');

      expect(
        r.ok,
        isTrue,
        reason:
            'a rejected session id fails here, on a Linux runner, instead of '
            'on the first desktop that tries it: ${r.error}',
      );
      expect(sessionIdPattern.hasMatch(r.sessionId!), isTrue);
    });

    test('the second turn resumes the session the first opened', () async {
      final CliConversation c = live();
      final ConversationReply first = await c.ask('Round one.');
      final ConversationReply second = await c.ask('Round two.');

      expect(second.ok, isTrue, reason: second.error ?? '');
      expect(
        second.sessionId,
        first.sessionId,
        reason:
            'the interview assumes one continuing chat, and on desktop the '
            'app has to maintain that rather than the user',
      );
    });

    test(
      'a prompt beginning with a dash survives the argument parser',
      () async {
        final ConversationReply r = await live(
          scenario: 'echo_prompt',
        ).ask('- twenty seats, - real service depth');

        expect(
          r.text,
          '- twenty seats, - real service depth',
          reason:
              'answering a numbered question with dashes is entirely ordinary, '
              'and without the -- separator the parser reads it as a flag',
        );
      },
    );

    test(
      'a model the CLI does not recognise is reported, not swallowed',
      () async {
        final ConversationReply r = await live(
          model: 'claude-opus-5',
        ).ask('Hi.');

        expect(r.ok, isFalse);
        expect(
          r.error,
          contains('--model'),
          reason:
              'the flag takes an alias or a full dated name; the app shipped a '
              'value that is neither, and --model enumerates no choices so the '
              'capability probe waves it through',
        );
      },
    );

    test('a subagent is not mistaken for the assistant', () async {
      final ConversationReply r = await live(
        scenario: 'subagent_noise',
      ).ask('Hi.');

      expect(r.text, contains('actually asked for'));
      expect(r.text, isNot(contains('Delegating')));
    });

    test('a partial answer that ends in failure is not an answer', () async {
      final CliConversation c = live(scenario: 'partial_then_fail');
      final ConversationReply r = await c.ask('Hi.');

      expect(r.ok, isFalse);
      expect(
        r.error,
        contains('session limit'),
        reason: 'stderr is the only channel the reason travels on',
      );
      expect(
        c.turns,
        isEmpty,
        reason:
            'a failed turn that left the question in the transcript made the '
            'retry send a continuing round into a session that never existed',
      );
      expect(
        r.text,
        contains('first half'),
        reason: 'the partial text is kept to show, just not counted as a reply',
      );
    });

    test('a warning on a successful turn is not thrown away', () async {
      final ConversationReply r = await live(
        scenario: 'warn_then_succeed',
      ).ask('Hi.');

      expect(r.ok, isTrue, reason: r.error ?? '');
      expect(
        r.stderrText,
        contains('approaching your session limit'),
        reason:
            'this used to be discarded whenever any text came back, throwing '
            'away the only notice that the next turn is about to fail',
      );
    });

    test('a build that reports no session id says so', () async {
      final ConversationReply r = await live(
        scenario: 'text_tier',
        capabilities: textOnly,
      ).ask('Hi.');

      expect(r.ok, isTrue, reason: 'the plain text is still the answer');
      expect(
        r.notes.join(' '),
        contains('new conversation'),
        reason:
            'with no id there is nothing to resume, so every round silently '
            'starts over while the app keeps writing for a chat that remembers',
      );
    });

    test(
      'a turn that never answers is stopped rather than waited on',
      () async {
        final ConversationReply r = await live(
          scenario: 'slow',
          timeout: const Duration(milliseconds: 300),
        ).ask('Hi.');

        expect(r.ok, isFalse);
        expect(r.error, contains('did not answer'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('a turn in flight can be stopped', () async {
      final CliConversation c = live(scenario: 'slow');
      final Future<ConversationReply> pending = c.ask('Hi.');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await c.cancel();

      final ConversationReply r = await pending;
      expect(r.ok, isFalse);
      expect(r.error, 'Stopped.');
      expect(c.turns, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('progress is visible while the turn is still running', () async {
      final CliConversation c = live();
      final List<ConversationEventKind> seen = <ConversationEventKind>[];
      final StreamSubscription<ConversationEvent> sub = c.events.listen(
        (ConversationEvent e) => seen.add(e.kind),
      );

      await c.ask('Round one.');
      // A broadcast controller delivers on a microtask, so the closing event
      // is still in flight when ask() returns.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(
        seen,
        contains(ConversationEventKind.started),
        reason:
            'the window was a frozen rectangle for the whole turn, so a hung '
            'CLI and a working one looked identical',
      );
      expect(seen, contains(ConversationEventKind.text));
      expect(seen.last, ConversationEventKind.done);
    });

    test('the transcript keeps both sides in order', () async {
      final CliConversation c = live();
      await c.ask('Round one.');

      expect(c.turns.map((ChatTurn t) => t.fromUser), <bool>[true, false]);
      expect(c.turns.first.text, 'Round one.');
    });

    test('a reset starts a new session rather than resuming', () async {
      final CliConversation c = live();
      await c.ask('Round one.');
      final String? first = c.sessionId;

      c.reset();
      await c.ask('A fresh start.');

      expect(c.sessionId, isNot(first));
      expect(c.turns, hasLength(2), reason: 'the transcript starts over too');
    });
  });
}
