import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';
import 'package:mp_runner/mp_runner.dart';
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
  const RunScreen({
    required this.store,
    required this.project,
    this.runner,
    super.key,
  });

  final AppStore store;
  final Project project;

  /// The shell's shared runner, so a connection tested in Settings is the one
  /// that runs the mission. Optional so a test can render the screen alone.
  final DesktopRunner? runner;

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

  late final DesktopRunner _runner = widget.runner ?? DesktopRunner();

  bool get _canRunLocally => DesktopRunner.isSupported;

  @override
  void dispose() {
    if (widget.runner == null) _runner.dispose();
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
                // Listening to the runner, because on desktop this panel is
                // now fed by the run itself rather than only by a hand-paste.
                ListenableBuilder(
                  listenable: _runner,
                  builder: (BuildContext context, _) => _StatePanel(
                    state: _runner.state ?? p.lastState,
                    spec: p.spec,
                  ),
                ),

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
                        'Start a new Claude conversation and send this first.',
                    document: compiled.body,
                    note:
                        'This is a mission brief. Read all of it, then '
                        'begin. Follow it exactly, including the state block '
                        'on every reply.',
                    fileName: '${p.spec.taskId}-brief.md',
                    limit: widget.store.settings.pasteLimit,
                  ),

                const SizedBox(height: MpSpace.md),
                if (_canRunLocally)
                  // Kept, never removed — the same rule as copy-paste in the
                  // interview. The CLI reads the heartbeat out of the run
                  // itself now, so pasting one by hand is the fallback for a
                  // mission carried on a phone and brought back here, not the
                  // only way progress is ever recorded.
                  MpDisclosure(
                    label: 'Record progress by hand',
                    child: MpInbound(
                      onSubmit: _applyState,
                      hint:
                          'Paste a reply from elsewhere, including its mpstate '
                          'block',
                      actionLabel: 'Record progress',
                    ),
                  )
                else
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
                      state: _runner.state ?? p.lastState,
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

/// Wall-clock, to the minute. `DateTime.toString()` printed microseconds at
/// someone waiting five hours.
String _clockTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// How long a duration reads as, at a glance and at every scale a run reaches.
String _spell(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
}

/// A timestamp five hours out is indistinguishable from a hang. A number that
/// counts down is not.
String _countdown(DateTime resumeAt) {
  final Duration left = resumeAt.difference(DateTime.now().toUtc());
  return left.isNegative ? 'any moment' : 'in ${_spell(left)}';
}

/// A run left open, offered rather than silently abandoned.
///
/// The whole value of the state file, unspent until now: it holds the session
/// id, the attempt history, the working directory and the point the run had
/// reached. Without this the only recovery was "Run this mission", which mints
/// a fresh id with no session and sends the entire brief again.
class _ResumeOffer extends StatelessWidget {
  const _ResumeOffer({required this.record, required this.onResume});

  final RunRecord record;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final DateTime? at = record.scheduledResumeAt;

    return MpPanel(
      accent: c.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            at != null
                ? 'A run is waiting to resume.'
                : 'A run was left unfinished.',
            style: MpType.label.copyWith(color: c.ink),
          ),
          const SizedBox(height: MpSpace.xs),
          Text(
            <String>[
              '${record.attempts.length} attempt(s)',
              if (record.sessionId != null)
                'session ${record.sessionId!.substring(0, 8)}'
              else
                'no session to reattach to',
              if (at != null) 'due ${_clockTime(at.toLocal())}',
            ].join(' · '),
            style: MpType.caption.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: MpSpace.md),
          MpButton(
            label: 'Continue this run',
            icon: Icons.restart_alt,
            kind: MpButtonKind.primary,
            expand: true,
            onPressed: onResume,
          ),
          const SizedBox(height: MpSpace.xs),
          Text(
            record.sessionId == null
                ? 'It will start from the brief and the recorded state, in the '
                      'same working directory.'
                : 'It reattaches to the same Claude session, so the work so '
                      'far is still in context. Starting over would send the '
                      'whole brief again as a new conversation.',
            style: MpType.caption.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// Whether the run met what the brief actually asked for.
///
/// A run was called finished on one signal — the process exited zero and the
/// CLI's result event said `success`. The brief makes six verifiable
/// commitments and the app could check none of them, so a twelve-hour run that
/// produced three of eleven artifacts, ran one review cycle of four and scored
/// itself 61 against a threshold of 90 was painted the same green as one that
/// met every gate. That is a silently wrong answer, which is worse than a
/// missing one.
class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.outcome});

  final MissionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final List<Shortfall> shortfalls = outcome.shortfalls;

    return MpPanel(
      accent: outcome.met ? c.success : c.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            outcome.met
                ? 'It met the brief.'
                : 'It finished, but not everything the brief asked for is '
                      'there.',
            style: MpType.label.copyWith(color: c.ink),
          ),
          if (outcome.expected.isNotEmpty) ...<Widget>[
            const SizedBox(height: MpSpace.xs),
            Text(
              '${outcome.produced.length} of ${outcome.expected.length} '
              'evidence artifacts on disk.',
              style: MpType.caption.copyWith(color: c.inkMuted),
            ),
          ],
          // Sentences, not field labels — MpField uppercases, which is right
          // for "NEXT ACTION" and unreadable for a line of prose.
          for (final Shortfall f in shortfalls) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.remove, size: 16, color: c.warning),
                const SizedBox(width: MpSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(f.what, style: MpType.body.copyWith(color: c.ink)),
                      if (f.detail.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          f.detail,
                          style: MpType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (!outcome.met) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            Text(
              'Nothing here overrides your own look at the work. It is the '
              'difference between "the process exited cleanly" and "the '
              'mission is done", which is a difference the screen used to '
              'hide.',
              style: MpType.caption.copyWith(color: c.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the run costs and how far into it you are.
///
/// Every number here was already computed, persisted to JSON, and then
/// dropped before it reached a widget. Over twelve hours the screen offered a
/// status word and a scrolling log, which cannot answer "is it still working"
/// or "how much has this cost".
class _Vitals extends StatelessWidget {
  const _Vitals({required this.runner});

  final DesktopRunner runner;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final DesktopRunner r = runner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: MpSpace.md,
          runSpacing: MpSpace.xs,
          children: <Widget>[
            if (r.elapsed > Duration.zero)
              _Vital(label: 'Elapsed', value: _spell(r.elapsed)),
            if (r.attempt > 0)
              _Vital(
                label: 'Attempt',
                value: '${r.attempt}',
                // A run on its seventh resume looked exactly like one that had
                // just started.
                tone: r.attempt > 1 ? c.warning : null,
              ),
            if (r.costUsd != null)
              _Vital(
                label: 'Spent',
                value: '\$${r.costUsd!.toStringAsFixed(2)}',
              ),
            // Shown because a hold nobody can see is a hold nobody notices
            // leaking, and because its absence is worth knowing before a
            // twelve-hour run rather than after one ends at hour three.
            if (r.isBusy)
              _Vital(
                label: 'Sleep',
                value: r.holdingAwake ? 'held off' : 'not held',
                tone: r.holdingAwake ? null : c.warning,
              ),
          ],
        ),
        if (r.sessionId != null) ...<Widget>[
          const SizedBox(height: MpSpace.xs),
          Text(
            'Session ${r.sessionId}',
            style: MpType.caption.copyWith(color: c.inkFaint),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _Vital extends StatelessWidget {
  const _Vital({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: MpType.eyebrow.copyWith(color: c.inkFaint),
        ),
        Text(value, style: MpType.numeric.copyWith(color: tone ?? c.ink)),
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
          subtitle: 'Into a brand-new Claude conversation.',
          document: capsule.text,
          note:
              'This is a mission that was interrupted partway through. '
              'Read the capsule and continue from exactly where it says, '
              'without redoing finished work.',
          fileName: '${capsule.taskId}-resume.md',
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
    // press anything, not after — and look for a run left open, which is the
    // sweep that makes a resume survive a reboot.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.runner.detect(widget.store.settings);
      if (!mounted) return;
      final Directory dir = await getApplicationSupportDirectory();
      if (!mounted) return;
      await widget.runner.lookForResumable(
        project: widget.project,
        stateDirectory: dir,
      );
    });
  }

  Future<void> _start({RunRecord? resuming}) async {
    final Directory dir = await getApplicationSupportDirectory();
    if (!mounted) return;
    await widget.runner.start(
      project: widget.project,
      settings: widget.store.settings,
      stateDirectory: dir,
      resuming: resuming,
      // What the run says about itself is written down where everything else
      // reads it: the resume capsule, the diagnostics report and the Progress
      // panel on the next launch all go through `lastState`, and a desktop run
      // used to leave all three empty.
      onState: (MpState s) {
        widget.project.lastState = s;
        unawaited(widget.store.save(widget.project));
      },
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
            // Green is a claim about the mission, and the only thing the
            // supervisor knows is that the process exited zero. Where the
            // brief set gates, they decide.
            DesktopRunStatus.finished =>
              r.outcome?.hasGates ?? false
                  ? (r.outcome!.met ? c.success : c.warning)
                  : c.success,
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

              if (r.isBusy || r.record != null || r.attempt > 0) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                _Vitals(runner: r),
              ],

              if (r.outcome != null && r.outcome!.hasGates) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                _OutcomePanel(outcome: r.outcome!),
              ],

              if (!r.isBusy && r.resumable != null) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                _ResumeOffer(
                  record: r.resumable!,
                  onResume: () => _start(resuming: r.resumable),
                ),
              ],

              if (r.error != null) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                Text(r.error!, style: MpType.caption.copyWith(color: c.danger)),
                const SizedBox(height: MpSpace.sm),
                // The search reports every candidate and what became of it,
                // and that list was reachable only from Settings. Being told
                // one sentence and left with nowhere to go is how a fixable
                // install reads as a broken program.
                if (r.attempts.isNotEmpty)
                  MpDisclosure(
                    label: 'Where it looked',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final ProbeAttempt a in r.attempts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${a.outcome.name}  ${a.path}'
                              '${a.detail.isEmpty ? '' : '  — ${a.detail}'}',
                              style: MpType.mono.copyWith(color: c.inkMuted),
                            ),
                          ),
                        const SizedBox(height: MpSpace.sm),
                        Text(
                          'Settings takes an explicit path, and uses it alone.',
                          style: MpType.caption.copyWith(color: c.inkFaint),
                        ),
                      ],
                    ),
                  ),
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
                        'Resuming at ${_clockTime(r.resumeAt!.toLocal())}'
                        ' — ${_countdown(r.resumeAt!)}',
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
                SizedBox(
                  // A twelve-hour run against a 220px window is a keyhole.
                  // Taller where there is room, and never taller than half the
                  // window, so the controls under it stay in view. Fixed rather
                  // than hugging, so the buttons underneath do not walk down
                  // the screen as output arrives.
                  height: (MediaQuery.sizeOf(context).height * 0.4).clamp(
                    220.0,
                    520.0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.canvas,
                      borderRadius: MpRadius.card,
                      border: Border.all(color: c.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(MpSpace.sm + 2),
                      child: Scrollbar(
                        // One SelectionArea rather than a SelectableText per
                        // line. The log is the first thing anyone asks about
                        // when a run goes wrong so it has to be copyable, but
                        // five hundred SelectableTexts in a shrink-wrapped list
                        // laid every one of them out on every event — and a
                        // chatty agent produces events for twelve hours, on the
                        // one screen that has to stay watchable.
                        child: SelectionArea(
                          child: ListView.builder(
                            reverse: true,
                            itemCount: r.log.length,
                            itemBuilder: (BuildContext context, int i) =>
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    r.log[r.log.length - 1 - i],
                                    style: MpType.mono.copyWith(
                                      color: c.inkMuted,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: MpSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MpButton(
                      label: r.isBusy
                          ? 'Running'
                          : r.resumable != null
                          ? 'Start over'
                          : 'Run this mission',
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
                r.workingDirectory == null
                    ? 'The brief is written to the working directory as '
                          'MASTER_PROMPT.md, so the run stays auditable and '
                          'recoverable without this app.'
                    : 'Working in ${r.workingDirectory}. The brief is there as '
                          'MASTER_PROMPT.md, so the run stays auditable and '
                          'recoverable without this app.',
                style: MpType.caption.copyWith(color: c.inkFaint),
              ),
            ],
          ),
        );
      },
    );
  }
}
