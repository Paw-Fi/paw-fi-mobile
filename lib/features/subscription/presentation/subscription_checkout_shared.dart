import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<PlanOption> buildPlusPlanOptions({
  required BuildContext context,
  required bool useIap,
  required AsyncValue<List<SubscriptionProduct>> productsAsync,
  required AsyncValue<IapState> iapStateAsync,
}) {
  if (useIap) {
    final storeDetailsById = iapStateAsync.value?.productDetailsById ?? const {};
    final catalogProducts = (productsAsync.value ?? const <SubscriptionProduct>[])
        .where((product) => isSubscriptionPlanPubliclySelectable(product.plan))
        .toList();

    final effectiveCatalogProducts = catalogProducts.isNotEmpty
        ? catalogProducts
        : <SubscriptionProduct>[
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
              sortOrder: 0,
            ),
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
              sortOrder: 10,
            ),
          ];

    return effectiveCatalogProducts.map((product) {
      final details = storeDetailsById[product.storeProductId];
      return PlanOption(
        id: product.optionId,
        serverPlanId: product.plan,
        billingInterval: product.billingInterval,
        storeProductId: product.storeProductId,
        catalogProduct: product,
        name: product.displayName,
        storePrice: details?.price,
        displayPriceUsd: product.displayPriceUsd,
        originalPriceUsd: product.originalPriceUsd,
        tagline: product.tagline,
        isPopular: product.isPopular,
        badgeText: product.badgeText,
      );
    }).toList()
      ..sort((a, b) {
        final catalogOrder =
            (a.catalogProduct?.sortOrder ?? 999).compareTo(b.catalogProduct?.sortOrder ?? 999);
        if (catalogOrder != 0) return catalogOrder;

        const intervalOrder = {'monthly': 0, 'yearly': 1};
        final aOrder =
            a.billingInterval != null ? (intervalOrder[a.billingInterval] ?? 2) : 2;
        final bOrder =
            b.billingInterval != null ? (intervalOrder[b.billingInterval] ?? 2) : 2;
        return aOrder.compareTo(bOrder);
      });
  }

  return [
    PlanOption(
      id: 'plus_monthly',
      serverPlanId: 'plus',
      billingInterval: 'monthly',
      name: context.l10n.monthly,
      storePrice: null,
      displayPriceUsd: Constants.subscriptionMonthlyPrice,
      tagline: context.l10n.paywallPlanMonthlyTagline,
    ),
    PlanOption(
      id: 'plus_yearly',
      serverPlanId: 'plus',
      billingInterval: 'yearly',
      name: context.l10n.yearly,
      storePrice: null,
      displayPriceUsd: Constants.subscriptionYearlyPrice,
      tagline: context.l10n.paywallPlanYearlyTagline,
      isPopular: true,
      badgeText: context.l10n.paywallBadgeSave50,
    ),
  ];
}

bool subscriptionMatchesPlanOption(Subscription? subscription, PlanOption option) {
  if (!(subscription?.isSubscribed ?? false)) return false;

  final currentPlan = subscription?.plan?.toLowerCase().trim();
  final targetPlan = option.serverPlanId.toLowerCase().trim();
  if (currentPlan != targetPlan) return false;

  final targetInterval = option.billingInterval?.toLowerCase().trim();
  if (targetInterval == null) return true;
  return subscription?.billingInterval?.toLowerCase().trim() == targetInterval;
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
    noSessionError: noSessionError,
    startCheckoutError: startCheckoutError,
    noCheckoutUrlError: noCheckoutUrlError,
  );

  if (result.isCanceled) {
    throw Exception(paymentCanceledMessage);
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
          if (result.verificationNonce != null && result.verificationNonce!.isNotEmpty)
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
