import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, debugPrint, kDebugMode;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:go_router/go_router.dart';

void _debugLog(Object? message) {
  if (!kDebugMode) return;
  debugPrint(message?.toString() ?? 'null');
}

// Intentionally shadow dart:core print in this file so any existing purchase
// flow logs never ship in release builds.
// ignore: avoid_print
void print(Object? message) => _debugLog(message);

const bool FORCE_USE_STRIPE_CHECKOUT = false;

enum PlanSelectionMode {
  trial,
  resubscribe,
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
    if (billingInterval == 'monthly') return '/mo';
    if (billingInterval == 'yearly') return '/yr';
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
    final selectedPlanId = useState<String>('lifetime');
    final hasAcknowledgedAutoRenew = useState(false);
    final isStripeProcessing = useState(false);
    final processingDialogOpen = useState(false);

    final currentSub = subscriptionAsync.value;
    final currentPlanId = currentSub?.subscription?.plan ?? 'free';
    final currentInterval = currentSub?.subscription?.billingInterval;
    final currentProvider = currentSub?.subscription?.provider;

    // Check if user is truly new (no subscription data exists)
    final isNewUser = currentSub?.subscription == null;

    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final useIap = isIos && !FORCE_USE_STRIPE_CHECKOUT;

    // Avoid accidentally registering multiple listeners across rebuilds.
    final didRegisterIapListener = useRef(false);

    // Track processing state for UI
    final isProcessing =
        (useIap ? (iapStateAsync.value?.isProcessing ?? false) : false) ||
            isStripeProcessing.value;

    void dismissProcessingDialog() {
      if (!processingDialogOpen.value) return;
      processingDialogOpen.value = false;
      if (!context.mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
    }

    String humanizePurchaseError(String raw) {
      final message = raw.trim();
      final lower = message.toLowerCase();
      if (lower.contains('cancel')) return 'Purchase cancelled.';
      if (lower.contains('timed out')) {
        return 'Purchase timed out. Please try again.';
      }
      if (lower.contains('not available') || lower.contains('store')) {
        return 'Store unavailable. Please try again later.';
      }
      if (lower.contains('verification')) {
        return 'Purchase verification failed. Please try again.';
      }
      return 'Purchase failed. Please try again.';
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
          dismissProcessingDialog();
          _debugLog('IAP provider error: ${next.error}');
          AppToast.error(context, 'Purchase failed. Please try again.');
          return;
        }

        final nextError = nextState?.lastError;
        final prevError = prevState?.lastError;
        if (nextError != null &&
            nextError.isNotEmpty &&
            nextError != prevError) {
          dismissProcessingDialog();
          _debugLog('IAP purchase error: $nextError');
          AppToast.error(context, humanizePurchaseError(nextError));
        }

        if (prevProcessing && !nextProcessing) {
          dismissProcessingDialog();

          // If we exited processing without an error, treat it as a successful
          // purchase/verification and send the user back to the app.
          if ((nextState?.lastError ?? '').isEmpty) {
            _debugLog('✅ Purchase successful! Refreshing subscription...');

            // Schedule async work without blocking the listener
            Future.microtask(() async {
              try {
                // Refresh subscription state - cross-invalidation ensures both providers stay in sync
                _debugLog('🔄 Refreshing subscription state...');
                await ref
                    .read(subscriptionManagementProvider.notifier)
                    .refresh();
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
                _debugLog(
                    '  - Subscription model: ${subscriptionData != null}');
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
                      '✅ Subscription confirmed active, navigating to dashboard');
                  if (context.mounted) {
                    context.go('/dashboard');
                  }
                } else {
                  // Subscription still not active - show error
                  _debugLog('❌ Subscription not active after purchase!');
                  AppToast.error(
                    context,
                    'Purchase completed but subscription not activated. Please restart the app.',
                  );
                }
              } catch (e, stack) {
                _debugLog('❌ Error refreshing subscription: $e');
                _debugLog('Stack: $stack');

                // Show error to user instead of navigating
                if (context.mounted) {
                  AppToast.error(
                    context,
                    'Purchase completed but failed to verify subscription. Please restart the app.',
                  );
                }
              }
            });
          }
        }
      });
    }

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
      }).toList();
    } else {
      // Android remains Stripe checkout (web) for now.
      plans = const [
        PlanOption(
          id: 'lifetime',
          serverPlanId: 'lifetime',
          billingInterval: null,
          name: 'Lifetime',
          storePrice: null,
          displayPriceUsd: 39.99,
          tagline: 'Pay once, own it forever.',
          badgeText: 'LIMITED',
        ),
        PlanOption(
          id: 'plus_yearly',
          serverPlanId: 'plus',
          billingInterval: 'yearly',
          name: 'Yearly',
          storePrice: null,
          displayPriceUsd: 29.99,
          originalPriceUsd: 59.99,
          tagline: 'Best value for 12 months.',
          isPopular: true,
          badgeText: 'SAVE 50%',
        ),
        PlanOption(
          id: 'plus_monthly',
          serverPlanId: 'plus',
          billingInterval: 'monthly',
          name: 'Monthly',
          storePrice: null,
          displayPriceUsd: 5.99,
          originalPriceUsd: 7.99,
          tagline: 'Flexible. Cancel anytime.',
        ),
      ];
    }

    final lifetimePlan =
        plans.where((p) => p.serverPlanId == 'lifetime').toList();
    final subPlans = plans.where((p) => p.serverPlanId != 'lifetime').toList();

    // Effect: If user is already on a plan, try to select it visually
    useEffect(() {
      if (plans.isNotEmpty && !plans.any((p) => p.id == selectedPlanId.value)) {
        selectedPlanId.value = plans.first.id;
      }

      if (mode == PlanSelectionMode.trial && currentPlanId == 'free') {
        final monthly = plans
            .where((p) =>
                p.serverPlanId == 'plus' && p.billingInterval == 'monthly')
            .toList();
        final yearly = plans
            .where((p) =>
                p.serverPlanId == 'plus' && p.billingInterval == 'yearly')
            .toList();
        final firstRecurring = (monthly.isNotEmpty
                ? monthly.first
                : yearly.isNotEmpty
                    ? yearly.first
                    : null) ??
            plans.first;

        selectedPlanId.value = firstRecurring.id;
        return null;
      }

      if (currentPlanId == 'lifetime') {
        selectedPlanId.value = 'lifetime';
      } else if (currentPlanId == 'plus') {
        if (currentInterval == 'monthly') {
          selectedPlanId.value = 'plus_monthly';
        } else {
          selectedPlanId.value = 'plus_yearly';
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

    // DIRECT RETURN FOR LIFETIME USERS
    if (currentPlanId == 'lifetime') {
      return const _LifetimeView();
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
      );
    }

    Future<void> onManageStoreSubscription() async {
      final storeProductId = currentSub?.subscription?.storeProductId;
      final uri = defaultTargetPlatform == TargetPlatform.iOS
          ? Uri.parse('https://apps.apple.com/account/subscriptions')
          : Uri.parse(
              'https://play.google.com/store/account/subscriptions?package=com.moneko.mobile${storeProductId != null ? '&sku=$storeProductId' : ''}',
            );

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        AppToast.error(context, 'Unable to open subscription settings');
      }
    }

    Future<void> startStripeCheckout(PlanOption option) async {
      print('🔄 Starting Stripe checkout for plan: ${option.serverPlanId}');

      final session = supabase.auth.currentSession;
      if (session == null) {
        print('❌ No active session found');
        throw Exception('No active session');
      }
      print('✅ Session validated for user: ${session.user.id}');

      // IMPORTANT: Do not URI-encode the Stripe placeholder.
      final successBase = Uri.https(Constants.checkoutBaseUrl, '/checkout', {
        'status': 'success',
        'source': 'mobile',
        'redirectUrl': DeepLinks.paymentCallback,
        'plan': option.serverPlanId,
        if (option.billingInterval != null) 'billing': option.billingInterval,
      }).toString();

      final cancelBase = Uri.https(Constants.checkoutBaseUrl, '/checkout', {
        'status': 'canceled',
        'source': 'mobile',
        'redirectUrl': DeepLinks.paymentCallback,
        'plan': option.serverPlanId,
        if (option.billingInterval != null) 'billing': option.billingInterval,
      }).toString();

      print('🌐 Calling Supabase function: create-checkout-session');
      print('📋 Checkout URL base: ${Constants.checkoutBaseUrl}');

      final response = await supabase.functions.invoke(
        'create-checkout-session',
        body: {
          'plan': option.serverPlanId,
          if (option.serverPlanId != 'lifetime')
            'billingInterval': option.billingInterval,
          'successUrl': '$successBase&session_id={CHECKOUT_SESSION_ID}',
          'cancelUrl': '$cancelBase&session_id={CHECKOUT_SESSION_ID}',
          'userId': session.user.id,
        },
      );

      print('📦 Response status: ${response.status}');
      print('📦 Response data: ${response.data}');

      if (response.data != null && response.data['checkoutUrl'] != null) {
        final checkoutUrl = response.data['checkoutUrl'] as String;
        print('🚀 Launching checkout URL: $checkoutUrl');

        await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
        print('✅ Checkout URL launched successfully');
      } else {
        print('❌ No checkout URL received from Supabase function');
        throw Exception('No checkout URL received');
      }
    }

    // Action Logic
    Future<void> onMainAction() async {
      print(
          '🎯 Starting subscription flow for plan: ${activePlanOption.serverPlanId}');

      if (isCurrentPlan(activePlanOption)) {
        print('⚠️ User already on this plan');
        // Already on this plan
        AppToast.info(context, 'You are already on this plan.');
        return;
      }

      // Android subscription upgrades/downgrades require passing ChangeSubscriptionParam
      // with the existing PurchaseDetails. To avoid accidental double subscriptions,
      // we direct users to manage plan changes in Google Play for now.
      final isPlayStore = currentProvider == 'play_store';
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final isIntervalSwitch = currentPlanId == 'plus' &&
          activePlanOption.serverPlanId == 'plus' &&
          currentInterval != null &&
          activePlanOption.billingInterval != null &&
          currentInterval != activePlanOption.billingInterval;

      // if (isAndroid && isPlayStore && isIntervalSwitch) {
      //   await onManageStoreSubscription();
      //   return;
      // }

      // Smart Dialog Copy
      String title = 'Confirm Selection';
      String description =
          'Switch to ${activePlanOption.name} for ${activePlanOption.priceDisplay}?';
      String confirmLabel = 'Confirm';

      if (activePlanOption.serverPlanId == 'lifetime') {
        title = 'Secure Lifetime Access';
        description =
            'Get unlimited access forever for a one-time payment of ${activePlanOption.priceDisplay}. No recurring fees.';
        confirmLabel = 'Get Lifetime';
      } else if (currentPlanId == 'plus' &&
          activePlanOption.serverPlanId == 'plus') {
        // Switching interval
        if (activePlanOption.billingInterval == 'yearly') {
          title = 'Switch to Yearly?';
          description =
              'Upgrade to annual billing for ${activePlanOption.priceDisplay}/year.';
          confirmLabel = 'Switch & Save';
        } else {
          title = 'Switch to Monthly?';
          description =
              'Switch to monthly billing for ${activePlanOption.priceDisplay}/mo.';
          confirmLabel = 'Switch';
        }
      }

      // Confirm Change
      final result = await MonekoAlertDialog.show(
        context: context,
        title: title,
        description: description,
        confirmLabel: confirmLabel,
        cancelLabel: 'Cancel',
      );

      if (result?.confirmed == true) {
        print('✅ User confirmed subscription dialog');
        try {
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
              processingDialogOpen.value = true;
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
            await ref.read(iapControllerProvider.notifier).buy(catalog);
            print('✅ buy() method completed');
            // Dialog will remain open until purchase completes
            // Navigation in _onPurchaseUpdated will automatically dismiss the dialog
          } else {
            print('💳 Starting Stripe checkout');

            isStripeProcessing.value = true;

            // Show processing dialog for Stripe
            if (context.mounted) {
              processingDialogOpen.value = true;
              showBlockingProcessingDialog(
                context: context,
                message: 'Redirecting to checkout...',
              );
            }

            try {
              await startStripeCheckout(activePlanOption);
            } finally {
              isStripeProcessing.value = false;
              dismissProcessingDialog();
            }
          }
        } catch (e) {
          print('❌ Error in subscription flow: $e');

          dismissProcessingDialog();

          if (context.mounted) {
            _debugLog('Purchase flow threw: $e');
            AppToast.error(context, humanizePurchaseError(e.toString()));
          }
        }
      } else {
        print('❌ User cancelled subscription dialog');
      }
    }

    Future<void> onRestorePurchases() async {
      if (context.mounted) {
        processingDialogOpen.value = true;
        showBlockingProcessingDialog(
          context: context,
          message: 'Restoring purchases...',
        );
      }

      try {
        if (useIap) {
          await ref.read(iapControllerProvider.notifier).restorePurchases();
        }
        await ref.read(subscriptionManagementProvider.notifier).refresh();
        if (context.mounted) {
          AppToast.success(context, 'Subscription status restored');
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.error(context, 'Failed to restore: ${e.toString()}');
        }
      } finally {
        dismissProcessingDialog();
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
            AppToast.success(context, 'Subscription cancelled');
          }
        } catch (e) {
          if (context.mounted) {
            AppToast.error(context, e.toString());
          }
        } finally {
          dismissProcessingDialog();
        }
      }
    }

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: ''),
      body: Material(
        color: colorScheme.appBackground,
        child: SafeArea(
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'EARLY BIRD SALE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 32),

                        // --- HERO: LIFETIME PLAN ---
                        if (lifetimePlan.isNotEmpty)
                          _LifetimeHeroCard(
                            plan: lifetimePlan.first,
                            isSelected:
                                selectedPlanId.value == lifetimePlan.first.id,
                            onTap: () =>
                                selectedPlanId.value = lifetimePlan.first.id,
                          ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR SUBSCRIBE',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.mutedForeground
                                          .withValues(alpha: 0.6))),
                            ),
                            Expanded(
                                child: Divider(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5))),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // --- STANDARD: SUBSCRIPTION PLANS ---
                        ...subPlans.map((plan) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _AppleStylePlanCard(
                              plan: plan,
                              isSelected: selectedPlanId.value == plan.id,
                              onTap: () => selectedPlanId.value = plan.id,
                              isNewUser: isNewUser,
                            ),
                          );
                        }),

                        const SizedBox(height: 12),

                        // Features Link
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => const _CleanFeatureSheet());
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'Compare features',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
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
                            : (value) =>
                                hasAcknowledgedAutoRenew.value = value ?? false,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: colorScheme.primary,
                        checkColor: colorScheme.onPrimary,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          mode == PlanSelectionMode.trial
                              ? 'I understand that after my ${activePlanOption.billingInterval == 'monthly' ? '30-day' : '1-year'} free trial, my subscription will automatically renew at ${activePlanOption.priceDisplay}${activePlanOption.billingInterval == 'monthly' ? '/month' : '/year'} unless I cancel at least 24 hours before the trial ends.'
                              : 'Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews at ${activePlanOption.priceDisplay}${activePlanOption.billingInterval == 'monthly' ? '/month' : '/year'} unless canceled at least 24 hours before the end of the current period. You can manage and cancel subscriptions in your account settings on the App Store.',
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        subtitle: Text(
                          'You can cancel anytime in Settings.',
                          style: TextStyle(
                            color: colorScheme.mutedForeground
                                .withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (!canConfirmAutoRenew) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Please check the box above to continue.',
                            style: TextStyle(
                              color: colorScheme.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    PrimaryAdaptiveButton(
                      onPressed:
                          isProcessing || !canConfirmAutoRenew || !isStoreReady
                              ? null
                              : onMainAction,
                      child: Text(
                        isProcessing
                            ? 'Processing...'
                            : !isStoreReady
                                ? 'Store unavailable'
                                : (activePlanOption.serverPlanId == 'lifetime'
                                    ? 'Get Lifetime Access for ${activePlanOption.priceDisplay}'
                                    : 'Subscribe for ${activePlanOption.priceDisplay} ${activePlanOption.billingInterval == 'monthly' ? '/mo' : '/yr'}'),
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
                        onTap: isProcessing ? null : onManageStoreSubscription,
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
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- COMPONENTS ---

class _LifetimeHeroCard extends StatelessWidget {
  final PlanOption plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _LifetimeHeroCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Premium Gold/Primary tint styling
    final borderColor =
        isSelected ? scheme.primary : Colors.amber.withValues(alpha: 0.5);
    final backgroundColor =
        isSelected ? scheme.primary.withValues(alpha: 0.05) : scheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FOUNDER\'S DEAL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    // Checkbox
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isSelected ? scheme.primary : Colors.transparent,
                          border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: 2)),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                          : null,
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (plan.originalPriceUsd != null) ...[
                      Text(
                        '\$${plan.originalPriceUsd!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          decoration: TextDecoration.lineThrough,
                          color: scheme.mutedForeground.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      plan.priceDisplay,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 6),
                      child: Text(
                        'once',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pay once, enjoy forever. This plan will be removed after the Early Bird sale ends.',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.2))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Offer expires soon',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[800] ?? Colors.amber,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          // Floating Badge
          Positioned(
            top: -10,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _AppleStylePlanCard extends StatelessWidget {
  final PlanOption plan;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isNewUser;

  const _AppleStylePlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.isNewUser,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final backgroundColor = scheme.surface;
    final borderColor = isSelected
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Row(
          children: [
            // Radio Indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.8),
                  width: 2,
                ),
                color: isSelected ? scheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child:
                          Icon(Icons.check, size: 14, color: scheme.onPrimary))
                  : null,
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (plan.badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.badgeText!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (plan.originalPriceUsd != null) ...[
                        Text(
                          '\$${plan.originalPriceUsd!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            color:
                                scheme.mutedForeground.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        plan.priceDisplay,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        plan.periodDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.mutedForeground,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (plan.billingInterval != null && isNewUser) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Free for first month, cancel anytime',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Could not open link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () =>
              _launchUrl(context, 'https://moneko.io/privacy-policy'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            minimumSize:
                const Size(0, 44), // Accessibility: 44px minimum tap target
          ),
          child: Text(
            'Privacy',
            style: TextStyle(fontSize: 12, color: scheme.primary),
          ),
        ),
        Text(' • ',
            style: TextStyle(fontSize: 12, color: scheme.mutedForeground)),
        TextButton(
          onPressed: () =>
              _launchUrl(context, 'https://moneko.io/terms-of-service'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            minimumSize:
                const Size(0, 44), // Accessibility: 44px minimum tap target
          ),
          child: Text(
            'Terms',
            style: TextStyle(fontSize: 12, color: scheme.primary),
          ),
        ),
        Text(' • ',
            style: TextStyle(fontSize: 12, color: scheme.mutedForeground)),
        TextButton(
          onPressed: () => _launchUrl(context, 'https://moneko.io/eula'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            minimumSize:
                const Size(0, 44), // Accessibility: 44px minimum tap target
          ),
          child: Text(
            'EULA',
            style: TextStyle(fontSize: 12, color: scheme.primary),
          ),
        ),
      ],
    );
  }
}

class _CleanFeatureSheet extends StatelessWidget {
  const _CleanFeatureSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final features = [
      'Unlimited AI Insights',
      'Automatic Bank Sync',
      'Smart Budgeting Goals',
      'Export to CSV',
      'Recurring Bill Tracking',
      'Priority Support',
      'Ad-free Experience',
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Included in Premium',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 22, color: scheme.primary),
                    const SizedBox(width: 14),
                    Text(f,
                        style: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurface.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _LifetimeView extends StatelessWidget {
  const _LifetimeView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: ''),
      body: Material(
        color: scheme.appBackground,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Icon(Icons.verified_rounded,
                      size: 48, color: scheme.primary),
                ),
                const SizedBox(height: 32),
                Text(
                  'Lifetime Member',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You have full access forever.\nThank you for supporting Moneko.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: scheme.mutedForeground,
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
