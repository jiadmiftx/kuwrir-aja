/// Real pricing breakdown for a cart, computed server-side without
/// creating an order — lets the checkout confirmation screen show the
/// actual delivery fee/tax/total instead of the cart's flat estimate.
class OrderQuote {
  final double subtotal;
  final double packagingFee;
  final double deliveryFee;
  final String deliveryType;
  final double appServiceFee;
  final double taxAmount;
  final double total;
  final double distanceKm;

  const OrderQuote({
    required this.subtotal,
    required this.packagingFee,
    required this.deliveryFee,
    required this.deliveryType,
    required this.appServiceFee,
    required this.taxAmount,
    required this.total,
    required this.distanceKm,
  });

  factory OrderQuote.fromJson(Map<String, dynamic> json) => OrderQuote(
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        packagingFee: (json['packaging_fee'] as num?)?.toDouble() ?? 0,
        deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
        deliveryType: json['delivery_type'] as String? ?? 'platform',
        appServiceFee: (json['app_service_fee'] as num?)?.toDouble() ?? 0,
        taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      );
}
