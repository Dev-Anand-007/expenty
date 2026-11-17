import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/core/services/share_service.dart';
import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/entities/group_expense.dart';
import 'package:expenty/features/groups/domain/repositories/group_repository.dart';
import 'package:expenty/features/groups/presentation/pages/group_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:convert';

/// Both streams actually deliver data — this is the scenario that used to
/// wipe the loaded group from the state.
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

  final expense = GroupExpense(
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
  );

  /// Dated "now" so the date-filter test is independent of the calendar.
  final autoExpense = GroupExpense(
    id: 'e2',
    title: 'Auto',
    amount: 400,
    paidBy: 'u2',
    splitType: SplitType.equal,
    shares: const {'u1': 200, 'u2': 200},
    splitLabel: 'Equal',
    date: DateTime.now(),
    createdAt: DateTime.now(),
    createdBy: 'u2',
  );

  @override
  Stream<List<Group>> watchMine() async* {
    yield const [];
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
    // Deliberately after the group doc so state updates arrive in the
    // order they do in the app.
    await Future<void>.delayed(Duration.zero);
    yield [expense, autoExpense];
  }

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

    await sl.unregister<GroupRepository>();
    sl.registerLazySingleton<GroupRepository>(() => _FakeGroupRepository());
  });

  tearDownAll(() async {
    await sl.reset();
  });

  testWidgets('keeps showing the group after the expenses stream emits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: GroupDetailPage(groupId: 'g1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Regression: the group must survive the expenses emission.
    expect(find.text('Could not open this group'), findsNothing);
    expect(find.text('Goa trip'), findsOneWidget);

    // Settlements: net per member, nothing else.
    expect(find.text('Settlements'), findsOneWidget);
    expect(find.text('Rahul owes ₹500.00'), findsOneWidget);
    expect(find.text('Anand is owed ₹500.00'), findsOneWidget);

    // Expense list.
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.textContaining('Paid by Anand'), findsOneWidget);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: GroupDetailPage(groupId: 'g1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('header menu offers rename, add member and leave', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('group-options-menu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-options-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Edit group name'), findsOneWidget);
    expect(find.text('Add member'), findsOneWidget);
    expect(find.text('Leave group'), findsOneWidget);

    // Rename opens a dialog pre-filled with the current name.
    await tester.tap(find.text('Edit group name'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Group name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('header menu exports the expenses as CSV', (tester) async {
    String? shared;
    ShareService.debugOverride = (filename, bytes) async {
      shared = utf8.decode(bytes);
    };
    addTearDown(() => ShareService.debugOverride = null);

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('group-options-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Export expenses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('export-share-csv')));
    await tester.pump();

    expect(shared, isNotNull);
    // Fixed fields + one numeric share column per member.
    expect(
      shared,
      contains('Date,Description,Paid by,Amount,Split,Anand,Rahul'),
    );
    expect(shared, contains('2026-11-07,Dinner,Anand,600.00,Equal,300.00,300.00'));
    expect(shared, contains('Auto,Rahul,400.00,Equal,200.00,200.00'));
  });

  testWidgets('date filter narrows the expense list', (tester) async {
    await pumpPage(tester);

    // Everything is visible by default.
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.byKey(const Key('group-expense-count')), findsOneWidget);

    for (final filter in ['today', 'week', 'month']) {
      await tester.tap(find.byKey(Key('group-date-$filter')));
      await tester.pump();

      // The "now" expense is always inside today / this week / this month.
      expect(find.text('Auto'), findsOneWidget);
      expect(find.byKey(const Key('group-expense-empty-filter')), findsNothing);
    }

    await tester.tap(find.byKey(const Key('group-date-all')));
    await tester.pump();

    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
  });
}
