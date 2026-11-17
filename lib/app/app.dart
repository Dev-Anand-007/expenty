import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';

class ExpentyApp extends StatelessWidget {
  const ExpentyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeCubit(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) {
          // The key forces a full remount when the mode changes so every
          // page re-reads AppColors' palette (static getters).
          return MaterialApp.router(
            key: ValueKey(mode),
            debugShowCheckedModeBanner: false,
            title: 'Expenty',
            routerConfig: appRouter,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
          );
        },
      ),
    );
  }
}
