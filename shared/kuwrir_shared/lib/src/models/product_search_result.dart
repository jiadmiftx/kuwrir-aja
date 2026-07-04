import 'product.dart';

/// A [Product] joined with just enough of its owning merchant to render a
/// Search result card and navigate to that merchant on tap. Returned by the
/// cross-merchant GET /products/search endpoint.
class ProductSearchResult {
  final Product product;
  final String merchantId;
  final String merchantName;
  final String? merchantLogoUrl;
  final bool merchantIsOpen;

  const ProductSearchResult({
    required this.product,
    required this.merchantId,
    required this.merchantName,
    this.merchantLogoUrl,
    this.merchantIsOpen = false,
  });

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) => ProductSearchResult(
        product: Product.fromJson(json),
        merchantId: json['merchant_id'] as String,
        merchantName: json['merchant_name'] as String? ?? '',
        merchantLogoUrl: json['merchant_logo_url'] as String?,
        merchantIsOpen: json['merchant_is_open'] as bool? ?? false,
      );
}
