import 'package:expenty/core/utils/validators.dart';
import 'package:expenty/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('rejects empty and malformed emails', () {
      expect(Validators.validateEmail(null), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('not-an-email'), isNotNull);
      expect(Validators.validateEmail('user@expenty.app'), isNull);
    });

    test('enforces minimum password length', () {
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword('12345'), isNotNull);
      expect(Validators.validatePassword('123456'), isNull);
    });

    test('rejects blank required fields', () {
      expect(Validators.validateRequired(null), isNotNull);
      expect(Validators.validateRequired('   '), isNotNull);
      expect(Validators.validateRequired('Expenty'), isNull);
    });
  });

  group('PrimaryButton', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrimaryButton(text: 'Login', onPressed: null)),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('is disabled while loading', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Please Wait...',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      expect(tapped, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
