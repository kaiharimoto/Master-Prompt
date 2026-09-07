import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../stream/cli_event.dart';
import 'capability_profile.dart';
import 'launch_plan.dart';

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

/// What one `ask` produced.
@immutable
class ConversationReply {
  const ConversationReply({
    required this.text,
    this.sessionId,
    this.notes = const <String>[],
    this.error,
  });

  /// Everything the assistant said, joined.
  final String text;

  /// The session this turn ran in, so the next one can resume it.
  final String? sessionId;

  /// Capabilities that were requested and could not be applied.
  final List<String> notes;

  /// Set when the turn did not produce a usable reply.
  final String? error;

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
class CliConversation {
  CliConversation({
    required this.executable,
    required this.capabilities,
    required this.workingDirectory,
    this.model,
    this.effortPreference = const <String>['high', 'medium'],
    this.newSessionId = _uuid,
    ProcessRunner? runner,
  }) : _run = runner ?? _defaultRunner;

  final String executable;
  final CapabilityProfile capabilities;
  final String workingDirectory;
  final String? model;
  final List<String> effortPreference;

  /// Injected so a test can pin the id it expects to see resumed.
  final String Function() newSessionId;

  final ProcessRunner _run;

  String? _sessionId;

  /// The session every turn after the first resumes. Null until one opens.
  String? get sessionId => _sessionId;

  final List<ChatTurn> _turns = <ChatTurn>[];
  List<ChatTurn> get turns => List<ChatTurn>.unmodifiable(_turns);

  /// Starts over. The next turn opens a new session.
  void reset() {
    _sessionId = null;
    _turns.clear();
  }

  /// Puts [prompt] to the CLI and waits for the whole reply.
  Future<ConversationReply> ask(String prompt) async {
    _turns.add(
      ChatTurn(fromUser: true, text: prompt, at: DateTime.now().toUtc()),
    );

    final String? resuming = _sessionId;
    final LaunchPlan plan;
    try {
      plan = const LaunchPlanBuilder().build(
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
    } on LaunchPlanError catch (e) {
      return ConversationReply(text: '', error: e.message);
    }

    final ProcessResult result;
    try {
      result = await _run(plan);
    } on ProcessException catch (e) {
      return ConversationReply(text: '', error: e.message);
    }

    final StringBuffer said = StringBuffer();
    // What the CLI reports, preferred over what was asked for. They agree in
    // practice, but if they ever did not, resuming the id we pinned rather
    // than the one it actually opened would fail on the next turn — and the
    // id cannot be pinned at all on older builds, where reading it back is
    // the only way to get one.
    String? reported;

    for (final String line in '${result.stdout}'.split('\n')) {
      if (line.trim().isEmpty) continue;
      final CliEvent event = CliEvent.parse(line);
      reported = event.sessionId ?? reported;
      if (event is AssistantEvent && !event.isSubagent) {
        final String text = event.text.trim();
        if (text.isNotEmpty) said.writeln(text);
      }
    }
    final String? session = reported ?? plan.sessionId;

    // Plain-text builds produce no events at all, so the output is the reply.
    final String text = said.isEmpty
        ? '${result.stdout}'.trim()
        : said.toString().trim();

    if (text.isEmpty) {
      final String err = '${result.stderr}'.trim();
      return ConversationReply(
        text: '',
        sessionId: session,
        notes: plan.notes,
        error: err.isEmpty
            ? 'The CLI exited ${result.exitCode} without saying anything.'
            : err,
      );
    }

    _sessionId = session ?? _sessionId;
    _turns.add(
      ChatTurn(fromUser: false, text: text, at: DateTime.now().toUtc()),
    );
    return ConversationReply(
      text: text,
      sessionId: _sessionId,
      notes: plan.notes,
    );
  }

  static Future<ProcessResult> _defaultRunner(LaunchPlan plan) {
    final Map<String, String> env = Map<String, String>.from(
      Platform.environment,
    );
    for (final MapEntry<String, String?> e in plan.environment.entries) {
      if (e.value == null) {
        env.remove(e.key);
      } else {
        env[e.key] = e.value!;
      }
    }
    return Process.run(
      plan.executable,
      plan.arguments,
      workingDirectory: plan.workingDirectory,
      environment: env,
      includeParentEnvironment: false,
      runInShell: CliConversation.needsShell(plan.executable),
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  }

  /// Same Windows batch-file rule the locator applies: `CreateProcess` refuses
  /// a `.cmd`, so an npm install has to go through a shell here too.
  static bool needsShell(String path) {
    if (!Platform.isWindows) return false;
    final String lower = path.toLowerCase();
    return lower.endsWith('.cmd') || lower.endsWith('.bat');
  }

  static int _counter = 0;

  /// Enough of a UUID for the CLI to accept as a session id.
  static String _uuid() {
    final int n = DateTime.now().microsecondsSinceEpoch;
    final String hex = n.toRadixString(16).padLeft(12, '0');
    final String tail = (_counter++).toRadixString(16).padLeft(4, '0');
    return '${hex.substring(0, 8)}-${hex.substring(8)}-4000-8000-'
        '${hex.substring(0, 8)}$tail';
  }
}

/// How a plan is executed. Replaced in tests.
typedef ProcessRunner = Future<ProcessResult> Function(LaunchPlan plan);
