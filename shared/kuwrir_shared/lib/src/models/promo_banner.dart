/// Admin-managed homepage promo banner shown as a carousel on the customer
/// app's Home screen. Named `PromoBanner` (not `Banner`) to avoid clashing
/// with Flutter's own `Banner` widget.
class PromoBanner {
  final String id;
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final String ctaText;
  final String? foodCategoryId;
  // "" (default) | "discount" | "free_delivery" — routes the CTA to a
  // pre-filtered Search instead of a plain category select.
  final String promoType;

  const PromoBanner({
    required this.id,
    required this.title,
    this.imageUrl,
    this.subtitle,
    this.ctaText = 'Lihat Menu',
    this.foodCategoryId,
    this.promoType = '',
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
        id: json['id'] as String,
        title: json['title'] as String,
        imageUrl: json['image_url'] as String?,
        subtitle: json['subtitle'] as String?,
        ctaText: json['cta_text'] as String? ?? 'Lihat Menu',
        foodCategoryId: json['food_category_id'] as String?,
        promoType: json['promo_type'] as String? ?? '',
      );
}
