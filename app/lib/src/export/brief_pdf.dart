import 'dart:typed_data';

import 'package:mp_core/mp_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The fonts the document is set in, loaded once by the caller.
///
/// Passed in rather than read here so this whole file stays free of Flutter
/// and of asset loading, which is what lets a generated PDF be checked in a
/// plain test rather than only by opening one.
class BriefFonts {
  const BriefFonts({
    required this.regular,
    required this.medium,
    required this.semiBold,
    required this.mono,
  });

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;
  final pw.Font mono;
}

/// The compiled brief as a document someone can read away from the app.
///
/// Built from the same blocks the on-screen preview uses, so the two cannot
/// drift: one reader over the compiled text, two ways of setting it.
class BriefPdf {
  const BriefPdf({required this.fonts});

  final BriefFonts fonts;

  static const PdfColor _ink = PdfColor.fromInt(0xFF17181A);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B6C70);
  static const PdfColor _faint = PdfColor.fromInt(0xFF9B9CA0);
  static const PdfColor _line = PdfColor.fromInt(0xFFE6E5E1);
  static const PdfColor _surface = PdfColor.fromInt(0xFFF6F6F4);

  /// [diff] marks what the last accepted round changed. Pass
  /// [BriefDiff.none] for a clean copy — the one to hand to someone who was
  /// not part of the review.
  Future<Uint8List> build({
    required String body,
    required String title,
    required BriefDiff diff,
    String? footer,
  }) async {
    final BriefDocument doc = BriefDocument.parse(body);
    // A theme rather than per-widget styles alone: anything not styled
    // explicitly would otherwise fall back to the reader's built-in Helvetica
    // and Courier, which carry no Unicode — a missing glyph in an exported
    // document is a silent corruption, and the brief is full of typographic
    // punctuation.
    final pw.Document pdf = pw.Document(
      title: title,
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.semiBold,
        italic: fonts.regular,
        boldItalic: fonts.semiBold,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 56,
          marginRight: 56,
          marginTop: 56,
          marginBottom: 56,
        ),
        footer: (pw.Context c) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${footer == null ? '' : '$footer  ·  '}'
            '${c.pageNumber} / ${c.pagesCount}',
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 8,
              color: _faint,
            ),
          ),
        ),
        build: (pw.Context context) => <pw.Widget>[
          if (!diff.isEmpty) ..._revisionNote(diff),
          for (final BriefBlock b in doc.blocks) _block(b, diff.marks(b)),
        ],
      ),
    );

    return pdf.save();
  }

  List<pw.Widget> _revisionNote(BriefDiff diff) => <pw.Widget>[
    pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'This copy marks a revision',
            style: pw.TextStyle(
              font: fonts.semiBold,
              fontSize: 11,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${diff.summary}. Changed passages carry a rule in the left '
            'margin. A copy without the marks can be exported from the app.',
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 9,
              color: _muted,
            ),
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 18),
  ];

  pw.Widget _block(BriefBlock b, bool changed) {
    final pw.Widget content = switch (b.kind) {
      BriefBlockKind.title => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(
          b.plain,
          style: pw.TextStyle(font: fonts.semiBold, fontSize: 22, color: _ink),
        ),
      ),
      BriefBlockKind.section => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 20, bottom: 6),
        child: pw.Text(
          b.plain.toUpperCase(),
          style: pw.TextStyle(
            font: fonts.semiBold,
            fontSize: 9,
            letterSpacing: 1.2,
            color: _muted,
          ),
        ),
      ),
      BriefBlockKind.paragraph => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: _rich(b),
      ),
      BriefBlockKind.bullet => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Container(
              width: 3,
              height: 3,
              margin: const pw.EdgeInsets.only(top: 5, right: 7),
              decoration: const pw.BoxDecoration(
                color: _faint,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.Expanded(child: _rich(b)),
          ],
        ),
      ),
      BriefBlockKind.table => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: _table(b.rows),
      ),
      BriefBlockKind.code => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: _surface,
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            b.text,
            style: pw.TextStyle(font: fonts.mono, fontSize: 8, color: _muted),
          ),
        ),
      ),
      BriefBlockKind.rule => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        child: pw.Divider(color: _line, height: 1, thickness: 0.5),
      ),
    };

    // The same gutter on every block whether or not it is marked, so the text
    // keeps one left edge down the page.
    return pw.Container(
      padding: const pw.EdgeInsets.only(left: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(
            color: changed ? _ink : PdfColors.white,
            width: 2,
          ),
        ),
      ),
      child: content,
    );
  }

  pw.Widget _rich(BriefBlock b) => pw.RichText(
    text: pw.TextSpan(
      children: <pw.TextSpan>[
        for (final BriefSpan s in b.spans)
          pw.TextSpan(
            text: s.text,
            style: switch (s.kind) {
              BriefSpanKind.plain => pw.TextStyle(
                font: fonts.regular,
                fontSize: 10,
                color: _ink,
                lineSpacing: 3,
              ),
              BriefSpanKind.strong => pw.TextStyle(
                font: fonts.semiBold,
                fontSize: 10,
                color: _ink,
                lineSpacing: 3,
              ),
              BriefSpanKind.code => pw.TextStyle(
                font: fonts.mono,
                fontSize: 9,
                color: _muted,
              ),
            },
          ),
      ],
    ),
  );

  pw.Widget _table(List<List<String>> rows) {
    if (rows.isEmpty) return pw.SizedBox();
    return pw.TableHelper.fromTextArray(
      headers: rows.first,
      data: rows.skip(1).toList(),
      border: pw.TableBorder.all(color: _line, width: 0.5),
      headerStyle: pw.TextStyle(font: fonts.medium, fontSize: 8, color: _muted),
      cellStyle: pw.TextStyle(font: fonts.regular, fontSize: 8, color: _ink),
      headerDecoration: const pw.BoxDecoration(color: _surface),
      cellPadding: const pw.EdgeInsets.all(5),
    );
  }
}

/// Loads Inter out of the design package so the PDF is set in the same face
/// as the app. Cached, because a font is a megabyte and an export is a tap.
class BriefFontLoader {
  BriefFontLoader(this.load);

  /// Injected so a test can supply bytes without a Flutter asset bundle.
  final Future<ByteData> Function(String key) load;

  BriefFonts? _cached;

  static const String _dir = 'packages/mp_design/assets/fonts';

  Future<BriefFonts> fonts() async {
    if (_cached != null) return _cached!;
    Future<pw.Font> face(String name) async =>
        pw.Font.ttf(await load('$_dir/$name'));
    _cached = BriefFonts(
      regular: await face('Inter-Regular.ttf'),
      medium: await face('Inter-Medium.ttf'),
      semiBold: await face('Inter-SemiBold.ttf'),
      // Inter has no monospace cut, and the fenced blocks in the brief are
      // directory trees whose alignment is the point. Courier is built into
      // every PDF reader, so it costs nothing to embed and always renders.
      mono: pw.Font.courier(),
    );
    return _cached!;
  }
}
