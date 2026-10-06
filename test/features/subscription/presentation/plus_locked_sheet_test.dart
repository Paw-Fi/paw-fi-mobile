import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/presentation/app_store_commitment_billing.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/presentation/subscription_checkout_shared.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _TestSubscription extends SubscriptionNotifier {
  _TestSubscription(this.subscription);

  final Subscription? subscription;

  @override
  Future<Subscription?> build() async => subscription;
}

class _TestManagement extends SubscriptionManagementNotifier {
  _TestManagement(this.subscription);

  final Subscription? subscription;

  @override
  Future<SubscriptionDetails?> build() async =>
      SubscriptionDetails(subscription: subscription, invoices: const []);
}

class _TestProducts extends SubscriptionProductsNotifier {
  @override
  Future<List<SubscriptionProduct>> build() async => const [
        SubscriptionProduct(
          id: 'plus_yearly',
          platform: 'ios',
          plan: 'plus',
          billingInterval: 'yearly',
          storeProductId: 'yearly',
          displayName: 'Yearly',
          tagline: '',
          badgeText: null,
          isPopular: true,
          displayPriceUsd: 29.99,
          originalPriceUsd: null,
          sortOrder: 0,
        ),
        SubscriptionProduct(
          id: 'plus_monthly',
          platform: 'ios',
          plan: 'plus',
          billingInterval: 'monthly',
          storeProductId: 'monthly',
          displayName: 'Monthly',
          tagline: '',
          badgeText: null,
          isPopular: false,
          displayPriceUsd: 5.99,
          originalPriceUsd: null,
          sortOrder: 1,
        ),
        SubscriptionProduct(
          id: 'lifetime',
          platform: 'ios',
          plan: 'lifetime',
          billingInterval: null,
          storeProductId: 'lifetime_earlybird',
          displayName: 'Lifetime',
          tagline: '',
          badgeText: null,
          isPopular: false,
          displayPriceUsd: 99,
          originalPriceUsd: null,
          sortOrder: 2,
        ),
      ];
}

class _TestIapController extends IapController {
  _TestIapController(
      {this.outcome = 'waiting',
      this.withPrices = true,
      this.withCommitment = true,
      this.loading = false});
  final bool withPrices;
  final bool withCommitment;
  final bool loading;
  final completer = Completer<IapState>();

  final String outcome;
  int purchaseCount = 0;
  String? purchasedProductId;
  bool? usedCommitment;

  @override
  Future<IapState> build() async {
    if (loading) return completer.future;
    return loadedState();
  }

  IapState loadedState() => IapState(
        storeAvailable: true,
        productDetailsById: withPrices
            ? {
                'yearly': ProductDetails(
                    id: 'yearly',
                    title: 'Yearly',
                    description: '',
                    price: r'$99.99',
                    rawPrice: 99.99,
                    currencyCode: 'USD',
                    currencySymbol: r'$'),
              }
            : {},
        commitmentTermsByProductId: withCommitment
            ? const {
                'yearly': AppStoreCommitmentTerms(
                    monthlyPrice: r'$2.49',
                    totalCommitmentPrice: r'$29.88',
                    totalCommitmentPriceValue: 29.88),
              }
            : const {},
        lastError: null,
      );

  @override
  Future<void> buy(
    SubscriptionProduct product, {
    bool useMonthlyCommitment = false,
  }) async {
    purchaseCount += 1;
    purchasedProductId = product.storeProductId;
    usedCommitment = useMonthlyCommitment;
    final current = state.requireValue;
    state = AsyncValue.data(current.copyWith(
      isProcessing: outcome == 'waiting',
      initiatedProductId: product.storeProductId,
      lastCanceledProductId:
          outcome == 'canceled' ? product.storeProductId : null,
      lastCompletedProductId:
          outcome == 'completed' ? product.storeProductId : null,
      lastError: outcome == 'pending'
          ? 'Purchase is pending App Store approval.'
          : outcome == 'failed'
              ? 'Verification failed'
              : null,
    ));
  }

  void complete() {
    final current = state.requireValue;
    state = AsyncValue.data(current.copyWith(
      isProcessing: false,
      lastCompletedProductId: purchasedProductId,
      clearInitiatedProductId: true,
    ));
  }
}

Future<_TestIapController> _showLockedSheet(
  WidgetTester tester, {
  required _TestIapController controller,
  Subscription? subscription,
  PlusFeature? feature,
  double textScale = 1,
  bool dark = false,
}) async {
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
            body: TextButton(
                onPressed: () =>
                    PlusLockedSheet.show(context, highlightedFeature: feature),
                child: const Text('Open locked sheet')))),
    GoRoute(
        path: '/plus-locked',
        builder: (context, state) =>
            PlusLockedSheet(highlightedFeature: feature)),
    GoRoute(
        path: '/plan-selection',
        builder: (context, state) =>
            const Scaffold(body: Text('All plans destination'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      subscriptionNotifierProvider.overrideWith(
        () => _TestSubscription(subscription),
      ),
      subscriptionManagementProvider.overrideWith(
        () => _TestManagement(subscription),
      ),
      subscriptionProductsProvider.overrideWith(_TestProducts.new),
      iapControllerProvider.overrideWith(() => controller),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.tap(find.text('Open locked sheet'));
  await tester.pumpAndSettle();
  expect(find.byType(PlusLockedSheet), findsOneWidget);
  return controller;
}

Future<void> _tapCheckout(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('plus-intro-continue'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _runOnIos(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 2000);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  test('formats yearly Plus price as a monthly equivalent', () {
    expect(formatPlusYearlyMonthlyEquivalent(79.99), r'$6.67');
  });

  test('waits for the matching App Store completion marker', () async {
    var reads = 0;
    final completed = await waitForIapPurchaseCompletion(
      productId: 'monthly',
      readState: () {
        reads += 1;
        return IapState(
          storeAvailable: true,
          productDetailsById: const {},
          lastError: null,
          lastCompletedProductId: reads == 3 ? 'monthly' : null,
        );
      },
      wait: (_) async {},
      maxAttempts: 4,
    );

    expect(completed, isTrue);
    expect(reads, 3);
  });

  test('does not report success when App Store purchase is canceled', () {
    expect(
      waitForIapPurchaseCompletion(
        productId: 'monthly',
        readState: () => const IapState(
          storeAvailable: true,
          productDetailsById: {},
          lastError: null,
          lastCanceledProductId: 'monthly',
        ),
        wait: (_) async {},
      ),
      throwsA(isA<PaymentCanceledException>()),
    );
  });

  test('does not report pending App Store approval as success', () {
    expect(
      waitForIapPurchaseCompletion(
        productId: 'yearly',
        readState: () => const IapState(
          storeAvailable: true,
          productDetailsById: {},
          lastError: 'Purchase is pending App Store approval.',
        ),
        wait: (_) async {},
      ),
      throwsA(isA<IapPurchasePendingException>()),
    );
  });

  testWidgets(
      'Continue selects yearly and preserves existing monthly commitment terms',
      (tester) => _runOnIos(() async {
            final controller = _TestIapController();
            await _showLockedSheet(tester, controller: controller);
            expect(find.text(r'$29.88 per year ($2.49/month)'), findsOneWidget);
            expect(find.text('Monthly'), findsNothing);
            expect(find.text('Lifetime'), findsNothing);
            await _tapCheckout(tester);
            expect(controller.purchasedProductId, 'yearly');
            expect(controller.usedCommitment, true);
            await _tapCheckout(tester);
            expect(controller.purchaseCount, 1);
            expect(find.byType(PlusLockedSheet), findsOneWidget);
            controller.complete();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pumpAndSettle();
            expect(find.byType(PlusLockedSheet), findsNothing);
            await tester.pump(const Duration(seconds: 8));
          }));

  testWidgets(
      'phone layout keeps actions reachable and reviews scrollable',
      (tester) => _runOnIos(() async {
            tester.view.physicalSize = const Size(393, 852);
            await _showLockedSheet(tester, controller: _TestIapController());
            expect(tester.takeException(), isNull);
            final link = find.byKey(const ValueKey('plus-intro-all-plans'));
            await tester.ensureVisible(link);
            await tester.pumpAndSettle();

            await tester.ensureVisible(find.byType(PaywallReviewsSection));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }));

  testWidgets(
      'large text in dark mode remains scrollable without overflow',
      (tester) => _runOnIos(() async {
            tester.view.physicalSize = const Size(320, 640);
            await _showLockedSheet(tester,
                controller: _TestIapController(), textScale: 2, dark: true);
            await tester.ensureVisible(
                find.byKey(const ValueKey('plus-intro-all-plans')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }));

  for (final dark in [false, true]) {
    testWidgets(
        'intro reviews and actions remain accessible at 3x text $dark',
        (tester) => _runOnIos(() async {
              tester.view.physicalSize = const Size(320, 568);
              await _showLockedSheet(tester,
                  controller: _TestIapController(), textScale: 3, dark: dark);
              await tester.ensureVisible(
                  find.byKey(const ValueKey('plus-intro-all-plans')));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.ensureVisible(find.byType(PaywallReviewsSection));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }));
  }

  testWidgets(
      'cached store price stays visible during refresh',
      (tester) => _runOnIos(() async {
            final controller = _TestIapController();
            await _showLockedSheet(tester, controller: controller);
            controller.state = const AsyncLoading<IapState>()
                .copyWithPrevious(AsyncData(controller.loadedState()));
            await tester.pumpAndSettle();
            expect(find.text(r'$29.88 per year ($2.49/month)'), findsOneWidget);
            expect(find.byKey(const ValueKey('plus-intro-price-loading')),
                findsNothing);
          }));

  testWidgets(
      'See all plans routes to plan selection',
      (tester) => _runOnIos(() async {
            await _showLockedSheet(tester, controller: _TestIapController());
            final link = find.byKey(const ValueKey('plus-intro-all-plans'));
            await tester.ensureVisible(link);
            await tester.tap(link);
            await tester.pumpAndSettle();
            expect(find.text('All plans destination'), findsOneWidget);
          }));

  testWidgets(
      'catalog billing terms and existing checkout readiness are preserved',
      (tester) => _runOnIos(() async {
            final controller =
                _TestIapController(withPrices: false, outcome: 'canceled');
            await _showLockedSheet(tester, controller: controller);
            expect(find.text(r'$29.88 per year ($2.49/month)'), findsOneWidget);
            await _tapCheckout(tester);
            expect(controller.purchasedProductId, 'yearly');
            expect(controller.usedCommitment, true);
            await tester.pump(const Duration(seconds: 8));
          }));

  testWidgets(
      'upfront yearly catalog keeps its existing upfront checkout',
      (tester) => _runOnIos(() async {
            final controller =
                _TestIapController(withCommitment: false, outcome: 'canceled');
            await _showLockedSheet(tester, controller: controller);
            expect(find.text(r'$99.99 per year ($8.33/month)'), findsOneWidget);
            await _tapCheckout(tester);
            expect(controller.purchasedProductId, 'yearly');
            expect(controller.usedCommitment, false);
            await tester.pump(const Duration(seconds: 8));
          }));

  testWidgets(
      'initial price skeleton becomes the real annual and monthly price',
      (tester) => _runOnIos(() async {
            final controller = _TestIapController(loading: true);
            await _showLockedSheet(tester, controller: controller);
            expect(find.byKey(const ValueKey('plus-intro-price-loading')),
                findsOneWidget);
            await _tapCheckout(tester);
            expect(controller.purchasedProductId, isNull);
            controller.completer.complete(controller.loadedState());
            await tester.pumpAndSettle();
            expect(find.text(r'$29.88 per year ($2.49/month)'), findsOneWidget);
          }));

  testWidgets(
      'highlighted grouped benefit appears first with the new reviews',
      (tester) => _runOnIos(() async {
            await _showLockedSheet(tester,
                controller: _TestIapController(),
                feature: PlusFeature.walletCreation);
            final wallets =
                tester.getTopLeft(find.text('Unlimited Spaces & Wallets'));
            final capture =
                tester.getTopLeft(find.text('Unlimited AI expense capture'));
            expect(wallets.dy, lessThan(capture.dy));
            expect(find.byType(PaywallReviewsSection), findsOneWidget);
            expect(tester.takeException(), isNull);
          }));

  for (final outcome in ['canceled', 'pending', 'failed']) {
    testWidgets(
        'locked sheet does not report $outcome as a purchase',
        (tester) => _runOnIos(() async {
              final controller = _TestIapController(outcome: outcome);
              await _showLockedSheet(tester, controller: controller);
              await _tapCheckout(tester);
              expect(controller.purchasedProductId, 'yearly');
              expect(find.byType(PlusLockedSheet), findsOneWidget);
              await tester.pump(const Duration(seconds: 8));
            }));
  }

  testWidgets(
      'existing matching trial does not count as a new purchase',
      (tester) => _runOnIos(() async {
            final trial = Subscription(
              id: 'trial',
              userId: 'user-1',
              plan: 'plus',
              status: 'trialing',
              billingInterval: 'yearly',
              createdAt: DateTime(2026, 1, 1),
            );
            final controller = _TestIapController();
            await _showLockedSheet(tester,
                controller: controller, subscription: trial);
            await _tapCheckout(tester);
            expect(controller.purchasedProductId, 'yearly');
            expect(find.byType(PlusLockedSheet), findsOneWidget);
            controller.complete();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pumpAndSettle();
            expect(find.byType(PlusLockedSheet), findsNothing);
            await tester.pump(const Duration(seconds: 8));
          }));
}
