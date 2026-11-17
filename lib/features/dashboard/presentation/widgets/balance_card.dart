import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/dashboard_models.dart';

/// Big navy "Total Balance" card with decorative blobs.
class BalanceCard extends StatelessWidget {
  final FinancialSummary summary;
  final VoidCallback? onMyBalances;
  final VoidCallback? onAddBalance;

  const BalanceCard({
    super.key,
    required this.summary,
    this.onMyBalances,
    this.onAddBalance,
  });

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        color: AppColors.navy,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            /// Decorative blobs
            Positioned(top: -34, right: 26, child: _blob(AppColors.chartYellow, 78)),
            Positioned(bottom: -46, left: -30, child: _blob(AppColors.chartMint, 92)),
            Positioned(top: 44, right: -34, child: _blob(AppColors.cardBlue, 70)),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: AppTypography.body.copyWith(
                      color: AppColors.white.withValues(alpha: .75),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(summary.totalBalance),
                    style: AppTypography.displayLarge.copyWith(
                      color: AppColors.white,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (onAddBalance != null)
                        Material(
                          color: AppColors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(30),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: onAddBalance,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: AppColors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Add balance',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        'My Balances',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.white.withValues(alpha: .75),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: AppColors.white.withValues(alpha: .14),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onMyBalances,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              size: 18,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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
