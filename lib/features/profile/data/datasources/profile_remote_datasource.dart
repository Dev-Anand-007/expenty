import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/profile.dart';

abstract class ProfileRemoteDataSource {
  Future<Profile> getProfile();

  /// Updates the name in Firebase Auth and both Firestore docs.
  Future<void> updateDisplayName(String name);

  /// Atomically claims [username] for the signed-in user.
  /// Throws when it is already taken.
  Future<void> claimUsername(String username);

  /// Persists the avatar URL in Firebase Auth and both Firestore docs.
  Future<void> updatePhotoUrl(String url);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  ProfileRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  DocumentReference<Map<String, dynamic>> get _users =>
      firestore.collection('users').doc(_uid);

  DocumentReference<Map<String, dynamic>> get _profiles =>
      firestore.collection('profiles').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _usernames =>
      firestore.collection('usernames');

  String get _uid {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Please sign in again to edit your profile.');
    }
    return user.uid;
  }

  /// Base fields so a legacy doc missing from `profiles` still gets the
  /// lookups (emailLower) right when we merge into it.
  Map<String, dynamic> _profileBase(User user) => {
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'emailLower': (user.email ?? '').trim().toLowerCase(),
      };

  @override
  Future<Profile> getProfile() async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Please sign in again to view your profile.');
    }

    final email = user.email ?? '';
    final fallbackName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (email.contains('@') ? email.split('@').first : 'User');

    final usersSnap = await _users.get();
    final usersData = usersSnap.data();

    if (usersData != null) {
      final name = (usersData['name'] as String?)?.trim();
      return Profile(
        id: user.uid,
        name: (name == null || name.isEmpty) ? fallbackName : name,
        email: (usersData['email'] as String?) ?? email,
        username: usersData['username'] as String?,
        photoUrl: (usersData['photoUrl'] as String?) ?? user.photoURL,
      );
    }

    // Legacy account without a `users` doc — fall back to Auth + profiles.
    final profilesSnap = await _profiles.get();
    final profilesData = profilesSnap.data();
    final profileName = (profilesData?['name'] as String?)?.trim();

    return Profile(
      id: user.uid,
      name: (profileName == null || profileName.isEmpty)
          ? fallbackName
          : profileName,
      email: (profilesData?['email'] as String?) ?? email,
      username: profilesData?['username'] as String?,
      photoUrl: user.photoURL,
    );
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Please sign in again to edit your profile.');
    }

    final trimmed = name.trim();

    await user.updateDisplayName(trimmed);

    await _users.set({'name': trimmed}, SetOptions(merge: true));
    await _profiles.set(
      {..._profileBase(user), 'name': trimmed},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> claimUsername(String username) async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Please sign in again to edit your profile.');
    }

    final handle = username.trim().toLowerCase();
    final newRef = _usernames.doc(handle);

    await firestore.runTransaction((transaction) async {
      // All reads must happen before any write.
      final usersSnap = await transaction.get(_users);
      final current = ((usersSnap.data()?['username'] as String?) ?? '')
          .trim()
          .toLowerCase();

      final newSnap = await transaction.get(newRef);
      if (newSnap.exists && newSnap.data()?['uid'] != user.uid) {
        throw Exception('That username is already taken.');
      }

      if (current.isNotEmpty && current != handle) {
        final oldRef = _usernames.doc(current);
        final oldSnap = await transaction.get(oldRef);
        if (oldSnap.exists && oldSnap.data()?['uid'] == user.uid) {
          transaction.delete(oldRef);
        }
      }

      transaction.set(newRef, {'uid': user.uid, 'username': handle});
      transaction.set(
        _users,
        {'username': handle},
        SetOptions(merge: true),
      );
      transaction.set(
        _profiles,
        {..._profileBase(user), 'username': handle},
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> updatePhotoUrl(String url) async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Please sign in again to edit your profile.');
    }

    await user.updatePhotoURL(url);

    await _users.set({'photoUrl': url}, SetOptions(merge: true));
    await _profiles.set(
      {..._profileBase(user), 'photoUrl': url},
      SetOptions(merge: true),
    );
  }
}
