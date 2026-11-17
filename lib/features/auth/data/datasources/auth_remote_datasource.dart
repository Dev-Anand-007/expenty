import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/firebase_messaging_service.dart';
import '../models/user_model.dart';

/// Thrown when [FirebaseConstants.googleWebClientId] is still empty.
///
/// Surfaced as-is in the UI so the button explains itself instead of
/// appearing broken.
class GoogleSignInNotConfiguredException implements Exception {
  const GoogleSignInNotConfiguredException();

  @override
  String toString() =>
      'Google Sign-In is not set up yet — paste the Web client ID into '
      'lib/core/constants/firebase_constants.dart.';
}

/// Thrown when [AuthRemoteDataSource.deleteAccount] is asked to delete an
/// email/password account without supplying the password.
///
/// Firebase refuses `user.delete()` unless the session was refreshed
/// recently, so the confirm dialog has to collect it first; this is the
/// safety net if that ever gets skipped.
class PasswordRequiredException implements Exception {
  const PasswordRequiredException();

  @override
  String toString() => 'Enter your password to confirm.';
}

abstract class AuthRemoteDataSource {
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> login({
    required String email,
    required String password,
  });

  /// Signs in with the Google account chosen on the device.
  ///
  /// First sign-in only, the `users` and `profiles` documents are created the
  /// same way [signUp] creates them — later sign-ins must not overwrite a
  /// name the user has edited in their profile.
  Future<void> signInWithGoogle();

  Future<void> logout();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Whether the signed-in account has an email/password credential — i.e.
  /// whether deleting it has to collect a password first.
  ///
  /// Synchronous on purpose: `currentUser.providerData` is already in
  /// memory and the confirm dialog needs the answer while it builds.
  bool requiresPasswordConfirmation();

  /// Permanently removes the account and everything that belongs to it:
  /// group memberships, transactions, wallet, profile, @username, and finally
  /// the Firebase Auth record.
  ///
  /// Order matters. Identity is proven *first*, because Firebase refuses
  /// `delete()` without a fresh sign-in — wiping the documents before
  /// knowing we can finish would strand a half-deleted account.
  Future<void> deleteAccount({String? password});

  Future<bool> isLoggedIn();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user!.updateDisplayName(name);

    final user = UserModel(
      id: credential.user!.uid,
      name: name,
      email: email,
      photoUrl: null,
    );

    await firestore
        .collection('users')
        .doc(user.id)
        .set(user.toJson());

    // Public directory entry so other people can find this user by email
    // when creating a group. Rules only allow writing your own profile.
    await firestore
        .collection('profiles')
        .doc(user.id)
        .set({
      'uid': user.id,
      'name': name,
      'email': email,
      'emailLower': email.trim().toLowerCase(),
    });
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    final webClientId = FirebaseConstants.googleWebClientId.trim();
    if (webClientId.isEmpty) {
      throw const GoogleSignInNotConfiguredException();
    }

    // Cheap and idempotent on Android (it only stores the parameters), so it
    // is called per sign-in rather than once at startup.
    await GoogleSignIn.instance.initialize(serverClientId: webClientId);

    final account = await GoogleSignIn.instance.authenticate();
    final authentication = account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) {
      throw Exception('Google did not return an ID token. Please try again.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await firebaseAuth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) return;

    final name = (user.displayName ?? '').trim();
    final email = (user.email ?? '').trim();

    // Seed Firestore only when the documents are missing — `users` is
    // owner-writable, so re-writing it on every login would silently undo a
    // name the user edited in their profile.
    final usersRef = firestore.collection('users').doc(user.uid);
    if (!(await usersRef.get()).exists) {
      await usersRef.set(
        UserModel(
          id: user.uid,
          name: name,
          email: email,
          photoUrl: user.photoURL,
        ).toJson(),
      );
    }

    if (email.isEmpty) return;

    // Public directory entry so other people can find this user by email when
    // creating a group. Rules only allow writing your own profile.
    final profilesRef = firestore.collection('profiles').doc(user.uid);
    if (!(await profilesRef.get()).exists) {
      await profilesRef.set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'emailLower': email.toLowerCase(),
      });
    }
  }

  @override
  Future<void> logout() async {
    // Drop this device's push token first — the users doc is owner-only,
    // so it must still be writable before we sign out.
    try {
      await FirebaseMessagingService.removeCurrentToken();
    } catch (_) {
      // Best-effort: a stale token only means a dead FCM target.
    }
    await firebaseAuth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await firebaseAuth.sendPasswordResetEmail(
      email: email,
    );
  }

  @override
  Future<void> sendEmailVerification() async {
    await firebaseAuth.currentUser?.sendEmailVerification();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw Exception('You must be signed in to change your password.');
    }

    // Firebase only allows updatePassword() after a fresh sign-in —
    // verifying the current password doubles as that re-authentication.
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  @override
  bool requiresPasswordConfirmation() {
    final providers = firebaseAuth.currentUser?.providerData ?? const [];
    return providers.any((info) => info.providerId == 'password');
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to delete your account.');
    }

    // 1. Prove it is really them — before a single document is touched.
    await _reauthenticate(user, password);

    // 2. Their data.
    await _deleteFirestoreData(user.uid);

    // 3. Finally the auth record itself.
    await user.delete();
  }

  /// Refreshes the session so `user.delete()` is allowed to run.
  Future<void> _reauthenticate(User user, String? password) async {
    if (requiresPasswordConfirmation()) {
      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw const PasswordRequiredException();
      }

      // Verifying the current password doubles as the re-authentication,
      // exactly as changePassword does.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return;
    }

    // Federated sign-in (Google): nothing to type, so refresh the session
    // with the same account picker the sign-in uses. Any failure — including
    // backing out of it — aborts here, with the data still intact.
    final webClientId = FirebaseConstants.googleWebClientId.trim();
    if (webClientId.isEmpty) return; // Not configured, nothing to refresh.

    await GoogleSignIn.instance.initialize(serverClientId: webClientId);
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) return;

    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> _deleteFirestoreData(String uid) async {
    await _leaveGroups(uid);
    await _deleteOwnedUsernames(uid);
    await _deleteSubcollection('users/$uid/transactions');
    await firestore.collection('users').doc(uid).delete();
    await _deleteProfile(uid);
  }

  /// The profile rules deny a delete when the document is missing (there is
  /// no `resource.data.uid` to compare against), so only ask for one when
  /// there is actually something to remove.
  Future<void> _deleteProfile(String uid) async {
    final profile = await firestore.collection('profiles').doc(uid).get();
    if (profile.exists) await profile.reference.delete();
  }

  /// Takes the account out of every group it belongs to.
  ///
  /// The app's own leave-group refuses to run when you are the last member —
  /// which is exactly where a solo tester sits — so a group that exists only
  /// for this account is deleted outright instead.
  Future<void> _leaveGroups(String uid) async {
    final snapshot = await firestore
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final memberIds =
          List<String>.from(data['memberIds'] as List? ?? const []);
      final members =
          List<Map<String, dynamic>>.from(data['members'] as List? ?? const []);
      final createdBy = data['createdBy'] as String? ?? '';

      // `members` is the richer of the two lists on older data, so fall back
      // to it when `memberIds` never got written.
      final memberCount =
          memberIds.isNotEmpty ? memberIds.length : members.length;

      if (memberCount <= 1 && createdBy == uid) {
        await _deleteGroupWithExpenses(doc.reference);
        continue;
      }

      // `memberBalances` is deliberately left alone: the leaver's share of
      // every past expense still exists, so dropping it would unbalance the
      // books for everyone who stays.
      await doc.reference.update({
        'members': [
          for (final m in members)
            if (m['uid'] != uid) m,
        ],
        'memberIds': [
          for (final id in memberIds)
            if (id != uid) id,
        ],
      });
    }
  }

  Future<void> _deleteGroupWithExpenses(
    DocumentReference<Map<String, dynamic>> group,
  ) async {
    // The expense rules call get() on the parent group, and Firestore caps
    // those at 10 per request — hence the much smaller chunks here.
    await _deleteSubcollection('${group.path}/expenses', batchSize: 10);
    await group.delete();
  }

  /// Releases every @handle this account claimed so somebody else can use it.
  Future<void> _deleteOwnedUsernames(String uid) async {
    final snapshot = await firestore
        .collection('usernames')
        .where('uid', isEqualTo: uid)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Firestore has no recursive delete on the client, so drain a collection
  /// in chunks. A write batch caps at 500 operations; group expenses are
  /// limited to [batchSize] by the rules `get()` allowance instead.
  Future<void> _deleteSubcollection(
    String path, {
    int batchSize = 400,
  }) async {
    while (true) {
      final snapshot =
          await firestore.collection(path).limit(batchSize).get();
      if (snapshot.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return firebaseAuth.currentUser != null;
  }
}