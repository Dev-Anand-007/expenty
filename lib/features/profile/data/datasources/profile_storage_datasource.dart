import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

abstract class ProfileStorageDataSource {
  /// Uploads the image at [filePath] as the avatar for [uid]
  /// and returns its public download URL.
  Future<String> uploadAvatar(String uid, String filePath);
}

class ProfileStorageDataSourceImpl implements ProfileStorageDataSource {
  final FirebaseStorage storage;

  ProfileStorageDataSourceImpl({required this.storage});

  @override
  Future<String> uploadAvatar(String uid, String filePath) async {
    // Fixed path per user: re-uploading replaces the old avatar.
    final ref = storage.ref('avatars/$uid.jpg');

    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await ref.getDownloadURL();
  }
}
