import 'entities/group.dart';

/// Pure net-balance maths for groups.
///
/// Balance rule per expense: payer is credited the full amount, every member
/// (including the payer) is debited their share.
class GroupBalances {
  GroupBalances._();

  static Map<String, double> zero(List<GroupMember> members) {
    return {for (final member in members) member.uid: 0.0};
  }

  static Map<String, double> applyExpense(
    Map<String, double> balances, {
    required String paidBy,
    required double amount,
    required Map<String, double> shares,
  }) {
    final next = Map<String, double>.from(balances);
    next[paidBy] = (next[paidBy] ?? 0) + amount;

    shares.forEach((uid, share) {
      next[uid] = (next[uid] ?? 0) - share;
    });

    return next;
  }

  static Map<String, double> undoExpense(
    Map<String, double> balances, {
    required String paidBy,
    required double amount,
    required Map<String, double> shares,
  }) {
    final next = Map<String, double>.from(balances);
    next[paidBy] = (next[paidBy] ?? 0) - amount;

    shares.forEach((uid, share) {
      next[uid] = (next[uid] ?? 0) + share;
    });

    return next;
  }

  /// Per-member nets, sorted: people who owe first, then those who are owed.
  static List<MemberNet> nets(Group group) {
    final list = [
      for (final member in group.members)
        MemberNet(member: member, net: group.balanceFor(member.uid)),
    ];

    list.sort((a, b) {
      final bySign = a.net.compareTo(b.net);
      if (bySign != 0) return bySign;
      return a.member.name.compareTo(b.member.name);
    });

    return list;
  }

  /// Aggregated position of one member across many groups.
  static GroupTotals totals(List<Group> groups, String uid) {
    var owes = 0.0;
    var owed = 0.0;

    for (final group in groups) {
      final net = group.balanceFor(uid);
      if (net < 0) {
        owes += -net;
      } else {
        owed += net;
      }
    }

    return GroupTotals(owes: owes, owed: owed);
  }
}

class GroupTotals {
  final double owes;
  final double owed;

  const GroupTotals({required this.owes, required this.owed});

  bool get isZero => owes < 0.005 && owed < 0.005;
}
