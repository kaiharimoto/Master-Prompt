import 'dart:async';
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
  StreamSubscription<ConversationEvent>? _listening;
  Timer? _tick;
  DateTime? _startedAt;

  bool _busy = false;
  String? _error;
  List<String> _notes = const <String>[];
  final StringBuffer _live = StringBuffer();
  String _activity = '';

  /// Everything said in this mission's session, oldest first.
  List<ChatTurn> get turns => _conversation?.turns ?? const <ChatTurn>[];

  bool get busy => _busy;
  String? get error => _error;

  /// What the installed CLI could not do as asked — a degraded effort level, a
  /// build that reports no session id. These used to reach `Diagnostics` and
  /// nowhere else, so a build that silently restarted the conversation every
  /// round looked exactly like one that did not.
  List<String> get notes => _notes;

  /// Text as it arrives, so the screen shows the answer being written rather
  /// than a disabled button for however long the turn takes.
  String get liveText => _live.toString();

  /// The most recent tool use or stderr line — one line, not a log.
  String get activity => _activity;

  /// How long the turn in flight has been running. A number that moves is the
  /// difference between "working" and "wedged".
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

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
  /// Returns null when the turn failed — in which case [error] says why. A
  /// failure never silently looks like an empty answer, and it leaves no trace
  /// in the transcript, so the retry is written for the fresh session it
  /// actually is.
  Future<ConversationReply?> send(String prompt, AppSettings settings) async {
    if (_busy) return null;
    final ClaudeInstall? install = runner.install;
    if (install == null) {
      _error = 'The Claude Code CLI is not connected. Test it in Settings.';
      notifyListeners();
      return null;
    }

    _busy = true;
    _error = null;
    _notes = const <String>[];
    _live.clear();
    _activity = '';
    _startedAt = DateTime.now();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    notifyListeners();

    try {
      final CliConversation c = _conversation ??= await _open(
        install,
        settings,
      );
      await _listening?.cancel();
      _listening = c.events.listen(_onEvent);

      final ConversationReply reply = await c.ask(prompt);
      _notes = reply.notes;
      Diagnostics.instance.log(
        'CLI turn (${prompt.length} chars, ${elapsed.inSeconds}s): '
        '${reply.ok ? '${reply.text.length} chars back' : 'failed'}'
        '${reply.sessionId == null ? '' : ' in ${reply.sessionId}'}.',
      );
      for (final String n in reply.notes) {
        Diagnostics.instance.log('CLI turn note: $n');
      }
      if (reply.stderrText.isNotEmpty) {
        Diagnostics.instance.log('CLI stderr: ${reply.stderrText}');
      }
      if (!reply.ok) {
        _error = reply.error ?? 'The CLI answered with nothing.';
        return null;
      }
      return reply;
    } on Object catch (e) {
      _error = '$e';
      return null;
    } finally {
      _tick?.cancel();
      _tick = null;
      _startedAt = null;
      _busy = false;
      notifyListeners();
    }
  }

  /// Stops the turn in flight. Nothing is applied and the round survives.
  Future<void> cancel() async => _conversation?.cancel();

  void _onEvent(ConversationEvent e) {
    switch (e.kind) {
      case ConversationEventKind.text:
        _live.write(e.text);
      case ConversationEventKind.tool:
        _activity = 'Using ${e.text}';
      case ConversationEventKind.stderr:
        // Not shown as the app's own status. A line addressed to someone at a
        // shell — "redirect stdin explicitly: < /dev/null" — told the person
        // writing a brief nothing they could act on, and displaced the elapsed
        // count for the rest of the turn. It reaches the diagnostics log,
        // which is where a report is built from, and the reason for a failed
        // turn still reaches the screen through `error`.
        return;
      case ConversationEventKind.started:
      case ConversationEventKind.done:
        return;
    }
    notifyListeners();
  }

  /// Forget the session. A different mission is a different conversation, and
  /// resuming the last one would carry another mission's settled answers into
  /// it as if they were this one's.
  void reset() {
    // Dropped before anything is torn down, so a turn that is still streaming
    // cannot find its way back to a screen about a different mission.
    unawaited(_listening?.cancel());
    _listening = null;

    // `dispose` kills the child and closes the stream, in that order. Doing it
    // the other way round is what crashed the app with "Cannot add new events
    // after calling close" when a mission changed mid-turn.
    unawaited(_conversation?.dispose());
    _conversation = null;

    _tick?.cancel();
    _tick = null;
    _startedAt = null;
    _error = null;
    _notes = const <String>[];
    _activity = '';
    _live.clear();
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_listening?.cancel());
    unawaited(_conversation?.dispose());
    super.dispose();
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
      // Empty means no --model at all, leaving the CLI on whatever the user
      // chose with /model. The flag refuses anything that is not an alias or a
      // full dated name, and it enumerates no choices, so the capability probe
      // cannot catch a bad one before it fails the turn.
      model: s.model.trim().isEmpty ? null : s.model.trim(),
      // The launch plan degrades this to whatever the build accepts, so a
      // preference the CLI has never heard of costs a note rather than a run.
      // Downward only: this list used to put `high` second, so a build that
      // did not accept the chosen level would upgrade the turn rather than
      // reduce it.
      effortPreference: effortLadder(s.effort),
    );
  }
}
