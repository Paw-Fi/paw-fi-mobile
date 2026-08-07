import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/data/regional_pricing.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

int? calculatePlanSavingsPercent({
  required num monthlyPrice,
  required num yearlyTotal,
}) {
  if (!monthlyPrice.isFinite ||
      !yearlyTotal.isFinite ||
      monthlyPrice <= 0 ||
      yearlyTotal <= 0) {
    return null;
  }

  final regularYearlyTotal = monthlyPrice * 12;
  final savings =
      ((regularYearlyTotal - yearlyTotal) / regularYearlyTotal) * 100;
  if (savings <= 0) return null;
  return savings.round().clamp(1, 99);
}

bool shouldUseAppStoreCheckout({required bool forceStripeCheckout}) {
  return defaultTargetPlatform == TargetPlatform.iOS && !forceStripeCheckout;
}

List<PlanOption> buildPlusPlanOptions({
  required BuildContext context,
  required bool useIap,
  required AsyncValue<List<SubscriptionProduct>> productsAsync,
  required AsyncValue<IapState> iapStateAsync,
  String? pricingCountryOverride,
}) {
  final normalizedPricingCountry = pricingCountryOverride?.trim().toUpperCase();
  final pricingCountry = normalizedPricingCountry != null &&
          regionalPricingCountryToMarket.containsKey(normalizedPricingCountry)
      ? normalizedPricingCountry
      : resolveDeviceRegionalPricingCountry();
  final regionalMarket = regionalPricingForCountry(pricingCountry);
  final regionalSavingsPercent = calculatePlanSavingsPercent(
    monthlyPrice: regionalMarket.monthly,
    yearlyTotal: regionalMarket.yearly,
  );

  String priceFor(String plan, String? billingInterval) {
    final amount = regionalPriceForPlan(
      regionalMarket,
      plan: plan,
      billingInterval: billingInterval,
    );
    return formatRegionalPrice(
      regionalMarket,
      billingInterval == 'yearly' ? (amount / 12).round() : amount,
    );
  }

  String yearlyPriceFor(String plan) {
    return formatRegionalPrice(
      regionalMarket,
      regionalPriceForPlan(regionalMarket,
          plan: plan, billingInterval: 'yearly'),
    );
  }

  if (useIap) {
    final storeDetailsById =
        iapStateAsync.value?.productDetailsById ?? const {};
    String? storePriceFor(SubscriptionProduct product) {
      final details = storeDetailsById[product.storeProductId];
      if (details == null) return null;
      if (product.billingInterval != 'yearly') return details.price;
      return NumberFormat.currency(
        locale: Localizations.localeOf(context).toString(),
        name: details.currencyCode,
        symbol: details.currencySymbol,
      ).format(details.rawPrice / 12);
    }

    final catalogProducts = (productsAsync.value ??
            const <SubscriptionProduct>[])
        .where((product) => isSubscriptionPlanPubliclySelectable(product.plan))
        .toList();

    final effectiveCatalogProducts = catalogProducts.isNotEmpty
        ? catalogProducts
        : <SubscriptionProduct>[
            SubscriptionProduct(
              id: 'fallback_plus_yearly_ios',
              platform: 'ios',
              plan: 'plus',
              billingInterval: 'yearly',
              storeProductId: 'yearly',
              displayName: context.l10n.yearly,
              tagline: context.l10n.paywallPlanYearlyTagline,
              badgeText: context.l10n.paywallBadgeSave50,
              isPopular: true,
              displayPriceUsd: Constants.subscriptionYearlyPrice,
              originalPriceUsd: Constants.subscriptionYearlyOriginalPrice,
              sortOrder: 0,
            ),
            SubscriptionProduct(
              id: 'fallback_plus_monthly_ios',
              platform: 'ios',
              plan: 'plus',
              billingInterval: 'monthly',
              storeProductId: 'monthly',
              displayName: context.l10n.monthly,
              tagline: context.l10n.paywallPlanMonthlyTagline,
              badgeText: null,
              isPopular: false,
              displayPriceUsd: Constants.subscriptionMonthlyPrice,
              originalPriceUsd: Constants.subscriptionMonthlyOriginalPrice,
              sortOrder: 10,
            ),
            SubscriptionProduct(
              id: 'fallback_lifetime_ios',
              platform: 'ios',
              plan: 'lifetime',
              billingInterval: null,
              storeProductId: 'lifetime_earlybird',
              displayName: context.l10n.lifetime,
              tagline: context.l10n.paywallPlanLifetimeTagline,
              badgeText: context.l10n.paywallBadgeLimited,
              isPopular: false,
              displayPriceUsd: Constants.subscriptionLifetimePrice,
              originalPriceUsd: null,
              sortOrder: 40,
            ),
          ];

    double? monthlyPriceForPlan(String plan) {
      SubscriptionProduct? monthlyProduct;
      for (final candidate in effectiveCatalogProducts) {
        if (candidate.plan == plan && candidate.billingInterval == 'monthly') {
          monthlyProduct = candidate;
          break;
        }
      }
      if (monthlyProduct == null) return null;
      return storeDetailsById[monthlyProduct.storeProductId]?.rawPrice ??
          monthlyProduct.displayPriceUsd;
    }

    return effectiveCatalogProducts.map((product) {
      final details = storeDetailsById[product.storeProductId];
      final commitmentTerms = iapStateAsync
          .value?.commitmentTermsByProductId[product.storeProductId];
      final isCommitment =
          product.billingInterval == 'yearly' && commitmentTerms != null;
      final yearlyTotal = isCommitment
          ? commitmentTerms.totalCommitmentPriceValue ??
              details?.rawPrice ??
              product.displayPriceUsd
          : details?.rawPrice ?? product.displayPriceUsd;
      final savingsPercent =
          product.billingInterval == 'yearly' && yearlyTotal != null
              ? calculatePlanSavingsPercent(
                  monthlyPrice: monthlyPriceForPlan(product.plan) ??
                      (product.originalPriceUsd != null
                          ? product.originalPriceUsd! / 12
                          : Constants.subscriptionMonthlyPrice),
                  yearlyTotal: yearlyTotal,
                )
              : null;
      return PlanOption(
        id: product.optionId,
        serverPlanId: product.plan,
        billingInterval: product.billingInterval,
        storeProductId: product.storeProductId,
        catalogProduct: product,
        name: product.billingInterval == 'yearly'
            ? context.l10n.paywallCommitmentAnnualPlan
            : product.displayName,
        storePrice: isCommitment
            ? commitmentTerms.monthlyPrice
            : storePriceFor(product),
        regionalPrice: priceFor(product.plan, product.billingInterval),
        currencyCode: regionalMarket.currencyCode,
        pricingCountry: pricingCountry,
        displayPriceUsd: product.displayPriceUsd,
        originalPriceUsd: product.originalPriceUsd,
        tagline: isCommitment
            ? '${context.l10n.paywallCommitmentBilledMonthly(12)}.'
            : product.billingInterval == 'yearly'
                ? '${context.l10n.paywallCommitmentPaidUpfront(12)}.'
                : product.tagline,
        isPopular: product.isPopular,
        badgeText: savingsPercent == null
            ? (product.billingInterval == 'yearly' ? null : product.badgeText)
            : context.l10n.paywallBadgeSavePercent(savingsPercent),
        isCommitment: isCommitment,
        totalCommitmentPrice: commitmentTerms?.totalCommitmentPrice,
        upfrontYearlyPrice: product.billingInterval == 'yearly' && !isCommitment
            ? details?.price ?? yearlyPriceFor(product.plan)
            : null,
      );
    }).toList()
      ..sort((a, b) {
        final catalogOrder = (a.catalogProduct?.sortOrder ?? 999)
            .compareTo(b.catalogProduct?.sortOrder ?? 999);
        if (catalogOrder != 0) return catalogOrder;

        const intervalOrder = {'yearly': 0, 'monthly': 1};
        final aOrder = a.billingInterval != null
            ? (intervalOrder[a.billingInterval] ?? 2)
            : 2;
        final bOrder = b.billingInterval != null
            ? (intervalOrder[b.billingInterval] ?? 2)
            : 2;
        return aOrder.compareTo(bOrder);
      });
  }

  return [
    PlanOption(
      id: 'plus_yearly',
      serverPlanId: 'plus',
      billingInterval: 'yearly',
      name: context.l10n.yearly,
      storePrice: null,
      regionalPrice: priceFor('plus', 'yearly'),
      currencyCode: regionalMarket.currencyCode,
      pricingCountry: pricingCountry,
      displayPriceUsd: Constants.subscriptionYearlyPrice,
      tagline: context.l10n.paywallCommitmentPaidUpfront(12),
      isPopular: true,
      badgeText: regionalSavingsPercent == null
          ? null
          : context.l10n.paywallBadgeSavePercent(regionalSavingsPercent),
      upfrontYearlyPrice: yearlyPriceFor('plus'),
    ),
    PlanOption(
      id: 'plus_monthly',
      serverPlanId: 'plus',
      billingInterval: 'monthly',
      name: context.l10n.monthly,
      storePrice: null,
      regionalPrice: priceFor('plus', 'monthly'),
      currencyCode: regionalMarket.currencyCode,
      pricingCountry: pricingCountry,
      displayPriceUsd: Constants.subscriptionMonthlyPrice,
      tagline: context.l10n.paywallPlanMonthlyTagline,
    ),
    PlanOption(
      id: 'lifetime',
      serverPlanId: 'lifetime',
      billingInterval: null,
      name: context.l10n.lifetime,
      storePrice: null,
      regionalPrice: priceFor('lifetime', null),
      currencyCode: regionalMarket.currencyCode,
      pricingCountry: pricingCountry,
      displayPriceUsd: Constants.subscriptionLifetimePrice,
      tagline: context.l10n.paywallPlanLifetimeTagline,
      badgeText: context.l10n.paywallBadgeLimited,
    ),
  ];
}

bool subscriptionMatchesPlanOption(
    Subscription? subscription, PlanOption option) {
  if (!(subscription?.isSubscribed ?? false)) return false;

  final currentPlan = subscription?.plan?.toLowerCase().trim();
  final targetPlan = option.serverPlanId.toLowerCase().trim();
  if (currentPlan != targetPlan) return false;

  final targetInterval = option.billingInterval?.toLowerCase().trim();
  if (targetInterval == null) return true;
  if (subscription?.billingInterval?.toLowerCase().trim() != targetInterval) {
    return false;
  }

  if (targetInterval != 'yearly') return true;
  final hasMonthlyCommitment =
      subscription?.paymentInterval?.toLowerCase().trim() == 'monthly' &&
          subscription?.commitmentMonths == 12 &&
          (subscription?.commitmentEnd?.isAfter(DateTime.now()) ?? false);
  return option.isCommitment == hasMonthlyCommitment;
}

Future<MobileStripeCheckoutResult?> startStripeCheckoutForOption({
  required BuildContext context,
  required PlanOption option,
  required SupabaseClient supabaseClient,
  required String noSessionError,
  required String startCheckoutError,
  required String noCheckoutUrlError,
  required String paymentCanceledMessage,
  required String paymentFailedMessage,
  required String notActivatedMessage,
  required Future<void> Function() refreshSubscription,
  required bool Function() hasActiveSubscription,
}) async {
  final result = await startMobileStripeCheckout(
    context: context,
    supabaseClient: supabaseClient,
    plan: option.serverPlanId,
    billingInterval: option.billingInterval,
    countryCode: option.pricingCountry,
    currencyCode: option.currencyCode,
    noSessionError: noSessionError,
    startCheckoutError: startCheckoutError,
    noCheckoutUrlError: noCheckoutUrlError,
  );

  if (result.isCanceled) {
    throw PaymentCanceledException(paymentCanceledMessage);
  }

  if (result.isFailed) {
    throw Exception(result.errorMessage ?? paymentFailedMessage);
  }

  if (result.sessionId != null && result.sessionId!.isNotEmpty) {
    try {
      await supabaseClient.functions.invoke(
        'verify-payment',
        body: {
          'sessionId': result.sessionId,
          if (result.verificationNonce != null &&
              result.verificationNonce!.isNotEmpty)
            'v': result.verificationNonce,
        },
      );
    } catch (_) {}
  }

  final isActive = await waitForMobileStripeSubscriptionActivation(
    refreshSubscription: refreshSubscription,
    hasActiveSubscription: hasActiveSubscription,
  );

  if (!context.mounted) return result;
  if (!isActive) {
    throw Exception(notActivatedMessage);
  }

  return result;
}
