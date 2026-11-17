import '../repositories/wallet_repository.dart';

class AddBalanceUseCase {
  final WalletRepository repository;

  AddBalanceUseCase(this.repository);

  Future<void> call(double amount) => repository.addBalance(amount);
}
