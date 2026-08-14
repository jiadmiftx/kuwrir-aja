import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class NotificationService {
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static const _channelId = 'kuwrir_driver';
  static const _channelName = 'Cocourir Driver Notifications';

  /// Latest push message's data payload, published on both foreground
  /// arrival and tap-to-open. Screens (e.g. chat) listen to this to refresh
  /// immediately instead of waiting on a slow poll fallback.
  static final ValueNotifier<Map<String, dynamic>?> onPushData =
      ValueNotifier(null);

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotif.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FirebaseMessaging.requestPermission above only covers iOS — Android
    // 13+ (API 33) gates ALL locally-shown notifications behind the
    // separate POST_NOTIFICATIONS runtime permission, never requested
    // implicitly. Declaring it in AndroidManifest.xml alone isn't enough —
    // without this, a device on Android 13+ sees nothing at all, silently.
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void setupForegroundHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        onPushData.value = message.data;
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        onPushData.value = message.data;
      }
      final notification = message.notification;
      if (notification == null) return;

      _localNotif.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }

  static Future<void> uploadToken(ApiClient api) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await api.saveDeviceToken(token);
      }
    } catch (_) {}
  }
}
