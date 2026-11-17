import '../entities/group.dart';
import '../repositories/group_repository.dart';

class CreateGroupUseCase {
  final GroupRepository repository;

  CreateGroupUseCase(this.repository);

  /// Returns the new group's id.
  Future<String> call({
    required String name,
    required List<GroupMember> members,
  }) {
    return repository.create(name: name, members: members);
  }
}
