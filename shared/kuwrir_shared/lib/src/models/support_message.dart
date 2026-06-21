class SupportMessage {
  final String id;
  final String userId;
  final String senderRole; // customer | admin
  final String text;
  final bool isRead;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.userId,
    required this.senderRole,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        senderRole: json['sender_role'] ?? '',
        text: json['text'] ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  bool get isFromCustomer => senderRole == 'customer';
  bool get isFromAdmin => senderRole == 'admin';
}
