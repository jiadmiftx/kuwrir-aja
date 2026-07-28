import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// A single push notification kept on-device for the in-app Notifications
/// screen. There's no server-side notification history (pushes are
/// fire-and-forget) so this is the only record of what a user has received —
/// local to this device, capped to the most recent [NotificationService.maxStored].
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

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        receivedAt: DateTime.tryParse(json['received_at'] as String? ?? '') ?? DateTime.now(),
        read: json['read'] as bool? ?? false,
      );
}

class NotificationService {
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static const _channelId = 'kuwrir_default';
  static const _channelName = 'Cocourir Notifications';
  static const _storeKey = 'stored_notifications';
  static const maxStored = 50;

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
  }

  static void setupForegroundHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        onPushData.value = message.data;
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (message.data.isNotEmpty) {
        onPushData.value = message.data;
      }
      if (notification == null) return;

      await persist(notification.title ?? '', notification.body ?? '');

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
    await prefs.setString(_storeKey, jsonEncode(trimmed.map((n) => n.toJson()).toList()));
  }

  static Future<List<AppNotification>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((n) => AppNotification.fromJson(n as Map<String, dynamic>)).toList();
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
    await prefs.setString(_storeKey, jsonEncode(updated.map((n) => n.toJson()).toList()));
  }
}
