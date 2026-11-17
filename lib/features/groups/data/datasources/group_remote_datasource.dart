import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/group_balances.dart';
import '../models/group_expense_model.dart';
import '../models/group_model.dart';

abstract class GroupRemoteDataSource {
  Stream<List<Group>> watchMine();

  Future<String> create({
    required String name,
    required List<GroupMember> members,
  });

  Stream<Group?> watchGroup(String groupId);

  Stream<List<GroupExpense>> watchExpenses(String groupId);

  Future<void> addExpense(String groupId, GroupExpense expense);

  Future<void> deleteExpense(String groupId, GroupExpense expense);

  Future<void> updateExpense(String groupId, GroupExpense expense);

  Future<void> renameGroup(String groupId, String name);

  Future<void> addMember(String groupId, GroupMember member);

  Future<void> leaveGroup(String groupId, String uid);

  Future<GroupMember?> findMemberByEmail(String email);

  /// Looks up a registered user by @username (profiles collection).
  Future<GroupMember?> findMemberByUsername(String username);

  /// Makes sure the signed-in user exists in the public directory so that
  /// other people can invite them by email.
  Future<void> syncOwnProfile();
}

class GroupRemoteDataSourceImpl implements GroupRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  GroupRemoteDataSourceImpl({required this.firestore, required this.auth});

  CollectionReference<Map<String, dynamic>> get _groups =>
      firestore.collection('groups');

  CollectionReference<Map<String, dynamic>> get _profiles =>
      firestore.collection('profiles');

  String get _uid {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('You must be signed in to use groups.');
    }
    return uid;
  }

  @override
  Stream<List<Group>> watchMine() {
    // No orderBy: array-contains + orderBy would need a composite index.
    // Sorting happens in memory instead.
    return _groups.where('memberIds', arrayContains: _uid).snapshots().map((
      snapshot,
    ) {
      final groups = snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  @override
  Future<String> create({
    required String name,
    required List<GroupMember> members,
  }) async {
    final uid = _uid;
    final ref = _groups.doc();

    await ref.set(
      GroupModel(
        id: ref.id,
        name: name,
        createdBy: uid,
        createdAt: DateTime.now(),
        members: members,
        memberBalances: GroupBalances.zero(members),
      ).toMap(),
    );

    return ref.id;
  }

  @override
  Stream<Group?> watchGroup(String groupId) {
    return _groups
        .doc(groupId)
        .snapshots()
        .map(
          (snapshot) => snapshot.data() == null
              ? null
              : GroupModel.fromMap(snapshot.id, snapshot.data()!),
        );
  }

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) {
    return _groups
        .doc(groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupExpenseModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> addExpense(String groupId, GroupExpense expense) {
    return firestore.runTransaction((transaction) async {
      final groupRef = _groups.doc(groupId);
      final snapshot = await transaction.get(groupRef);
      final data = snapshot.data();

      if (data == null) {
        throw Exception('This group no longer exists.');
      }

      final updated = GroupBalances.applyExpense(
        _balancesOf(data),
        paidBy: expense.paidBy,
        amount: expense.amount,
        shares: expense.shares,
      );

      transaction.update(groupRef, {'memberBalances': updated});

      final expenses = groupRef.collection('expenses');
      final expenseRef = expense.id.isEmpty
          ? expenses.doc()
          : expenses.doc(expense.id);

      transaction.set(
        expenseRef,
        GroupExpenseModel(
          id: expenseRef.id,
          title: expense.title,
          amount: expense.amount,
          paidBy: expense.paidBy,
          splitType: expense.splitType,
          shares: expense.shares,
          splitLabel: expense.splitLabel,
          date: expense.date,
          createdAt: expense.createdAt,
          createdBy: expense.createdBy,
        ).toMap(),
      );
    });
  }

  @override
  Future<void> deleteExpense(String groupId, GroupExpense expense) {
    return firestore.runTransaction((transaction) async {
      final groupRef = _groups.doc(groupId);
      final snapshot = await transaction.get(groupRef);
      final data = snapshot.data();

      if (data == null) {
        throw Exception('This group no longer exists.');
      }

      final updated = GroupBalances.undoExpense(
        _balancesOf(data),
        paidBy: expense.paidBy,
        amount: expense.amount,
        shares: expense.shares,
      );

      transaction.update(groupRef, {'memberBalances': updated});
      transaction.delete(groupRef.collection('expenses').doc(expense.id));
    });
  }

  @override
  Future<void> updateExpense(String groupId, GroupExpense expense) {
    return firestore.runTransaction((transaction) async {
      final groupRef = _groups.doc(groupId);
      final expenseRef = groupRef.collection('expenses').doc(expense.id);

      final groupSnapshot = await transaction.get(groupRef);
      final groupData = groupSnapshot.data();
      if (groupData == null) {
        throw Exception('This group no longer exists.');
      }

      // The stored expense is the source of truth for what to undo — the
      // caller's copy may be stale.
      final expenseSnapshot = await transaction.get(expenseRef);
      final previousData = expenseSnapshot.data();
      if (previousData == null) {
        throw Exception('This expense no longer exists.');
      }
      final previous = GroupExpenseModel.fromMap(expense.id, previousData);

      var balances = GroupBalances.undoExpense(
        _balancesOf(groupData),
        paidBy: previous.paidBy,
        amount: previous.amount,
        shares: previous.shares,
      );
      balances = GroupBalances.applyExpense(
        balances,
        paidBy: expense.paidBy,
        amount: expense.amount,
        shares: expense.shares,
      );

      transaction.update(groupRef, {'memberBalances': balances});

      // Keep the amount from the *first* edit that changed it, so the
      // note always reads as the original → current amount.
      final originalAmount =
          previous.originalAmount ??
          (previous.amount != expense.amount ? previous.amount : null);

      transaction.set(
        expenseRef,
        GroupExpenseModel(
          id: expense.id,
          title: expense.title,
          amount: expense.amount,
          paidBy: expense.paidBy,
          splitType: expense.splitType,
          shares: expense.shares,
          splitLabel: expense.splitLabel,
          date: expense.date,
          createdAt: previous.createdAt,
          createdBy: previous.createdBy,
          editedAt: expense.editedAt ?? DateTime.now(),
          editedBy: expense.editedBy ?? _uid,
          editReason: expense.editReason ?? previous.editReason,
          originalAmount: originalAmount,
        ).toMap(),
      );
    });
  }

  @override
  Future<void> renameGroup(String groupId, String name) {
    return _groups.doc(groupId).update({'name': name});
  }

  @override
  Future<void> addMember(String groupId, GroupMember member) {
    return firestore.runTransaction((transaction) async {
      final groupRef = _groups.doc(groupId);
      final snapshot = await transaction.get(groupRef);
      final data = snapshot.data();

      if (data == null) {
        throw Exception('This group no longer exists.');
      }

      final group = GroupModel.fromMap(snapshot.id, data);
      if (group.members.any((m) => m.uid == member.uid)) {
        throw Exception('That member is already in this group.');
      }

      final members = [...group.members, member];

      transaction.update(groupRef, {
        'members': [
          for (final m in members)
            {'uid': m.uid, 'name': m.name, 'email': m.email},
        ],
        'memberIds': [for (final m in members) m.uid],
        // putIfAbsent: a returning member keeps their earlier balance.
        'memberBalances': <String, double>{
          ...group.memberBalances,
          if (!group.memberBalances.containsKey(member.uid)) member.uid: 0,
        },
      });
    });
  }

  @override
  Future<void> leaveGroup(String groupId, String uid) {
    return firestore.runTransaction((transaction) async {
      final groupRef = _groups.doc(groupId);
      final snapshot = await transaction.get(groupRef);
      final data = snapshot.data();

      if (data == null) {
        throw Exception('This group no longer exists.');
      }

      final group = GroupModel.fromMap(snapshot.id, data);
      if (group.members.length <= 1) {
        throw Exception(
          "You're the last member — ask someone else to join first.",
        );
      }
      if (!group.members.any((m) => m.uid == uid)) {
        throw Exception("You're not a member of this group.");
      }

      final members = group.members.where((m) => m.uid != uid).toList();

      transaction.update(groupRef, {
        'members': [
          for (final m in members)
            {'uid': m.uid, 'name': m.name, 'email': m.email},
        ],
        'memberIds': [for (final m in members) m.uid],
        // memberBalances is deliberately untouched: the leaver's share of
        // every past expense still exists, so dropping it would unbalance
        // the books for everyone who stays.
      });
    });
  }

  @override
  Future<GroupMember?> findMemberByEmail(String email) async {
    final normalized = email.trim().toLowerCase();

    final snapshot = await _profiles
        .where('emailLower', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return GroupMember(
      uid: (data['uid'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? normalized) as String,
    );
  }

  @override
  Future<GroupMember?> findMemberByUsername(String username) async {
    final handle = username.trim().toLowerCase().replaceFirst('@', '');
    if (handle.isEmpty) return null;

    final snapshot = await _profiles
        .where('username', isEqualTo: handle)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return GroupMember(
      uid: (data['uid'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
    );
  }

  @override
  Future<void> syncOwnProfile() async {
    final user = auth.currentUser;
    if (user == null) return;

    final email = user.email;
    if (email == null || email.isEmpty) return;

    final name = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : email.split('@').first;

    await _profiles.doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': email,
      'emailLower': email.trim().toLowerCase(),
    }, SetOptions(merge: true));
  }

  Map<String, double> _balancesOf(Map<String, dynamic> data) {
    final raw = (data['memberBalances'] as Map?) ?? const {};
    return {
      for (final entry in raw.entries)
        entry.key as String: (entry.value as num).toDouble(),
    };
  }
}
