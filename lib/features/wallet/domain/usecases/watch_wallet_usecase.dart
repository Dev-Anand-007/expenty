import '../entities/wallet.dart';
import '../repositories/wallet_repository.dart';

class WatchWalletUseCase {
  final WalletRepository repository;

  WatchWalletUseCase(this.repository);

  Stream<Wallet> call() => repository.watch();
}
