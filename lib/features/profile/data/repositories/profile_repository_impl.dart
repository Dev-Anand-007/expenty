import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../datasources/profile_storage_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final FirebaseAuth firebaseAuth;
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileStorageDataSource storageDataSource;

  ProfileRepositoryImpl({
    required this.firebaseAuth,
    required this.remoteDataSource,
    required this.storageDataSource,
  });

  @override
  Future<Profile> getProfile() => remoteDataSource.getProfile();

  @override
  Future<void> updateDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Name cannot be empty');
    }
    return remoteDataSource.updateDisplayName(trimmed);
  }

  @override
  Future<void> setUsername(String username) =>
      remoteDataSource.claimUsername(username);

  @override
  Future<void> updateProfilePhoto(String filePath) async {
    final uid = firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Please sign in again to edit your profile.');
    }

    final url = await storageDataSource.uploadAvatar(uid, filePath);
    await remoteDataSource.updatePhotoUrl(url);
  }
}
