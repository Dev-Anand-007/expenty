import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/primary_text_field.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/split_calculator.dart';
import '../bloc/group_detail_bloc.dart';
import '../bloc/group_detail_event.dart';
import '../bloc/group_detail_state.dart';

class AddGroupExpensePage extends StatefulWidget {
  final String groupId;

  /// When set the page edits this expense instead of creating one, and
  /// requires a reason for the change.
  final GroupExpense? existing;

  const AddGroupExpensePage({super.key, required this.groupId, this.existing});

  @override
  State<AddGroupExpensePage> createState() => _AddGroupExpensePageState();
}

class _AddGroupExpensePageState extends State<AddGroupExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();

  /// One text controller per member per split mode, so switching modes
  /// doesn't lose what was typed.
  final Map<SplitType, Map<String, TextEditingController>> _values = {
    for (final type in SplitType.values) type: {},
  };

  SplitType _splitType = SplitType.equal;
  String? _paidBy;
  DateTime _date = DateTime.now();

  /// Edit mode: a change reason is mandatory so the row can carry an
  /// audit note.
  final _reasonController = TextEditingController();

  /// Set once the existing expense's amount / title / date / split have
  /// been written into the form.
  bool _basePrefilled = false;

  /// Set once the per-member split inputs have been written too — those
  /// wait for the group's members to arrive.
  bool _splitPrefilled = false;

  /// Set once the group loads so every member has a value controller for
  /// each split mode (percentages are prefilled from the member count).
  List<GroupMember>? _members;

  bool get _isEditing => widget.existing != null;

  void _ensureControllers(List<GroupMember> members) {
    if (members.isEmpty) return;
    if (_members != null && _members!.length == members.length) return;

    _members = members;
    for (final member in members) {
      _valueFor(SplitType.ratio, member.uid);
      _valueFor(SplitType.percentage, member.uid);
      _valueFor(SplitType.custom, member.uid);
    }
  }

  /// Writes the stored expense into the form once the members are known.
  void _prefill(List<GroupMember> members) {
    if (_basePrefilled || !_isEditing) return;
    _basePrefilled = true;

    final existing = widget.existing!;
    _amountController.text = _formatAmount(existing.amount);
    _titleController.text = existing.title;
    _date = existing.date;
    _splitType = existing.splitType;
    _paidBy = existing.paidBy;
    _reasonController.text = '';

    _prefillSplit(existing, members);
  }

  /// Writes the stored per-member split into the value controllers once
  /// the member list is known.
  void _prefillSplit(GroupExpense existing, List<GroupMember> members) {
    if (_splitPrefilled || members.isEmpty) return;
    if (existing.splitType == SplitType.equal) {
      _splitPrefilled = true;
      return;
    }
    _splitPrefilled = true;

    final values = _splitValuesFor(existing, members);
    values.forEach((uid, text) {
      _valueFor(existing.splitType, uid).text = text;
    });
  }

  /// Reconstructs the per-member inputs of a stored expense.
  ///
  /// Prefers the human `splitLabel` (what the user originally typed) and
  /// falls back to the stored shares when the member list has changed
  /// since — e.g. someone joined afterwards.
  Map<String, String> _splitValuesFor(
    GroupExpense existing,
    List<GroupMember> members,
  ) {
    final labelParts = existing.splitLabel.split(':');
    final labelMatches =
        labelParts.length == members.length &&
        existing.splitType != SplitType.custom;

    if (labelMatches) {
      return {
        for (var i = 0; i < members.length; i++)
          members[i].uid: labelParts[i].trim(),
      };
    }

    switch (existing.splitType) {
      case SplitType.custom:
        return {
          for (final member in members)
            member.uid: _formatAmount(existing.shares[member.uid] ?? 0),
        };
      case SplitType.percentage:
        final amount = existing.amount;
        return {
          for (final member in members)
            member.uid: amount == 0
                ? '0'
                : _formatAmount(
                    (existing.shares[member.uid] ?? 0) / amount * 100,
                  ),
        };
      case SplitType.ratio:
      case SplitType.equal:
        // Shares are proportional to the ratio, so they work as ratios.
        return {
          for (final member in members)
            member.uid: _formatAmount(existing.shares[member.uid] ?? 0),
        };
    }
  }

  String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _reasonController.dispose();
    for (final map in _values.values) {
      for (final controller in map.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  /// "Amount ₹600.00 → ₹900.00" style hint, or null when the amount has
  /// not changed yet.
  String? get _amountChangeNote {
    final existing = widget.existing;
    if (existing == null) return null;

    final newAmount = _amount;
    if (newAmount == null || newAmount == existing.amount) {
      return 'Amount unchanged at ${CurrencyFormatter.format(existing.amount)}.';
    }

    return 'Amount ${CurrencyFormatter.format(existing.amount)} → '
        '${CurrencyFormatter.format(newAmount)}';
  }

  TextEditingController _valueFor(SplitType type, String uid) {
    final map = _values[type]!;
    return map.putIfAbsent(uid, () {
      final controller = TextEditingController();
      if (type == SplitType.ratio) {
        controller.text = '1'; // 1:1:1 by default
      } else if (type == SplitType.percentage) {
        // Prefill an even percentage split that already totals 100.
        final count = _memberCount;
        if (count > 0) {
          final base = (100 / count);
          final rounded = base.round();
          controller.text = '$rounded';
        }
      }
      return controller;
    });
  }

  int get _memberCount => _members?.length ?? 0;

  double _read(String uid) =>
      double.tryParse(_valueFor(_splitType, uid).text.trim()) ?? 0;

  /// Current shares for the selected mode, or null when the inputs are
  /// not valid yet.
  Map<String, double>? _preview(List<GroupMember> members) {
    final amount = _amount;
    if (amount == null || amount <= 0 || members.isEmpty) return null;

    final uids = [for (final member in members) member.uid];

    switch (_splitType) {
      case SplitType.equal:
        return SplitCalculator.equal(amount: amount, uids: uids);

      case SplitType.ratio:
        final ratios = {for (final uid in uids) uid: _read(uid)};
        if (ratios.values.any((value) => value < 0)) return null;
        if (ratios.values.fold<double>(0, (sum, v) => sum + v) <= 0) {
          return null;
        }
        return SplitCalculator.ratio(amount: amount, ratios: ratios);

      case SplitType.percentage:
        final percentages = {for (final uid in uids) uid: _read(uid)};
        if (!SplitCalculator.percentageIsValid(percentages)) return null;
        return SplitCalculator.percentage(
          amount: amount,
          percentages: percentages,
        );

      case SplitType.custom:
        final amounts = {for (final uid in uids) uid: _read(uid)};
        if (!SplitCalculator.customIsValid(amount: amount, amounts: amounts)) {
          return null;
        }
        return SplitCalculator.custom(amounts: amounts);
    }
  }

  /// Reason shown to the user when [_preview] returns null.
  String get _splitProblem {
    final amount = _amount ?? 0;

    return switch (_splitType) {
      SplitType.equal => 'Enter an amount greater than zero',
      SplitType.ratio => 'Enter ratio values that add up to more than zero',
      SplitType.percentage => 'Percentages must add up to exactly 100%',
      SplitType.custom =>
        'Amounts must add up to ${CurrencyFormatter.format(amount)}',
    };
  }

  String _splitLabel(List<GroupMember> members) {
    switch (_splitType) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.custom:
        return 'Custom amounts';
      case SplitType.ratio:
      case SplitType.percentage:
        final uids = [for (final member in members) member.uid];
        return uids
            .map((uid) {
              final value = _valueFor(_splitType, uid).text.trim();
              final parsed = double.tryParse(value) ?? 0;
              return parsed == parsed.roundToDouble()
                  ? parsed.toInt().toString()
                  : value;
            })
            .join(':');
    }
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(value ?? '');
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// [blocContext] must be below the page's BlocProvider.
  void _save(BuildContext blocContext) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final group = blocContext.read<GroupDetailBloc>().state.group;
    final members = group?.members ?? const <GroupMember>[];
    if (members.isEmpty) {
      AppSnackbar.show(context, 'This group has no members yet.');
      return;
    }

    final shares = _preview(members);
    if (shares == null) {
      AppSnackbar.show(context, _splitProblem, type: AppSnackbarType.error);
      return;
    }

    final amount = _amount!;
    final ownUid = AuthService.currentUser?.uid ?? '';
    final paidBy =
        (members.any((m) => m.uid == _paidBy) ? _paidBy : null) ??
        (members.any((m) => m.uid == ownUid) ? ownUid : members.first.uid);

    final bloc = blocContext.read<GroupDetailBloc>();
    final title = _titleController.text.trim();
    final splitLabel = _splitLabel(members);

    final existing = widget.existing;
    if (existing != null) {
      final reason = _reasonController.text.trim();

      bloc.add(
        GroupExpenseUpdated(
          GroupExpense(
            id: existing.id,
            title: title,
            amount: amount,
            paidBy: paidBy,
            splitType: _splitType,
            shares: shares,
            splitLabel: splitLabel,
            date: _date,
            createdAt: existing.createdAt,
            createdBy: existing.createdBy,
            editedAt: DateTime.now(),
            editedBy: ownUid,
            editReason: reason,
            // Keep the amount from the first edit that changed it, so the
            // note always reads original → current.
            originalAmount:
                existing.originalAmount ??
                (existing.amount != amount ? existing.amount : null),
          ),
        ),
      );
      return;
    }

    bloc.add(
      GroupExpenseAdded(
        GroupExpense(
          id: '',
          title: title,
          amount: amount,
          paidBy: paidBy,
          splitType: _splitType,
          shares: shares,
          splitLabel: splitLabel,
          date: _date,
          createdAt: DateTime.now(),
          createdBy: ownUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<GroupDetailBloc>()..add(GroupDetailWatched(widget.groupId)),
      child: BlocConsumer<GroupDetailBloc, GroupDetailState>(
        listener: (context, state) {
          if (state.status == GroupDetailStatus.success &&
              state.message != null) {
            AppSnackbar.show(
              context,
              state.message!,
              type: AppSnackbarType.success,
            );
            // Plain Navigator pop: works whether or not a GoRouter is
            // above this page (and in tests).
            Navigator.of(context).maybePop();
          }

          if (state.status == GroupDetailStatus.failure &&
              !state.busy &&
              state.message != null) {
            AppSnackbar.show(
              context,
              state.message!,
              type: AppSnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final group = state.group;

          if (group == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: SafeArea(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              ),
            );
          }

          final members = group.members;
          _ensureControllers(members);
          _prefill(members);

          final ownUid = AuthService.currentUser?.uid;
          final paidBy = (members.isEmpty)
              ? ''
              : ((_paidBy != null && members.any((m) => m.uid == _paidBy))
                    ? _paidBy!
                    : (members.any((m) => m.uid == ownUid)
                          ? ownUid!
                          : members.first.uid));

          final preview = _preview(members);
          final isSaving = state.busy;
          final changeNote = _amountChangeNote;

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
                        Expanded(
                          child: Text(
                            _isEditing
                                ? 'Edit expense · ${group.name}'
                                : 'Add expense · ${group.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    /// Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      validator: _validateAmount,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 40,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: CurrencyFormatter.format(0),
                        hintStyle: AppTypography.displayLarge.copyWith(
                          fontSize: 40,
                          color: AppColors.textSecondary.withValues(alpha: .4),
                        ),
                        filled: false,
                        errorStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    PrimaryTextField(
                      controller: _titleController,
                      hintText: 'Title (e.g. Dinner at the beach)',
                      prefixIcon: const Icon(Icons.title_rounded),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter a title'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    /// Why the change is being made — required in edit
                    /// mode so the row can carry an audit note.
                    if (_isEditing) ...[
                      PrimaryTextField(
                        controller: _reasonController,
                        key: const Key('edit-reason-field'),
                        hintText: 'Why are you changing this? (required)',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Add a short reason for the change'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      if (changeNote != null) ...[
                        Container(
                          key: const Key('edit-amount-change'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            changeNote,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],

                    /// Date
                    _label('Date'),
                    const SizedBox(height: 8),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickDate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat.yMMMd().format(_date),
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    /// Paid by
                    _label('Paid by'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final member in members)
                          ChoiceChip(
                            selected: paidBy == member.uid,
                            onSelected: (_) =>
                                setState(() => _paidBy = member.uid),
                            label: Text(
                              member.uid == ownUid
                                  ? '${member.name} (You)'
                                  : member.name,
                            ),
                            selectedColor: AppColors.teal,
                            backgroundColor: AppColors.surface,
                            labelStyle: AppTypography.caption.copyWith(
                              color: paidBy == member.uid
                                  ? AppColors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(color: AppColors.divider),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    /// Split type
                    _label('Split'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final type in SplitType.values)
                          ChoiceChip(
                            selected: _splitType == type,
                            onSelected: (_) =>
                                setState(() => _splitType = type),
                            label: Text(type.label),
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            labelStyle: AppTypography.caption.copyWith(
                              color: _splitType == type
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(color: AppColors.divider),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ..._splitInputs(members, preview),

                    /// Preview
                    if (preview != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Each member pays',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final member in members)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        member.uid == ownUid
                                            ? '${member.name} (You)'
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
                                        preview[member.uid] ?? 0,
                                      ),
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.teal,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    PrimaryButton(
                      text: isSaving
                          ? 'Saving...'
                          : (_isEditing ? 'Save Changes' : 'Save Expense'),
                      isLoading: isSaving,
                      onPressed: isSaving ? null : () => _save(context),
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

  /// Per-mode inputs (ratio / percentage / custom amount values).
  List<Widget> _splitInputs(
    List<GroupMember> members,
    Map<String, double>? preview,
  ) {
    final ownUid = AuthService.currentUser?.uid;

    switch (_splitType) {
      case SplitType.equal:
        final amount = _amount;
        final each = preview == null ? null : (preview[members.first.uid] ?? 0);
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.call_split_rounded,
                  size: 18,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    each == null || amount == null
                        ? 'Split equally between ${members.length} '
                              '${members.length == 1 ? 'member' : 'members'}'
                        : 'Split equally — ${CurrencyFormatter.format(each)} '
                              'per person',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];

      case SplitType.ratio:
      case SplitType.percentage:
      case SplitType.custom:
        final isRatio = _splitType == SplitType.ratio;
        final isPercentage = _splitType == SplitType.percentage;

        final total = members.fold<double>(0, (sum, member) {
          return sum +
              (double.tryParse(_valueFor(_splitType, member.uid).text.trim()) ??
                  0);
        });

        String totalLabel;
        Color? totalColor;

        if (isRatio) {
          totalLabel =
              'Shares add up to '
              '${total == total.roundToDouble() ? total.toInt() : total}';
          totalColor = total > 0 ? AppColors.success : AppColors.error;
        } else if (isPercentage) {
          final ok = SplitCalculator.percentageIsValid({
            for (final member in members)
              member.uid:
                  double.tryParse(
                    _valueFor(_splitType, member.uid).text.trim(),
                  ) ??
                  0,
          });
          totalLabel =
              'Total ${_formatNumber(total)}% '
              '${ok ? '· looks good' : '· must be 100%'}';
          totalColor = ok ? AppColors.success : AppColors.error;
        } else {
          final amount = _amount ?? 0;
          final ok = SplitCalculator.customIsValid(
            amount: amount,
            amounts: {
              for (final member in members)
                member.uid:
                    double.tryParse(
                      _valueFor(_splitType, member.uid).text.trim(),
                    ) ??
                    0,
            },
          );
          totalLabel =
              'Total ${CurrencyFormatter.format(total)} of '
              '${CurrencyFormatter.format(amount)} '
              '${ok ? '· looks good' : '· must match'}';
          totalColor = ok ? AppColors.success : AppColors.error;
        }

        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRatio
                      ? 'Enter the ratio each member pays'
                      : isPercentage
                      ? 'Enter each member’s percentage'
                      : 'Enter each member’s share',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final member in members) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.uid == ownUid
                              ? '${member.name} (You)'
                              : member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: PrimaryTextField(
                          controller: _valueFor(_splitType, member.uid),
                          hintText: isRatio
                              ? '1'
                              : isPercentage
                              ? '0%'
                              : CurrencyFormatter.format(0),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (member != members.last) const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isRatio ? Icons.tag_rounded : Icons.percent_rounded,
                      size: 14,
                      color: totalColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      totalLabel,
                      style: AppTypography.caption.copyWith(
                        color: totalColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
    }
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
