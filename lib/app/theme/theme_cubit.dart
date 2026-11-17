import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/storage_service.dart';
import 'app_colors.dart';

/// Holds the app's [ThemeMode], persisted via [StorageService].
///
/// Also flips [AppColors]' palette so widgets that read the static colors
/// directly pick up dark values. `ExpentyApp` remounts the tree on change
/// (via a `ValueKey`) so every page re-reads them.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(StorageService.isDarkMode ? ThemeMode.dark : ThemeMode.light) {
    AppColors.setDarkMode(state == ThemeMode.dark);
  }

  void setDarkMode(bool enabled) {
    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (mode == state) return;

    AppColors.setDarkMode(enabled);
    StorageService.setDarkMode(enabled);
    emit(mode);
  }

  void toggle() => setDarkMode(state != ThemeMode.dark);
}
