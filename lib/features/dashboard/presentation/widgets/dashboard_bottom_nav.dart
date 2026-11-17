import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Home | Activity | (+ add) | Groups | Menu
///
/// The center add button is an elevated round FAB that sits slightly above
/// the bar, so it reads as the primary action.
class DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onAdd;

  const DashboardBottomNav({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onAdd,
  });

  Widget _destination({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onIndexChanged(index),
        child: SizedBox(
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 24,
                color: selected ? AppColors.teal : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.teal : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            /// Nav row: two destinations, a gap for the FAB, then two more.
            Row(
              children: [
                _destination(
                  index: 0,
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                _destination(
                  index: 1,
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long_rounded,
                  label: 'Activity',
                ),
                const SizedBox(width: 76),
                _destination(
                  index: 2,
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups_rounded,
                  label: 'Groups',
                ),
                _destination(
                  index: 3,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  label: 'Menu',
                ),
              ],
            ),

            /// Elevated round add button, centered and raised above the bar.
            Positioned(
              top: -22,
              child: Material(
                color: AppColors.teal,
                shape: const CircleBorder(),
                elevation: 8,
                shadowColor: AppColors.teal.withValues(alpha: .45),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onAdd,
                  child: const SizedBox(
                    width: 58,
                    height: 58,
                    child: Icon(Icons.add_rounded, size: 30, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
