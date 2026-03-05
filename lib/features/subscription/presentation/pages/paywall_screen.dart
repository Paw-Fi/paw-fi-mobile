import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, debugPrint;
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
import 'package:moneko/core/preview/preview_mode_provider.dart';

void _debugLog(Object? message) {
  debugPrint(message?.toString() ?? 'null');
}

// Intentionally shadow dart:core print in this file so any existing purchase
// flow logs never ship in release builds.
// ignore: avoid_print
void print(Object? message) => _debugLog(message);

const bool forceUseStripeCheckout = false;

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
  const PaywallScreen(
      {super.key, this.mode = PaywallMode.resubscribe});

  final PaywallMode mode;

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

    // Check if user is truly new (no subscription data exists)
    // final isNewUser = currentSub?.subscription == null;

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
    final lastIapErrorShown = useRef<String?>(null);
    final didSeeIapProcessing = useRef(false);

    void dismissProcessingDialog([String? reason]) {
      _debugLog(
        '🧹 Dismissing processing dialog${reason != null ? " - $reason" : ""} | open=${processingDialogOpen.value} mounted=${context.mounted}',
      );
      if (!processingDialogOpen.value) return;
      processingDialogOpen.value = false;
      processingDialogKind.value = null;
      if (!context.mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      final canPop = nav.canPop();
      _debugLog('🧭 root nav canPop=$canPop');
      if (canPop) {
        nav.pop();
      } else {
        _debugLog('⚠️ No route to pop for processing dialog');
      }
    }

    String humanizePurchaseError(String raw) {
      final message = raw.trim();
      final lower = message.toLowerCase();
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
      return 'Purchase failed. Please try again.';
    }

    void showIapError(String message, String source) {
      if (message.isEmpty) return;
      if (message == lastIapErrorShown.value) return;
      lastIapErrorShown.value = message;
      dismissProcessingDialog('iap error $source');
      if (context.mounted) {
        AppToast.error(context, humanizePurchaseError(message));
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

        _debugLog(
          '🧪 IAP state change | prevProcessing=$prevProcessing nextProcessing=$nextProcessing '
          'prevError=${prevState?.lastError ?? ""} nextError=${nextState?.lastError ?? ""} '
          'storeAvailable=${nextState?.storeAvailable ?? false} '
          'dialogOpen=${processingDialogOpen.value}',
        );

        if (next.hasError) {
          dismissProcessingDialog('provider error');
          _debugLog('IAP provider error: ${next.error}');
          showIapError('Purchase failed. Please try again.', 'provider error');
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
                dismissProcessingDialog('iap verification error');
                AppToast.error(
                  context,
                  'Purchase completed but failed to verify subscription. Please restart the app.',
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
        showIapError(iapLastError, 'effect');
        return null;
      }

      if (didSeeIapProcessing.value && !iapProcessing) {
        dismissProcessingDialog('iap processing ended');
      }

      return null;
    }, [
      useIap,
      iapProcessing,
      iapLastError,
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
          final aOrder = a.billingInterval != null
              ? (order[a.billingInterval] ?? 2)
              : 2;
          final bOrder = b.billingInterval != null
              ? (order[b.billingInterval] ?? 2)
              : 2;
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
          displayPriceUsd: 19.99,
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
        AppToast.error(context, 'Unable to open subscription settings');
      }
    }

    Future<void> startStripeCheckout(PlanOption option) async {
      print('🔄 Starting Stripe checkout for plan: ${option.serverPlanId}');
      _debugLog(
        '🧾 Stripe checkout start | plan=${option.serverPlanId} interval=${option.billingInterval}',
      );

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

      if (response.status >= 400) {
        final data = response.data;
        final code = data is Map ? data['code'] : null;
        final message = data is Map && data['error'] is String
            ? data['error'] as String
            : 'Failed to start checkout';
        throw Exception(
            code is String && code.isNotEmpty ? '$code: $message' : message);
      }

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
      _debugLog(
        '🧭 onMainAction start | plan=${activePlanOption.id} serverPlan=${activePlanOption.serverPlanId} interval=${activePlanOption.billingInterval} storeReady=$isStoreReady useIap=$useIap',
      );
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

      _debugLog(
        '🧾 Confirmed selection | plan=${activePlanOption.id} serverPlan=${activePlanOption.serverPlanId} interval=${activePlanOption.billingInterval} useIap=$useIap',
      );
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
            _debugLog(
                '🧾 Dialog open set to true (iap). plan=${activePlanOption.id}');
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

          // Show processing dialog for Stripe
          if (context.mounted) {
            processingDialogOpen.value = true;
            _debugLog(
                '🧾 Dialog open set to true (stripe). plan=${activePlanOption.id}');
            showBlockingProcessingDialog(
              context: context,
              message: 'Redirecting to checkout...',
            );
          }

          try {
            await startStripeCheckout(activePlanOption);
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

          AppToast.error(context, humanizePurchaseError(raw));
        }
      }
    }

    Future<void> onRestorePurchases() async {
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
            AppToast.success(context, 'Subscription cancelled');
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
                
                        const SizedBox(height: 16),
                        Text(
                          mode == PaywallMode.trial
                              ? 'Start your free trial'
                              : 'Subscribe Now',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mode == PaywallMode.trial
                              ? 'Pick a plan. You won\'t be charged until your trial ends.'
                              : 'Pick a plan to get back to full access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _AppRatingBadge(),
                        const SizedBox(height: 24),

                        // --- SUBSCRIPTION PLANS ---
                        _UnifiedPlanCard(
                          plans: plans,
                          selectedPlanId: selectedPlanId.value,
                          onPlanSelected: (id) => selectedPlanId.value = id,
                        ),

                        const SizedBox(height: 16),

                        // Preview App Link
                        GestureDetector(
                          onTap: () {
                            ref.read(previewModeProvider.notifier).enable();
                            if (context.mounted) {
                              context.go('/dashboard');
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              
                                Text(
                                  'Preview the App',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                  Icon(Icons.arrow_right_alt, size: 16, color: colorScheme.primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: colorScheme.appBackground,
                  border: Border(
                      top: BorderSide(
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.3))),
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
                              : () => hasAcknowledgedAutoRenew.value =
                                  !hasAcknowledgedAutoRenew.value,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
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
                                        : (value) => hasAcknowledgedAutoRenew.value =
                                            value ?? false,
                                    activeColor: colorScheme.primary,
                                    checkColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
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
                                        ? 'I understand that my free trial will last for 7 days, and will auto-renew at ${activePlanOption.priceDisplay}${activePlanOption.billingInterval == 'monthly' ? '/month' : '/year'} until cancelled.'
                                        : 'Subscription automatically renews at ${activePlanOption.priceDisplay}${activePlanOption.billingInterval == 'monthly' ? '/month' : '/year'} unless canceled at least 24 hours before the end of the current period. You can manage and cancel subscriptions in your account settings.',
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
                        onPressed:
                            isProcessing || !canConfirmAutoRenew || !isStoreReady
                                ? null
                                : onMainAction,
                        child: Text(
                          isProcessing
                              ? 'Processing...'
                              : !isStoreReady
                                  ? 'Store unavailable'
                                  : mode == PaywallMode.trial &&
                                          activePlanOption.serverPlanId !=
                                              'lifetime'
                                      ? 'Start Free Trial'
                                      : activePlanOption.serverPlanId ==
                                              'lifetime'
                                          ? 'Get Lifetime Access'
                                          : 'Subscribe',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Cancel / Manage Subscription Button
                      if (currentPlanId != 'free' &&
                          (currentProvider == null ||
                              (currentProvider != 'app_store' &&
                                  currentProvider != 'play_store'))) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: isProcessing ? null : onCancelSubscription,
                          child: Text(
                            'Cancel Subscription',
                            style: TextStyle(
                              color: colorScheme.mutedForeground,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],

                      if (currentPlanId != 'free' &&
                          (currentProvider == 'app_store' ||
                              currentProvider == 'play_store') &&
                          currentPlanId != 'lifetime') ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: isProcessing ? null : onManageStoreSubscription,
                          child: Text(
                            'Manage Subscription',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: isProcessing ? null : onRestorePurchases,
                            child: Text(
                              'Restore Purchases',
                              style: TextStyle(
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('https://moneko.io/terms-of-service');
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                            child: Text(
                              'Terms & Privacy',
                              style: TextStyle(
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: plans.asMap().entries.map((entry) {
          final idx = entry.key;
          final plan = entry.value;
          final isSelected = selectedPlanId == plan.id;

          return Column(
            children: [
              if (idx > 0)
                Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                    indent: 16,
                    endIndent: 16),
              GestureDetector(
                onTap: () => onPlanSelected(plan.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(idx == 0 ? 24 : 0),
                      bottom: Radius.circular(idx == plans.length - 1 ? 24 : 0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: 0.8),
                            width: isSelected ? 5.5 : 1.5,
                          ),
                          color: isSelected ? scheme.surface : Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              plan.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: scheme.onSurface,
                              ),
                            ),
                            if (plan.badgeText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  plan.badgeText!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        plan.priceDisplay,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
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
              'lib/assets/images/onboarding/laurel-wreath.png',
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
                  'OUT OF 5',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: contentColor.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 4; i++)
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    Stack(
                      children: [
                        Icon(Icons.star_rounded, color: scheme.outlineVariant.withValues(alpha: 0.5), size: 16),
                        ClipRect(
                          clipper: _FractionalClipper(0.8),
                          child: const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
        
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'We didn’t ask for applause— \n we built a budgeting app.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: contentColor.withValues(alpha: 0.8),
            height: 1.3,
          ),
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
  bool shouldReclip(covariant _FractionalClipper oldClipper) => oldClipper.fraction != fraction;
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
