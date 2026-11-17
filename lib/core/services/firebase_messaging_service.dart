import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';
import 'notification_service.dart';

/// FCM client half: permission, the device token on `users/{uid}`, and
/// turning incoming messages into local notifications.
///
/// Actual push *delivery* needs a backend (Cloud Functions) — until then
/// tokens are stored so a future backend can target this device, and all
/// alerts the user actually sees come from [ActivityAlertWatcher].
class FirebaseMessagingService {
  FirebaseMessagingService._();

  static String? _lastUid;
  static String? _lastToken;

  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleMessage);
    messaging.onTokenRefresh.listen((token) => _saveToken(token));

    await _saveTokenIfSignedIn();
  }

  /// Asks the OS for permission — called after the first frame so the
  /// system dialog never blocks startup.
  static Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await NotificationService.requestAndroidPermission();
  }

  /// Reacts to sign-in / sign-out: keeps this device's token in sync.
  static Future<void> onUserChanged(User? user) async {
    if (user == null) {
      await _removeToken();
      return;
    }
    await _saveTokenIfSignedIn();
  }

  /// Drops the push token while the user is still signed in — called from
  /// `logout()` *before* `signOut()`, because Firestore rules only allow
  /// the owner to write their own `users/{uid}` doc.
  static Future<void> removeCurrentToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _writeToken(token, uid, remove: true);
  }

  static Future<void> _saveTokenIfSignedIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _lastUid = uid;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? _lastUid;
    if (uid == null || token.isEmpty) return;

    _lastUid = uid;
    _lastToken = token;
    await _writeToken(token, uid, remove: false);
  }

  static Future<void> _removeToken() async {
    final uid = _lastUid;
    final token = _lastToken;
    if (uid == null || token == null) return;

    await _writeToken(token, uid, remove: true);
    _lastUid = null;
    _lastToken = null;
  }

  static Future<void> _writeToken(
    String token,
    String uid, {
    required bool remove,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'fcmTokens':
              remove
                  ? FieldValue.arrayRemove([token])
                  : FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Token sync is best-effort — never block sign-in/out on it.
    }
  }

  static Future<void> _handleMessage(RemoteMessage message) async {
    final data = message.data;
    await NotificationService.show(
      type: NotificationService.typeFrom(data['type'] as String?),
      title:
          message.notification?.title ??
          (data['title'] as String?) ??
          'Expenty',
      body: message.notification?.body ?? (data['body'] as String?) ?? '',
    );
  }
}

/// Runs in a background isolate when a data-only FCM message arrives
/// while the app is terminated/backgrounded.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final data = message.data;
  await NotificationService.show(
    type: NotificationService.typeFrom(data['type'] as String?),
    title:
        message.notification?.title ?? (data['title'] as String?) ?? 'Expenty',
    body: message.notification?.body ?? (data['body'] as String?) ?? '',
  );
}
