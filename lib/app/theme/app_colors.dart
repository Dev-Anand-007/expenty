import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ------------------------------------------------------------- theme switch
  static bool _darkMode = false;

  static bool get isDarkMode => _darkMode;

  /// Flips the palette used by the theme-aware getters below.
  /// Called by [ThemeCubit] before the app rebuilds.
  static void setDarkMode(bool value) => _darkMode = value;

  // Brand
  static const primary = Color(0xFF865A9A);
  static const accent = Color(0xFFEF8767);
  static const darkPurple = Color(0xFF42224A);

  // Background (theme aware)
  static Color get background =>
      _darkMode ? const Color(0xFF141016) : const Color(0xFFF7F4F7);

  static Color get surface =>
      _darkMode ? const Color(0xFF1F1A22) : Colors.white;

  /// Lighter primary for dark backgrounds so buttons/links stay legible.
  static Color get primaryForBackground =>
      _darkMode ? const Color(0xFFB98FCB) : primary;

  // Text (theme aware)
  static Color get textPrimary =>
      _darkMode ? const Color(0xFFF4EFF6) : const Color(0xFF120216);

  static Color get textSecondary =>
      _darkMode ? const Color(0xFFB6ADC0) : const Color(0xFF6E6575);

  /// Label/icon colour for [primary]-filled buttons.
  ///
  /// Deliberately not theme-aware: the button fill is [primary] in *both*
  /// themes, so the label colour has to be the same in both. Dark instead of
  /// white — pure white on #865A9A was the glare this replaced.
  static const onPrimary = Color(0xFF120216);

  /// Background of the launch/splash screen. Deliberately not theme-aware and
  /// shared with the native launch drawable — it has to match the first frame
  /// of `assets/images/splash_animation.gif` exactly or the hand-off flashes.
  static const splashBackground = Color(0xFF0D132B);

  // Status
  static const success = Color(0xFF2DBE7F);
  static const warning = Color(0xFFF5A623);
  static const error = Color(0xFFE53935);

  // Others
  static const white = Colors.white;
  static const black = Colors.black;

  static Color get divider =>
      _darkMode ? const Color(0xFF332C38) : const Color(0xFFE9E3EB);

  // Dashboard
  static const navy = Color(0xFF152A5E);
  static const navyDeep = Color(0xFF0F1F49);
  static const teal = Color(0xFF2AA17B);
  static const cardOrange = Color(0xFFF08C1E);
  static const cardGreen = Color(0xFF2E9C7E);
  static const cardBlue = Color(0xFF2F6BD9);
  static const chartYellow = Color(0xFFF5C542);
  static const chartMint = Color(0xFF5BCB8A);

  static Color get progressTrack =>
      _darkMode ? const Color(0xFF2A2430) : const Color(0xFFEDE9F1);
}
