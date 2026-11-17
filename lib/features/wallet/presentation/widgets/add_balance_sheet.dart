import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/primary_text_field.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';

/// Bottom sheet for topping up the wallet.
///
/// [context] must sit *below* the WalletBloc provider (the dashboard's
/// MultiBlocProvider does) — the bloc is captured before the sheet is
/// pushed onto the navigator.
///
/// The form itself is a StatefulWidget so the controller is disposed by
/// its own [State.dispose] — i.e. exactly when the sheet really leaves the
/// tree. Disposing it "when the future completes" is too early: the sheet
/// still rebuilds during its exit animation and would hit a disposed
/// controller.
Future<void> showAddBalanceSheet(BuildContext context) {
  final bloc = context.read<WalletBloc>();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _AddBalanceSheet(bloc: bloc),
  );
}

class _AddBalanceSheet extends StatefulWidget {
  final WalletBloc bloc;

  const _AddBalanceSheet({required this.bloc});

  @override
  State<_AddBalanceSheet> createState() => _AddBalanceSheetState();
}

class _AddBalanceSheetState extends State<_AddBalanceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.parse(_controller.text.trim());
    widget.bloc.add(BalanceAdded(amount));

    // `context` here is this sheet's own element: still mounted at this
    // point (the pop is animated), so the bloc/messenger lookups are safe.
    Navigator.of(context).pop();
    AppSnackbar.show(
      context,
      'Added ${CurrencyFormatter.format(amount)} to your wallet',
      type: AppSnackbarType.success,
    );
  }

  void _quickPick(double amount) {
    _controller.text = amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add balance',
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Money you have in hand, bank or UPI — it's added to your "
              'total balance, recorded as income in Activity, and spent '
              "down as you track expenses.",
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryTextField(
              controller: _controller,
              hintText: CurrencyFormatter.format(0),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: const Icon(Icons.currency_rupee_rounded),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final amount in const <double>[500, 1000, 2000, 5000])
                  ActionChip(
                    label: Text(CurrencyFormatter.format(amount)),
                    backgroundColor: AppColors.background,
                    side: BorderSide(color: AppColors.divider),
                    onPressed: () => _quickPick(amount),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Add Balance',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
