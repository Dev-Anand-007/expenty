import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/money_transaction.dart';

class MoneyTransactionModel extends MoneyTransaction {
  const MoneyTransactionModel({
    required super.id,
    required super.title,
    required super.amount,
    required super.type,
    required super.category,
    required super.date,
    super.note,
    required super.createdAt,
  });

  factory MoneyTransactionModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return MoneyTransactionModel(
      id: id,
      title: (map['title'] ?? '') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: map['type'] == TransactionType.income.name
          ? TransactionType.income
          : TransactionType.expense,
      category: (map['category'] ?? 'Other') as String,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: (map['note'] ?? '') as String,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
