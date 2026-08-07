import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';

void main() {
  SubscriptionProduct product({
    required String id,
    required String plan,
    required String? billingInterval,
    required String storeProductId,
  }) {
    return SubscriptionProduct(
      id: id,
      platform: 'ios',
      plan: plan,
      billingInterval: billingInterval,
      storeProductId: storeProductId,
      displayName: id,
      tagline: '',
      badgeText: null,
      isPopular: false,
      displayPriceUsd: 1,
      originalPriceUsd: null,
      sortOrder: 0,
    );
  }

  test('restores the missing Lifetime product to a partial iOS catalog', () {
    final products = [
      product(
        id: 'plus_monthly',
        plan: 'plus',
        billingInterval: 'monthly',
        storeProductId: 'monthly',
      ),
      product(
        id: 'plus_yearly',
        plan: 'plus',
        billingInterval: 'yearly',
        storeProductId: 'yearly',
      ),
    ];

    mergeMissingIosFallbackProducts(products);

    final lifetimeProducts =
        products.where((product) => product.plan == 'lifetime').toList();
    expect(lifetimeProducts, hasLength(1));
    expect(lifetimeProducts.single.storeProductId, 'lifetime_earlybird');
  });

  test('keeps a catalog-provided Lifetime product unchanged', () {
    final products = [
      product(
        id: 'catalog_lifetime',
        plan: 'lifetime',
        billingInterval: null,
        storeProductId: 'lifetime_campaign',
      ),
    ];

    mergeMissingIosFallbackProducts(products);

    final lifetimeProducts =
        products.where((product) => product.plan == 'lifetime').toList();
    expect(lifetimeProducts, hasLength(1));
    expect(lifetimeProducts.single.storeProductId, 'lifetime_campaign');
  });
}
