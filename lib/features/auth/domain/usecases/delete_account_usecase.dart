import '../repositories/auth_repository.dart';

/// Permanently removes the signed-in account and everything that belongs to
/// it — group memberships, transactions, wallet, profile, @username and the
/// Firebase Auth record itself.
class DeleteAccountUseCase {
  final AuthRepository repository;

  DeleteAccountUseCase(this.repository);

  /// True when the confirm dialog has to collect a password before anything
  /// can be deleted (i.e. the account has an email/password credential).
  bool requiresPasswordConfirmation() =>
      repository.requiresPasswordConfirmation();

  Future<void> call({String? password}) =>
      repository.deleteAccount(password: password);
}
