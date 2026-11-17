import '../entities/money_transaction.dart';
import '../repositories/transaction_repository.dart';

class WatchTransactionsUseCase {
  final TransactionRepository repository;

  WatchTransactionsUseCase(this.repository);

  Stream<List<MoneyTransaction>> call() => repository.watchAll();
}
