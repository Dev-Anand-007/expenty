import '../repositories/profile_repository.dart';

class UpdateProfilePhotoUseCase {
  final ProfileRepository repository;

  UpdateProfilePhotoUseCase(this.repository);

  Future<void> call(String filePath) =>
      repository.updateProfilePhoto(filePath);
}
