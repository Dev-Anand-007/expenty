import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/csv_builder.dart';
import 'entities/group.dart';
import 'entities/group_expense.dart';

/// CSV export of a group's expenses — one row per expense, oldest first.
///
/// After the fixed fields there is **one numeric column per member**
/// (roster order), so `=SUM(Anand:Anand)` totals what a person was
/// charged and `=SUMIFS(…, "Paid by", "Anand")` finds what they paid.
class GroupExpenseCsv {
  GroupExpenseCsv._();

  static const fixedHeaders = ['Date', 'Description', 'Paid by', 'Amount', 'Split'];

  static List<String> headersFor(
    Group group,
    List<GroupExpense> expenses,
  ) => [...fixedHeaders, ..._columns(group, expenses).map((c) => c.label)];

  static String toCsv({
    required Group group,
    required List<GroupExpense> expenses,
  }) {
    return CsvBuilder.build(
      headersFor(group, expenses),
      toRows(group: group, expenses: expenses),
    );
  }

  /// Shared with the PDF twin so both exports carry identical rows.
  static List<List<String>> toRows({
    required Group group,
    required List<GroupExpense> expenses,
  }) {
    final columns = _columns(group, expenses);
    final names = {
      for (final member in group.members) member.uid: member.name,
    };
    String nameOf(String uid) => names[uid] ?? 'Unknown';

    final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));

    return [
      for (final expense in sorted)
        [
          date(expense.date),
          expense.title,
          nameOf(expense.paidBy),
          CurrencyFormatter.plain(expense.amount),
          expense.splitLabel,
          for (final column in columns) shareCell(expense, column.uid),
        ],
    ];
  }

  /// The member's share for that row — empty when they weren't charged.
  static String shareCell(GroupExpense expense, String uid) {
    final share = expense.shares[uid];
    if (share == null) return '';
    return CurrencyFormatter.plain(share);
  }

  static String date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// The member columns: current roster first (group order), then anyone
  /// who only shows up in older expenses' splits. Duplicate display names
  /// get a numeric suffix so every column stays distinct.
  static List<_MemberColumn> _columns(
    Group group,
    List<GroupExpense> expenses,
  ) {
    final byUid = <String, _MemberColumn>{};
    final usedLabels = <String>{};

    String uniqueLabel(String raw) {
      var label = raw;
      var suffix = 2;
      while (usedLabels.contains(label)) {
        label = '$raw ($suffix)';
        suffix++;
      }
      usedLabels.add(label);
      return label;
    }

    void add(String uid, String rawLabel) {
      if (byUid.containsKey(uid)) return;
      byUid[uid] = _MemberColumn(uid, uniqueLabel(rawLabel));
    }

    for (final member in group.members) {
      add(member.uid, member.name.isEmpty ? 'Unknown' : member.name);
    }
    for (final expense in expenses) {
      for (final uid in expense.shares.keys) {
        add(uid, 'Unknown');
      }
    }

    return byUid.values.toList();
  }
}

class _MemberColumn {
  final String uid;
  final String label;

  const _MemberColumn(this.uid, this.label);
}
