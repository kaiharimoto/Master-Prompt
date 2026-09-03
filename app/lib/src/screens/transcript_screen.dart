import 'package:flutter/material.dart';
import 'package:mp_design/mp_design.dart';

import '../store/project.dart';

/// Everything sent and received, in full.
///
/// Kept because a paste is never discarded — including one that could not be
/// parsed. If a round went wrong, the raw text of it is still here.
class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({required this.project, super.key});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final List<TranscriptEntry> entries = project.transcript.reversed.toList();

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(MpSpace.xl),
        child: MpEmpty(
          title: 'Nothing yet',
          detail:
              'Every message sent to Claude and every reply brought back will '
              'be kept here in full, including anything that could not be read.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(MpSpace.lg),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: MpSpace.md),
      itemBuilder: (BuildContext context, int i) {
        final TranscriptEntry e = entries[i];
        final bool sent = e.direction == TranscriptDirection.sent;
        return MpPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  MpTag(
                    sent ? 'sent' : 'received',
                    tone: sent ? c.inkFaint : c.accent,
                  ),
                  const Spacer(),
                  if (e.note != null)
                    Text(
                      e.note!,
                      style: MpType.caption.copyWith(color: c.inkFaint),
                    ),
                ],
              ),
              const SizedBox(height: MpSpace.sm + 2),
              SelectableText(
                e.text,
                style: MpType.mono.copyWith(color: c.inkMuted),
                maxLines: 14,
              ),
            ],
          ),
        );
      },
    );
  }
}
