class OrderItem {
  final String id;
  final String? productId;
  final String itemName;
  final int quantity;
  final double basePrice;
  final double unitPrice;
  final double totalPrice;
  final String? notes;

  const OrderItem({
    required this.id,
    this.productId,
    required this.itemName,
    required this.quantity,
    required this.basePrice,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'] as String? ?? '',
    productId: json['product_id'] as String?,
    itemName: json['item_name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
    unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
    totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
    notes: json['notes'] as String?,
  );
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentType;
  final String paymentStatus;
  final String? paymentUrl;
  final DateTime? paymentExpiredAt;
  final double total;
  final double subtotal;
  final double deliveryFee;
  final double platformMarkup;
  final double taxAmount;
  final double appServiceFee;
  final double driverEarning;
  final double distanceKm;

  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? senderName;
  final String? senderPhone;

  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? receiverName;
  final String? receiverPhone;

  final String? notes;
  final String? merchantId;
  final String? merchantName;
  final String? merchantLogoUrl;
  final String? driverId;
  final DateTime? acceptedAt;
  final String? cancellationReason;
  final bool hasReview;
  final List<OrderItem> items;
  final DateTime? createdAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.paymentType = 'cash',
    this.paymentStatus = 'pending',
    this.paymentUrl,
    this.paymentExpiredAt,
    required this.total,
    required this.subtotal,
    this.deliveryFee = 0,
    this.platformMarkup = 0,
    this.taxAmount = 0,
    this.appServiceFee = 0,
    this.driverEarning = 0,
    this.distanceKm = 0,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.senderName,
    this.senderPhone,
    this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.receiverName,
    this.receiverPhone,
    this.notes,
    this.merchantId,
    this.merchantName,
    this.merchantLogoUrl,
    this.driverId,
    this.acceptedAt,
    this.cancellationReason,
    this.hasReview = false,
    this.items = const [],
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    return Order(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      paymentType: json['payment_type'] as String? ?? 'cash',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paymentUrl: json['payment_url'] as String?,
      paymentExpiredAt: DateTime.tryParse(
        json['payment_expired_at'] as String? ?? '',
      ),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      platformMarkup: (json['platform_markup'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      appServiceFee: (json['app_service_fee'] as num?)?.toDouble() ?? 0,
      driverEarning: (json['driver_earning'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      pickupAddress: json['pickup_address'] as String?,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      senderName: json['sender_name'] as String?,
      senderPhone: json['sender_phone'] as String?,
      dropoffAddress: json['dropoff_address'] as String?,
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble(),
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble(),
      receiverName: json['receiver_name'] as String?,
      receiverPhone: json['receiver_phone'] as String?,
      notes: json['notes'] as String?,
      merchantId: json['merchant_id'] as String?,
      merchantName: merchant?['name'] as String?,
      merchantLogoUrl: merchant?['logo_url'] as String?,
      driverId: json['driver_id'] as String?,
      acceptedAt:
          json['accepted_at'] != null
              ? DateTime.tryParse(json['accepted_at'] as String)
              : null,
      cancellationReason: json['cancellation_reason'] as String?,
      hasReview: json['has_review'] as bool? ?? false,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  // Matches the backend's CancelOrder rule exactly (customer/handler.go) —
  // once a merchant accepts (status leaves 'pending'), only the merchant's
  // own cancel/item-change flow can end the order, not the customer.
  bool get isCancellable => status == 'pending';
  bool get isDelivered => status == 'delivered';
  bool get isActive => [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'picked_up',
  ].contains(status);

  // Merchant chat opens once the merchant has accepted the order (there's
  // someone on the other end to reply) and stays open through delivery —
  // matches order_tracking_screen.dart's canChat and the backend's
  // SendMerchantChat gate (merchant must send the first message, checked
  // there, not just gated here — this is a UX nicety, not the real rule).
  bool get canChatMerchant =>
      ['confirmed', 'preparing', 'ready', 'picked_up'].contains(status);

  // Driver chat only makes sense once a driver has actually accepted the
  // job (driverId alone isn't enough — admin can pre-assign a driver who
  // hasn't confirmed yet, see backend AssignDriverToOrder/AcceptDelivery)
  // — mirrors Gojek/Grab only surfacing driver contact once a real driver
  // is en route, not the moment one's merely earmarked.
  bool get canChatDriver => driverId != null && acceptedAt != null && isActive;
}
