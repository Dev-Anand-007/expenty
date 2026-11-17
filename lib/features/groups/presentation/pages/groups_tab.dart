import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/entities/group.dart';
import '../bloc/groups_bloc.dart';
import '../bloc/groups_event.dart';
import '../bloc/groups_state.dart';

/// Replaces the old Merchants tab: list of my groups with a quick read on
/// what I owe / am owed in each one.
///
/// Uses the [GroupsBloc] provided by the dashboard so the owe/pay summary
/// and this list share one Firestore listener.
class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupsBloc, GroupsState>(
      listener: (context, state) {
        if (state.status == GroupsStatus.failure) {
          AppSnackbar.show(
            context,
            state.message ?? 'Something went wrong',
            type: AppSnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final groups = state.groups;
        final uid = AuthService.currentUser?.uid;
        final isLoading =
            state.status == GroupsStatus.loading && groups.isEmpty;
        final hasFailed =
            state.status == GroupsStatus.failure && groups.isEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            /// Header
            Row(
              children: [
                Text(
                  'Groups',
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push(RouteNames.createGroup),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    'New group',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              ),
            ] else if (hasFailed) ...[
              _EmptyState(
                icon: Icons.cloud_off_rounded,
                color: AppColors.error,
                title: 'Could not load your groups',
                message: state.message ?? 'Please try again.',
                actionLabel: 'Retry',
                onAction: () =>
                    context.read<GroupsBloc>().add(const GroupsWatched()),
              ),
            ] else if (groups.isEmpty) ...[
              _EmptyState(
                icon: Icons.groups_rounded,
                color: AppColors.teal,
                title: 'No groups yet',
                message:
                    'Create a group to split rent, trips or dinners with '
                    'friends and see who owes whom at a glance.',
                actionLabel: 'Create a group',
                onAction: () => context.push(RouteNames.createGroup),
              ),
            ] else ...[
              for (final group in groups) ...[
                _GroupCard(group: group, uid: uid),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final String? uid;

  const _GroupCard({required this.group, this.uid});

  String get _initial {
    final name = group.name.trim();
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final net = uid == null ? 0.0 : group.balanceFor(uid!);
    final settled = net.abs() < 0.005;

    final color = settled
        ? AppColors.textSecondary
        : (net < 0 ? AppColors.error : AppColors.success);
    final label = settled
        ? 'Settled up'
        : (net < 0
              ? 'You owe ${CurrencyFormatter.format(-net)}'
              : 'You are owed ${CurrencyFormatter.format(net)}');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/groups/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.teal.withValues(alpha: .14),
                child: Text(
                  _initial,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.members.length} '
                      '${group.members.length == 1 ? 'member' : 'members'}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: AppTypography.button.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
