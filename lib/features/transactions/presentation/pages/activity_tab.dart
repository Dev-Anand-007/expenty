import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/export/export_actions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/export_sheet.dart';
import '../../domain/entities/money_transaction.dart';
import '../../domain/transaction_csv.dart';
import '../../domain/transaction_pdf.dart';
import '../bloc/transactions_bloc.dart';
import '../bloc/transactions_event.dart';
import '../bloc/transactions_state.dart';

enum _TypeFilter { all, income, expense }

enum _DateFilter { all, today, week, month, custom }

/// Full transaction history with income/expense and date filters.
class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  _TypeFilter _type = _TypeFilter.all;
  _DateFilter _date = _DateFilter.all;
  DateTimeRange? _customRange;

  /// Start (inclusive) / end (exclusive) of the active date filter.
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
          end: DateTime(range.end.year, range.end.month, range.end.day)
              .add(const Duration(days: 1)),
        );
      case _DateFilter.all:
        return (start: null, end: null);
    }
  }

  List<MoneyTransaction> _applyFilters(List<MoneyTransaction> all) {
    final bounds = _bounds;

    final filtered = all.where((transaction) {
      if (_type == _TypeFilter.income && !transaction.isIncome) return false;
      if (_type == _TypeFilter.expense && transaction.isIncome) return false;

      final start = bounds.start;
      if (start != null && transaction.date.isBefore(start)) return false;

      final end = bounds.end;
      if (end != null && !transaction.date.isBefore(end)) return false;

      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return filtered;
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.teal,
                ),
          ),
          child: child!,
        );
      },
    );

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

  /// Exports the currently filtered rows (respects type + date filters)
  /// through the share/save chooser — CSV or PDF.
  Future<void> _export(List<MoneyTransaction> rows) async {
    final action = await ExportSheet.show(context);
    if (action == null || !mounted) return;

    final pdf = await TransactionPdf.build(rows);
    if (!mounted) return;

    await performExport(
      context,
      action: action,
      baseFilename:
          'expenty-activity-${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      csvContent: TransactionCsv.toCsv(rows),
      pdf: pdf,
    );
  }

  String get _dateChipLabel {
    switch (_date) {
      case _DateFilter.all:
        return 'All time';
      case _DateFilter.today:
        return 'Today';
      case _DateFilter.week:
        return 'This week';
      case _DateFilter.month:
        return 'This month';
      case _DateFilter.custom:
        final range = _customRange;
        if (range == null) return 'Custom range';
        final start = DateFormat('d MMM').format(range.start);
        final end = DateFormat('d MMM yyyy').format(range.end);
        return '$start – $end';
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionsBloc bloc,
    MoneyTransaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${transaction.title}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) bloc.add(TransactionDeleted(transaction.id));
  }

  /// Tapping a row offers edit / delete for that transaction.
  Future<void> _showActions(MoneyTransaction transaction) async {
    final bloc = context.read<TransactionsBloc>();
    final isTopUp =
        TransactionCategories.isWalletTopUp(transaction.category);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final category = TransactionCategories.byName(transaction.category);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, size: 22, color: category.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${transaction.category}  •  '
                            '${DateFormat.yMMMd().format(transaction.date)}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${transaction.isIncome ? '+' : '-'}'
                      '${CurrencyFormatter.format(transaction.amount)}',
                      style: AppTypography.subtitle.copyWith(
                        color: transaction.isIncome
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (isTopUp)
                  // Wallet top-ups are generated by "Add balance" — their
                  // amount/category are owned by the wallet, so only the
                  // delete path is offered.
                  ListTile(
                    key: const Key('activity-action-locked'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(
                      'Editing is disabled',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Wallet top-ups are recorded when you add balance, '
                      'so their details stay as they are. You can still '
                      'delete this row.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  ListTile(
                    key: const Key('activity-action-edit'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Edit transaction',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Change amount, category, date or note',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop('edit'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Delete transaction',
                    style: AppTypography.body.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('delete'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'edit' && !isTopUp) {
      context.push(RouteNames.editTransaction, extra: transaction);
    } else if (action == 'delete') {
      await _confirmDelete(context, bloc, transaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TransactionsBloc, TransactionsState>(
      listener: (context, state) {
        if (state.status == TransactionsStatus.failure) {
          AppSnackbar.show(
            context,
            state.message ?? 'Something went wrong',
            type: AppSnackbarType.error,
          );
        }

        if (state.status == TransactionsStatus.success &&
            (state.message ?? '').isNotEmpty) {
          AppSnackbar.show(
            context,
            state.message!,
            type: AppSnackbarType.success,
          );
        }
      },
      builder: (context, state) {
        final transactions = state.transactions;
        final isLoading = state.status == TransactionsStatus.loading &&
            transactions.isEmpty;
        final hasFailed = state.status == TransactionsStatus.failure &&
            transactions.isEmpty;

        final filtered = _applyFilters(transactions);
        final income = filtered
            .where((t) => t.isIncome)
            .fold<double>(0, (sum, t) => sum + t.amount);
        final expenses = filtered
            .where((t) => !t.isIncome)
            .fold<double>(0, (sum, t) => sum + t.amount);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            /// Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity',
                  style: AppTypography.headline.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${filtered.length} '
                      '${filtered.length == 1 ? 'transaction' : 'transactions'}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('activity-export'),
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _export(filtered),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Export CSV',
                      icon: Icon(
                        Icons.ios_share_rounded,
                        size: 20,
                        color: filtered.isEmpty
                            ? AppColors.divider
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Income / expense filter
            Row(
              children: [
                _TypeButton(
                  label: 'All',
                  selected: _type == _TypeFilter.all,
                  color: AppColors.teal,
                  onTap: () => setState(() => _type = _TypeFilter.all),
                ),
                const SizedBox(width: 10),
                _TypeButton(
                  label: 'Income',
                  selected: _type == _TypeFilter.income,
                  color: AppColors.success,
                  onTap: () => setState(() => _type = _TypeFilter.income),
                ),
                const SizedBox(width: 10),
                _TypeButton(
                  label: 'Expense',
                  selected: _type == _TypeFilter.expense,
                  color: AppColors.error,
                  onTap: () => setState(() => _type = _TypeFilter.expense),
                ),
              ],
            ),
            const SizedBox(height: 12),

            /// Date filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _DateFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _DateChip(
                        label: filter == _DateFilter.custom
                            ? _dateChipLabel
                            : _labelFor(filter),
                        selected: _date == filter,
                        onTap: () => _onDateSelected(filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else if (hasFailed)
              _StatusCard(
                icon: Icons.cloud_off_rounded,
                color: AppColors.error,
                title: "Couldn't load transactions",
                message: state.message ?? 'Please try again.',
                actionLabel: 'Retry',
                onAction: () => context
                    .read<TransactionsBloc>()
                    .add(const TransactionsWatched()),
              )
            else ...[
              /// Totals for the current filter
              _TotalsCard(income: income, expenses: expenses),
              const SizedBox(height: 18),

              if (filtered.isEmpty)
                _StatusCard(
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.teal,
                  title: 'Nothing here yet',
                  message: _emptyMessage(),
                  actionLabel: null,
                  onAction: null,
                )
              else
                for (final group in _groupByDay(filtered)) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 6),
                    child: Text(
                      group.label,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final transaction in group.transactions)
                    _TransactionTile(
                      transaction: transaction,
                      onTap: () => _showActions(transaction),
                    ),
                ],
            ],
          ],
        );
      },
    );
  }

  String _labelFor(_DateFilter filter) {
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
        return 'Custom';
    }
  }

  String _emptyMessage() {
    final hasFilter = _type != _TypeFilter.all || _date != _DateFilter.all;
    if (hasFilter) {
      return 'No transactions match the selected filters. '
          'Try a wider date range or a different type.';
    }
    return 'Add your first income or expense to see it here.';
  }

  List<_DayGroup> _groupByDay(List<MoneyTransaction> transactions) {
    final groups = <_DayGroup>[];
    DateTime? currentDay;

    for (final transaction in transactions) {
      final day = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (day != currentDay) {
        currentDay = day;
        groups.add(_DayGroup(label: _dayLabel(day), transactions: []));
      }

      groups.last.transactions.add(transaction);
    }

    return groups;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return DateFormat('EEEE, d MMM yyyy').format(day);
  }
}

class _DayGroup {
  final String label;
  final List<MoneyTransaction> transactions;

  _DayGroup({required this.label, required this.transactions});
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        key: Key('activity-filter-$label'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : AppColors.divider),
          ),
          child: Text(
            label,
            style: AppTypography.button.copyWith(
              fontSize: 14,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('activity-date-$label'),
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
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final double income;
  final double expenses;

  const _TotalsCard({required this.income, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final net = income - expenses;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: .22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.white.withValues(alpha: .75),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(income),
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: AppColors.white.withValues(alpha: .24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: .22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expenses',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.white.withValues(alpha: .75),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(expenses),
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net for this period',
                style: AppTypography.caption.copyWith(
                  color: AppColors.white.withValues(alpha: .75),
                ),
              ),
              Text(
                '${net < 0 ? '-' : '+'}${CurrencyFormatter.format(net.abs())}',
                style: AppTypography.subtitle.copyWith(
                  color: net < 0 ? AppColors.error : AppColors.chartMint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final MoneyTransaction transaction;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = TransactionCategories.byName(transaction.category);
    final isIncome = transaction.isIncome;
    final sign = isIncome ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, size: 20, color: category.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          transaction.category,
                          if (transaction.note.isNotEmpty) transaction.note,
                          DateFormat.jm().format(transaction.date),
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sign${CurrencyFormatter.format(transaction.amount)}',
                      style: AppTypography.subtitle.copyWith(
                        color: isIncome
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (_) => onTap(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'actions', child: Text('Edit / Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusCard({
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
