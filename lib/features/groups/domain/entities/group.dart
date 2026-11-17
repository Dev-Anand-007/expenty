/// A person who belongs to a group (denormalised from their profile).
class GroupMember {
  final String uid;
  final String name;
  final String email;

  const GroupMember({
    required this.uid,
    required this.name,
    required this.email,
  });
}

/// Net settlement per member.
///
/// [net] = what they paid − what they were charged.
/// Negative → they still owe money. Positive → they overpaid.
class MemberNet {
  final GroupMember member;
  final double net;

  const MemberNet({required this.member, required this.net});

  bool get isSettled => net.abs() < 0.005;

  /// Amount this person must pay back.
  double get mustPay => net < 0 ? -net : 0;

  /// Amount still owed to this person (they overpaid).
  double get isOwed => net > 0 ? net : 0;
}

class Group {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final List<GroupMember> members;
  final Map<String, double> memberBalances;

  const Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.memberBalances,
  });

  double balanceFor(String uid) => memberBalances[uid] ?? 0;
}
