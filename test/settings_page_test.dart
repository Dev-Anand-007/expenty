import 'package:expenty/app/theme/app_colors.dart';
import 'package:expenty/app/theme/theme_cubit.dart';
import 'package:expenty/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    // Leave the palette clean for other test files.
    AppColors.setDarkMode(false);
  });

  Future<ThemeCubit> pumpSettings(WidgetTester tester) async {
    final cubit = ThemeCubit();
    addTearDown(cubit.close);

    // Tall viewport so every section (incl. SECURITY) is on-screen.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: cubit,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return cubit;
  }

  testWidgets('shows appearance, preferences and about sections', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.byKey(const Key('settings-title')), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.byKey(const Key('settings-currency')), findsOneWidget);
    expect(find.text('Transaction alerts'), findsOneWidget);
    expect(find.text('Group activity'), findsOneWidget);
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.byKey(const Key('settings-change-password')), findsOneWidget);
    expect(find.text('DATA'), findsOneWidget);
    expect(find.byKey(const Key('settings-reset-balance')), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.byKey(const Key('settings-delete-account')), findsOneWidget);
    expect(find.byKey(const Key('settings-version')), findsOneWidget);
    expect(find.text('1.0.0 (1)'), findsOneWidget);
  });

  testWidgets('dark mode toggle flips the theme palette', (tester) async {
    final cubit = await pumpSettings(tester);

    expect(cubit.state, ThemeMode.light);
    expect(AppColors.isDarkMode, isFalse);

    await tester.tap(find.byKey(const Key('settings-dark-mode')));
    await tester.pump();

    expect(cubit.state, ThemeMode.dark);
    expect(AppColors.isDarkMode, isTrue);

    await tester.tap(find.byKey(const Key('settings-dark-mode')));
    await tester.pump();

    expect(cubit.state, ThemeMode.light);
    expect(AppColors.isDarkMode, isFalse);
  });

  testWidgets('currency can be changed from the picker', (tester) async {
    await pumpSettings(tester);

    final currencyTile = find.byKey(const Key('settings-currency'));
    await tester.ensureVisible(currencyTile);
    await tester.pump();
    await tester.tap(currencyTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Currency symbol'), findsOneWidget);

    await tester.tap(find.text(r'$'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Currency symbol'), findsNothing);
    expect(find.text('Shown across the app — \$'), findsOneWidget);
  });

  testWidgets('notification toggles flip their stored preference', (
    tester,
  ) async {
    await pumpSettings(tester);

    final tile = find.byKey(const Key('settings-notifications-transactions'));
    await tester.ensureVisible(tile);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(tile);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
  });

  testWidgets('about dialog shows the app version', (tester) async {
    await pumpSettings(tester);

    final aboutTile = find.byKey(const Key('settings-about'));
    await tester.ensureVisible(aboutTile);
    await tester.pump();
    await tester.tap(aboutTile);
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    expect(find.textContaining('Track personal expenses'), findsOneWidget);
  });
}
