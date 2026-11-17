import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Greeting + avatar + quick actions.
class DashboardHeader extends StatelessWidget {
  final String userName;
  final String? photoUrl;

  const DashboardHeader({
    super.key,
    required this.userName,
    this.photoUrl,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final initial = userName.isEmpty ? '?' : userName[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: .15),
          child: photoUrl != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: photoUrl!,
                    fit: BoxFit.cover,
                    width: 44,
                    height: 44,
                    errorWidget: (_, __, ___) => Text(
                      initial,
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : Text(
                  initial,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                userName,
                style: AppTypography.title.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
