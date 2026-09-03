import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_runner/mp_runner.dart';

import 'diagnostics.dart';
import 'project.dart';
import 'settings.dart';

/// Where a desktop run currently stands, for the UI.
enum DesktopRunStatus { idle, locating, running, paused, finished, failed }

/// Drives the Claude Code CLI for one mission and exposes progress.
///
/// Everything hard lives in mp_runner; this is the thin adapter that turns a
/// project plus settings into a run, and the supervisor's event stream into
/// something a widget can paint.
class DesktopRunner extends ChangeNotifier {
  DesktopRunner();

  static bool get isSupported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  DesktopRunStatus _status = DesktopRunStatus.idle;
  final List<String> _log = <String>[];
  ClaudeInstall? _install;
  RunSupervisor? _supervisor;
  RunRecord? _record;
  String? _error;
  DateTime? _resumeAt;
  LimitKind? _limitKind;

  DesktopRunStatus get status => _status;
  List<String> get log => List<String>.unmodifiable(_log);
  ClaudeInstall? get install => _install;
  RunRecord? get record => _record;
  String? get error => _error;

  /// When the supervisor intends to resume after a usage limit.
  DateTime? get resumeAt => _resumeAt;

  LimitKind? get limitKind => _limitKind;

  bool get isBusy =>
      _status == DesktopRunStatus.running ||
      _status == DesktopRunStatus.paused ||
      _status == DesktopRunStatus.locating;

  void _say(String line) {
    _log.add(line);
    // Mirrored so a run that misbehaves is visible in a pasted report, not only
    // in the on-screen log the user would have to transcribe by hand.
    Diagnostics.instance.log(
      'run: ${line.length > 160 ? '${line.substring(0, 160)}…' : line}',
    );
    // A twelve-hour run produces a great deal of output; the UI keeps a window
    // of it and the full stream stays on disk.
    if (_log.length > 500) _log.removeRange(0, _log.length - 500);
    notifyListeners();
  }

  /// Find the CLI and read what it supports.
  Future<void> detect(AppSettings settings) async {
    _status = DesktopRunStatus.locating;
    _error = null;
    notifyListeners();
    try {
      _install = await const CliLocator().locate(
        explicitPath: settings.claudePath,
      );
      _say(
        'Found Claude Code ${_install!.version} at ${_install!.path} '
        '(${_install!.authMode.name}).',
      );
      final List<String> effort =
          _install!.capabilities.choices['--effort'] ?? const <String>[];
      if (effort.isNotEmpty) {
        _say('This build accepts effort levels: ${effort.join(', ')}.');
      }
      _status = DesktopRunStatus.idle;
    } on ClaudeNotFound catch (e) {
      _error = '${e.message}\n\nSearched:\n${e.searched.join('\n')}';
      _status = DesktopRunStatus.failed;
    }
    notifyListeners();
  }

  /// Launch the mission and supervise it until it finishes or stalls.
  Future<void> start({
    required Project project,
    required AppSettings settings,
    required Directory stateDirectory,
  }) async {
    if (isBusy) return;
    if (_install == null) await detect(settings);
    final ClaudeInstall? install = _install;
    if (install == null) return;

    final String workingDirectory =
        settings.workingDirectory?.trim().isNotEmpty ?? false
        ? settings.workingDirectory!.trim()
        : '${stateDirectory.path}${Platform.pathSeparator}${project.spec.taskId}';
    final Directory wd = Directory(workingDirectory);
    if (!wd.existsSync()) wd.createSync(recursive: true);

    final CompiledPrompt compiled = const PromptCompiler().compile(
      project.spec,
    );
    // The brief also lands on disk, so a run is recoverable and auditable
    // without this app.
    File(
      '${wd.path}${Platform.pathSeparator}MASTER_PROMPT.md',
    ).writeAsStringSync(compiled.body);

    _status = DesktopRunStatus.running;
    _error = null;
    _resumeAt = null;
    _limitKind = null;
    notifyListeners();

    final RunSupervisor supervisor = RunSupervisor(
      executable: install.path,
      capabilities: install.capabilities,
      store: RunStore(
        Directory('${stateDirectory.path}${Platform.pathSeparator}runs'),
      ),
    );
    _supervisor = supervisor;

    supervisor.events.listen((SupervisorEvent e) {
      switch (e.kind) {
        case 'limited':
          _status = DesktopRunStatus.paused;
          _resumeAt = e.record?.scheduledResumeAt;
          _limitKind = e.record?.lastVerdict?.kind;
          _say(e.message);
        case 'launch':
          _status = DesktopRunStatus.running;
          _resumeAt = null;
          _say('Launching.');
        case 'event':
          // Only the assistant's own words go to the log; the raw stream is
          // written to disk in full by the supervisor.
          final CliEvent? c = e.cliEvent;
          if (c is AssistantEvent &&
              !c.isSubagent &&
              c.text.trim().isNotEmpty) {
            _say(c.text.trim());
          } else if (c is AssistantEvent && c.toolUses.isNotEmpty) {
            _say('· ${c.toolUses.join(', ')}');
          }
        case 'stderr':
          if (e.message.trim().isNotEmpty) _say('stderr: ${e.message.trim()}');
        default:
          _say(e.message);
      }
    });

    try {
      final RunRecord out = await supervisor.execute(
        RunRecord(
          runId: '${project.id}-${DateTime.now().millisecondsSinceEpoch}',
          taskId: project.spec.taskId,
          workingDirectory: wd.path,
          prompt: compiled.body,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      _record = out;
      _status = out.conclusion == RunConclusion.completed
          ? DesktopRunStatus.finished
          : DesktopRunStatus.failed;
      _say(
        'Run ${out.conclusion?.name ?? 'ended'} after '
        '${out.attempts.length} attempt(s).',
      );
    } on Object catch (e) {
      _error = '$e';
      _status = DesktopRunStatus.failed;
    } finally {
      await supervisor.dispose();
      _supervisor = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _supervisor?.cancel();
    _say('Stopping at the next checkpoint.');
  }

  @override
  void dispose() {
    unawaited(_supervisor?.dispose());
    super.dispose();
  }
}
