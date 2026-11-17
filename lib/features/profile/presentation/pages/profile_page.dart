import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/primary_text_field.dart';
import '../../domain/username_rules.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';

/// Edit personal details: avatar, display name and @username.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// TEMP — avatar uploads are parked while Firebase Storage is broken for
  /// this project (the bucket rejects/never accepts `avatars/{uid}.jpg`).
  ///
  /// While `false` the camera badge only shows a "coming soon" toast and the
  /// existing photo is displayed read-only. The whole pick → crop → upload
  /// pipeline (image_picker, image_cropper, `ProfileStorageDataSource`,
  /// `UpdateProfilePhotoUseCase`) is still wired up below and in
  /// `service_locator.dart`, so re-enabling is a one-line change:
  ///   1. flip this flag to `true`,
  ///   2. confirm the Storage bucket exists in the Firebase console and
  ///      publish `storage.rules` (`firebase deploy --only storage`).
  static const _photoUploadEnabled = false;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  final _picker = ImagePicker();

  /// One-shot sync of the loaded profile into the fields.
  bool _fieldsFilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onPhotoPressed(BuildContext context) {
    if (!_photoUploadEnabled) {
      AppSnackbar.show(
        context,
        'Profile photo is coming soon',
        type: AppSnackbarType.info,
      );
      return;
    }
    _openPhotoSourceSheet(context);
  }

  Future<void> _openPhotoSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              key: const Key('profile-photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: Text('Choose from gallery', style: AppTypography.body),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              key: const Key('profile-photo-camera'),
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: Text('Take a photo', style: AppTypography.body),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;
    await _pickAndCrop(context, source);
  }

  Future<void> _pickAndCrop(BuildContext context, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (picked == null || !context.mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(title: 'Crop photo'),
        ],
      );
      if (cropped == null || !context.mounted) return;

      context.read<ProfileBloc>().add(ProfilePhotoUpdated(cropped.path));
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Could not open the image picker',
          type: AppSnackbarType.error,
        );
      }
    }
  }

  void _saveName(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(context, 'Name cannot be empty',
          type: AppSnackbarType.error);
      return;
    }
    context.read<ProfileBloc>().add(ProfileNameSaveRequested(name));
  }

  void _saveUsername(BuildContext context) {
    final raw = _usernameController.text;
    final error = UsernameRules.validate(raw);
    if (error != null) {
      AppSnackbar.show(context, error, type: AppSnackbarType.error);
      return;
    }
    context
        .read<ProfileBloc>()
        .add(ProfileUsernameSaveRequested(UsernameRules.normalize(raw)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileBloc>()..add(const ProfileLoadRequested()),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state.status == ProfileStatus.saved) {
            AppSnackbar.show(context, 'Profile updated',
                type: AppSnackbarType.success);
          }

          if (state.status == ProfileStatus.failure &&
              state.message != null) {
            AppSnackbar.show(
              context,
              state.message!,
              type: AppSnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final profile = state.profile;

          if (profile == null && (state.isBusy || state.status == ProfileStatus.initial)) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: const AppLoader(),
            );
          }

          if (profile == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(title: const Text('Profile')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load your profile',
                        textAlign: TextAlign.center,
                        style: AppTypography.subtitle
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      if (state.message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          state.message!,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 16),
                      PrimaryButton(
                        key: const Key('profile-retry'),
                        text: 'Retry',
                        onPressed: () => context
                            .read<ProfileBloc>()
                            .add(const ProfileLoadRequested()),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (!_fieldsFilled) {
            _fieldsFilled = true;
            _nameController.text = profile.name;
            _usernameController.text = profile.username ?? '';
            _emailController.text = profile.email;
          }

          final initial = profile.name.trim().isEmpty
              ? '?'
              : profile.name.trim()[0].toUpperCase();

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Profile', key: Key('profile-title')),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                /// Avatar
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        key: const Key('profile-avatar'),
                        radius: 48,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: .15),
                        child: profile.photoUrl == null
                            ? Text(
                                initial,
                                style: AppTypography.displayLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: profile.photoUrl!,
                                  fit: BoxFit.cover,
                                  width: 96,
                                  height: 96,
                                  placeholder: (_, __) => Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Text(
                                    initial,
                                    style:
                                        AppTypography.displayLarge.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('profile-photo-button'),
                          customBorder: const CircleBorder(),
                          onTap: state.isBusy
                              ? null
                              : () => _onPhotoPressed(context),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                /// Display name
                Text(
                  'Display name',
                  style: AppTypography.subtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                PrimaryTextField(
                  key: const Key('profile-name-field'),
                  controller: _nameController,
                  hintText: 'Your name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  key: const Key('profile-save-name'),
                  text: 'Save name',
                  isLoading: state.isSaving(ProfileSaveTarget.name),
                  onPressed: state.isBusy
                      ? null
                      : () => _saveName(context),
                ),

                const SizedBox(height: 28),

                /// Username
                Text(
                  'Username',
                  style: AppTypography.subtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Friends can find and add you with @username.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                PrimaryTextField(
                  key: const Key('profile-username-field'),
                  controller: _usernameController,
                  hintText: 'username',
                  keyboardType: TextInputType.text,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  key: const Key('profile-save-username'),
                  text: 'Save username',
                  isLoading: state.isSaving(ProfileSaveTarget.username),
                  onPressed: state.isBusy
                      ? null
                      : () => _saveUsername(context),
                ),

                const SizedBox(height: 28),

                /// Email (read-only)
                Text(
                  'Email',
                  style: AppTypography.subtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                PrimaryTextField(
                  key: const Key('profile-email-field'),
                  controller: _emailController,
                  hintText: 'Email',
                  enabled: false,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
