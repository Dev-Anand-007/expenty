import '../entities/group_expense.dart';
import '../repositories/group_repository.dart';

class WatchGroupExpensesUseCase {
  final GroupRepository repository;

  WatchGroupExpensesUseCase(this.repository);

  Stream<List<GroupExpense>> call(String groupId) =>
      repository.watchExpenses(groupId);
}
