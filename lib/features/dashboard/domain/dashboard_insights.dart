import '../../../core/constants/transaction_categories.dart';
import '../../transactions/domain/entities/money_transaction.dart';
import 'dashboard_models.dart';

/// Pure functions that turn raw transactions into dashboard data.
class DashboardInsights {
  DashboardInsights._();

  /// All-time income / expenses, and the resulting balance.
  ///
  /// [walletBalance] is money the user explicitly added to their wallet;
  /// expenses draw it down and income tops it up.
  ///
  /// Wallet top-ups are also mirrored into the transaction list as income
  /// (so they show in Activity), but the wallet field already holds that
  /// money — so they are discounted from [FinancialSummary.totalBalance]
  /// to keep the amount from being counted twice. They still count as
  /// income in [FinancialSummary.income].
  static FinancialSummary summary(
    List<MoneyTransaction> transactions, {
    double walletBalance = 0,
  }) {
    var income = 0.0;
    var expenses = 0.0;
    var walletTopUps = 0.0;

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        income += transaction.amount;
        if (transaction.category == TransactionCategories.walletTopUp.name) {
          walletTopUps += transaction.amount;
        }
      } else {
        expenses += transaction.amount;
      }
    }

    return FinancialSummary(
      totalBalance: walletBalance + income - expenses - walletTopUps,
      income: income,
      expenses: expenses,
    );
  }

  /// Biggest expense categories of the current week (Monday → Sunday).
  static List<TopExpense> topExpenses(
    List<MoneyTransaction> transactions, {
    int limit = 5,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final weekStart = _startOfWeek(today);
    final totals = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.isIncome) continue;

      final day = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      if (day.isBefore(weekStart)) continue;

      totals[transaction.category] =
          (totals[transaction.category] ?? 0) + transaction.amount;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (var i = 0; i < sorted.length && i < limit; i++)
        TopExpense(
          rank: i + 1,
          category: sorted[i].key,
          amount: sorted[i].value,
          color: TransactionCategories.byName(sorted[i].key).color,
        ),
    ];
  }

  static DateTime _startOfWeek(DateTime day) {
    final daysSinceMonday = (day.weekday + 6) % 7;
    return DateTime(day.year, day.month, day.day)
        .subtract(Duration(days: daysSinceMonday));
  }
}
