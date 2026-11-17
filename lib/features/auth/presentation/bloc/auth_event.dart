import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class SignupRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;

  const SignupRequested({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [
    name,
    email,
    password,
  ];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

class ForgotPasswordRequested extends AuthEvent {
  final String email;

  const ForgotPasswordRequested(this.email);

  @override
  List<Object?> get props => [email];
}

class SendEmailVerificationRequested extends AuthEvent {
  const SendEmailVerificationRequested();
}

class ChangePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

/// Taps the "Continue with Google" button on the login screen.
class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
}

/// Confirms the "Delete account" dialog. [password] is only supplied for
/// email/password accounts — Google sign-ins are re-authenticated silently.
class DeleteAccountRequested extends AuthEvent {
  final String? password;

  const DeleteAccountRequested({this.password});

  @override
  List<Object?> get props => [password];
}