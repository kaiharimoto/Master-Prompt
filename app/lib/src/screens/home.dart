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
        // Ghost first, then the one that does something — and the one that
        // does something here is keeping the run, not ending it.
        actions: <Widget>[
          MpButton(
            label: 'Close anyway',
            kind: MpButtonKind.quiet,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          MpButton(
            label: 'Keep running',
            kind: MpButtonKind.primary,
            onPressed: () => Navigator.of(context).pop(false),
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
              backgroundColor: c.paper,
              appBar: AppBar(
                title: Text(
                  title,
                  style: MpType.heading.copyWith(color: c.ink),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: c.ink),
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

    // A pane about a mission cannot outlive the mission. Deselecting one with
    // the Brief open would otherwise build a screen with nothing to show it.
    final AppDestination? pane =
        _panel != null && _panel!.needsMission && p == null ? null : _panel;

    final Widget runLight = _RunLight(
      runner: _runner,
      onTap: () => _open(AppDestination.run),
    );
    final Widget menu = _Menu(
      enabled: p != null,
      hasUpdate: _updater.hasUpdate,
      onSelected: _open,
    );

    if (wide) {
      // The Master UI shell: a 40px title bar across the top carrying the
      // wordmark and the system status, the index rail down the left, and the
      // page beside it — each region divided from the next by an ink rule.
      return Scaffold(
        backgroundColor: c.paper,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              // The bar is unconditional, and so is the menu in it. It used to
              // be built only when a mission was selected, which meant a fresh
              // desktop install had no menu at all — and therefore no way to
              // reach Settings and connect the Claude Code CLI, which is the
              // first thing a desktop user needs to do.
              Container(
                height: MpSpace.titleBar,
                padding: const EdgeInsets.only(left: 20, right: MpSpace.sm),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.ink)),
                ),
                child: Row(
                  children: <Widget>[
                    const MpWordmark(),
                    const Spacer(),
                    runLight,
                    menu,
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Switching missions is genuinely a desktop activity, so
                    // the rail stays where there is room for it.
                    _Rail(store: widget.store, onNew: _newRound),
                    Container(width: 1, color: c.ink),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            padding: EdgeInsets.fromLTRB(
                              pane != null ? MpSpace.sm : MpSpace.xl,
                              MpSpace.sm,
                              MpSpace.xl,
                              MpSpace.sm,
                            ),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: c.ink)),
                            ),
                            alignment: Alignment.centerLeft,
                            child: pane != null
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back),
                                        tooltip: 'Back to the mission',
                                        onPressed: _closePanel,
                                      ),
                                      const SizedBox(width: MpSpace.sm),
                                      MpNumeral(pane.index),
                                      const SizedBox(width: MpSpace.smd),
                                      Text(
                                        pane.label,
                                        style: MpType.heading.copyWith(
                                          color: c.ink,
                                        ),
                                      ),
                                    ],
                                  )
                                : p == null
                                ? Text(
                                    'NO MISSION OPEN',
                                    style: MpType.eyebrow.copyWith(
                                      color: c.ink45,
                                    ),
                                  )
                                : _Progress(project: p, wide: true),
                          ),
                          Expanded(
                            // Escape leaves a pane exactly as it leaves a
                            // pushed route on a phone, so the two behave the
                            // same way.
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
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.paper,
      appBar: AppBar(
        titleSpacing: MpSpace.lg,
        toolbarHeight: p == null ? 48 : 56,
        title: p == null ? const MpWordmark() : _Progress(project: p),
        actions: <Widget>[
          runLight,
          menu,
          const SizedBox(width: MpSpace.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.ink),
        ),
      ),
      body: SafeArea(top: false, child: flow),
    );
  }
}

/// That a run is going, from anywhere in the app.
///
/// Close the Run pane and a twelve-hour run was invisible: the app bar shows
/// interview readiness, which stops moving the moment the brief is finished,
/// so the screen looked identical whether an agent was working or nothing was.
/// Quiet by design — the family's breathing square and a micro-caps word, and
/// nothing at all when nothing is running. Paused is the same square, still.
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

        return Tooltip(
          message: paused
              ? 'Waiting out a usage limit. Open the run to see when it '
                    'resumes'
              : 'A run is going. Open it to watch',
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MpSpace.smd,
                vertical: MpSpace.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  MpLiveSquare(live: !paused),
                  const SizedBox(width: MpSpace.sm),
                  Text(
                    paused ? 'PAUSED' : 'RUNNING',
                    style: MpType.eyebrow.copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The mission and how far through it we are: its name, and the numbered
/// strip of stages with the current one inverted.
class _Progress extends StatelessWidget {
  const _Progress({required this.project, this.wide = false});

  final Project project;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final ReadinessReport r = const InterviewEngine().assess(project.spec);
    final Widget title = Text(
      project.title,
      style: MpType.rowTitle.copyWith(color: c.ink),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
    final Widget steps = MpSteps(
      step: r.canCompile ? InterviewStage.stepCount : r.currentStage.step,
      total: InterviewStage.stepCount,
    );

    if (wide) {
      return Row(
        children: <Widget>[
          Expanded(child: title),
          const SizedBox(width: MpSpace.lg),
          steps,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[title, const SizedBox(height: 6), steps],
    );
  }
}

/// Everything that is not the flow, as a numbered list in an ink frame.
///
/// Navigation is numbered, never iconned. The update entry, when there is one,
/// is marked by a 6px square on the trigger rather than by a colour.
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
          Icon(Icons.more_horiz, color: c.ink, size: 20),
          if (hasUpdate)
            Positioned(
              right: -2,
              top: -2,
              child: Container(width: 6, height: 6, color: c.ink),
            ),
        ],
      ),
      tooltip: hasUpdate ? 'More — an update is waiting' : 'More',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 208),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppDestination>>[
        for (int i = 0; i < items.length; i++)
          PopupMenuItem<AppDestination>(
            value: items[i],
            height: 40,
            enabled: enabled || !items[i].needsMission,
            child: Row(
              children: <Widget>[
                MpNumeral(i + 1),
                const SizedBox(width: MpSpace.smd),
                // A popup menu is 256 wide by default and its row is not
                // free to grow, so a long label overflows rather than wraps.
                Expanded(
                  child: Text(
                    items[i].label,
                    style: MpType.label.copyWith(
                      color: c.ink,
                      fontWeight: items[i] == AppDestination.update
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
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

/// The index rail: every mission, numbered, the open one inverted.
class _Rail extends StatelessWidget {
  const _Rail({required this.store, required this.onNew});

  final AppStore store;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return SizedBox(
      width: MpSpace.railWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(
              20,
              MpSpace.smd,
              20,
              MpSpace.smd,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.ink12)),
            ),
            child: Text(
              'MISSIONS',
              style: MpType.eyebrow.copyWith(color: c.ink45),
            ),
          ),
          Expanded(
            child: store.projects.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'NOTHING YET',
                      style: MpType.eyebrow.copyWith(color: c.ink45),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      for (int i = 0; i < store.projects.length; i++)
                        _MissionRow(
                          project: store.projects[i],
                          index: i + 1,
                          selected: store.projects[i].id == store.current?.id,
                          onTap: () {
                            store.select(store.projects[i].id);
                            onNew();
                          },
                        ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(MpSpace.md),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.ink)),
            ),
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

/// One mission in a list: its numeral and its name, a hairline under it, a
/// wash on hover, and inverted when it is the one open.
class _MissionRow extends StatefulWidget {
  const _MissionRow({
    required this.project,
    required this.index,
    required this.selected,
    required this.onTap,
    this.showId = false,
  });

  final Project project;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  /// Whether to show the task id under the name, where there is room for it.
  final bool showId;

  @override
  State<_MissionRow> createState() => _MissionRowState();
}

class _MissionRowState extends State<_MissionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool on = widget.selected;
    final Color fg = on ? c.paper : c.ink;

    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (bool v) => setState(() => _hover = v),
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: MpMotion.fast,
          curve: MpMotion.ease,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: MpSpace.smd,
          ),
          decoration: BoxDecoration(
            color: on
                ? c.ink
                : _hover
                ? c.ink06
                : Colors.transparent,
            border: Border(bottom: BorderSide(color: c.ink12)),
          ),
          child: Row(
            children: <Widget>[
              MpNumeral(
                widget.index,
                color: on ? c.paper.withValues(alpha: 0.6) : c.ink45,
              ),
              const SizedBox(width: MpSpace.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.project.title,
                      style: MpType.rowTitle.copyWith(color: fg),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (widget.showId) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        widget.project.spec.taskId,
                        style: MpType.numeral.copyWith(
                          color: on ? c.paper.withValues(alpha: 0.6) : c.ink45,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: MpMotion.fast,
                opacity: _hover && !on ? 1 : 0,
                child: AnimatedSlide(
                  duration: MpMotion.fast,
                  curve: MpMotion.ease,
                  offset: _hover ? Offset.zero : const Offset(-0.3, 0),
                  child: Text('→', style: MpType.body.copyWith(color: fg)),
                ),
              ),
            ],
          ),
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
            Text('Missions', style: MpType.heading.copyWith(color: c.ink)),
            const SizedBox(height: MpSpace.md),
            // Everything below the title scrolls together. The list used to be
            // the only scrollable part, with the controls fixed beneath it, so
            // opening the transfer disclosure overflowed the sheet by 384px on
            // a phone.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  if (store.projects.isNotEmpty) const MpRule(strong: true),
                  for (int i = 0; i < store.projects.length; i++)
                    _MissionRow(
                      project: store.projects[i],
                      index: i + 1,
                      showId: true,
                      selected: store.projects[i].id == current?.id,
                      onTap: () {
                        store.select(store.projects[i].id);
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
