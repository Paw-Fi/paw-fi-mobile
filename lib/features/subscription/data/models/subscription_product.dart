class SubscriptionProduct {
  final String id;
  final String platform; // ios | android
  final String plan; // plus | lifetime
  final String? billingInterval; // monthly | yearly | null
  final String storeProductId;

  // Marketing
  final String displayName;
  final String tagline;
  final String? badgeText;
  final bool isPopular;
  final double? displayPriceUsd;
  final double? originalPriceUsd;
  final int sortOrder;

  const SubscriptionProduct({
    required this.id,
    required this.platform,
    required this.plan,
    required this.billingInterval,
    required this.storeProductId,
    required this.displayName,
    required this.tagline,
    required this.badgeText,
    required this.isPopular,
    required this.displayPriceUsd,
    required this.originalPriceUsd,
    required this.sortOrder,
  });

  factory SubscriptionProduct.fromJson(Map<String, dynamic> json) {
    return SubscriptionProduct(
      id: json['id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      plan: json['plan']?.toString() ?? '',
      billingInterval: json['billing_interval']?.toString(),
      storeProductId: json['store_product_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      badgeText: json['badge_text']?.toString(),
      isPopular: json['is_popular'] as bool? ?? false,
      displayPriceUsd: json['display_price_usd'] != null
          ? (json['display_price_usd'] as num).toDouble()
          : null,
      originalPriceUsd: json['original_price_usd'] != null
          ? (json['original_price_usd'] as num).toDouble()
          : null,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  String get optionId {
    if (plan == 'lifetime') return 'lifetime';
    return '${plan}_${billingInterval ?? 'unknown'}';
  }

  bool get isLifetime => plan == 'lifetime';
}
