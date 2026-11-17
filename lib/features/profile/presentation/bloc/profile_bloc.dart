import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/set_username_usecase.dart';
import '../../domain/usecases/update_display_name_usecase.dart';
import '../../domain/usecases/update_profile_photo_usecase.dart';

import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfile;
  final UpdateDisplayNameUseCase updateDisplayName;
  final SetUsernameUseCase setUsername;
  final UpdateProfilePhotoUseCase updateProfilePhoto;

  ProfileBloc({
    required this.getProfile,
    required this.updateDisplayName,
    required this.setUsername,
    required this.updateProfilePhoto,
  }) : super(const ProfileState()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileNameSaveRequested>(_onNameSaveRequested);
    on<ProfileUsernameSaveRequested>(_onUsernameSaveRequested);
    on<ProfilePhotoUpdated>(_onPhotoUpdated);
  }

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(
      status: ProfileStatus.loading,
      clearMessage: true,
      clearSavingField: true,
    ));

    try {
      final profile = await getProfile();
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          profile: profile,
          clearMessage: true,
          clearSavingField: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          message: _messageOf(error),
          clearSavingField: true,
        ),
      );
    }
  }

  Future<void> _onNameSaveRequested(
    ProfileNameSaveRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (event.name.trim().isEmpty) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          message: 'Name cannot be empty',
          clearSavingField: true,
        ),
      );
      return;
    }

    emit(state.copyWith(
      status: ProfileStatus.saving,
      savingField: ProfileSaveTarget.name,
      clearMessage: true,
    ));

    try {
      await updateDisplayName(event.name);
      final profile = state.profile;
      emit(
        state.copyWith(
          status: ProfileStatus.saved,
          profile: profile?.copyWith(name: event.name.trim()),
          clearMessage: true,
          clearSavingField: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          message: _messageOf(error),
          clearSavingField: true,
        ),
      );
    }
  }

  Future<void> _onUsernameSaveRequested(
    ProfileUsernameSaveRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(
      status: ProfileStatus.saving,
      savingField: ProfileSaveTarget.username,
      clearMessage: true,
    ));

    try {
      await setUsername(event.username);
      final profile = state.profile;
      emit(
        state.copyWith(
          status: ProfileStatus.saved,
          profile: profile?.copyWith(username: event.username.trim().toLowerCase()),
          clearMessage: true,
          clearSavingField: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          message: _messageOf(error),
          clearSavingField: true,
        ),
      );
    }
  }

  Future<void> _onPhotoUpdated(
    ProfilePhotoUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(
      status: ProfileStatus.saving,
      savingField: ProfileSaveTarget.photo,
      clearMessage: true,
    ));

    try {
      await updateProfilePhoto(event.filePath);
      // Reload to pick up the new download URL.
      final profile = await getProfile();
      emit(
        state.copyWith(
          status: ProfileStatus.saved,
          profile: profile,
          clearMessage: true,
          clearSavingField: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          message: _messageOf(error),
          clearSavingField: true,
        ),
      );
    }
  }

  String _messageOf(Object error) {
    final text = error.toString();
    // Exception('x') formats as 'Exception: x' — trim the prefix noise.
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }
}
