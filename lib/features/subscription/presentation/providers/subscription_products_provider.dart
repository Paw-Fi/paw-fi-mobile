import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/subscription_product.dart';

class SubscriptionProductsNotifier
    extends AsyncNotifier<List<SubscriptionProduct>> {
  @override
  Future<List<SubscriptionProduct>> build() async {
    final user = ref.watch(authProvider);
    if (user.isEmpty) return const [];

    final platform = _platformString();
    if (platform == null) {
      // Desktop/web build: no IAP.
      return const [];
    }

    try {
      return await _fetchProducts(platform);
    } catch (e) {
      // iOS must still be able to render a paywall even if the backend catalog isn't ready.
      if (platform == 'ios') {
        debugPrint(
          '[SubscriptionProducts] Falling back to local iOS catalog: $e',
        );
        return _publiclySelectableProducts(_fallbackIosProducts);
      }
      rethrow;
    }
  }

  String? _platformString() {
    if (kIsWeb) return null;
    // Product catalog is used for iOS IAP. Android remains Stripe web checkout for now.
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return null;
  }

  Future<List<SubscriptionProduct>> _fetchProducts(String platform) async {
    final response = await supabase.functions.invoke(
      'get-subscription-products',
      method: HttpMethod.post,
      body: {
        'platform': platform,
      },
    );

    if (response.status >= 400) {
      throw Exception('Failed to load products: ${response.status}');
    }

    final data = response.data as Map<String, dynamic>?;
    final list = (data?['products'] as List?) ?? const [];
    final products = list
        .map((e) => SubscriptionProduct.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    if (platform == 'ios') {
      mergeMissingIosFallbackProducts(products);
    }

    final publicProducts = _publiclySelectableProducts(products);
    publicProducts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return publicProducts;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final platform = _platformString();
      if (platform == null) return const [];
      try {
        return await _fetchProducts(platform);
      } catch (e) {
        if (platform == 'ios') {
          debugPrint(
            '[SubscriptionProducts] Falling back to local iOS catalog: $e',
          );
          return _publiclySelectableProducts(_fallbackIosProducts);
        }
        rethrow;
      }
    });
  }
}

/// Keeps the full iOS purchase catalog available when the remotely managed
/// catalog temporarily omits an individual public product.
void mergeMissingIosFallbackProducts(List<SubscriptionProduct> products) {
  for (final fallback in _publiclySelectableProducts(_fallbackIosProducts)) {
    final exists = products.any(
      (product) =>
          product.plan == fallback.plan &&
          product.billingInterval == fallback.billingInterval,
    );
    if (!exists) {
      products.add(fallback);
    }
  }
}

List<SubscriptionProduct> _publiclySelectableProducts(
  List<SubscriptionProduct> products,
) {
  return products
      .where((product) => isSubscriptionPlanPubliclySelectable(product.plan))
      .toList();
}

const _fallbackIosProducts = <SubscriptionProduct>[
  SubscriptionProduct(
    id: 'fallback_plus_monthly_ios',
    platform: 'ios',
    plan: 'plus',
    billingInterval: 'monthly',
    storeProductId: 'monthly',
    displayName: 'Monthly',
    tagline: 'Flexible. Cancel anytime.',
    badgeText: null,
    isPopular: false,
    displayPriceUsd: Constants.subscriptionMonthlyPrice,
    originalPriceUsd: Constants.subscriptionMonthlyOriginalPrice,
    sortOrder: 0,
  ),
  SubscriptionProduct(
    id: 'fallback_plus_yearly_ios',
    platform: 'ios',
    plan: 'plus',
    billingInterval: 'yearly',
    storeProductId: 'yearly',
    displayName: 'Yearly',
    tagline: 'Best value for 12 months.',
    badgeText: 'SAVE 50%',
    isPopular: true,
    displayPriceUsd: Constants.subscriptionYearlyPrice,
    originalPriceUsd: Constants.subscriptionYearlyOriginalPrice,
    sortOrder: 10,
  ),
  SubscriptionProduct(
    id: 'fallback_lifetime_ios',
    platform: 'ios',
    plan: 'lifetime',
    billingInterval: null,
    storeProductId: 'lifetime_earlybird',
    displayName: 'Lifetime',
    tagline: 'One payment. Lifetime access.',
    badgeText: 'LIMITED',
    isPopular: false,
    displayPriceUsd: Constants.subscriptionLifetimePrice,
    originalPriceUsd: null,
    sortOrder: 40,
  ),
  SubscriptionProduct(
    id: 'fallback_premium_monthly_ios',
    platform: 'ios',
    plan: 'premium',
    billingInterval: 'monthly',
    storeProductId: 'premium_monthly',
    displayName: 'Monthly',
    tagline: 'All Premium features.',
    badgeText: null,
    isPopular: false,
    displayPriceUsd: Constants.subscriptionPremiumMonthlyPrice,
    originalPriceUsd: Constants.subscriptionPremiumMonthlyOriginalPrice,
    sortOrder: 20,
  ),
  SubscriptionProduct(
    id: 'fallback_premium_yearly_ios',
    platform: 'ios',
    plan: 'premium',
    billingInterval: 'yearly',
    storeProductId: 'premium_yearly',
    displayName: 'Yearly',
    tagline: 'All Premium features.',
    badgeText: 'PREMIUM',
    isPopular: false,
    displayPriceUsd: Constants.subscriptionPremiumYearlyPrice,
    originalPriceUsd: Constants.subscriptionPremiumYearlyOriginalPrice,
    sortOrder: 30,
  ),
];

final subscriptionProductsProvider = AsyncNotifierProvider<
    SubscriptionProductsNotifier, List<SubscriptionProduct>>(
  () => SubscriptionProductsNotifier(),
);
