import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

class ProfileNameSaveRequested extends ProfileEvent {
  final String name;

  const ProfileNameSaveRequested(this.name);

  @override
  List<Object?> get props => [name];
}

class ProfileUsernameSaveRequested extends ProfileEvent {
  final String username;

  const ProfileUsernameSaveRequested(this.username);

  @override
  List<Object?> get props => [username];
}

class ProfilePhotoUpdated extends ProfileEvent {
  /// Local path of the picked + cropped image.
  final String filePath;

  const ProfilePhotoUpdated(this.filePath);

  @override
  List<Object?> get props => [filePath];
}
