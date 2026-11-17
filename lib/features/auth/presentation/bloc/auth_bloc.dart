import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/google_sign_in_usecase.dart';
import '../../domain/usecases/is_logged_in_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/send_email_verification_usecase.dart';
import '../../domain/usecases/signup_usecase.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final SignupUseCase signupUseCase;
  final LogoutUseCase logoutUseCase;
  final ForgotPasswordUseCase forgotPasswordUseCase;
  final SendEmailVerificationUseCase sendEmailVerificationUseCase;
  final IsLoggedInUseCase isLoggedInUseCase;
  final ChangePasswordUseCase changePasswordUseCase;
  final GoogleSignInUseCase googleSignInUseCase;
  final DeleteAccountUseCase deleteAccountUseCase;

  AuthBloc({
    required this.loginUseCase,
    required this.signupUseCase,
    required this.logoutUseCase,
    required this.forgotPasswordUseCase,
    required this.sendEmailVerificationUseCase,
    required this.isLoggedInUseCase,
    required this.changePasswordUseCase,
    required this.googleSignInUseCase,
    required this.deleteAccountUseCase,
  }) : super(const AuthState()) {
    on<LoginRequested>(_onLoginRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignupRequested>(_onSignupRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ForgotPasswordRequested>(_onForgotPasswordRequested);
    on<SendEmailVerificationRequested>(
      _onSendEmailVerificationRequested,
    );
    on<ChangePasswordRequested>(_onChangePasswordRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
  }

  Future<void> _onLoginRequested(
      LoginRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.login,
        message: null,
      ),
    );

    try {
      await loginUseCase(
        email: event.email,
        password: event.password,
      );

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          message: "Login successful.",
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onGoogleSignInRequested(
      GoogleSignInRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.google,
        message: null,
      ),
    );

    try {
      await googleSignInUseCase();

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          message: "Login successful.",
        ),
      );
    } on GoogleSignInException catch (e) {
      // Backing out of the account picker is not a failure — clear the
      // spinner and say nothing rather than showing a red error.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        emit(state.copyWith(status: AuthStatus.initial, message: null));
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSignupRequested(
      SignupRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.signup,
        message: null,
      ),
    );

    try {
      await signupUseCase(
        name: event.name,
        email: event.email,
        password: event.password,
      );

      emit(
        state.copyWith(
          status: AuthStatus.success,
          message: "Account created successfully.",
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.logout,
        message: null,
      ),
    );

    try {
      await logoutUseCase();

      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          message: "Logged out successfully.",
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCheckAuthStatus(
      CheckAuthStatus event,
      Emitter<AuthState> emit,
      ) async {
    try {
      final isLoggedIn = await isLoggedInUseCase();

      emit(
        state.copyWith(
          status: isLoggedIn
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          message: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onForgotPasswordRequested(
      ForgotPasswordRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.forgotPassword,
        message: null,
      ),
    );

    try {
      await forgotPasswordUseCase(event.email);

      emit(
        state.copyWith(
          status: AuthStatus.success,
          message: "Password reset email sent.",
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSendEmailVerificationRequested(
      SendEmailVerificationRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.verification,
        message: null,
      ),
    );

    try {
      await sendEmailVerificationUseCase();

      emit(
        state.copyWith(
          status: AuthStatus.success,
          message: "Verification email sent.",
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onChangePasswordRequested(
      ChangePasswordRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.changePassword,
        message: null,
      ),
    );

    try {
      await changePasswordUseCase(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );

      emit(
        state.copyWith(
          status: AuthStatus.success,
          message: 'Password updated.',
        ),
      );
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: _changePasswordError(e),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteAccountRequested(
      DeleteAccountRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        flow: AuthFlow.deleteAccount,
        message: null,
      ),
    );

    try {
      await deleteAccountUseCase(password: event.password);

      emit(
        state.copyWith(
          status: AuthStatus.success,
          message: 'Account deleted.',
        ),
      );
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: _deleteAccountError(e),
        ),
      );
    } on GoogleSignInException catch (e) {
      // Backing out of the re-authentication picker is not a failure — but
      // the dialog does have to stay open, so say what happened plainly.
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.code == GoogleSignInExceptionCode.canceled
              ? 'Deletion cancelled — your account is untouched'
              : e.toString(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  /// Firebase's raw codes are developer-speak — turn them into something
  /// a person can act on.
  static String _changePasswordError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Your current password is incorrect';
      case 'weak-password':
        return 'New password is too weak — use at least 6 characters';
      case 'requires-recent-login':
        return 'For your security, sign in again and retry';
      case 'user-mismatch':
      case 'user-not-found':
      case 'invalid-user-token':
      case 'user-disabled':
        return 'Session expired — sign in again and retry';
      default:
        return 'Could not update your password — please try again';
    }
  }

  static String _deleteAccountError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Your password is incorrect';
      case 'requires-recent-login':
        return 'For your security, sign in again and retry';
      case 'user-disabled':
      case 'user-not-found':
      case 'invalid-user-token':
        return 'Session expired — sign in again and retry';
      case 'too-many-requests':
        return 'Too many attempts — try again later';
      default:
        return 'Could not delete your account — please try again';
    }
  }
}