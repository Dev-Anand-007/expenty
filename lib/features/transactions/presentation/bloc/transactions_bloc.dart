import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/money_transaction.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../domain/usecases/watch_transactions_usecase.dart';
import 'transactions_event.dart';
import 'transactions_state.dart';

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  final WatchTransactionsUseCase watchTransactions;
  final AddTransactionUseCase addTransaction;
  final UpdateTransactionUseCase updateTransaction;
  final DeleteTransactionUseCase deleteTransaction;

  StreamSubscription<List<MoneyTransaction>>? _subscription;

  TransactionsBloc({
    required this.watchTransactions,
    required this.addTransaction,
    required this.updateTransaction,
    required this.deleteTransaction,
  }) : super(const TransactionsState()) {
    on<TransactionsWatched>(_onWatched);
    on<TransactionAdded>(_onAdded);
    on<TransactionUpdated>(_onUpdated);
    on<TransactionDeleted>(_onDeleted);
    on<_TransactionsUpdated>(_onStreamUpdated);
    on<_TransactionsFailed>(_onFailed);
  }

  Future<void> _onWatched(
    TransactionsWatched event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(state.copyWith(status: TransactionsStatus.loading, message: null));

    await _subscription?.cancel();
    _subscription = watchTransactions().listen(
      (transactions) => add(_TransactionsUpdated(transactions)),
      onError: (Object error) => add(_TransactionsFailed(error.toString())),
    );
  }

  void _onStreamUpdated(
    _TransactionsUpdated event,
    Emitter<TransactionsState> emit,
  ) {
    emit(
      state.copyWith(
        status: TransactionsStatus.loaded,
        transactions: event.transactions,
        message: null,
      ),
    );
  }

  void _onFailed(
    _TransactionsFailed event,
    Emitter<TransactionsState> emit,
  ) {
    emit(
      state.copyWith(
        status: TransactionsStatus.failure,
        message: event.message,
      ),
    );
  }

  Future<void> _onAdded(
    TransactionAdded event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(state.copyWith(status: TransactionsStatus.loading, message: null));

    try {
      await addTransaction(event.transaction);
      emit(
        state.copyWith(
          status: TransactionsStatus.success,
          message: 'Transaction added.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TransactionsStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdated(
    TransactionUpdated event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(state.copyWith(status: TransactionsStatus.loading, message: null));

    try {
      await updateTransaction(event.transaction);
      emit(
        state.copyWith(
          status: TransactionsStatus.success,
          message: 'Transaction updated.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TransactionsStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleted(
    TransactionDeleted event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(state.copyWith(status: TransactionsStatus.loading, message: null));

    try {
      await deleteTransaction(event.id);
      emit(
        state.copyWith(
          status: TransactionsStatus.success,
          message: 'Transaction deleted.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TransactionsStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

class _TransactionsUpdated extends TransactionsEvent {
  final List<MoneyTransaction> transactions;

  const _TransactionsUpdated(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class _TransactionsFailed extends TransactionsEvent {
  final String message;

  const _TransactionsFailed(this.message);

  @override
  List<Object?> get props => [message];
}
