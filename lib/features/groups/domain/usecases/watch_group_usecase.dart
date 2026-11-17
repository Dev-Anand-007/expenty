import '../entities/group.dart';
import '../repositories/group_repository.dart';

class WatchGroupUseCase {
  final GroupRepository repository;

  WatchGroupUseCase(this.repository);

  Stream<Group?> call(String groupId) => repository.watchGroup(groupId);
}
