import 'package:flutter/material.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../store/app_store.dart';
import '../store/project.dart';
import '../widgets/exchange.dart';

/// The discussion that produces the brief.
///
/// The readiness meter is the point of this screen. It is not decoration: it
/// shows precisely what is still unsettled and what each omission would cost an
/// unattended run, and it is what refuses to let a half-specified brief be
/// compiled.
class InterviewScreen extends StatefulWidget {
  const InterviewScreen({
    required this.store,
    required this.project,
    super.key,
  });

  final AppStore store;
  final Project project;

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  static const InterviewEngine _engine = InterviewEngine();
  static const SpecPatchParser _patcher = SpecPatchParser();

  String? _lastNote;
  List<String> _lastApplied = const <String>[];
  List<String> _lastRejected = const <String>[];

  Future<void> _applyReply(String reply) async {
    final Project p = widget.project;
    final SpecPatchResult r = _patcher.parse(reply, p.spec);

    await widget.store.addTranscript(
      p,
      TranscriptEntry(
        direction: TranscriptDirection.received,
        text: reply,
        at: DateTime.now().toUtc(),
        note: r.found
            ? '${r.applied.length} changes applied'
            : 'No patch block found',
      ),
    );

    if (!r.found) {
      setState(() {
        _lastNote =
            'No mpspec block in that reply — nothing was changed. If Claude '
            'asked you questions, answer them in the same chat and paste its '
            'next reply.';
        _lastApplied = const <String>[];
        _lastRejected = const <String>[];
      });
      return;
    }

    p.spec = r.spec;
    await widget.store.save(p);
    setState(() {
      _lastNote = null;
      _lastApplied = r.applied;
      _lastRejected = r.rejected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Project p = widget.project;
    final ReadinessReport report = _engine.assess(p.spec);
    final InterviewTurn turn = _engine.nextTurn(p.spec);

    return ListView(
      padding: const EdgeInsets.all(MpSpace.md),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MpSpace.readingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Readiness(report: report),
                const SizedBox(height: MpSpace.lg),

                if (report.canCompile)
                  MpPanel(
                    accent: c.success,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'The brief is complete enough to run unattended',
                          style: MpType.heading.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: MpSpace.sm),
                        Text(
                          turn.text,
                          style: MpType.prose.copyWith(color: c.inkMuted),
                        ),
                        const SizedBox(height: MpSpace.md),
                        Text(
                          'Open the Brief tab to compile it, red-team it, and '
                          'run it.',
                          style: MpType.caption.copyWith(color: c.inkFaint),
                        ),
                      ],
                    ),
                  )
                else
                  MpOutbound(
                    title: 'Round: ${turn.stage.title}',
                    subtitle: turn.stage.purpose,
                    text: turn.text,
                  ),

                const SizedBox(height: MpSpace.md),
                MpInbound(onSubmit: _applyReply),

                if (_lastNote != null) ...<Widget>[
                  const SizedBox(height: MpSpace.md),
                  MpPanel(
                    accent: c.warning,
                    child: Text(
                      _lastNote!,
                      style: MpType.prose.copyWith(color: c.inkMuted),
                    ),
                  ),
                ],

                if (_lastApplied.isNotEmpty) ...<Widget>[
                  const SizedBox(height: MpSpace.md),
                  MpPanel(
                    accent: c.success,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Applied ${_lastApplied.length} changes',
                          style: MpType.heading.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: MpSpace.sm),
                        for (final String a in _lastApplied.take(12))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '· $a',
                              style: MpType.caption.copyWith(color: c.inkMuted),
                            ),
                          ),
                        if (_lastApplied.length > 12)
                          Text(
                            '· and ${_lastApplied.length - 12} more',
                            style: MpType.caption.copyWith(color: c.inkFaint),
                          ),
                      ],
                    ),
                  ),
                ],

                if (_lastRejected.isNotEmpty) ...<Widget>[
                  const SizedBox(height: MpSpace.sm),
                  MpPanel(
                    accent: c.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "${_lastRejected.length} lines weren't understood",
                          style: MpType.heading.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: MpSpace.xs),
                        Text(
                          'They are kept in the transcript rather than dropped.',
                          style: MpType.caption.copyWith(color: c.inkMuted),
                        ),
                        const SizedBox(height: MpSpace.sm),
                        for (final String r in _lastRejected.take(6))
                          Text(
                            r,
                            style: MpType.mono.copyWith(color: c.inkFaint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: MpSpace.xl),
                _Transcript(project: p),
                const SizedBox(height: MpSpace.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Readiness extends StatelessWidget {
  const _Readiness({required this.report});

  final ReadinessReport report;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool ready = report.canCompile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MpSectionHeader(
          number: '01',
          title: 'Readiness',
          trailing: Text(
            '${report.satisfied} / ${report.totalRequired}',
            style: MpType.numeric.copyWith(color: c.inkMuted),
          ),
        ),
        const SizedBox(height: MpSpace.sm),
        MpMeter(value: report.completion, tone: ready ? c.success : c.ink),
        const SizedBox(height: MpSpace.md),
        if (report.blocking.isNotEmpty)
          Text(
            'The brief cannot be compiled yet. Each item below is something an '
            'agent would otherwise have to stop and ask about.',
            style: MpType.prose.copyWith(color: c.inkMuted),
          ),
        const SizedBox(height: MpSpace.sm),
        for (final ReadinessGap g in report.blocking)
          _Gap(gap: g, tone: c.danger),
        for (final ReadinessGap g in report.advisory)
          _Gap(gap: g, tone: c.inkFaint),
      ],
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.gap, required this.tone});

  final ReadinessGap gap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: MpSpace.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6, right: MpSpace.sm + 2),
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        gap.label,
                        style: MpType.body.copyWith(color: c.ink),
                      ),
                    ),
                    if (!gap.blocking) MpTag('optional', tone: c.inkFaint),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  gap.why,
                  style: MpType.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    if (project.transcript.isEmpty) return const SizedBox.shrink();

    final List<TranscriptEntry> recent = project.transcript.reversed
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const MpSectionHeader(number: '02', title: 'Transcript'),
        const SizedBox(height: MpSpace.sm),
        Text(
          'Every exchange is kept in full, including replies that could not be '
          'parsed.',
          style: MpType.caption.copyWith(color: c.inkFaint),
        ),
        const SizedBox(height: MpSpace.md),
        for (final TranscriptEntry e in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: MpSpace.sm),
            child: MpPanel(
              padding: const EdgeInsets.all(MpSpace.sm + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      MpTag(
                        e.direction == TranscriptDirection.sent
                            ? 'sent'
                            : 'received',
                        tone: e.direction == TranscriptDirection.sent
                            ? c.inkFaint
                            : c.accent,
                      ),
                      const Spacer(),
                      if (e.note != null)
                        Text(
                          e.note!,
                          style: MpType.caption.copyWith(color: c.inkFaint),
                        ),
                    ],
                  ),
                  const SizedBox(height: MpSpace.sm),
                  Text(
                    e.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: MpType.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
