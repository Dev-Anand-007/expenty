import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/transaction_categories.dart';
import '../../../transactions/domain/entities/money_transaction.dart';
import '../../../transactions/domain/usecases/add_transaction_usecase.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/usecases/add_balance_usecase.dart';
import '../../domain/usecases/watch_wallet_usecase.dart';
import 'wallet_event.dart';
import 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WatchWalletUseCase watchWallet;
  final AddBalanceUseCase addBalance;
  final AddTransactionUseCase addTransaction;

  StreamSubscription<Wallet>? _subscription;

  WalletBloc({
    required this.watchWallet,
    required this.addBalance,
    required this.addTransaction,
  }) : super(const WalletState()) {
    on<WalletWatched>(_onWatched);
    on<BalanceAdded>(_onBalanceAdded);
    on<_WalletUpdated>(_onUpdated);
    on<_WalletFailed>(_onFailed);
  }

  Future<void> _onWatched(
    WalletWatched event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(status: WalletStatus.loading, message: null));

    await _subscription?.cancel();
    _subscription = watchWallet().listen(
      (wallet) => add(_WalletUpdated(wallet)),
      onError: (Object error) => add(_WalletFailed(error.toString())),
    );
  }

  void _onUpdated(
    _WalletUpdated event,
    Emitter<WalletState> emit,
  ) {
    emit(
      state.copyWith(
        status: WalletStatus.loaded,
        wallet: event.wallet,
        message: null,
      ),
    );
  }

  void _onFailed(
    _WalletFailed event,
    Emitter<WalletState> emit,
  ) {
    emit(
      state.copyWith(status: WalletStatus.failure, message: event.message),
    );
  }

  Future<void> _onBalanceAdded(
    BalanceAdded event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(status: WalletStatus.loading, message: null));

    try {
      await addBalance(event.amount);

      // Mirror the top-up as an income row so it shows up in Activity.
      // It is tagged with [TransactionCategories.walletTopUp] so the
      // balance maths can discount it (the wallet field already holds it).
      await addTransaction(
        MoneyTransaction(
          id: '',
          title: 'Balance added',
          amount: event.amount,
          type: TransactionType.income,
          category: TransactionCategories.walletTopUp.name,
          date: DateTime.now(),
          note: 'Added to wallet',
          createdAt: DateTime.now(),
        ),
      );

      emit(
        state.copyWith(
          status: WalletStatus.success,
          message: 'Balance added.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: WalletStatus.failure,
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

class _WalletUpdated extends WalletEvent {
  final Wallet wallet;

  const _WalletUpdated(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class _WalletFailed extends WalletEvent {
  final String message;

  const _WalletFailed(this.message);

  @override
  List<Object?> get props => [message];
}
