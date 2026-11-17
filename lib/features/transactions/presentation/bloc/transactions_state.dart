import 'package:equatable/equatable.dart';

import '../../domain/entities/money_transaction.dart';

enum TransactionsStatus {
  initial,
  loading,
  loaded,
  success,
  failure,
}

class TransactionsState extends Equatable {
  final TransactionsStatus status;
  final List<MoneyTransaction> transactions;
  final String? message;

  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
    this.message,
  });

  TransactionsState copyWith({
    TransactionsStatus? status,
    List<MoneyTransaction>? transactions,
    String? message,
  }) {
    return TransactionsState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, transactions, message];
}
