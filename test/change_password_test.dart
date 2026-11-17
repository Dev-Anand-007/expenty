import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/app/theme/theme_cubit.dart';
import 'package:expenty/features/auth/domain/repositories/auth_repository.dart';
import 'package:expenty/features/settings/presentation/pages/settings_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// FirebaseAuthException's constructor is @protected — subclass it so the
/// bloc's `on FirebaseAuthException` mapping can be exercised for real.
class _FakeAuthException extends FirebaseAuthException {
  _FakeAuthException(String code) : super(code: code);
}

class _FakeAuthRepository implements AuthRepository {
  String? currentPassword;
  String? newPassword;
  Object? failWith;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
    final failure = failWith;
    if (failure != null) throw failure;
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
  bool requiresPasswordConfirmation() => false;

  @override
  Future<void> deleteAccount({String? password}) async {}

  @override
  Future<bool> isLoggedIn() async => true;
}

void main() {
  late _FakeAuthRepository fake;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await setupLocator();
    fake = _FakeAuthRepository();
    await sl.unregister<AuthRepository>();
    sl.registerLazySingleton<AuthRepository>(() => fake);
  });

  tearDownAll(() async {
    await sl.reset();
  });

  setUp(() {
    fake.currentPassword = null;
    fake.newPassword = null;
    fake.failWith = null;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    final cubit = ThemeCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: cubit,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openDialog(WidgetTester tester) async {
    final tile = find.byKey(const Key('settings-change-password'));
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('settings-password-submit')), findsOneWidget);
  }

  Future<void> fillFields(
    WidgetTester tester, {
    required String current,
    required String fresh,
    required String confirm,
  }) async {
    await tester.enterText(
      find.byKey(const Key('settings-password-current')),
      current,
    );
    await tester.enterText(
      find.byKey(const Key('settings-password-new')),
      fresh,
    );
    await tester.enterText(
      find.byKey(const Key('settings-password-confirm')),
      confirm,
    );
  }

  testWidgets('empty form is rejected before any Firebase call', (
    tester,
  ) async {
    await pumpSettings(tester);
    await openDialog(tester);

    await tester.tap(find.byKey(const Key('settings-password-submit')));
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Password is required'), findsNWidgets(2));
    expect(fake.currentPassword, isNull);
  });

  testWidgets('confirm must match the new password', (tester) async {
    await pumpSettings(tester);
    await openDialog(tester);

    await fillFields(
      tester,
      current: 'oldpass123',
      fresh: 'newpass123',
      confirm: 'different1',
    );
    await tester.tap(find.byKey(const Key('settings-password-submit')));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(fake.currentPassword, isNull);
  });

  testWidgets('valid form updates the password and confirms', (tester) async {
    await pumpSettings(tester);
    await openDialog(tester);

    await fillFields(
      tester,
      current: 'oldpass123',
      fresh: 'brandnew1',
      confirm: 'brandnew1',
    );
    await tester.tap(find.byKey(const Key('settings-password-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.currentPassword, 'oldpass123');
    expect(fake.newPassword, 'brandnew1');

    // Dialog closes and the page confirms.
    expect(find.byKey(const Key('settings-password-submit')), findsNothing);
    expect(find.text('Password updated.'), findsOneWidget);

    // Let the snackbar's duration timer fire so it can't linger into
    // the next test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });

  testWidgets('a wrong current password shows a friendly error', (
    tester,
  ) async {
    fake.failWith = _FakeAuthException('invalid-credential');

    await pumpSettings(tester);
    await openDialog(tester);

    await fillFields(
      tester,
      current: 'wrongpass',
      fresh: 'brandnew1',
      confirm: 'brandnew1',
    );
    await tester.tap(find.byKey(const Key('settings-password-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('settings-password-error')), findsOneWidget);
    expect(find.text('Your current password is incorrect'), findsOneWidget);
    // The dialog stays open for another try.
    expect(find.byKey(const Key('settings-password-submit')), findsOneWidget);
  });
}
