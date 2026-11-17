import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/app/theme/theme_cubit.dart';
import 'package:expenty/features/auth/domain/repositories/auth_repository.dart';
import 'package:expenty/features/settings/presentation/pages/settings_page.dart';
import 'package:expenty/features/wallet/domain/entities/wallet.dart';
import 'package:expenty/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// The two destructive settings: "Reset wallet balance" and "Delete account".
class _FakeWalletRepository implements WalletRepository {
  int resetCalls = 0;
  Object? failWith;

  @override
  Stream<Wallet> watch() async* {
    yield const Wallet(balance: 0);
  }

  @override
  Future<void> addBalance(double amount) async {}

  @override
  Future<void> resetBalance() async {
    final failure = failWith;
    if (failure != null) throw failure;
    resetCalls++;
  }
}

class _FakeAuthRepository implements AuthRepository {
  /// True for email/password accounts — the dialog then has to collect a
  /// password; false models a Google-only account.
  bool needsPassword = true;
  bool deleted = false;
  String? deletedWithPassword;
  Object? failWith;

  void reset() {
    needsPassword = true;
    deleted = false;
    deletedWithPassword = null;
    failWith = null;
  }

  @override
  bool requiresPasswordConfirmation() => needsPassword;

  @override
  Future<void> deleteAccount({String? password}) async {
    final failure = failWith;
    if (failure != null) throw failure;
    deleted = true;
    deletedWithPassword = password;
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<bool> isLoggedIn() async => true;
}

void main() {
  late _FakeAuthRepository authRepo;
  late _FakeWalletRepository walletRepo;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await setupLocator();
    authRepo = _FakeAuthRepository();
    walletRepo = _FakeWalletRepository();

    // Swap the Firebase-backed implementations out — nothing here may
    // touch FirebaseAuth.instance.
    await sl.unregister<AuthRepository>();
    await sl.unregister<WalletRepository>();
    sl.registerLazySingleton<AuthRepository>(() => authRepo);
    sl.registerLazySingleton<WalletRepository>(() => walletRepo);
  });

  tearDownAll(() async {
    await sl.reset();
  });

  setUp(() {
    authRepo.reset();
    walletRepo.resetCalls = 0;
    walletRepo.failWith = null;
  });

  /// The delete flow ends by routing to the login page, so those tests need
  /// a real GoRouter — `context.go` has nowhere to go inside a bare
  /// MaterialApp.
  GoRouter makeRouter() => GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: Text('LOGIN_PAGE')),
      ),
    ],
  );

  Future<void> pumpSettings(WidgetTester tester, {GoRouter? router}) async {
    final cubit = ThemeCubit();
    addTearDown(cubit.close);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final Widget app = router == null
        ? const MaterialApp(home: SettingsPage())
        : MaterialApp.router(routerConfig: router);

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(value: cubit, child: app),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapTile(WidgetTester tester, Key key) async {
    final tile = find.byKey(key);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('reset wallet balance', () {
    testWidgets('asks first and only writes when confirmed', (tester) async {
      await pumpSettings(tester);

      await tapTile(tester, const Key('settings-reset-balance'));
      expect(find.text('Reset wallet balance?'), findsOneWidget);
      expect(walletRepo.resetCalls, 0);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(walletRepo.resetCalls, 0);

      await tapTile(tester, const Key('settings-reset-balance'));
      await tester.tap(find.byKey(const Key('settings-reset-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(walletRepo.resetCalls, 1);
      expect(find.text('Reset wallet balance?'), findsNothing);
      expect(find.text('Wallet balance reset to 0.'), findsOneWidget);
    });

    testWidgets('reports a failure without claiming success', (tester) async {
      walletRepo.failWith = Exception('offline');

      await pumpSettings(tester);
      await tapTile(tester, const Key('settings-reset-balance'));
      await tester.tap(find.byKey(const Key('settings-reset-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(walletRepo.resetCalls, 0);
      expect(
        find.text('Could not reset the balance — please try again.'),
        findsOneWidget,
      );
      expect(find.text('Wallet balance reset to 0.'), findsNothing);
    });
  });

  group('delete account', () {
    testWidgets('a password account has to confirm before anything happens', (
      tester,
    ) async {
      final router = makeRouter();
      addTearDown(router.dispose);

      await pumpSettings(tester, router: router);
      await tapTile(tester, const Key('settings-delete-account'));

      // The account has a password, so the dialog asks for it.
      expect(find.byKey(const Key('settings-delete-password')), findsOneWidget);

      // Blank field: rejected by the form, so the bloc never runs.
      await tester.tap(find.byKey(const Key('settings-delete-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(authRepo.deleted, isFalse);
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('settings-delete-password')),
        'hunter2',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings-delete-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authRepo.deleted, isTrue);
      expect(authRepo.deletedWithPassword, 'hunter2');
      expect(find.byKey(const Key('settings-delete-submit')), findsNothing);
      expect(find.text('LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('a Google account is never asked for a password', (
      tester,
    ) async {
      authRepo.needsPassword = false;

      final router = makeRouter();
      addTearDown(router.dispose);

      await pumpSettings(tester, router: router);
      await tapTile(tester, const Key('settings-delete-account'));

      expect(
        find.byKey(const Key('settings-delete-password')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('settings-delete-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authRepo.deleted, isTrue);
      expect(authRepo.deletedWithPassword, isNull);
      expect(find.text('LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('a rejected re-authentication keeps the dialog open', (
      tester,
    ) async {
      authRepo.failWith = FirebaseAuthException(code: 'wrong-password');

      final router = makeRouter();
      addTearDown(router.dispose);

      await pumpSettings(tester, router: router);
      await tapTile(tester, const Key('settings-delete-account'));

      await tester.enterText(
        find.byKey(const Key('settings-delete-password')),
        'wrong',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings-delete-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authRepo.deleted, isFalse);
      expect(find.byKey(const Key('settings-delete-error')), findsOneWidget);
      expect(find.text('Your password is incorrect'), findsOneWidget);
      expect(find.byKey(const Key('settings-delete-submit')), findsOneWidget);
      expect(find.text('LOGIN_PAGE'), findsNothing);
    });
  });
}
