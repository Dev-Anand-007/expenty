import 'package:expenty/app/di/service_locator.dart';
import 'package:expenty/features/transactions/domain/entities/money_transaction.dart';
import 'package:expenty/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:expenty/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeTransactionRepository implements TransactionRepository {
  final List<MoneyTransaction> added = [];
  final List<MoneyTransaction> updated = [];

  @override
  Stream<List<MoneyTransaction>> watchAll() async* {
    yield added;
  }

  @override
  Future<void> add(MoneyTransaction transaction) async {
    added.add(transaction);
  }

  @override
  Future<void> update(MoneyTransaction transaction) async {
    updated.add(transaction);
  }

  @override
  Future<void> delete(String id) async {}
}

void main() {
  late _FakeTransactionRepository repository;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupLocator();

    repository = _FakeTransactionRepository();
    await sl.unregister<TransactionRepository>();
    sl.registerLazySingleton<TransactionRepository>(() => repository);
  });

  tearDownAll(() async {
    await sl.reset();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    // Tall viewport so the whole form (incl. Save) is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AddTransactionPage()));
    await tester.pump();
  }

  testWidgets('renders amount, title, category and save controls', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Save Transaction'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
  });

  testWidgets('switches between expense and income', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Income'));
    await tester.pump();

    // Both remain visible; the toggle just changes which is selected.
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
  });

  testWidgets('validates amount and title before saving', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Save Transaction'));
    await tester.pump();

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.text('Enter a title'), findsOneWidget);

    // Nothing was written to the repository.
    expect(repository.added, isEmpty);
  });

  testWidgets('saves a valid transaction and returns to the dashboard', (
    tester,
  ) async {
    // Regression test: _save() must read the bloc from a context *below*
    // the page's BlocProvider, otherwise it throws ProviderNotFoundException.
    final router = GoRouter(
      initialLocation: '/add-transaction',
      routes: [
        GoRoute(
          path: '/add-transaction',
          builder: (_, __) => const AddTransactionPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('dashboard-home'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    // Fields: 0 = amount, 1 = title, 2 = note.
    await tester.enterText(find.byType(TextFormField).at(0), '250');
    await tester.enterText(find.byType(TextFormField).at(1), 'Morning coffee');
    await tester.pump();

    await tester.tap(find.text('Save Transaction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repository.added, hasLength(1));
    expect(repository.added.single.title, 'Morning coffee');
    expect(repository.added.single.amount, 250);
    expect(find.text('dashboard-home'), findsOneWidget);
  });

  testWidgets('edit mode prefills the form and saves an update', (
    tester,
  ) async {
    final existing = MoneyTransaction(
      id: 'tx-1',
      title: 'Weekly groceries',
      amount: 1200,
      type: TransactionType.expense,
      category: 'Groceries',
      date: DateTime(2026, 3, 5),
      note: 'Market run',
      createdAt: DateTime(2026, 3, 5),
    );

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('dashboard-home'))),
        ),
        GoRoute(
          path: '/edit-transaction',
          builder: (_, state) =>
              AddTransactionPage(existing: state.extra as MoneyTransaction),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    router.push('/edit-transaction', extra: existing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Prefilled from the existing transaction.
    expect(find.text('Edit Transaction'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller
          ?.text,
      '1200',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller
          ?.text,
      'Weekly groceries',
    );

    // Change the amount and save.
    await tester.enterText(find.byType(TextFormField).at(0), '1500');
    await tester.pump();

    // Changed amount is written as an update (id preserved), not a new row.
    final addedBefore = repository.added.length;
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repository.updated, hasLength(1));
    expect(repository.added, hasLength(addedBefore));
    expect(repository.updated.single.id, 'tx-1');
    expect(repository.updated.single.amount, 1500);
    expect(find.text('dashboard-home'), findsOneWidget);
  });

  testWidgets('locks a wallet top-up: read-only form, no update written', (
    tester,
  ) async {
    final topUp = MoneyTransaction(
      id: 'tx-topup',
      title: 'Balance added',
      amount: 5000,
      type: TransactionType.income,
      category: 'Wallet top-up',
      date: DateTime(2026, 3, 5),
      note: 'Added to wallet',
      createdAt: DateTime(2026, 3, 5),
    );

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('dashboard-home'))),
        ),
        GoRoute(
          path: '/edit-transaction',
          builder: (_, state) =>
              AddTransactionPage(existing: state.extra as MoneyTransaction),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    router.push('/edit-transaction', extra: topUp);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Prefilled for reading, but flagged as read-only.
    expect(find.byKey(const Key('edit-locked-banner')), findsOneWidget);
    expect(find.text('Editing disabled'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(0)).enabled,
      isFalse,
    );

    // Tapping the disabled button writes nothing. (The fakes are shared
    // per file, so compare against the counts before this test.)
    final addedBefore = repository.added.length;
    final updatedBefore = repository.updated.length;

    await tester.tap(find.text('Editing disabled'));
    await tester.pump();

    expect(repository.updated, hasLength(updatedBefore));
    expect(repository.added, hasLength(addedBefore));
  });
}
