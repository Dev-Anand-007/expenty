import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/csv_builder.dart';
import 'entities/money_transaction.dart';

/// CSV export of the Activity list — one row per transaction, in the
/// order the caller passes them (the Activity tab sorts newest first).
///
/// [Net] is the signed amount (+ income / − expense) so a plain `=SUM`
/// over the column gives the net change; [Amount] stays positive for
/// `=SUMIFS(…, Type, "Expense")`.
class TransactionCsv {
  TransactionCsv._();

  static const headers = [
    'Date',
    'Description',
    'Category',
    'Type',
    'Amount',
    'Net',
    'Note',
  ];

  static String toCsv(List<MoneyTransaction> transactions) =>
      CsvBuilder.build(headers, toRows(transactions));

  /// Shared with the PDF twin so both exports carry identical rows.
  static List<List<String>> toRows(List<MoneyTransaction> transactions) {
    return [
      for (final transaction in transactions)
        [
          date(transaction.date),
          transaction.title,
          transaction.category,
          transaction.isIncome ? 'Income' : 'Expense',
          CurrencyFormatter.plain(transaction.amount),
          net(transaction),
          transaction.note,
        ],
    ];
  }

  /// Signed amount: `+50000.00` for income, `-450.50` for expense.
  static String net(MoneyTransaction transaction) {
    final sign = transaction.isIncome ? '+' : '-';
    return '$sign${CurrencyFormatter.plain(transaction.amount)}';
  }

  static String date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
