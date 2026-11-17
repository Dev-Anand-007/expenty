import '../repositories/group_repository.dart';

class SyncOwnProfileUseCase {
  final GroupRepository repository;

  SyncOwnProfileUseCase(this.repository);

  Future<void> call() => repository.syncOwnProfile();
}
