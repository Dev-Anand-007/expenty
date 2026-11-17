import '../repositories/auth_repository.dart';

/// Signs the user in with the Google account already on the device.
class GoogleSignInUseCase {
  final AuthRepository repository;

  GoogleSignInUseCase(this.repository);

  Future<void> call() => repository.signInWithGoogle();
}
