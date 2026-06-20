class ProductVariant {
  final String id;
  final String groupName;
  final String name;
  final double price;
  final bool isRequired;

  const ProductVariant({
    required this.id,
    required this.groupName,
    required this.name,
    this.price = 0,
    this.isRequired = false,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] as String,
        groupName: json['group_name'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        isRequired: json['is_required'] as bool? ?? false,
      );
}

class Product {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final double costPrice;
  final String? imageUrl;
  final bool isAvailable;
  final bool trackStock;
  final int stockQuantity;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description,
    this.costPrice = 0,
    this.imageUrl,
    this.isAvailable = true,
    this.trackStock = false,
    this.stockQuantity = 0,
    this.variants = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        categoryId: json['category_id'] as String? ?? '',
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        description: json['description'] as String?,
        costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
        imageUrl: json['image_url'] as String?,
        isAvailable: json['is_available'] as bool? ?? true,
        trackStock: json['track_stock'] as bool? ?? false,
        stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
        variants: (json['variants'] as List<dynamic>?)
                ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [],
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
