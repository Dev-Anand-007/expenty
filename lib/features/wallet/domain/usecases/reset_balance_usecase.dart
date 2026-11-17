import '../repositories/wallet_repository.dart';

/// Puts the wallet back to zero.
///
/// Only `users/{uid}.walletBalance` is written — income, expenses and every
/// transaction stay exactly as they are, so the dashboard's other figures
/// keep their history.
class ResetBalanceUseCase {
  final WalletRepository repository;

  ResetBalanceUseCase(this.repository);

  Future<void> call() => repository.resetBalance();
}
