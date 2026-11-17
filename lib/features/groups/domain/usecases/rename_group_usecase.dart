import '../repositories/group_repository.dart';

class RenameGroupUseCase {
  final GroupRepository repository;

  RenameGroupUseCase(this.repository);

  Future<void> call({required String groupId, required String name}) {
    return repository.renameGroup(groupId, name);
  }
}
