enum TransactionType { income, expense }

/// A single income or expense record.
class MoneyTransaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  const MoneyTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
    required this.createdAt,
  });

  bool get isIncome => type == TransactionType.income;
}
