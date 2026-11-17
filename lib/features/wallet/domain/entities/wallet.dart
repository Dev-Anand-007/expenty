/// Money the user has added to their wallet.
///
/// Kept separate from income/expense transactions: the displayed
/// Total Balance = [balance] + income − expenses.
class Wallet {
  final double balance;
  final DateTime? updatedAt;

  const Wallet({
    required this.balance,
    this.updatedAt,
  });
}
