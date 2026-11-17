/// Validation rules for the public `@username` handle.
class UsernameRules {
  UsernameRules._();

  /// 3–20 chars, starts and ends with a letter or digit,
  /// letters/numbers/`.`/`_ in between.
  static final _pattern = RegExp(r'^[a-z0-9][a-z0-9._]{1,18}[a-z0-9]$');

  /// Handles that must stay under our control.
  static const reserved = [
    'admin',
    'administrator',
    'expenty',
    'official',
    'support',
    'help',
    'root',
    'system',
    'user',
    'me',
  ];

  /// Returns an error message, or `null` when [value] is acceptable.
  /// The value is normalised to lowercase before checking.
  static String? validate(String value) {
    final handle = value.trim().toLowerCase();

    if (handle.length < 3) return 'Usernames need at least 3 characters';
    if (handle.length > 20) return 'Usernames can be at most 20 characters';
    if (!_pattern.hasMatch(handle)) {
      return 'Use letters, numbers, . and _ — must start and end with a letter or number';
    }
    if (reserved.contains(handle)) return 'That username is reserved';

    return null;
  }

  /// Lowercased/trimmed form to persist.
  static String normalize(String value) => value.trim().toLowerCase();
}
