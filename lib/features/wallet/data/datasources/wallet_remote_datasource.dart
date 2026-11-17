import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/wallet.dart';
import '../models/wallet_model.dart';

abstract class WalletRemoteDataSource {
  Stream<Wallet> watch();

  Future<void> addBalance(double amount);

  /// Sets `users/{uid}.walletBalance` back to 0 without deleting anything.
  Future<void> resetBalance();
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  WalletRemoteDataSourceImpl({
    required this.firestore,
    required this.auth,
  });

  DocumentReference<Map<String, dynamic>> get _doc {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('You must be signed in to use your wallet.');
    }
    return firestore.collection('users').doc(uid);
  }

  @override
  Stream<Wallet> watch() {
    return _doc.snapshots().map(
          (snapshot) =>
              WalletModel.fromMap(snapshot.data() ?? const {}),
        );
  }

  @override
  Future<void> addBalance(double amount) async {
    // merge:true creates the document if the user record doesn't exist yet.
    await _doc.set(
      WalletModel(balance: 0, updatedAt: DateTime.now()).toMap(amount),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> resetBalance() async {
    // merge:true so a user who only ever had a wallet top-up (and therefore
    // no `users` doc of their own yet) still ends up with a clean zero.
    await _doc.set(
      WalletModel(balance: 0, updatedAt: DateTime.now()).toResetMap(),
      SetOptions(merge: true),
    );
  }
}
