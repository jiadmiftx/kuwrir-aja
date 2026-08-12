import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// A single push notification kept on-device for the in-app Notifications
/// screen. There's no server-side notification history (pushes are
/// fire-and-forget) so this is the only record of what a merchant has
/// received — local to this device, capped to the most recent
/// [NotificationService.maxStored].
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    receivedAt: receivedAt,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'received_at': receivedAt.toIso8601String(),
    'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        receivedAt:
            DateTime.tryParse(json['received_at'] as String? ?? '') ??
            DateTime.now(),
        read: json['read'] as bool? ?? false,
      );
}

class NotificationService {
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static const _channelId = 'kuwrir_merchant';
  static const _channelName = 'Cocourir Merchant Notifications';
  // Separate channel for new-order alerts — Android notification channels
  // are immutable after creation (importance/sound can't be bumped on the
  // existing "kuwrir_merchant" channel for users who already have it), and
  // new orders need Importance.max + a full-screen intent to behave like an
  // incoming call rather than a normal notification.
  static const _alarmChannelId = 'kuwrir_merchant_order_alarm';
  static const _alarmChannelName = 'Pesanan Baru';
  static const _storeKey = 'stored_notifications';
  static const maxStored = 50;

  /// Latest push message's data payload (e.g. {'type': 'new_order', ...}),
  /// published whenever a foreground push arrives or a background push is
  /// tapped open. main.dart listens to this to trigger an immediate order
  /// list refresh instead of waiting for the next poll tick.
  static final ValueNotifier<Map<String, dynamic>?> onPushData = ValueNotifier(
    null,
  );

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotif.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) return;
        try {
          onPushData.value =
              jsonDecode(response.payload!) as Map<String, dynamic>;
        } catch (_) {}
      },
    );

    // Cold start via tapping the alarm notification while the app was fully
    // killed — this is a locally-built notification (see
    // _showForMessage/handleBackgroundMessage), not one Android auto-showed
    // from an FCM `notification` payload, so it's this plugin's own launch
    // details that carry the payload, not FirebaseMessaging.getInitialMessage.
    final launchDetails = await _localNotif.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        try {
          onPushData.value = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Importance.max + fullScreenIntent so a new order behaves like an
    // incoming call — pops the accept/reject screen over the lock screen
    // instead of sitting quietly in the shade. The actual looping siren is
    // played from Dart once IncomingOrderScreen is on screen (see that
    // file), not from this channel's own one-shot sound.
    const alarmChannel = AndroidNotificationChannel(
      _alarmChannelId,
      _alarmChannelName,
      description: 'Notifikasi pesanan baru masuk',
      importance: Importance.max,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static void setupForegroundHandler() {
    // Also covers the "app was backgrounded, user tapped the push" case —
    // same data payload, so the same refresh trigger handles it.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        onPushData.value = message.data;
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.data.isNotEmpty) {
        onPushData.value = message.data;
      }
      await _showForMessage(message);
    });
  }

  /// Builds and shows the local notification for a received [message],
  /// covering both shapes the backend sends:
  /// - normal pushes: `message.notification` carries title/body, backend's
  ///   AndroidConfig has no channel override, shown on the default channel.
  /// - the merchant new-order alarm: sent data-only (see backend
  ///   `service.SendAlarmToUser`) specifically so this method — not
  ///   Android's own auto-display — is what runs in every app state,
  ///   including backgrounded/killed, which is required to attach
  ///   `fullScreenIntent`. title/body travel inside `data` for this case.
  ///
  /// Shared between the foreground listener above and main.dart's top-level
  /// background/killed-app handler.
  static Future<void> _showForMessage(RemoteMessage message) async {
    final isNewOrder = message.data['type'] == 'new_order';
    final title =
        message.notification?.title ?? message.data['title'] as String? ?? '';
    final body =
        message.notification?.body ?? message.data['body'] as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;

    await persist(title, body);

    await _localNotif.show(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
      notificationDetails: NotificationDetails(
        android: isNewOrder
            ? const AndroidNotificationDetails(
                _alarmChannelId,
                _alarmChannelName,
                importance: Importance.max,
                priority: Priority.max,
                icon: '@drawable/ic_notification',
                fullScreenIntent: true,
                category: AndroidNotificationCategory.call,
                visibility: NotificationVisibility.public,
              )
            : const AndroidNotificationDetails(
                _channelId,
                _channelName,
                importance: Importance.high,
                priority: Priority.high,
                icon: '@drawable/ic_notification',
              ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Entry point for main.dart's top-level `@pragma('vm:entry-point')`
  /// background handler — the only way a data-only alarm push gets a
  /// full-screen-intent notification while the app is backgrounded or fully
  /// killed (see `_showForMessage`'s doc comment).
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await _showForMessage(message);
  }

  static Future<void> uploadToken(ApiClient api) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await api.saveDeviceToken(token);
      }
    } catch (_) {}
  }

  /// Appends a notification to on-device storage — called for both
  /// foreground messages and background/terminated messages (from
  /// main.dart's top-level background handler).
  static Future<void> persist(String title, String body) async {
    if (title.isEmpty && body.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.insert(
      0,
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        receivedAt: DateTime.now(),
      ),
    );
    final trimmed = all.take(maxStored).toList();
    await prefs.setString(
      _storeKey,
      jsonEncode(trimmed.map((n) => n.toJson()).toList()),
    );
  }

  static Future<List<AppNotification>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<int> unreadCount() async {
    final all = await getAll();
    return all.where((n) => !n.read).length;
  }

  static Future<void> markAllRead() async {
    final all = await getAll();
    if (all.every((n) => n.read)) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = all.map((n) => n.copyWith(read: true)).toList();
    await prefs.setString(
      _storeKey,
      jsonEncode(updated.map((n) => n.toJson()).toList()),
    );
  }
}
