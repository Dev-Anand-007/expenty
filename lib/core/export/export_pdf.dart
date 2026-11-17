import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/theme/app_colors.dart';

/// Builds the printable half of an export: a titled A4 document with a
/// branded header row, zebra striping, right-aligned numeric columns and
/// page numbers. Long tables split across pages automatically (the pdf
/// package's table implements the spanning-widget protocol).
///
/// Amounts stay plain digits so the PDF and its CSV twin carry identical
/// rows (a `=SUM` in a spreadsheet and the printed number never disagree).
/// Everything else — titles, notes, group names, and ₹ if it ever appears —
/// survives because the document is rendered with a real Unicode font from
/// [pdfTheme] instead of the package's WinAnsi-only Helvetica.
Future<pw.Document> buildExportPdf({
  required String title,
  required String subtitle,
  required List<String> headers,
  required List<List<String>> rows,
  Set<int> rightAlign = const {},
  List<double>? columnWeights,
}) async {
  final doc = pw.Document();
  final theme = await pdfTheme();

  pw.TableColumnWidth widthOf(int index) {
    final weight =
        columnWeights != null && index < columnWeights.length
            ? columnWeights[index]
            : 1.0;
    return pw.FlexColumnWidth(weight);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 44),
      build: (context) => [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 9,
          ),
          headerAlignment: pw.Alignment.centerLeft,
          headerAlignments: {
            for (final index in rightAlign) index: pw.Alignment.centerRight,
          },
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromInt(AppColors.primary.toARGB32()),
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {
            for (final index in rightAlign) index: pw.Alignment.centerRight,
          },
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          columnWidths: {for (var i = 0; i < headers.length; i++) i: widthOf(i)},
          defaultColumnWidth: const pw.FlexColumnWidth(1),
        ),
      ],
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
    ),
  );

  return doc;
}

/// Document theme with a bundled Unicode font (see assets/fonts/README.md).
///
/// The pdf package's built-in Helvetica only covers Latin-1: it drops the
/// rupee sign, Devanagari and smart quotes without complaint, which is why
/// every export used to print `Helvetica has no Unicode support`.
///
/// A failure here falls back to the built-in font rather than failing the
/// export — a PDF that renders in Helvetica beats one that does not render.
Future<pw.ThemeData> pdfTheme() async {
  try {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-bold.ttf'),
    );
    return pw.ThemeData.withFont(base: regular, bold: bold);
  } catch (error) {
    debugPrint('PDF theme: falling back to Helvetica ($error)');
    return pw.ThemeData.withFont();
  }
}
