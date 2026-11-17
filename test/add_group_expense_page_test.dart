import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/entities/group_expense.dart';
import 'package:expenty/features/groups/domain/repositories/group_repository.dart';
import 'package:expenty/features/groups/presentation/pages/add_group_expense_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeGroupRepository implements GroupRepository {
  GroupExpense? lastExpense;
  GroupExpense? lastUpdated;
  int updateCount = 0;

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
    yield Group(
      id: 'g1',
      name: 'Goa trip',
      createdBy: 'u1',
      createdAt: DateTime.now(),
      members: const [
        GroupMember(uid: 'u1', name: 'Anand', email: 'anand@x.com'),
        GroupMember(uid: 'u2', name: 'Rahul', email: 'rahul@x.com'),
        GroupMember(uid: 'u3', name: 'Zoe', email: 'zoe@x.com'),
      ],
      memberBalances: const {},
    );
  }

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) async* {}

  @override
  Future<void> addExpense(String groupId, GroupExpense expense) async {
    lastExpense = expense;
  }

  @override
  Future<void> deleteExpense(String groupId, GroupExpense expense) async {}

  @override
  Future<void> updateExpense(String groupId, GroupExpense expense) async {
    lastUpdated = expense;
    updateCount++;
  }

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
  late _FakeGroupRepository repository;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupLocator();

    repository = _FakeGroupRepository();
    await sl.unregister<GroupRepository>();
    sl.registerLazySingleton<GroupRepository>(() => repository);
  });

  tearDownAll(() async {
    await sl.reset();
  });

  Future<void> pumpPage(WidgetTester tester, {GroupExpense? existing}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AddGroupExpensePage(groupId: 'g1', existing: existing),
      ),
    );
    // Wait for the group stream to deliver the members.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> enterAmountAndTitle(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), '900');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dinner');
    await tester.pump();
  }

  testWidgets('splits equally by default and saves the expense', (
    tester,
  ) async {
    await pumpPage(tester);
    await enterAmountAndTitle(tester);

    expect(find.text('Add expense · Goa trip'), findsOneWidget);
    expect(find.text('Split equally — ₹300.00 per person'), findsOneWidget);
    expect(find.text('Each member pays'), findsOneWidget);

    await tester.tap(find.text('Save Expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Expense added.'), findsOneWidget);

    final saved = repository.lastExpense;
    expect(saved, isNotNull);
    expect(saved!.amount, 900);
    expect(saved.splitLabel, 'Equal');
    expect(saved.shares.values.fold<double>(0, (sum, v) => sum + v), 900);
    expect(saved.shares['u1'], 300);
    expect(saved.shares['u2'], 300);
    expect(saved.shares['u3'], 300);
  });

  testWidgets('validates ratio, percentage and custom splits', (tester) async {
    await pumpPage(tester);
    await enterAmountAndTitle(tester);

    /// Ratio defaults to 1:1:1 → still 300 each.
    await tester.tap(find.text('Ratio'));
    await tester.pump();
    expect(find.text('Shares add up to 3'), findsOneWidget);

    /// Percentage prefills 33/33/33 → must be corrected to 100%.
    await tester.tap(find.text('Percentage'));
    await tester.pump();
    expect(find.textContaining('Total 99%'), findsOneWidget);
    expect(find.textContaining('must be 100%'), findsOneWidget);

    /// Custom amounts must add up to the expense total.
    await tester.tap(find.text('Custom amount'));
    await tester.pump();
    expect(find.textContaining('Total ₹0.00 of ₹900.00'), findsOneWidget);
    expect(find.textContaining('must match'), findsOneWidget);
    expect(find.text('Each member pays'), findsNothing);
  });

  testWidgets('edit mode requires a reason and records the audit trail', (
    tester,
  ) async {
    final existing = GroupExpense(
      id: 'e1',
      title: 'Dinner',
      amount: 600,
      paidBy: 'u1',
      splitType: SplitType.equal,
      shares: const {'u1': 200, 'u2': 200, 'u3': 200},
      splitLabel: 'Equal',
      date: DateTime(2026, 11, 7),
      createdAt: DateTime(2026, 11, 7),
      createdBy: 'u1',
    );

    await pumpPage(tester, existing: existing);

    expect(find.text('Edit expense · Goa trip'), findsOneWidget);

    // Prefilled from the stored expense.
    expect(find.widgetWithText(TextFormField, '600'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Dinner'), findsOneWidget);

    // Amount hint before and after changing the amount.
    expect(find.text('Amount unchanged at ₹600.00.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '900');
    await tester.pump();
    expect(find.text('Amount ₹600.00 → ₹900.00'), findsOneWidget);

    // Saving without a reason is rejected.
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add a short reason for the change'), findsOneWidget);
    expect(repository.updateCount, 0);

    // With a reason it saves and carries the audit trail.
    await tester.enterText(find.byType(TextFormField).at(2), 'Wrong total');
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Expense updated.'), findsOneWidget);
    expect(repository.updateCount, 1);

    final saved = repository.lastUpdated;
    expect(saved, isNotNull);
    expect(saved!.id, 'e1');
    expect(saved.amount, 900);
    expect(saved.originalAmount, 600);
    expect(saved.editReason, 'Wrong total');
    expect(saved.editedAt, isNotNull);
    expect(saved.amountChanged, isTrue);
    expect(saved.createdAt, existing.createdAt);
  });
}
