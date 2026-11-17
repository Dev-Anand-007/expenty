import '../entities/group_expense.dart';
import '../repositories/group_repository.dart';

class DeleteGroupExpenseUseCase {
  final GroupRepository repository;

  DeleteGroupExpenseUseCase(this.repository);

  Future<void> call({required String groupId, required GroupExpense expense}) {
    return repository.deleteExpense(groupId, expense);
  }
}
