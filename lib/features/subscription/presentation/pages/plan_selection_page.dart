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
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/iap_restore_polling.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/presentation/widgets/family_sharing_restored_dialog.dart';
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
const String membershipDashboardUrl =
    'https://moneko.io/dashboard/user-settings/membership';

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
    final selectedPlanId = useState<String?>(null);
    final hasAcknowledgedAutoRenew = useState(false);
    final isStripeProcessing = useState(false);
    final processingDialogOpen = useState(false);
    final processingDialogKind = useState<_ProcessingDialogKind?>(null);

    final currentSub = subscriptionAsync.value;
    final currentPlanId = currentSub?.subscription?.plan ?? 'free';
    final currentInterval = currentSub?.subscription?.billingInterval;
    final currentProvider = currentSub?.subscription?.provider;
    final currentStatus = currentSub?.subscription?.status?.toLowerCase();
    final renewalInfoLabel = currentSub?.renewalInfo(context.l10n);
    final hasActiveSubscription =
        currentSub?.subscription?.isSubscribed ?? false;
    final currentSubscription = currentSub?.subscription;
    final isHouseholdSharedSubscription =
        currentSubscription?.boundToUserId != null;
    final isFamilySharedSubscription =
        currentSubscription?.isAppStoreFamilyShared ?? false;
    final isAppStoreManagedSubscription = currentProvider == 'app_store' ||
        currentSubscription?.appStoreInAppOwnershipType != null;
    final isPlayStoreManagedSubscription = currentProvider == 'play_store';
    final isStoreManagedSubscription = currentSubscription?.isIap ?? false;
    final canManageCurrentSubscription = currentPlanId != 'free' &&
        currentPlanId != 'lifetime' &&
        !isHouseholdSharedSubscription &&
        !isFamilySharedSubscription;

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
    final didInitiateFamilyAutoRestore = useRef(false);
    final didAttemptFamilyAutoRestore = useRef(false);
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
      final isFamilyAutoRestore = source == 'family_sharing';
      didInitiateCheckout.value = false;
      didInitiateRestore.value = false;
      didInitiateFamilyAutoRestore.value = false;

      dismissProcessingDialog('plan selection flow completed');

      if (!context.mounted) return;

      if (isFamilyAutoRestore) {
        final restoredDetails =
            ref.read(subscriptionManagementProvider).valueOrNull;
        await showAppStoreAccessRestoredDialog(
          context,
          planName: restoredDetails?.planDisplayName(context.l10n) ??
              context.l10n.plus,
          isFamilyShared:
              restoredDetails?.subscription?.isAppStoreFamilyShared ?? false,
        );
        if (!context.mounted) return;
      }

      final successMessage = source == 'restore'
          ? context.l10n.subscriptionStatusRestored
          : context.l10n.paymentSuccessfulCheckingSubscription;
      final toastContext = rootNavigatorKey.currentContext;
      final effectiveToastContext =
          toastContext != null && toastContext.mounted ? toastContext : context;
      final router = GoRouter.of(context);

      if (!isFamilyAutoRestore) {
        AppToast.success(effectiveToastContext, successMessage);
      }

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
          context.l10n.paywallErrorNotActivated,
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
            context.l10n.paywallErrorVerificationFailedRestart,
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
            context.l10n.paywallErrorGeneric,
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
          if (didInitiateFamilyAutoRestore.value &&
              !didInitiateCheckout.value &&
              !didInitiateRestore.value) {
            didInitiateFamilyAutoRestore.value = false;
            _debugLog('Auto family restore ended with IAP error: $nextError');
            return;
          }
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
      plans = [
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
        PlanOption(
          id: 'lifetime',
          serverPlanId: 'lifetime',
          billingInterval: null,
          name: context.l10n.lifetime,
          storePrice: null,
          displayPriceUsd: Constants.subscriptionLifetimePrice,
          tagline: context.l10n.paywallPlanLifetimeTagline,
          badgeText: context.l10n.paywallBadgeLimited,
        ),
      ];
    }

    // Keep selection valid when plan options refresh.
    useEffect(() {
      if (selectedPlanId.value != null &&
          !plans.any((p) => p.id == selectedPlanId.value)) {
        selectedPlanId.value = null;
      }
      return null;
    }, [plans.length]);

    // Helpers
    PlanOption? activePlanOption;
    for (final option in plans) {
      if (option.id == selectedPlanId.value) {
        activePlanOption = option;
        break;
      }
    }

    final requiresAutoRenewAcknowledgement =
        activePlanOption != null && activePlanOption.serverPlanId != 'lifetime';
    final canConfirmAutoRenew = activePlanOption != null &&
        (!requiresAutoRenewAcknowledgement || hasAcknowledgedAutoRenew.value);

    final isStoreReady =
        !useIap || (iapStateAsync.valueOrNull?.storeAvailable ?? false);

    Future<void> refreshSubscriptionState() async {
      ref.invalidate(subscriptionNotifierProvider);
      await ref.read(subscriptionManagementProvider.notifier).refresh();
    }

    Future<bool> restoreIapEntitlement({required bool showProcessing}) async {
      final iapState = iapStateAsync.valueOrNull;
      if (!useIap || iapState == null || !iapState.storeAvailable) {
        return false;
      }

      if (showProcessing && context.mounted) {
        processingDialogOpen.value = true;
        _debugLog('🧾 Dialog open set to true (plan selection restore)');
        showBlockingProcessingDialog(
          context: context,
          message: context.l10n.paywallRestoringPurchases,
        );
      }

      return restoreAndWaitForIapSubscription(
        restorePurchases: () =>
            ref.read(iapControllerProvider.notifier).restorePurchases(),
        refreshSubscription: refreshSubscriptionState,
        hasActiveSubscription: () {
          final restoredSubscription = ref
              .read(subscriptionManagementProvider)
              .valueOrNull
              ?.subscription;
          return restoredSubscription?.isSubscribed ?? false;
        },
        restoreError: () =>
            ref.read(iapControllerProvider).valueOrNull?.lastError ?? '',
        maxRefreshAttempts: showProcessing ? 6 : 1,
        retryDelay: showProcessing ? const Duration(seconds: 1) : Duration.zero,
      );
    }

    useEffect(() {
      if (!useIap ||
          didAttemptFamilyAutoRestore.value ||
          hasActiveSubscription ||
          isProcessing ||
          !isStoreReady ||
          productsAsync.isLoading ||
          plans.isEmpty) {
        return null;
      }

      didAttemptFamilyAutoRestore.value = true;
      didInitiateFamilyAutoRestore.value = true;
      unawaited(() async {
        try {
          final isRestored = await restoreIapEntitlement(showProcessing: false);
          if (!context.mounted) return;
          if (isRestored) {
            await completePlanSelectionFlowToDashboard(
              option: activePlanOption,
              source: 'family_sharing',
              provider: 'iap',
              includePurchaseEvent: false,
            );
          } else {
            didInitiateFamilyAutoRestore.value = false;
          }
        } catch (e, stack) {
          didInitiateFamilyAutoRestore.value = false;
          _debugLog('Auto family restore skipped: $e');
          _debugLog('Stack: $stack');
        }
      }());

      return null;
    }, [
      useIap,
      hasActiveSubscription,
      isProcessing,
      isStoreReady,
      productsAsync.isLoading,
      plans.length,
    ]);

    useEffect(() {
      if (didCompletePlanSelectionFlow.value) return null;
      if (!hasActiveSubscription) return null;
      if (!didInitiateCheckout.value &&
          !didInitiateRestore.value &&
          !didInitiateFamilyAutoRestore.value) {
        return null;
      }

      _debugLog(
        '✅ Active subscription detected on plan selection; scheduling flow completion '
        '| checkout=${didInitiateCheckout.value} restore=${didInitiateRestore.value} '
        'mode=${mode.queryValue} option=${activePlanOption?.id ?? 'none'}',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(() async {
          if (!context.mounted || didCompletePlanSelectionFlow.value) return;

          await completePlanSelectionFlowToDashboard(
            option: activePlanOption,
            source: didInitiateFamilyAutoRestore.value
                ? 'family_sharing'
                : didInitiateRestore.value
                    ? 'restore'
                    : 'checkout',
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
      activePlanOption?.id,
      mode.queryValue,
      currentSub?.subscription?.plan,
      currentSub?.subscription?.status,
      currentSub?.subscription?.provider,
    ]);

    useEffect(() {
      if (activePlanOption == null) {
        hasAcknowledgedAutoRenew.value = false;
        return null;
      }

      if (!requiresAutoRenewAcknowledgement) {
        hasAcknowledgedAutoRenew.value = true;
        return null;
      }

      hasAcknowledgedAutoRenew.value = false;
      return null;
    }, [activePlanOption?.id]);

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

    String resolveSubscriptionStatusLabel() {
      return switch (currentStatus) {
        'active' => currentPlanId == 'lifetime'
            ? context.l10n.activeLifetimeStatus
            : context.l10n.activeStatus,
        'trialing' => context.l10n.trialStatus,
        'canceled' => context.l10n.canceledStatus,
        'past_due' => context.l10n.pastDueStatus,
        _ => context.l10n.freePlan,
      };
    }

    Future<void> openMembershipDashboardOnWeb() async {
      final uri = Uri.parse(membershipDashboardUrl);
      var launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      if (!launched && context.mounted) {
        AppToast.error(context, context.l10n.couldNotOpenMembershipPage);
      }
    }

    Future<void> onManageMembership() async {
      if (!canManageCurrentSubscription) {
        return;
      }

      if (isStoreManagedSubscription) {
        final storeProductId = currentSubscription?.storeProductId;
        final uri = isAppStoreManagedSubscription ||
                (!isPlayStoreManagedSubscription &&
                    defaultTargetPlatform == TargetPlatform.iOS)
            ? Uri.parse('https://apps.apple.com/account/subscriptions')
            : Uri.parse(
                'https://play.google.com/store/account/subscriptions?package=com.moneko.mobile${storeProductId != null ? '&sku=$storeProductId' : ''}',
              );
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          AppToast.error(
              context, context.l10n.unableToOpenSubscriptionSettings);
        }
        return;
      }

      await openMembershipDashboardOnWeb();
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
                    onPressed: () => ref
                        .read(subscriptionProductsProvider.notifier)
                        .refresh(),
                    child: Text(context.l10n.retry),
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
      final storeProductId = currentSubscription?.storeProductId;
      final uri = isAppStoreManagedSubscription ||
              (!isPlayStoreManagedSubscription &&
                  defaultTargetPlatform == TargetPlatform.iOS)
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
      final selectedPlan = activePlanOption;
      if (selectedPlan == null) {
        return;
      }

      checkoutAttemptCounter.value += 1;
      final attemptId = checkoutAttemptCounter.value;
      _debugLog(
        '🧭 onMainAction start | attempt=$attemptId '
        'plan=${selectedPlan.id} serverPlan=${selectedPlan.serverPlanId} interval=${selectedPlan.billingInterval} '
        'storeReady=$isStoreReady useIap=$useIap hasActiveSubscription=$hasActiveSubscription '
        'currentPlan=$currentPlanId currentInterval=$currentInterval currentStatus=$currentStatus currentProvider=$currentProvider',
      );
      print(
          '🎯 Starting subscription flow for plan: ${selectedPlan.serverPlanId}');

      if (isCurrentPlan(selectedPlan)) {
        print('⚠️ User already on this plan');
        // Already on this plan
        AppToast.info(context, context.l10n.alreadyOnThisPlan);
        return;
      }

      // Android subscription upgrades/downgrades require passing ChangeSubscriptionParam
      // with the existing PurchaseDetails. To avoid accidental double subscriptions,
      // we direct users to manage plan changes in Google Play for now.

      _debugLog(
        '🧾 Confirmed selection | plan=${selectedPlan.id} serverPlan=${selectedPlan.serverPlanId} interval=${selectedPlan.billingInterval} useIap=$useIap',
      );
      try {
        didInitiateCheckout.value = true;
        print('🍎 Platform check - iOS: $isIos');
        if (useIap) {
          // Don't allow purchase attempts until the store/products are ready.
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception(context.l10n.paywallErrorStoreUnavailableShort);
          }

          final catalog = selectedPlan.catalogProduct;
          print(
              '📦 catalogProduct: ${catalog != null ? "id=${catalog.storeProductId}, plan=${catalog.plan}, interval=${catalog.billingInterval}" : "NULL"}');
          if (catalog == null) {
            throw Exception(context.l10n.paywallErrorMissingProductMapping);
          }

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
                '🧾 Dialog open set to true (iap). attempt=$attemptId plan=${selectedPlan.id} '
                'initialDidSeeIapProcessing=${didSeeIapProcessing.value}');
            showBlockingProcessingDialog(
              context: context,
              message: context.l10n.paywallProcessingPurchase,
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
            await startStripeCheckout(selectedPlan);
            await completePlanSelectionFlowToDashboard(
              option: selectedPlan,
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
              title: context.l10n.paywallManageSubscriptionPlayStore,
              description: context.l10n.paywallErrorManagedInPlayStore,
              confirmLabel: context.l10n.paywallOpenPlayStore,
              cancelLabel: context.l10n.cancel,
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
      didInitiateRestore.value = true;
      lastIapErrorShown.value = null;
      didSeeIapProcessing.value = false;

      try {
        final isRestored = await restoreIapEntitlement(showProcessing: true);
        if (!context.mounted) return;

        if (isRestored) {
          await completePlanSelectionFlowToDashboard(source: 'restore');
          return;
        }

        didInitiateRestore.value = false;
        final restoredIapState = ref.read(iapControllerProvider).valueOrNull;
        final restoreError = restoredIapState?.lastError ?? '';
        if (restoreError.isNotEmpty) {
          AppToast.error(
            context,
            humanizePurchaseError(
                restoreError, restoredIapState?.lastErrorCode),
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
        dismissProcessingDialog('plan selection restore purchases');
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
                            const SizedBox(height: 50),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                currentSub?.planDisplayName(
                                                        context.l10n) ??
                                                    context.l10n.freePlan,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.foreground,
                                                  letterSpacing: -0.2,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                resolveSubscriptionStatusLabel()
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: colorScheme.primary,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            if (isFamilySharedSubscription) ...[
                                              const SizedBox(width: 6),
                                              const Flexible(
                                                child: _FamilySharingBadge(),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (renewalInfoLabel != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            renewalInfoLabel,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  colorScheme.mutedForeground,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (canManageCurrentSubscription) ...[
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: isProcessing
                                          ? null
                                          : onManageMembership,
                                      child: Text(
                                        context.l10n.manage,
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
                              selectedPlanId: selectedPlanId.value ?? '',
                              onPlanSelected: (id) => selectedPlanId.value = id,
                              isCurrentPlan: isCurrentPlan,
                              isNewUser: isNewUser,
                            ),

                            const SizedBox(height: 12),
                            const PaywallBenefitsChecklist(),
                            const SizedBox(height: 40),
                            const PaywallReviewsSection(),
                            const SizedBox(height: 12),
                            if (useIap)
                              _PlanSelectionFooterLinks(
                                isProcessing: isProcessing || !isStoreReady,
                                onRestorePurchases: onRestorePurchases,
                              )
                            else
                              const _LegalLinks(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Actions (shown only after explicit plan selection)
                  if (activePlanOption != null)
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
                                    ? context.l10n.paywallTrialTerms(
                                        activePlanOption.billingInterval ==
                                                'monthly'
                                            ? context.l10n.perMonth
                                            : context.l10n.perYear,
                                        activePlanOption.priceDisplay,
                                      )
                                    : context.l10n.paywallSubTerms(
                                        activePlanOption.billingInterval ==
                                                'monthly'
                                            ? context.l10n.perMonth
                                            : context.l10n.perYear,
                                        activePlanOption.priceDisplay,
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
                                  ? context.l10n.paywallProcessing
                                  : !isStoreReady
                                      ? context.l10n
                                          .paywallErrorStoreUnavailableShort
                                      : isCurrentPlan(activePlanOption)
                                          ? context.l10n.alreadyOnThisPlan
                                          : mode == PlanSelectionMode.trial &&
                                                  activePlanOption
                                                          .serverPlanId !=
                                                      'lifetime'
                                              ? context.l10n.paywallStartTrial
                                              : activePlanOption.serverPlanId ==
                                                      'lifetime'
                                                  ? context
                                                      .l10n.paywallGetLifetime
                                                  : '${context.l10n.paywallSubscribe} ${activePlanOption.priceDisplay} ${activePlanOption.billingInterval == 'monthly' ? context.l10n.perMonth : context.l10n.perYear}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (currentPlanId != 'free' &&
                              isStoreManagedSubscription &&
                              !isFamilySharedSubscription &&
                              currentPlanId != 'lifetime') ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: isProcessing
                                  ? null
                                  : onManageStoreSubscription,
                              child: Text(
                                context.l10n.paywallManageSubscriptionPlayStore,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: colorScheme.primary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
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

class _PlanSelectionFooterLinks extends StatelessWidget {
  const _PlanSelectionFooterLinks({
    required this.isProcessing,
    required this.onRestorePurchases,
  });

  final bool isProcessing;
  final VoidCallback onRestorePurchases;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final linkStyle = TextStyle(
      color: colorScheme.mutedForeground.withValues(alpha: 0.8),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: isProcessing ? null : onRestorePurchases,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Text(
              context.l10n.paywallRestorePurchase,
              style: linkStyle,
            ),
          ),
        ),
        Text('|', style: linkStyle),
        const _LegalLinks(),
      ],
    );
  }
}

class _FamilySharingBadge extends StatelessWidget {
  const _FamilySharingBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        context.l10n.onboardingFinishHighlightHouseholdTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
          letterSpacing: 0.2,
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
