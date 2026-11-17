import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class DarkTheme {
  DarkTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: AppColors.background,

      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryForBackground,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ).copyWith(
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),

      fontFamily: AppTypography.body.fontFamily,

      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge
            .copyWith(color: AppColors.textPrimary),
        headlineMedium: AppTypography.headline
            .copyWith(color: AppColors.textPrimary),
        titleLarge: AppTypography.title.copyWith(color: AppColors.textPrimary),
        titleMedium:
            AppTypography.subtitle.copyWith(color: AppColors.textPrimary),
        bodyLarge: AppTypography.body.copyWith(color: AppColors.textPrimary),
        bodyMedium: AppTypography.body.copyWith(color: AppColors.textPrimary),
        labelLarge: AppTypography.button.copyWith(color: AppColors.textPrimary),
        bodySmall: AppTypography.caption
            .copyWith(color: AppColors.textSecondary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),

        hintStyle: TextStyle(color: AppColors.textSecondary),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
