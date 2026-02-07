import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
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
        return _fallbackIosProducts;
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
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return products;
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
          return _fallbackIosProducts;
        }
        rethrow;
      }
    });
  }
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
    displayPriceUsd: 5.99,
    originalPriceUsd: 7.99,
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
    displayPriceUsd: 29.99,
    originalPriceUsd: 59.99,
    sortOrder: 10,
  ),
  SubscriptionProduct(
    id: 'fallback_lifetime_ios',
    platform: 'ios',
    plan: 'lifetime',
    billingInterval: null,
    storeProductId: 'lifetime_earlybird',
    displayName: 'Lifetime',
    tagline: 'Pay once, own it forever.',
    badgeText: 'LIMITED',
    isPopular: false,
    displayPriceUsd: 39.99,
    originalPriceUsd: null,
    sortOrder: 20,
  ),
];

final subscriptionProductsProvider = AsyncNotifierProvider<
    SubscriptionProductsNotifier, List<SubscriptionProduct>>(
  () => SubscriptionProductsNotifier(),
);
