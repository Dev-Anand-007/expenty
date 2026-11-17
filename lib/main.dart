import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/di/service_locator.dart';
import 'app/app.dart';
import 'core/services/activity_alert_watcher.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await StorageService.init();
  await setupLocator();

  await NotificationService.init();
  await FirebaseMessagingService.init();

  // Local alert watchers and the device push token follow the session.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      ActivityAlertWatcher.start(user.uid);
      await FirebaseMessagingService.onUserChanged(user);
    } else {
      await ActivityAlertWatcher.stop();
      await FirebaseMessagingService.onUserChanged(null);
    }
  });

  runApp(const ExpentyApp());

  // Ask for notification permission once the first frame is on screen so
  // the system dialog never stalls startup.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FirebaseMessagingService.requestPermission();
  });
}
