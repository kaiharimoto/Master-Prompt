// `AppExitResponse` is a dart:ui type; Flutter uses it without re-exporting it.
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../app.dart';
import '../flow/flow_controller.dart';
import '../store/app_store.dart';
import '../store/claude_chat.dart';
import '../store/desktop_runner.dart';
import '../store/project.dart';
import '../update/updater.dart';
import '../widgets/exchange.dart';
import 'destinations.dart';
import 'present.dart';
import 'flow_screen.dart';
import 'progress_sheet.dart';
import 'prompt_screen.dart';
import 'run_screen.dart';
import 'settings_screen.dart';
import 'transcript_screen.dart';
import 'update_sheet.dart';

/// The shell around the flow.
///
/// There is no tab bar. The first build put four dashboards behind four tabs
/// and made the user choose between them before doing anything; the app now
/// shows the one thing that is next, and everything else waits in a menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    this.updater,
    this.runner,
    this.chat,
    super.key,
  });

  final AppStore store;

  /// Supplied by the app so the launch check and the menu share one state.
  /// Optional so a test can render the shell without one.
  final Updater? updater;

  /// The CLI connection and the conversation held over it. Both optional, and
  /// both injectable, because a widget test cannot run a real process at all.
  final DesktopRunner? runner;
  final ClaudeChat? chat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlowController _flow = FlowController();
  late final Updater _updater = widget.updater ?? Updater();

  /// One CLI connection for the whole app. Settings tests it, the Run screen
  /// uses it, and the flow talks to it — three probes would be free to
  /// disagree about whether Claude Code is installed.
  late final DesktopRunner _runner = widget.runner ?? DesktopRunner();
  late final ClaudeChat _chat = widget.chat ?? ClaudeChat(runner: _runner);

  /// Which destination the wide layout is showing in its content pane, if any.
  ///
  /// On a phone these are pushed routes, which is right: there is only ever
  /// one column and a back arrow is the way out. On a desktop a push covers
  /// the rail as well, so opening Settings blanks a 1600px window into a phone
  /// page and the missions you were switching between disappear.
  AppDestination? _panel;

  /// Intercepts closing the window while a run is going.
  ///
  /// A run in progress dies with the process, and the one most worth keeping
  /// is a run paused for a five-hour limit and waiting to resume — hours of
  /// waiting, ended by a click on the wrong corner. The engine consumes the
  /// first WM_CLOSE precisely so the framework can answer, but only when
  /// something has registered for `didRequestAppExit`; nothing had, so the
  /// close was a one-click unconfirmed kill.
  ///
  /// This is the whole of it, and none of it is native: the Windows runner
  /// already routes the message.
  AppLifecycleListener? _exit;

  @override
  void initState() {
    super.initState();
    if (DesktopRunner.isSupported) {
      _exit = AppLifecycleListener(onExitRequested: _onExitRequested);
    }
  }

  Future<AppExitResponse> _onExitRequested() async {
    if (!_runner.isBusy) return AppExitResponse.exit;
    final bool leave = await _confirmClose() ?? false;
    return leave ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  Future<bool?> _confirmClose() {
    final DateTime? resumeAt = _runner.resumeAt;
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('A run is still going'),
        content: Text(
          resumeAt != null
              ? 'It is waiting out a usage limit and is due to resume at '
                    '${resumeAt.toLocal().hour.toString().padLeft(2, '0')}:'
                    '${resumeAt.toLocal().minute.toString().padLeft(2, '0')}. '
                    'Closing now ends it — the schedule is on disk and the '
                    'run can be continued from the Run screen, but nothing '
                    'will happen while the app is shut.'
              : 'Closing now ends it. The run is saved and can be continued '
                    'from the Run screen, but the work in flight stops here.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep running'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close anyway'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _exit?.dispose();
    _flow.dispose();
    if (widget.runner == null) _runner.dispose();
    if (widget.chat == null) _chat.dispose();
    if (widget.updater == null) _updater.dispose();
    super.dispose();
  }

  /// A different mission is a different conversation. Resuming the last one
  /// would carry another mission's settled answers in as if they were this
  /// one's.
  void _newRound() {
    _flow.reset();
    _chat.reset();
    // A pane about the old mission has nothing to say about the new one.
    _closePanel();
  }

  void _open(AppDestination d) {
    final Project? p = widget.store.current;
    if (d.needsMission && p == null) return;

    switch (d) {
      case AppDestination.update:
        UpdateSheet.show(context, _updater);
      case AppDestination.progress:
        present(
          context,
          builder: (BuildContext context) =>
              ProgressSheet(project: p!, draggable: !isDesktop(context)),
        );
      case AppDestination.missions:
        present(
          context,
          builder: (BuildContext context) =>
              _MissionPicker(store: widget.store, onPicked: _newRound),
        );
      case AppDestination.brief:
      case AppDestination.run:
      case AppDestination.transcript:
      case AppDestination.settings:
        if (isDesktop(context)) {
          setState(() => _panel = d);
        } else {
          _push(d.label, _screenFor(d, p));
        }
    }
  }

  void _closePanel() => setState(() => _panel = null);

  Widget _screenFor(AppDestination d, Project? p) => switch (d) {
    AppDestination.brief => PromptScreen(
      store: widget.store,
      project: p!,
      runner: _runner,
    ),
    AppDestination.run => RunScreen(
      store: widget.store,
      project: p!,
      runner: _runner,
    ),
    AppDestination.transcript => TranscriptScreen(project: p!),
    AppDestination.settings => SettingsScreen(
      store: widget.store,
      updater: _updater,
      runner: _runner,
    ),
    // The three that are never a pane: they are sheets, or a dialog.
    _ => const SizedBox.shrink(),
  };

  void _push(String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final MpColors c = MpTheme.colorsOf(context);
          // Escape closes a pushed screen, which is what every other desktop
          // program does and what Flutter gives a route none of by default.
          // None of these screens autofocuses a field, so taking focus here
          // cannot steal a caret from one.
          return MpEscape(
            child: Scaffold(
              backgroundColor: c.canvas,
              appBar: AppBar(
                backgroundColor: c.canvas,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  title,
                  style: MpType.heading.copyWith(color: c.ink),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: c.line),
                ),
              ),
              body: SafeArea(top: false, child: child),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[widget.store, _updater, _chat]),
      builder: (BuildContext context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool wide = isDesktop(context);

    if (!widget.store.isLoaded) {
      return Scaffold(backgroundColor: c.canvas, body: const SizedBox.shrink());
    }

    final Project? p = widget.store.current;
    final Widget flow = FlowScreen(
      store: widget.store,
      flow: _flow,
      chat: _chat,
      onOpen: _open,
    );

    final PreferredSizeWidget bar = AppBar(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: MpSpace.lg,
      title: p == null
          ? Text('MASTER PROMPT', style: MpType.eyebrow.copyWith(color: c.ink))
          : _Progress(project: p),
      actions: <Widget>[
        _RunLight(runner: _runner, onTap: () => _open(AppDestination.run)),
        _Menu(
          enabled: p != null,
          hasUpdate: _updater.hasUpdate,
          onSelected: _open,
        ),
        const SizedBox(width: MpSpace.sm),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.line),
      ),
    );

    // A pane about a mission cannot outlive the mission. Deselecting one with
    // the Brief open would otherwise build a screen with nothing to show it.
    final AppDestination? pane =
        _panel != null && _panel!.needsMission && p == null ? null : _panel;

    if (wide) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              // Switching missions is genuinely a desktop activity, so the rail
              // stays where there is room for it.
              _Rail(store: widget.store, onNew: _newRound, onOpen: _open),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: <Widget>[
                    // The header is unconditional. It used to be built only
                    // when a mission was selected, which meant a fresh desktop
                    // install had no menu at all — and therefore no way to
                    // reach Settings and connect the Claude Code CLI, which is
                    // the first thing a desktop user needs to do.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        MpSpace.lg,
                        MpSpace.md,
                        MpSpace.lg,
                        MpSpace.md,
                      ),
                      child: Row(
                        children: <Widget>[
                          if (pane != null) ...<Widget>[
                            IconButton(
                              icon: const Icon(Icons.arrow_back, size: 22),
                              tooltip: 'Back to the mission',
                              onPressed: _closePanel,
                            ),
                            const SizedBox(width: MpSpace.sm),
                          ],
                          Expanded(
                            child: pane != null
                                ? Text(
                                    pane.label,
                                    style: MpType.heading.copyWith(
                                      color: c.ink,
                                    ),
                                  )
                                : p == null
                                ? Text(
                                    'No mission open',
                                    style: MpType.label.copyWith(
                                      color: c.inkFaint,
                                    ),
                                  )
                                : _Progress(project: p),
                          ),
                          _RunLight(
                            runner: _runner,
                            onTap: () => _open(AppDestination.run),
                          ),
                          _Menu(
                            enabled: p != null,
                            hasUpdate: _updater.hasUpdate,
                            onSelected: _open,
                          ),
                        ],
                      ),
                    ),
                    const MpRule(),
                    Expanded(
                      // Escape leaves a pane exactly as it leaves a pushed
                      // route on a phone, so the two behave the same way.
                      child: pane == null
                          ? flow
                          : MpEscape(
                              onEscape: _closePanel,
                              child: _screenFor(pane, p),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: bar,
      body: SafeArea(top: false, child: flow),
    );
  }
}

/// That a run is going, from anywhere in the app.
///
/// Close the Run pane and a twelve-hour run was invisible: the app bar shows
/// interview readiness, which stops moving the moment the brief is finished,
/// so the screen looked identical whether an agent was working or nothing was.
/// Quiet by design — a dot and a word, and nothing at all when nothing is
/// running.
class _RunLight extends StatelessWidget {
  const _RunLight({required this.runner, required this.onTap});

  final DesktopRunner runner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    return ListenableBuilder(
      listenable: runner,
      builder: (BuildContext context, _) {
        if (!runner.isBusy) return const SizedBox.shrink();
        final bool paused = runner.status == DesktopRunStatus.paused;

        return Padding(
          padding: const EdgeInsets.only(right: MpSpace.xs),
          child: Tooltip(
            message: paused
                ? 'Waiting out a usage limit. Open the run to see when it '
                      'resumes.'
                : 'A run is going. Open it to watch.',
            child: TextButton.icon(
              onPressed: onTap,
              icon: Icon(
                paused ? Icons.pause_circle_outline : Icons.circle,
                size: paused ? 16 : 10,
                color: paused ? c.warning : c.success,
              ),
              label: Text(
                paused ? 'Paused' : 'Running',
                style: MpType.caption.copyWith(
                  color: paused ? c.warning : c.inkMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The mission and how far through it we are, in one quiet line.
class _Progress extends StatelessWidget {
  const _Progress({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final ReadinessReport r = const InterviewEngine().assess(project.spec);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          project.title,
          style: MpType.label.copyWith(color: c.ink),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 6),
        MpSteps(
          step: r.canCompile ? InterviewStage.stepCount : r.currentStage.step,
          total: InterviewStage.stepCount,
        ),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.enabled,
    required this.hasUpdate,
    required this.onSelected,
  });

  final bool enabled;

  /// Adds the update entry and a mark on the icon. Both disappear again once
  /// there is nothing waiting, so the mark always means the same thing.
  final bool hasUpdate;

  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final List<AppDestination> items = <AppDestination>[
      if (hasUpdate) AppDestination.update,
      ...AppDestination.standing,
    ];

    return PopupMenuButton<AppDestination>(
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Icon(Icons.more_horiz, color: c.inkMuted, size: 24),
          if (hasUpdate)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      tooltip: hasUpdate ? 'More — an update is waiting' : 'More',
      color: c.surfaceRaised,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppDestination>>[
        for (final AppDestination d in items)
          PopupMenuItem<AppDestination>(
            value: d,
            enabled: enabled || !d.needsMission,
            child: Row(
              children: <Widget>[
                Icon(
                  d.icon,
                  size: 20,
                  color: d == AppDestination.update ? c.warning : c.inkMuted,
                ),
                const SizedBox(width: MpSpace.md),
                // A popup menu is 256 wide by default and its row is not
                // free to grow, so a long label overflows rather than wraps.
                Expanded(
                  child: Text(
                    d.label,
                    style: MpType.body.copyWith(color: c.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.store, required this.onNew, required this.onOpen});

  final AppStore store;
  final VoidCallback onNew;
  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MpSpace.lg,
              MpSpace.lg,
              MpSpace.lg,
              MpSpace.md,
            ),
            child: Text(
              'MASTER PROMPT',
              style: MpType.eyebrow.copyWith(color: c.ink),
            ),
          ),
          const MpRule(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: MpSpace.sm),
              children: <Widget>[
                for (final Project p in store.projects)
                  _RailItem(
                    project: p,
                    selected: p.id == store.current?.id,
                    onTap: () {
                      store.select(p.id);
                      onNew();
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MpSpace.md),
            child: MpButton(
              label: 'New mission',
              icon: Icons.add,
              expand: true,
              onPressed: () {
                store.deselect();
                onNew();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MpSpace.lg,
          vertical: MpSpace.md,
        ),
        color: selected ? c.surface : Colors.transparent,
        child: Row(
          children: <Widget>[
            Container(
              width: 2,
              height: 24,
              color: selected ? c.ink : Colors.transparent,
            ),
            const SizedBox(width: MpSpace.md),
            Expanded(
              child: Text(
                project.title,
                style: MpType.body.copyWith(
                  color: selected ? c.ink : c.inkMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionPicker extends StatefulWidget {
  const _MissionPicker({required this.store, required this.onPicked});

  final AppStore store;
  final VoidCallback onPicked;

  @override
  State<_MissionPicker> createState() => _MissionPickerState();
}

class _MissionPickerState extends State<_MissionPicker> {
  String? _note;
  Color? _noteTone;

  /// Read a mission sent from another device.
  ///
  /// A paste rather than a file picker, deliberately: opening a file is the one
  /// thing `masterprompt/platform` cannot do, and adding it would be new native
  /// code on two platforms that no test on a Linux runner could execute. The
  /// text of an `.mpx` is the whole bundle, so a paste carries everything a
  /// file would.
  ///
  /// A paste is never discarded: a bundle that cannot be read says what was
  /// seen instead, and leaves the text where it is.
  Future<void> _import(String text) async {
    final MpColors c = MpTheme.colorsOf(context);
    try {
      final MissionBundle b = MissionBundle.decode(text);
      await widget.store.importBundle(b);
      if (!mounted) return;
      widget.onPicked();
      Navigator.of(context).pop();
    } on BundleFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _note = '$e';
        _noteTone = c.danger;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _note = 'That did not read as a mission file. $e';
        _noteTone = c.danger;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final AppStore store = widget.store;
    final Project? current = store.current;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MpSpace.lg,
          0,
          MpSpace.lg,
          MpSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Missions', style: MpType.title.copyWith(color: c.ink)),
            const SizedBox(height: MpSpace.md),
            // Everything below the title scrolls together. The list used to be
            // the only scrollable part, with the controls fixed beneath it, so
            // opening the transfer disclosure overflowed the sheet by 384px on
            // a phone.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final Project p in store.projects)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.title,
                        style: MpType.body.copyWith(color: c.ink),
                      ),
                      subtitle: Text(
                        p.spec.taskId,
                        style: MpType.caption.copyWith(color: c.inkFaint),
                      ),
                      selected: p.id == current?.id,
                      onTap: () {
                        store.select(p.id);
                        widget.onPicked();
                        Navigator.of(context).pop();
                      },
                    ),
                  const SizedBox(height: MpSpace.md),
                  MpButton(
                    label: 'New mission',
                    icon: Icons.add,
                    expand: true,
                    kind: MpButtonKind.primary,
                    onPressed: () {
                      store.deselect();
                      widget.onPicked();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: MpSpace.md),
                  // The bundle has round-tripped and been fully tested
                  // since it was written, and nothing in the app could
                  // produce or read one — so a mission started on the phone
                  // and continued at the desk had no route between the two at
                  // all. Behind a disclosure because most openings of this
                  // sheet are just switching mission.
                  MpDisclosure(
                    label: 'Move a mission between devices',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (current != null) ...<Widget>[
                          // Built once. Called twice it encoded the whole
                          // mission twice per frame — and stamped each with
                          // its own `exportedAt`, so the file name and the
                          // document inside it could disagree about the date.
                          Builder(
                            builder: (BuildContext context) {
                              final MissionBundle b = _bundleFor(current);
                              return MpOutbound(
                                title: 'This mission as a file',
                                subtitle:
                                    'The spec, the brief, the last reported '
                                    'progress and the exchanges. Nothing '
                                    'device-specific travels — no session, no '
                                    'paths — so it opens cleanly wherever it '
                                    'lands.',
                                document: b.encode(),
                                note:
                                    'A Master Prompt mission file. Open Master '
                                    'Prompt on the other device, choose Missions, '
                                    'and paste it under "Move a mission between '
                                    'devices".',
                                fileName: b.suggestedFileName,
                                limit: store.settings.pasteLimit,
                              );
                            },
                          ),
                          const SizedBox(height: MpSpace.md),
                        ],
                        MpInbound(
                          onSubmit: _import,
                          hint: 'Paste a mission file from another device',
                          actionLabel: 'Bring it in',
                        ),
                        if (_note != null) ...<Widget>[
                          const SizedBox(height: MpSpace.md),
                          MpPanel(
                            accent: _noteTone,
                            child: Text(
                              _note!,
                              style: MpType.prose.copyWith(color: c.inkMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MissionBundle _bundleFor(Project p) => MissionBundle.from(
    spec: p.spec,
    compiled: p.compiled,
    state: p.lastState,
    producedArtifacts: p.producedArtifacts,
    history: <BundleExchange>[
      for (final TranscriptEntry e in p.transcript)
        BundleExchange(
          sent: e.direction == TranscriptDirection.sent,
          text: e.text,
          at: e.at,
          note: e.note,
        ),
    ],
  );
}
