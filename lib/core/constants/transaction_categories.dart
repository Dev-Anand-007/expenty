import 'package:flutter/material.dart';

/// A spendable category shown on chips and top-expense cards.
class TransactionCategory {
  final String name;
  final Color color;
  final IconData icon;

  const TransactionCategory(this.name, this.color, this.icon);
}

class TransactionCategories {
  TransactionCategories._();

  static const list = <TransactionCategory>[
    TransactionCategory(
      'Groceries',
      Color(0xFFF08C1E),
      Icons.local_grocery_store_outlined,
    ),
    TransactionCategory(
      'Car',
      Color(0xFF2E9C7E),
      Icons.directions_car_outlined,
    ),
    TransactionCategory(
      'Phone',
      Color(0xFF2F6BD9),
      Icons.phone_iphone_outlined,
    ),
    TransactionCategory(
      'Shopping',
      Color(0xFF865A9A),
      Icons.shopping_bag_outlined,
    ),
    TransactionCategory(
      'Dining',
      Color(0xFFEF8767),
      Icons.restaurant_outlined,
    ),
    TransactionCategory(
      'Clothes',
      Color(0xFFB4508C),
      Icons.checkroom_outlined,
    ),
    TransactionCategory(
      'House',
      Color(0xFF4A6FA5),
      Icons.home_outlined,
    ),
    TransactionCategory(
      'Salary',
      Color(0xFF2DBE7F),
      Icons.payments_outlined,
    ),
    TransactionCategory(
      'Freelance',
      Color(0xFF6C63FF),
      Icons.laptop_mac_outlined,
    ),
    TransactionCategory(
      'Other',
      Color(0xFF8A8A8A),
      Icons.category_outlined,
    ),
  ];

  static TransactionCategory byName(String name) {
    if (name == walletTopUp.name) return walletTopUp;
    for (final category in list) {
      if (category.name == name) return category;
    }
    return list.last;
  }

  /// Wallet top-ups are written automatically by the dashboard's
  /// "Add balance" flow, so their rows are read-only in Activity.
  static bool isWalletTopUp(String category) => category == walletTopUp.name;

  /// Special category for wallet top-ups made from the dashboard's quick
  /// "Add balance" sheet.
  ///
  /// Deliberately *not* part of [list], so it can't be picked in the
  /// add-transaction form.
  static const walletTopUp = TransactionCategory(
    'Wallet top-up',
    Color(0xFF152A5E),
    Icons.account_balance_wallet_outlined,
  );
}
