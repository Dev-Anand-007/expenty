import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/group.dart';

class GroupModel extends Group {
  const GroupModel({
    required super.id,
    required super.name,
    required super.createdBy,
    required super.createdAt,
    required super.members,
    required super.memberBalances,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    final rawMembers = (map['members'] as List?) ?? const [];
    final rawBalances = (map['memberBalances'] as Map?) ?? const {};

    return GroupModel(
      id: id,
      name: (map['name'] ?? '') as String,
      createdBy: (map['createdBy'] ?? '') as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      members: [
        for (final raw in rawMembers)
          if (raw is Map)
            GroupMember(
              uid: (raw['uid'] ?? '') as String,
              name: (raw['name'] ?? '') as String,
              email: (raw['email'] ?? '') as String,
            ),
      ],
      memberBalances: {
        for (final entry in rawBalances.entries)
          entry.key as String: (entry.value as num).toDouble(),
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberIds': [for (final member in members) member.uid],
      'members': [
        for (final member in members)
          {'uid': member.uid, 'name': member.name, 'email': member.email},
      ],
      'memberBalances': memberBalances,
    };
  }
}
