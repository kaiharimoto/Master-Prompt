import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../export/brief_pdf.dart';
import '../handover/sender.dart';

/// The brief as a document rather than as a payload.
///
/// Everywhere else in the app the compiled brief is a thing to be transported:
/// a monospace block with a copy button under it. This is the one place it is
/// meant to be read. It renders the compiled text itself rather than a second
/// rendering driven from the spec — the brief is the artifact, and a preview
/// generated another way would be free to drift from what the agent is handed.
///
/// When a round has been accepted, what it changed is marked. The marks are
/// for the person reading; nothing about them reaches the model.
class BriefPreview extends StatelessWidget {
  const BriefPreview({
    required this.body,
    required this.title,
    required this.fileStem,
    this.baseline,
    this.onDismissMarks,
    this.sender,
    this.fontLoader,
    super.key,
  });

  /// What an exported file is called, before the extension.
  final String fileStem;

  /// Injected by tests; the real ones talk to the platform and the bundle.
  final HandoverSender? sender;
  final BriefFontLoader? fontLoader;

  /// The compiled brief, exactly as it will be handed over.
  final String body;

  final String title;

  /// The brief as it stood before the last accepted round, if there was one.
  final String? baseline;

  final VoidCallback? onDismissMarks;

  BriefDiff get diff =>
      baseline == null ? BriefDiff.none : BriefDiff.between(baseline!, body);

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final BriefDocument doc = BriefDocument.parse(body);
    final BriefDiff d = diff;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpSpace.lg,
        MpSpace.lg,
        MpSpace.lg,
        MpSpace.xxl,
      ),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MpSpace.readingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Export(
                  body: body,
                  title: title,
                  fileStem: fileStem,
                  diff: d,
                  sender: sender,
                  fontLoader: fontLoader,
                ),
                const SizedBox(height: MpSpace.lg),
                if (!d.isEmpty) ...<Widget>[
                  _ChangeBanner(diff: d, onDismiss: onDismissMarks),
                  const SizedBox(height: MpSpace.lg),
                ],
                for (final BriefBlock b in doc.blocks)
                  _Block(block: b, changed: d.marks(b), colors: c),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeBanner extends StatelessWidget {
  const _ChangeBanner({required this.diff, required this.onDismiss});

  final BriefDiff diff;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return MpPanel(
      accent: c.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'What the last round changed',
            style: MpType.heading.copyWith(color: c.ink),
          ),
          const SizedBox(height: 2),
          Text(
            '${diff.summary}. Marked in the margin below.',
            style: MpType.caption.copyWith(color: c.inkMuted),
          ),
          if (onDismiss != null) ...<Widget>[
            const SizedBox(height: MpSpace.sm),
            MpButton(
              label: 'Clear the marks',
              kind: MpButtonKind.quiet,
              onPressed: onDismiss,
            ),
          ],
        ],
      ),
    );
  }
}

/// One block, set the way the design system sets everything else.
class _Block extends StatelessWidget {
  const _Block({
    required this.block,
    required this.changed,
    required this.colors,
  });

  final BriefBlock block;
  final bool changed;
  final MpColors colors;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (block.kind) {
      BriefBlockKind.title => Padding(
        padding: const EdgeInsets.only(bottom: MpSpace.md),
        child: Text(
          block.plain,
          style: MpType.question.copyWith(color: colors.ink),
        ),
      ),
      BriefBlockKind.section => Padding(
        padding: const EdgeInsets.only(top: MpSpace.xl, bottom: MpSpace.sm),
        child: Text(
          block.plain.toUpperCase(),
          style: MpType.eyebrow.copyWith(color: colors.inkMuted),
        ),
      ),
      BriefBlockKind.paragraph => Padding(
        padding: const EdgeInsets.only(bottom: MpSpace.md),
        child: _spans(MpType.prose.copyWith(color: colors.ink)),
      ),
      BriefBlockKind.bullet => Padding(
        padding: const EdgeInsets.only(bottom: MpSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 7, right: MpSpace.sm + 2),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.inkFaint,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(child: _spans(MpType.prose.copyWith(color: colors.ink))),
          ],
        ),
      ),
      BriefBlockKind.table => Padding(
        padding: const EdgeInsets.only(bottom: MpSpace.md),
        child: _Table(rows: block.rows, colors: colors),
      ),
      BriefBlockKind.code => Padding(
        padding: const EdgeInsets.only(bottom: MpSpace.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MpSpace.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: MpRadius.card,
            border: Border.all(color: colors.line),
          ),
          // Fenced blocks in the brief are directory trees and the state
          // template: fixed-width, and wrapping them would misrepresent them.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              block.text,
              style: MpType.mono.copyWith(color: colors.inkMuted),
            ),
          ),
        ),
      ),
      BriefBlockKind.rule => const Padding(
        padding: EdgeInsets.symmetric(vertical: MpSpace.md),
        child: MpRule(),
      ),
    };

    // A rule in the margin rather than a highlight behind the text: the brief
    // is long and dense, and a tinted background over a third of it would make
    // the document harder to read at the moment it most needs reading.
    //
    // Every block carries the same gutter and only a marked one colours it, so
    // the text stays on one left edge whether or not it changed. Pulling the
    // bar outward with a negative margin is not an option — Container asserts
    // against one.
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: changed ? colors.accent : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: MpSpace.md),
      child: content,
    );
  }

  Widget _spans(TextStyle base) => Text.rich(
    TextSpan(
      children: <TextSpan>[
        for (final BriefSpan s in block.spans)
          TextSpan(
            text: s.text,
            style: switch (s.kind) {
              BriefSpanKind.plain => base,
              BriefSpanKind.strong => base.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
              BriefSpanKind.code => MpType.mono.copyWith(
                color: colors.inkMuted,
              ),
            },
          ),
      ],
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.colors});

  final List<List<String>> rows;
  final MpColors colors;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.line),
          borderRadius: MpRadius.card,
        ),
        child: Column(
          children: <Widget>[
            for (int r = 0; r < rows.length; r++)
              Container(
                decoration: BoxDecoration(
                  color: r == 0 ? colors.surface : null,
                  border: r == rows.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: colors.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final String cell in rows[r])
                      Container(
                        width: 150,
                        padding: const EdgeInsets.all(MpSpace.sm + 2),
                        child: Text(
                          cell,
                          style: r == 0
                              ? MpType.label.copyWith(color: colors.inkMuted)
                              : MpType.caption.copyWith(color: colors.ink),
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
}

/// Getting the document out of the app.
///
/// A marked copy by default, because the reason to export just after a round
/// is to check it; a clean one for handing to someone who was not part of the
/// review and would only be puzzled by the marks.
class _Export extends StatefulWidget {
  const _Export({
    required this.body,
    required this.title,
    required this.fileStem,
    required this.diff,
    required this.sender,
    required this.fontLoader,
  });

  final String body;
  final String title;
  final String fileStem;
  final BriefDiff diff;
  final HandoverSender? sender;
  final BriefFontLoader? fontLoader;

  @override
  State<_Export> createState() => _ExportState();
}

class _ExportState extends State<_Export> {
  late final HandoverSender _sender = widget.sender ?? HandoverSender();
  late final BriefFontLoader _fonts =
      widget.fontLoader ?? BriefFontLoader(rootBundle.load);
  bool _busy = false;

  Future<void> _export({required bool marked}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final BriefPdf pdf = BriefPdf(fonts: await _fonts.fonts());
      final Uint8List bytes = await pdf.build(
        body: widget.body,
        title: widget.title,
        diff: marked ? widget.diff : BriefDiff.none,
        footer: widget.title,
      );
      final String name =
          '${widget.fileStem}${marked && !widget.diff.isEmpty ? '-marked' : ''}'
          '.pdf';
      final SaveOutcome outcome = await _sender.saveBytes(bytes, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (outcome) {
            SaveOutcome.toDownloads => 'Saved to Downloads as $name.',
            SaveOutcome.toChosenFolder => 'Saved as $name.',
            SaveOutcome.cancelled => 'Nothing saved.',
            SaveOutcome.failed => 'Could not write the PDF.',
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool marked = !widget.diff.isEmpty;

    return Row(
      children: <Widget>[
        Expanded(
          child: MpButton(
            label: _busy
                ? 'Working…'
                : marked
                ? 'Save as PDF, marked'
                : 'Save as PDF',
            icon: Icons.picture_as_pdf_outlined,
            expand: true,
            onPressed: _busy ? null : () => _export(marked: true),
          ),
        ),
        if (marked) ...<Widget>[
          const SizedBox(width: MpSpace.sm),
          MpButton(
            label: 'Clean copy',
            kind: MpButtonKind.quiet,
            onPressed: _busy ? null : () => _export(marked: false),
          ),
        ],
      ],
    );
  }
}
