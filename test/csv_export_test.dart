import 'package:expenty/core/utils/csv_builder.dart';
import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/entities/group_expense.dart';
import 'package:expenty/features/groups/domain/group_expense_csv.dart';
import 'package:expenty/features/transactions/domain/entities/money_transaction.dart';
import 'package:expenty/features/transactions/domain/transaction_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvBuilder', () {
    test('passes plain fields through untouched', () {
      expect(CsvBuilder.escape('Dinner'), 'Dinner');
      expect(CsvBuilder.escape(''), '');
    });

    test('quotes commas, doubles quotes, wraps newlines', () {
      expect(CsvBuilder.escape('a,b'), '"a,b"');
      expect(CsvBuilder.escape('say "hi"'), '"say ""hi"""');
      expect(CsvBuilder.escape('line1\nline2'), '"line1\nline2"');
    });

    test('joins header and rows with CRLF', () {
      final csv = CsvBuilder.build([
        'A',
        'B',
      ], [
        ['1', '2'],
        ['3', '4'],
      ]);

      expect(csv, 'A,B\r\n1,2\r\n3,4');
    });
  });

  group('TransactionCsv', () {
    MoneyTransaction tx({
      required String title,
      required double amount,
      required TransactionType type,
      required String category,
      required DateTime date,
      String note = '',
    }) => MoneyTransaction(
      id: title,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: note,
      createdAt: date,
    );

    test('one row per transaction in the order given', () {
      final csv = TransactionCsv.toCsv([
        tx(
          title: 'Salary',
          amount: 50000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(2026, 11, 1),
        ),
        tx(
          title: 'Dinner, out',
          amount: 450.5,
          type: TransactionType.expense,
          category: 'Dining',
          date: DateTime(2026, 11, 7),
          note: 'with "friends"',
        ),
      ]);

      final lines = csv.split('\r\n');
      expect(lines, hasLength(3));
      expect(lines[0], 'Date,Description,Category,Type,Amount,Net,Note');
      expect(lines[1], '2026-11-01,Salary,Salary,Income,50000.00,+50000.00,');
      expect(
        lines[2],
        '2026-11-07,"Dinner, out",Dining,Expense,450.50,-450.50,'
        '"with ""friends"""',
      );
    });

    test('amounts are plain numbers a spreadsheet can sum', () {
      final csv = TransactionCsv.toCsv([
        tx(
          title: 'Chai',
          amount: 40,
          type: TransactionType.expense,
          category: 'Dining',
          date: DateTime(2026, 11, 7),
        ),
      ]);

      // Positive Amount for SUMIFS on Type, signed Net so =SUM is the
      // net change.
      expect(csv, contains(',Expense,40.00,-40.00,'));
      expect(csv, isNot(contains('₹')));
    });
  });

  group('GroupExpenseCsv', () {
    final group = Group(
      id: 'g1',
      name: 'Goa trip',
      createdBy: 'u1',
      createdAt: DateTime(2026, 11, 1),
      members: const [
        GroupMember(uid: 'u1', name: 'Anand', email: 'anand@x.com'),
        GroupMember(uid: 'u2', name: 'Rahul', email: 'rahul@x.com'),
      ],
      memberBalances: const {},
    );

    GroupExpense expense({
      required String title,
      required double amount,
      required String paidBy,
      required DateTime date,
      String createdBy = 'u1',
    }) => GroupExpense(
      id: title,
      title: title,
      amount: amount,
      paidBy: paidBy,
      splitType: SplitType.equal,
      shares: const {'u1': 300, 'u2': 300},
      splitLabel: 'Equal',
      date: date,
      createdAt: date,
      createdBy: createdBy,
    );

    test('resolves member names for payer and shares', () {
      final csv = GroupExpenseCsv.toCsv(
        group: group,
        expenses: [
          expense(
            title: 'Dinner',
            amount: 600,
            paidBy: 'u1',
            date: DateTime(2026, 11, 7),
          ),
        ],
      );

      final lines = csv.split('\r\n');
      expect(lines, hasLength(2));
      expect(lines[0], 'Date,Description,Paid by,Amount,Split,Anand,Rahul');
      expect(lines[1], '2026-11-07,Dinner,Anand,600.00,Equal,300.00,300.00');
    });

    test('member columns follow the roster, then split-only extras', () {
      final csv = GroupExpenseCsv.toCsv(
        group: group,
        expenses: [
          GroupExpense(
            id: 'e1',
            title: 'Taxi',
            amount: 100,
            paidBy: 'ghost',
            splitType: SplitType.equal,
            shares: const {'u1': 30, 'ghost1': 35, 'ghost2': 35},
            splitLabel: 'Custom',
            date: DateTime(2026, 11, 7),
            createdAt: DateTime(2026, 11, 7),
            createdBy: 'u1',
          ),
        ],
      );

      final lines = csv.split('\r\n');
      // Roster first (Anand, Rahul), then unknown split-only members with
      // deduplicated labels; Anand's empty share cell stays empty.
      expect(
        lines[0],
        'Date,Description,Paid by,Amount,Split,Anand,Rahul,Unknown,'
        'Unknown (2)',
      );
      expect(
        lines[1],
        '2026-11-07,Taxi,Unknown,100.00,Custom,30.00,,35.00,35.00',
      );
    });

    test('rows come out oldest first', () {
      final csv = GroupExpenseCsv.toCsv(
        group: group,
        expenses: [
          expense(
            title: 'Newer',
            amount: 100,
            paidBy: 'u2',
            date: DateTime(2026, 11, 9),
          ),
          expense(
            title: 'Older',
            amount: 200,
            paidBy: 'u1',
            date: DateTime(2026, 11, 2),
          ),
        ],
      );

      final lines = csv.split('\r\n');
      expect(lines[1], startsWith('2026-11-02,Older'));
      expect(lines[2], startsWith('2026-11-09,Newer'));
    });
  });
}
