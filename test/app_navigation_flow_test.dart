import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/app/theme/theme_cubit.dart';
import 'package:expenty/features/auth/domain/repositories/auth_repository.dart';
import 'package:expenty/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/entities/group_expense.dart';
import 'package:expenty/features/groups/domain/repositories/group_repository.dart';
import 'package:expenty/features/groups/presentation/pages/add_group_expense_page.dart';
import 'package:expenty/features/groups/presentation/pages/create_group_page.dart';
import 'package:expenty/features/groups/presentation/pages/group_detail_page.dart';
import 'package:expenty/features/profile/domain/entities/profile.dart';
import 'package:expenty/features/profile/domain/repositories/profile_repository.dart';
import 'package:expenty/features/profile/presentation/pages/profile_page.dart';
import 'package:expenty/features/settings/presentation/pages/settings_page.dart';
import 'package:expenty/features/transactions/domain/entities/money_transaction.dart';
import 'package:expenty/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:expenty/features/wallet/domain/entities/wallet.dart';
import 'package:expenty/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

MoneyTransaction _tx({
  required String title,
  required double amount,
  required TransactionType type,
  required String category,
}) {
  final now = DateTime.now();
  return MoneyTransaction(
    id: '$title-$amount',
    title: title,
    amount: amount,
    type: type,
    category: category,
    date: now,
    createdAt: now,
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> login({required String email, required String password}) async {}

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
  Future<bool> isLoggedIn() async => true;
}

class _FakeTransactionRepository implements TransactionRepository {
  @override
  Stream<List<MoneyTransaction>> watchAll() async* {
    yield [
      _tx(
        title: 'Salary',
        amount: 50000,
        type: TransactionType.income,
        category: 'Salary',
      ),
      _tx(
        title: 'Weekly groceries',
        amount: 1200,
        type: TransactionType.expense,
        category: 'Groceries',
      ),
    ];
  }

  @override
  Future<void> add(MoneyTransaction transaction) async {}

  @override
  Future<void> update(MoneyTransaction transaction) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Stream<Wallet> watch() async* {
    yield const Wallet(balance: 10000);
  }

  @override
  Future<void> addBalance(double amount) async {}

  @override
  Future<void> resetBalance() async {}
}

class _FakeGroupRepository implements GroupRepository {
  final group = Group(
    id: 'g1',
    name: 'Goa trip',
    createdBy: 'u1',
    createdAt: DateTime.now(),
    members: const [
      GroupMember(uid: 'u1', name: 'Anand', email: 'anand@x.com'),
      GroupMember(uid: 'u2', name: 'Rahul', email: 'rahul@x.com'),
    ],
    memberBalances: const {'u1': 500, 'u2': -500},
  );

  GroupExpense? lastExpense;

  @override
  Stream<List<Group>> watchMine() async* {
    yield [group];
  }

  @override
  Future<String> create({
    required String name,
    required List<GroupMember> members,
  }) async => 'g1';

  @override
  Stream<Group?> watchGroup(String groupId) async* {
    yield group;
  }

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) async* {
    await Future<void>.delayed(Duration.zero);
    yield [
      GroupExpense(
        id: 'e1',
        title: 'Dinner',
        amount: 600,
        paidBy: 'u1',
        splitType: SplitType.equal,
        shares: const {'u1': 300, 'u2': 300},
        splitLabel: 'Equal',
        date: DateTime(2026, 11, 7),
        createdAt: DateTime(2026, 11, 7),
        createdBy: 'u1',
      ),
    ];
  }

  @override
  Future<void> addExpense(String groupId, GroupExpense expense) async {
    lastExpense = expense;
  }

  @override
  Future<void> deleteExpense(String groupId, GroupExpense expense) async {}

  @override
  Future<void> updateExpense(String groupId, GroupExpense expense) async {}

  @override
  Future<void> renameGroup(String groupId, String name) async {}

  @override
  Future<void> addMember(String groupId, GroupMember member) async {}

  @override
  Future<void> leaveGroup(String groupId, String uid) async {}

  @override
  Future<GroupMember?> findMemberByEmail(String email) async => null;

  @override
  Future<GroupMember?> findMemberByUsername(String username) async => null;

  @override
  Future<void> syncOwnProfile() async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Profile> getProfile() async => const Profile(
    id: 'u1',
    name: 'Asha',
    email: 'asha@example.com',
    username: 'asha',
  );

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  Future<void> setUsername(String username) async {}

  @override
  Future<void> updateProfilePhoto(String filePath) async {}
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupLocator();

    await sl.unregister<AuthRepository>();
    sl.registerLazySingleton<AuthRepository>(() => _FakeAuthRepository());

    await sl.unregister<TransactionRepository>();
    sl.registerLazySingleton<TransactionRepository>(
      () => _FakeTransactionRepository(),
    );

    await sl.unregister<WalletRepository>();
    sl.registerLazySingleton<WalletRepository>(() => _FakeWalletRepository());

    await sl.unregister<GroupRepository>();
    sl.registerLazySingleton<GroupRepository>(() => _FakeGroupRepository());

    await sl.unregister<ProfileRepository>();
    sl.registerLazySingleton<ProfileRepository>(() => _FakeProfileRepository());
  });

  tearDownAll(() async {
    await sl.reset();
  });

  testWidgets('dashboard → group → back → add expense → save (no crash)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/groups/new',
          builder: (context, state) => const CreateGroupPage(),
        ),
        GoRoute(
          path: '/groups/:id',
          builder: (context, state) =>
              GroupDetailPage(groupId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/groups/:id/add-expense',
          builder: (context, state) =>
              AddGroupExpensePage(groupId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Home tab: balance + group owe/pay card.
    expect(find.text('Across your groups'), findsOneWidget);

    // Bottom sheet from the balance card — same taps as the bug report:
    // open → pick a quick amount → press Add Balance.
    await tester.tap(find.text('Add balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add balance'), findsWidgets);

    await tester.tap(find.text('₹500.00'));
    await tester.pump();
    await tester.tap(find.text('Add Balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Added ₹500.00 to your wallet'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));

    // Open the Groups tab.
    await tester.tap(find.text('Groups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Goa trip'), findsOneWidget);

    // Push the group detail page.
    router.push('/groups/g1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Settlements'), findsOneWidget);

    // Push the add-expense page on top, then save → snackbar + pop.
    router.push('/groups/g1/add-expense');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Add expense · Goa trip'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '600');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dinner');
    await tester.pump();
    await tester.tap(find.text('Save Expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Expense added.'), findsOneWidget);
    expect(find.text('Settlements'), findsOneWidget);

    // Delete confirmation dialog on the expense.
    await tester.tap(find.byKey(const Key('expense-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete expense?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Pop back to the dashboard — the Groups tab is still selected.
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Goa trip'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Across your groups'), findsOneWidget);

    // Create-group flow ends with pushReplacement (can't actually create
    // without a signed-in user in tests, so perform the same navigator op).
    router.push('/groups/new');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('New group'), findsOneWidget);

    router.pushReplacement('/groups/g1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Settlements'), findsOneWidget);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Switch tabs a few times.
    for (final label in ['Activity', 'Groups', 'Menu', 'Home']) {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
  });

  testWidgets('Menu opens the Profile and Settings pages', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>(
        create: (_) => ThemeCubit(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Menu tab → Profile.
    await tester.tap(find.text('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('profile-title')), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Save username'), findsOneWidget);

    // Back to the menu → Settings.
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('settings-title')), findsOneWidget);
    expect(find.byKey(const Key('settings-dark-mode')), findsOneWidget);
  });
}
