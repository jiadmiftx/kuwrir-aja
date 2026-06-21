import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class NotificationService {
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static const _channelId = 'kuwrir_default';
  static const _channelName = 'KUWRIR Notifications';

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
  }

  static void setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
