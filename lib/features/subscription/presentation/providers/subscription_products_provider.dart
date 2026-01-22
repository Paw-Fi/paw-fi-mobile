import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
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

    return _fetchProducts(platform);
  }

  String? _platformString() {
    if (kIsWeb) return null;
    // Product catalog is used for iOS IAP. Android remains Stripe web checkout for now.
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return null;
  }

  Future<List<SubscriptionProduct>> _fetchProducts(String platform) async {
    final response = await supabase.functions.invoke(
      'get-subscription-products?platform=${Uri.encodeComponent(platform)}',
      method: HttpMethod.get,
    );

    if (response.status >= 400) {
      throw Exception('Failed to load products: ${response.status}');
    }

    final data = response.data as Map<String, dynamic>?;
    final list = (data?['products'] as List?) ?? const [];
    return list
        .map((e) => SubscriptionProduct.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final platform = _platformString();
      if (platform == null) return const [];
      return _fetchProducts(platform);
    });
  }
}

final subscriptionProductsProvider = AsyncNotifierProvider<
    SubscriptionProductsNotifier, List<SubscriptionProduct>>(
  () => SubscriptionProductsNotifier(),
);
