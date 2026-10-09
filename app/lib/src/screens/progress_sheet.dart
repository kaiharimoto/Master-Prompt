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
  const ProgressSheet({
    required this.project,
    this.draggable = true,
    super.key,
  });

  final Project project;

  /// Drag-to-expand belongs to a bottom sheet. In a desktop dialog the frame
  /// is already the right size and the gesture has nothing to grab.
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final ReadinessReport r = const InterviewEngine().assess(project.spec);

    Widget body(ScrollController? controller) => Padding(
      padding: EdgeInsets.fromLTRB(
        draggable ? MpSpace.lg : 0,
        0,
        draggable ? MpSpace.lg : 0,
        0,
      ),
      child: ListView(
        controller: controller,
        shrinkWrap: !draggable,
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
          MpMeter(value: r.completion, tone: r.canCompile ? c.success : c.ink),
          const SizedBox(height: MpSpace.xl),

          if (r.blocking.isNotEmpty) ...<Widget>[
            Text(
              'STILL NEEDED',
              style: MpType.eyebrow.copyWith(color: c.inkFaint),
            ),
            const SizedBox(height: MpSpace.md),
            for (final ReadinessGap g in r.blocking) _Gap(gap: g, glyph: '○'),
            const SizedBox(height: MpSpace.lg),
          ],

          if (r.advisory.isNotEmpty) ...<Widget>[
            Text('OPTIONAL', style: MpType.eyebrow.copyWith(color: c.inkFaint)),
            const SizedBox(height: MpSpace.md),
            for (final ReadinessGap g in r.advisory) _Gap(gap: g, glyph: '–'),
          ],
          SizedBox(height: draggable ? MpSpace.xxl : MpSpace.md),
        ],
      ),
    );

    if (!draggable) return body(null);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) =>
          body(controller),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.gap, required this.glyph});

  final ReadinessGap gap;

  /// The stage-list glyph: `○` still to do, `–` optional. A glyph rather than
  /// a coloured dot, because there are no colours to mean anything with.
  final String glyph;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MpSpace.smd),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.ink12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: MpSpace.md,
            child: Text(glyph, style: MpType.numeral.copyWith(color: c.ink)),
          ),
          const SizedBox(width: MpSpace.sm),
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
          const SizedBox(width: MpSpace.smd),
          Text(
            gap.stage.title.toUpperCase(),
            style: MpType.eyebrow.copyWith(color: c.ink45),
          ),
        ],
      ),
    );
  }
}
