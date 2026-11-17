import '../entities/group.dart';
import '../repositories/group_repository.dart';

class FindMemberByUsernameUseCase {
  final GroupRepository repository;

  FindMemberByUsernameUseCase(this.repository);

  Future<GroupMember?> call(String username) =>
      repository.findMemberByUsername(username);
}
