import '../entities/money_transaction.dart';

abstract class TransactionRepository {
  Stream<List<MoneyTransaction>> watchAll();

  Future<void> add(MoneyTransaction transaction);

  Future<void> update(MoneyTransaction transaction);

  Future<void> delete(String id);
}
