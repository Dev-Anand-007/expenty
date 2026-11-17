import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Title + filter chip used by every dashboard section.
class DashboardSectionHeader extends StatelessWidget {
  final String title;
  final String chipLabel;
  final VoidCallback? onChipTap;

  const DashboardSectionHeader({
    super.key,
    required this.title,
    required this.chipLabel,
    this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.title.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        GestureDetector(
          onTap: onChipTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              chipLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
