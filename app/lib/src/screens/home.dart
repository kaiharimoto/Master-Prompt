import 'package:flutter/material.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../app.dart';
import '../flow/flow_controller.dart';
import '../store/app_store.dart';
import '../store/project.dart';
import 'destinations.dart';
import 'flow_screen.dart';
import 'progress_sheet.dart';
import 'prompt_screen.dart';
import 'run_screen.dart';
import 'settings_screen.dart';
import 'transcript_screen.dart';

/// The shell around the flow.
///
/// There is no tab bar. The first build put four dashboards behind four tabs
/// and made the user choose between them before doing anything; the app now
/// shows the one thing that is next, and everything else waits in a menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlowController _flow = FlowController();

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  void _open(AppDestination d) {
    final Project? p = widget.store.current;
    if (d.needsMission && p == null) return;

    switch (d) {
      case AppDestination.progress:
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: MpTheme.colorsOf(context).surfaceRaised,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (BuildContext context) => ProgressSheet(project: p!),
        );
      case AppDestination.missions:
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: MpTheme.colorsOf(context).surfaceRaised,
          showDragHandle: true,
          builder: (BuildContext context) =>
              _MissionPicker(store: widget.store, onPicked: _flow.reset),
        );
      case AppDestination.brief:
        _push(d.label, PromptScreen(store: widget.store, project: p!));
      case AppDestination.run:
        _push(d.label, RunScreen(store: widget.store, project: p!));
      case AppDestination.transcript:
        _push(d.label, TranscriptScreen(project: p!));
      case AppDestination.settings:
        _push(d.label, SettingsScreen(store: widget.store));
    }
  }

  void _push(String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final MpColors c = MpTheme.colorsOf(context);
          return Scaffold(
            backgroundColor: c.canvas,
            appBar: AppBar(
              backgroundColor: c.canvas,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(title, style: MpType.heading.copyWith(color: c.ink)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: c.line),
              ),
            ),
            body: SafeArea(top: false, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
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
        _Menu(enabled: p != null, onSelected: _open),
        const SizedBox(width: MpSpace.sm),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.line),
      ),
    );

    if (wide) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              // Switching missions is genuinely a desktop activity, so the rail
              // stays where there is room for it.
              _Rail(store: widget.store, onNew: _flow.reset, onOpen: _open),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: <Widget>[
                    if (p != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          MpSpace.lg,
                          MpSpace.md,
                          MpSpace.lg,
                          MpSpace.md,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: _Progress(project: p)),
                            _Menu(enabled: true, onSelected: _open),
                          ],
                        ),
                      ),
                    const MpRule(),
                    Expanded(child: flow),
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
  const _Menu({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return PopupMenuButton<AppDestination>(
      icon: Icon(Icons.more_horiz, color: c.inkMuted, size: 24),
      tooltip: 'More',
      color: c.surfaceRaised,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppDestination>>[
        for (final AppDestination d in AppDestination.values)
          PopupMenuItem<AppDestination>(
            value: d,
            enabled: enabled || !d.needsMission,
            child: Row(
              children: <Widget>[
                Icon(d.icon, size: 20, color: c.inkMuted),
                const SizedBox(width: MpSpace.md),
                Text(d.label, style: MpType.body.copyWith(color: c.ink)),
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

class _MissionPicker extends StatelessWidget {
  const _MissionPicker({required this.store, required this.onPicked});

  final AppStore store;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
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
                      selected: p.id == store.current?.id,
                      onTap: () {
                        store.select(p.id);
                        onPicked();
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: MpSpace.md),
            MpButton(
              label: 'New mission',
              icon: Icons.add,
              expand: true,
              kind: MpButtonKind.primary,
              onPressed: () {
                store.deselect();
                onPicked();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
