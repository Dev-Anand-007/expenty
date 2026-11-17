import '../repositories/profile_repository.dart';

class UpdateDisplayNameUseCase {
  final ProfileRepository repository;

  UpdateDisplayNameUseCase(this.repository);

  Future<void> call(String name) => repository.updateDisplayName(name);
}
