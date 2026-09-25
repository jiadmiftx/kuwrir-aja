class ChatMessage {
  final String id;
  final String orderId;
  final String channel; // driver | merchant
  final String senderId;
  final String senderRole; // customer | driver | merchant
  final String text;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.orderId,
    this.channel = 'driver',
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] ?? '',
    orderId: json['order_id'] ?? '',
    channel: json['channel'] ?? 'driver',
    senderId: json['sender_id'] ?? '',
    senderRole: json['sender_role'] ?? '',
    text: json['text'] ?? '',
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    isRead: json['is_read'] as bool? ?? false,
  );

  bool get isFromCustomer => senderRole == 'customer';
  bool get isFromDriver => senderRole == 'driver';
  bool get isFromMerchant => senderRole == 'merchant';
}
