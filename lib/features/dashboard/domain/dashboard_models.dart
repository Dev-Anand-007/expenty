import 'package:flutter/material.dart';

/// Totals shown on the dashboard's balance and income/expense cards.
///
/// Produced by [DashboardInsights.summary] from live Firestore data.
class FinancialSummary {
  final double totalBalance;
  final double income;
  final double expenses;

  const FinancialSummary({
    required this.totalBalance,
    required this.income,
    required this.expenses,
  });
}

/// A ranked expense category for the "Top 5 expenses" carousel.
class TopExpense {
  final int rank;
  final String category;
  final double amount;
  final Color color;

  const TopExpense({
    required this.rank,
    required this.category,
    required this.amount,
    required this.color,
  });
}
