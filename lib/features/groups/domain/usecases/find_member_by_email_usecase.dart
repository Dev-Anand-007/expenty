import '../entities/group.dart';
import '../repositories/group_repository.dart';

class FindMemberByEmailUseCase {
  final GroupRepository repository;

  FindMemberByEmailUseCase(this.repository);

  Future<GroupMember?> call(String email) =>
      repository.findMemberByEmail(email);
}
