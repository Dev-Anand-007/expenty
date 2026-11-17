import 'package:expenty/features/profile/domain/username_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsernameRules.validate', () {
    test('accepts valid handles', () {
      expect(UsernameRules.validate('asha'), isNull);
      expect(UsernameRules.validate('john.doe_09'), isNull);
      expect(UsernameRules.validate('a1b'), isNull);
    });

    test('normalises case and whitespace', () {
      expect(UsernameRules.validate('  ASHA  '), isNull);
      expect(UsernameRules.normalize(' ASHA.Kumar '), 'asha.kumar');
    });

    test('rejects handles that are too short', () {
      expect(UsernameRules.validate('ab'), isNotNull);
    });

    test('rejects handles that are too long', () {
      expect(UsernameRules.validate('a' * 21), isNotNull);
      expect(UsernameRules.validate('a' * 20), isNull);
    });

    test('rejects reserved handles', () {
      expect(UsernameRules.validate('admin'), isNotNull);
      expect(UsernameRules.validate('Expenty'), isNotNull);
    });

    test('rejects invalid characters and edges', () {
      expect(UsernameRules.validate('a b'), isNotNull);
      expect(UsernameRules.validate('ash@'), isNotNull);
      expect(UsernameRules.validate('.abc'), isNotNull);
      expect(UsernameRules.validate('abc.'), isNotNull);
      expect(UsernameRules.validate('_abc'), isNotNull);
    });
  });
}
