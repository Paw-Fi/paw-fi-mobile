import 'package:moneko/features/subscription/data/models/subscription_product.dart';

class PlanOption {
  final String id; // Unique ID for UI selection
  final String serverPlanId; // 'plus' or 'lifetime'
  final String? billingInterval; // 'monthly', 'yearly', or null for lifetime
  // iOS-only (IAP). Android uses Stripe web checkout.
  final String? storeProductId;
  final SubscriptionProduct? catalogProduct;
  final String name;
  final String? storePrice;
  final double? displayPriceUsd;
  final double? originalPriceUsd;
  final String tagline;
  final bool isPopular;
  final String? badgeText;

  const PlanOption({
    required this.id,
    required this.serverPlanId,
    this.billingInterval,
    this.storeProductId,
    this.catalogProduct,
    required this.name,
    required this.storePrice,
    this.displayPriceUsd,
    this.originalPriceUsd,
    required this.tagline,
    this.isPopular = false,
    this.badgeText,
  });

  String get periodDisplay {
    if (billingInterval == 'monthly') return '/month';
    if (billingInterval == 'yearly') return '/year';
    return 'once';
  }

  String get priceDisplay {
    if (storePrice != null && storePrice!.isNotEmpty) {
      return storePrice!;
    }
    if (displayPriceUsd != null) {
      return '\$${displayPriceUsd!.toStringAsFixed(2)}';
    }
    return '...';
  }
}
