class Merchant {
  final String id;
  final String name;
  final String slug;
  final String address;
  final String? logoUrl;
  final String? bannerUrl;
  final String? description;
  final String? phone;
  final double latitude;
  final double longitude;
  final double rating;
  final int totalReviews;
  final bool isOpen;
  final bool isActive;
  final bool canSelfDeliver;
  final double selfDeliveryFee;
  final double? distanceKm;

  const Merchant({
    required this.id,
    required this.name,
    required this.slug,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.logoUrl,
    this.bannerUrl,
    this.description,
    this.phone,
    this.rating = 0,
    this.totalReviews = 0,
    this.isOpen = false,
    this.isActive = false,
    this.canSelfDeliver = false,
    this.selfDeliveryFee = 0,
    this.distanceKm,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) => Merchant(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String? ?? '',
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        logoUrl: json['logo_url'] as String?,
        bannerUrl: json['banner_url'] as String?,
        description: json['description'] as String?,
        phone: json['phone'] as String?,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
        isOpen: json['is_open'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? false,
        canSelfDeliver: json['can_self_deliver'] as bool? ?? false,
        selfDeliveryFee: (json['self_delivery_fee'] as num?)?.toDouble() ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );
}
