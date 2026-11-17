import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasources/group_remote_datasource.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;

  GroupRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<Group>> watchMine() => remoteDataSource.watchMine();

  @override
  Future<String> create({
    required String name,
    required List<GroupMember> members,
  }) => remoteDataSource.create(name: name, members: members);

  @override
  Stream<Group?> watchGroup(String groupId) =>
      remoteDataSource.watchGroup(groupId);

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) =>
      remoteDataSource.watchExpenses(groupId);

  @override
  Future<void> addExpense(String groupId, GroupExpense expense) =>
      remoteDataSource.addExpense(groupId, expense);

  @override
  Future<void> deleteExpense(String groupId, GroupExpense expense) =>
      remoteDataSource.deleteExpense(groupId, expense);

  @override
  Future<void> updateExpense(String groupId, GroupExpense expense) =>
      remoteDataSource.updateExpense(groupId, expense);

  @override
  Future<void> renameGroup(String groupId, String name) =>
      remoteDataSource.renameGroup(groupId, name);

  @override
  Future<void> addMember(String groupId, GroupMember member) =>
      remoteDataSource.addMember(groupId, member);

  @override
  Future<void> leaveGroup(String groupId, String uid) =>
      remoteDataSource.leaveGroup(groupId, uid);

  @override
  Future<GroupMember?> findMemberByEmail(String email) =>
      remoteDataSource.findMemberByEmail(email);

  @override
  Future<GroupMember?> findMemberByUsername(String username) =>
      remoteDataSource.findMemberByUsername(username);

  @override
  Future<void> syncOwnProfile() => remoteDataSource.syncOwnProfile();
}
