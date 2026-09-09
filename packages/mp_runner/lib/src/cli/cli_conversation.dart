import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../stream/cli_event.dart';
import 'capability_profile.dart';
import 'launch_plan.dart';
import 'session_id.dart';

/// The shared generator, aliased so the constructor's default value can reach
/// it past its own parameter of the same name.
const String Function() _newSessionId = newSessionId;

/// One side of a desktop interview exchange.
@immutable
class ChatTurn {
  const ChatTurn({
    required this.fromUser,
    required this.text,
    required this.at,
  });

  final bool fromUser;
  final String text;
  final DateTime at;
}

/// What is happening inside a turn, as it happens.
enum ConversationEventKind {
  /// The session opened. Carries the id the CLI actually chose.
  started,

  /// Assistant text arrived.
  text,

  /// The assistant used a tool, named.
  tool,

  /// A line on stderr — where the limit and auth reasons live, and nowhere else.
  stderr,

  /// The turn ended, one way or another.
  done,
}

@immutable
class ConversationEvent {
  const ConversationEvent(this.kind, this.text, {this.sessionId});

  final ConversationEventKind kind;
  final String text;
  final String? sessionId;
}

/// What one `ask` produced.
@immutable
class ConversationReply {
  const ConversationReply({
    required this.text,
    this.sessionId,
    this.notes = const <String>[],
    this.error,
    this.exitCode = 0,
    this.stderrText = '',
  });

  /// Everything the assistant said, joined.
  final String text;

  /// The session this turn ran in, so the next one can resume it.
  final String? sessionId;

  /// Capabilities that were requested and could not be applied.
  final List<String> notes;

  /// Set when the turn did not produce a usable reply.
  final String? error;

  final int exitCode;

  /// Kept even when the turn succeeded. `Error.message` is non-enumerable and
  /// the CLI serialises with a plain `JSON.stringify`, so a warning about a
  /// nearing limit exists here and in no other channel. Discarding it whenever
  /// text came back — which is what this used to do — throws away the only
  /// notice that the next turn is about to fail.
  final String stderrText;

  bool get ok => error == null && text.trim().isNotEmpty;
}

/// A continuing conversation with the CLI, for the desktop interview.
///
/// The phone carries the interview by clipboard because there is nothing else;
/// on a desktop the CLI is right there, and the app can hold the conversation
/// itself. The first turn opens a session with a pre-assigned id and every turn
/// after resumes it, which gives the desktop the same *one continuing chat*
/// property `TurnStyle.continuing` already assumes — without the user having to
/// maintain it.
///
/// Built on [LaunchPlanBuilder] rather than assembling arguments here, so the
/// verified invariants — `--print` is mandatory, stream-json needs `--verbose`,
/// a pinned id cannot ride a plain `--resume` — apply to a conversation exactly
/// as they do to a run.
///
/// **There is one code path to a process.** The previous version had an
/// injectable `ProcessRunner`, every test used it, and so the three functions
/// that only exist against a real binary were never executed once — which is
/// how an invalid session id shipped. Argument composition is now a pure
/// function ([planFor]) that a test can inspect without spawning anything, and
/// [ask] always spawns. There is no seam left to fake.
class CliConversation {
  CliConversation({
    required this.executable,
    required this.capabilities,
    required this.workingDirectory,
    this.model,
    this.effortPreference = const <String>['high', 'medium'],
    this.environment = const <String, String>{},
    this.timeout = const Duration(minutes: 15),
    this.newSessionId = _newSessionId,
    this.commandLineBudget,
  });

  final String executable;
  final CapabilityProfile capabilities;
  final String workingDirectory;

  /// Omitted entirely when null, which leaves the CLI on whatever model the
  /// user has already chosen with `/model`. That is the safe default: the flag
  /// takes an alias or a full dated name, and a value that is neither fails
  /// every turn.
  final String? model;

  final List<String> effortPreference;

  /// Merged into the child's environment. The CLI reads credentials from here,
  /// and a test uses it to choose a scenario without replacing the process
  /// machinery it is trying to exercise.
  final Map<String, String> environment;

  /// How long a turn may take before it is killed and reported. A real round
  /// takes well under a minute; the generous default is there so a slow
  /// machine is never mistaken for a wedged one, and the ceiling exists so a
  /// wedged one is never mistaken for a slow machine.
  final Duration timeout;

  /// Injected so a test can pin the id it expects to see resumed.
  final String Function() newSessionId;

  /// How many characters of command line this platform will carry, or null to
  /// work it out from the platform.
  ///
  /// Injectable because the rule is Windows-only and a Linux runner could
  /// otherwise never reach it — which is the same shape of hole that let an
  /// invalid session id ship: a platform-guarded branch with no way in from
  /// the machine the tests run on.
  final int? commandLineBudget;

  String? _sessionId;
  Process? _current;
  bool _cancelled = false;

  final StreamController<ConversationEvent> _events =
      StreamController<ConversationEvent>.broadcast();

  /// What is happening inside the turn in flight. Without this the window is a
  /// frozen rectangle for however long the CLI takes, and a turn that has hung
  /// looks exactly like one that is working.
  Stream<ConversationEvent> get events => _events.stream;

  /// The session every turn after the first resumes. Null until one opens.
  String? get sessionId => _sessionId;

  final List<ChatTurn> _turns = <ChatTurn>[];
  List<ChatTurn> get turns => List<ChatTurn>.unmodifiable(_turns);

  bool get busy => _current != null;

  /// Starts over. The next turn opens a new session.
  void reset() {
    _sessionId = null;
    _turns.clear();
  }

  /// Stops the turn in flight.
  Future<void> cancel() async {
    _cancelled = true;
    _current?.kill();
  }

  /// Emits, unless there is no longer anyone to emit to.
  ///
  /// A closed controller throws on `add`, and this one is closed by `dispose`
  /// — which the app calls when the mission changes. A turn still streaming at
  /// that moment would take the whole app down with
  /// *"Bad state: Cannot add new events after calling close"*, which is
  /// exactly what happened on a real desktop.
  void _say(ConversationEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }

  bool _disposed = false;

  /// Ends the conversation and stops anything still running in it.
  ///
  /// The kill is not tidiness: closing the stream while the child is still
  /// writing into it is precisely the setup for the crash above, and it would
  /// otherwise leave a `claude` process running with nowhere to send its
  /// answer.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelled = true;
    _current?.kill();
    await _events.close();
  }

  /// The exact invocation [ask] would make, without making it.
  ///
  /// Public because argument composition is the half that can be proven
  /// without a process, and it should be proven that way rather than inferred
  /// from a recording of a fake one.
  LaunchPlan planFor(String prompt) {
    final String? resuming = _sessionId;
    return const LaunchPlanBuilder().build(
      executable: executable,
      capabilities: capabilities,
      request: LaunchRequest(
        prompt: prompt,
        workingDirectory: workingDirectory,
        intent: resuming == null ? LaunchIntent.fresh : LaunchIntent.resume,
        sessionId: resuming == null ? newSessionId() : null,
        resumeSessionId: resuming,
        model: model,
        effortPreference: effortPreference,
        // Never the user's run setting. `bypassPermissions` exists so an
        // unattended build can work without stopping to ask; an interview
        // turn is a question about what to build and needs no tools at all.
        // Under the default mode a tool call cannot be approved in a
        // headless turn, so the failure direction is refusal rather than
        // something happening on disk that nobody asked for.
        permissionMode: 'default',
      ),
    );
  }

  /// Puts [prompt] to the CLI and waits for the whole reply.
  Future<ConversationReply> ask(String prompt) async {
    if (_disposed) {
      return const ConversationReply(
        text: '',
        error: 'This conversation has been closed.',
      );
    }
    if (_current != null) {
      return const ConversationReply(
        text: '',
        error: 'A turn is already in flight.',
      );
    }
    _cancelled = false;

    final ChatTurn asked = ChatTurn(
      fromUser: true,
      text: prompt,
      at: DateTime.now().toUtc(),
    );
    _turns.add(asked);

    /// A failed turn must leave no trace in the transcript.
    ///
    /// It used to leave the user's turn behind, so `hasExchange` went true on
    /// a failure and the retry sent the short *continuing* round into a
    /// session that had never existed. Retrying after an error made things
    /// quietly worse, which is the worst way for a retry to behave.
    ConversationReply fail(
      String message, {
      int exitCode = 0,
      String stderrText = '',
      String partial = '',
      List<String> notes = const <String>[],
    }) {
      _turns.remove(asked);
      _say(ConversationEvent(ConversationEventKind.done, message));
      return ConversationReply(
        text: partial,
        sessionId: _sessionId,
        notes: notes,
        error: message,
        exitCode: exitCode,
        stderrText: stderrText,
      );
    }

    final LaunchPlan plan;
    try {
      plan = planFor(prompt);
    } on LaunchPlanError catch (e) {
      return fail(e.message);
    }

    final String? tooLong = _tooLongForThisPlatform(plan);
    if (tooLong != null) return fail(tooLong);

    final Process process;
    try {
      process = await Process.start(
        plan.executable,
        plan.arguments,
        workingDirectory: plan.workingDirectory,
        environment: _childEnvironment(plan),
        includeParentEnvironment: false,
        runInShell: needsShell(plan.executable),
      );
    } on ProcessException catch (e) {
      return fail(e.message);
    }
    _current = process;

    // `Process.run` closes the child's stdin; `Process.start` does not. Left
    // open, the CLI waits three seconds for piped input that is never coming
    // and warns about redirecting stdin — into a window belonging to someone
    // who has never seen a shell. The prompt travels as an argument after
    // `--`, so there is nothing to write: closing says "no piped input".
    unawaited(process.stdin.close());

    final StringBuffer said = StringBuffer();
    final StringBuffer errText = StringBuffer();
    final StringBuffer plain = StringBuffer();
    String? reported;
    String? resultText;

    // Killed rather than awaited past the ceiling: `Process.run` had no
    // timeout at all, so a CLI waiting on a login prompt it cannot show hung
    // the app until it was force-quit, orphaning the child.
    bool timedOut = false;
    final Timer clock = Timer(timeout, () {
      timedOut = true;
      process.kill();
    });

    final Future<void> outDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          if (line.trim().isEmpty) return;
          plain.writeln(line);
          final CliEvent event = CliEvent.parse(line);
          final String? id = _sessionIdOf(event);
          if (id != null && reported == null) {
            reported = id;
            _say(
              ConversationEvent(
                ConversationEventKind.started,
                'Session $id.',
                sessionId: id,
              ),
            );
          }
          if (event is AssistantEvent && !event.isSubagent) {
            final String text = event.text;
            if (text.trim().isNotEmpty) {
              said.write(text);
              _say(ConversationEvent(ConversationEventKind.text, text));
            }
            for (final String tool in event.toolUses) {
              _say(ConversationEvent(ConversationEventKind.tool, tool));
            }
          } else if (event is ResultEvent) {
            resultText = event.text;
          }
        })
        .asFuture<void>()
        // Malformed bytes throw from the strict decoder, and losing the whole
        // turn to one bad character is worse than losing the character.
        .catchError((Object _) {});

    final Future<void> errDone = process.stderr
        .transform(utf8.decoder)
        .listen((String chunk) {
          errText.write(chunk);
          final String line = chunk.trimRight();
          if (line.isNotEmpty) {
            _say(ConversationEvent(ConversationEventKind.stderr, line));
          }
        })
        .asFuture<void>()
        .catchError((Object _) {});

    final int exitCode = await process.exitCode;
    await Future.wait<void>(<Future<void>>[outDone, errDone]);
    clock.cancel();
    _current = null;

    final String stderrText = errText.toString().trim();
    // A plain-text build produces no events at all, so what it wrote *is* the
    // reply — but only when plain text is what was asked for. Falling back to
    // raw stdout unconditionally means a `json`-tier build hands the user the
    // JSON envelope as if Claude had said it, with the patch block inside it
    // backslash-escaped and invisible to the parser.
    String text = said.isNotEmpty
        ? said.toString().trim()
        : (resultText ?? '').trim();
    if (text.isEmpty && plan.telemetry == TelemetryTier.text) {
      text = plain.toString().trim();
    }

    if (_cancelled) {
      return fail('Stopped.', exitCode: exitCode, stderrText: stderrText);
    }
    if (timedOut) {
      return fail(
        'Claude did not answer within ${timeout.inMinutes} minutes, so the '
        'turn was stopped. Nothing was applied.',
        exitCode: exitCode,
        stderrText: stderrText,
        partial: text,
      );
    }

    // A non-zero exit is a failure even when text came back. Committing half a
    // reply — and the session id attached to it — as a complete answer is how
    // a turn that died at a usage limit was stored as if Claude had finished
    // speaking.
    if (exitCode != 0) {
      return fail(
        stderrText.isEmpty
            ? 'The CLI exited $exitCode without saying why.'
            : stderrText,
        exitCode: exitCode,
        stderrText: stderrText,
        partial: text,
        notes: plan.notes,
      );
    }

    if (text.isEmpty) {
      return fail(
        stderrText.isEmpty
            ? 'The CLI exited $exitCode without saying anything.'
            : stderrText,
        exitCode: exitCode,
        stderrText: stderrText,
        notes: plan.notes,
      );
    }

    // What the CLI reports, preferred over what was asked for. They agree in
    // practice, but if they ever did not, resuming the id we pinned rather
    // than the one it actually opened would fail on the next turn — and the
    // id cannot be pinned at all on older builds, where reading it back is
    // the only way to get one.
    final List<String> notes = <String>[...plan.notes];
    final String? session = reported ?? plan.sessionId;
    if (session == null) {
      // Silent, total interview corruption otherwise: with no id there is
      // nothing to resume, so every round opens a fresh session while the app
      // goes on sending rounds written for a chat that remembers the last one.
      notes.add(
        'This CLI build reports no session id, so each round starts a new '
        'conversation and Claude will not remember the previous one.',
      );
    }
    _sessionId = session ?? _sessionId;
    _turns.add(
      ChatTurn(fromUser: false, text: text, at: DateTime.now().toUtc()),
    );
    _say(ConversationEvent(ConversationEventKind.done, 'Answered.'));

    return ConversationReply(
      text: text,
      sessionId: _sessionId,
      notes: notes,
      stderrText: stderrText,
    );
  }

  /// `session_id` read defensively. It is a hard cast on [CliEvent], evaluated
  /// on every line, and a non-string would take the whole turn down.
  String? _sessionIdOf(CliEvent event) {
    final Object? raw = event.raw['session_id'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  Map<String, String> _childEnvironment(LaunchPlan plan) {
    final Map<String, String> env = Map<String, String>.from(
      Platform.environment,
    )..addAll(environment);
    for (final MapEntry<String, String?> e in plan.environment.entries) {
      if (e.value == null) {
        env.remove(e.key);
      } else {
        env[e.key] = e.value!;
      }
    }
    return env;
  }

  /// What this platform will carry on a command line, or null for no limit.
  ///
  /// Windows caps `CreateProcess` at 32767 characters, and a `.cmd` — which an
  /// npm install of Claude Code is — goes through `cmd.exe`, where the cap
  /// drops to 8191. Both are left some headroom for the flags and the quoting.
  int? budgetFor(String executable) {
    if (commandLineBudget != null) return commandLineBudget;
    if (!Platform.isWindows) return null;
    return needsShell(executable) ? 7800 : 30000;
  }

  /// The length of the command line, counted the way the operating system
  /// counts it: every argument, plus a space and the quotes around it.
  static int commandLineLength(LaunchPlan plan) => plan.arguments.fold<int>(
    plan.executable.length,
    (int n, String a) => n + a.length + 3,
  );

  /// Refuses a command line the operating system would truncate or reject.
  ///
  /// Failing here with a sentence is better than failing there with whatever a
  /// truncated argument list happens to do.
  String? _tooLongForThisPlatform(LaunchPlan plan) {
    final int? budget = budgetFor(plan.executable);
    if (budget == null) return null;
    final int length = commandLineLength(plan);
    if (length <= budget) return null;
    return 'That message is too long to hand to the CLI on this platform '
        '($length characters, limit $budget). Shorten it, or copy it across '
        'by hand instead.';
  }
}
