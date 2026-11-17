import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_datasource.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;

  WalletRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<Wallet> watch() => remoteDataSource.watch();

  @override
  Future<void> addBalance(double amount) =>
      remoteDataSource.addBalance(amount);

  @override
  Future<void> resetBalance() => remoteDataSource.resetBalance();
}
