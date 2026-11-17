import 'package:equatable/equatable.dart';

import '../../domain/entities/wallet.dart';

enum WalletStatus {
  initial,
  loading,
  loaded,
  success,
  failure,
}

class WalletState extends Equatable {
  final WalletStatus status;
  final Wallet wallet;
  final String? message;

  const WalletState({
    this.status = WalletStatus.initial,
    this.wallet = const Wallet(balance: 0, updatedAt: null),
    this.message,
  });

  WalletState copyWith({
    WalletStatus? status,
    Wallet? wallet,
    String? message,
  }) {
    return WalletState(
      status: status ?? this.status,
      wallet: wallet ?? this.wallet,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, wallet, message];
}
