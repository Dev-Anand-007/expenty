import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/currency_formatter.dart';
import 'notification_service.dart';

/// Local notifications for changes that happen while the app is open but
/// did not originate on this screen:
///
/// * **Transactions** — written by another device of the same account
///   (Firestore rules keep them owner-only). Writes made *here* are
///   registered via [markLocalWrite] so their stream echo is silent.
/// * **Group expenses** — added by another member while you have the app
///   open. Your own additions (on any device) are skipped by `createdBy`.
///
/// Each stream primes on its first snapshot so opening the app never
/// floods you with alerts for old data. Started when the user signs in,
/// stopped on sign-out. Push while the app is *closed* needs a backend
/// (Cloud Functions) — this is the foreground half.
class ActivityAlertWatcher {
  ActivityAlertWatcher._();

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _txSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsSub;
  static final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _expenseSubs = {};
  static final Map<String, _GroupInfo> _groups = {};

  static bool _running = false;
  static bool _txPrimed = false;
  static final Set<String> _knownTxnIds = {};
  static final Set<String> _primedExpenseGroups = {};

  /// ids this device just wrote — their stream echo must stay silent.
  static final Map<String, DateTime> _localWrites = {};

  /// Register a transaction this device is about to write so the watcher
  /// ignores it when it comes back off the stream.
  static void markLocalWrite(String id) {
    _localWrites[id] = DateTime.now();
    _pruneLocalWrites();
  }

  static bool _consumeLocalWrite(String id) => _localWrites.remove(id) != null;

  static void _pruneLocalWrites() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _localWrites.removeWhere((_, writtenAt) => writtenAt.isBefore(cutoff));
  }

  static Future<void> start(String uid) async {
    if (_running) await stop();
    _running = true;

    final firestore = FirebaseFirestore.instance;

    _txSub = firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .snapshots()
        .listen((snapshot) {
          _pruneLocalWrites();

          if (!_txPrimed) {
            _txPrimed = true;
            _knownTxnIds.addAll(snapshot.docs.map((doc) => doc.id));
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;

            final id = change.doc.id;
            if (_knownTxnIds.contains(id)) continue;
            _knownTxnIds.add(id);
            if (_consumeLocalWrite(id)) continue;

            final data = change.doc.data();
            if (data == null) continue;

            final title = (data['title'] as String?) ?? 'Transaction';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            final isIncome = data['type'] == 'income';

            NotificationService.show(
              type: NotificationType.transaction,
              title: 'Transaction recorded',
              body:
                  '$title • ${isIncome ? '+' : '-'}'
                  '${CurrencyFormatter.format(amount)}',
            );
          }
        });

    _groupsSub = firestore
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
          final currentIds = <String>{};

          for (final doc in snapshot.docs) {
            currentIds.add(doc.id);
            final data = doc.data();
            _groups[doc.id] = _GroupInfo(
              name: (data['name'] as String?) ?? 'Group',
              memberNames: {
                for (final raw in (data['members'] as List?) ?? const [])
                  if (raw is Map)
                    (raw['uid'] as String?) ?? '': (raw['name'] as String?) ?? '',
              },
            );
            _ensureExpenseListener(uid, doc.id);
          }

          // Left a group → drop its listener.
          final stale = _expenseSubs.keys.toSet().difference(currentIds);
          for (final groupId in stale) {
            unawaited(_expenseSubs.remove(groupId)?.cancel());
            _groups.remove(groupId);
            _primedExpenseGroups.remove(groupId);
          }
        });
  }

  static void _ensureExpenseListener(String uid, String groupId) {
    if (_expenseSubs.containsKey(groupId)) return;

    _expenseSubs[groupId] = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .snapshots()
        .listen((snapshot) {
          if (!_primedExpenseGroups.contains(groupId)) {
            _primedExpenseGroups.add(groupId);
            return;
          }

          final info = _groups[groupId];
          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;

            final data = change.doc.data();
            if (data == null) continue;

            final createdBy = data['createdBy'] as String?;
            // Your own additions never alert (Firestore has no way to tell
            // which device wrote them, and `createdBy` is you either way).
            if (createdBy == null || createdBy == uid) continue;

            final title = (data['title'] as String?) ?? 'an expense';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            final byName = info?.memberNames[createdBy] ?? 'Someone';

            NotificationService.show(
              type: NotificationType.group,
              title: info?.name ?? 'Group',
              body:
                  '$byName added $title — '
                  '${CurrencyFormatter.format(amount)}',
              payload: 'group:$groupId',
            );
          }
        });
  }

  static Future<void> stop() async {
    await _txSub?.cancel();
    _txSub = null;
    await _groupsSub?.cancel();
    _groupsSub = null;
    for (final sub in _expenseSubs.values) {
      await sub.cancel();
    }
    _expenseSubs.clear();
    _groups.clear();

    _running = false;
    _txPrimed = false;
    _knownTxnIds.clear();
    _primedExpenseGroups.clear();
    _localWrites.clear();
  }
}

class _GroupInfo {
  final String name;
  final Map<String, String> memberNames;

  const _GroupInfo({required this.name, required this.memberNames});
}
