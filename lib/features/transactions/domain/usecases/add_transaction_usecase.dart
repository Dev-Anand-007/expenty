import '../entities/money_transaction.dart';
import '../repositories/transaction_repository.dart';

class AddTransactionUseCase {
  final TransactionRepository repository;

  AddTransactionUseCase(this.repository);

  Future<void> call(MoneyTransaction transaction) {
    return repository.add(transaction);
  }
}
