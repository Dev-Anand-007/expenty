import '../entities/group.dart';
import '../entities/group_expense.dart';

abstract class GroupRepository {
  Stream<List<Group>> watchMine();

  /// Returns the new group's id.
  Future<String> create({
    required String name,
    required List<GroupMember> members,
  });

  Stream<Group?> watchGroup(String groupId);

  Stream<List<GroupExpense>> watchExpenses(String groupId);

  Future<void> addExpense(String groupId, GroupExpense expense);

  Future<void> deleteExpense(String groupId, GroupExpense expense);

  /// Rewrites an existing expense and rebalances the group in one
  /// transaction. [expense] carries the audit fields (editedAt / reason).
  Future<void> updateExpense(String groupId, GroupExpense expense);

  /// Renames the group. Any member may do this.
  Future<void> renameGroup(String groupId, String name);

  /// Adds a member to an existing group (no-op if already a member).
  Future<void> addMember(String groupId, GroupMember member);

  /// Removes the given member from the group. Balances are left intact so
  /// the remaining members' nets stay correct.
  Future<void> leaveGroup(String groupId, String uid);

  /// Looks up a registered user by email (profiles collection).
  Future<GroupMember?> findMemberByEmail(String email);

  /// Looks up a registered user by @username (profiles collection).
  Future<GroupMember?> findMemberByUsername(String username);

  Future<void> syncOwnProfile();
}
