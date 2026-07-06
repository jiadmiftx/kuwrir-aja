/// A customer's saved delivery address ("Rumah", "Kantor", etc.) — label +
/// pinned location, picked once via the map and reused at checkout instead
/// of re-entering it every order.
class SavedAddress {
  final String id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;
  final bool isDefault;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
      };
}
