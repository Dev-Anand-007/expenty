import '../entities/group.dart';
import '../repositories/group_repository.dart';

class WatchMyGroupsUseCase {
  final GroupRepository repository;

  WatchMyGroupsUseCase(this.repository);

  Stream<List<Group>> call() => repository.watchMine();
}
