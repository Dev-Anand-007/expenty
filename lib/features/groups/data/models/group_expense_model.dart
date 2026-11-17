import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/group_expense.dart';

class GroupExpenseModel extends GroupExpense {
  const GroupExpenseModel({
    required super.id,
    required super.title,
    required super.amount,
    required super.paidBy,
    required super.splitType,
    required super.shares,
    required super.splitLabel,
    required super.date,
    required super.createdAt,
    required super.createdBy,
    super.editedAt,
    super.editedBy,
    super.editReason,
    super.originalAmount,
  });

  factory GroupExpenseModel.fromMap(String id, Map<String, dynamic> map) {
    final rawShares = (map['shares'] as Map?) ?? const {};

    return GroupExpenseModel(
      id: id,
      title: (map['title'] ?? '') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paidBy: (map['paidBy'] ?? '') as String,
      splitType: SplitType.values.firstWhere(
        (type) => type.name == map['splitType'],
        orElse: () => SplitType.equal,
      ),
      shares: {
        for (final entry in rawShares.entries)
          entry.key as String: (entry.value as num).toDouble(),
      },
      splitLabel: (map['splitLabel'] ?? 'Equal') as String,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: (map['createdBy'] ?? '') as String,
      editedAt: (map['editedAt'] as Timestamp?)?.toDate(),
      editedBy: map['editedBy'] as String?,
      editReason: map['editReason'] as String?,
      originalAmount: (map['originalAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'splitType': splitType.name,
      'shares': shares,
      'splitLabel': splitLabel,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      if (editedBy != null) 'editedBy': editedBy,
      if (editReason != null) 'editReason': editReason,
      if (originalAmount != null) 'originalAmount': originalAmount,
    };
  }
}
