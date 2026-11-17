import 'package:equatable/equatable.dart';

import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';

abstract class GroupDetailEvent extends Equatable {
  const GroupDetailEvent();

  @override
  List<Object?> get props => [];
}

class GroupDetailWatched extends GroupDetailEvent {
  final String groupId;

  const GroupDetailWatched(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

class GroupExpenseAdded extends GroupDetailEvent {
  final GroupExpense expense;

  const GroupExpenseAdded(this.expense);

  @override
  List<Object?> get props => [expense];
}

class GroupExpenseRemoved extends GroupDetailEvent {
  final GroupExpense expense;

  const GroupExpenseRemoved(this.expense);

  @override
  List<Object?> get props => [expense];
}

/// Rewrites an existing expense. [expense] must already carry the audit
/// fields (editedAt, editedBy, editReason, originalAmount).
class GroupExpenseUpdated extends GroupDetailEvent {
  final GroupExpense expense;

  const GroupExpenseUpdated(this.expense);

  @override
  List<Object?> get props => [expense];
}

class GroupRenamed extends GroupDetailEvent {
  final String name;

  const GroupRenamed(this.name);

  @override
  List<Object?> get props => [name];
}

class GroupMemberAdded extends GroupDetailEvent {
  final GroupMember member;

  const GroupMemberAdded(this.member);

  @override
  List<Object?> get props => [member];
}

class GroupLeft extends GroupDetailEvent {
  final String uid;

  const GroupLeft(this.uid);

  @override
  List<Object?> get props => [uid];
}
