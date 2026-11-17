import '../../../../core/services/activity_alert_watcher.dart';
import '../../domain/entities/money_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;

  TransactionRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<MoneyTransaction>> watchAll() => remoteDataSource.watchAll();

  @override
  Future<void> add(MoneyTransaction transaction) {
    // Tell the alert watcher this write is ours, so the stream echo
    // doesn't raise a "Transaction recorded" notification.
    ActivityAlertWatcher.markLocalWrite(transaction.id);
    return remoteDataSource.add(transaction);
  }

  @override
  Future<void> update(MoneyTransaction transaction) =>
      remoteDataSource.update(transaction);

  @override
  Future<void> delete(String id) => remoteDataSource.delete(id);
}
