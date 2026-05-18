import 'package:flutter/foundation.dart';

class ProductPricingTier {
  final int id;
  final String? title;
  final num? price;

  const ProductPricingTier({
    required this.id,
    this.title,
    this.price,
  });

  factory ProductPricingTier.fromJson(Map<String, dynamic> json) {
    try {
      final translations = json['translations'] != null
          ? List<Map<String, dynamic>>.from(json['translations'])
          : null;

      String? title;
      if (translations != null && translations.isNotEmpty) {
        final translation = translations.first;
        if (translation['title'] != null) {
          title = translation['title'];
        }
      }

      // If no translation title is found, fall back to pricing_tier_name
      // ONLY IF it's not a slug (usually slugs contain hyphens or numbers like member-1)
      title ??= json['pricing_tier_name'];

      return ProductPricingTier(
        id: json['id'] ?? 0,
        title: title,
        price: num.tryParse(json['price']?.toString() ?? '0'),
      );
    } catch (e) {
      debugPrint('Error parsing ProductPricingTier: $e');
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductPricingTier &&
        other.title?.toLowerCase().trim() == title?.toLowerCase().trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pricing_tier_name': title,
      'price': price,
    };
  }

  @override
  int get hashCode => title?.toLowerCase().trim().hashCode ?? 0;

  @override
  String toString() =>
      'ProductPricingTier(id: $id, title: $title, price: $price)';
}
