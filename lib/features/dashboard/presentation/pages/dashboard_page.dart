import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../groups/domain/group_balances.dart';
import '../../../groups/presentation/bloc/groups_bloc.dart';
import '../../../groups/presentation/bloc/groups_event.dart';
import '../../../groups/presentation/bloc/groups_state.dart';
import '../../../groups/presentation/pages/groups_tab.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/presentation/widgets/add_balance_sheet.dart';
import '../../domain/dashboard_insights.dart';
import '../../../transactions/presentation/bloc/transactions_bloc.dart';
import '../../../transactions/presentation/bloc/transactions_event.dart';
import '../../../transactions/presentation/bloc/transactions_state.dart';
import '../../../transactions/presentation/pages/activity_tab.dart';
import '../widgets/balance_card.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/income_expense_card.dart';
import '../widgets/owe_pay_card.dart';
import '../widgets/top_expenses_section.dart';
import 'dashboard_menu_tab.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  void _comingSoon(String feature) {
    AppSnackbar.show(context, '$feature is coming soon');
  }

  void _openAddTransaction() => context.go(RouteNames.addTransaction);

  void _openActivityTab() => setState(() => _currentIndex = 1);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TransactionsBloc>(
          create: (_) =>
              sl<TransactionsBloc>()..add(const TransactionsWatched()),
        ),
        BlocProvider<WalletBloc>(
          create: (_) => sl<WalletBloc>()..add(const WalletWatched()),
        ),
        BlocProvider<GroupsBloc>(
          create: (_) => sl<GroupsBloc>()..add(const GroupsWatched()),
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocListener<WalletBloc, WalletState>(
            listener: (context, state) {
              if (state.status == WalletStatus.failure) {
                AppSnackbar.show(
                  context,
                  state.message ?? 'Something went wrong',
                  type: AppSnackbarType.error,
                );
              }
            },
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _HomeTab(
                  onComingSoon: _comingSoon,
                  onAddTransaction: _openAddTransaction,
                  onOpenActivityTab: _openActivityTab,
                ),
                const ActivityTab(),
                const GroupsTab(),
                const DashboardMenuTab(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: DashboardBottomNav(
          currentIndex: _currentIndex,
          onIndexChanged: (index) => setState(() => _currentIndex = index),
          onAdd: _openAddTransaction,
        ),
      ),
    );
  }
}

/// Home tab: header, balance, income/expenses, top expenses, activity teaser.
class _HomeTab extends StatelessWidget {
  final ValueChanged<String> onComingSoon;
  final VoidCallback onAddTransaction;
  final VoidCallback onOpenActivityTab;

  const _HomeTab({
    required this.onComingSoon,
    required this.onAddTransaction,
    required this.onOpenActivityTab,
  });

  @override
  Widget build(BuildContext context) {
    final walletBalance = context.watch<WalletBloc>().state.wallet.balance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        DashboardHeader(
          userName: AuthService.displayName,
          photoUrl: AuthService.currentUser?.photoURL,
        ),
        const SizedBox(height: 16),
        BlocBuilder<TransactionsBloc, TransactionsState>(
          builder: (context, txState) {
            final transactions = txState.transactions;
            final isLoading = txState.status == TransactionsStatus.loading &&
                transactions.isEmpty;
            final hasFailed = txState.status == TransactionsStatus.failure &&
                transactions.isEmpty;

            if (isLoading) return const _LoadingCard();

            if (hasFailed) {
              return _MessageCard(
                icon: Icons.cloud_off_rounded,
                color: AppColors.error,
                title: "Couldn't load your data",
                message: txState.message ?? 'Please try again.',
                actionLabel: 'Retry',
                onAction: () => context
                    .read<TransactionsBloc>()
                    .add(const TransactionsWatched()),
              );
            }

            final summary = DashboardInsights.summary(
              transactions,
              walletBalance: walletBalance,
            );
            final topExpenses = DashboardInsights.topExpenses(transactions);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BalanceCard(
                  summary: summary,
                  onMyBalances: () => onComingSoon('My Balances'),
                  onAddBalance: () => showAddBalanceSheet(context),
                ),
                const SizedBox(height: 14),

                /// Owe / owed across all groups
                BlocBuilder<GroupsBloc, GroupsState>(
                  builder: (context, groupState) {
                    final groups = groupState.groups;
                    if (groups.isEmpty) return const SizedBox.shrink();

                    final totals = GroupBalances.totals(
                      groups,
                      AuthService.currentUser?.uid ?? '',
                    );

                    return OwePayCard(
                      totals: totals,
                      groupCount: groups.length,
                    );
                  },
                ),
                const SizedBox(height: 14),

                IncomeExpenseCard(summary: summary),
                const SizedBox(height: 24),

                /// Top 5 expenses
                if (topExpenses.isEmpty)
                  _MessageCard(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.teal,
                    title: 'No expenses this week',
                    message:
                        'Add an expense to see your top categories here.',
                    actionLabel: 'Add transaction',
                    onAction: onAddTransaction,
                  )
                else ...[
                  TopExpensesSection(
                    expenses: topExpenses,
                    onFilterTap: onOpenActivityTab,
                  ),
                  const SizedBox(height: 24),
                ],

                /// Recent activity teaser
                if (transactions.isEmpty)
                  _MessageCard(
                    icon: Icons.history_rounded,
                    color: AppColors.teal,
                    title: 'No activity yet',
                    message:
                        'Your income and expenses will show up here once '
                        'you add them.',
                    actionLabel: 'See activity',
                    onAction: onOpenActivityTab,
                  )
                else
                  _MessageCard(
                    icon: Icons.history_rounded,
                    color: AppColors.teal,
                    title: 'Your full history',
                    message:
                        'Filter every transaction by date, income or '
                        'expense in Activity.',
                    actionLabel: 'See all activity',
                    onAction: onOpenActivityTab,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
