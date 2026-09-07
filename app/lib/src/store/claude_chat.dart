import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mp_runner/mp_runner.dart';
import 'package:path_provider/path_provider.dart';

import 'desktop_runner.dart';
import 'diagnostics.dart';
import 'settings.dart';

/// How a conversation is opened. Replaced in tests, where no CLI exists and a
/// real process could not complete inside the tester's fake-async zone anyway.
typedef ConversationFactory =
    Future<CliConversation> Function(ClaudeInstall install, AppSettings s);

/// The desktop half of the interview: the same rounds, held in a session
/// instead of the clipboard.
///
/// The phone carries the interview by hand because there is nothing else. On a
/// desktop the CLI is already installed and already authenticated, so the app
/// can hold the conversation itself — and because every turn after the first
/// resumes one session, it gets the *one continuing chat* property the
/// clipboard route asks the user to maintain by hand.
class ClaudeChat extends ChangeNotifier {
  ClaudeChat({required this.runner, ConversationFactory? open})
    : _open = open ?? _openWithCli;

  final DesktopRunner runner;
  final ConversationFactory _open;

  CliConversation? _conversation;
  bool _busy = false;
  String? _error;

  /// Everything said in this mission's session, oldest first.
  List<ChatTurn> get turns => _conversation?.turns ?? const <ChatTurn>[];

  bool get busy => _busy;
  String? get error => _error;

  /// True once a turn has actually been exchanged, which is what distinguishes
  /// the CLI route from the clipboard one on a machine that could do either.
  bool get hasExchange => turns.isNotEmpty;

  /// Whether this machine could hold the conversation at all. Keyed off the
  /// platform and the probe, never off the layout width — a narrow window on a
  /// desktop is still a desktop.
  bool get available => DesktopRunner.isSupported && runner.install != null;

  /// The last thing Claude said, which is what the screen is about.
  String? get lastReply {
    for (final ChatTurn t in turns.reversed) {
      if (!t.fromUser) return t.text;
    }
    return null;
  }

  /// Puts one round to the CLI and waits for the whole answer.
  ///
  /// Returns the reply, or null when the turn failed — in which case [error]
  /// says why. A failure never silently looks like an empty answer.
  Future<String?> send(String prompt, AppSettings settings) async {
    if (_busy) return null;
    final ClaudeInstall? install = runner.install;
    if (install == null) {
      _error = 'The Claude Code CLI is not connected. Test it in Settings.';
      notifyListeners();
      return null;
    }

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _conversation ??= await _open(install, settings);
      final ConversationReply reply = await _conversation!.ask(prompt);
      Diagnostics.instance.log(
        'CLI turn (${prompt.length} chars): '
        '${reply.ok ? '${reply.text.length} chars back' : 'failed'}'
        '${reply.sessionId == null ? '' : ' in ${reply.sessionId}'}.',
      );
      for (final String n in reply.notes) {
        Diagnostics.instance.log('CLI turn note: $n');
      }
      if (!reply.ok) {
        _error = reply.error ?? 'The CLI answered with nothing.';
        return null;
      }
      return reply.text;
    } on Object catch (e) {
      _error = '$e';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Forget the session. A different mission is a different conversation, and
  /// resuming the last one would carry another mission's settled answers into
  /// it as if they were this one's.
  void reset() {
    _conversation = null;
    _error = null;
    _busy = false;
    notifyListeners();
  }

  /// The real thing: a session-backed conversation in a directory of its own.
  ///
  /// Not the mission's working directory. An interview turn asks about what to
  /// build and touches nothing, and a CLAUDE.md sitting in the project the
  /// mission is *about* would join the conversation uninvited.
  static Future<CliConversation> _openWithCli(
    ClaudeInstall install,
    AppSettings s,
  ) async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory(
      '${support.path}${Platform.pathSeparator}interview',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);

    return CliConversation(
      executable: install.path,
      capabilities: install.capabilities,
      workingDirectory: dir.path,
      model: s.model.trim().isEmpty ? null : s.model.trim(),
      // The launch plan degrades this to whatever the build accepts, so a
      // preference the CLI has never heard of costs a note rather than a run.
      effortPreference: <String>[s.effort, 'high', 'medium', 'low'],
    );
  }
}
