import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/app/router/route_names.dart';
import 'package:expenty/features/auth/domain/repositories/auth_repository.dart';
import 'package:expenty/features/auth/presentation/pages/login_page.dart';
import 'package:expenty/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// LoginPage builds its own AuthBloc through get_it, so the container needs a
/// repository that never touches Firebase.
class _StubAuthRepository implements AuthRepository {
  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  bool requiresPasswordConfirmation() => false;

  @override
  Future<void> deleteAccount({String? password}) async {}

  @override
  Future<bool> isLoggedIn() async => false;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    await setupLocator();
    await sl.unregister<AuthRepository>();
    sl.registerLazySingleton<AuthRepository>(() => _StubAuthRepository());
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('splash plays the logo animation, then hands over to login', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RouteNames.splash,
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const LoginPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    // The animation replaces the old spinner, on the brand navy background.
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF0D132B));

    // Past the 2 s hand-off.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
