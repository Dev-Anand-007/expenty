import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/wallet.dart';

class WalletModel extends Wallet {
  const WalletModel({
    required super.balance,
    required super.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      balance: (map['walletBalance'] as num?)?.toDouble() ?? 0,
      updatedAt: (map['walletUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap(double amount) {
    return {
      'walletBalance': FieldValue.increment(amount),
      'walletUpdatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Wallet back to zero.
  ///
  /// Writes a literal `0` rather than `FieldValue.increment(0)` — adding zero
  /// would leave the old balance exactly where it was.
  Map<String, dynamic> toResetMap() {
    return {
      'walletBalance': 0,
      'walletUpdatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}
