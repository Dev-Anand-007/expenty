import '../repositories/profile_repository.dart';

class SetUsernameUseCase {
  final ProfileRepository repository;

  SetUsernameUseCase(this.repository);

  Future<void> call(String username) => repository.setUsername(username);
}
