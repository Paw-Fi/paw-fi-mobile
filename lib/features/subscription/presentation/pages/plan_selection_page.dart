import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, debugPrint;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/app/router.dart' show rootNavigatorKey;
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
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/widgets/unified_plan_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/features/subscription/presentation/pages/purchase_processing_dialog_lifecycle.dart';
import 'package:go_router/go_router.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

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

enum PlanSelectionMode {
  trial,
  resubscribe,
}

enum _ProcessingDialogKind {
  iapPurchase,
  // stripeCheckout,  // Uncomment when needed
  // restorePurchases,  // Uncomment when needed
  // cancelSubscription,  // Uncomment when needed
}

extension PlanSelectionModeX on PlanSelectionMode {
  static PlanSelectionMode fromQuery(String? value) {
    return switch (value) {
      'resubscribe' => PlanSelectionMode.resubscribe,
      _ => PlanSelectionMode.trial,
    };
  }

  String get queryValue {
    return switch (this) {
      PlanSelectionMode.trial => 'trial',
      PlanSelectionMode.resubscribe => 'resubscribe',
    };
  }
}

// --- PAGE ---
class PlanSelectionPage extends HookConsumerWidget {
  const PlanSelectionPage(
      {super.key, this.mode = PlanSelectionMode.resubscribe});

  final PlanSelectionMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionManagementProvider);
    final productsAsync = ref.watch(subscriptionProductsProvider);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // View State
    final selectedPlanId = useState<String>('plus_monthly');
    final hasAcknowledgedAutoRenew = useState(false);
    final isStripeProcessing = useState(false);
    final processingDialogOpen = useState(false);
    final processingDialogKind = useState<_ProcessingDialogKind?>(null);

    final currentSub = subscriptionAsync.value;
    final currentPlanId = currentSub?.subscription?.plan ?? 'free';
    final currentInterval = currentSub?.subscription?.billingInterval;
    final currentProvider = currentSub?.subscription?.provider;
    final currentStatus = currentSub?.subscription?.status?.toLowerCase();
    final hasActiveSubscription =
        currentSub?.subscription?.isSubscribed ?? false;

    // Check if user is truly new (no subscription data exists)
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
    final didCompletePlanSelectionFlow = useRef(false);
    final checkoutAttemptCounter = useRef(0);

    void runAfterBuild(VoidCallback callback) {
      runAfterBuildIfMounted(context, callback);
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

    Future<void> completePlanSelectionFlowToDashboard({
      PlanOption? option,
      String? source,
      String? provider,
      bool includePurchaseEvent = false,
    }) async {
      if (didCompletePlanSelectionFlow.value) return;
      didCompletePlanSelectionFlow.value = true;
      didInitiateCheckout.value = false;
      didInitiateRestore.value = false;

      dismissProcessingDialog('plan selection flow completed');

      if (!context.mounted) return;

      final successMessage = source == 'restore'
          ? context.l10n.subscriptionStatusRestored
          : context.l10n.paymentSuccessfulCheckingSubscription;
      final toastContext = rootNavigatorKey.currentContext;
      final effectiveToastContext =
          toastContext != null && toastContext.mounted ? toastContext : context;
      final router = GoRouter.of(context);

      AppToast.success(effectiveToastContext, successMessage);

      if (router.canPop()) {
        router.pop();
      } else {
        context.go('/dashboard');
      }
    }

    Future<void> verifySubscriptionAndCompleteCheckout(String trigger) async {
      try {
        _debugLog(
            '🔄 verifySubscriptionAndCompleteCheckout start | trigger=$trigger');
        await ref.read(subscriptionManagementProvider.notifier).refresh();
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        if (!context.mounted) return;

        final subscriptionAsync = ref.read(subscriptionManagementProvider);
        final subscriptionData = subscriptionAsync.valueOrNull?.subscription;
        final isActive = subscriptionData?.isSubscribed ?? false;

        _debugLog(
          '📊 Checkout verification snapshot | trigger=$trigger '
          'hasValue=${subscriptionAsync.hasValue} hasError=${subscriptionAsync.hasError} '
          'plan=${subscriptionData?.plan} status=${subscriptionData?.status} '
          'provider=${subscriptionData?.provider} interval=${subscriptionData?.billingInterval} '
          'isSubscribed=$isActive',
        );

        if (isActive) {
          await completePlanSelectionFlowToDashboard(
            source: 'checkout',
            provider: 'iap',
            includePurchaseEvent: true,
          );
          return;
        }

        didInitiateCheckout.value = false;
        AppToast.error(
          context,
          'Purchase completed but subscription not activated. Please restart the app.',
        );
      } catch (e, stack) {
        _debugLog(
            '❌ verifySubscriptionAndCompleteCheckout failed | trigger=$trigger error=$e');
        _debugLog('Stack: $stack');
        didInitiateCheckout.value = false;
        if (context.mounted) {
          dismissProcessingDialog('iap verification error');
          AppToast.error(
            context,
            'Purchase completed but failed to verify subscription. Please restart the app.',
          );
        }
      }
    }

    String humanizePurchaseError(String raw, [String? code]) {
      final message = raw.trim();
      final lower = message.toLowerCase();
      if (code == purchaseOwnedByAnotherAccountCode ||
          lower.contains('linked to another moneko account') ||
          lower.contains('belongs to another account')) {
        return message.isNotEmpty
            ? message
            : 'This App Store purchase is already linked to another Moneko account.';
      }
      if (lower.contains('cancel')) return 'Purchase cancelled.';
      if (lower.contains('subscription_managed_in_app') ||
          lower.contains('managed through an in-app purchase')) {
        return 'Your subscription is managed through an in-app purchase. Please manage billing in the App Store / Play Store.';
      }
      if (lower.contains('household') || lower.contains('family')) {
        return 'Your Apple ID is part of a shared subscription. Please leave the household to manage your own subscription.';
      }
      if (lower.contains('timed out')) {
        return 'Purchase timed out. Please try again.';
      }
      if (lower.contains('not available') || lower.contains('store')) {
        return 'Store unavailable. Please try again later.';
      }
      if (lower.contains('verification')) {
        return 'Purchase verification failed. Please try again.';
      }
      return message.isNotEmpty
          ? message
          : 'Purchase failed. Please try again.';
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
          'prevErrorCode=${prevState?.lastErrorCode ?? ""} nextErrorCode=${nextState?.lastErrorCode ?? ""} '
          'prevInitiated=${prevState?.initiatedProductId ?? ""} nextInitiated=${nextState?.initiatedProductId ?? ""} '
          'prevCompleted=${prevState?.lastCompletedProductId ?? ""} nextCompleted=${nextState?.lastCompletedProductId ?? ""} '
          'storeAvailable=${nextState?.storeAvailable ?? false} '
          'dialogOpen=${processingDialogOpen.value} dialogKind=${processingDialogKind.value} '
          'didInitiateCheckout=${didInitiateCheckout.value} didSeeIapProcessing=${didSeeIapProcessing.value}',
        );

        if (next.hasError) {
          didInitiateCheckout.value = false;
          dismissProcessingDialog('provider error');
          _debugLog('IAP provider error: ${next.error}');
          showIapError(
            'Purchase failed. Please try again.',
            'provider error',
          );
          return;
        }

        final nextError = nextState?.lastError;
        final prevError = prevState?.lastError;
        final nextErrorCode = nextState?.lastErrorCode;
        _debugLog(
            '🔍 Error check: nextError="$nextError" prevError="$prevError"');
        if (nextError != null &&
            nextError.isNotEmpty &&
            nextError != prevError) {
          didInitiateCheckout.value = false;
          _debugLog('🚨 IAP purchase error detected: $nextError');
          _debugLog('🚨 Calling showIapError...');
          showIapError(nextError, 'lastError', nextErrorCode);
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
          Future.microtask(() =>
              verifySubscriptionAndCompleteCheckout('has_new_completion'));
        }

        if (!prevProcessing && nextProcessing) {
          _debugLog('⏳ IAP processing started');
          didSeeIapProcessing.value = true;
        }

        if (prevProcessing &&
            !nextProcessing &&
            nextError == null &&
            nextCompletedProductId == null) {
          _debugLog(
            '⚠️ IAP processing ended without error/completion marker; '
            'dialogOpen=${processingDialogOpen.value} initiated=${nextState?.initiatedProductId}',
          );
          if (didInitiateCheckout.value) {
            dismissProcessingDialog('iap processing ended without completion');
            Future.microtask(() => verifySubscriptionAndCompleteCheckout(
                'processing_ended_without_completion_marker'));
          }
        }
      });
    }

    useEffect(() {
      if (!useIap) return null;
      _debugLog(
        '🧭 IAP dialog effect | dialogOpen=${processingDialogOpen.value} '
        'dialogKind=${processingDialogKind.value} iapProcessing=$iapProcessing '
        'didSeeIapProcessing=${didSeeIapProcessing.value} '
        'iapLastError="$iapLastError" iapLastErrorCode=${iapLastErrorCode ?? ""}',
      );
      if (processingDialogKind.value != _ProcessingDialogKind.iapPurchase) {
        _debugLog('🧭 IAP dialog effect skip: kind is not iapPurchase');
        return null;
      }
      if (!processingDialogOpen.value) {
        _debugLog('🧭 IAP dialog effect skip: dialog already closed');
        return null;
      }

      if (iapProcessing && !didSeeIapProcessing.value) {
        didSeeIapProcessing.value = true;
        _debugLog(
            '🧭 IAP dialog effect: recovered missing processing transition -> didSeeIapProcessing=true');
      }

      if (iapLastError.isNotEmpty) {
        _debugLog('🧭 IAP dialog effect: lastError present -> showIapError');
        runAfterBuild(() => showIapError(iapLastError, 'effect'));
        return null;
      }

      if (didSeeIapProcessing.value && !iapProcessing) {
        _debugLog(
            '🧭 IAP dialog effect: processing finished -> dismiss dialog');
        runAfterBuild(() => dismissProcessingDialog('iap processing ended'));
      } else {
        _debugLog('🧭 IAP dialog effect: keep waiting');
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
          : const <SubscriptionProduct>[
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
          const order = {'monthly': 0, 'yearly': 1};
          final aOrder =
              a.billingInterval != null ? (order[a.billingInterval] ?? 2) : 2;
          final bOrder =
              b.billingInterval != null ? (order[b.billingInterval] ?? 2) : 2;
          return aOrder.compareTo(bOrder);
        });
    } else {
      // Android remains Stripe checkout (web) for now.
      plans = const [
        PlanOption(
          id: 'plus_monthly',
          serverPlanId: 'plus',
          billingInterval: 'monthly',
          name: 'Monthly',
          storePrice: null,
          displayPriceUsd: 2.99,
          tagline: 'Flexible. Cancel anytime.',
        ),
        PlanOption(
          id: 'plus_yearly',
          serverPlanId: 'plus',
          billingInterval: 'yearly',
          name: 'Yearly',
          storePrice: null,
          displayPriceUsd: 9.99,
          tagline: 'Best value for 12 months.',
          isPopular: true,
          badgeText: 'SAVE 50%',
        ),
        PlanOption(
          id: 'lifetime',
          serverPlanId: 'lifetime',
          billingInterval: null,
          name: 'Lifetime',
          storePrice: null,
          displayPriceUsd: 29.99,
          tagline: 'Pay once, own it forever.',
          badgeText: 'LIMITED',
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
        // Free user (both trial and resubscribe): default to monthly
        final monthly = plans
            .where((p) =>
                p.serverPlanId == 'plus' && p.billingInterval == 'monthly')
            .toList();
        if (monthly.isNotEmpty) {
          selectedPlanId.value = monthly.first.id;
        }
      }
      return null;
    }, [mode, currentPlanId, currentInterval, plans.length]);

    // Helpers
    final activePlanOption = plans.firstWhere(
      (p) => p.id == selectedPlanId.value,
      orElse: () => plans.first,
    );

    final requiresAutoRenewAcknowledgement =
        activePlanOption.serverPlanId != 'lifetime';
    final canConfirmAutoRenew =
        !requiresAutoRenewAcknowledgement || hasAcknowledgedAutoRenew.value;

    final isStoreReady =
        !useIap || (iapStateAsync.valueOrNull?.storeAvailable ?? false);

    useEffect(() {
      if (didCompletePlanSelectionFlow.value) return null;
      if (!hasActiveSubscription) return null;
      if (!didInitiateCheckout.value && !didInitiateRestore.value) {
        return null;
      }

      _debugLog(
        '✅ Active subscription detected on plan selection; scheduling flow completion '
        '| checkout=${didInitiateCheckout.value} restore=${didInitiateRestore.value} '
        'mode=${mode.queryValue} option=${activePlanOption.id}',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(() async {
          if (!context.mounted || didCompletePlanSelectionFlow.value) return;

          await completePlanSelectionFlowToDashboard(
            option: activePlanOption,
            source: didInitiateRestore.value ? 'restore' : 'checkout',
            provider: useIap ? 'iap' : 'stripe',
            includePurchaseEvent:
                didInitiateCheckout.value || didInitiateRestore.value,
          );
        }());
      });

      return null;
    }, [
      hasActiveSubscription,
      useIap,
      activePlanOption.id,
      mode.queryValue,
      currentSub?.subscription?.plan,
      currentSub?.subscription?.status,
      currentSub?.subscription?.provider,
    ]);

    useEffect(() {
      if (!requiresAutoRenewAcknowledgement) {
        hasAcknowledgedAutoRenew.value = true;
        return null;
      }

      hasAcknowledgedAutoRenew.value = false;
      return null;
    }, [activePlanOption.id]);

    bool isCurrentPlan(PlanOption option) {
      final shouldBlockSamePlan =
          hasActiveSubscription && currentStatus == 'active';
      if (!shouldBlockSamePlan) {
        return false;
      }

      if (option.serverPlanId == 'lifetime' && currentPlanId == 'lifetime') {
        return true;
      }
      if (option.serverPlanId == currentPlanId &&
          option.billingInterval == currentInterval) {
        return true;
      }
      return false;
    }

    if (currentPlanId == 'lifetime') {
      return const _LifetimeView();
    }

    if (useIap && productsAsync.isLoading) {
      return StatusBarOverlayRegion(
          child: AdaptiveScaffold(
        appBar: const AdaptiveAppBar(title: ''),
        body: Material(
          color: colorScheme.appBackground,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ));
    }

    if (useIap && (productsAsync.hasError || plans.isEmpty)) {
      return StatusBarOverlayRegion(
          child: AdaptiveScaffold(
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
                    'Unable to load subscription options',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  PrimaryAdaptiveButton(
                    onPressed: () => ref
                        .read(subscriptionProductsProvider.notifier)
                        .refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    Future<void> onManageStoreSubscription() async {
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
        AppToast.error(context, context.l10n.unableToOpenSubscriptionSettings);
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
      checkoutAttemptCounter.value += 1;
      final attemptId = checkoutAttemptCounter.value;
      _debugLog(
        '🧭 onMainAction start | attempt=$attemptId '
        'plan=${activePlanOption.id} serverPlan=${activePlanOption.serverPlanId} interval=${activePlanOption.billingInterval} '
        'storeReady=$isStoreReady useIap=$useIap hasActiveSubscription=$hasActiveSubscription '
        'currentPlan=$currentPlanId currentInterval=$currentInterval currentStatus=$currentStatus currentProvider=$currentProvider',
      );
      print(
          '🎯 Starting subscription flow for plan: ${activePlanOption.serverPlanId}');

      if (isCurrentPlan(activePlanOption)) {
        print('⚠️ User already on this plan');
        // Already on this plan
        AppToast.info(context, context.l10n.alreadyOnThisPlan);
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
        print('🍎 Platform check - iOS: $isIos');
        if (useIap) {
          // Don't allow purchase attempts until the store/products are ready.
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception('Store unavailable');
          }

          final catalog = activePlanOption.catalogProduct;
          print(
              '📦 catalogProduct: ${catalog != null ? "id=${catalog.storeProductId}, plan=${catalog.plan}, interval=${catalog.billingInterval}" : "NULL"}');
          if (catalog == null) throw Exception('Missing iOS product mapping');

          print('✅ catalogProduct is valid, proceeding...');

          // Show processing dialog before starting purchase
          if (context.mounted) {
            print('🎬 Showing processing dialog...');
            lastIapErrorShown.value = null;
            didSeeIapProcessing.value =
                iapStateAsync.valueOrNull?.isProcessing ?? false;
            processingDialogOpen.value = true;
            processingDialogKind.value = _ProcessingDialogKind.iapPurchase;
            _debugLog(
                '🧾 Dialog open set to true (iap). attempt=$attemptId plan=${activePlanOption.id} '
                'initialDidSeeIapProcessing=${didSeeIapProcessing.value}');
            showBlockingProcessingDialog(
              context: context,
              message: 'Processing your purchase...',
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
            await startStripeCheckout(activePlanOption);
            await completePlanSelectionFlowToDashboard(
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
        didInitiateCheckout.value = false;

        if (context.mounted) {
          _debugLog('Purchase flow threw: $e');

          final raw = e.toString();
          final lower = raw.toLowerCase();
          final isCanceled = lower.contains('cancel');
          final isManagedInApp =
              lower.contains('subscription_managed_in_app') ||
                  lower.contains('managed through an in-app purchase');

          if (isManagedInApp) {
            final result = await MonekoAlertDialog.show(
              context: context,
              title: 'Manage subscription in Play Store',
              description:
                  'Your subscription is managed through an in-app purchase. Please manage billing in the Play Store.',
              confirmLabel: 'Open Play Store',
              cancelLabel: 'Cancel',
            );
            if (result?.confirmed == true) {
              await onManageStoreSubscription();
            }
            return;
          }

          if (isCanceled) {
            AppToast.info(context, context.l10n.paymentCanceled);
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
      if (context.mounted) {
        processingDialogOpen.value = true;
        _debugLog('🧾 Dialog open set to true (restore purchases)');
        showBlockingProcessingDialog(
          context: context,
          message: 'Restoring purchases...',
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
          await completePlanSelectionFlowToDashboard(
            option: activePlanOption,
            source: 'restore',
            provider: useIap ? 'iap' : 'stripe',
            includePurchaseEvent: true,
          );
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
            context, 'Failed to restore: Purchase failed. Please try again.');
      } catch (e) {
        didInitiateRestore.value = false;
        if (context.mounted) {
          AppToast.error(
              context, '${context.l10n.failedToRestore}: ${e.toString()}');
        }
      } finally {
        dismissProcessingDialog('restore purchases');
      }
    }

    Future<void> onCancelSubscription() async {
      final result = await MonekoAlertDialog.show(
        context: context,
        title: 'Cancel Subscription',
        description:
            'Are you sure? You will lose access to premium features at the end of your current billing period.',
        confirmLabel: 'Confirm Cancellation',
        cancelLabel: 'Keep Plan',
        isDestructive: true,
      );

      if (result?.confirmed == true) {
        if (context.mounted) {
          processingDialogOpen.value = true;
          _debugLog('🧾 Dialog open set to true (cancel subscription)');
          showBlockingProcessingDialog(
            context: context,
            message: 'Cancelling subscription...',
          );
        }

        try {
          await ref
              .read(subscriptionManagementProvider.notifier)
              .cancelSubscription();
          if (context.mounted) {
            AppToast.success(context, context.l10n.subscriptionCancelled);
          }
        } catch (e) {
          if (context.mounted) {
            AppToast.error(context, e.toString());
          }
        } finally {
          dismissProcessingDialog('cancel subscription');
        }
      }
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: ''),
      body: Material(
        color: colorScheme.appBackground,
        child: Stack(
          children: [
            const PaywallBackgroundDecoration(),
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
                            // Header
                            const SizedBox(height: 24),
                            Text(
                              mode == PlanSelectionMode.trial
                                  ? 'Start your free trial'
                                  : 'Subscribe Now',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mode == PlanSelectionMode.trial
                                  ? 'Pick a plan. You won\'t be charged until your trial ends.'
                                  : 'Pick a plan to get back to full access.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const PaywallHeroIcon(),
                            const SizedBox(height: 24),
                            const PaywallAppRatingBadge(),
                            const SizedBox(height: 32),

                            // --- SUBSCRIPTION PLANS ---
                            UnifiedPlanCard(
                              plans: plans,
                              selectedPlanId: selectedPlanId.value,
                              onPlanSelected: (id) => selectedPlanId.value = id,
                              isCurrentPlan: isCurrentPlan,
                              isNewUser: isNewUser,
                            ),

                            const SizedBox(height: 12),
                            const PaywallBenefitsChecklist(),
                            const SizedBox(height: 40),
                            const PaywallReviewsSection(),
                            const SizedBox(height: 12),
                            const _LegalLinks(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    decoration: BoxDecoration(
                      color: colorScheme.appBackground,
                      border: Border(
                          top: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (requiresAutoRenewAcknowledgement) ...[
                          CheckboxListTile(
                            value: hasAcknowledgedAutoRenew.value,
                            onChanged: isProcessing
                                ? null
                                : (value) => hasAcknowledgedAutoRenew.value =
                                    value ?? false,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: colorScheme.primary,
                            checkColor: colorScheme.onPrimary,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              mode == PlanSelectionMode.trial
                                  ? 'I understand that my free trial will last for 30 days, and will auto-renew at ${activePlanOption.priceDisplay}${activePlanOption.billingInterval == 'monthly' ? '/month' : '/year'} until cancelled.'
                                  : context.l10n.paywallSubTerms(
                                      activePlanOption.priceDisplay,
                                      activePlanOption.billingInterval ==
                                              'monthly'
                                          ? '/month'
                                          : '/year',
                                    ),
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        PrimaryAdaptiveButton(
                          onPressed: isProcessing ||
                                  !canConfirmAutoRenew ||
                                  !isStoreReady ||
                                  isCurrentPlan(activePlanOption)
                              ? null
                              : onMainAction,
                          child: Text(
                            isProcessing
                                ? 'Processing...'
                                : !isStoreReady
                                    ? 'Store unavailable'
                                    : isCurrentPlan(activePlanOption)
                                        ? 'Current Plan'
                                        : mode == PlanSelectionMode.trial &&
                                                activePlanOption.serverPlanId !=
                                                    'lifetime'
                                            ? 'Start your free month'
                                            : activePlanOption.serverPlanId ==
                                                    'lifetime'
                                                ? 'Get Lifetime Access'
                                                : 'Subscribe for ${activePlanOption.priceDisplay} ${activePlanOption.billingInterval == 'monthly' ? '/mo' : '/yr'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        // Cancel / Manage Subscription Button
                        // ONLY shown if user is NOT on free plan
                        if (currentPlanId != 'free' &&
                            (currentProvider == null ||
                                (currentProvider != 'app_store' &&
                                    currentProvider != 'play_store'))) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: isProcessing ? null : onCancelSubscription,
                            child: Text(
                              'Cancel Subscription',
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: colorScheme.mutedForeground
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],

                        if (currentPlanId != 'free' &&
                            (currentProvider == 'app_store' ||
                                currentProvider == 'play_store') &&
                            currentPlanId != 'lifetime') ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap:
                                isProcessing ? null : onManageStoreSubscription,
                            child: Text(
                              'Manage Subscription',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    colorScheme.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],

                        // Restore Purchases (Always visible)
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: isProcessing ? null : onRestorePurchases,
                          child: Text(
                            'Restore Purchases',
                            style: TextStyle(
                              color: colorScheme.mutedForeground
                                  .withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

// --- COMPONENTS ---

class _LifetimeView extends StatelessWidget {
  const _LifetimeView();

  @override
  Widget build(BuildContext context) {
    return StatusBarOverlayRegion(
      child: AdaptiveScaffold(
        appBar: const AdaptiveAppBar(title: ''),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.activeLifetimeStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.paywallLifetimeSupport,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.mutedForeground,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://moneko.io/terms-of-service');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          context.l10n.paywallTermsPrivacy,
          style: TextStyle(
            color: colorScheme.mutedForeground.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}


