// A stand-in for the `claude` binary, used to exercise the supervisor.
//
// The supervisor's most important behaviour — detecting a usage limit,
// scheduling a resume that survives a restart, and re-attaching to the same
// session — cannot be tested against the real CLI, because a five-hour limit
// cannot be summoned on demand and a twelve-hour run cannot be repeated in CI.
// This script reproduces the shapes the real binary emits, including the ones
// verified by inspecting it: `system/api_error` rather than `api_retry`, limit
// text on stderr only, and stream-json gated on --verbose.
//
// Scenario is chosen with FAKE_CLAUDE_SCENARIO. Attempt counting persists in
// FAKE_CLAUDE_STATE so a scenario can behave differently on the resume.
import 'dart:convert';
import 'dart:io';

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

void main(List<String> args) {
  final Map<String, String> env = Platform.environment;
  final String scenario = env['FAKE_CLAUDE_SCENARIO'] ?? 'success';
  final int attempt = _attempt(env['FAKE_CLAUDE_STATE']);

  if (args.contains('--help')) {
    stdout.write(_help);
    exit(0);
  }
  if (args.contains('--version') || args.contains('-v')) {
    stdout.writeln('2.1.42 (Claude Code)');
    exit(0);
  }

  // Mirror the real binary: stream-json without --verbose writes nothing.
  final int fmtIndex = args.indexOf('--output-format');
  final String format = fmtIndex >= 0 && fmtIndex + 1 < args.length
      ? args[fmtIndex + 1]
      : 'text';
  final bool streaming = format == 'stream-json' && args.contains('--verbose');

  final int sidIndex = args.indexOf('--session-id');
  final int resumeIndex = args.indexOf('--resume');
  final bool isResume = resumeIndex >= 0;
  final String sessionId = sidIndex >= 0 && sidIndex + 1 < args.length
      ? args[sidIndex + 1]
      : (isResume && resumeIndex + 1 < args.length
            ? args[resumeIndex + 1]
            : 'generated-session-id');

  // The real CLI rejects this combination outright.
  if (sidIndex >= 0 &&
      (isResume || args.contains('--continue')) &&
      !args.contains('--fork-session')) {
    stderr.writeln(
      'Error: --session-id can only be used with --continue or --resume if '
      '--fork-session is also specified.',
    );
    exit(1);
  }

  void init() {
    if (!streaming) return;
    emit(<String, Object?>{
      'type': 'system',
      'subtype': 'init',
      'session_id': sessionId,
      'model': 'claude-opus-5',
      'tools': <String>['Read', 'Edit', 'Bash'],
    });
  }

  void assistant(String text) {
    if (!streaming) return;
    emit(<String, Object?>{
      'type': 'assistant',
      'session_id': sessionId,
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
        'session_id': sessionId,
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
        'session_id': sessionId,
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
      if (args.contains('--fork-session')) {
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
      stderr.writeln('Error: No conversation found with session ID $sessionId');
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
