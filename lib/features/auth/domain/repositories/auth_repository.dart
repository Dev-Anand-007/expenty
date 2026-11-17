abstract class AuthRepository {
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> login({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> logout();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Whether deleting this account has to collect a password first.
  bool requiresPasswordConfirmation();

  /// Permanently deletes the signed-in account and everything that belongs
  /// to it. See `AuthRemoteDataSource.deleteAccount` for the ordering.
  Future<void> deleteAccount({String? password});

  Future<bool> isLoggedIn();
}