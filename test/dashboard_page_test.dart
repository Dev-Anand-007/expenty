import 'dart:convert';

import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/core/services/save_service.dart';
import 'package:expenty/core/services/share_service.dart';
import 'package:expenty/features/auth/domain/repositories/auth_repository.dart';
import 'package:expenty/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:expenty/features/dashboard/presentation/widgets/dashboard_bottom_nav.dart';
import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/entities/group_expense.dart';
import 'package:expenty/features/groups/domain/repositories/group_repository.dart';
import 'package:expenty/features/transactions/domain/entities/money_transaction.dart';
import 'package:expenty/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:expenty/features/wallet/domain/entities/wallet.dart';
import 'package:expenty/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

MoneyTransaction _tx({
  required String title,
  required double amount,
  required TransactionType type,
  required String category,
  DateTime? date,
}) {
  final now = DateTime.now();
  return MoneyTransaction(
    id: '$title-$amount',
    title: title,
    amount: amount,
    type: type,
    category: category,
    date: date ?? now,
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
      _tx(
        title: 'Dinner out',
        amount: 450,
        type: TransactionType.expense,
        category: 'Dining',
      ),
      _tx(
        title: 'Fuel',
        amount: 2000,
        type: TransactionType.expense,
        category: 'Car',
        date: DateTime.now().subtract(const Duration(days: 20)),
      ),
      // Mirrored from the dashboard's quick "Add balance" sheet.
      _tx(
        title: 'Balance added',
        amount: 2000,
        type: TransactionType.income,
        category: 'Wallet top-up',
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
  @override
  Stream<List<Group>> watchMine() async* {
    yield [
      Group(
        id: 'g1',
        name: 'Goa trip',
        createdBy: 'u1',
        createdAt: DateTime.now(),
        members: const [
          GroupMember(uid: 'u1', name: 'Anand', email: 'anand@x.com'),
          GroupMember(uid: 'u2', name: 'Rahul', email: 'rahul@x.com'),
        ],
        // The signed-out test user has no uid, so the card reads this key.
        memberBalances: {'': -500, 'u1': 500, 'u2': 0},
      ),
    ];
  }

  @override
  Future<String> create({
    required String name,
    required List<GroupMember> members,
  }) async => 'g1';

  @override
  Stream<Group?> watchGroup(String groupId) async* {
    yield null;
  }

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) async* {}

  @override
  Future<void> addExpense(String groupId, GroupExpense expense) async {}

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
  });

  tearDownAll(() async {
    await sl.reset();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    // Tall viewport so the full scrollable dashboard is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders live balance, income and section headers', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Top 5 expenses'), findsOneWidget);
    expect(find.text('Your full history'), findsOneWidget);

    // Wallet 10000 + income 52000 (incl. the 2000 top-up) − all-time
    // expenses 3650 (1200+450+2000) − the 2000 top-up counted once more
    // because the wallet field already holds it → 56,350.
    expect(find.text('₹56,350.00'), findsOneWidget);
    expect(find.text('₹52,000.00'), findsOneWidget);
    expect(find.text('Add balance'), findsOneWidget);

    // Group owe/pay summary sits below the balance.
    expect(find.text('Across your groups'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    expect(find.text('₹500.00'), findsOneWidget);
  });

  testWidgets('shows all four bottom navigation tabs', (tester) async {
    await pumpDashboard(tester);

    final nav = find.byType(DashboardBottomNav);
    for (final label in ['Home', 'Activity', 'Groups', 'Menu']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }

    // Center elevated add button sits in the bar.
    expect(
      find.descendant(of: nav, matching: find.byIcon(Icons.add_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('Groups tab lists my groups with a net position', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Groups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Goa trip'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(find.text('New group'), findsOneWidget);
    // The signed-out test user has no uid → their net reads as settled.
    expect(find.text('Settled up'), findsOneWidget);
  });

  testWidgets('switches to Activity tab with filtered transactions', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Activity'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Net for this period'), findsOneWidget);
    expect(find.text('5 transactions'), findsOneWidget);

    // Income / expense filter narrows the list to expenses only.
    await tester.tap(find.byKey(const Key('activity-filter-Expense')));
    await tester.pump();
    expect(find.text('3 transactions'), findsOneWidget);

    // ...and to income only (salary + the wallet top-up).
    await tester.tap(find.byKey(const Key('activity-filter-Income')));
    await tester.pump();
    expect(find.text('2 transactions'), findsOneWidget);

    // Back to everything.
    await tester.tap(find.byKey(const Key('activity-filter-All')));
    await tester.pump();
    expect(find.text('5 transactions'), findsOneWidget);

    // Date filter: this week excludes the 20-day-old fuel entry.
    await tester.tap(find.byKey(const Key('activity-date-Week')));
    await tester.pump();
    expect(find.text('4 transactions'), findsOneWidget);
  });

  testWidgets('Activity export shares the date-filtered rows as CSV', (
    tester,
  ) async {
    String? shared;
    ShareService.debugOverride = (filename, bytes) async {
      shared = utf8.decode(bytes);
    };
    addTearDown(() => ShareService.debugOverride = null);

    await pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Activity'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // All-time export includes the 20-day-old fuel entry.
    await tester.tap(find.byKey(const Key('activity-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('export-share-csv')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(shared, isNotNull);
    expect(
      shared,
      contains('Date,Description,Category,Type,Amount,Net,Note'),
    );
    expect(shared, contains('Salary'));
    expect(shared, contains('Fuel'));

    // Narrowing to this week drops it from the export.
    shared = null;
    await tester.tap(find.byKey(const Key('activity-date-Week')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('export-share-csv')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(shared, isNotNull);
    expect(shared, contains('Weekly groceries'));
    expect(shared, isNot(contains('Fuel')));
  });

  testWidgets('Activity export can save the CSV to the device', (
    tester,
  ) async {
    String? savedName;
    List<int>? savedBytes;
    SaveService.debugOverride = (filename, bytes) async {
      savedName = filename;
      savedBytes = bytes;
      return true;
    };
    addTearDown(() => SaveService.debugOverride = null);

    await pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Activity'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('activity-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('export-save-csv')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(savedName, isNotNull);
    expect(savedName, startsWith('expenty-activity-'));
    expect(savedName, endsWith('.csv'));
    expect(
      utf8.decode(savedBytes!),
      contains('Date,Description,Category,Type,Amount,Net,Note'),
    );
    expect(find.text('Saved to device'), findsOneWidget);

    // Let the snackbar's timer finish before the test ends.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });

  testWidgets('Activity export can share a PDF', (tester) async {
    String? sharedName;
    List<int>? sharedBytes;
    ShareService.debugOverride = (filename, bytes) async {
      sharedName = filename;
      sharedBytes = bytes;
    };
    addTearDown(() => ShareService.debugOverride = null);

    await pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Activity'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('activity-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('export-share-pdf')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sharedName, isNotNull);
    expect(sharedName, endsWith('.pdf'));
    expect(String.fromCharCodes(sharedBytes!.sublist(0, 4)), '%PDF');
  });

  testWidgets('wallet top-up row offers delete but blocks editing', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Activity'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Open the action sheet for the auto-generated top-up row.
    await tester.tap(find.text('Balance added'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('activity-action-locked')), findsOneWidget);
    expect(find.byKey(const Key('activity-action-edit')), findsNothing);
    expect(find.text('Delete transaction'), findsOneWidget);

    // Close it and compare with a normal row.
    Navigator.of(
      tester.element(find.byKey(const Key('activity-action-locked'))),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Weekly groceries'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('activity-action-edit')), findsOneWidget);
    expect(find.byKey(const Key('activity-action-locked')), findsNothing);
    expect(find.text('Delete transaction'), findsOneWidget);
  });

  testWidgets('Menu tab shows profile and logout', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Menu'));
    await tester.pump();

    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
