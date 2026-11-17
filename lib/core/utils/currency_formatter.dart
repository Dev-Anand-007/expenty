import 'package:intl/intl.dart';

import '../services/storage_service.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String _lastSymbol = '';
  static NumberFormat? _formatter;

  /// Formats using the symbol picked in Settings (defaults to ₹).
  static String format(num amount) {
    final symbol = StorageService.currencySymbol;

    if (_formatter == null || symbol != _lastSymbol) {
      _lastSymbol = symbol;
      _formatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: symbol,
        decimalDigits: 2,
      );
    }

    return _formatter!.format(amount);
  }

  /// Plain decimal without the currency symbol — for CSV exports, where
  /// spreadsheets should see a number they can sum.
  static String plain(num amount) => amount.toStringAsFixed(2);
}
