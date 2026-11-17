import 'package:equatable/equatable.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class WalletWatched extends WalletEvent {
  const WalletWatched();
}

class BalanceAdded extends WalletEvent {
  final double amount;

  const BalanceAdded(this.amount);

  @override
  List<Object?> get props => [amount];
}
