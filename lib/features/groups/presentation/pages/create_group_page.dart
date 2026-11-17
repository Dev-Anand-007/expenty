import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/primary_text_field.dart';
import '../../domain/entities/group.dart';
import '../../domain/usecases/find_member_by_email_usecase.dart';
import '../../domain/usecases/find_member_by_username_usecase.dart';
import '../bloc/groups_bloc.dart';
import '../bloc/groups_event.dart';
import '../bloc/groups_state.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final List<GroupMember> _invited = [];
  bool _lookingUp = false;
  bool _navigated = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => AuthService.currentUser != null;

  GroupMember get _self => GroupMember(
    uid: AuthService.currentUser?.uid ?? '',
    name: AuthService.displayName,
    email: AuthService.currentUser?.email ?? '',
  );

  Future<void> _addMember() async {
    if (!_isLoggedIn) return;

    final input = _emailController.text.trim();
    if (input.isEmpty) {
      AppSnackbar.show(context, 'Enter an email address or @username');
      return;
    }

    // `user@mail.com` → email; `@handle` or `handle` → username.
    final isEmail = input.contains('@') && !input.startsWith('@');

    if (isEmail) {
      final valid = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(input);
      if (!valid) {
        AppSnackbar.show(context, 'Enter a valid email address');
        return;
      }
    }

    setState(() => _lookingUp = true);

    try {
      final member = isEmail
          ? await sl<FindMemberByEmailUseCase>()(input)
          : await sl<FindMemberByUsernameUseCase>()(input);

      if (member == null || member.uid.isEmpty) {
        if (mounted) {
          AppSnackbar.show(
            context,
            isEmail
                ? 'No Expenty user with that email — ask them to sign up first.'
                : 'No Expenty user with that @username — check the spelling.',
            type: AppSnackbarType.error,
          );
        }
        return;
      }

      if (!mounted) return;

      if (member.uid == _self.uid) {
        AppSnackbar.show(context, 'You are already in this group');
        return;
      }

      if (_invited.any((m) => m.uid == member.uid)) {
        AppSnackbar.show(context, 'That member is already added');
        return;
      }

      setState(() {
        _invited.add(member);
        _emailController.clear();
      });
    } catch (error) {
      if (mounted) {
        AppSnackbar.show(
          context,
          error.toString(),
          type: AppSnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _create(BuildContext blocContext) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isLoggedIn) {
      AppSnackbar.show(context, 'Please sign in again to create a group.');
      return;
    }

    blocContext.read<GroupsBloc>().add(
      GroupCreated(
        name: _nameController.text.trim(),
        members: [_self, ..._invited],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Factory: only needs the create flow, not the list subscription.
      create: (_) => sl<GroupsBloc>(),
      child: BlocConsumer<GroupsBloc, GroupsState>(
        listener: (context, state) {
          final id = state.createdGroupId;

          if (state.status == GroupsStatus.success &&
              id != null &&
              !_navigated) {
            _navigated = true;
            AppSnackbar.show(
              context,
              'Group created',
              type: AppSnackbarType.success,
            );
            context.pushReplacement('/groups/$id');
          }

          if (state.status == GroupsStatus.failure) {
            AppSnackbar.show(
              context,
              state.message ?? 'Could not create the group',
              type: AppSnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final isSaving = state.status == GroupsStatus.loading;

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    /// Header
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(RouteNames.dashboard);
                            }
                          },
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        Text(
                          'New group',
                          style: AppTypography.title.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    PrimaryTextField(
                      controller: _nameController,
                      hintText: 'Group name (e.g. Goa trip)',
                      prefixIcon: const Icon(Icons.groups_rounded),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter a group name'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Add members',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PrimaryTextField(
                            controller: _emailController,
                            hintText: 'friend@example.com or @username',
                            prefixIcon:
                                const Icon(Icons.person_search_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _lookingUp ? null : _addMember,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _lookingUp
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Everyone must have an Expenty account.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: .8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Members
                    _memberTile(member: _self, isSelf: true, onRemove: null),
                    for (final member in _invited) ...[
                      const SizedBox(height: 10),
                      _memberTile(
                        member: member,
                        isSelf: false,
                        onRemove: () => setState(() => _invited.remove(member)),
                      ),
                    ],

                    const SizedBox(height: 32),
                    PrimaryButton(
                      text: isSaving ? 'Creating...' : 'Create Group',
                      isLoading: isSaving,
                      onPressed: isSaving ? null : () => _create(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _memberTile({
    required GroupMember member,
    required bool isSelf,
    required VoidCallback? onRemove,
  }) {
    final initial = member.name.trim().isEmpty
        ? '?'
        : member.name.trim().characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelf
              ? AppColors.teal.withValues(alpha: .35)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isSelf
                ? AppColors.teal.withValues(alpha: .16)
                : AppColors.primary.withValues(alpha: .12),
            child: Text(
              initial,
              style: AppTypography.caption.copyWith(
                color: isSelf ? AppColors.teal : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'You',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
