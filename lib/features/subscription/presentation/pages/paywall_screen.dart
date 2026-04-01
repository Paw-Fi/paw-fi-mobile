import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, debugPrint, kDebugMode;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:moneko/core/analytics/onboarding_flow_analytics_service.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/data/models/app_store_reviews.dart';
import 'package:moneko/shared/widgets/app_store_review_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/features/subscription/presentation/pages/purchase_processing_dialog_lifecycle.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

void _debugLog(Object? message) {
  debugPrint(message?.toString() ?? 'null');
}

// Intentionally shadow dart:core print in this file so any existing purchase
// flow logs never ship in release builds.
// ignore: avoid_print
void print(Object? message) => _debugLog(message);

const bool forceUseStripeCheckout = false;
const String purchaseOwnedByAnotherAccountCode =
    'PURCHASE_OWNED_BY_ANOTHER_ACCOUNT';
const Duration paywallReturnTrialThreshold =
    kDebugMode ? Duration(minutes: 1) : Duration(minutes: 3);

String _paywallReturnTrialExitAtKey(String userId) =>
    'paywall_return_trial:$userId:exit_at';
String _paywallReturnTrialExitModeKey(String userId) =>
    'paywall_return_trial:$userId:exit_mode';
String _paywallReturnTrialGrantedKey(String userId) =>
    'paywall_return_trial:$userId:granted';
String _paywallReturnTrialReviewPromptShownKey(String userId) =>
    'paywall_return_trial:$userId:review_prompt_shown';

enum PaywallMode {
  trial,
  resubscribe,
}

enum _ProcessingDialogKind {
  iapPurchase,
  // stripeCheckout,  // Uncomment when needed
  // restorePurchases,  // Uncomment when needed
  // cancelSubscription,  // Uncomment when needed
}

extension PaywallModeX on PaywallMode {
  static PaywallMode fromQuery(String? value) {
    return switch (value) {
      'resubscribe' => PaywallMode.resubscribe,
      _ => PaywallMode.trial,
    };
  }

  String get queryValue {
    return switch (this) {
      PaywallMode.trial => 'trial',
      PaywallMode.resubscribe => 'resubscribe',
    };
  }
}

// --- DATA ---
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

// --- PAGE ---
class PaywallScreen extends HookConsumerWidget {
  const PaywallScreen({super.key, this.mode = PaywallMode.resubscribe});

  final PaywallMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final subscriptionAsync = ref.watch(subscriptionManagementProvider);
    final productsAsync = ref.watch(subscriptionProductsProvider);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);

    // View State
    final selectedPlanId = useState<String>('plus_yearly');
    final hasAcknowledgedAutoRenew = useState(false);
    final isStripeProcessing = useState(false);
    final processingDialogOpen = useState(false);
    final processingDialogKind = useState<_ProcessingDialogKind?>(null);

    final currentSub = subscriptionAsync.value;
    final currentPlanId = currentSub?.subscription?.plan ?? 'free';
    final currentInterval = currentSub?.subscription?.billingInterval;
    final hasActiveSubscription =
        currentSub?.subscription?.isSubscribed ?? false;
    final isNewUser = currentSub?.subscription == null;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final useIap = isIos && !forceUseStripeCheckout;

    // Avoid accidentally registering multiple listeners across rebuilds.
    final didRegisterIapListener = useRef(false);

    // Track processing state for UI
    final isProcessing =
        (useIap ? (iapStateAsync.value?.isProcessing ?? false) : false) ||
            isStripeProcessing.value;

    final iapProcessing = iapStateAsync.valueOrNull?.isProcessing ?? false;
    final iapLastError = iapStateAsync.valueOrNull?.lastError ?? '';
    final iapLastErrorCode = iapStateAsync.valueOrNull?.lastErrorCode;
    final lastIapErrorShown = useRef<String?>(null);
    final didSeeIapProcessing = useRef(false);
    final didInitiateCheckout = useRef(false);
    final didInitiateRestore = useRef(false);
    final didCompletePaywallFlow = useRef(false);
    final isCheckingReturnTrial = useRef(false);
    final didMarkBackgroundExit = useRef(false);
    final isReturnTrialDialogOpen = useRef(false);
    final lastPresentedPlanKey = useRef<String?>(null);

    useEffect(() {
      unawaited(
        analytics.beginPage(
          flowName: 'onboarding_funnel',
          pageId: 'paywall',
          properties: <String, Object?>{
            'paywall_mode': mode.queryValue,
          },
        ),
      );
      return null;
    }, [mode]);

    void runAfterBuild(VoidCallback callback) {
      runAfterBuildIfMounted(context, callback);
    }

    Future<void> markPaywallExitForTrialOffer() async {
      if (auth.uid.isEmpty) return;
      if (!isNewUser) return;
      if (hasActiveSubscription) return;
      if (isProcessing ||
          processingDialogOpen.value ||
          didInitiateCheckout.value ||
          didInitiateRestore.value) {
        return;
      }

      final prefs = ref.read(sharedPreferencesProvider);
      final exitedAtIso = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(
        _paywallReturnTrialExitAtKey(auth.uid),
        exitedAtIso,
      );
      await prefs.setString(
        _paywallReturnTrialExitModeKey(auth.uid),
        mode.queryValue,
      );

      debugPrint(
          '[PaywallReturnTrial] marked exit locally uid=${auth.uid} at=$exitedAtIso mode=${mode.queryValue}');

      await ref
          .read(subscriptionManagementProvider.notifier)
          .markPaywallReturnExit();

      debugPrint(
          '[PaywallReturnTrial] marked exit on server uid=${auth.uid} at=$exitedAtIso');
    }

    Future<void> completePaywallFlowToDashboard({
      required PlanOption option,
      required String source,
      required String provider,
      required bool includePurchaseEvent,
    }) async {
      if (didCompletePaywallFlow.value) return;
      didCompletePaywallFlow.value = true;

      if (includePurchaseEvent) {
        await analytics.trackEvent(
          eventName: 'paywall_purchase_succeeded',
          flowName: 'onboarding_funnel',
          pageId: 'paywall',
          dedupeKey: 'success-${mode.queryValue}-${option.id}-$source',
          properties: <String, Object?>{
            'paywall_mode': mode.queryValue,
            'selected_plan': option.serverPlanId,
            'selected_option_id': option.id,
            'billing_interval': option.billingInterval,
            'provider': provider,
            'source': source,
          },
        );
      }

      await analytics.completeSession(
        flowName: 'onboarding_funnel',
        pageId: 'paywall',
        properties: <String, Object?>{
          'completion_target': 'dashboard',
          'paywall_mode': mode.queryValue,
          'selected_plan': option.id,
          'provider': provider,
          'source': source,
        },
      );

      didInitiateCheckout.value = false;
      didInitiateRestore.value = false;

      if (context.mounted) {
        context.go('/dashboard');
      }
    }

    void showReturnTrialGrantingDialog() {
      if (!context.mounted || isReturnTrialDialogOpen.value) return;
      isReturnTrialDialogOpen.value = true;
      unawaited(
        showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: BlockingProcessingDialog(
              message: context.l10n.activatingFreeTrial,
            ),
          ),
        ).whenComplete(() {
          isReturnTrialDialogOpen.value = false;
        }),
      );
    }

    void dismissReturnTrialGrantingDialog() {
      if (!isReturnTrialDialogOpen.value || !context.mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
      isReturnTrialDialogOpen.value = false;
    }

    void dismissProcessingDialog([String? reason]) {
      dismissProcessingDialogSafely<_ProcessingDialogKind>(
        context: context,
        dialogOpen: processingDialogOpen,
        dialogKind: processingDialogKind,
        reason: reason,
        logger: _debugLog,
      );
    }

    String humanizePurchaseError(String raw, [String? code]) {
      final message = raw.trim();
      final lower = message.toLowerCase();
      if (code == purchaseOwnedByAnotherAccountCode ||
          lower.contains('linked to another moneko account') ||
          lower.contains('belongs to another account')) {
        return message.isNotEmpty
            ? message
            : context.l10n.paywallErrorPurchaseOwnedByAnotherAccount;
      }
      if (lower.contains('cancel')) {
        return context.l10n.paywallErrorPurchaseCancelled;
      }
      if (lower.contains('subscription_managed_in_app') ||
          lower.contains('managed through an in-app purchase')) {
        return context.l10n.paywallErrorManagedInStore;
      }
      if (lower.contains('household') || lower.contains('family')) {
        return context.l10n.paywallErrorSharedSubscription;
      }
      if (lower.contains('timed out')) {
        return context.l10n.paywallErrorTimedOut;
      }
      if (lower.contains('not available') || lower.contains('store')) {
        return context.l10n.paywallErrorStoreUnavailable;
      }
      if (lower.contains('verification')) {
        return context.l10n.paywallErrorVerificationFailed;
      }
      return message.isNotEmpty ? message : context.l10n.paywallErrorGeneric;
    }

    void showIapError(String message, String source, [String? code]) {
      if (message.isEmpty) return;
      final dedupeKey = '${code ?? ''}:$message';
      if (dedupeKey == lastIapErrorShown.value) return;
      lastIapErrorShown.value = dedupeKey;
      runAfterBuild(() {
        dismissProcessingDialog('iap error $source');
        AppToast.error(context, humanizePurchaseError(message, code));
      });
    }

    if (useIap && !didRegisterIapListener.value) {
      didRegisterIapListener.value = true;
      ref.listen<AsyncValue<IapState>>(iapControllerProvider, (prev, next) {
        if (!context.mounted) return;

        final prevState = prev?.valueOrNull;
        final nextState = next.valueOrNull;
        final prevProcessing = prevState?.isProcessing ?? false;
        final nextProcessing = nextState?.isProcessing ?? false;

        _debugLog(
          '🧪 IAP state change | prevProcessing=$prevProcessing nextProcessing=$nextProcessing '
          'prevError=${prevState?.lastError ?? ""} nextError=${nextState?.lastError ?? ""} '
          'storeAvailable=${nextState?.storeAvailable ?? false} '
          'dialogOpen=${processingDialogOpen.value}',
        );

        if (next.hasError) {
          dismissProcessingDialog('provider error');
          _debugLog('IAP provider error: ${next.error}');
          showIapError(
            context.l10n.paywallErrorGeneric,
            'provider error',
          );
          return;
        }

        final nextError = nextState?.lastError;
        final prevError = prevState?.lastError;
        _debugLog(
            '🔍 Error check: nextError="$nextError" prevError="$prevError"');
        if (nextError != null &&
            nextError.isNotEmpty &&
            nextError != prevError) {
          _debugLog('🚨 IAP purchase error detected: $nextError');
          _debugLog('🚨 Calling showIapError...');
          showIapError(nextError, 'lastError');
          _debugLog('🚨 showIapError called');
        }

        // Check if a user-initiated purchase completed successfully
        // We use lastCompletedProductId to distinguish between:
        // 1. User-initiated purchases that completed (should navigate)
        // 2. Background processing of pending purchases from previous sessions (should NOT navigate)
        final prevCompletedProductId = prevState?.lastCompletedProductId;
        final nextCompletedProductId = nextState?.lastCompletedProductId;
        final hasNewCompletion = nextCompletedProductId != null &&
            nextCompletedProductId != prevCompletedProductId;

        if (hasNewCompletion) {
          _debugLog(
              '✅ User-initiated purchase completed: $nextCompletedProductId');
          dismissProcessingDialog('user-initiated purchase completed');

          // User-initiated purchase completed successfully - navigate to dashboard
          _debugLog('✅ Purchase successful! Refreshing subscription...');

          // Schedule async work without blocking the listener
          Future.microtask(() async {
            try {
              // Refresh subscription state - cross-invalidation ensures both providers stay in sync
              _debugLog('🔄 Refreshing subscription state...');
              await ref.read(subscriptionManagementProvider.notifier).refresh();
              // Note: subscriptionNotifierProvider is cross-invalidated automatically

              // Wait a bit longer to ensure Supabase propagation
              await Future.delayed(const Duration(milliseconds: 1000));

              if (!context.mounted) return;

              // Verify subscription is actually active before navigating
              final subscriptionAsync =
                  ref.read(subscriptionManagementProvider);
              final subscriptionDetails = subscriptionAsync.valueOrNull;
              final subscriptionData = subscriptionDetails?.subscription;

              // Use the Subscription model's isSubscribed check (includes expiry validation)
              final isActive = subscriptionData?.isSubscribed ?? false;

              _debugLog('📊 Full subscription check:');
              _debugLog(
                  '  - AsyncValue hasValue: ${subscriptionAsync.hasValue}');
              _debugLog(
                  '  - AsyncValue hasError: ${subscriptionAsync.hasError}');
              _debugLog(
                  '  - SubscriptionDetails: ${subscriptionDetails != null}');
              _debugLog('  - Subscription model: ${subscriptionData != null}');
              _debugLog('  - plan: ${subscriptionData?.plan}');
              _debugLog('  - status: ${subscriptionData?.status}');
              _debugLog('  - provider: ${subscriptionData?.provider}');
              _debugLog(
                  '  - currentPeriodEnd: ${subscriptionData?.currentPeriodEnd}');
              _debugLog('  - now: ${DateTime.now()}');
              if (subscriptionData?.currentPeriodEnd != null) {
                _debugLog(
                    '  - isAfter now: ${subscriptionData!.currentPeriodEnd!.isAfter(DateTime.now())}');
              }
              _debugLog('  - isSubscribed (from model): $isActive');

              if (isActive) {
                _debugLog(
                    '✅ Subscription confirmed active, waiting for paywall completion effect');
              } else {
                // Subscription still not active - show error
                _debugLog('❌ Subscription not active after purchase!');
                AppToast.error(
                  context,
                  context.l10n.paywallErrorNotActivated,
                );
              }
            } catch (e, stack) {
              _debugLog('❌ Error refreshing subscription: $e');
              _debugLog('Stack: $stack');

              // Show error to user instead of navigating
              if (context.mounted) {
                dismissProcessingDialog('iap verification error');
                AppToast.error(
                  context,
                  context.l10n.paywallErrorVerificationFailedRestart,
                );
              }
            }
          });
        }

        if (!prevProcessing && nextProcessing) {
          _debugLog('⏳ IAP processing started');
          didSeeIapProcessing.value = true;
        }
      });
    }

    useEffect(() {
      if (!useIap) return null;
      if (processingDialogKind.value != _ProcessingDialogKind.iapPurchase) {
        return null;
      }
      if (!processingDialogOpen.value) return null;

      if (iapLastError.isNotEmpty) {
        runAfterBuild(() => showIapError(iapLastError, 'effect'));
        return null;
      }

      if (didSeeIapProcessing.value && !iapProcessing) {
        runAfterBuild(() => dismissProcessingDialog('iap processing ended'));
      }

      return null;
    }, [
      useIap,
      iapProcessing,
      iapLastError,
      iapLastErrorCode,
      processingDialogOpen.value,
      processingDialogKind.value,
    ]);

    final List<PlanOption> plans;
    if (useIap) {
      // iOS uses IAP. Store product IDs:
      // - lifetime: lifetime_earlybird
      // - yearly: yearly
      // - monthly: monthly
      final storeDetailsById =
          iapStateAsync.value?.productDetailsById ?? const {};
      final catalogProducts =
          productsAsync.value ?? const <SubscriptionProduct>[];

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
                displayName: context.l10n.yearly,
                tagline: context.l10n.paywallPlanYearlyTagline,
                badgeText: context.l10n.paywallBadgeSave50,
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
                displayName: context.l10n.lifetime,
                tagline: context.l10n.paywallPlanLifetimeTagline,
                badgeText: context.l10n.paywallBadgeLimited,
                isPopular: false,
                displayPriceUsd: 39.99,
                originalPriceUsd: null,
                sortOrder: 20,
              ),
            ];

      plans = effectiveCatalogProducts.map((p) {
        final details = storeDetailsById[p.storeProductId];
        return PlanOption(
          id: p.optionId,
          serverPlanId: p.plan,
          billingInterval: p.billingInterval,
          storeProductId: p.storeProductId,
          catalogProduct: p,
          name: p.displayName,
          storePrice: details?.price,
          displayPriceUsd: p.displayPriceUsd,
          originalPriceUsd: p.originalPriceUsd,
          tagline: p.tagline,
          isPopular: p.isPopular,
          badgeText: p.badgeText,
        );
      }).toList()
        ..sort((a, b) {
          const order = {'yearly': 0, 'monthly': 1};
          final aOrder =
              a.billingInterval != null ? (order[a.billingInterval] ?? 2) : 2;
          final bOrder =
              b.billingInterval != null ? (order[b.billingInterval] ?? 2) : 2;
          return aOrder.compareTo(bOrder);
        });
    } else {
      // Android remains Stripe checkout (web) for now.
      plans = [
        PlanOption(
          id: 'plus_monthly',
          serverPlanId: 'plus',
          billingInterval: 'monthly',
          name: context.l10n.monthly,
          storePrice: null,
          displayPriceUsd: 2.99,
          tagline: context.l10n.paywallPlanMonthlyTagline,
        ),
        PlanOption(
          id: 'plus_yearly',
          serverPlanId: 'plus',
          billingInterval: 'yearly',
          name: context.l10n.yearly,
          storePrice: null,
          displayPriceUsd: 9.99,
          tagline: context.l10n.paywallPlanYearlyTagline,
          isPopular: true,
          badgeText: context.l10n.paywallBadgeSave50,
        ),
        PlanOption(
          id: 'lifetime',
          serverPlanId: 'lifetime',
          billingInterval: null,
          name: context.l10n.lifetime,
          storePrice: null,
          displayPriceUsd: 29.99,
          tagline: context.l10n.paywallPlanLifetimeTagline,
          badgeText: context.l10n.paywallBadgeLimited,
        ),
      ];
    }

    // Effect: If user is already on a plan, try to select it visually
    useEffect(() {
      if (plans.isNotEmpty && !plans.any((p) => p.id == selectedPlanId.value)) {
        selectedPlanId.value = plans.first.id;
      }

      if (currentPlanId == 'lifetime') {
        selectedPlanId.value = 'lifetime';
      } else if (currentPlanId == 'plus') {
        if (currentInterval == 'monthly') {
          selectedPlanId.value = 'plus_monthly';
        } else {
          selectedPlanId.value = 'plus_yearly';
        }
      } else {
        // Free user (both trial and resubscribe): default to yearly
        final yearly = plans
            .where((p) =>
                p.serverPlanId == 'plus' && p.billingInterval == 'yearly')
            .toList();
        if (yearly.isNotEmpty) {
          selectedPlanId.value = yearly.first.id;
        }
      }
      return null;
    }, [mode, currentPlanId, currentInterval, plans.length]);

    // Helpers
    final activePlanOption = plans.firstWhere(
      (p) => p.id == selectedPlanId.value,
      orElse: () => plans.first,
    );

    useEffect(() {
      if (plans.isEmpty || hasActiveSubscription) {
        return null;
      }

      final planKey =
          '${mode.queryValue}:${activePlanOption.id}:${activePlanOption.billingInterval ?? 'none'}';
      if (lastPresentedPlanKey.value == planKey) {
        return null;
      }

      lastPresentedPlanKey.value = planKey;
      unawaited(
        analytics.trackEvent(
          eventName: 'paywall_plan_presented',
          flowName: 'onboarding_funnel',
          pageId: 'paywall',
          dedupeKey: planKey,
          properties: <String, Object?>{
            'paywall_mode': mode.queryValue,
            'selected_plan': activePlanOption.serverPlanId,
            'selected_option_id': activePlanOption.id,
            'billing_interval': activePlanOption.billingInterval,
          },
        ),
      );
      return null;
    }, [
      plans.length,
      hasActiveSubscription,
      mode.queryValue,
      activePlanOption.id,
      activePlanOption.serverPlanId,
      activePlanOption.billingInterval,
    ]);

    Future<void> maybeGrantReturnTrial() async {
      if (!isNewUser) return;
      if (auth.uid.isEmpty || hasActiveSubscription) return;
      if (isCheckingReturnTrial.value) return;

      isCheckingReturnTrial.value = true;
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        final alreadyGranted =
            prefs.getBool(_paywallReturnTrialGrantedKey(auth.uid)) ?? false;
        if (alreadyGranted) return;

        final exitedAtRaw =
            prefs.getString(_paywallReturnTrialExitAtKey(auth.uid));
        if (exitedAtRaw == null || exitedAtRaw.isEmpty) return;

        final exitMode =
            prefs.getString(_paywallReturnTrialExitModeKey(auth.uid)) ??
                mode.queryValue;

        final exitedAt = DateTime.tryParse(exitedAtRaw)?.toUtc();
        if (exitedAt == null) {
          debugPrint(
              '[PaywallReturnTrial] invalid exit timestamp uid=${auth.uid} raw=$exitedAtRaw; clearing markers');
          await prefs.remove(_paywallReturnTrialExitAtKey(auth.uid));
          await prefs.remove(_paywallReturnTrialExitModeKey(auth.uid));
          return;
        }

        final elapsed = DateTime.now().toUtc().difference(exitedAt);
        if (elapsed < paywallReturnTrialThreshold) {
          debugPrint(
              '[PaywallReturnTrial] not eligible yet uid=${auth.uid} elapsed=${elapsed.inSeconds}s threshold=${paywallReturnTrialThreshold.inSeconds}s');
          return;
        }

        debugPrint(
            '[PaywallReturnTrial] attempting grant uid=${auth.uid} elapsed=${elapsed.inSeconds}s');

        // Re-sync the server marker with the original local exit timestamp.
        // This handles cases where background mark did not reach backend
        // (offline/background termination) but local marker still exists.
        await ref
            .read(subscriptionManagementProvider.notifier)
            .markPaywallReturnExit(exitedAtUtc: exitedAt);

        showReturnTrialGrantingDialog();

        await ref
            .read(subscriptionManagementProvider.notifier)
            .grantPaywallReturnTrial(trialDays: 14);

        debugPrint('[PaywallReturnTrial] grant succeeded uid=${auth.uid}');

        // Persist flow flags immediately after grant, before any navigation.
        await prefs.setBool('onboarding_completed:${auth.uid}', true);
        await prefs.setBool(_paywallReturnTrialGrantedKey(auth.uid), true);
        await prefs.remove(_paywallReturnTrialExitAtKey(auth.uid));
        await prefs.remove(_paywallReturnTrialExitModeKey(auth.uid));

        if (!context.mounted) return;

        // Ensure both subscription sources used by UI/router observe the update
        // before we navigate, otherwise router may immediately bounce back.
        await ref.read(subscriptionManagementProvider.notifier).refresh();
        if (!context.mounted) return;
        await ref.read(subscriptionNotifierProvider.notifier).refresh();

        await analytics.trackEvent(
          eventName: 'paywall_return_trial_granted',
          flowName: 'onboarding_funnel',
          pageId: 'paywall',
          dedupeKey: 'return-trial-${auth.uid}-$exitedAtRaw',
          properties: <String, Object?>{
            'paywall_mode': mode.queryValue,
            'exit_paywall_mode': exitMode,
            'minutes_away': elapsed.inMinutes,
            'grant_days': 14,
            'selected_plan': activePlanOption.serverPlanId,
            'billing_interval': activePlanOption.billingInterval,
            'provider': 'app_trial',
            'source': 'paywall_return',
          },
        );

        if (!context.mounted) return;

        await completePaywallFlowToDashboard(
          option: activePlanOption,
          source: 'paywall_return_trial',
          provider: 'app_trial',
          includePurchaseEvent: false,
        );
      } catch (e, stack) {
        final message = e.toString().toLowerCase();
        debugPrint(
            '[PaywallReturnTrial] grant failed uid=${auth.uid} error=$e');
        final isTerminalEligibilityFailure =
            message.contains('already granted') ||
                message.contains('already has active subscription access') ||
                message.contains('eligibility window expired') ||
                message.contains('no eligible paywall exit recorded');
        if (isTerminalEligibilityFailure) {
          final prefs = ref.read(sharedPreferencesProvider);
          await prefs.remove(_paywallReturnTrialExitAtKey(auth.uid));
          await prefs.remove(_paywallReturnTrialExitModeKey(auth.uid));
        }
        appLog(
          'Failed to grant return trial',
          name: 'PaywallScreen',
          error: e,
          stackTrace: stack,
        );
      } finally {
        dismissReturnTrialGrantingDialog();
        isCheckingReturnTrial.value = false;
      }
    }

    Future<void> maybeShowReviewPromptAfterReturnTrial() async {
      if (auth.uid.isEmpty) return;
      if (hasActiveSubscription) return;
      if (mode != PaywallMode.resubscribe) return;

      final prefs = ref.read(sharedPreferencesProvider);
      final didGetReturnTrial =
          prefs.getBool(_paywallReturnTrialGrantedKey(auth.uid)) ?? false;
      if (!didGetReturnTrial) return;

      final hasShownPaywallReviewPrompt =
          prefs.getBool(_paywallReturnTrialReviewPromptShownKey(auth.uid)) ??
              false;
      if (hasShownPaywallReviewPrompt) return;

      try {
        final inAppReview = InAppReview.instance;
        final isAvailable = await inAppReview.isAvailable();
        if (!isAvailable) return;

        debugPrint(
            '[PaywallReturnTrial] showing review prompt after trial uid=${auth.uid}');
        await inAppReview.requestReview();
        await prefs.setBool(
            _paywallReturnTrialReviewPromptShownKey(auth.uid), true);
      } catch (e, stack) {
        appLog(
          'Failed to show review prompt after return trial',
          name: 'PaywallScreen',
          error: e,
          stackTrace: stack,
        );
      }
    }

    final requiresAutoRenewAcknowledgement =
        activePlanOption.serverPlanId != 'lifetime';
    final canConfirmAutoRenew =
        !requiresAutoRenewAcknowledgement || hasAcknowledgedAutoRenew.value;

    final isStoreReady =
        !useIap || (iapStateAsync.valueOrNull?.storeAvailable ?? false);

    useEffect(() {
      final lifecycle = AppLifecycleListener(
        onStateChange: (state) {
          if (state == AppLifecycleState.paused) {
            if (didMarkBackgroundExit.value) {
              debugPrint(
                  '[PaywallReturnTrial] lifecycle paused ignored (already marked) uid=${auth.uid}');
              return;
            }

            didMarkBackgroundExit.value = true;
            unawaited(markPaywallExitForTrialOffer());
            return;
          }

          if (state == AppLifecycleState.resumed) {
            didMarkBackgroundExit.value = false;
            unawaited(maybeGrantReturnTrial());
          }
        },
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(maybeGrantReturnTrial());
        unawaited(maybeShowReviewPromptAfterReturnTrial());
      });

      return lifecycle.dispose;
    }, [
      auth.uid,
      hasActiveSubscription,
      isProcessing,
      processingDialogOpen.value,
      mode.queryValue,
      activePlanOption.id,
    ]);

    useEffect(() {
      if (didCompletePaywallFlow.value) return null;
      if (hasActiveSubscription) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(() async {
            await completePaywallFlowToDashboard(
              option: activePlanOption,
              source: didInitiateRestore.value
                  ? 'restore'
                  : didInitiateCheckout.value
                      ? 'checkout'
                      : 'existing_subscription',
              provider: useIap ? 'iap' : 'stripe',
              includePurchaseEvent:
                  didInitiateCheckout.value || didInitiateRestore.value,
            );
          }());
        });
      }
      return null;
    }, [hasActiveSubscription, useIap, activePlanOption.id]);

    useEffect(() {
      if (!requiresAutoRenewAcknowledgement) {
        hasAcknowledgedAutoRenew.value = true;
        return null;
      }

      hasAcknowledgedAutoRenew.value = false;
      return null;
    }, [activePlanOption.id]);

    bool isCurrentPlan(PlanOption option) {
      if (option.serverPlanId == 'lifetime' && currentPlanId == 'lifetime') {
        return true;
      }
      if (option.serverPlanId == currentPlanId &&
          option.billingInterval == currentInterval) {
        return true;
      }
      return false;
    }

    if (hasActiveSubscription) {
      return AdaptiveScaffold(
        body: Material(
          color: colorScheme.appBackground,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (useIap && productsAsync.isLoading) {
      return AdaptiveScaffold(
        appBar: const AdaptiveAppBar(title: ''),
        body: Material(
          color: colorScheme.appBackground,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (useIap && (productsAsync.hasError || plans.isEmpty)) {
      return AdaptiveScaffold(
        appBar: const AdaptiveAppBar(title: ''),
        body: Material(
          color: colorScheme.appBackground,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.paywallErrorLoadOptions,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  PrimaryAdaptiveButton(
                    onPressed: () {
                      unawaited(
                        analytics.trackAction(
                          flowName: 'onboarding_funnel',
                          pageId: 'paywall',
                          actionId: 'retry_load_options_tapped',
                          result: 'used',
                          properties: <String, Object?>{
                            'paywall_mode': mode.queryValue,
                            'provider': 'iap',
                          },
                        ),
                      );
                      ref.read(subscriptionProductsProvider.notifier).refresh();
                    },
                    child: Text(context.l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> onManageStoreSubscription() async {
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: 'paywall',
        actionId: 'manage_store_subscription_tapped',
        result: 'used',
        properties: <String, Object?>{
          'paywall_mode': mode.queryValue,
          'provider': useIap ? 'iap' : 'stripe',
        },
      );
      _debugLog('🧾 Open manage store subscription');
      final storeProductId = currentSub?.subscription?.storeProductId;
      final uri = defaultTargetPlatform == TargetPlatform.iOS
          ? Uri.parse('https://apps.apple.com/account/subscriptions')
          : Uri.parse(
              'https://play.google.com/store/account/subscriptions?package=com.moneko.mobile${storeProductId != null ? '&sku=$storeProductId' : ''}',
            );

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      _debugLog('🧾 Manage subscription launchUrl result: $ok');
      if (!ok && context.mounted) {
        AppToast.error(context, context.l10n.paywallErrorOpenSettings);
      }
    }

    Future<void> startStripeCheckout(PlanOption option) async {
      print('🔄 Starting Stripe checkout for plan: ${option.serverPlanId}');
      _debugLog(
        '🧾 Stripe checkout start | plan=${option.serverPlanId} interval=${option.billingInterval}',
      );
      final noSessionError = context.l10n.paywallErrorNoSession;
      final startCheckoutError = context.l10n.paywallErrorStartCheckout;
      final noCheckoutUrlError = context.l10n.paywallErrorNoCheckoutUrl;
      final paymentCanceledMessage = context.l10n.paymentCanceled;
      final paymentFailedMessage = context.l10n.paymentFailed;
      final notActivatedMessage = context.l10n.paywallErrorNotActivated;

      final result = await startMobileStripeCheckout(
        context: context,
        supabaseClient: supabase,
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
          await supabase.functions.invoke(
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
        refreshSubscription: () async {
          await ref.read(subscriptionManagementProvider.notifier).refresh();
        },
        hasActiveSubscription: () {
          final subscriptionData = ref
              .read(subscriptionManagementProvider)
              .valueOrNull
              ?.subscription;
          return subscriptionData?.isSubscribed ?? false;
        },
      );

      if (!context.mounted) return;

      if (isActive) {
        return;
      }

      throw Exception(notActivatedMessage);
    }

    // Action Logic
    Future<void> onMainAction() async {
      _debugLog(
        '🧭 onMainAction start | plan=${activePlanOption.id} serverPlan=${activePlanOption.serverPlanId} interval=${activePlanOption.billingInterval} storeReady=$isStoreReady useIap=$useIap',
      );
      print(
          '🎯 Starting subscription flow for plan: ${activePlanOption.serverPlanId}');
      final infoAlreadyOnPlanMessage = context.l10n.paywallInfoAlreadyOnPlan;
      final storeUnavailableMessage =
          context.l10n.paywallErrorStoreUnavailableShort;
      final missingProductMappingMessage =
          context.l10n.paywallErrorMissingProductMapping;
      final processingPurchaseMessage = context.l10n.paywallProcessingPurchase;
      final manageSubscriptionTitle =
          context.l10n.paywallManageSubscriptionPlayStore;
      final manageSubscriptionDescription =
          context.l10n.paywallErrorManagedInPlayStore;
      final openPlayStoreLabel = context.l10n.paywallOpenPlayStore;
      final cancelLabel = context.l10n.cancel;
      final paymentCanceledMessage = context.l10n.paymentCanceled;

      if (isCurrentPlan(activePlanOption)) {
        print('⚠️ User already on this plan');
        // Already on this plan
        AppToast.info(context, infoAlreadyOnPlanMessage);
        return;
      }

      // Android subscription upgrades/downgrades require passing ChangeSubscriptionParam
      // with the existing PurchaseDetails. To avoid accidental double subscriptions,
      // we direct users to manage plan changes in Google Play for now.

      _debugLog(
        '🧾 Confirmed selection | plan=${activePlanOption.id} serverPlan=${activePlanOption.serverPlanId} interval=${activePlanOption.billingInterval} useIap=$useIap',
      );
      try {
        didInitiateCheckout.value = true;
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: 'paywall',
          actionId: 'subscribe_tapped',
          result: 'used',
          properties: <String, Object?>{
            'paywall_mode': mode.queryValue,
            'selected_plan': activePlanOption.serverPlanId,
            'selected_option_id': activePlanOption.id,
            'billing_interval': activePlanOption.billingInterval,
            'provider': useIap ? 'iap' : 'stripe',
          },
        );
        print('🍎 Platform check - iOS: $isIos');
        if (useIap) {
          // Don't allow purchase attempts until the store/products are ready.
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception(storeUnavailableMessage);
          }

          final catalog = activePlanOption.catalogProduct;
          print(
              '📦 catalogProduct: ${catalog != null ? "id=${catalog.storeProductId}, plan=${catalog.plan}, interval=${catalog.billingInterval}" : "NULL"}');
          if (catalog == null) {
            throw Exception(missingProductMappingMessage);
          }

          print('✅ catalogProduct is valid, proceeding...');

          // Show processing dialog before starting purchase
          if (context.mounted) {
            print('🎬 Showing processing dialog...');
            lastIapErrorShown.value = null;
            didSeeIapProcessing.value = false;
            processingDialogOpen.value = true;
            processingDialogKind.value = _ProcessingDialogKind.iapPurchase;
            _debugLog(
                '🧾 Dialog open set to true (iap). plan=${activePlanOption.id}');
            showBlockingProcessingDialog(
              context: context,
              message: processingPurchaseMessage,
            );
            print('✅ Processing dialog shown');
          } else {
            print('⚠️ Context not mounted, skipping dialog');
          }

          print(
              '🔍 About to call buy() method with product: ${catalog.storeProductId}');
          _debugLog(
            '🧾 IAP buy start | product=${catalog.storeProductId} plan=${catalog.plan} interval=${catalog.billingInterval}',
          );
          await analytics.trackEvent(
            eventName: 'paywall_checkout_started',
            flowName: 'onboarding_funnel',
            pageId: 'paywall',
            properties: <String, Object?>{
              'paywall_mode': mode.queryValue,
              'selected_plan': activePlanOption.serverPlanId,
              'selected_option_id': activePlanOption.id,
              'billing_interval': activePlanOption.billingInterval,
              'provider': 'iap',
            },
          );
          await ref.read(iapControllerProvider.notifier).buy(catalog);
          print('✅ buy() method completed');
          _debugLog('🧾 IAP buy completed');
          _debugLog(
              '🧾 IAP state after buy: processing=${iapStateAsync.valueOrNull?.isProcessing} lastError=${iapStateAsync.valueOrNull?.lastError ?? ""}');
          // Dialog will remain open until purchase completes
          // Navigation in _onPurchaseUpdated will automatically dismiss the dialog
        } else {
          print('💳 Starting Stripe checkout');

          isStripeProcessing.value = true;

          try {
            await analytics.trackEvent(
              eventName: 'paywall_checkout_started',
              flowName: 'onboarding_funnel',
              pageId: 'paywall',
              properties: <String, Object?>{
                'paywall_mode': mode.queryValue,
                'selected_plan': activePlanOption.serverPlanId,
                'selected_option_id': activePlanOption.id,
                'billing_interval': activePlanOption.billingInterval,
                'provider': 'stripe',
              },
            );
            await startStripeCheckout(activePlanOption);
            await completePaywallFlowToDashboard(
              option: activePlanOption,
              source: 'checkout',
              provider: 'stripe',
              includePurchaseEvent: true,
            );
          } finally {
            isStripeProcessing.value = false;
            dismissProcessingDialog('stripe flow completed');
          }
        }
      } catch (e) {
        print('❌ Error in subscription flow: $e');

        dismissProcessingDialog('main action catch');

        if (context.mounted) {
          _debugLog('Purchase flow threw: $e');

          final raw = e.toString();
          final lower = raw.toLowerCase();
          final isCanceled = lower.contains('cancel');
          final isManagedInApp =
              lower.contains('subscription_managed_in_app') ||
                  lower.contains('managed through an in-app purchase');

          if (isManagedInApp) {
            await analytics.trackEvent(
              eventName: 'paywall_purchase_failed',
              flowName: 'onboarding_funnel',
              pageId: 'paywall',
              properties: <String, Object?>{
                'paywall_mode': mode.queryValue,
                'selected_plan': activePlanOption.serverPlanId,
                'billing_interval': activePlanOption.billingInterval,
                'provider': useIap ? 'iap' : 'stripe',
                'failure_reason': 'managed_in_store',
              },
            );
            if (!context.mounted) return;
            final result = await MonekoAlertDialog.show(
              context: context,
              title: manageSubscriptionTitle,
              description: manageSubscriptionDescription,
              confirmLabel: openPlayStoreLabel,
              cancelLabel: cancelLabel,
            );
            if (!context.mounted) return;
            if (result?.confirmed == true) {
              await onManageStoreSubscription();
            }
            return;
          }

          await analytics.trackEvent(
            eventName: isCanceled
                ? 'paywall_purchase_cancelled'
                : 'paywall_purchase_failed',
            flowName: 'onboarding_funnel',
            pageId: 'paywall',
            properties: <String, Object?>{
              'paywall_mode': mode.queryValue,
              'selected_plan': activePlanOption.serverPlanId,
              'billing_interval': activePlanOption.billingInterval,
              'provider': useIap ? 'iap' : 'stripe',
              'error_message': raw,
            },
          );
          didInitiateCheckout.value = false;
          if (!context.mounted) return;

          if (isCanceled) {
            AppToast.info(context, paymentCanceledMessage);
            return;
          }

          AppToast.error(context, humanizePurchaseError(raw));
        }
      }
    }

    Future<void> onRestorePurchases() async {
      Future<void> refreshSubscriptionState() async {
        await ref.read(subscriptionManagementProvider.notifier).refresh();
        await ref.read(subscriptionNotifierProvider.notifier).refresh();
      }

      didInitiateRestore.value = true;
      lastIapErrorShown.value = null;
      didSeeIapProcessing.value = false;
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: 'paywall',
        actionId: 'restore_purchases_tapped',
        result: 'used',
        properties: <String, Object?>{
          'paywall_mode': mode.queryValue,
        },
      );
      if (context.mounted) {
        processingDialogOpen.value = true;
        _debugLog('🧾 Dialog open set to true (restore purchases)');
        showBlockingProcessingDialog(
          context: context,
          message: context.l10n.paywallRestoringPurchases,
        );
      }

      try {
        if (useIap) {
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception(context.l10n.paywallErrorStoreUnavailableShort);
          }

          await ref.read(iapControllerProvider.notifier).restorePurchases();
        }

        await refreshSubscriptionState();

        var refreshedSubscription =
            ref.read(subscriptionManagementProvider).valueOrNull?.subscription;
        var refreshedIapState = ref.read(iapControllerProvider).valueOrNull;
        var restoreError = refreshedIapState?.lastError ?? '';
        var restoreErrorCode = refreshedIapState?.lastErrorCode;
        var isRestored = refreshedSubscription?.isSubscribed ?? false;

        if (useIap && !isRestored && restoreError.isEmpty) {
          for (var attempt = 0; attempt < 5; attempt++) {
            await Future<void>.delayed(const Duration(seconds: 1));
            await refreshSubscriptionState();
            refreshedSubscription = ref
                .read(subscriptionManagementProvider)
                .valueOrNull
                ?.subscription;
            refreshedIapState = ref.read(iapControllerProvider).valueOrNull;
            restoreError = refreshedIapState?.lastError ?? '';
            restoreErrorCode = refreshedIapState?.lastErrorCode;
            isRestored = refreshedSubscription?.isSubscribed ?? false;
            if (isRestored || restoreError.isNotEmpty) {
              break;
            }
          }
        }

        if (!context.mounted) return;

        if (isRestored) {
          await completePaywallFlowToDashboard(
            option: activePlanOption,
            source: 'restore',
            provider: useIap ? 'iap' : 'stripe',
            includePurchaseEvent: true,
          );
          AppToast.success(context, context.l10n.paywallRestoreSuccess);
          return;
        }

        didInitiateRestore.value = false;
        if (restoreError.isNotEmpty) {
          AppToast.error(
            context,
            humanizePurchaseError(restoreError, restoreErrorCode),
          );
          return;
        }

        AppToast.error(
          context,
          context.l10n.paywallRestoreFailed(context.l10n.paywallErrorGeneric),
        );
      } catch (e) {
        didInitiateRestore.value = false;
        if (context.mounted) {
          AppToast.error(
            context,
            context.l10n.paywallRestoreFailed(e.toString()),
          );
        }
      } finally {
        dismissProcessingDialog('restore purchases');
      }
    }

    return AdaptiveScaffold(
      body: Material(
        color: colorScheme.appBackground,
        child: Stack(
          children: [
            const _PaywallBackground(),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              mode == PaywallMode.trial
                                  ? context.l10n.paywallTitleSimple
                                  : context.l10n.paywallTitleSubscribe,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (mode == PaywallMode.resubscribe) ...[
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.paywallSubtitleResubscribe,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            const _HeroAppIcon(),
                            const SizedBox(height: 24),
                            const _AppRatingBadge(),
                            const SizedBox(height: 32),
                            // --- SUBSCRIPTION PLANS ---
                            _UnifiedPlanCard(
                              plans: plans,
                              selectedPlanId: selectedPlanId.value,
                              onPlanSelected: (id) {
                                final selectedPlan = plans.firstWhere(
                                  (plan) => plan.id == id,
                                  orElse: () => plans.first,
                                );
                                selectedPlanId.value = id;
                                unawaited(
                                  analytics.trackAction(
                                    flowName: 'onboarding_funnel',
                                    pageId: 'paywall',
                                    actionId: 'plan_selected',
                                    result: 'used',
                                    properties: <String, Object?>{
                                      'paywall_mode': mode.queryValue,
                                      'selected_plan':
                                          selectedPlan.serverPlanId,
                                      'selected_option_id': selectedPlan.id,
                                      'billing_interval':
                                          selectedPlan.billingInterval,
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),

                            // --- BENEFITS CHECKLIST ---
                            const _BenefitsChecklist(),
                            const SizedBox(height: 48),

                            // --- REVIEWS ---
                            const _ReviewsSection(),
                            const SizedBox(height: 32),

                            // Preview App Link
                            GestureDetector(
                              onTap: () {
                                unawaited(() async {
                                  await analytics.trackEvent(
                                    eventName: 'onboarding_preview_clicked',
                                    flowName: 'onboarding_funnel',
                                    pageId: 'paywall',
                                    properties: <String, Object?>{
                                      'paywall_mode': mode.queryValue,
                                      'selected_plan':
                                          activePlanOption.serverPlanId,
                                      'billing_interval':
                                          activePlanOption.billingInterval,
                                      'preview_entry_point': 'paywall',
                                    },
                                  );
                                  await analytics.trackAction(
                                    flowName: 'onboarding_funnel',
                                    pageId: 'paywall',
                                    actionId: 'preview_app_tapped',
                                    result: 'used',
                                    properties: <String, Object?>{
                                      'paywall_mode': mode.queryValue,
                                      'selected_plan':
                                          activePlanOption.serverPlanId,
                                      'billing_interval':
                                          activePlanOption.billingInterval,
                                      'preview_entry_point': 'paywall',
                                    },
                                  );
                                  await analytics.endPage(
                                    reason: 'preview_app',
                                    transitionTo: '/dashboard',
                                  );
                                  final prefs =
                                      ref.read(sharedPreferencesProvider);
                                  await prefs.setBool(
                                      kPreviewModeActiveKey, true);
                                  await prefs.setBool(
                                      kPreviewReturnToPreauthKey, false);
                                  await prefs.setString(
                                    kPreviewExitRouteKey,
                                    '/paywall?mode=${mode.queryValue}',
                                  );
                                  ref
                                      .read(previewModeProvider.notifier)
                                      .enable();
                                  if (context.mounted) {
                                    context.go('/dashboard');
                                  }
                                }());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7458FF),
                                      Color(0xFFA855F7),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      context.l10n.paywallPreviewApp,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_right_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                context.l10n.paywallCompetitorPromoText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    decoration: BoxDecoration(
                      color: colorScheme.appBackground,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.appBackground,
                          blurRadius: 16,
                          spreadRadius: 8,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (requiresAutoRenewAcknowledgement) ...[
                            GestureDetector(
                              onTap: isProcessing
                                  ? null
                                  : () {
                                      final nextValue =
                                          !hasAcknowledgedAutoRenew.value;
                                      hasAcknowledgedAutoRenew.value =
                                          nextValue;
                                      unawaited(
                                        analytics.trackAction(
                                          flowName: 'onboarding_funnel',
                                          pageId: 'paywall',
                                          actionId: 'auto_renew_ack_toggled',
                                          result: 'used',
                                          properties: <String, Object?>{
                                            'paywall_mode': mode.queryValue,
                                            'selected_plan':
                                                activePlanOption.serverPlanId,
                                            'billing_interval': activePlanOption
                                                .billingInterval,
                                            'is_checked': nextValue,
                                          },
                                        ),
                                      );
                                    },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: hasAcknowledgedAutoRenew.value,
                                        onChanged: isProcessing
                                            ? null
                                            : (value) {
                                                final nextValue =
                                                    value ?? false;
                                                hasAcknowledgedAutoRenew.value =
                                                    nextValue;
                                                unawaited(
                                                  analytics.trackAction(
                                                    flowName:
                                                        'onboarding_funnel',
                                                    pageId: 'paywall',
                                                    actionId:
                                                        'auto_renew_ack_toggled',
                                                    result: 'used',
                                                    properties: <String,
                                                        Object?>{
                                                      'paywall_mode':
                                                          mode.queryValue,
                                                      'selected_plan':
                                                          activePlanOption
                                                              .serverPlanId,
                                                      'billing_interval':
                                                          activePlanOption
                                                              .billingInterval,
                                                      'is_checked': nextValue,
                                                    },
                                                  ),
                                                );
                                              },
                                        activeColor: colorScheme.primary,
                                        checkColor: colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        side: BorderSide(
                                          color: colorScheme.outlineVariant,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        mode == PaywallMode.trial
                                            ? context.l10n.paywallTrialTerms(
                                                activePlanOption.priceDisplay,
                                                activePlanOption
                                                            .billingInterval ==
                                                        'monthly'
                                                    ? context
                                                        .l10n.paywallPeriodMonth
                                                    : context
                                                        .l10n.paywallPeriodYear)
                                            : context.l10n.paywallSubTerms(
                                                activePlanOption.priceDisplay,
                                                activePlanOption
                                                            .billingInterval ==
                                                        'monthly'
                                                    ? context
                                                        .l10n.paywallPeriodMonth
                                                    : context.l10n
                                                        .paywallPeriodYear),
                                        style: TextStyle(
                                          color: colorScheme.mutedForeground,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          PrimaryAdaptiveButton(
                            onPressed: isProcessing ||
                                    !canConfirmAutoRenew ||
                                    !isStoreReady
                                ? null
                                : onMainAction,
                            child: Center(
                              child: Text(
                                isProcessing
                                    ? context.l10n.paywallProcessing
                                    : !isStoreReady
                                        ? context.l10n
                                            .paywallErrorStoreUnavailableShort
                                        : mode == PaywallMode.trial &&
                                                activePlanOption.serverPlanId !=
                                                    'lifetime'
                                            ? context.l10n.paywallStartTrial
                                            : activePlanOption.serverPlanId ==
                                                    'lifetime'
                                                ? context
                                                    .l10n.paywallGetLifetime
                                                : context.l10n.paywallSubscribe,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: isProcessing ? null : onRestorePurchases,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                  child: Text(
                                    context.l10n.paywallRestorePurchase,
                                    style: TextStyle(
                                      color: colorScheme.mutedForeground
                                          .withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await analytics.trackAction(
                                    flowName: 'onboarding_funnel',
                                    pageId: 'paywall',
                                    actionId: 'terms_privacy_tapped',
                                    result: 'used',
                                    properties: <String, Object?>{
                                      'paywall_mode': mode.queryValue,
                                      'selected_plan':
                                          activePlanOption.serverPlanId,
                                      'billing_interval':
                                          activePlanOption.billingInterval,
                                    },
                                  );
                                  final uri = Uri.parse(
                                      'https://moneko.io/terms-of-service');
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                  child: Text(
                                    context.l10n.paywallTermsPrivacy,
                                    style: TextStyle(
                                      color: colorScheme.mutedForeground
                                          .withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- COMPONENTS ---

class _UnifiedPlanCard extends StatelessWidget {
  final List<PlanOption> plans;
  final String selectedPlanId;
  final ValueChanged<String> onPlanSelected;

  const _UnifiedPlanCard({
    required this.plans,
    required this.selectedPlanId,
    required this.onPlanSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: plans.asMap().entries.map((entry) {
          final idx = entry.key;
          final plan = entry.value;
          final isSelected = selectedPlanId == plan.id;
          final trialText = switch (plan.billingInterval) {
            'yearly' => context.l10n.paywallYearlyTrial,
            'monthly' => context.l10n.paywallMonthlyTrial,
            _ => null,
          };
          final supportingText = plan.serverPlanId == 'lifetime'
              ? context.l10n.paywallLifetimeSupport
              : context.l10n.paywallFamilySharing;
          final periodText = switch (plan.billingInterval) {
            'yearly' => context.l10n.perYear,
            'monthly' => context.l10n.perMonth,
            _ => '',
          };

          return Padding(
            padding: EdgeInsets.only(
              left: idx == 0 ? 0 : 6,
              right: idx == plans.length - 1
                  ? 24
                  : 6, // extra right padding on the last item for overscroll buffer
            ),
            child: GestureDetector(
              onTap: () => onPlanSelected(plan.id),
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints.tightFor(
                  width: 188,
                  height: 150,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF17181D) : scheme.surface,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF7458FF)
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (plan.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7458FF),
                                  Color(0xFFA855F7),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              plan.badgeText!,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (trialText != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 12,
                            color: Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trialText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      supportingText,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    RichText(
                      text: TextSpan(
                        text: plan.priceDisplay,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8B5CF6),
                          letterSpacing: -0.5,
                        ),
                        children: [
                          if (periodText.isNotEmpty)
                            TextSpan(
                              text: periodText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PaywallBackground extends StatelessWidget {
  const _PaywallBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SvgPicture.asset(
        'lib/assets/images/paywall/background-gradient.svg',
        width: MediaQuery.of(context).size.width,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _HeroAppIcon extends StatelessWidget {
  const _HeroAppIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'lib/assets/mascots/moneko-gradient.svg',
      width: 87,
      height: 87,
      fit: BoxFit.contain,
    );
  }
}

class _AppRatingBadge extends StatelessWidget {
  const _AppRatingBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contentColor = scheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Background image using laurel wreath
            Image.asset(
              'lib/assets/images/paywall/laurel-wreath.png',
              width: 170,
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '4.8',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: contentColor,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${PlatformInfo.isIOS ? context.l10n.paywallStoreLabelApple : context.l10n.paywallStoreLabelPlay} ${context.l10n.paywallRatingSuffix}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: contentColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 4; i++)
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFCB860), size: 16),
                    Stack(
                      children: [
                        Icon(Icons.star_rounded,
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                            size: 16),
                        ClipRect(
                          clipper: _FractionalClipper(0.8),
                          child: const Icon(Icons.star_rounded,
                              color: Color(0xFFFCB860), size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _FractionalClipper extends CustomClipper<Rect> {
  final double fraction;
  _FractionalClipper(this.fraction);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(covariant _FractionalClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _BenefitsChecklist extends StatelessWidget {
  const _BenefitsChecklist();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final items = [
      context.l10n.paywallBenefit1,
      context.l10n.paywallBenefit2,
      context.l10n.paywallBenefit3,
      context.l10n.paywallBenefit4,
    ];

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF8ED4),
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Pick 3 high-quality reviews that mention key value propositions
    final selectedReviews = [
      appStoreReviews.firstWhere((r) =>
          r.id == 'review-004'), // Really good budgeting app! Clean, simple.
      appStoreReviews
          .firstWhere((r) => r.id == 'review-019'), // Envelope budgeting
      appStoreReviews.firstWhere((r) =>
          r.id ==
          'review-010'), // WhatsApp integration, AI automatically does everything
    ];

    return Column(
      children: [
        Text(
          context.l10n.paywallLovedBy,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        ...selectedReviews
            .map(
              (review) => AppStoreReviewCard(
                review: review,
                margin: const EdgeInsets.only(bottom: 16),
              ),
            )
            .toList(),
      ],
    );
  }
}
