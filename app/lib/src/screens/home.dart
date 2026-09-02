import 'package:flutter/material.dart';
import 'package:mp_design/mp_design.dart';

import '../app.dart';
import '../store/app_store.dart';
import '../store/project.dart';
import 'interview_screen.dart';
import 'prompt_screen.dart';
import 'run_screen.dart';
import 'settings_screen.dart';

/// The four working views, in the order a mission moves through them.
enum MpView { interview, prompt, run, settings }

extension on MpView {
  String get label => switch (this) {
    MpView.interview => 'Discuss',
    MpView.prompt => 'Brief',
    MpView.run => 'Run',
    MpView.settings => 'Settings',
  };

  IconData get icon => switch (this) {
    MpView.interview => Icons.forum_outlined,
    MpView.prompt => Icons.description_outlined,
    MpView.run => Icons.play_circle_outline,
    MpView.settings => Icons.tune,
  };

  String get number => switch (this) {
    MpView.interview => '01',
    MpView.prompt => '02',
    MpView.run => '03',
    MpView.settings => '04',
  };
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MpView _view = MpView.interview;

  @override
  Widget build(BuildContext context) {
    // The screen listens to the store itself rather than relying on an
    // ancestor to rebuild it, so creating or selecting a mission updates the
    // view wherever HomeScreen is mounted.
    return ListenableBuilder(
      listenable: widget.store,
      builder: (BuildContext context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool wide = isDesktop(context);

    if (!widget.store.isLoaded) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final Project? project = widget.store.current;

    if (project == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MpSpace.xl),
            child: MpEmpty(
              title: 'No missions yet',
              detail:
                  'A mission starts as a conversation. The app will interview '
                  'you until the brief is complete enough to run unattended.',
              action: MpButton(
                label: 'Start a mission',
                kind: MpButtonKind.primary,
                icon: Icons.add,
                onPressed: () => widget.store.create(),
              ),
            ),
          ),
        ),
      );
    }

    final Widget body = switch (_view) {
      MpView.interview => InterviewScreen(
        store: widget.store,
        project: project,
      ),
      MpView.prompt => PromptScreen(store: widget.store, project: project),
      MpView.run => RunScreen(store: widget.store, project: project),
      MpView.settings => SettingsScreen(store: widget.store),
    };

    if (wide) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              _Rail(
                store: widget.store,
                view: _view,
                onView: (MpView v) => setState(() => _view = v),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: MpSpace.md,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              project.title,
              style: MpType.heading.copyWith(color: c.ink),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              project.spec.taskId,
              style: MpType.caption.copyWith(color: c.inkFaint),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.folder_outlined, size: 20),
            tooltip: 'Missions',
            onPressed: () => _showProjects(context),
          ),
          const SizedBox(width: MpSpace.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.line),
        ),
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: NavigationBar(
          backgroundColor: c.canvas,
          surfaceTintColor: Colors.transparent,
          indicatorColor: c.line,
          height: 62,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _view.index,
          onDestinationSelected: (int i) =>
              setState(() => _view = MpView.values[i]),
          destinations: <Widget>[
            for (final MpView v in MpView.values)
              NavigationDestination(
                icon: Icon(v.icon, size: 20),
                label: v.label,
              ),
          ],
        ),
      ),
    );
  }

  void _showProjects(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MpSpace.md,
            0,
            MpSpace.md,
            MpSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const MpSectionHeader(number: '00', title: 'Missions'),
              const SizedBox(height: MpSpace.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final Project p in widget.store.projects)
                      ListTile(
                        title: Text(p.title, style: MpType.body),
                        subtitle: Text(
                          p.spec.taskId,
                          style: MpType.caption.copyWith(color: c.inkFaint),
                        ),
                        selected: p.id == widget.store.current?.id,
                        onTap: () {
                          widget.store.select(p.id);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: MpSpace.sm),
              MpButton(
                label: 'New mission',
                icon: Icons.add,
                expand: true,
                kind: MpButtonKind.primary,
                onPressed: () {
                  widget.store.create();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The desktop left rail: missions above, views below.
class _Rail extends StatelessWidget {
  const _Rail({required this.store, required this.view, required this.onView});

  final AppStore store;
  final MpView view;
  final ValueChanged<MpView> onView;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MpSpace.md,
              MpSpace.lg,
              MpSpace.md,
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
                  _RailProject(
                    project: p,
                    selected: p.id == store.current?.id,
                    onTap: () => store.select(p.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MpSpace.sm),
            child: MpButton(
              label: 'New mission',
              icon: Icons.add,
              expand: true,
              onPressed: () => store.create(),
            ),
          ),
          const MpRule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MpSpace.sm),
            child: Column(
              children: <Widget>[
                for (final MpView v in MpView.values)
                  _RailView(
                    view: v,
                    selected: v == view,
                    onTap: () => onView(v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailProject extends StatelessWidget {
  const _RailProject({
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
          horizontal: MpSpace.md,
          vertical: MpSpace.sm + 2,
        ),
        color: selected ? c.surface : Colors.transparent,
        child: Row(
          children: <Widget>[
            Container(
              width: 2,
              height: 26,
              color: selected ? c.ink : Colors.transparent,
            ),
            const SizedBox(width: MpSpace.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    project.title,
                    style: MpType.body.copyWith(
                      color: selected ? c.ink : c.inkMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    project.spec.taskId,
                    style: MpType.caption.copyWith(color: c.inkFaint),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailView extends StatelessWidget {
  const _RailView({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final MpView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MpSpace.md,
          vertical: MpSpace.sm + 2,
        ),
        child: Row(
          children: <Widget>[
            Text(
              view.number,
              style: MpType.eyebrow.copyWith(
                color: selected ? c.ink : c.inkFaint,
              ),
            ),
            const SizedBox(width: MpSpace.md),
            Text(
              view.label,
              style: MpType.body.copyWith(color: selected ? c.ink : c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
