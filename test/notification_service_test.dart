import 'package:expenty/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCM payload types map onto the toggle that governs them', () {
    expect(
      NotificationService.typeFrom('transaction'),
      NotificationType.transaction,
    );
    expect(NotificationService.typeFrom('group'), NotificationType.group);
    expect(NotificationService.typeFrom(null), NotificationType.general);
    expect(
      NotificationService.typeFrom('something-else'),
      NotificationType.general,
    );
  });

  test('every toggle defaults to on (tests never init SharedPreferences)', () {
    expect(
      NotificationService.isEnabledFor(NotificationType.transaction),
      isTrue,
    );
    expect(NotificationService.isEnabledFor(NotificationType.group), isTrue);
    expect(NotificationService.isEnabledFor(NotificationType.general), isTrue);
  });
}
