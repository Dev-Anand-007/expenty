import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// Profile / settings / logout tab.
class DashboardMenuTab extends StatelessWidget {
  const DashboardMenuTab({super.key});

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color ?? AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body.copyWith(
                          color: color ?? AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final email = user?.email ?? 'Not signed in';

    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.unauthenticated) {
            context.go(RouteNames.login);
          }

          if (state.status == AuthStatus.failure) {
            AppSnackbar.show(
              context,
              state.message ?? 'Something went wrong',
              type: AppSnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final isLoggingOut = state.status == AuthStatus.loading;
          final photoUrl = AuthService.currentUser?.photoURL;

          final initial = AuthService.displayName.isEmpty
              ? '?'
              : AuthService.displayName[0].toUpperCase();

          final initialLetter = Text(
            initial,
            style: AppTypography.title.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              /// Profile summary
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: .15),
                      child: photoUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                width: 52,
                                height: 52,
                                errorWidget: (_, __, ___) => initialLetter,
                              ),
                            )
                          : initialLetter,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthService.displayName,
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _tile(
                icon: Icons.person_outline_rounded,
                title: 'Profile',
                subtitle: 'Personal details, photo & username',
                onTap: () => context.push(RouteNames.profile),
              ),
              _tile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Preferences & security',
                onTap: () => context.push(RouteNames.settings),
              ),
              _tile(
                icon: Icons.logout_rounded,
                title: 'Log out',
                color: AppColors.error,
                enabled: !isLoggingOut,
                onTap: () => context.read<AuthBloc>().add(LogoutRequested()),
              ),

              if (isLoggingOut)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
