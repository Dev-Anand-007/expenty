import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/money_transaction.dart';
import '../models/money_transaction_model.dart';

abstract class TransactionRemoteDataSource {
  Stream<List<MoneyTransaction>> watchAll();

  Future<void> add(MoneyTransaction transaction);

  Future<void> update(MoneyTransaction transaction);

  Future<void> delete(String id);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  TransactionRemoteDataSourceImpl({
    required this.firestore,
    required this.auth,
  });

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('You must be signed in to manage transactions.');
    }
    return firestore.collection('users').doc(uid).collection('transactions');
  }

  @override
  Stream<List<MoneyTransaction>> watchAll() {
    return _collection
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MoneyTransactionModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> add(MoneyTransaction transaction) async {
    final payload = MoneyTransactionModel(
      id: transaction.id,
      title: transaction.title,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      date: transaction.date,
      note: transaction.note,
      createdAt: transaction.createdAt,
    );

    if (transaction.id.isEmpty) {
      await _collection.doc().set(payload.toMap());
    } else {
      await _collection.doc(transaction.id).set(payload.toMap());
    }
  }

  @override
  Future<void> update(MoneyTransaction transaction) async {
    if (transaction.id.isEmpty) {
      throw Exception('Cannot update a transaction without an id.');
    }

    final payload = MoneyTransactionModel(
      id: transaction.id,
      title: transaction.title,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      date: transaction.date,
      note: transaction.note,
      createdAt: transaction.createdAt,
    );

    await _collection.doc(transaction.id).set(payload.toMap());
  }

  @override
  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
