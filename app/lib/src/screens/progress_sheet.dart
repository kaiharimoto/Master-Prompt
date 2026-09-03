import 'package:flutter/material.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../store/project.dart';

/// The full readiness detail — every requirement and what leaving it open would
/// cost an unattended run.
///
/// This is the list that used to greet you on opening a mission: twenty-one
/// rows before anything actionable. It has not been deleted or trimmed. It is
/// here, one tap away, for when you want the whole picture rather than the next
/// step.
class ProgressSheet extends StatelessWidget {
  const ProgressSheet({required this.project, super.key});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final ReadinessReport r = const InterviewEngine().assess(project.spec);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) => Padding(
        padding: const EdgeInsets.fromLTRB(MpSpace.lg, 0, MpSpace.lg, 0),
        child: ListView(
          controller: controller,
          children: <Widget>[
            Text('Progress', style: MpType.title.copyWith(color: c.ink)),
            const SizedBox(height: MpSpace.sm),
            Text(
              r.canCompile
                  ? 'Everything required is settled.'
                  : '${r.satisfied} of ${r.totalRequired} required things '
                        'settled. Each one below is something an agent would '
                        'otherwise have to stop and ask about.',
              style: MpType.prose.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: MpSpace.md),
            MpMeter(
              value: r.completion,
              tone: r.canCompile ? c.success : c.ink,
            ),
            const SizedBox(height: MpSpace.xl),

            if (r.blocking.isNotEmpty) ...<Widget>[
              Text(
                'STILL NEEDED',
                style: MpType.eyebrow.copyWith(color: c.inkFaint),
              ),
              const SizedBox(height: MpSpace.md),
              for (final ReadinessGap g in r.blocking)
                _Gap(gap: g, tone: c.danger),
              const SizedBox(height: MpSpace.lg),
            ],

            if (r.advisory.isNotEmpty) ...<Widget>[
              Text(
                'OPTIONAL',
                style: MpType.eyebrow.copyWith(color: c.inkFaint),
              ),
              const SizedBox(height: MpSpace.md),
              for (final ReadinessGap g in r.advisory)
                _Gap(gap: g, tone: c.inkFaint),
            ],
            const SizedBox(height: MpSpace.xxl),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: MpSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8, right: MpSpace.md),
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(gap.label, style: MpType.body.copyWith(color: c.ink)),
                const SizedBox(height: 2),
                Text(
                  gap.why,
                  style: MpType.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            gap.stage.title,
            style: MpType.caption.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}
