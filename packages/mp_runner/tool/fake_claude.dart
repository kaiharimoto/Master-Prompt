// A stand-in for the `claude` binary, used to exercise the supervisor and the
// desktop interview.
//
// The supervisor's most important behaviour — detecting a usage limit,
// scheduling a resume that survives a restart, and re-attaching to the same
// session — cannot be tested against the real CLI, because a five-hour limit
// cannot be summoned on demand and a twelve-hour run cannot be repeated in CI.
// This script reproduces the shapes the real binary emits, including the ones
// verified by inspecting it: `system/api_error` rather than `api_retry`, limit
// text on stderr only, and stream-json gated on --verbose.
//
// **It also refuses what the real binary refuses.** For a long time it did not,
// and that is how `--session-id 65add9e6-e7b6e-4000-8000-…` — eight-five-four-
// four-twelve, not a UUID — reached a real machine behind nine green tests. A
// test double that accepts everything proves only that the code runs. Every
// rejection below is one the real CLI performs, worded as it words it.
//
// Scenario is chosen with FAKE_CLAUDE_SCENARIO. Attempt counting persists in
// FAKE_CLAUDE_STATE so a scenario can behave differently on the resume.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Flags this build knows, and whether each consumes the next argument.
///
/// Taken from `test/fixtures/help_2.1.42.txt`. Anything else exits 1, the way
/// commander does — so a flag composed from documentation rather than from the
/// binary fails loudly here instead of silently on someone's desktop.
const Map<String, bool> _flags = <String, bool>{
  '-p': false,
  '--print': false,
  '--output-format': true,
  '--input-format': true,
  '--verbose': false,
  '--include-partial-messages': false,
  '--session-id': true,
  '--fork-session': false,
  '-r': true,
  '--resume': true,
  '-c': false,
  '--continue': false,
  '--model': true,
  '--fallback-model': true,
  '--effort': true,
  '--permission-mode': true,
  '--dangerously-skip-permissions': false,
  '--add-dir': true,
  '--append-system-prompt': true,
  '--settings': true,
  '--max-budget-usd': true,
  '--no-session-persistence': false,
  '--allowedTools': true,
  '--disallowedTools': true,
  '--json-schema': true,
  '--help': false,
  '--version': false,
  '-v': false,
};

/// The same pattern `session_id.dart` generates against. Duplicated as a
/// literal on purpose: a double that imports the code under test cannot
/// disagree with it, and disagreeing is the entire job.
final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// An alias, or a full dated name. Both forms are quoted in the real `--help`:
/// "Provide an alias for the latest model (e.g. 'sonnet' or 'opus') or a
/// model's full name (e.g. 'claude-sonnet-4-5-20250929')."
final RegExp _datedModel = RegExp(r'^claude-[a-z0-9]+(-[a-z0-9]+)*-\d{8}$');
const Set<String> _modelAliases = <String>{
  'default',
  'opus',
  'sonnet',
  'haiku',
  'opusplan',
};

const Set<String> _effortLevels = <String>{'low', 'medium', 'high'};
const Set<String> _permissionModes = <String>{
  'acceptEdits',
  'bypassPermissions',
  'default',
  'delegate',
  'dontAsk',
  'plan',
};

int _attempt(String? statePath) {
  if (statePath == null) return 1;
  final File f = File(statePath);
  final int n = f.existsSync()
      ? (int.tryParse(f.readAsStringSync().trim()) ?? 0)
      : 0;
  f.writeAsStringSync('${n + 1}');
  return n + 1;
}

void emit(Map<String, Object?> event) => stdout.writeln(jsonEncode(event));

Never _die(String message, [int code = 1]) {
  stderr.writeln(message);
  exit(code);
}

/// How long to wait for a piped stdin to reach EOF before giving up on it.
///
/// The real binary waits about three seconds. A quarter of that is plenty to
/// catch a caller who never closes the pipe, and keeps the suite quick: a
/// correct caller closes at once and pays nothing at all.
const Duration _stdinGrace = Duration(milliseconds: 250);

/// Reproduces the one piece of the real CLI's behaviour that had no double.
///
/// `Process.run` closes the child's stdin; `Process.start` does not. When the
/// conversation moved to `Process.start` for streaming, the close went with it,
/// and every real turn — and every launch of a twelve-hour run — began by
/// waiting three seconds for input that was never coming, then printing a
/// warning about redirecting stdin into a window belonging to someone who has
/// never seen a shell. Nothing caught it, because this file did not read stdin
/// at all.
Future<void> _awaitStdin() async {
  try {
    await stdin.drain<void>().timeout(_stdinGrace);
  } on TimeoutException {
    stderr.writeln(
      'Warning: no stdin data received in ${_stdinGrace.inMilliseconds}ms, '
      'proceeding without it. If piping from a slow command, redirect stdin '
      'explicitly: < /dev/null to skip, or wait longer.',
    );
  } on Object {
    // No stdin to read at all. That is the ordinary case and not a problem.
  }
}

Future<void> main(List<String> args) async {
  final Map<String, String> env = Platform.environment;

  // Before anything else, and before the attempt counter — a capability probe
  // must not be able to advance a scenario's state as a side effect.
  if (args.contains('--help')) {
    stdout.write(_help);
    exit(0);
  }
  if (args.contains('--version') || args.contains('-v')) {
    stdout.writeln('2.1.42 (Claude Code)');
    exit(0);
  }

  // --- parse, and refuse what the real binary refuses --------------------
  final Map<String, String> values = <String, String>{};
  final Set<String> present = <String>{};
  final List<String> positional = <String>[];
  bool endOfFlags = false;

  for (int i = 0; i < args.length; i++) {
    final String a = args[i];
    if (endOfFlags) {
      positional.add(a);
      continue;
    }
    if (a == '--') {
      endOfFlags = true;
      continue;
    }
    if (a.startsWith('-') && a.length > 1) {
      if (!_flags.containsKey(a)) _die("error: unknown option '$a'");
      present.add(a);
      if (_flags[a]!) {
        if (i + 1 >= args.length) _die("error: option '$a' argument missing");
        values[a] = args[++i];
      }
      continue;
    }
    positional.add(a);
  }

  bool has(String a, [String? alias]) =>
      present.contains(a) || (alias != null && present.contains(alias));

  // Non-interactive is the whole premise. Without it the real binary opens a
  // session on a terminal that is not there, and simply hangs.
  if (!has('--print', '-p')) {
    _die(
      'Error: this fake only supports non-interactive use. Pass --print.\n'
      'A GUI cannot drive an interactive session; it will hang.',
    );
  }

  final String? sessionId = values['--session-id'];
  if (sessionId != null && !_uuid.hasMatch(sessionId)) {
    // Verbatim from the real binary, and the reason this file now validates
    // anything at all.
    _die('Error: invalid session ID. Must be a valid UUID.');
  }

  final String? model = values['--model'];
  if (model != null &&
      !_modelAliases.contains(model) &&
      !_datedModel.hasMatch(model)) {
    _die(
      "error: option '--model <model>' argument '$model' is invalid. Provide "
      "an alias for the latest model (e.g. 'sonnet' or 'opus') or a model's "
      "full name (e.g. 'claude-sonnet-4-5-20250929').",
    );
  }

  final String? effort = values['--effort'];
  if (effort != null && !_effortLevels.contains(effort)) {
    _die(
      "error: option '--effort <level>' argument '$effort' is invalid. "
      'Allowed choices are low, medium, high.',
    );
  }

  final String? mode = values['--permission-mode'];
  if (mode != null && !_permissionModes.contains(mode)) {
    _die(
      "error: option '--permission-mode <mode>' argument '$mode' is invalid. "
      'Allowed choices are ${_permissionModes.join(', ')}.',
    );
  }

  final String? format = values['--output-format'];
  if (format != null &&
      !<String>['text', 'json', 'stream-json'].contains(format)) {
    _die(
      "error: option '--output-format <format>' argument '$format' is "
      'invalid. Allowed choices are text, json, stream-json.',
    );
  }

  // The real CLI rejects this combination outright.
  if (sessionId != null &&
      (has('--resume', '-r') || has('--continue', '-c')) &&
      !has('--fork-session')) {
    _die(
      'Error: --session-id can only be used with --continue or --resume if '
      '--fork-session is also specified.',
    );
  }

  // After the arguments are settled and before any work, which is where the
  // real binary looks for piped input.
  await _awaitStdin();

  final String scenario = env['FAKE_CLAUDE_SCENARIO'] ?? 'success';
  final int attempt = _attempt(env['FAKE_CLAUDE_STATE']);

  // Mirror the real binary: stream-json without --verbose writes nothing.
  final bool streaming = format == 'stream-json' && has('--verbose');

  final bool isResume = has('--resume', '-r');
  final String session =
      sessionId ??
      (isResume
          ? (values['--resume'] ?? values['-r'])!
          : 'generated-session-id');

  /// The prompt as the binary would see it, so a test can prove that a prompt
  /// beginning with `-` survived the `--` separator rather than being parsed
  /// as an option.
  final String prompt = positional.isEmpty ? '' : positional.last;

  void init() {
    if (!streaming) return;
    emit(<String, Object?>{
      'type': 'system',
      'subtype': 'init',
      'session_id': session,
      'model': model ?? 'claude-opus-5',
      'tools': <String>['Read', 'Edit', 'Bash'],
    });
  }

  void assistant(String text, {String? parentToolUseId}) {
    if (!streaming) return;
    emit(<String, Object?>{
      'type': 'assistant',
      'session_id': session,
      'parent_tool_use_id': parentToolUseId,
      'message': <String, Object?>{
        'content': <Object?>[
          <String, Object?>{'type': 'text', 'text': text},
        ],
      },
    });
  }

  void success(String text) {
    if (streaming) {
      emit(<String, Object?>{
        'type': 'result',
        'subtype': 'success',
        'session_id': session,
        'result': text,
        'total_cost_usd': 0.42,
        'usage': <String, Object?>{'input_tokens': 1200, 'output_tokens': 800},
      });
    } else {
      stdout.writeln(text);
    }
    exit(0);
  }

  /// A usage limit as the real CLI presents it: a 429 with an empty error
  /// object on stdout, because Error.message is non-enumerable, and the words
  /// only on stderr.
  void limit({required String stderrText, int status = 429}) {
    if (streaming) {
      emit(<String, Object?>{
        'type': 'system',
        'subtype': 'api_error',
        'session_id': session,
        'error_status': status,
        'retryAttempt': 5,
        'maxRetries': 5,
        'error': <String, Object?>{},
      });
    }
    stderr.writeln(stderrText);
    exit(1);
  }

  switch (scenario) {
    case 'success':
      init();
      assistant('Working on the mission.');
      success('Mission step complete.');

    case 'echo_prompt':
      // Proves the prompt arrived intact — separator, leading dash, newlines
      // and all — rather than being eaten by the option parser.
      init();
      assistant(prompt);
      success(prompt);

    case 'slow':
      // Nothing is written first, so a turn that never answers is
      // indistinguishable from one still working — which is the case a
      // timeout and a cancel have to handle, and which no scenario could
      // produce while every one of them returned instantly.
      init();
      sleep(
        Duration(
          milliseconds:
              int.tryParse(env['FAKE_CLAUDE_SLEEP_MS'] ?? '') ?? 30000,
        ),
      );
      success('Finally.');

    case 'warn_then_succeed':
      // The limit warning that arrives *before* the limit. It exists on stderr
      // and nowhere else, and throwing it away whenever text came back — which
      // is what the conversation used to do — discards the only notice that
      // the next turn is about to fail.
      init();
      stderr.writeln(
        'Warning: approaching your session limit. 5% of quota remaining.',
      );
      assistant('Answering anyway.');
      success('Done, with a warning.');

    case 'partial_then_fail':
      // Text, then a non-zero exit. Treating this as a complete answer commits
      // half a reply and a session id that the CLI has already abandoned.
      init();
      assistant('Here is the first half of the answer, and then—');
      stderr.writeln("Error: You've hit your session limit.");
      exit(1);

    case 'text_tier':
      // A build with no stream-json: no events, so no session id to read back.
      // The app must notice, or every round silently opens a new session.
      stdout.writeln('A plain text answer with no envelope around it.');
      exit(0);

    case 'subagent_noise':
      // A subagent's words must not be mistaken for the assistant's own.
      init();
      assistant('Delegating that part.', parentToolUseId: 'toolu_01abc');
      assistant('The answer you actually asked for.');
      success('Done.');

    case 'limit_then_success':
      init();
      assistant('Started the graybox.');
      if (attempt == 1) {
        limit(
          stderrText:
              "Error: You've hit your session limit. Your limit will reset "
              'later today.',
        );
      }
      assistant('Resumed and continued from the checkpoint.');
      success('Mission complete after resume.');

    case 'weekly_limit':
      init();
      limit(stderrText: "Error: You've hit your weekly limit.");

    case 'resume_rejected':
      // Establishes a session and makes progress, but does not finish, so the
      // supervisor resumes. That resume is rejected, forcing the ladder down to
      // a fork, which then completes.
      if (has('--fork-session')) {
        init();
        assistant('Forked from the original transcript.');
        success('Continued in a forked session.');
      }
      if (!isResume) {
        init();
        assistant('Initial run, more work to do.');
        // Exit cleanly with no result event: work in progress, not finished.
        exit(0);
      }
      stderr.writeln('Error: No conversation found with session ID $session');
      exit(1);

    case 'die_midstream':
      init();
      assistant('Partial work...');
      // No result event: the stream simply stops.
      exit(1);

    case 'always_limit':
      init();
      limit(stderrText: "Error: You've hit your session limit.");

    case 'auth_failure':
      stderr.writeln('Error: Invalid API key. Please run /login.');
      exit(1);

    case 'no_progress':
      // Resumes cleanly every time but never advances the mission — the case a
      // liveness check would call healthy and a progress check must not.
      init();
      assistant('Thinking about it.');
      success('No changes made.');

    default:
      stderr.writeln('Unknown scenario: $scenario');
      exit(2);
  }
}

const String _help = '''
Usage: claude [options] [command] [prompt]

Options:
  -p, --print                                       Print response and exit
  --output-format <format>                          Output format (choices: "text", "json", "stream-json")
  --input-format <format>                           Input format (only works with --print) (choices: "text", "stream-json")
  --verbose                                         Override verbose mode setting from config
  --session-id <uuid>                               Use a specific session ID for the conversation
  --fork-session                                    When resuming, create a new session ID
  -r, --resume [value]                              Resume a conversation by session ID
  -c, --continue                                    Continue the most recent conversation
  --model <model>                                   Model for the current session
  --effort <level>                                  Effort level for the current session (low, medium, high)
  --permission-mode <mode>                          Permission mode (choices: "acceptEdits", "bypassPermissions", "default", "plan")
  --dangerously-skip-permissions                    Bypass all permission checks
  --append-system-prompt <prompt>                   Append a system prompt to the default system prompt
  --add-dir <directories...>                        Additional directories to allow tool access to
  --settings <file-or-json>                         Path to a settings JSON file
''';
