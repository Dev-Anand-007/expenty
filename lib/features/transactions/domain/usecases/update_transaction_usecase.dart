import '../entities/money_transaction.dart';
import '../repositories/transaction_repository.dart';

class UpdateTransactionUseCase {
  final TransactionRepository repository;

  UpdateTransactionUseCase(this.repository);

  Future<void> call(MoneyTransaction transaction) {
    return repository.update(transaction);
  }
}
