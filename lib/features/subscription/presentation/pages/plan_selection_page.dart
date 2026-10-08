import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/app/router.dart' show rootNavigatorKey;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
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
import 'package:moneko/features/subscription/presentation/subscription_checkout_shared.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/presentation/widgets/family_sharing_restored_dialog.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/widgets/plan_selection_card_row.dart';
import 'package:moneko/features/subscription/presentation/widgets/plan_selection_layout.dart';
import 'package:moneko/features/subscription/presentation/widgets/manage_membership_choice_sheet.dart';
import 'package:moneko/features/subscription/presentation/widgets/cancel_reason_sheet.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart'
    show showFreeVsPlusComparisonDialog;
import 'package:moneko/features/subscription/data/subscription_cancel_reason_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/features/subscription/presentation/pages/purchase_processing_dialog_lifecycle.dart';
import 'package:go_router/go_router.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';


int? _computeTrialDaysLeft(DateTime? trialEndAt) {
  if (trialEndAt == null) return null;

  final nowUtc = DateTime.now().toUtc();
  final endUtc = trialEndAt.toUtc();
  if (!endUtc.isAfter(nowUtc)) return null;

  final remaining = endUtc.difference(nowUtc);
  return (remaining.inMilliseconds / Duration.millisecondsPerDay).ceil();
}

String? _trialActiveUntilLabel(
    BuildContext context, Subscription? subscription) {
  if (subscription?.status?.toLowerCase() != 'trialing') return null;
  final trialEndsAt = subscription?.currentPeriodEnd;
  if (trialEndsAt == null) return null;
  if (_computeTrialDaysLeft(trialEndsAt) == null) return null;
  final formattedDate = formatLocalizedDate(context, trialEndsAt);
  return context.l10n.trialActiveUntilDate(formattedDate);
}

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

enum _PlanFamily {
  plus,
  lifetime,
}

extension _PlanFamilyX on _PlanFamily {
  String get planId {
    return switch (this) {
      _PlanFamily.plus => 'plus',
      _PlanFamily.lifetime => 'lifetime',
    };
  }
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
  const PlanSelectionPage({
    super.key,
    this.mode = PlanSelectionMode.resubscribe,
    this.preferredPlanId,
    this.preferredBillingInterval,
  });

  final PlanSelectionMode mode;
  final String? preferredPlanId;
  final String? preferredBillingInterval;

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
    final preferredPlanFamily = switch (preferredPlanId) {
      'plus' => _PlanFamily.plus,
      'lifetime' => _PlanFamily.lifetime,
      _ => null,
    };
    final selectedPlanFamily = useState(
      preferredPlanFamily ?? _PlanFamily.plus,
    );
    final lastSyncedPlanFamilyForPlan = useRef<String?>(null);
    final currentSubscription = currentSub?.subscription;

    final currentProvider = currentSubscription?.provider;
    final normalizedProvider = currentProvider?.toLowerCase().trim();
    final currentStatus = currentSub?.subscription?.status?.toLowerCase();
    final renewalInfoLabel = currentSub?.renewalInfo(context.l10n);
    final trialDaysLeftLabel =
        _trialActiveUntilLabel(context, currentSubscription);
    final currentPlanInfoLabel = trialDaysLeftLabel ?? renewalInfoLabel;
    final hasActiveSubscription = currentSubscription?.isSubscribed ?? false;
    final isHouseholdSharedSubscription =
        currentSubscription?.boundToUserId != null;
    final isFamilySharedSubscription =
        currentSubscription?.isAppStoreFamilyShared ?? false;
    final hasLegacyAppStoreOwnership =
        currentSubscription?.appStoreInAppOwnershipType != null;
    final isLegacyAppStoreManagedSubscription =
        (normalizedProvider == null || normalizedProvider.isEmpty) &&
            hasLegacyAppStoreOwnership;
    final isStripeManagedSubscription = normalizedProvider == 'stripe';
    final isAppStoreManagedSubscription = normalizedProvider == 'app_store' ||
        isLegacyAppStoreManagedSubscription;
    final isPlayStoreManagedSubscription = normalizedProvider == 'play_store';
    final isStoreManagedSubscription =
        isAppStoreManagedSubscription || isPlayStoreManagedSubscription;
    final canManageCurrentSubscription = currentPlanId != 'free' &&
        currentStatus != 'trialing' &&
        !isHouseholdSharedSubscription &&
        !isFamilySharedSubscription;

    // Check if user is truly new (no subscription data exists)
    final isNewUser = currentSub?.subscription == null;

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
    final didCompletePlanSelectionFlow = useRef(false);
    final checkoutPlanOption = useRef<PlanOption?>(null);
    final checkoutAttemptCounter = useRef(0);

    useEffect(() {
      final planFamilySyncKey = '$currentPlanId:${preferredPlanId ?? ''}';
      if (lastSyncedPlanFamilyForPlan.value == planFamilySyncKey) {
        return null;
      }

      lastSyncedPlanFamilyForPlan.value = planFamilySyncKey;
      if (preferredPlanFamily != null) {
        selectedPlanFamily.value = preferredPlanFamily;
      } else {
        selectedPlanFamily.value = _PlanFamily.plus;
      }

      return null;
    }, [currentPlanId, preferredPlanId]);

    void runAfterBuild(VoidCallback callback) {
      runAfterBuildIfMounted(context, callback);
    }

    void dismissProcessingDialog([String? reason]) {
      dismissProcessingDialogSafely<_ProcessingDialogKind>(
        context: context,
        dialogOpen: processingDialogOpen,
        dialogKind: processingDialogKind,
        reason: reason,
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
      checkoutPlanOption.value = null;

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
        await ref.read(subscriptionManagementProvider.notifier).refresh();
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        if (!context.mounted) return;

        final subscriptionAsync = ref.read(subscriptionManagementProvider);
        final subscriptionData = subscriptionAsync.valueOrNull?.subscription;
        final isActive = subscriptionData?.isSubscribed ?? false;
        final expectedOption = checkoutPlanOption.value;
        // The IAP controller emits its completion marker only after the
        // backend has persisted the matching App Store entitlement. Keep this
        // second check just as strict so an existing Moneko trial with the
        // same Plus/yearly shape can never be mistaken for the new purchase.
        final hasExpectedPlan = expectedOption == null
            ? isActive
            : expectedOption.catalogProduct == null
                ? false
                : subscriptionData?.confirmsAppStorePurchase(
                      expectedOption.catalogProduct!.storeProductId,
                    ) ==
                    true;

        if (hasExpectedPlan) {
          await completePlanSelectionFlowToDashboard(
            option: expectedOption,
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

        if (next.hasError) {
          didInitiateCheckout.value = false;
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
        final nextErrorCode = nextState?.lastErrorCode;

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

          showIapError(nextError, 'lastError', nextErrorCode);
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
          Future.microtask(() =>
              verifySubscriptionAndCompleteCheckout('has_new_completion'));
        }

        if (!prevProcessing && nextProcessing) {
          didSeeIapProcessing.value = true;
        }
      });
    }

    useEffect(() {
      if (!useIap) return null;

      if (processingDialogKind.value != _ProcessingDialogKind.iapPurchase) {
        return null;
      }
      if (!processingDialogOpen.value) {
        return null;
      }

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

    final visiblePlans = sortPlanOptions(plans);

    // Only an explicit tap selects a plan. Refreshes may invalidate that choice,
    // but must not select a current, preferred, or default plan automatically.
    useEffect(() {
      final selection = selectedPlanId.value;
      if (selection != null &&
          !visiblePlans.any((plan) => plan.id == selection)) {
        selectedPlanId.value = null;
      }
      return null;
    }, [visiblePlans.map((plan) => plan.id).join('|')]);

    // Helpers
    PlanOption? activePlanOption;
    for (final option in visiblePlans) {
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
      if (didCompletePlanSelectionFlow.value) return null;
      // A StoreKit request is not a purchase. New users can already have an
      // active Moneko trial, which must never cause this generic active-plan
      // observer to dismiss the page or claim payment success. IAP checkout
      // completes only from the matching purchase-stream completion marker.
      if (useIap && didInitiateCheckout.value) return null;
      if (!hasActiveSubscription) return null;
      if (!didInitiateCheckout.value &&
          !didInitiateRestore.value &&
          !didInitiateFamilyAutoRestore.value) {
        return null;
      }

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
      return subscriptionMatchesPlanOption(currentSubscription, option);
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
      if (!hasActiveSubscription) {
        return context.l10n.freePlan;
      }
      return switch (currentStatus) {
        'active' => context.l10n.activeStatus,
        'trialing' => context.l10n.trialStatus,
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

    Uri appStoreSubscriptionSettingsUri() {
      return Uri.parse('https://apps.apple.com/account/subscriptions');
    }

    Uri playStoreSubscriptionSettingsUri() {
      final storeProductId = currentSubscription?.storeProductId;
      return Uri.parse(
        'https://play.google.com/store/account/subscriptions?package=com.moneko.mobile${storeProductId != null ? '&sku=$storeProductId' : ''}',
      );
    }

    Future<void> openStoreSubscriptionSettings(Uri uri) async {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        AppToast.error(context, context.l10n.unableToOpenSubscriptionSettings);
      }
    }

    Future<void> redirectToManage() async {
      if (isStripeManagedSubscription) {
        await openMembershipDashboardOnWeb();
        return;
      }

      if (isAppStoreManagedSubscription) {
        await openStoreSubscriptionSettings(appStoreSubscriptionSettingsUri());
        return;
      }

      if (isPlayStoreManagedSubscription) {
        await openStoreSubscriptionSettings(playStoreSubscriptionSettingsUri());
        return;
      }

      await openMembershipDashboardOnWeb();
    }

    /// The single membership-management entry point. It presents a choice
    /// sheet, then a cancel-reason form when the user chooses to cancel,
    /// before redirecting to the existing store/web management surface.
    Future<void> manageMembershipWithCancelFlow() async {
      final choice = await ManageMembershipChoiceSheet.show(context);
      if (choice == null || !context.mounted) return;

      if (choice == ManageMembershipChoice.viewStatus) {
        await redirectToManage();
        return;
      }

      // choice == cancelPlan
      final submission = await CancelReasonSheet.show(context);
      if (submission == null || !context.mounted) return;

      // Persist reason (fire-and-forget; never blocks redirect)
      unawaited(submitCancelReason(
        CancelReasonSubmission(
          reason: submission.reason,
          reasonLabel: submission.reasonLabel,
          detailText: submission.detailText,
          provider: normalizedProvider,
        ),
      ));

      await redirectToManage();
    }

    Future<void> onManageMembership() async {
      if (!canManageCurrentSubscription) {
        return;
      }
      await manageMembershipWithCancelFlow();
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

    Future<void> startStripeCheckout(PlanOption option) async {
      await startStripeCheckoutForOption(
          context: context,
          option: option,
          supabaseClient: supabase,
          noSessionError: context.l10n.paywallErrorNoSession,
          startCheckoutError: context.l10n.paywallErrorStartCheckout,
          noCheckoutUrlError: context.l10n.paywallErrorNoCheckoutUrl,
          paymentCanceledMessage: context.l10n.paymentCanceled,
          paymentFailedMessage: context.l10n.paymentFailed,
          notActivatedMessage: context.l10n.paywallErrorNotActivated,
          refreshSubscription: () async {
            await ref.read(subscriptionManagementProvider.notifier).refresh();
            await ref.read(subscriptionNotifierProvider.notifier).refresh();
          },
          hasActiveSubscription: () {
            final subscriptionData = ref
                .read(subscriptionManagementProvider)
                .valueOrNull
                ?.subscription;
            return subscriptionMatchesPlanOption(subscriptionData, option);
          });
    }

    // Action Logic
    Future<void> onMainAction() async {
      final selectedPlan = activePlanOption;
      if (selectedPlan == null) {
        return;
      }

      checkoutAttemptCounter.value += 1;

      if (isCurrentPlan(selectedPlan)) {
        // Already on this plan
        AppToast.info(context, context.l10n.alreadyOnThisPlan);
        return;
      }

      // Existing Stripe subscriptions must use the web membership flow, which
      // previews and applies immediate/scheduled changes against the current
      // subscription instead of creating a second checkout subscription.
      if (hasActiveSubscription &&
          canManageCurrentSubscription &&
          !isStoreManagedSubscription) {
        await openMembershipDashboardOnWeb();
        return;
      }

      // Apple controls all subscription-group change timing, including the
      // immediate and deferred rules for a 12-month commitment. Do not start
      // a second Moneko purchase that could incorrectly promise an immediate
      // change. Lifetime is a separate non-consumable and must wait until the
      // recurring App Store entitlement has ended.
      if (hasActiveSubscription && isAppStoreManagedSubscription) {
        if (selectedPlan.serverPlanId == 'lifetime') {
          AppToast.info(
            context,
            context.l10n.paywallLifetimeAvailableAfterSubscriptionEnds,
          );
        }
        await openStoreSubscriptionSettings(appStoreSubscriptionSettingsUri());
        return;
      }

      if (hasActiveSubscription &&
          currentSubscription?.plan?.toLowerCase().trim() == 'lifetime') {
        AppToast.info(context, context.l10n.paywallLifetimeAlreadyIncludesPlus);
        return;
      }

      try {
        didInitiateCheckout.value = true;
        checkoutPlanOption.value = selectedPlan;

        if (useIap) {
          // Don't allow purchase attempts until the store/products are ready.
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception(context.l10n.paywallErrorStoreUnavailableShort);
          }

          final catalog = selectedPlan.catalogProduct;

          if (catalog == null) {
            throw Exception(context.l10n.paywallErrorMissingProductMapping);
          }

          // Show processing dialog before starting purchase
          if (context.mounted) {
            lastIapErrorShown.value = null;
            // A StoreKit terminal update can arrive between Flutter frames.
            // This dialog belongs to the checkout attempt itself, so mark it
            // as pending immediately rather than waiting to observe a
            // separate `isProcessing == true` rebuild. Otherwise a rapid
            // StoreKit cancellation can leave this non-dismissible dialog
            // open forever.
            didSeeIapProcessing.value = true;
            processingDialogOpen.value = true;
            processingDialogKind.value = _ProcessingDialogKind.iapPurchase;

            showBlockingProcessingDialog(
              context: context,
              message: context.l10n.paywallProcessingPurchase,
            );
          }

          await ref.read(iapControllerProvider.notifier).buy(
                catalog,
                useMonthlyCommitment: selectedPlan.isCommitment,
              );

          // Dialog will remain open until purchase completes
          // Navigation in _onPurchaseUpdated will automatically dismiss the dialog
        } else {
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
        dismissProcessingDialog('main action catch');
        didInitiateCheckout.value = false;
        checkoutPlanOption.value = null;

        if (context.mounted) {
          final raw = e.toString();
          final lower = raw.toLowerCase();
          final isCanceled =
              e is PaymentCanceledException || lower.contains('cancel');
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
              await manageMembershipWithCancelFlow();
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
        body: PlanSelectionLayout(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(context.l10n.currentPlan,
                            style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.mutedForeground)),
                        Text(resolveSubscriptionStatusLabel().toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary)),
                        if (isFamilySharedSubscription)
                          const _FamilySharingBadge(),
                        if (canManageCurrentSubscription)
                          TextButton(
                            onPressed: isProcessing ? null : onManageMembership,
                            style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            child: Text(context.l10n.manage),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                  ),
                ],
              ),
              if (currentPlanInfoLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(currentPlanInfoLabel,
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.mutedForeground)),
                ),
            ],
          ),
          plans: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: PlanSelectionCardRow(
              key: ValueKey(selectedPlanFamily.value.planId),
              plans: visiblePlans,
              selectedPlanId: selectedPlanId.value ?? '',
              onPlanSelected: (id) => selectedPlanId.value = id,
              isCurrentPlan: isCurrentPlan,
              isNewUser: isNewUser,
              vertical: true,
            ),
          ),
          comparison: Center(
            child: TextButton(
              onPressed: () => showFreeVsPlusComparisonDialog(context),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(context.l10n.comparePlans,
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                      decorationColor: colorScheme.primary,
                      decoration: TextDecoration.underline)),
            ),
          ),
          actions: activePlanOption == null
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (requiresAutoRenewAcknowledgement)
                      PaywallAutoRenewCheckbox(
                        value: hasAcknowledgedAutoRenew.value,
                        onChanged: (value) =>
                            hasAcknowledgedAutoRenew.value = value,
                        isProcessing: isProcessing,
                        option: activePlanOption,
                        trialMode: mode == PlanSelectionMode.trial,
                        bottomPadding: 4,
                        compact: true,
                      ),
                    PaywallCheckoutActionButton(
                      option: activePlanOption,
                      isProcessing: isProcessing,
                      isStoreReady: isStoreReady,
                      canConfirmAutoRenew: canConfirmAutoRenew,
                      isCurrentPlan: isCurrentPlan(activePlanOption),
                      trialMode: mode == PlanSelectionMode.trial,
                      includePrice: true,
                      onPressed: onMainAction,
                    ),
                  ],
                ),
          footer: useIap
              ? PaywallFooterLinks(
                  isProcessing: isProcessing || !isStoreReady,
                  onRestorePurchases: onRestorePurchases,
                  wrap: true,
                )
              : const PaywallLegalLinks(),
        ),
      ),
    );
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
            child: Image.asset(
              'lib/assets/images/paywall/lifetime-thanks.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
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
