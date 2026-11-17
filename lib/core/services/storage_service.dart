import 'package:shared_preferences/shared_preferences.dart';

/// Thin static wrapper over [SharedPreferences] for app-level preferences
/// (appearance, currency, notification toggles).
///
/// Call [init] once in `main()` before `runApp`. Every getter is null-safe so
/// widget tests (where `init` was never called) fall back to defaults.
class StorageService {
  StorageService._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------- appearance
  static const _kDarkMode = 'isDarkMode';

  static bool get isDarkMode => _prefs?.getBool(_kDarkMode) ?? false;

  static Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool(_kDarkMode, value);
  }

  // ------------------------------------------------------------------ currency
  static const defaultCurrencySymbol = '₹';
  static const _kCurrencySymbol = 'currencySymbol';

  static String get currencySymbol =>
      _prefs?.getString(_kCurrencySymbol) ?? defaultCurrencySymbol;

  static Future<void> setCurrencySymbol(String value) async {
    await _prefs?.setString(_kCurrencySymbol, value);
  }

  // -------------------------------------------------------------- notifications
  static const _kNotifyTransactions = 'notifyTransactions';
  static const _kNotifyGroups = 'notifyGroups';

  static bool get notifyTransactions =>
      _prefs?.getBool(_kNotifyTransactions) ?? true;

  static Future<void> setNotifyTransactions(bool value) async {
    await _prefs?.setBool(_kNotifyTransactions, value);
  }

  static bool get notifyGroups => _prefs?.getBool(_kNotifyGroups) ?? true;

  static Future<void> setNotifyGroups(bool value) async {
    await _prefs?.setBool(_kNotifyGroups, value);
  }
}
