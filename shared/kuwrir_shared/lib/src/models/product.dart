class ProductVariant {
  final String id;
  final String groupName;
  final String name;
  final double price;
  final bool isRequired;
  final int minSelect;
  final int maxSelect;

  const ProductVariant({
    required this.id,
    required this.groupName,
    required this.name,
    this.price = 0,
    this.isRequired = false,
    this.minSelect = 0,
    this.maxSelect = 1,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] as String,
        groupName: json['group_name'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        isRequired: json['is_required'] as bool? ?? false,
        minSelect: (json['min_select'] as num?)?.toInt() ?? 0,
        maxSelect: (json['max_select'] as num?)?.toInt() ?? 1,
      );
}

class Product {
  final String id;
  final String categoryId;
  final String? foodCategoryId;
  final String name;
  final String? description;
  final double price;
  final double costPrice;
  final String? imageUrl;
  final bool isAvailable;
  final bool trackStock;
  final int stockQuantity;
  final String? sku;
  final List<ProductVariant> variants;
  final double? discountPrice;
  final double packagingFee;
  final int? visibleFromMinute;
  final int? visibleUntilMinute;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.foodCategoryId,
    this.description,
    this.costPrice = 0,
    this.imageUrl,
    this.isAvailable = true,
    this.trackStock = false,
    this.stockQuantity = 0,
    this.sku,
    this.variants = const [],
    this.discountPrice,
    this.packagingFee = 0,
    this.visibleFromMinute,
    this.visibleUntilMinute,
  });

  /// Whether this product should show up right now, given its visibility
  /// window (minutes since midnight). Both-null means always visible.
  /// Mirrors the backend's pricing.IsVisibleNow wraparound logic.
  bool get isVisibleNow {
    final from = visibleFromMinute;
    final until = visibleUntilMinute;
    if (from == null || until == null) return true;
    final now = DateTime.now();
    final nowMinute = now.hour * 60 + now.minute;
    if (from <= until) {
      return nowMinute >= from && nowMinute <= until;
    }
    return nowMinute >= from || nowMinute <= until;
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        categoryId: json['category_id'] as String? ?? '',
        foodCategoryId: json['food_category_id'] as String?,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        description: json['description'] as String?,
        costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
        imageUrl: json['image_url'] as String?,
        isAvailable: json['is_available'] as bool? ?? true,
        trackStock: json['track_stock'] as bool? ?? false,
        stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
        sku: json['sku'] as String?,
        variants: (json['variants'] as List<dynamic>?)
                ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [],
        discountPrice: (json['discount_price'] as num?)?.toDouble(),
        packagingFee: (json['packaging_fee'] as num?)?.toDouble() ?? 0,
        visibleFromMinute: (json['visible_from_minute'] as num?)?.toInt(),
        visibleUntilMinute: (json['visible_until_minute'] as num?)?.toInt(),
      );
}

class ProductCategory {
  final String id;
  final String merchantId;
  final String name;
  final int sortOrder;
  final List<Product> products;

  const ProductCategory({
    required this.id,
    required this.merchantId,
    required this.name,
    this.sortOrder = 0,
    this.products = const [],
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
        id: json['id'] as String,
        merchantId: json['merchant_id'] as String? ?? '',
        name: json['name'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        products: (json['products'] as List<dynamic>?)
                ?.map((p) => Product.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
