import 'package:equatable/equatable.dart';

import '../../domain/entities/group.dart';

enum GroupsStatus { initial, loading, loaded, success, failure }

class GroupsState extends Equatable {
  final GroupsStatus status;
  final List<Group> groups;
  final String? createdGroupId;
  final String? message;

  const GroupsState({
    this.status = GroupsStatus.initial,
    this.groups = const [],
    this.createdGroupId,
    this.message,
  });

  GroupsState copyWith({
    GroupsStatus? status,
    List<Group>? groups,
    String? createdGroupId,
    String? message,
  }) {
    return GroupsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      createdGroupId: createdGroupId ?? this.createdGroupId,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, groups, createdGroupId, message];
}
