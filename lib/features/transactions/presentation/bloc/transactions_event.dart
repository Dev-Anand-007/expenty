import 'package:equatable/equatable.dart';

import '../../domain/entities/money_transaction.dart';

abstract class TransactionsEvent extends Equatable {
  const TransactionsEvent();

  @override
  List<Object?> get props => [];
}

class TransactionsWatched extends TransactionsEvent {
  const TransactionsWatched();
}

class TransactionAdded extends TransactionsEvent {
  final MoneyTransaction transaction;

  const TransactionAdded(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class TransactionDeleted extends TransactionsEvent {
  final String id;

  const TransactionDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

class TransactionUpdated extends TransactionsEvent {
  final MoneyTransaction transaction;

  const TransactionUpdated(this.transaction);

  @override
  List<Object?> get props => [transaction];
}
