import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  /// Returns the signed-in user, or `null` when Firebase isn't available
  /// (e.g. in widget tests where Firebase has not been initialized).
  static User? get currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  static bool get isLoggedIn => currentUser != null;

  /// Display name for greetings, falling back to the email local-part.
  static String get displayName {
    final user = currentUser;

    if (user == null) return 'User';

    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user.email;
    if (email != null && email.contains('@')) {
      final local = email.split('@').first;
      if (local.isNotEmpty) return local;
    }

    return 'User';
  }
}
