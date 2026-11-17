import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../groups/domain/group_balances.dart';

/// "You owe / You are owed" summary across all groups — sits directly
/// below the Total Balance card.
class OwePayCard extends StatelessWidget {
  final GroupTotals totals;
  final int groupCount;

  const OwePayCard({
    super.key,
    required this.totals,
    required this.groupCount,
  });

  Widget _side({
    required IconData icon,
    required Color color,
    required String label,
    required double amount,
  }) {
    final isZero = amount < 0.005;

    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                CurrencyFormatter.format(amount),
                style: AppTypography.subtitle.copyWith(
                  color: isZero ? AppColors.textSecondary : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                size: 16,
                color: AppColors.teal,
              ),
              const SizedBox(width: 8),
              Text(
                'Across your groups',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$groupCount ${groupCount == 1 ? 'group' : 'groups'}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _side(
                icon: Icons.arrow_upward_rounded,
                color: AppColors.error,
                label: 'You owe',
                amount: totals.owes,
              ),
              Container(
                width: 1,
                height: 44,
                color: AppColors.divider,
              ),
              const SizedBox(width: 14),
              _side(
                icon: Icons.arrow_downward_rounded,
                color: AppColors.success,
                label: 'You are owed',
                amount: totals.owed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
