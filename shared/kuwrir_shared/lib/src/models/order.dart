class Order {
  final String id;
  final String orderNumber;
  final String status;
  final double total;
  final double subtotal;
  final double deliveryFee;
  final double platformMarkup;
  final double driverEarning;
  
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? senderName;
  final String? senderPhone;

  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String? receiverName;
  final String? receiverPhone;
  
  final double distanceKm;
  final String? notes;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.subtotal,
    required this.deliveryFee,
    required this.platformMarkup,
    required this.driverEarning,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.senderName,
    this.senderPhone,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    this.receiverName,
    this.receiverPhone,
    required this.distanceKm,
    this.notes,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'pending',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      platformMarkup: (json['platform_markup'] as num?)?.toDouble() ?? 0.0,
      driverEarning: (json['driver_earning'] as num?)?.toDouble() ?? 0.0,
      
      pickupAddress: json['pickup_address'],
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      senderName: json['sender_name'],
      senderPhone: json['sender_phone'],

      dropoffAddress: json['dropoff_address'] ?? '',
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble() ?? 0.0,
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble() ?? 0.0,
      receiverName: json['receiver_name'],
      receiverPhone: json['receiver_phone'],
      
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
    );
  }
}
