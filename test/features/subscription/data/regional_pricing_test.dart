import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/data/regional_pricing.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/app_store_commitment_billing.dart';
import 'package:moneko/features/subscription/presentation/subscription_checkout_shared.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  for (final country in ['US', 'SG', 'AU']) {
    testWidgets('Stripe commitment is available in $country', (tester) async {
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
                productsAsync: const AsyncValue.data([]),
                iapStateAsync: const AsyncValue.data(
                  IapState(
                    storeAvailable: false,
                    productDetailsById: {},
                    lastError: null,
                  ),
                ),
                pricingCountryOverride: country,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final yearlyPlan = plans.singleWhere((plan) => plan.id == 'plus_yearly');
      expect(yearlyPlan.isCommitment, isTrue);
      expect(yearlyPlan.name, 'Yearly');
      expect(yearlyPlan.periodDisplay, '/month');
    });
  }

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

  test('savings percentage uses the monthly and yearly totals', () {
    expect(
      calculatePlanSavingsPercent(
        monthlyPrice: 10.99,
        yearlyTotal: 79.99,
      ),
      39,
    );
    expect(
      calculatePlanSavingsPercent(monthlyPrice: 5, yearlyTotal: 60),
      isNull,
    );
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
      formatRegionalPrice(market, (market.yearly / 12).round()),
    );
    expect(yearlyPlan.isCommitment, isTrue);
    expect(yearlyPlan.name, 'Yearly');
    expect(
      yearlyPlan.badgeText,
      'SAVE ${calculatePlanSavingsPercent(
        monthlyPrice: market.monthly.toDouble(),
        yearlyTotal: (market.yearly / 12).round() * 12,
      )}%',
    );
    expect(yearlyPlan.periodDisplay, '/month');
    expect(
      lifetimePlan.priceDisplay,
      formatRegionalPrice(market, market.lifetime),
    );
  });

  testWidgets(
      'eligible iOS devices replace yearly upfront with commitment terms',
      (tester) async {
    late List<PlanOption> plans;
    const yearlyProduct = SubscriptionProduct(
      id: 'yearly-product',
      platform: 'ios',
      plan: 'plus',
      billingInterval: 'yearly',
      storeProductId: 'yearly',
      displayName: 'Yearly',
      tagline: 'Best value for 12 months.',
      badgeText: 'SAVE 50%',
      isPopular: true,
      displayPriceUsd: 79.99,
      originalPriceUsd: 131.88,
      sortOrder: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            plans = buildPlusPlanOptions(
              context: context,
              useIap: true,
              productsAsync: const AsyncValue.data([yearlyProduct]),
              iapStateAsync: const AsyncValue.data(
                IapState(
                  storeAvailable: true,
                  productDetailsById: {},
                  commitmentTermsByProductId: {
                    'yearly': AppStoreCommitmentTerms(
                      monthlyPrice: '€6.99',
                      totalCommitmentPrice: '€83.88',
                      totalCommitmentPriceValue: 83.88,
                    ),
                  },
                  lastError: null,
                ),
              ),
              pricingCountryOverride: 'CA',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final yearlyPlan = plans.singleWhere((plan) => plan.id == 'plus_yearly');
    expect(yearlyPlan.isCommitment, isTrue);
    expect(yearlyPlan.name, 'Yearly');
    expect(yearlyPlan.priceDisplay, '€6.99');
    expect(yearlyPlan.totalCommitmentPrice, '€83.88');
    expect(yearlyPlan.badgeText, 'SAVE 36%');
    expect(yearlyPlan.periodDisplay, '/month');
  });

  testWidgets('StoreKit commitment terms override the device pricing locale',
      (tester) async {
    late List<PlanOption> plans;
    const yearlyProduct = SubscriptionProduct(
      id: 'yearly-product',
      platform: 'ios',
      plan: 'plus',
      billingInterval: 'yearly',
      storeProductId: 'yearly',
      displayName: 'Yearly',
      tagline: 'Best value for 12 months.',
      badgeText: 'SAVE 50%',
      isPopular: true,
      displayPriceUsd: 79.99,
      originalPriceUsd: 131.88,
      sortOrder: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            plans = buildPlusPlanOptions(
              context: context,
              useIap: true,
              productsAsync: const AsyncValue.data([yearlyProduct]),
              iapStateAsync: const AsyncValue.data(
                IapState(
                  storeAvailable: true,
                  productDetailsById: {},
                  commitmentTermsByProductId: {
                    'yearly': AppStoreCommitmentTerms(
                      monthlyPrice: r'$6.67',
                      totalCommitmentPrice: r'$80.04',
                    ),
                  },
                  lastError: null,
                ),
              ),
              pricingCountryOverride: 'US',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final yearlyPlan = plans.singleWhere((plan) => plan.id == 'plus_yearly');
    expect(yearlyPlan.isCommitment, isTrue);
    expect(yearlyPlan.upfrontYearlyPrice, isNull);
    expect(yearlyPlan.priceDisplay, r'$6.67');
  });

  testWidgets('unsupported iOS devices retain the yearly upfront option',
      (tester) async {
    late List<PlanOption> plans;
    const yearlyProduct = SubscriptionProduct(
      id: 'yearly-product',
      platform: 'ios',
      plan: 'plus',
      billingInterval: 'yearly',
      storeProductId: 'yearly',
      displayName: 'Yearly',
      tagline: 'Best value for 12 months.',
      badgeText: 'SAVE 50%',
      isPopular: true,
      displayPriceUsd: 79.99,
      originalPriceUsd: 131.88,
      sortOrder: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            plans = buildPlusPlanOptions(
              context: context,
              useIap: true,
              productsAsync: const AsyncValue.data([yearlyProduct]),
              iapStateAsync: const AsyncValue.data(
                IapState(
                  storeAvailable: true,
                  productDetailsById: {},
                  lastError: null,
                ),
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final yearlyPlan = plans.singleWhere((plan) => plan.id == 'plus_yearly');
    expect(yearlyPlan.isCommitment, isFalse);
    expect(yearlyPlan.name, 'Yearly');
    expect(yearlyPlan.upfrontYearlyPrice, isNotNull);
    expect(yearlyPlan.periodDisplay, '/month');
  });
}
