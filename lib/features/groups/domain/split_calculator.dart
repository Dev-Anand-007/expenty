/// Pure split maths. All results are rounded to paise (2 decimals).
class SplitCalculator {
  SplitCalculator._();

  /// 1:1:1 — any remainder paise go to the first members, so shares always
  /// add up to exactly [amount].
  static Map<String, double> equal({
    required double amount,
    required List<String> uids,
  }) {
    if (uids.isEmpty) return const {};
    if (uids.length == 1) return {uids.first: round(amount)};

    final cents = (amount * 100).round();
    final base = cents ~/ uids.length;
    final remainder = cents - base * uids.length;

    return {
      for (var i = 0; i < uids.length; i++)
        uids[i]: (base + (i < remainder ? 1 : 0)) / 100,
    };
  }

  /// e.g. ratios {a:2, b:1, c:1} → 50% / 25% / 25%.
  static Map<String, double> ratio({
    required double amount,
    required Map<String, double> ratios,
  }) {
    final total = ratios.values.fold<double>(0, (sum, r) => sum + r);
    if (total <= 0) return const {};

    final raw = ratios.map((uid, r) => MapEntry(uid, amount * r / total));
    return _reconcile(raw, amount);
  }

  /// Percentages must total 100 (validated by [percentageIsValid]).
  static Map<String, double> percentage({
    required double amount,
    required Map<String, double> percentages,
  }) {
    final raw = percentages.map((uid, p) => MapEntry(uid, amount * p / 100));
    return _reconcile(raw, amount);
  }

  /// Explicit amounts per member — must already total [amount].
  static Map<String, double> custom({required Map<String, double> amounts}) {
    return amounts.map((uid, value) => MapEntry(uid, round(value)));
  }

  static bool percentageIsValid(Map<String, double> percentages) {
    final total = percentages.values.fold<double>(0, (sum, p) => sum + p);
    return (total - 100).abs() < 0.01;
  }

  static bool customIsValid({
    required double amount,
    required Map<String, double> amounts,
  }) {
    final total = amounts.values.fold<double>(0, (sum, v) => sum + v);
    return (total - amount).abs() < 0.01;
  }

  static double round(double value) => (value * 100).roundToDouble() / 100;

  /// Rounding fix-up: gives leftover paise to the largest share so the
  /// shares sum exactly to the expense amount.
  static Map<String, double> _reconcile(
    Map<String, double> raw,
    double amount,
  ) {
    if (raw.isEmpty) return const {};

    final rounded = raw.map((uid, value) => MapEntry(uid, round(value)));
    final total = rounded.values.fold<double>(0, (sum, v) => sum + v);
    final diff = round(amount - total);

    if (diff != 0) {
      final biggest = rounded.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      rounded[biggest.key] = round(biggest.value + diff);
    }

    return rounded;
  }
}
