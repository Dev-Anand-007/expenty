import '../entities/wallet.dart';

abstract class WalletRepository {
  Stream<Wallet> watch();

  Future<void> addBalance(double amount);

  /// Puts the wallet back to zero; transactions are left untouched.
  Future<void> resetBalance();
}
