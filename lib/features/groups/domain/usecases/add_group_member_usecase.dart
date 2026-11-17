import '../entities/group.dart';
import '../repositories/group_repository.dart';

class AddGroupMemberUseCase {
  final GroupRepository repository;

  AddGroupMemberUseCase(this.repository);

  Future<void> call({required String groupId, required GroupMember member}) {
    return repository.addMember(groupId, member);
  }
}
