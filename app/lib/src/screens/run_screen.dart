import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';
import 'package:path_provider/path_provider.dart';

import '../store/app_store.dart';
import '../store/desktop_runner.dart';
import '../store/diagnostics.dart';
import '../store/project.dart';
import '../widgets/exchange.dart';

/// Where a mission actually runs, and where a usage limit stops being a
/// disaster.
///
/// On the desktop this drives the CLI. On a phone there is no CLI, so the same
/// mission is carried by hand — and the resume capsule is what makes that
/// survivable when Claude cuts the conversation off.
class RunScreen extends StatefulWidget {
  const RunScreen({required this.store, required this.project, super.key});

  final AppStore store;
  final Project project;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  static const StateParser _parser = StateParser();
  static const ResumeCapsuleBuilder _capsules = ResumeCapsuleBuilder();
  static const InterviewEngine _engine = InterviewEngine();

  String? _note;
  Color? _noteTone;
  bool _showCapsule = false;

  final DesktopRunner _runner = DesktopRunner();

  bool get _canRunLocally => DesktopRunner.isSupported;

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  Future<void> _applyState(String reply) async {
    final Project p = widget.project;
    final StateParseResult r = _parser.parse(
      reply,
      expectedTaskId: p.spec.taskId,
    );
    Diagnostics.instance.log(
      'State paste (${reply.length} chars): ${r.status.name}'
      '${r.repairs.isEmpty ? '' : ', repaired'}.',
    );

    // The raw paste is stored before anything else, always.
    await widget.store.addTranscript(
      p,
      TranscriptEntry(
        direction: TranscriptDirection.received,
        text: reply,
        at: DateTime.now().toUtc(),
        note: 'state: ${r.status.name}',
      ),
    );

    final MpColors c = MpTheme.colorsOf(context);
    if (r.canAdvanceState && r.state != null) {
      p.lastState = r.state;
      await widget.store.save(p);
      setState(() {
        _note = r.repairs.isEmpty
            ? 'State updated.'
            : 'State updated, after repairs: ${r.repairs.join(' ')}';
        _noteTone = c.success;
      });
    } else {
      setState(() {
        _note =
            r.diagnostic ?? 'That reply could not be read as a state block.';
        _noteTone = r.status == StateParseStatus.foreign ? c.danger : c.warning;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Project p = widget.project;
    final ReadinessReport report = _engine.assess(p.spec);

    if (!report.canCompile) {
      return const Padding(
        padding: EdgeInsets.all(MpSpace.xl),
        child: MpEmpty(
          title: 'Nothing to run yet',
          detail:
              'Finish the discussion first. A run started from an incomplete '
              'brief will stop to ask questions, which is exactly what this is '
              'meant to prevent.',
        ),
      );
    }

    final CompiledPrompt compiled = const PromptCompiler().compile(
      p.spec,
      profile: TransportProfile.paste,
    );
    final MpState? state = p.lastState;

    return ListView(
      padding: const EdgeInsets.all(MpSpace.md),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MpSpace.readingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const MpSectionHeader(number: '01', title: 'Progress'),
                const SizedBox(height: MpSpace.md),
                _StatePanel(state: state, spec: p.spec),

                const SizedBox(height: MpSpace.xl),
                MpSectionHeader(
                  number: '02',
                  title: _canRunLocally ? 'Run' : 'Carry the mission',
                  subtitle: _canRunLocally
                      ? 'The desktop runner drives the Claude Code CLI, detects '
                            'usage limits, and resumes automatically when they '
                            'lift.'
                      : 'Paste the brief into the Claude app, then bring each '
                            'reply back here. The app tracks progress from the '
                            'heartbeat block at the end of every reply.',
                ),
                const SizedBox(height: MpSpace.md),

                if (_canRunLocally)
                  _DesktopRunPanel(
                    runner: _runner,
                    project: p,
                    store: widget.store,
                  )
                else
                  MpOutbound(
                    title: 'Mission brief',
                    subtitle:
                        'Start a new Claude conversation and paste this first.',
                    text: compiled.body,
                    limit: widget.store.settings.pasteLimit,
                  ),

                const SizedBox(height: MpSpace.md),
                MpInbound(
                  onSubmit: _applyState,
                  hint: "Paste Claude's reply, including its mpstate block",
                  actionLabel: 'Record progress',
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

                const SizedBox(height: MpSpace.xl),
                MpSectionHeader(
                  number: '03',
                  title: 'If the conversation is cut off',
                  subtitle:
                      'A Pro plan will hit its limit partway through a long '
                      'mission. Start a fresh Claude chat and paste the capsule '
                      'below; it carries everything the new conversation needs '
                      'to continue from exactly here.',
                ),
                const SizedBox(height: MpSpace.md),
                if (!_showCapsule)
                  MpButton(
                    label: 'Build a resume capsule',
                    icon: Icons.restart_alt,
                    expand: true,
                    onPressed: () => setState(() => _showCapsule = true),
                  )
                else
                  _Capsule(
                    capsule: _capsules.build(
                      spec: p.spec,
                      state: state,
                      compiled: compiled,
                      producedArtifacts: p.producedArtifacts,
                    ),
                    limit: widget.store.settings.pasteLimit,
                  ),
                const SizedBox(height: MpSpace.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.state, required this.spec});

  final MpState? state;
  final MissionSpec spec;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    // Bound to a local so the null check promotes: a public field cannot be.
    final MpState? s = state;

    if (s == null) {
      return MpPanel(
        child: Text(
          'Nothing recorded yet. Progress appears here once a reply carrying an '
          'mpstate block has been pasted back.',
          style: MpType.prose.copyWith(color: c.inkMuted),
        ),
      );
    }

    final double scoreFraction = spec.rubric.total == 0
        ? 0
        : s.score / spec.rubric.total;
    final bool passing = s.score >= spec.rubric.exitThreshold;

    return MpPanel(
      accent: s.isBlocked ? c.danger : (passing ? c.success : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              MpTag(s.phase.name, tone: c.accent),
              const SizedBox(width: MpSpace.sm),
              if (s.cycle > 0) MpTag('cycle ${s.cycle}'),
              const Spacer(),
              Text(
                '${s.score.toStringAsFixed(0)} / ${spec.rubric.total}',
                style: MpType.numeric.copyWith(color: c.ink),
              ),
            ],
          ),
          const SizedBox(height: MpSpace.sm),
          MpMeter(value: scoreFraction, tone: passing ? c.success : c.ink),
          const SizedBox(height: MpSpace.xs),
          Text(
            'Exit at ${spec.rubric.exitThreshold}',
            style: MpType.caption.copyWith(color: c.inkFaint),
          ),
          if (s.step.isNotEmpty) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpField(
              label: 'Current step',
              child: Text(s.step, style: MpType.body.copyWith(color: c.ink)),
            ),
          ],
          if (s.next.isNotEmpty) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpField(
              label: 'Next action',
              child: Text(s.next, style: MpType.body.copyWith(color: c.ink)),
            ),
          ],
          if (s.isBlocked) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpField(
              label: 'Blocked',
              child: Text(
                s.blocked!,
                style: MpType.body.copyWith(color: c.danger),
              ),
            ),
          ],
          if (s.hasQuestion) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpField(
              label: 'Asking you',
              child: Text(s.ask!, style: MpType.body.copyWith(color: c.ink)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({required this.capsule, required this.limit});

  final ResumeCapsule capsule;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (capsule.droppedSections.isNotEmpty) ...<Widget>[
          MpPanel(
            accent: c.warning,
            child: Text(
              'Trimmed to fit: ${capsule.droppedSections.join(', ')}. The '
              'rubric, failure conditions and next action are always kept.',
              style: MpType.caption.copyWith(color: c.inkMuted),
            ),
          ),
          const SizedBox(height: MpSpace.sm),
        ],
        // One panel that steps, rather than a panel per part. Stacking four
        // of these was the dense-dashboard habit the redesign removed
        // everywhere else.
        MpOutbound(
          title: 'Resume capsule',
          subtitle: 'Paste into a brand-new Claude conversation.',
          text: capsule.text,
          limit: limit,
        ),
        const SizedBox(height: MpSpace.sm),
      ],
    );
  }
}

class _DesktopRunPanel extends StatefulWidget {
  const _DesktopRunPanel({
    required this.runner,
    required this.project,
    required this.store,
  });

  final DesktopRunner runner;
  final Project project;
  final AppStore store;

  @override
  State<_DesktopRunPanel> createState() => _DesktopRunPanelState();
}

class _DesktopRunPanelState extends State<_DesktopRunPanel> {
  @override
  void initState() {
    super.initState();
    // Probe the CLI on arrival so the user learns it is missing before they
    // press anything, not after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.runner.detect(widget.store.settings);
    });
  }

  Future<void> _start() async {
    final Directory dir = await getApplicationSupportDirectory();
    if (!mounted) return;
    await widget.runner.start(
      project: widget.project,
      settings: widget.store.settings,
      stateDirectory: dir,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    return ListenableBuilder(
      listenable: widget.runner,
      builder: (BuildContext context, _) {
        final DesktopRunner r = widget.runner;

        return MpPanel(
          accent: switch (r.status) {
            DesktopRunStatus.paused => c.warning,
            DesktopRunStatus.failed => c.danger,
            DesktopRunStatus.finished => c.success,
            _ => null,
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  MpTag(r.status.name, tone: c.accent),
                  const SizedBox(width: MpSpace.sm),
                  if (r.install != null)
                    Expanded(
                      child: Text(
                        'Claude Code ${r.install!.version} · '
                        '${r.install!.authMode.name}',
                        style: MpType.caption.copyWith(color: c.inkMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),

              if (r.error != null) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                Text(r.error!, style: MpType.caption.copyWith(color: c.danger)),
              ],

              if (r.status == DesktopRunStatus.paused &&
                  r.resumeAt != null) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                MpField(
                  label: r.limitKind?.isAccountWide ?? false
                      ? 'Account-wide limit'
                      : 'Waiting out a limit',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Resuming at ${r.resumeAt!.toLocal()}',
                        style: MpType.numeric.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: MpSpace.xs),
                      Text(
                        r.limitKind?.isAccountWide ?? false
                            ? 'This limit applies to the whole account, so '
                                  'continuing on your phone will not help.'
                            : 'The run reattaches to the same session when the '
                                  'limit lifts. Closing the app is safe — the '
                                  'schedule is on disk.',
                        style: MpType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],

              if (r.log.isNotEmpty) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: c.canvas,
                    borderRadius: MpRadius.card,
                    border: Border.all(color: c.line),
                  ),
                  padding: const EdgeInsets.all(MpSpace.sm + 2),
                  child: Scrollbar(
                    child: ListView(
                      reverse: true,
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final String line in r.log.reversed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              line,
                              style: MpType.mono.copyWith(color: c.inkMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: MpSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MpButton(
                      label: r.isBusy ? 'Running' : 'Run this mission',
                      icon: Icons.play_arrow,
                      kind: MpButtonKind.primary,
                      expand: true,
                      onPressed: r.isBusy || r.install == null ? null : _start,
                    ),
                  ),
                  if (r.isBusy) ...<Widget>[
                    const SizedBox(width: MpSpace.sm),
                    MpButton(label: 'Stop', onPressed: r.stop),
                  ],
                ],
              ),
              const SizedBox(height: MpSpace.sm),
              Text(
                'The brief is written to the working directory as '
                'MASTER_PROMPT.md, so the run stays auditable and recoverable '
                'without this app.',
                style: MpType.caption.copyWith(color: c.inkFaint),
              ),
            ],
          ),
        );
      },
    );
  }
}
