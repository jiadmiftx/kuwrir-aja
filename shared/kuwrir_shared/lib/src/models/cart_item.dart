import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  final String? notes;
  final List<ProductVariant> selectedVariants;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
    this.selectedVariants = const [],
  });

  /// Effective unit price for one line unit: discounted price (if set) plus
  /// every selected variant's price. Packaging fee is added separately below
  /// since it's a flat per-unit surcharge, not part of the product price.
  double get unitPrice {
    final base = product.discountPrice ?? product.price;
    final variantsSum = selectedVariants.fold(0.0, (sum, v) => sum + v.price);
    return base + variantsSum;
  }

  /// Packaging fee for this line — set by the merchant per product, not a
  /// platform charge.
  double get packagingFeeTotal => product.packagingFee * quantity;

  double get lineTotal => (unitPrice + product.packagingFee) * quantity;

  /// Identifies this exact product + variant combination as a single cart
  /// line — two selections of the same product with different variants
  /// (e.g. "Nasi Goreng - Pedas" vs "- Tidak Pedas") are distinct lines.
  String get variantKey {
    final ids = selectedVariants.map((v) => v.id).toList()..sort();
    return ids.join(',');
  }

  CartItem copyWith({int? quantity, String? notes, List<ProductVariant>? selectedVariants}) =>
      CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
        selectedVariants: selectedVariants ?? this.selectedVariants,
      );
}
