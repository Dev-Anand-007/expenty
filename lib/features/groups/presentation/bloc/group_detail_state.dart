import 'package:equatable/equatable.dart';

import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';

enum GroupDetailStatus { initial, loading, loaded, success, failure }

class GroupDetailState extends Equatable {
  final GroupDetailStatus status;
  final Group? group;
  final List<GroupExpense> expenses;
  final bool busy;
  final String? message;

  /// Set once the signed-in member leaves the group, so the page can
  /// navigate away instead of showing a dead group.
  final bool left;

  const GroupDetailState({
    this.status = GroupDetailStatus.initial,
    this.group,
    this.expenses = const [],
    this.busy = false,
    this.message,
    this.left = false,
  });

  /// Keeps every existing field unless a new value is supplied — most
  /// importantly the loaded [group], which several independent stream
  /// events update (group doc + expenses).
  GroupDetailState copyWith({
    GroupDetailStatus? status,
    Group? group,
    List<GroupExpense>? expenses,
    bool? busy,
    String? message,
    bool? left,
  }) {
    return GroupDetailState(
      status: status ?? this.status,
      group: group ?? this.group,
      expenses: expenses ?? this.expenses,
      busy: busy ?? this.busy,
      message: message,
      left: left ?? this.left,
    );
  }

  @override
  List<Object?> get props => [status, group, expenses, busy, message, left];
}
