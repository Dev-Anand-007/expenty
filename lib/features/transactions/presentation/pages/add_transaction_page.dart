import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/primary_text_field.dart';
import '../../domain/entities/money_transaction.dart';
import '../bloc/transactions_bloc.dart';
import '../bloc/transactions_event.dart';
import '../bloc/transactions_state.dart';

class AddTransactionPage extends StatefulWidget {
  /// When provided, the page edits this transaction instead of creating one.
  final MoneyTransaction? existing;

  const AddTransactionPage({super.key, this.existing});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _category = TransactionCategories.list.first.name;
  DateTime _date = DateTime.now();

  bool get _isEditing => widget.existing != null;

  /// Wallet top-ups are owned by the wallet flow — never editable here.
  bool get _isLocked =>
      _isEditing &&
      TransactionCategories.isWalletTopUp(widget.existing!.category);

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = existing.amount.toStringAsFixed(
        existing.amount == existing.amount.roundToDouble() ? 0 : 2,
      );
      _titleController.text = existing.title;
      _noteController.text = existing.note;
      _type = existing.type;
      _category = existing.category;
      _date = existing.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(value ?? '');
    if (amount == null || amount <= 0) {
      return 'Enter a valid amount';
    }
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

  /// [blocContext] must be a context *below* the page's BlocProvider —
  /// this State's own context sits above it and cannot read the bloc.
  void _save(BuildContext blocContext) {
    // Belt and braces: the Activity sheet hides edit for wallet top-ups,
    // but the route can be pushed directly.
    if (_isLocked) {
      AppSnackbar.show(
        blocContext,
        "Wallet top-ups can't be edited",
        type: AppSnackbarType.error,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final transaction = MoneyTransaction(
      id: widget.existing?.id ?? '',
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      type: _type,
      category: _category,
      date: _date,
      note: _noteController.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    blocContext.read<TransactionsBloc>().add(
          _isEditing
              ? TransactionUpdated(transaction)
              : TransactionAdded(transaction),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransactionsBloc>(),
      child: BlocConsumer<TransactionsBloc, TransactionsState>(
        listener: (context, state) {
          if (state.status == TransactionsStatus.success) {
            AppSnackbar.show(
              context,
              state.message ??
                  (_isEditing ? 'Transaction updated.' : 'Transaction added.'),
              type: AppSnackbarType.success,
            );

            // Editing was pushed from the Activity list — go straight back
            // so the user lands on the same tab they started from.
            if (_isEditing && context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.dashboard);
            }
          }

          if (state.status == TransactionsStatus.failure) {
            AppSnackbar.show(
              context,
              state.message ?? 'Something went wrong',
              type: AppSnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final isSaving = state.status == TransactionsStatus.loading;

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
                          _isEditing ? 'Edit Transaction' : 'Add Transaction',
                          style: AppTypography.title.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// Read-only notice for auto-generated wallet top-ups.
                    if (_isLocked)
                      Container(
                        key: const Key('edit-locked-banner'),
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This wallet top-up is read-only. It was '
                                'recorded when you added balance — go back '
                                'to Activity to delete it instead.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    /// Type toggle
                    Row(
                      children: [
                        _typeButton(
                          label: 'Expense',
                          selected: _type == TransactionType.expense,
                          color: AppColors.error,
                          enabled: !_isLocked,
                          onTap: () => setState(
                            () => _type = TransactionType.expense,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _typeButton(
                          label: 'Income',
                          selected: _type == TransactionType.income,
                          color: AppColors.success,
                          enabled: !_isLocked,
                          onTap: () => setState(
                            () => _type = TransactionType.income,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    /// Amount
                    TextFormField(
                      controller: _amountController,
                      enabled: !_isLocked,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      validator: _validateAmount,
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
                      hintText: 'Title (e.g. Weekly groceries)',
                      prefixIcon: const Icon(Icons.title_rounded),
                      enabled: !_isLocked,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Enter a title'
                              : null,
                    ),

                    const SizedBox(height: 20),

                    /// Date
                    _label('Date'),
                    const SizedBox(height: 8),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isLocked ? null : _pickDate,
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

                    const SizedBox(height: 20),

                    /// Category
                    _label('Category'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final category in TransactionCategories.list)
                          ChoiceChip(
                            selected: _category == category.name,
                            onSelected: _isLocked
                                ? null
                                : (_) => setState(
                                      () => _category = category.name,
                                    ),
                            avatar: Icon(
                              category.icon,
                              size: 16,
                              color: _category == category.name
                                  ? AppColors.white
                                  : category.color,
                            ),
                            label: Text(category.name),
                            selectedColor: category.color,
                            backgroundColor: AppColors.surface,
                            labelStyle: AppTypography.caption.copyWith(
                              color: _category == category.name
                                  ? AppColors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: AppColors.divider,
                            ),
                            showCheckmark: false,
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    PrimaryTextField(
                      controller: _noteController,
                      hintText: 'Note (optional)',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      enabled: !_isLocked,
                    ),

                    const SizedBox(height: 32),

                    PrimaryButton(
                      text: isSaving
                          ? 'Saving...'
                          : _isLocked
                              ? 'Editing disabled'
                              : _isEditing
                                  ? 'Save Changes'
                                  : 'Save Transaction',
                      isLoading: isSaving,
                      // `context` here is the BlocConsumer's builder context,
                      // which lives below the BlocProvider.
                      onPressed:
                          (isSaving || _isLocked) ? null : () => _save(context),
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

  Widget _label(String text) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _typeButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? color
                : enabled
                    ? AppColors.surface
                    : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.button.copyWith(
              fontSize: 15,
              color: selected
                  ? AppColors.white
                  : enabled
                      ? AppColors.textSecondary
                      : AppColors.textSecondary.withValues(alpha: .5),
            ),
          ),
        ),
      ),
    );
  }
}
