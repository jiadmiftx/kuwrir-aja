class Promotion {
  final String id;
  final String code;
  final String title;
  final String type; // percentage, fixed, free_delivery
  final double value;
  final double minOrder;
  final double maxDiscount;

  const Promotion({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    this.value = 0,
    this.minOrder = 0,
    this.maxDiscount = 0,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
        id: json['id'] as String,
        code: json['code'] as String,
        title: json['title'] as String,
        type: json['type'] as String? ?? 'percentage',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        minOrder: (json['min_order'] as num?)?.toDouble() ?? 0,
        maxDiscount: (json['max_discount'] as num?)?.toDouble() ?? 0,
      );
}
