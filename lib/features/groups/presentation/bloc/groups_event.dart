import 'package:equatable/equatable.dart';

import '../../domain/entities/group.dart';

abstract class GroupsEvent extends Equatable {
  const GroupsEvent();

  @override
  List<Object?> get props => [];
}

class GroupsWatched extends GroupsEvent {
  const GroupsWatched();
}

class GroupCreated extends GroupsEvent {
  final String name;
  final List<GroupMember> members;

  const GroupCreated({required this.name, required this.members});

  @override
  List<Object?> get props => [name, members];
}
