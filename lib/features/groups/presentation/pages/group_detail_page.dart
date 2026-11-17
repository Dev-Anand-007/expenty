import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/export/export_actions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/export_sheet.dart';
import '../../../../core/widgets/primary_text_field.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/group_balances.dart';
import '../../domain/group_expense_csv.dart';
import '../../domain/group_expense_pdf.dart';
import '../../domain/usecases/find_member_by_email_usecase.dart';
import '../../domain/usecases/find_member_by_username_usecase.dart';
import '../bloc/group_detail_bloc.dart';
import '../bloc/group_detail_event.dart';
import '../bloc/group_detail_state.dart';

class GroupDetailPage extends StatelessWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupDetailBloc>()..add(GroupDetailWatched(groupId)),
      child: BlocConsumer<GroupDetailBloc, GroupDetailState>(
        listener: (context, state) {
          if (state.left) {
            // Left the group: leave this screen instead of showing a
            // group the user is no longer part of.
            if (state.message != null) {
              AppSnackbar.show(
                context,
                state.message!,
                type: AppSnackbarType.success,
              );
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.dashboard);
            }
            return;
          }

          if (state.status == GroupDetailStatus.failure &&
              state.message != null &&
              !state.busy) {
            AppSnackbar.show(
              context,
              state.message!,
              type: AppSnackbarType.error,
            );
          }

          if (state.status == GroupDetailStatus.success &&
              state.message != null) {
            AppSnackbar.show(
              context,
              state.message!,
              type: AppSnackbarType.success,
            );
          }
        },
        builder: (context, state) {
          final group = state.group;
          final isLoading =
              group == null && state.status == GroupDetailStatus.loading;

          return Scaffold(
            backgroundColor: AppColors.background,
            floatingActionButton: group == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: state.busy
                        ? null
                        : () => context.push('/groups/$groupId/add-expense'),
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.white,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      'Add expense',
                      style: AppTypography.button.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
            body: SafeArea(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    )
                  : group == null
                  ? _FailedBody(state: state, groupId: groupId)
                  : _GroupBody(
                      group: group,
                      expenses: state.expenses,
                      groupId: groupId,
                      busy: state.busy,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _FailedBody extends StatelessWidget {
  final GroupDetailState state;
  final String groupId;

  const _FailedBody({required this.state, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              state.message ?? 'Could not open this group',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.read<GroupDetailBloc>().add(
                GroupDetailWatched(groupId),
              ),
              child: Text(
                'Retry',
                style: AppTypography.button.copyWith(color: AppColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBody extends StatelessWidget {
  final Group group;
  final List<GroupExpense> expenses;
  final String groupId;
  final bool busy;

  const _GroupBody({
    required this.group,
    required this.expenses,
    required this.groupId,
    required this.busy,
  });

  String _nameFor(String uid) {
    for (final member in group.members) {
      if (member.uid == uid) {
        return member.uid == AuthService.currentUser?.uid ? 'You' : member.name;
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    final nets = GroupBalances.nets(group);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
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
            _GroupOptionsMenu(groupId: groupId, isEnabled: !busy),
          ],
        ),
        const SizedBox(height: 16),

        /// Settlements — who still has to pay / who is overpaid.
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Settlements',
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Only the net balance of each member — positive means '
                'they are owed money, negative means they still owe.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < nets.length; i++) ...[
                _NetRow(net: nets[i], isSelf: nets[i].member.uid == uid),
                if (i != nets.length - 1) const Divider(height: 1, indent: 42),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        /// Expenses, with a calendar filter.
        _ExpenseSection(
          expenses: expenses,
          nameFor: _nameFor,
          isEnabled: !busy,
          onShowSplit: (expense) => _showSplit(context, expense),
          onDelete: (expense) => _confirmDelete(context, expense),
          onEdit: (expense) => _editExpense(context, expense),
        ),
      ],
    );
  }

  void _editExpense(BuildContext context, GroupExpense expense) {
    context.push('/groups/$groupId/edit-expense', extra: expense);
  }

  void _showSplit(BuildContext context, GroupExpense expense) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(expense.title, style: AppTypography.subtitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paid by ${_nameFor(expense.paidBy)} · '
                '${CurrencyFormatter.format(expense.amount)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                expense.splitLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              for (final member in group.members)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          member.uid == AuthService.currentUser?.uid
                              ? 'You'
                              : member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          expense.shares[member.uid] ?? 0,
                        ),
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
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
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    GroupExpense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete expense?', style: AppTypography.subtitle),
        content: Text(
          '“${expense.title}” will be removed and every balance in this '
          'group recalculated.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.button.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.button.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<GroupDetailBloc>().add(GroupExpenseRemoved(expense));
    }
  }
}

class _NetRow extends StatelessWidget {
  final MemberNet net;
  final bool isSelf;

  const _NetRow({required this.net, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final settled = net.isSettled;

    final color = settled
        ? AppColors.textSecondary
        : (net.mustPay > 0 ? AppColors.error : AppColors.success);

    final status = settled
        ? 'Settled up'
        : (net.mustPay > 0
              ? '${isSelf ? 'You owe' : '${net.member.name} owes'} '
                    '${CurrencyFormatter.format(net.mustPay)}'
              : '${isSelf ? 'You are owed' : '${net.member.name} is owed'} '
                    '${CurrencyFormatter.format(net.isOwed)}');

    final initial = net.member.name.trim().isEmpty
        ? '?'
        : net.member.name.trim().characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSelf ? '${net.member.name} (You)' : net.member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              status,
              textAlign: TextAlign.end,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final GroupExpense expense;
  final String payerName;
  final VoidCallback onShowSplit;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ExpenseTile({
    required this.expense,
    required this.payerName,
    required this.onShowSplit,
    required this.onDelete,
    required this.onEdit,
  });

  /// The small "edited" note: who, why, when — plus old → new amount
  /// when the amount itself changed.
  Widget? get _auditNote {
    final editedAt = expense.editedAt;
    if (editedAt == null) return null;

    final reason = (expense.editReason ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        key: const Key('expense-audit-note'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason.isEmpty
                  ? 'Edited on ${DateFormat.yMMMd().format(editedAt)}'
                  : 'Edited on ${DateFormat.yMMMd().format(editedAt)} — $reason',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (expense.amountChanged) ...[
              const SizedBox(height: 2),
              Text(
                '${CurrencyFormatter.format(expense.originalAmount!)} → '
                '${CurrencyFormatter.format(expense.amount)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onShowSplit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid by $payerName · ${expense.splitLabel} · '
                      '${DateFormat.yMMMd().format(expense.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_auditNote != null) _auditNote!,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CurrencyFormatter.format(expense.amount),
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<String>(
                key: const Key('expense-menu'),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (menuContext) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The expense list plus its calendar filter.
///
/// Kept in its own [StatefulWidget] so the selected date range survives
/// rebuilds driven by the group / expenses streams.
class _ExpenseSection extends StatefulWidget {
  final List<GroupExpense> expenses;
  final String Function(String uid) nameFor;
  final bool isEnabled;
  final ValueChanged<GroupExpense> onShowSplit;
  final ValueChanged<GroupExpense> onDelete;
  final ValueChanged<GroupExpense> onEdit;

  const _ExpenseSection({
    required this.expenses,
    required this.nameFor,
    required this.isEnabled,
    required this.onShowSplit,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_ExpenseSection> createState() => _ExpenseSectionState();
}

class _ExpenseSectionState extends State<_ExpenseSection> {
  _DateFilter _date = _DateFilter.all;
  DateTimeRange? _customRange;

  ({DateTime? start, DateTime? end}) get _bounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_date) {
      case _DateFilter.today:
        return (start: today, end: null);
      case _DateFilter.week:
        final daysSinceMonday = (now.weekday + 6) % 7;
        return (
          start: today.subtract(Duration(days: daysSinceMonday)),
          end: null,
        );
      case _DateFilter.month:
        return (start: DateTime(now.year, now.month, 1), end: null);
      case _DateFilter.custom:
        final range = _customRange;
        if (range == null) return (start: null, end: null);
        return (
          start: DateTime(range.start.year, range.start.month, range.start.day),
          end: DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          ).add(const Duration(days: 1)),
        );
      case _DateFilter.all:
        return (start: null, end: null);
    }
  }

  List<GroupExpense> get _filtered {
    final bounds = _bounds;

    return widget.expenses.where((expense) {
      final start = bounds.start;
      if (start != null && expense.date.isBefore(start)) return false;

      final end = bounds.end;
      if (end != null && !expense.date.isBefore(end)) return false;

      return true;
    }).toList();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.teal),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _date = _DateFilter.custom;
      });
    } else if (_date == _DateFilter.custom && _customRange == null) {
      setState(() => _date = _DateFilter.all);
    }
  }

  void _onDateSelected(_DateFilter filter) {
    if (filter == _DateFilter.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _date = filter);
  }

  String _chipLabel(_DateFilter filter) {
    switch (filter) {
      case _DateFilter.all:
        return 'All';
      case _DateFilter.today:
        return 'Today';
      case _DateFilter.week:
        return 'Week';
      case _DateFilter.month:
        return 'Month';
      case _DateFilter.custom:
        final range = _customRange;
        if (range == null) return 'Custom';
        return '${DateFormat('d MMM').format(range.start)} – '
            '${DateFormat('d MMM yyyy').format(range.end)}';
    }
  }

  bool get _hasFilter => _date != _DateFilter.all;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = widget.expenses.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Header — shows how many of the group's expenses are in view.
        Row(
          children: [
            Text(
              'Expenses',
              style: AppTypography.subtitle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _hasFilter ? '${filtered.length} of $total' : '$total',
                key: const Key('group-expense-count'),
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        /// Calendar filter.
        if (total > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in _DateFilter.values) ...[
                  _DateChip(
                    key: Key('group-date-${filter.name}'),
                    label: _chipLabel(filter),
                    selected: _date == filter,
                    onTap: widget.isEnabled
                        ? () => _onDateSelected(filter)
                        : null,
                  ),
                  if (filter != _DateFilter.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (total == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'No expenses yet — tap “Add expense” to start.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'No expenses in this date range.',
              key: const Key('group-expense-empty-filter'),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (final expense in filtered) ...[
            _ExpenseTile(
              expense: expense,
              payerName: widget.nameFor(expense.paidBy),
              onShowSplit: () => widget.onShowSplit(expense),
              onDelete: () => widget.onDelete(expense),
              onEdit: () => widget.onEdit(expense),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

enum _DateFilter { all, today, week, month, custom }

class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _DateChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 14, color: AppColors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The header's ⋮ menu: rename, add a member, leave.
///
/// Any member may use all three — there are no owner-only actions in a
/// group.
class _GroupOptionsMenu extends StatelessWidget {
  final String groupId;
  final bool isEnabled;

  const _GroupOptionsMenu({required this.groupId, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('group-options-menu'),
      enabled: isEnabled,
      onSelected: (value) {
        switch (value) {
          case 'rename':
            _rename(context);
          case 'add-member':
            _addMember(context);
          case 'export':
            _export(context);
          case 'leave':
            _leave(context);
        }
      },
      itemBuilder: (menuContext) => [
        _item(
          value: 'rename',
          icon: Icons.drive_file_rename_outline_rounded,
          color: AppColors.textPrimary,
          label: 'Edit group name',
        ),
        _item(
          value: 'add-member',
          icon: Icons.person_add_alt_1_rounded,
          color: AppColors.textPrimary,
          label: 'Add member',
        ),
        _item(
          value: 'export',
          icon: Icons.ios_share_rounded,
          color: AppColors.textPrimary,
          label: 'Export expenses',
        ),
        _item(
          value: 'leave',
          icon: Icons.logout_rounded,
          color: AppColors.error,
          label: 'Leave group',
        ),
      ],
      icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
    );
  }

  PopupMenuItem<String> _item({
    required String value,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Exports the group's expenses through the share/save chooser —
  /// CSV or PDF.
  Future<void> _export(BuildContext context) async {
    final state = context.read<GroupDetailBloc>().state;
    final group = state.group;
    final expenses = state.expenses;

    if (group == null || expenses.isEmpty) {
      AppSnackbar.show(context, 'No expenses to export yet');
      return;
    }

    final action = await ExportSheet.show(context);
    if (action == null || !context.mounted) return;

    final slug = group.name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-+|-+\$'), '');

    final pdf = await GroupExpensePdf.build(group: group, expenses: expenses);
    if (!context.mounted) return;

    await performExport(
      context,
      action: action,
      baseFilename:
          'expenty-${slug.isEmpty ? 'group' : slug}-'
          '${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      csvContent: GroupExpenseCsv.toCsv(group: group, expenses: expenses),
      pdf: pdf,
    );
  }

  Future<void> _rename(BuildContext context) async {
    final bloc = context.read<GroupDetailBloc>();
    final current = bloc.state.group?.name ?? '';

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: 'Edit group name',
        initialText: current,
        hintText: 'Group name',
        prefixIcon: Icons.groups_rounded,
        confirmLabel: 'Save',
        emptyError: 'Enter a name',
      ),
    );

    if (name == null || name.isEmpty || name == current || !context.mounted) {
      return;
    }
    bloc.add(GroupRenamed(name));
  }

  Future<void> _addMember(BuildContext context) async {
    final bloc = context.read<GroupDetailBloc>();

    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _TextPromptDialog(
        title: 'Add member',
        description:
            'They need an Expenty account. Look them up by email or @username.',
        hintText: 'friend@email.com or @username',
        prefixIcon: Icons.person_search_outlined,
        confirmLabel: 'Add',
        emptyError: 'Enter an email or username',
      ),
    );

    if (input == null || input.trim().isEmpty || !context.mounted) return;

    final raw = input.trim();

    // `user@mail.com` → email; `@handle` or `handle` → username.
    final isEmail = raw.contains('@') && !raw.startsWith('@');

    final member = isEmail
        ? await sl<FindMemberByEmailUseCase>()(raw)
        : await sl<FindMemberByUsernameUseCase>()(raw);

    if (!context.mounted) return;

    if (member == null || member.uid.isEmpty) {
      AppSnackbar.show(
        context,
        isEmail
            ? 'No Expenty user with that email — ask them to sign up first.'
            : 'No Expenty user with that @username — check the spelling.',
        type: AppSnackbarType.error,
      );
      return;
    }

    final group = bloc.state.group;
    if (group != null && group.members.any((m) => m.uid == member.uid)) {
      AppSnackbar.show(context, 'That member is already in this group.');
      return;
    }

    bloc.add(GroupMemberAdded(member));
  }

  Future<void> _leave(BuildContext context) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    final bloc = context.read<GroupDetailBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Leave this group?', style: AppTypography.subtitle),
        content: Text(
          'You’ll stop seeing this group and its expenses. Balances for '
          'the members who stay are kept exactly as they are.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.button.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Leave',
              style: AppTypography.button.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    bloc.add(GroupLeft(uid));
  }
}

/// A single-field prompt dialog.
///
/// The dialog owns its own [TextEditingController] and disposes it in
/// [State.dispose]. That matters because `showDialog`'s future completes
/// as soon as the route is popped — before the exit animation finishes — so
/// disposing the controller in the caller would dispose it while the
/// [PrimaryTextField] is still mounted.
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String? description;
  final String? initialText;
  final String hintText;
  final String? emptyError;
  final IconData prefixIcon;
  final String confirmLabel;

  const _TextPromptDialog({
    required this.title,
    required this.hintText,
    required this.prefixIcon,
    required this.confirmLabel,
    this.description,
    this.initialText,
    this.emptyError,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = widget.emptyError ?? 'This field is required');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: AppTypography.subtitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(
              widget.description!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ],
          PrimaryTextField(
            controller: _controller,
            hintText: widget.hintText,
            prefixIcon: Icon(widget.prefixIcon),
            autofocus: true,
            errorText: _error,
            onChanged: (_) {
              if (_error == null) return;
              setState(() => _error = null);
            },
          ),
        ],
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
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: AppTypography.button.copyWith(color: AppColors.teal),
          ),
        ),
      ],
    );
  }
}
