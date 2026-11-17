import 'failure.dart';

class FirebaseFailure extends Failure {
  const FirebaseFailure(super.message);

  factory FirebaseFailure.fromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return const FirebaseFailure('Please enter a valid email.');

      case 'user-not-found':
        return const FirebaseFailure('No account found with this email.');

      case 'wrong-password':
        return const FirebaseFailure('Incorrect password.');

      case 'email-already-in-use':
        return const FirebaseFailure('This email is already registered.');

      case 'weak-password':
        return const FirebaseFailure(
          'Password should be at least 6 characters.',
        );

      case 'network-request-failed':
        return const FirebaseFailure(
          'No internet connection.',
        );

      default:
        return const FirebaseFailure(
          'Something went wrong. Please try again.',
        );
    }
  }
}
