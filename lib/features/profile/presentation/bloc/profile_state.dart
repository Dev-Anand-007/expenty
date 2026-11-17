import 'package:equatable/equatable.dart';

import '../../domain/entities/profile.dart';

enum ProfileStatus {
  initial,

  /// First fetch in progress.
  loading,

  /// A save (name / username / photo) is in progress.
  saving,

  /// Initial fetch finished.
  loaded,

  /// A save finished successfully.
  saved,
  failure,
}

/// Which field the current save belongs to. Lets the page spin only the
/// button that was actually pressed instead of every save button at once.
enum ProfileSaveTarget { name, username, photo }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final Profile? profile;
  final String? message;

  /// Set only while [status] is [ProfileStatus.saving].
  final ProfileSaveTarget? savingField;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.message,
    this.savingField,
  });

  bool get isBusy =>
      status == ProfileStatus.loading || status == ProfileStatus.saving;

  /// True when [target] is the save currently in flight.
  bool isSaving(ProfileSaveTarget target) =>
      status == ProfileStatus.saving && savingField == target;

  ProfileState copyWith({
    ProfileStatus? status,
    Profile? profile,
    String? message,
    ProfileSaveTarget? savingField,
    bool clearMessage = false,
    bool clearSavingField = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      message: clearMessage ? null : (message ?? this.message),
      savingField: clearSavingField
          ? null
          : (savingField ?? this.savingField),
    );
  }

  @override
  List<Object?> get props => [status, profile, message, savingField];
}
