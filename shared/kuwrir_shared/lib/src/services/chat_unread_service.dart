import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_unread_count.dart';

/// Keeps a [ChatUnreadCount] fresh via a light foreground poll (matching
/// this codebase's existing "no background service, just a cheap poll while
/// the app is open" convention — see driver_app's LocationService) plus an
/// immediate refresh whenever a chat/merchant_chat/support push arrives, so
/// a badge updates right away instead of waiting up to [pollInterval].
///
/// Plain [ChangeNotifier]-free service (not a Cubit) so it has no
/// flutter_bloc dependency — kuwrir_shared doesn't otherwise depend on it.
/// Each app wires this to its own `NotificationService.onPushData`.
class ChatUnreadService {
  final Future<ChatUnreadCount> Function() fetch;
  final ValueNotifier<Map<String, dynamic>?>? pushSignal;
  final Duration pollInterval;

  final ValueNotifier<ChatUnreadCount> count = ValueNotifier(
    const ChatUnreadCount(),
  );
  Timer? _timer;

  ChatUnreadService({
    required this.fetch,
    this.pushSignal,
    this.pollInterval = const Duration(seconds: 30),
  });

  void start() {
    _refresh();
    _timer = Timer.periodic(pollInterval, (_) => _refresh());
    pushSignal?.addListener(_onPush);
  }

  void _onPush() {
    final type = pushSignal?.value?['type'] as String?;
    if (type == 'chat' || type == 'merchant_chat' || type == 'support') {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      count.value = await fetch();
    } catch (_) {
      // Best-effort — a stale/missing badge isn't worth surfacing an error for.
    }
  }

  void dispose() {
    _timer?.cancel();
    pushSignal?.removeListener(_onPush);
    count.dispose();
  }
}
