import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/entities/group_expense.dart';
import 'package:expenty/features/groups/domain/group_expense_pdf.dart';
import 'package:expenty/features/transactions/domain/entities/money_transaction.dart';
import 'package:expenty/features/transactions/domain/transaction_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The exporter reads the bundled Roboto through rootBundle, which needs
  // the test binding (widget tests already have it; plain `test()` bodies
  // do not).
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('TransactionPdf', () {
    test('produces a real PDF document', () async {
      final bytes = await (await TransactionPdf.build([
        tx(
          title: 'Salary',
          amount: 50000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(2026, 11, 1),
        ),
        tx(
          title: 'Dinner',
          amount: 450.5,
          type: TransactionType.expense,
          category: 'Dining',
          date: DateTime(2026, 11, 7),
          note: 'with friends',
        ),
      ])).save();

      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
      expect(bytes.length, greaterThan(1000));
    });

    test('an empty activity still produces a valid document', () async {
      final bytes = await (await TransactionPdf.build([])).save();

      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('long lists paginate instead of overflowing', () async {
      final transactions = [
        for (var i = 0; i < 200; i++)
          tx(
            title: 'Transaction $i',
            amount: i + 0.5,
            type: i.isEven ? TransactionType.expense : TransactionType.income,
            category: 'General',
            date: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
      ];

      final bytes = await (await TransactionPdf.build(transactions)).save();

      // The pdf package splits tables across pages; a broken spanning
      // implementation would hang or throw here.
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
      expect(bytes.length, greaterThan(5000));
    });

    test('embeds a Unicode font so ₹ and dashes are not dropped', () async {
      final bytes = await (await TransactionPdf.build([
        tx(
          title: 'Rent — ₹1,250 (H1)',
          amount: 1250,
          type: TransactionType.expense,
          category: 'Housing',
          date: DateTime(2026, 11, 7),
          note: 'café “share”',
        ),
      ])).save();

      // Helvetica is WinAnsi-only and silently drops everything outside
      // Latin-1 — the rupee sign, em dashes, curly quotes; the bundled
      // Roboto must be the font actually embedded.
      expect(String.fromCharCodes(bytes), contains('Roboto'));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });

  group('GroupExpensePdf', () {
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

    test('produces a real PDF document', () async {
      final bytes = await (await GroupExpensePdf.build(
        group: group,
        expenses: [
          GroupExpense(
            id: 'e1',
            title: 'Dinner',
            amount: 600,
            paidBy: 'u1',
            splitType: SplitType.equal,
            shares: const {'u1': 300, 'u2': 300},
            splitLabel: 'Equal',
            date: DateTime(2026, 11, 7),
            createdAt: DateTime(2026, 11, 7),
            createdBy: 'u1',
          ),
        ],
      )).save();

      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
      expect(bytes.length, greaterThan(1000));
    });
  });
}
