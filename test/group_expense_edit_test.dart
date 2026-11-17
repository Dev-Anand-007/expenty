import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/entities/group_expense.dart';
import 'package:expenty/features/groups/domain/repositories/group_repository.dart';
import 'package:expenty/features/groups/presentation/pages/group_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// A group whose only expense has already been edited once, so the audit
/// note is on screen.
class _FakeGroupRepository implements GroupRepository {
  final editedExpense = GroupExpense(
    id: 'e1',
    title: 'Dinner',
    amount: 900,
    paidBy: 'u1',
    splitType: SplitType.equal,
    shares: const {'u1': 450, 'u2': 450},
    splitLabel: 'Equal',
    date: DateTime(2026, 11, 7),
    createdAt: DateTime(2026, 11, 7),
    createdBy: 'u1',
    editedAt: DateTime(2026, 11, 9, 14, 30),
    editedBy: 'u1',
    editReason: 'Wrong total',
    originalAmount: 600,
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
    yield Group(
      id: 'g1',
      name: 'Goa trip',
      createdBy: 'u1',
      createdAt: DateTime.now(),
      members: const [
        GroupMember(uid: 'u1', name: 'Anand', email: 'anand@x.com'),
        GroupMember(uid: 'u2', name: 'Rahul', email: 'rahul@x.com'),
      ],
      memberBalances: const {},
    );
  }

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) async* {
    await Future<void>.delayed(Duration.zero);
    yield [editedExpense];
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

  testWidgets('edited expense carries a note with why, when and old → new', (
    tester,
  ) async {
    await pumpPage(tester);

    final note = find.byKey(const Key('expense-audit-note'));
    expect(note, findsOneWidget);
    expect(
      find.descendant(of: note, matching: find.textContaining('Edited on')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: note, matching: find.textContaining('Wrong total')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: note, matching: find.text('₹600.00 → ₹900.00')),
      findsOneWidget,
    );
  });

  testWidgets('expense menu offers Edit as well as Delete', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('expense-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
