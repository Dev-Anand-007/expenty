import 'package:equatable/equatable.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  success,
  failure,
}

/// Which action put the bloc into [AuthStatus.loading].
///
/// The login screen shows two buttons (email + Google) on one bloc, so the
/// spinner has to know which one was tapped — otherwise both light up for a
/// single press, the same double-loading bug the profile screen had.
enum AuthFlow {
  login,
  google,
  signup,
  logout,
  forgotPassword,
  verification,
  changePassword,
  deleteAccount,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final String? message;
  final AuthFlow? flow;

  const AuthState({
    this.status = AuthStatus.initial,
    this.message,
    this.flow,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? message,
    AuthFlow? flow,
  }) {
    return AuthState(
      status: status ?? this.status,
      message: message,
      flow: flow ?? this.flow,
    );
  }

  /// True while *any* action is in flight — use it to disable buttons, not to
  /// decide which one is spinning.
  bool get isBusy => status == AuthStatus.loading;

  @override
  List<Object?> get props => [
    status,
    message,
    flow,
  ];
}
