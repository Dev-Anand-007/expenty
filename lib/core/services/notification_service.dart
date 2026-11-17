import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'storage_service.dart';

/// Which Settings toggle governs a notification.
enum NotificationType { transaction, group, general }

/// Shows local notifications, gated by the user's Settings toggles.
///
/// Notifications are produced locally (Firestore watchers) or by an FCM
/// message that arrived on this device; both funnel through [show] so a
/// toggle flip in Settings takes effect immediately.
class NotificationService {
  NotificationService._();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'expenty_alerts',
    'Expenty alerts',
    description: 'Transaction and group activity alerts',
    importance: Importance.defaultImportance,
  );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static int _nextId = 0;

  /// Whether the in-app toggle for [type] is currently on.
  static bool isEnabledFor(NotificationType type) {
    switch (type) {
      case NotificationType.transaction:
        return StorageService.notifyTransactions;
      case NotificationType.group:
        return StorageService.notifyGroups;
      case NotificationType.general:
        return true;
    }
  }

  /// Maps an FCM payload `type` onto the toggle that governs it.
  static NotificationType typeFrom(String? raw) {
    switch (raw) {
      case 'transaction':
        return NotificationType.transaction;
      case 'group':
        return NotificationType.group;
      default:
        return NotificationType.general;
    }
  }

  static Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      // The permission prompt is driven once by FirebaseMessaging —
      // asking again here would show a second dialog on iOS.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        // Tapping an alert just opens the app (default launcher activity);
        // payload routing can be added here later.
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Android 13+ runtime permission (iOS is requested via FirebaseMessaging).
  static Future<void> requestAndroidPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> show({
    required NotificationType type,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!isEnabledFor(type)) return;

    // Background isolates (FCM data messages) reach [show] without going
    // through main()'s init — initialise on first use there.
    await init();

    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
