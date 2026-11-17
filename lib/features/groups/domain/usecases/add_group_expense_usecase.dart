import '../entities/group_expense.dart';
import '../repositories/group_repository.dart';

class AddGroupExpenseUseCase {
  final GroupRepository repository;

  AddGroupExpenseUseCase(this.repository);

  Future<void> call({required String groupId, required GroupExpense expense}) {
    return repository.addExpense(groupId, expense);
  }
}
