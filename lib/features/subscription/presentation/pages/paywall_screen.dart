import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/iap_restore_polling.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/presentation/subscription_checkout_shared.dart';
import 'package:moneko/features/subscription/presentation/paywall_plan_selection.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/presentation/widgets/family_sharing_restored_dialog.dart';
import 'package:moneko/features/subscription/presentation/widgets/unified_plan_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/features/subscription/presentation/pages/purchase_processing_dialog_lifecycle.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';


const bool forceUseStripeCheckout = false;
const String purchaseOwnedByAnotherAccountCode =
    'PURCHASE_OWNED_BY_ANOTHER_ACCOUNT';

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

// --- PAGE ---
class PaywallScreen extends HookConsumerWidget {
  const PaywallScreen({super.key, this.mode = PaywallMode.resubscribe});

  final PaywallMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionManagementProvider);
    final routerSubscriptionAsync = ref.watch(subscriptionNotifierProvider);
    final productsAsync = ref.watch(subscriptionProductsProvider);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // View State
    final selectedPlanId = useState<String>('plus_yearly');
    final hasAcknowledgedAutoRenew = useState(false);
    final isStripeProcessing = useState(false);
    final processingDialogOpen = useState(false);
    final processingDialogKind = useState<_ProcessingDialogKind?>(null);

    final currentSub = subscriptionAsync.value;
    final directSubscription = routerSubscriptionAsync.valueOrNull;
    final effectiveSubscription =
        currentSub?.subscription ?? directSubscription;
    final currentPlanId = effectiveSubscription?.plan ?? 'free';
    final currentInterval = effectiveSubscription?.billingInterval;
    final currentStatus = effectiveSubscription?.status?.toLowerCase();
    final currentProvider = effectiveSubscription?.provider;
    final normalizedProvider = currentProvider?.toLowerCase().trim();
    final hasLegacyAppStoreOwnership =
        effectiveSubscription?.appStoreInAppOwnershipType != null;
    final isLegacyAppStoreManagedSubscription =
        (normalizedProvider == null || normalizedProvider.isEmpty) &&
            hasLegacyAppStoreOwnership;
    final isAppStoreManagedSubscription = normalizedProvider == 'app_store' ||
        isLegacyAppStoreManagedSubscription;
    final isPlayStoreManagedSubscription = normalizedProvider == 'play_store';
    final hasActiveSubscription =
        (currentSub?.subscription?.isSubscribed ?? false) ||
            (directSubscription?.isSubscribed ?? false);
    final useIap = shouldUseAppStoreCheckout(
      forceStripeCheckout: forceUseStripeCheckout,
    );

    // Avoid accidentally registering multiple listeners across rebuilds.
    final didRegisterIapListener = useRef(false);

    // Track processing state for UI
    final isProcessing =
        (useIap ? (iapStateAsync.value?.isProcessing ?? false) : false) ||
            isStripeProcessing.value;

    final iapProcessing = iapStateAsync.valueOrNull?.isProcessing ?? false;
    final iapLastError = iapStateAsync.valueOrNull?.lastError ?? '';
    final iapLastErrorCode = iapStateAsync.valueOrNull?.lastErrorCode;
    final iapLastCanceledProductId =
        iapStateAsync.valueOrNull?.lastCanceledProductId;
    final lastIapErrorShown = useRef<String?>(null);
    final didSeeIapProcessing = useRef(false);
    final didInitiateCheckout = useRef(false);
    final didInitiateRestore = useRef(false);
    final didInitiateFamilyAutoRestore = useRef(false);
    final didAttemptFamilyAutoRestore = useRef(false);
    final didCompletePaywallFlow = useRef(false);
    final checkoutPlanOption = useRef<PlanOption?>(null);
    final lastPresentedPlanKey = useRef<String?>(null);

    void runAfterBuild(VoidCallback callback) {
      runAfterBuildIfMounted(context, callback);
    }

    Future<void> completePaywallFlowToDashboard({
      required PlanOption option,
      required String source,
      required String provider,
      required bool includePurchaseEvent,
    }) async {
      if (didCompletePaywallFlow.value) return;
      didCompletePaywallFlow.value = true;
      final isFamilyAutoRestore = source == 'family_sharing';

      didInitiateCheckout.value = false;
      didInitiateRestore.value = false;
      didInitiateFamilyAutoRestore.value = false;
      checkoutPlanOption.value = null;

      if (context.mounted) {
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

        if (provider == 'stripe') {
          AppToast.success(
            context,
            context.l10n.paymentSuccessfulCheckingSubscription,
          );
        }
        context.go('/dashboard');
      }
    }

    void dismissProcessingDialog([String? reason]) {
      dismissProcessingDialogSafely<_ProcessingDialogKind>(
        context: context,
        dialogOpen: processingDialogOpen,
        dialogKind: processingDialogKind,
        reason: reason,
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

    Future<void> verifyIapSubscriptionAndCompleteCheckout(
        String trigger) async {
      try {
        await ref.read(subscriptionNotifierProvider.notifier).refresh();
        await ref.read(subscriptionManagementProvider.notifier).refresh();

        // Give the Edge Function/Supabase read path a short propagation window.
        await Future.delayed(const Duration(milliseconds: 1000));

        if (!context.mounted) return;

        final subscriptionAsync = ref.read(subscriptionManagementProvider);
        final subscriptionDetails = subscriptionAsync.valueOrNull;
        final subscriptionData = subscriptionDetails?.subscription;
        final directSubscription =
            ref.read(subscriptionNotifierProvider).valueOrNull;
        final isActive = (subscriptionData?.isSubscribed ?? false) ||
            (directSubscription?.isSubscribed ?? false);
        final completedOption = checkoutPlanOption.value;
        final hasExpectedPlan = completedOption == null
            ? isActive
            : _subscriptionMatchesPlan(subscriptionData, completedOption) ||
                _subscriptionMatchesPlan(directSubscription, completedOption);

        if (hasExpectedPlan) {
          if (completedOption == null) {
            didCompletePaywallFlow.value = true;
            didInitiateCheckout.value = false;
            checkoutPlanOption.value = null;
            context.go('/dashboard');
            return;
          }

          await completePaywallFlowToDashboard(
            option: completedOption,
            source: 'checkout',
            provider: 'iap',
            includePurchaseEvent: true,
          );
          return;
        }

        didInitiateCheckout.value = false;
        checkoutPlanOption.value = null;
        AppToast.error(
          context,
          context.l10n.paywallErrorNotActivated,
        );
      } catch (e) {
        didInitiateCheckout.value = false;
        checkoutPlanOption.value = null;

        if (context.mounted) {
          dismissProcessingDialog('iap verification error');
          AppToast.error(
            context,
            context.l10n.paywallErrorVerificationFailedRestart,
          );
        }
      }
    }

    if (useIap && !didRegisterIapListener.value) {
      didRegisterIapListener.value = true;
      ref.listen<AsyncValue<IapState>>(iapControllerProvider, (prev, next) {
        if (!context.mounted) return;

        final prevState = prev?.valueOrNull;
        final nextState = next.valueOrNull;
        final prevProcessing = prevState?.isProcessing ?? false;
        final nextProcessing = nextState?.isProcessing ?? false;

        if (next.hasError) {
          didInitiateCheckout.value = false;
          checkoutPlanOption.value = null;
          dismissProcessingDialog('provider error');

          showIapError(
            context.l10n.paywallErrorGeneric,
            'provider error',
          );
          return;
        }

        final previousCanceledProductId = prevState?.lastCanceledProductId;
        final nextCanceledProductId = nextState?.lastCanceledProductId;
        final hasNewCancellation = nextCanceledProductId != null &&
            nextCanceledProductId != previousCanceledProductId;
        if (hasNewCancellation && didInitiateCheckout.value) {
          didInitiateCheckout.value = false;
          checkoutPlanOption.value = null;
          runAfterBuild(() {
            dismissProcessingDialog('user cancelled StoreKit purchase');
            AppToast.info(context, context.l10n.paymentCanceled);
          });
          return;
        }

        final nextError = nextState?.lastError;
        final prevError = prevState?.lastError;

        if (nextError != null &&
            nextError.isNotEmpty &&
            nextError != prevError) {
          if (didInitiateFamilyAutoRestore.value &&
              !didInitiateCheckout.value &&
              !didInitiateRestore.value) {
            didInitiateFamilyAutoRestore.value = false;

            return;
          }

          didInitiateCheckout.value = false;
          checkoutPlanOption.value = null;
          showIapError(nextError, 'lastError');
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
          dismissProcessingDialog('user-initiated purchase completed');

          // User-initiated purchase completed successfully - navigate to dashboard

          // Schedule async work without blocking the listener
          Future.microtask(
            () => verifyIapSubscriptionAndCompleteCheckout(
              'has_new_completion',
            ),
          );
        }

        if (!prevProcessing && nextProcessing) {
          didSeeIapProcessing.value = true;
        }

        if (prevProcessing &&
            !nextProcessing &&
            nextError == null &&
            nextCompletedProductId == null) {
          if (didInitiateCheckout.value) {
            dismissProcessingDialog('iap processing ended without completion');
            Future.microtask(
              () => verifyIapSubscriptionAndCompleteCheckout(
                'processing_ended_without_completion_marker',
              ),
            );
          }
        }
      });
    }

    useEffect(() {
      if (!useIap) return null;
      if (processingDialogKind.value != _ProcessingDialogKind.iapPurchase) {
        return null;
      }
      if (!processingDialogOpen.value) return null;

      if (iapLastCanceledProductId != null && didInitiateCheckout.value) {
        didInitiateCheckout.value = false;
        checkoutPlanOption.value = null;
        runAfterBuild(() {
          dismissProcessingDialog('user cancelled StoreKit purchase');
          AppToast.info(context, context.l10n.paymentCanceled);
        });
        return null;
      }

      if (iapProcessing && !didSeeIapProcessing.value) {
        didSeeIapProcessing.value = true;
      }

      if (iapLastError.isNotEmpty &&
          (didInitiateCheckout.value || didInitiateRestore.value)) {
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
      iapLastCanceledProductId,
      processingDialogOpen.value,
      processingDialogKind.value,
    ]);

    final plans = buildPlusPlanOptions(
      context: context,
      useIap: useIap,
      productsAsync: productsAsync,
      iapStateAsync: iapStateAsync,
    );

    // Effect: If user is already on a plan, try to select it visually
    useEffect(() {
      final nextSelection = selectPaywallPlanId(
        currentPlanId: currentPlanId,
        currentInterval: currentInterval,
        plans: plans,
        currentSelection: selectedPlanId.value,
      );
      if (nextSelection != null) {
        selectedPlanId.value = nextSelection;
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
      return null;
    }, [
      plans.length,
      hasActiveSubscription,
      mode.queryValue,
      activePlanOption.id,
      activePlanOption.serverPlanId,
      activePlanOption.billingInterval,
    ]);

    final requiresAutoRenewAcknowledgement =
        activePlanOption.serverPlanId != 'lifetime';
    final canConfirmAutoRenew =
        !requiresAutoRenewAcknowledgement || hasAcknowledgedAutoRenew.value;

    final isStoreReady =
        !useIap || (iapStateAsync.valueOrNull?.storeAvailable ?? false);

    Future<void> refreshSubscriptionState() async {
      await ref.read(subscriptionNotifierProvider.notifier).refresh();
      await ref.read(subscriptionManagementProvider.notifier).refresh();
    }

    Future<bool> restoreIapEntitlementQuietly() async {
      final iapState = iapStateAsync.valueOrNull;
      if (!useIap || iapState == null || !iapState.storeAvailable) {
        return false;
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
          final isRestored = await restoreIapEntitlementQuietly();
          if (!context.mounted) return;
          if (isRestored) {
            await completePaywallFlowToDashboard(
              option: activePlanOption,
              source: 'family_sharing',
              provider: 'iap',
              includePurchaseEvent: false,
            );
          } else {
            didInitiateFamilyAutoRestore.value = false;
          }
        } catch (e) {
          didInitiateFamilyAutoRestore.value = false;
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
      if (didCompletePaywallFlow.value) return null;
      if (hasActiveSubscription) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(() async {
            await completePaywallFlowToDashboard(
              option: activePlanOption,
              source: didInitiateFamilyAutoRestore.value
                  ? 'family_sharing'
                  : didInitiateRestore.value
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
                      ref.read(subscriptionProductsProvider.notifier).refresh();
                    },
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
      final storeProductId = effectiveSubscription?.storeProductId;
      final uri = isAppStoreManagedSubscription ||
              (!isPlayStoreManagedSubscription &&
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? Uri.parse('https://apps.apple.com/account/subscriptions')
          : Uri.parse(
              'https://play.google.com/store/account/subscriptions?package=com.moneko.mobile${storeProductId != null ? '&sku=$storeProductId' : ''}',
            );

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!ok && context.mounted) {
        AppToast.error(context, context.l10n.paywallErrorOpenSettings);
      }
    }

    Future<void> startStripeCheckout(PlanOption option) async {
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
          await ref.read(subscriptionNotifierProvider.notifier).refresh();
        },
        hasActiveSubscription: () {
          final subscriptionData = ref
              .read(subscriptionManagementProvider)
              .valueOrNull
              ?.subscription;
          return _subscriptionMatchesPlan(subscriptionData, option);
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
        // Already on this plan
        AppToast.info(context, infoAlreadyOnPlanMessage);
        return;
      }

      // Android subscription upgrades/downgrades require passing ChangeSubscriptionParam
      // with the existing PurchaseDetails. To avoid accidental double subscriptions,
      // we direct users to manage plan changes in Google Play for now.

      try {
        didInitiateCheckout.value = true;

        if (useIap) {
          checkoutPlanOption.value = activePlanOption;
          // Don't allow purchase attempts until the store/products are ready.
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception(storeUnavailableMessage);
          }

          final catalog = activePlanOption.catalogProduct;

          if (catalog == null) {
            throw Exception(missingProductMappingMessage);
          }

          // Show processing dialog before starting purchase
          if (context.mounted) {
            lastIapErrorShown.value = null;
            // StoreKit can report a terminal result before Flutter renders
            // the intermediate processing state. This dialog is owned by the
            // checkout attempt, so treat it as pending immediately; the
            // first terminal controller state will always dismiss it.
            didSeeIapProcessing.value = true;
            processingDialogOpen.value = true;
            processingDialogKind.value = _ProcessingDialogKind.iapPurchase;

            showBlockingProcessingDialog(
              context: context,
              message: processingPurchaseMessage,
            );
          }

          await ref.read(iapControllerProvider.notifier).buy(catalog);

          // Dialog will remain open until purchase completes
          // Navigation in _onPurchaseUpdated will automatically dismiss the dialog
        } else {
          isStripeProcessing.value = true;

          try {
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
        dismissProcessingDialog('main action catch');

        if (context.mounted) {
          final raw = e.toString();
          final lower = raw.toLowerCase();
          final isCanceled =
              e is PaymentCanceledException || lower.contains('cancel');
          final isManagedInApp =
              lower.contains('subscription_managed_in_app') ||
                  lower.contains('managed through an in-app purchase');

          if (isManagedInApp) {
            didInitiateCheckout.value = false;
            checkoutPlanOption.value = null;
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

          didInitiateCheckout.value = false;
          checkoutPlanOption.value = null;
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
        await ref.read(subscriptionNotifierProvider.notifier).refresh();
        await ref.read(subscriptionManagementProvider.notifier).refresh();
      }

      didInitiateRestore.value = true;
      lastIapErrorShown.value = null;
      didSeeIapProcessing.value = false;
      final storeUnavailableMessage =
          context.l10n.paywallErrorStoreUnavailableShort;
      if (context.mounted) {
        processingDialogOpen.value = true;

        showBlockingProcessingDialog(
          context: context,
          message: context.l10n.paywallRestoringPurchases,
        );
      }

      try {
        if (useIap) {
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception(storeUnavailableMessage);
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
          if (!context.mounted) return;
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

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
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
                            const PaywallHeroIcon(),
                            const SizedBox(height: 24),
                            const PaywallAppRatingBadge(),
                            const SizedBox(height: 32),
                            // --- SUBSCRIPTION PLANS ---
                            UnifiedPlanCard(
                              plans: plans,
                              selectedPlanId: selectedPlanId.value,
                              onPlanSelected: (id) {
                                selectedPlanId.value = id;
                              },
                              isNewUser: currentPlanId == 'free',
                              isCurrentPlan: null, // Always allow on paywall
                            ),
                            const SizedBox(height: 32),

                            // --- BENEFITS CHECKLIST ---
                            const PaywallBenefitsChecklist(),
                            const SizedBox(height: 48),

                            // --- REVIEWS ---
                            const PaywallReviewsSection(),
                            const SizedBox(height: 32),

                            // Preview App Link
                            GestureDetector(
                              onTap: () {
                                unawaited(() async {
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
                            PaywallAutoRenewCheckbox(
                              value: hasAcknowledgedAutoRenew.value,
                              onChanged: (value) =>
                                  hasAcknowledgedAutoRenew.value = value,
                              isProcessing: isProcessing,
                              option: activePlanOption,
                              trialMode: mode == PaywallMode.trial,
                            ),
                          ],
                          PaywallCheckoutActionButton(
                            option: activePlanOption,
                            isProcessing: isProcessing,
                            isStoreReady: isStoreReady,
                            canConfirmAutoRenew: canConfirmAutoRenew,
                            isCurrentPlan: false,
                            trialMode: mode == PaywallMode.trial,
                            onPressed: onMainAction,
                            centerText: true,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          PaywallFooterLinks(
                            isProcessing: isProcessing,
                            onRestorePurchases: onRestorePurchases,
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
    ));
  }
}

bool _subscriptionMatchesPlan(Subscription? subscription, PlanOption option) {
  if (!(subscription?.isSubscribed ?? false)) return false;
  final currentPlan = subscription?.plan?.toLowerCase().trim();
  final targetPlan = option.serverPlanId.toLowerCase().trim();
  if (currentPlan != targetPlan) return false;

  final targetInterval = option.billingInterval?.toLowerCase().trim();
  if (targetInterval == null) return true;
  return subscription?.billingInterval?.toLowerCase().trim() == targetInterval;
}

// --- COMPONENTS ---
