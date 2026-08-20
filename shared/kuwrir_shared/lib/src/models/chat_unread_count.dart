/// Aggregate unread chat/support counts for the current user — shared shape
/// across the customer/driver/merchant "chat-unread" endpoints (see backend
/// GetChatUnreadCount variants). [orders] maps order id -> channel
/// ("driver"/"merchant") -> unread count, letting a per-order chat icon show
/// its own badge without a separate request per order.
class ChatUnreadCount {
  final int total;
  final int support;
  final Map<String, Map<String, int>> orders;

  const ChatUnreadCount({
    this.total = 0,
    this.support = 0,
    this.orders = const {},
  });

  factory ChatUnreadCount.fromJson(Map<String, dynamic> json) {
    final ordersJson = json['orders'] as Map<String, dynamic>? ?? {};
    return ChatUnreadCount(
      total: (json['total'] as num?)?.toInt() ?? 0,
      support: (json['support'] as num?)?.toInt() ?? 0,
      orders: ordersJson.map(
        (orderId, channels) => MapEntry(
          orderId,
          (channels as Map<String, dynamic>).map(
            (channel, count) => MapEntry(channel, (count as num).toInt()),
          ),
        ),
      ),
    );
  }

  /// Unread count for one order's channel, 0 if none.
  int forOrder(String orderId, String channel) =>
      orders[orderId]?[channel] ?? 0;
}
