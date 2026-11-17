import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/usecases/add_group_expense_usecase.dart';
import '../../domain/usecases/add_group_member_usecase.dart';
import '../../domain/usecases/delete_group_expense_usecase.dart';
import '../../domain/usecases/leave_group_usecase.dart';
import '../../domain/usecases/rename_group_usecase.dart';
import '../../domain/usecases/update_group_expense_usecase.dart';
import '../../domain/usecases/watch_group_expenses_usecase.dart';
import '../../domain/usecases/watch_group_usecase.dart';
import 'group_detail_event.dart';
import 'group_detail_state.dart';

class GroupDetailBloc extends Bloc<GroupDetailEvent, GroupDetailState> {
  final WatchGroupUseCase watchGroup;
  final WatchGroupExpensesUseCase watchExpenses;
  final AddGroupExpenseUseCase addGroupExpense;
  final DeleteGroupExpenseUseCase deleteGroupExpense;
  final UpdateGroupExpenseUseCase updateGroupExpense;
  final RenameGroupUseCase renameGroup;
  final AddGroupMemberUseCase addGroupMember;
  final LeaveGroupUseCase leaveGroup;

  StreamSubscription<Group?>? _groupSubscription;
  StreamSubscription<List<GroupExpense>>? _expensesSubscription;

  String _groupId = '';

  GroupDetailBloc({
    required this.watchGroup,
    required this.watchExpenses,
    required this.addGroupExpense,
    required this.deleteGroupExpense,
    required this.updateGroupExpense,
    required this.renameGroup,
    required this.addGroupMember,
    required this.leaveGroup,
  }) : super(const GroupDetailState()) {
    on<GroupDetailWatched>(_onWatched);
    on<GroupExpenseAdded>(_onExpenseAdded);
    on<GroupExpenseRemoved>(_onExpenseRemoved);
    on<GroupExpenseUpdated>(_onExpenseUpdated);
    on<GroupRenamed>(_onRenamed);
    on<GroupMemberAdded>(_onMemberAdded);
    on<GroupLeft>(_onLeft);
    on<_GroupLoaded>(_onGroupLoaded);
    on<_ExpensesLoaded>(_onExpensesLoaded);
    on<_DetailFailed>(_onFailed);
  }

  Future<void> _onWatched(
    GroupDetailWatched event,
    Emitter<GroupDetailState> emit,
  ) async {
    _groupId = event.groupId;
    emit(const GroupDetailState(status: GroupDetailStatus.loading));

    await _groupSubscription?.cancel();
    await _expensesSubscription?.cancel();

    _groupSubscription = watchGroup(_groupId).listen(
      (group) => add(_GroupLoaded(group)),
      onError: (Object error) => add(_DetailFailed(error.toString())),
    );
    _expensesSubscription = watchExpenses(_groupId).listen(
      (expenses) => add(_ExpensesLoaded(expenses)),
      onError: (Object error) => add(_DetailFailed(error.toString())),
    );
  }

  void _onGroupLoaded(_GroupLoaded event, Emitter<GroupDetailState> emit) {
    if (event.group == null) {
      // Build the state directly: copyWith can't clear the group.
      emit(
        GroupDetailState(
          status: GroupDetailStatus.failure,
          expenses: state.expenses,
          message: 'This group no longer exists.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: GroupDetailStatus.loaded,
        group: event.group,
        message: null,
      ),
    );
  }

  void _onExpensesLoaded(
    _ExpensesLoaded event,
    Emitter<GroupDetailState> emit,
  ) {
    emit(
      state.copyWith(
        status: GroupDetailStatus.loaded,
        expenses: event.expenses,
        message: null,
      ),
    );
  }

  void _onFailed(_DetailFailed event, Emitter<GroupDetailState> emit) {
    emit(
      state.copyWith(status: GroupDetailStatus.failure, message: event.message),
    );
  }

  Future<void> _onExpenseAdded(
    GroupExpenseAdded event,
    Emitter<GroupDetailState> emit,
  ) async {
    emit(state.copyWith(busy: true, message: null));

    try {
      await addGroupExpense(groupId: _groupId, expense: event.expense);
      emit(
        state.copyWith(
          status: GroupDetailStatus.success,
          busy: false,
          message: 'Expense added.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          busy: false,
          status: GroupDetailStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onExpenseRemoved(
    GroupExpenseRemoved event,
    Emitter<GroupDetailState> emit,
  ) async {
    emit(state.copyWith(busy: true, message: null));

    try {
      await deleteGroupExpense(groupId: _groupId, expense: event.expense);
      emit(
        state.copyWith(
          status: GroupDetailStatus.success,
          busy: false,
          message: 'Expense deleted.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          busy: false,
          status: GroupDetailStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onExpenseUpdated(
    GroupExpenseUpdated event,
    Emitter<GroupDetailState> emit,
  ) async {
    emit(state.copyWith(busy: true, message: null));

    try {
      await updateGroupExpense(groupId: _groupId, expense: event.expense);
      emit(
        state.copyWith(
          status: GroupDetailStatus.success,
          busy: false,
          message: 'Expense updated.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          busy: false,
          status: GroupDetailStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onRenamed(
    GroupRenamed event,
    Emitter<GroupDetailState> emit,
  ) async {
    emit(state.copyWith(busy: true, message: null));

    try {
      await renameGroup(groupId: _groupId, name: event.name);
      emit(
        state.copyWith(
          status: GroupDetailStatus.success,
          busy: false,
          message: 'Group renamed.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          busy: false,
          status: GroupDetailStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onMemberAdded(
    GroupMemberAdded event,
    Emitter<GroupDetailState> emit,
  ) async {
    emit(state.copyWith(busy: true, message: null));

    try {
      await addGroupMember(groupId: _groupId, member: event.member);
      emit(
        state.copyWith(
          status: GroupDetailStatus.success,
          busy: false,
          message: '${event.member.name} joined the group.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          busy: false,
          status: GroupDetailStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onLeft(GroupLeft event, Emitter<GroupDetailState> emit) async {
    emit(state.copyWith(busy: true, message: null));

    try {
      await leaveGroup(groupId: _groupId, uid: event.uid);
      emit(
        state.copyWith(
          status: GroupDetailStatus.success,
          busy: false,
          left: true,
          message: 'You left the group.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          busy: false,
          status: GroupDetailStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _groupSubscription?.cancel();
    _expensesSubscription?.cancel();
    return super.close();
  }
}

class _GroupLoaded extends GroupDetailEvent {
  final Group? group;

  const _GroupLoaded(this.group);

  @override
  List<Object?> get props => [group];
}

class _ExpensesLoaded extends GroupDetailEvent {
  final List<GroupExpense> expenses;

  const _ExpensesLoaded(this.expenses);

  @override
  List<Object?> get props => [expenses];
}

class _DetailFailed extends GroupDetailEvent {
  final String message;

  const _DetailFailed(this.message);

  @override
  List<Object?> get props => [message];
}
