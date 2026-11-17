import 'package:pdf/widgets.dart' as pw;

import '../../../core/export/export_pdf.dart';
import 'entities/money_transaction.dart';
import 'transaction_csv.dart';

/// PDF twin of [TransactionCsv]: the same columns and rows, laid out for
/// reading and printing instead of number crunching.
class TransactionPdf {
  TransactionPdf._();

  static Future<pw.Document> build(
    List<MoneyTransaction> transactions,
  ) async {
    final count = transactions.length;
    final subtitle =
        '$count ${count == 1 ? 'transaction' : 'transactions'} · '
        'Generated ${TransactionCsv.date(DateTime.now())}';

    return buildExportPdf(
      title: 'Activity',
      subtitle: subtitle,
      headers: TransactionCsv.headers,
      rows: TransactionCsv.toRows(transactions),
      rightAlign: {4, 5},
      columnWeights: const [1.0, 1.8, 1.3, 0.9, 1.1, 1.1, 1.7],
    );
  }
}
