class FoodCategory {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  const FoodCategory({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory FoodCategory.fromJson(Map<String, dynamic> json) => FoodCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );
}
