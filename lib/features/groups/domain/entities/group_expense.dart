/// How a group expense is divided between members.
enum SplitType {
  equal,
  ratio,
  percentage,
  custom;

  String get label => switch (this) {
    equal => 'Equal',
    ratio => 'Ratio',
    percentage => 'Percentage',
    custom => 'Custom amount',
  };
}

class GroupExpense {
  final String id;
  final String title;
  final double amount;

  /// uid of the member who paid.
  final String paidBy;
  final SplitType splitType;

  /// uid → share of the bill charged to that member (sums to [amount]).
  final Map<String, double> shares;

  /// Human readable split, e.g. "2:1:1" or "40:30:30".
  final String splitLabel;

  final DateTime date;
  final DateTime createdAt;
  final String createdBy;

  /// Audit trail — set the first time someone edits this expense.
  final DateTime? editedAt;
  final String? editedBy;

  /// Why the change was made, shown on the row as a small note.
  final String? editReason;

  /// Amount before the first edit that changed it, kept so the note can
  /// read "₹600.00 → ₹900.00". Null while the amount never changed.
  final double? originalAmount;

  const GroupExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.splitType,
    required this.shares,
    required this.splitLabel,
    required this.date,
    required this.createdAt,
    required this.createdBy,
    this.editedAt,
    this.editedBy,
    this.editReason,
    this.originalAmount,
  });

  /// Whether the note should show an old → new amount.
  bool get amountChanged => originalAmount != null && originalAmount! != amount;
}
