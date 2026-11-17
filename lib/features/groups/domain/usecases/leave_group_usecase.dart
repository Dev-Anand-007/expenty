import '../repositories/group_repository.dart';

class LeaveGroupUseCase {
  final GroupRepository repository;

  LeaveGroupUseCase(this.repository);

  Future<void> call({required String groupId, required String uid}) {
    return repository.leaveGroup(groupId, uid);
  }
}
