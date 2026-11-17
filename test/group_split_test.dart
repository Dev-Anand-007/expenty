import 'package:expenty/features/groups/domain/entities/group.dart';
import 'package:expenty/features/groups/domain/group_balances.dart';
import 'package:expenty/features/groups/domain/split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = 'uid-a';
  const b = 'uid-b';
  const c = 'uid-c';

  final members = const [
    GroupMember(uid: a, name: 'Anand', email: 'a@x.com'),
    GroupMember(uid: b, name: 'Rahul', email: 'b@x.com'),
    GroupMember(uid: c, name: 'Zoe', email: 'c@x.com'),
  ];

  double sum(Map<String, double> shares) =>
      shares.values.fold<double>(0, (total, v) => total + v);

  group('SplitCalculator.equal', () {
    test('splits three ways evenly', () {
      final shares = SplitCalculator.equal(amount: 900, uids: const [a, b, c]);

      expect(shares[a], 300);
      expect(shares[b], 300);
      expect(shares[c], 300);
      expect(sum(shares), 900);
    });

    test('handles remainder paise without losing money', () {
      final shares = SplitCalculator.equal(amount: 100, uids: const [a, b, c]);

      expect(sum(shares), 100);
      expect(shares.values.every((v) => v > 0), isTrue);
    });

    test('single member pays it all', () {
      final shares = SplitCalculator.equal(amount: 250, uids: const [a]);
      expect(shares, {a: 250});
    });
  });

  group('SplitCalculator.ratio', () {
    test('splits 2:1:1', () {
      final shares = SplitCalculator.ratio(
        amount: 400,
        ratios: {a: 2, b: 1, c: 1},
      );

      expect(shares[a], 200);
      expect(shares[b], 100);
      expect(shares[c], 100);
      expect(sum(shares), 400);
    });

    test('rejects all-zero ratios', () {
      final shares = SplitCalculator.ratio(amount: 400, ratios: {a: 0, b: 0});
      expect(shares, isEmpty);
    });
  });

  group('SplitCalculator.percentage', () {
    test('splits 50/30/20', () {
      final shares = SplitCalculator.percentage(
        amount: 1000,
        percentages: {a: 50, b: 30, c: 20},
      );

      expect(shares[a], 500);
      expect(shares[b], 300);
      expect(shares[c], 200);
      expect(sum(shares), 1000);
    });

    test('validates that percentages total 100', () {
      expect(SplitCalculator.percentageIsValid({a: 50, b: 40, c: 10}), isTrue);
      expect(SplitCalculator.percentageIsValid({a: 50, b: 40, c: 5}), isFalse);
    });

    test('reconciles rounding so shares still total the amount', () {
      final shares = SplitCalculator.percentage(
        amount: 100,
        percentages: {a: 33.33, b: 33.33, c: 33.34},
      );

      expect(sum(shares), 100);
    });
  });

  group('SplitCalculator.custom', () {
    test('accepts explicit amounts that total the expense', () {
      expect(
        SplitCalculator.customIsValid(amount: 750, amounts: {a: 500, b: 250}),
        isTrue,
      );
      expect(
        SplitCalculator.customIsValid(amount: 750, amounts: {a: 500, b: 200}),
        isFalse,
      );
    });
  });

  group('GroupBalances', () {
    test('payer is credited, everyone is debited their share', () {
      final balances = GroupBalances.applyExpense(
        GroupBalances.zero(members),
        paidBy: a,
        amount: 300,
        shares: {a: 100, b: 100, c: 100},
      );

      expect(balances[a], 200); // paid 300, owed 100
      expect(balances[b], -100);
      expect(balances[c], -100);
    });

    test('undo restores the original balances', () {
      final before = GroupBalances.zero(members);
      final shares = {a: 100.0, b: 100.0, c: 100.0};

      final applied = GroupBalances.applyExpense(
        before,
        paidBy: a,
        amount: 300,
        shares: shares,
      );
      final undone = GroupBalances.undoExpense(
        applied,
        paidBy: a,
        amount: 300,
        shares: shares,
      );

      expect(undone, before);
    });

    test('members owe and are owed across multiple expenses', () {
      var balances = GroupBalances.zero(members);

      balances = GroupBalances.applyExpense(
        balances,
        paidBy: a,
        amount: 300,
        shares: {a: 100, b: 100, c: 100},
      );
      balances = GroupBalances.applyExpense(
        balances,
        paidBy: b,
        amount: 60,
        shares: {a: 30, b: 15, c: 15},
      );

      expect(balances[a], 170); // 200 − 30
      expect(balances[b], -55); // −100 + 60 − 15
      expect(balances[c], -115); // −100 − 15

      final group = Group(
        id: 'g1',
        name: 'Goa trip',
        createdBy: a,
        createdAt: DateTime(2026, 11, 1),
        members: members,
        memberBalances: balances,
      );

      final nets = GroupBalances.nets(group);
      expect(nets.first.member.uid, c); // most negative first
      expect(nets.first.mustPay, 115);
      expect(nets.last.isOwed, 170);
      expect(nets.where((n) => n.isSettled), isEmpty);
    });

    test('aggregates a member totals across groups', () {
      Group groupWith(Map<String, double> balances) => Group(
        id: 'g',
        name: 'g',
        createdBy: a,
        createdAt: DateTime(2026, 11, 1),
        members: members,
        memberBalances: balances,
      );

      final totals = GroupBalances.totals([
        groupWith({a: -200, b: 200, c: 0}),
        groupWith({a: 350, b: -150, c: -200}),
      ], a);

      expect(totals.owes, 200);
      expect(totals.owed, 350);
      expect(totals.isZero, isFalse);
    });
  });
}
