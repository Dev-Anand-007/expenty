import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return remoteDataSource.signUp(
      name: name,
      email: email,
      password: password,
    );
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) {
    return remoteDataSource.login(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() {
    return remoteDataSource.signInWithGoogle();
  }

  @override
  Future<void> logout() {
    return remoteDataSource.logout();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return remoteDataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<void> sendEmailVerification() {
    return remoteDataSource.sendEmailVerification();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  bool requiresPasswordConfirmation() {
    return remoteDataSource.requiresPasswordConfirmation();
  }

  @override
  Future<void> deleteAccount({String? password}) {
    return remoteDataSource.deleteAccount(password: password);
  }

  @override
  Future<bool> isLoggedIn() {
    return remoteDataSource.isLoggedIn();
  }
}