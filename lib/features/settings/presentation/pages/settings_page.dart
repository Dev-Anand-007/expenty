import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/theme_cubit.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_text_field.dart';
import '../../../auth/domain/usecases/delete_account_usecase.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../wallet/domain/usecases/reset_balance_usecase.dart';

/// App preferences: appearance, currency, notifications and about info.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _currency;
  late bool _notifyTransactions;
  late bool _notifyGroups;

  /// True while "Reset wallet balance" is talking to Firestore, so the tile
  /// can't be tapped twice.
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _currency = StorageService.currencySymbol;
    _notifyTransactions = StorageService.notifyTransactions;
    _notifyGroups = StorageService.notifyGroups;
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Future<void> _pickCurrency() async {
    const symbols = [
      '₹', // Indian Rupee
      '\$', // Dollar
      '€', // Euro
      '£', // Pound
      '¥', // Yen
      '₺', // Turkish Lira
      '₫', // Vietnamese Dong
      '₩', // Won
      'R', // Rand
      '₱', // Peso
      '₦', // Naira
      '৳', // Taka
    ];

    final customController = TextEditingController();

    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Currency symbol', style: AppTypography.subtitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final symbol in symbols)
                  ActionChip(
                    label: Text(symbol, style: AppTypography.subtitle),
                    backgroundColor: _currency == symbol
                        ? AppColors.primary.withValues(alpha: .15)
                        : AppColors.background,
                    side: BorderSide(
                      color: _currency == symbol
                          ? AppColors.primary
                          : AppColors.divider,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(symbol),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('settings-currency-custom'),
              controller: customController,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: 'Custom symbol',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style:
                  AppTypography.button.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final custom = customController.text.trim();
              Navigator.of(dialogContext).pop(custom.isEmpty ? null : custom);
            },
            child: Text(
              'Apply',
              style: AppTypography.button.copyWith(color: AppColors.teal),
            ),
          ),
        ],
      ),
    );

    customController.dispose();

    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _currency = picked);
    await StorageService.setCurrencySymbol(picked);
  }

  Future<void> _changePassword() async {
    final updated =
        await showDialog<bool>(
          context: context,
          builder: (_) => const _ChangePasswordDialog(),
        ) ??
        false;

    if (!updated || !mounted) return;
    AppSnackbar.show(
      context,
      'Password updated.',
      type: AppSnackbarType.success,
    );
  }

  /// Puts the dashboard balance back to ₹0 without touching any transaction.
  Future<void> _resetBalance() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => const _ResetBalanceDialog(),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _resetting = true);
    try {
      await sl<ResetBalanceUseCase>()();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Wallet balance reset to 0.',
        type: AppSnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Could not reset the balance — please try again.',
        type: AppSnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  /// Opens the delete-account confirmation, then bounces to login on success.
  Future<void> _deleteAccount() async {
    final deleted =
        await showDialog<bool>(
          context: context,
          builder: (_) => const _DeleteAccountDialog(),
        ) ??
        false;

    if (!deleted || !mounted) return;
    context.go(RouteNames.login);
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text(AppStrings.appName, style: AppTypography.subtitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${AppStrings.appVersion} (${AppStrings.appBuildNumber})',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'Track personal expenses, split bills with friends and settle '
              'up in seconds.',
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© ${DateTime.now().year} ${AppStrings.appName}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: AppTypography.button.copyWith(color: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', key: Key('settings-title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _sectionLabel('APPEARANCE'),
          _card(
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, mode) => SwitchListTile(
                key: const Key('settings-dark-mode'),
                value: mode == ThemeMode.dark,
                onChanged: (enabled) =>
                    context.read<ThemeCubit>().setDarkMode(enabled),
                title: Text(
                  'Dark mode',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Easier on the eyes at night',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                secondary: Icon(
                  Icons.dark_mode_outlined,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          _sectionLabel('PREFERENCES'),
          _card(
            Column(
              children: [
                ListTile(
                  key: const Key('settings-currency'),
                  leading: Icon(Icons.currency_rupee_rounded,
                      color: AppColors.primary),
                  title: Text(
                    'Currency',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Shown across the app — $_currency',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                  onTap: _pickCurrency,
                ),
                Divider(height: 1, color: AppColors.divider),
                SwitchListTile(
                  key: const Key('settings-notifications-transactions'),
                  value: _notifyTransactions,
                  onChanged: (value) {
                    setState(() => _notifyTransactions = value);
                    StorageService.setNotifyTransactions(value);
                  },
                  title: Text(
                    'Transaction alerts',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Get notified when income or expenses are recorded',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Divider(height: 1, color: AppColors.divider),
                SwitchListTile(
                  key: const Key('settings-notifications-groups'),
                  value: _notifyGroups,
                  onChanged: (value) {
                    setState(() => _notifyGroups = value);
                    StorageService.setNotifyGroups(value);
                  },
                  title: Text(
                    'Group activity',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'New expenses and settlements in your groups',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          _sectionLabel('SECURITY'),
          _card(
            ListTile(
              key: const Key('settings-change-password'),
              leading:
                  Icon(Icons.lock_outline_rounded, color: AppColors.primary),
              title: Text(
                'Change password',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Update the password you sign in with',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: _changePassword,
            ),
          ),

          _sectionLabel('DATA'),
          _card(
            ListTile(
              key: const Key('settings-reset-balance'),
              leading: Icon(Icons.restart_alt_rounded,
                  color: AppColors.primary),
              title: Text(
                'Reset wallet balance',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Set the dashboard balance back to 0 — transactions are kept',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              trailing: _resetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
              onTap: _resetting ? null : _resetBalance,
            ),
          ),

          _sectionLabel('ACCOUNT'),
          _card(
            ListTile(
              key: const Key('settings-delete-account'),
              leading:
                  Icon(Icons.delete_forever_outlined, color: AppColors.error),
              title: Text(
                'Delete account',
                style: AppTypography.body.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Permanently remove your account and all of its data',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: _deleteAccount,
            ),
          ),

          _sectionLabel('ABOUT'),
          _card(
            Column(
              children: [
                ListTile(
                  key: const Key('settings-version'),
                  leading:
                      Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  title: Text(
                    'App version',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${AppStrings.appVersion} (${AppStrings.appBuildNumber})',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Divider(height: 1, color: AppColors.divider),
                ListTile(
                  key: const Key('settings-about'),
                  leading: Icon(Icons.public_rounded,
                      color: AppColors.primary),
                  title: Text(
                    'About ${AppStrings.appName}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                  onTap: _showAbout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings → Change password: verify the current password, then set a
/// new one. Runs through its own [AuthBloc] so the status never leaks
/// into other pages.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit(AuthBloc bloc) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    bloc.add(
      ChangePasswordRequested(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.success) {
            Navigator.of(context).pop(true);
          }
        },
        builder: (dialogContext, state) {
          final loading = state.status == AuthStatus.loading;
          final error =
              state.status == AuthStatus.failure ? state.message : null;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Change password', style: AppTypography.subtitle),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryTextField(
                      key: const Key('settings-password-current'),
                      controller: _currentController,
                      hintText: 'Current password',
                      prefixIcon: Icon(Icons.lock_outline_rounded,
                          size: 20, color: AppColors.textSecondary),
                      obscureText: true,
                      enabled: !loading,
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 12),
                    PrimaryTextField(
                      key: const Key('settings-password-new'),
                      controller: _newController,
                      hintText: 'New password',
                      prefixIcon: Icon(Icons.password_rounded,
                          size: 20, color: AppColors.textSecondary),
                      obscureText: true,
                      enabled: !loading,
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 12),
                    PrimaryTextField(
                      key: const Key('settings-password-confirm'),
                      controller: _confirmController,
                      hintText: 'Confirm new password',
                      prefixIcon: Icon(Icons.password_rounded,
                          size: 20, color: AppColors.textSecondary),
                      obscureText: true,
                      enabled: !loading,
                      validator: (value) {
                        final base = Validators.validatePassword(value);
                        if (base != null) return base;
                        if (value != _newController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        key: const Key('settings-password-error'),
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    loading ? null : () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: AppTypography.button
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                key: const Key('settings-password-submit'),
                onPressed: loading ? null : () => _submit(dialogContext.read<AuthBloc>()),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        'Update',
                        style:
                            AppTypography.button.copyWith(color: AppColors.teal),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Settings → Reset wallet balance. Only confirms — the write happens in
/// `_SettingsPageState._resetBalance`, so this dialog never touches Firestore.
class _ResetBalanceDialog extends StatelessWidget {
  const _ResetBalanceDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Reset wallet balance?', style: AppTypography.subtitle),
      content: Text(
        'Your dashboard balance goes back to 0. Income, expenses and every '
        'transaction stay exactly as they are — this clears the figure, not '
        'your history.',
        style: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.button.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          key: const Key('settings-reset-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Reset',
            style: AppTypography.button.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

/// Settings → Delete account: the Play Store requires a working in-app
/// deletion flow, and Firebase will not let `user.delete()` run on a stale
/// session — hence the password for accounts that have one.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  /// Only email/password accounts need to prove themselves; Google sign-ins
  /// are re-authenticated silently by the datasource.
  late final bool _needsPassword;

  @override
  void initState() {
    super.initState();
    _needsPassword = sl<DeleteAccountUseCase>().requiresPasswordConfirmation();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(AuthBloc bloc) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    bloc.add(
      DeleteAccountRequested(
        password: _needsPassword ? _passwordController.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.success) {
            Navigator.of(context).pop(true);
          }
        },
        builder: (dialogContext, state) {
          final loading = state.status == AuthStatus.loading;
          final error =
              state.status == AuthStatus.failure ? state.message : null;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 28),
                const SizedBox(width: 10),
                Text('Delete account', style: AppTypography.subtitle),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This cannot be undone. Everything goes: your profile, '
                      '@username, wallet, every transaction, and your place '
                      'in any groups you share.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    if (_needsPassword) ...[
                      const SizedBox(height: 16),
                      PrimaryTextField(
                        key: const Key('settings-delete-password'),
                        controller: _passwordController,
                        hintText: 'Confirm your password',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        obscureText: true,
                        enabled: !loading,
                        validator: Validators.validateRequired,
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        key: const Key('settings-delete-error'),
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    loading ? null : () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: AppTypography.button
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                key: const Key('settings-delete-submit'),
                onPressed: loading
                    ? null
                    : () => _submit(dialogContext.read<AuthBloc>()),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : Text(
                        'Delete',
                        style:
                            AppTypography.button.copyWith(color: AppColors.error),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
