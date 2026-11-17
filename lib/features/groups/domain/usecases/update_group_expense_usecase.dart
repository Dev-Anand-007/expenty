import '../entities/group_expense.dart';
import '../repositories/group_repository.dart';

class UpdateGroupExpenseUseCase {
  final GroupRepository repository;

  UpdateGroupExpenseUseCase(this.repository);

  Future<void> call({required String groupId, required GroupExpense expense}) {
    return repository.updateExpense(groupId, expense);
  }
}
