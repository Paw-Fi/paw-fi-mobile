import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/data/regional_pricing.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/subscription_checkout_shared.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('regional pricing catalog', () {
    test('covers 175 unique countries', () {
      expect(regionalPricingCountryCodes, hasLength(175));
      expect(regionalPricingCountryCodes.toSet(), hasLength(175));
    });

    test('resolves local markets and falls back to USD', () {
      expect(regionalPricingForCountry('IE').currencyCode, 'EUR');
      expect(regionalPricingForCountry('in').currencyCode, 'INR');
      expect(regionalPricingForCountry('unknown').currencyCode, 'USD');
    });

    test('selects and formats plan prices in minor units', () {
      final market = regionalPricingForCountry('IE');

      expect(
        regionalPriceForPlan(
          market,
          plan: 'plus',
          billingInterval: 'yearly',
        ),
        market.yearly,
      );
      expect(
        regionalPriceForPlan(market, plan: 'lifetime'),
        market.lifetime,
      );
      expect(formatRegionalPrice(market, market.monthly), contains('4.99'));
    });

    test('keeps GBP source prices and canonical EUR/USD Stripe prices', () {
      final gbp = regionalPricingForCountry('GB');
      expect(gbp.monthly, 399);
      expect(gbp.yearly, 2499);
      expect(gbp.lifetime, 8999);
      expect(formatRegionalPrice(gbp, gbp.lifetime), contains('89.99'));
      expect(regionalPricingForCountry('ME').monthly, 499);
      expect(regionalPricingForCountry('AF').monthly, 1099);
    });
  });

  test('StoreKit price takes priority over regional and USD fallbacks', () {
    const storeOption = PlanOption(
      id: 'plus_monthly',
      serverPlanId: 'plus',
      billingInterval: 'monthly',
      name: 'Monthly',
      storePrice: '€10.99',
      regionalPrice: '€9.99',
      displayPriceUsd: 10.99,
      tagline: 'Monthly plan',
    );
    const regionalOption = PlanOption(
      id: 'plus_monthly',
      serverPlanId: 'plus',
      billingInterval: 'monthly',
      name: 'Monthly',
      storePrice: null,
      regionalPrice: '€9.99',
      displayPriceUsd: 10.99,
      tagline: 'Monthly plan',
    );

    expect(storeOption.priceDisplay, '€10.99');
    expect(regionalOption.priceDisplay, '€9.99');
  });

  test('checkout platform selection is centralized', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(shouldUseAppStoreCheckout(forceStripeCheckout: false), isTrue);
    expect(shouldUseAppStoreCheckout(forceStripeCheckout: true), isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(shouldUseAppStoreCheckout(forceStripeCheckout: false), isFalse);
  });

  testWidgets('shared Android plan options use the regional catalog',
      (tester) async {
    late List<PlanOption> plans;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            plans = buildPlusPlanOptions(
              context: context,
              useIap: false,
              productsAsync:
                  const AsyncValue<List<SubscriptionProduct>>.data([]),
              iapStateAsync: const AsyncValue<IapState>.loading(),
              pricingCountryOverride: 'IE',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final market = regionalPricingForCountry('IE');
    final monthlyPlan = plans.singleWhere(
      (plan) => plan.billingInterval == 'monthly',
    );
    final yearlyPlan = plans.singleWhere(
      (plan) => plan.billingInterval == 'yearly',
    );
    final lifetimePlan = plans.singleWhere(
      (plan) => plan.serverPlanId == 'lifetime',
    );

    expect(plans, hasLength(3));
    expect(plans.every((plan) => plan.storePrice == null), isTrue);
    expect(plans.every((plan) => plan.currencyCode == 'EUR'), isTrue);
    expect(plans.every((plan) => plan.pricingCountry == 'IE'), isTrue);
    expect(
      monthlyPlan.priceDisplay,
      formatRegionalPrice(market, market.monthly),
    );
    expect(
      yearlyPlan.priceDisplay,
      formatRegionalPrice(market, market.yearly),
    );
    expect(
      lifetimePlan.priceDisplay,
      formatRegionalPrice(market, market.lifetime),
    );
  });
}
