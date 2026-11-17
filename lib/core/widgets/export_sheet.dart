import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Which way out of the app the user picked in an [ExportSheet].
enum ExportAction { shareCsv, saveCsv, sharePdf, savePdf }

/// Bottom sheet offering the four ways to get an export out of the app:
/// share or save, as CSV or PDF. Returns null when dismissed without
/// picking an action.
class ExportSheet extends StatelessWidget {
  const ExportSheet({super.key});

  static Future<ExportAction?> show(BuildContext context) {
    return showModalBottomSheet<ExportAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ExportSheet(),
    );
  }

  Widget _item(
    BuildContext context, {
    required String actionKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required ExportAction action,
  }) {
    return ListTile(
      key: Key(actionKey),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            'Export',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          _item(
            context,
            actionKey: 'export-share-csv',
            icon: Icons.table_view_rounded,
            title: 'Share CSV',
            subtitle: 'Spreadsheet — opens in Excel or Sheets',
            action: ExportAction.shareCsv,
          ),
          _item(
            context,
            actionKey: 'export-save-csv',
            icon: Icons.download_rounded,
            title: 'Save CSV to device',
            subtitle: 'Keeps a copy in your downloads',
            action: ExportAction.saveCsv,
          ),
          _item(
            context,
            actionKey: 'export-share-pdf',
            icon: Icons.picture_as_pdf_rounded,
            title: 'Share PDF',
            subtitle: 'Formatted statement to print or send',
            action: ExportAction.sharePdf,
          ),
          _item(
            context,
            actionKey: 'export-save-pdf',
            icon: Icons.save_alt_rounded,
            title: 'Save PDF to device',
            subtitle: 'Keeps a copy in your downloads',
            action: ExportAction.savePdf,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
