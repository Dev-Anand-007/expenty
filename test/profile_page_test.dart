import 'dart:async';

import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/features/profile/domain/entities/profile.dart';
import 'package:expenty/features/profile/domain/repositories/profile_repository.dart';
import 'package:expenty/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeProfileRepository implements ProfileRepository {
  Profile profile = const Profile(
    id: 'u1',
    name: 'Asha',
    email: 'asha@example.com',
    username: 'asha',
  );

  final savedNames = <String>[];
  final savedUsernames = <String>[];

  @override
  Future<Profile> getProfile() async => profile;

  @override
  Future<void> updateDisplayName(String name) async {
    savedNames.add(name);
    profile = profile.copyWith(name: name);
  }

  @override
  Future<void> setUsername(String username) async {
    savedUsernames.add(username);
    profile = profile.copyWith(username: username);
  }

  @override
  Future<void> updateProfilePhoto(String filePath) async {
    profile = profile.copyWith(photoUrl: 'https://example.com/avatar.jpg');
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late _FakeProfileRepository fake;

  setUp(() async {
    await setupLocator();
    await sl.unregister<ProfileRepository>();
    fake = _FakeProfileRepository();
    sl.registerLazySingleton<ProfileRepository>(() => fake);
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('loads and shows the personal details', (tester) async {
    await pumpProfile(tester);

    expect(find.byKey(const Key('profile-title')), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);

    // The username section sits below the fold on a short test screen.
    final usernameField = find.byKey(const Key('profile-username-field'));
    await tester.ensureVisible(usernameField);
    await tester.pump();
    expect(find.text('Friends can find and add you with @username.'),
        findsOneWidget);

    final emailField = find.byKey(const Key('profile-email-field'));
    await tester.ensureVisible(emailField);
    await tester.pump();
    expect(find.text('asha@example.com'), findsOneWidget);
  });

  testWidgets('saves an edited display name', (tester) async {
    await pumpProfile(tester);

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Asha Kumar',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile-save-name')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.savedNames, contains('Asha Kumar'));
    expect(find.text('Profile updated'), findsOneWidget);
  });

  testWidgets('only the pressed save button spins while a save runs', (
    tester,
  ) async {
    final slow = _SlowProfileRepository();
    await sl.unregister<ProfileRepository>();
    sl.registerLazySingleton<ProfileRepository>(() => slow);

    await pumpProfile(tester);

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Asha Kumar',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile-save-name')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Name save is in flight: only its button shows the spinner.
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-save-name')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-save-username')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    // The other button is parked, not spinning.
    expect(
      tester
          .widget<ElevatedButton>(
            find.descendant(
              of: find.byKey(const Key('profile-save-username')),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNull,
    );

    slow.releaseName();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Profile updated'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-save-name')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('photo button is parked as coming soon', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byKey(const Key('profile-photo-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Profile photo is coming soon'), findsOneWidget);
    // The picker sheet must not open.
    expect(find.text('Choose from gallery'), findsNothing);
    expect(find.text('Take a photo'), findsNothing);
  });

  testWidgets('rejects an invalid username without saving', (tester) async {
    await pumpProfile(tester);

    await tester.enterText(
      find.byKey(const Key('profile-username-field')),
      'ab',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile-save-username')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.savedUsernames, isEmpty);
    expect(find.text('Usernames need at least 3 characters'), findsOneWidget);
  });

  testWidgets('saves a valid username', (tester) async {
    await pumpProfile(tester);

    await tester.enterText(
      find.byKey(const Key('profile-username-field')),
      'ASHA.kumar',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile-save-username')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.savedUsernames, ['asha.kumar']);
    expect(find.text('Profile updated'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when loading fails', (
    tester,
  ) async {
    final failing = _FailingProfileRepository();
    await sl.unregister<ProfileRepository>();
    sl.registerLazySingleton<ProfileRepository>(() => failing);

    await pumpProfile(tester);

    expect(find.byKey(const Key('profile-retry')), findsOneWidget);
    expect(find.textContaining('Could not load'), findsOneWidget);
  });
}

class _FailingProfileRepository implements ProfileRepository {
  @override
  Future<Profile> getProfile() async => throw Exception('boom');

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  Future<void> setUsername(String username) async {}

  @override
  Future<void> updateProfilePhoto(String filePath) async {}
}

/// Holds the name save open until [releaseName] so a test can observe the
/// in-flight (loading) UI.
class _SlowProfileRepository extends _FakeProfileRepository {
  final _nameGate = Completer<void>();

  void releaseName() {
    if (!_nameGate.isCompleted) _nameGate.complete();
  }

  @override
  Future<void> updateDisplayName(String name) async {
    await _nameGate.future;
    await super.updateDisplayName(name);
  }
}
