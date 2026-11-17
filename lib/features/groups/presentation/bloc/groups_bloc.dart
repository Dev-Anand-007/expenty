import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/group.dart';
import '../../domain/usecases/create_group_usecase.dart';
import '../../domain/usecases/sync_own_profile_usecase.dart';
import '../../domain/usecases/watch_my_groups_usecase.dart';
import 'groups_event.dart';
import 'groups_state.dart';

class GroupsBloc extends Bloc<GroupsEvent, GroupsState> {
  final WatchMyGroupsUseCase watchMyGroups;
  final CreateGroupUseCase createGroup;
  final SyncOwnProfileUseCase syncOwnProfile;

  StreamSubscription<List<Group>>? _subscription;

  GroupsBloc({
    required this.watchMyGroups,
    required this.createGroup,
    required this.syncOwnProfile,
  }) : super(const GroupsState()) {
    on<GroupsWatched>(_onWatched);
    on<GroupCreated>(_onCreated);
    on<_GroupsLoaded>(_onLoaded);
    on<_GroupsFailed>(_onFailed);
  }

  Future<void> _onWatched(
    GroupsWatched event,
    Emitter<GroupsState> emit,
  ) async {
    emit(state.copyWith(status: GroupsStatus.loading));

    // Best effort: makes sure this user can be invited by email. Older
    // accounts (created before the profiles directory existed) are fixed
    // up here.
    try {
      await syncOwnProfile();
    } catch (_) {
      // Never block the tab on a directory write.
    }

    await _subscription?.cancel();
    _subscription = watchMyGroups().listen(
      (groups) => add(_GroupsLoaded(groups)),
      onError: (Object error) => add(_GroupsFailed(error.toString())),
    );
  }

  void _onLoaded(_GroupsLoaded event, Emitter<GroupsState> emit) {
    emit(
      state.copyWith(
        status: GroupsStatus.loaded,
        groups: event.groups,
        message: null,
      ),
    );
  }

  void _onFailed(_GroupsFailed event, Emitter<GroupsState> emit) {
    emit(state.copyWith(status: GroupsStatus.failure, message: event.message));
  }

  Future<void> _onCreated(GroupCreated event, Emitter<GroupsState> emit) async {
    emit(state.copyWith(status: GroupsStatus.loading));

    try {
      final id = await createGroup(name: event.name, members: event.members);
      emit(
        state.copyWith(
          status: GroupsStatus.success,
          createdGroupId: id,
          message: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(status: GroupsStatus.failure, message: error.toString()),
      );
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

class _GroupsLoaded extends GroupsEvent {
  final List<Group> groups;

  const _GroupsLoaded(this.groups);

  @override
  List<Object?> get props => [groups];
}

class _GroupsFailed extends GroupsEvent {
  final String message;

  const _GroupsFailed(this.message);

  @override
  List<Object?> get props => [message];
}
