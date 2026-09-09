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
  DesktopRunner({CliLocator locator = const CliLocator()}) : _locator = locator;

  /// Injected so a widget test can have a connected CLI without one existing.
  /// Probing is real process work, which cannot complete inside the tester's
  /// fake-async zone at all.
  final CliLocator _locator;

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
  List<ProbeAttempt> _attempts = const <ProbeAttempt>[];

  RunHeartbeat? _heartbeat;
  int _attempt = 0;
  double? _costUsd;
  String? _sessionId;
  String? _workingDirectory;
  DateTime? _startedAt;
  Timer? _tick;
  ValueChanged<MpState>? _onState;

  /// What the run last said about itself.
  ///
  /// The brief demands an `mpstate` heartbeat on every reply and explains why
  /// on the CLI transport in particular — it doubles as a compaction detector,
  /// because micro-compaction is not observable from the event stream. Nothing
  /// read it. The block scrolled past in the log as three lines of
  /// `phase=build` among thousands, and the Progress panel said "nothing
  /// recorded yet" for twelve hours while the run reported its score, its
  /// phase, what it was blocked on and what it wanted to ask, every turn.
  MpState? get state => _heartbeat?.state;

  /// Which attempt is in flight. The supervisor has always emitted this and
  /// the adapter always threw it away, so a run on its seventh resume looked
  /// exactly like one that had just started.
  int get attempt => _attempt;

  /// Spent so far, summed over attempts. Null until the CLI reports one.
  double? get costUsd => _costUsd;

  /// The session the run is attached to — the thing that makes a resume a
  /// resume rather than a fresh start.
  String? get sessionId => _sessionId;

  /// Where the work is happening. The panel used to promise that the brief
  /// was written to the working directory without ever naming it, and by
  /// default it is a path inside application support that nobody has seen.
  String? get workingDirectory => _workingDirectory;

  /// What the brief asked for, checked against what is actually on disk.
  ///
  /// Null until a run ends. The supervisor's `completed` means the process
  /// exited zero and the CLI said `success` — a fact about the process, not
  /// about the mission — so a run that produced three of eleven artifacts and
  /// scored itself 61 against a threshold of 90 was painted the same green as
  /// one that met every gate.
  MissionOutcome? _outcome;
  MissionOutcome? get outcome => _outcome;

  /// How long the run has been going. A number that moves is the difference
  /// between "working" and "wedged", and over twelve hours it is most of what
  /// there is to look at.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Every candidate the last search tried, and what became of it.
  ///
  /// Shown whether or not the search succeeded: someone who does not know how
  /// they installed the CLI is told rather than asked, and the path that
  /// worked is worth seeing too.
  List<ProbeAttempt> get attempts => List<ProbeAttempt>.unmodifiable(_attempts);

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
  ///
  /// Does nothing while a run is in flight, and that guard is the whole of a
  /// fix for something close to fatal. The Run pane probes on arrival, so
  /// closing it and opening it again mid-run — or switching missions in the
  /// rail, which closes it for you — walked the status back to `locating` and
  /// then `idle`. `isBusy` went false with the supervisor still running, which
  /// took Stop off the screen, put Run back, and let a second click launch a
  /// second agent into the same directory under `bypassPermissions` while the
  /// first went on working with nothing left holding a handle to it.
  Future<void> detect(AppSettings settings) async {
    if (isBusy) return;
    _status = DesktopRunStatus.locating;
    _error = null;
    notifyListeners();
    final List<ProbeAttempt> log = <ProbeAttempt>[];
    try {
      _install = await _locator.locate(
        explicitPath: settings.claudePath,
        attempts: log,
      );
      _attempts = log;
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
      _attempts = e.attempts;
      _error = e.message;
      _status = DesktopRunStatus.failed;
    }
    notifyListeners();
  }

  /// A run on disk that could be picked up rather than started over.
  ///
  /// The store has always written one and nothing ever read one back, so
  /// reopening the app after a crash, a reboot or a stop showed a Run screen
  /// exactly as it was before anything happened: status idle, empty log, one
  /// button reading "Run this mission". Pressing it minted a fresh id with no
  /// session, and eleven hours of context went back to the start — while the
  /// panel said "Closing the app is safe" and the supervisor said "Sign in
  /// again, then resume this run".
  RunRecord? _resumable;
  RunRecord? get resumable => _resumable;

  Directory _runsIn(Directory stateDirectory) =>
      Directory('${stateDirectory.path}${Platform.pathSeparator}runs');

  /// Look for one, for this mission. Called when the Run screen opens.
  Future<void> lookForResumable({
    required Project project,
    required Directory stateDirectory,
  }) async {
    if (isBusy) return;
    final List<RunRecord> open = await RunStore(
      _runsIn(stateDirectory),
    ).resumable();
    RunRecord? found;
    for (final RunRecord r in open) {
      if (r.taskId == project.spec.taskId) {
        found = r;
        break;
      }
    }
    if (found == _resumable) return;
    _resumable = found;
    notifyListeners();
  }

  /// Launch the mission and supervise it until it finishes or stalls.
  ///
  /// Pass [resuming] to continue a run already on disk: its session id, its
  /// attempt history and its working directory all come from the record, which
  /// is the difference between reattaching and starting again.
  Future<void> start({
    required Project project,
    required AppSettings settings,
    required Directory stateDirectory,
    ValueChanged<MpState>? onState,
    RunRecord? resuming,
  }) async {
    if (isBusy) return;
    if (_install == null) await detect(settings);
    final ClaudeInstall? install = _install;
    if (install == null) return;

    // A resumed run continues where it was, whatever Settings says now.
    final String workingDirectory =
        resuming?.workingDirectory ??
        (settings.workingDirectory?.trim().isNotEmpty ?? false
            ? settings.workingDirectory!.trim()
            : '${stateDirectory.path}${Platform.pathSeparator}'
                  '${project.spec.taskId}');
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
    // A second run used to append to the first one's output with nothing
    // between them, so the top of the box was history and there was no way to
    // tell where.
    _log.clear();
    _attempt = 0;
    _costUsd = null;
    _sessionId = null;
    _record = null;
    _outcome = null;
    _resumable = null;
    _heartbeat = RunHeartbeat(expectedTaskId: project.spec.taskId);
    _onState = onState;
    _workingDirectory = wd.path;
    _startedAt = DateTime.now();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    notifyListeners();

    final RunSupervisor supervisor = RunSupervisor(
      executable: install.path,
      capabilities: install.capabilities,
      store: RunStore(_runsIn(stateDirectory)),
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
          _attempt = (e.record?.attempts.length ?? _attempt) + 1;
          _say(_attempt <= 1 ? 'Launching.' : 'Resuming — attempt $_attempt.');
        case 'event':
          // Only the assistant's own words go to the log; the raw stream is
          // written to disk in full by the supervisor.
          final CliEvent? c = e.cliEvent;
          _sessionId = c?.sessionId ?? _sessionId;
          if (c is ResultEvent && c.costUsd != null) {
            _costUsd = (_costUsd ?? 0) + c.costUsd!;
          }
          if (c is AssistantEvent &&
              !c.isSubagent &&
              c.text.trim().isNotEmpty) {
            final MpState? beat = _heartbeat?.read(c.text);
            if (beat != null) _onState?.call(beat);
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
        // A resumed record keeps its conclusion until the supervisor clears
        // it; a stopped run would otherwise be finished before it started.
        resuming?.copyWith(clearConclusion: true) ??
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
      _outcome = _inspect(project.spec, wd);
      final MissionOutcome? o = _outcome;
      if (o != null && o.hasGates && !o.met) {
        for (final Shortfall f in o.shortfalls) {
          _say('Not met: ${f.what}');
        }
      }
    } on Object catch (e) {
      _error = '$e';
      _status = DesktopRunStatus.failed;
    } finally {
      await supervisor.dispose();
      _supervisor = null;
      _tick?.cancel();
      _tick = null;
      notifyListeners();
    }
  }

  /// Which of the named evidence artifacts are actually there.
  ///
  /// By basename and recursively, because the brief fixes the file names but
  /// not where in the tree they land. Bounded, because a working directory can
  /// contain a whole checkout and walking all of it to answer a question about
  /// eleven files would be its own bug.
  MissionOutcome _inspect(MissionSpec spec, Directory wd) {
    final Set<String> present = <String>{};
    try {
      int seen = 0;
      for (final FileSystemEntity e in wd.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (++seen > 20000) break;
        if (e is! File) continue;
        try {
          if (e.lengthSync() > 0) {
            present.add(e.path.split(Platform.pathSeparator).last);
          }
        } on FileSystemException {
          // A file that cannot be measured is not counted as produced.
        }
      }
    } on FileSystemException catch (e) {
      _say('Could not check the working directory: $e');
    }
    return MissionCheck.inspect(
      spec: spec,
      filesPresent: present,
      reported: state,
    );
  }

  Future<void> stop() async {
    await _supervisor?.cancel();
    _say('Stopping at the next checkpoint.');
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_supervisor?.dispose());
    super.dispose();
  }
}
