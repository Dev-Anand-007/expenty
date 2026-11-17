import 'dart:async';

import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/core/widgets/primary_button.dart';
import 'package:expenty/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:expenty/features/auth/domain/repositories/auth_repository.dart';
import 'package:expenty/features/auth/domain/usecases/change_password_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/forgot_password_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/google_sign_in_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/is_logged_in_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/login_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/logout_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:expenty/features/auth/domain/usecases/signup_usecase.dart';
import 'package:expenty/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:expenty/features/auth/presentation/bloc/auth_event.dart';
import 'package:expenty/features/auth/presentation/bloc/auth_state.dart';
import 'package:expenty/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Both sign-in paths hang until the test releases them, so the screen stays
/// mid-flight long enough to assert on.
class _GatedAuthRepository implements AuthRepository {
  final _loginGate = Completer<void>();
  final _googleGate = Completer<void>();

  /// When set, [signInWithGoogle] throws it instead of blocking.
  Object? googleError;

  @override
  Future<void> login({
    required String email,
    required String password,
  }) => _loginGate.future;

  @override
  Future<void> signInWithGoogle() async {
    final error = googleError;
    if (error != null) throw error;
    return _googleGate.future;
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {}

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
  bool requiresPasswordConfirmation() => false;

  @override
  Future<void> deleteAccount({String? password}) async {}

  @override
  Future<bool> isLoggedIn() async => false;
}

AuthBloc _bloc(AuthRepository repository) => AuthBloc(
  loginUseCase: LoginUseCase(repository),
  signupUseCase: SignupUseCase(repository),
  logoutUseCase: LogoutUseCase(repository),
  forgotPasswordUseCase: ForgotPasswordUseCase(repository),
  sendEmailVerificationUseCase: SendEmailVerificationUseCase(repository),
  isLoggedInUseCase: IsLoggedInUseCase(repository),
  changePasswordUseCase: ChangePasswordUseCase(repository),
  googleSignInUseCase: GoogleSignInUseCase(repository),
  deleteAccountUseCase: DeleteAccountUseCase(repository),
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late _GatedAuthRepository repo;

  // LoginPage builds its own AuthBloc through get_it, so the fake goes into
  // the container rather than into a BlocProvider above the page.
  setUp(() async {
    await setupLocator();
    await sl.unregister<AuthRepository>();
    repo = _GatedAuthRepository();
    sl.registerLazySingleton<AuthRepository>(() => repo);
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pump();
  }

  testWidgets('only the tapped sign-in button spins', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('google-sign-in-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Google spins…
    expect(
      find.descendant(
        of: find.byKey(const Key('google-sign-in-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    // …the email button neither spins nor stays tappable.
    expect(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.descendant(
              of: find.byType(PrimaryButton),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('email login spins only the Login button', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'asha@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.pump();

    await tester.tap(find.widgetWithText(PrimaryButton, 'Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('google-sign-in-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('google-sign-in-button')),
          )
          .onPressed,
      isNull,
    );
  });

  group('Google sign-in failures', () {
    test('a cancelled account picker returns to idle without an error', () async {
      final repo = _GatedAuthRepository()
        ..googleError = const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );
      final bloc = _bloc(repo);
      final settled = bloc.stream.firstWhere(
        (state) => state.status != AuthStatus.loading,
      );

      bloc.add(const GoogleSignInRequested());
      final state = await settled;
      await bloc.close();

      expect(state.status, AuthStatus.initial);
      expect(state.message, isNull);
      expect(state.isBusy, isFalse);
    });

    test('a missing Web client ID explains where to paste it', () async {
      final repo = _GatedAuthRepository()
        ..googleError = const GoogleSignInNotConfiguredException();
      final bloc = _bloc(repo);
      final settled = bloc.stream.firstWhere(
        (state) => state.status != AuthStatus.loading,
      );

      bloc.add(const GoogleSignInRequested());
      final state = await settled;
      await bloc.close();

      expect(state.status, AuthStatus.failure);
      expect(state.message, contains('lib/core/constants/firebase_constants.dart'));
    });
  });
}
