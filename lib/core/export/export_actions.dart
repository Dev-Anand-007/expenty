import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/save_service.dart';
import '../services/share_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/export_sheet.dart';

/// Runs the export the user picked in an [ExportSheet]: shares it through
/// the system share sheet or saves it to the device, as CSV or PDF.
///
/// Shows the success/error snackbar itself; call after the sheet has been
/// dismissed so [context] still points at the page underneath.
Future<void> performExport(
  BuildContext context, {
  required ExportAction action,
  required String baseFilename,
  required String csvContent,
  required pw.Document pdf,
}) async {
  final isPdf =
      action == ExportAction.sharePdf || action == ExportAction.savePdf;
  final filename = '$baseFilename.${isPdf ? 'pdf' : 'csv'}';

  try {
    switch (action) {
      case ExportAction.shareCsv:
        await ShareService.shareCsv(filename: filename, content: csvContent);

      case ExportAction.saveCsv:
        final saved = await SaveService.saveFile(
          filename: filename,
          bytes: utf8.encode(csvContent),
        );
        if (saved && context.mounted) {
          AppSnackbar.show(
            context,
            'Saved to device',
            type: AppSnackbarType.success,
          );
        }

      case ExportAction.sharePdf:
        await ShareService.shareFile(
          filename: filename,
          bytes: await pdf.save(),
          mimeType: 'application/pdf',
        );

      case ExportAction.savePdf:
        final saved = await SaveService.saveFile(
          filename: filename,
          bytes: await pdf.save(),
        );
        if (saved && context.mounted) {
          AppSnackbar.show(
            context,
            'Saved to device',
            type: AppSnackbarType.success,
          );
        }
    }
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        "Couldn't export — please try again",
        type: AppSnackbarType.error,
      );
    }
  }
}
