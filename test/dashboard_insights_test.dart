import 'package:expenty/features/dashboard/domain/dashboard_insights.dart';
import 'package:expenty/features/transactions/domain/entities/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

MoneyTransaction _tx({
  required double amount,
  required TransactionType type,
  required String category,
  required DateTime date,
}) {
  return MoneyTransaction(
    id: '$category-$amount-$date',
    title: category,
    amount: amount,
    type: type,
    category: category,
    date: date,
    createdAt: date,
  );
}

void main() {
  final monday = DateTime(2026, 11, 2); // a Monday
  final withinWeek = monday.add(const Duration(days: 2));
  final lastMonth = DateTime(2026, 10, 5);

  final transactions = [
    _tx(
      amount: 50000,
      type: TransactionType.income,
      category: 'Salary',
      date: withinWeek,
    ),
    _tx(
      amount: 3000,
      type: TransactionType.expense,
      category: 'Groceries',
      date: withinWeek,
    ),
    _tx(
      amount: 1000,
      type: TransactionType.expense,
      category: 'Groceries',
      date: withinWeek,
    ),
    _tx(
      amount: 500,
      type: TransactionType.expense,
      category: 'Dining',
      date: withinWeek,
    ),
    // Outside the week and outside the month → excluded from both views.
    _tx(
      amount: 20000,
      type: TransactionType.expense,
      category: 'Car',
      date: lastMonth,
    ),
  ];

  group('DashboardInsights.summary', () {
    test('sums income, expenses and nets the balance', () {
      final summary = DashboardInsights.summary(transactions);

      expect(summary.income, 50000);
      expect(summary.expenses, 24500);
      expect(summary.totalBalance, 25500);
    });

    test('returns zeros for no transactions', () {
      final summary = DashboardInsights.summary(const []);

      expect(summary.income, 0);
      expect(summary.expenses, 0);
      expect(summary.totalBalance, 0);
    });

    test('adds the wallet balance on top of income minus expenses', () {
      final summary = DashboardInsights.summary(
        transactions,
        walletBalance: 10000,
      );

      // 10000 (wallet) + 50000 (income) − 24500 (expenses)
      expect(summary.totalBalance, 35500);
      expect(summary.income, 50000);
      expect(summary.expenses, 24500);
    });

    test('does not double-count a mirrored wallet top-up', () {
      final topUp = _tx(
        amount: 2000,
        type: TransactionType.income,
        category: 'Wallet top-up',
        date: withinWeek,
      );

      final summary = DashboardInsights.summary([
        ...transactions,
        topUp,
      ], walletBalance: 10000);

      // The top-up is income you can see, but the wallet field already
      // holds it — so the balance must not count it twice.
      expect(summary.income, 52000);
      // 10000 (wallet, includes the 2000) + 52000 − 24500 − 2000 (top-up)
      expect(summary.totalBalance, 35500);
    });
  });

  group('DashboardInsights.topExpenses', () {
    test('groups by category for the current week and ranks them', () {
      final top = DashboardInsights.topExpenses(transactions, now: monday);

      expect(top, hasLength(2));
      expect(top.first.category, 'Groceries');
      expect(top.first.rank, 1);
      expect(top.first.amount, 4000);
      expect(top.last.category, 'Dining');
      expect(top.last.rank, 2);
    });

    test('ignores income and older transactions', () {
      final top = DashboardInsights.topExpenses(transactions, now: monday);

      expect(top.map((item) => item.category), isNot(contains('Salary')));
      expect(top.map((item) => item.category), isNot(contains('Car')));
    });

    test('respects the limit', () {
      final top = DashboardInsights.topExpenses(
        transactions,
        limit: 1,
        now: monday,
      );

      expect(top, hasLength(1));
    });
  });
}
