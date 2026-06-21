class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String senderRole; // customer | driver
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? '',
        orderId: json['order_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        senderRole: json['sender_role'] ?? '',
        text: json['text'] ?? '',
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  bool get isFromCustomer => senderRole == 'customer';
  bool get isFromDriver => senderRole == 'driver';
}
