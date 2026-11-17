import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum AppSnackbarType { info, success, error }

/// Central place for showing snackbars across the app.
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final background = switch (type) {
      AppSnackbarType.success => AppColors.success,
      AppSnackbarType.error => AppColors.error,
      AppSnackbarType.info => AppColors.navy,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}
