import 'package:pdf/widgets.dart' as pw;

import '../../../core/export/export_pdf.dart';
import 'entities/group.dart';
import 'entities/group_expense.dart';
import 'group_expense_csv.dart';

/// PDF twin of [GroupExpenseCsv]: the same columns and rows — including
/// the per-member share columns — laid out for reading and printing.
class GroupExpensePdf {
  GroupExpensePdf._();

  static Future<pw.Document> build({
    required Group group,
    required List<GroupExpense> expenses,
  }) async {
    final count = expenses.length;
    final subtitle =
        '$count ${count == 1 ? 'expense' : 'expenses'} · '
        'Generated ${GroupExpenseCsv.date(DateTime.now())}';
    final headers = GroupExpenseCsv.headersFor(group, expenses);

    // Amount sits at index 3; member share columns start at index 5.
    return buildExportPdf(
      title: group.name,
      subtitle: subtitle,
      headers: headers,
      rows: GroupExpenseCsv.toRows(group: group, expenses: expenses),
      rightAlign: {
        3,
        for (var i = 5; i < headers.length; i++) i,
      },
      columnWeights: [
        1.1,
        1.9,
        1.3,
        1.0,
        1.1,
        for (var i = 5; i < headers.length; i++) 0.9,
      ],
    );
  }
}
