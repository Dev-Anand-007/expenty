import '../entities/profile.dart';

abstract class ProfileRepository {
  /// Loads the profile for the signed-in user.
  Future<Profile> getProfile();

  /// Updates the display name everywhere it is stored (Auth + Firestore).
  Future<void> updateDisplayName(String name);

  /// Claims [username] for the signed-in user.
  /// Throws when the username is invalid or already taken.
  Future<void> setUsername(String username);

  /// Uploads the image at [filePath] as the avatar and persists its URL.
  Future<void> updateProfilePhoto(String filePath);
}
