import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/dashboard_models.dart';

/// Navy card split into Income | Expenses.
class IncomeExpenseCard extends StatelessWidget {
  final FinancialSummary summary;

  const IncomeExpenseCard({super.key, required this.summary});

  Widget _stat({
    required IconData icon,
    required Color color,
    required String label,
    required double amount,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
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
                  color: AppColors.white.withValues(alpha: .75),
                ),
              ),
              Text(
                CurrencyFormatter.format(amount),
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.white,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: AppColors.navy,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: -26,
              left: -22,
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.cardBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: -18,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.cardOrange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Row(
                children: [
                  _stat(
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.success,
                    label: 'Income',
                    amount: summary.income,
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: AppColors.white.withValues(alpha: .24),
                  ),
                  const SizedBox(width: 14),
                  _stat(
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.error,
                    label: 'Expenses',
                    amount: summary.expenses,
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
