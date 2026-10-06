import '../../../helpers/paywall_test_fonts.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart' show rootNavigatorKey;
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/presentation/pages/plan_selection_page.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _FakeSubscriptionManagementNotifier
    extends SubscriptionManagementNotifier {
  _FakeSubscriptionManagementNotifier({
    required this.initialValue,
    required this.refreshedValue,
    this.refreshValues,
  });

  final SubscriptionDetails? initialValue;
  final SubscriptionDetails? refreshedValue;
  final List<SubscriptionDetails?>? refreshValues;
  var refreshCallCount = 0;

  @override
  Future<SubscriptionDetails?> build() async => initialValue;

  @override
  Future<void> refresh() async {
    final queuedValues = refreshValues;
    if (queuedValues != null && refreshCallCount < queuedValues.length) {
      state = AsyncValue.data(queuedValues[refreshCallCount]);
      refreshCallCount += 1;
      return;
    }
    state = AsyncValue.data(refreshedValue);
  }
}

class _FakeSubscriptionProductsNotifier extends SubscriptionProductsNotifier {
  _FakeSubscriptionProductsNotifier(this.products);

  final List<SubscriptionProduct> products;

  @override
  Future<List<SubscriptionProduct>> build() async => products;
}

class _FakeIapController extends IapController {
  _FakeIapController(
    this.initialState, {
    this.completesPurchase = true,
    this.cancelsFirstPurchase = false,
  });

  final IapState initialState;
  final bool completesPurchase;
  final bool cancelsFirstPurchase;
  var buyCallCount = 0;
  var restoreCallCount = 0;

  @override
  Future<IapState> build() async => initialState;

  @override
  Future<void> buy(
    SubscriptionProduct product, {
    bool useMonthlyCommitment = false,
  }) async {
    buyCallCount += 1;
    state = AsyncValue.data(
      IapState(
        storeAvailable: true,
        productDetailsById: const {},
        lastError: null,
        lastErrorCode: null,
        isProcessing: true,
        initiatedProductId: product.storeProductId,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));

    if (cancelsFirstPurchase && buyCallCount == 1) {
      state = AsyncValue.data(
        IapState(
          storeAvailable: true,
          productDetailsById: const {},
          lastError: null,
          lastErrorCode: null,
          isProcessing: false,
          lastCanceledProductId: product.storeProductId,
        ),
      );
      return;
    }

    if (!completesPurchase) {
      return;
    }

    state = AsyncValue.data(
      IapState(
        storeAvailable: true,
        productDetailsById: const {},
        lastError: null,
        lastErrorCode: null,
        isProcessing: false,
        initiatedProductId: product.storeProductId,
        lastCompletedProductId: product.storeProductId,
      ),
    );
  }

  @override
  Future<void> restorePurchases() async {
    restoreCallCount += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPaywallTestFonts);

  final inactiveSubscription = SubscriptionDetails(
    subscription: null,
    invoices: const [],
  );

  final activeSubscription = SubscriptionDetails(
    subscription: Subscription(
      id: 'sub_1',
      userId: 'user_1',
      provider: 'app_store',
      storeProductId: 'monthly',
      appStoreInAppOwnershipType: 'FAMILY_SHARED',
      plan: 'plus',
      status: 'active',
      billingInterval: 'monthly',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    ),
    invoices: const [],
  );

  const monthlyProduct = SubscriptionProduct(
    id: 'plus_monthly',
    platform: 'ios',
    plan: 'plus',
    billingInterval: 'monthly',
    storeProductId: 'monthly',
    displayName: 'Monthly',
    tagline: 'Flexible. Cancel anytime.',
    badgeText: null,
    isPopular: false,
    displayPriceUsd: 5.99,
    originalPriceUsd: null,
    sortOrder: 0,
  );

  const yearlyProduct = SubscriptionProduct(
    id: 'plus_yearly',
    platform: 'ios',
    plan: 'plus',
    billingInterval: 'yearly',
    storeProductId: 'yearly',
    displayName: 'Annual',
    tagline: '',
    badgeText: '44% OFF',
    isPopular: true,
    displayPriceUsd: 99.99,
    originalPriceUsd: null,
    sortOrder: 1,
  );
  const lifetimeProduct = SubscriptionProduct(
    id: 'lifetime',
    platform: 'ios',
    plan: 'lifetime',
    billingInterval: null,
    storeProductId: 'lifetime',
    displayName: 'Lifetime',
    tagline: '',
    badgeText: null,
    isPopular: false,
    displayPriceUsd: 149.99,
    originalPriceUsd: null,
    sortOrder: 2,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 2000);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  for (final dark in [false, true]) {
    for (final configuration in [
      (size: const Size(393, 852), scale: 1.0),
      (size: const Size(320, 568), scale: 1.0),
      (size: const Size(320, 568), scale: 2.0),
      (size: const Size(320, 568), scale: 3.0),
    ]) {
      testWidgets(
          'stacked plans remain scrollable with fixed artwork $dark $configuration',
          (tester) async {
        tester.view.physicalSize = configuration.size;
        final fakeIap = _FakeIapController(const IapState(
          storeAvailable: true,
          productDetailsById: {},
          lastError: null,
        ));
        final router = GoRouter(
          navigatorKey: rootNavigatorKey,
          routes: [
            GoRoute(
                path: '/',
                builder: (_, __) => const PlanSelectionPage(
                    preferredPlanId: 'plus',
                    preferredBillingInterval: 'yearly'))
          ],
        );
        await tester.pumpWidget(ProviderScope(
          overrides: [
            subscriptionManagementProvider.overrideWith(() =>
                _FakeSubscriptionManagementNotifier(
                    initialValue: inactiveSubscription,
                    refreshedValue: inactiveSubscription)),
            subscriptionProductsProvider.overrideWith(() =>
                _FakeSubscriptionProductsNotifier(
                    const [monthlyProduct, lifetimeProduct, yearlyProduct])),
            iapControllerProvider.overrideWith(() => fakeIap),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(configuration.scale),
                padding: configuration.size.width == 393
                    ? const EdgeInsets.only(top: 44, bottom: 34)
                    : const EdgeInsets.only(top: 20),
              ),
              child: child!,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('plan-selection-floating-actions')),
            findsNothing);
        expect(find.byType(PaywallCheckoutActionButton), findsNothing);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
            tester.getRect(
                find.byKey(const ValueKey('plan-selection-background'))),
            Offset.zero & configuration.size);
        final annual = find.text('Yearly');
        final monthly = find.text('Monthly');
        final lifetime = find.text('Lifetime');
        expect(tester.getTopLeft(annual).dy,
            lessThan(tester.getTopLeft(monthly).dy));
        expect(tester.getTopLeft(monthly).dy,
            lessThan(tester.getTopLeft(lifetime).dy));
        expect(
            find.byWidgetPredicate((widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal),
            findsNothing);
        for (final plan in [annual, monthly, lifetime]) {
          await tester.ensureVisible(plan);
          await tester.pumpAndSettle();
          await tester.tap(plan);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (find.byType(CheckboxListTile).evaluate().isNotEmpty) {
            await tester.ensureVisible(find.byType(CheckboxListTile));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.byType(PaywallCheckoutActionButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final panel =
              find.byKey(const ValueKey('plan-selection-floating-actions'));
          expect(panel, findsOneWidget);
          final initialPanelRect = tester.getRect(panel);
          expect(initialPanelRect.bottom,
              lessThanOrEqualTo(configuration.size.height));
          await tester.drag(
              find.byKey(const ValueKey('plan-selection-viewport')),
              const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(tester.getRect(panel), initialPanelRect,
              reason: 'Checkout stays fixed while the plans scroll.');
          final action = tester.widget<PaywallCheckoutActionButton>(
              find.byType(PaywallCheckoutActionButton));
          final container = ProviderScope.containerOf(
              tester.element(find.byType(PlanSelectionPage)));
          await container
              .read(subscriptionManagementProvider.notifier)
              .refresh();
          await tester.pumpAndSettle();
          expect(
              tester
                  .widget<PaywallCheckoutActionButton>(
                      find.byType(PaywallCheckoutActionButton))
                  .option
                  .id,
              action.option.id);
          expect(
              tester
                  .getSize(find.byKey(const ValueKey('plan-selection-hero')))
                  .height,
              220);
          expect(
              tester
                  .getSize(find.byKey(const ValueKey('plan-selection-rating')))
                  .height,
              90);
          final viewport = tester.widget<SingleChildScrollView>(
              find.byKey(const ValueKey('plan-selection-viewport')));
          expect(viewport.physics, isA<AlwaysScrollableScrollPhysics>());
        }
        expect(find.text('Get Lifetime Access'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(fakeIap.buyCallCount, 0);
        await tester.ensureVisible(find.text('Restore Purchase'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets(
    'automatically restores family sharing access and shows an explanation dialog',
    (tester) async {
      final fakeIapController = _FakeIapController(
        const IapState(
          storeAvailable: true,
          productDetailsById: {},
          lastError: null,
          lastErrorCode: null,
        ),
      );
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/plans',
        routes: [
          GoRoute(
            path: '/plans',
            builder: (_, __) => const PlanSelectionPage(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Dashboard')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionManagementProvider.overrideWith(
              () => _FakeSubscriptionManagementNotifier(
                initialValue: inactiveSubscription,
                refreshedValue: activeSubscription,
              ),
            ),
            subscriptionProductsProvider.overrideWith(
              () => _FakeSubscriptionProductsNotifier(const [monthlyProduct]),
            ),
            iapControllerProvider.overrideWith(() => fakeIapController),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fakeIapController.restoreCallCount, 1);
      expect(find.text('Family sharing included'), findsWidgets);
      expect(find.textContaining('Plus plan'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'shows a family badge in the current plan banner for family-shared app store access',
    (tester) async {
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/plans',
        routes: [
          GoRoute(
            path: '/plans',
            builder: (_, __) => const PlanSelectionPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionManagementProvider.overrideWith(
              () => _FakeSubscriptionManagementNotifier(
                initialValue: activeSubscription,
                refreshedValue: activeSubscription,
              ),
            ),
            subscriptionProductsProvider.overrideWith(
              () => _FakeSubscriptionProductsNotifier(const [monthlyProduct]),
            ),
            iapControllerProvider.overrideWith(
              () => _FakeIapController(
                const IapState(
                  storeAvailable: true,
                  productDetailsById: {},
                  lastError: null,
                  lastErrorCode: null,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Family Sharing'), findsOneWidget);
      expect(find.text('Manage'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'shows a success toast after a completed purchase on the plan selection page',
    (tester) async {
      final fakeIapController = _FakeIapController(
        const IapState(
          storeAvailable: true,
          productDetailsById: {},
          lastError: null,
          lastErrorCode: null,
        ),
      );
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/plans',
        routes: [
          GoRoute(
            path: '/plans',
            builder: (_, __) => const PlanSelectionPage(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Dashboard')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionManagementProvider.overrideWith(
              () => _FakeSubscriptionManagementNotifier(
                initialValue: inactiveSubscription,
                refreshedValue: activeSubscription,
                refreshValues: [
                  inactiveSubscription,
                  inactiveSubscription,
                  inactiveSubscription,
                  inactiveSubscription,
                  inactiveSubscription,
                  inactiveSubscription,
                  activeSubscription,
                ],
              ),
            ),
            subscriptionProductsProvider.overrideWith(
              () => _FakeSubscriptionProductsNotifier(const [monthlyProduct]),
            ),
            iapControllerProvider.overrideWith(() => fakeIapController),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Subscribe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(fakeIapController.buyCallCount, 1);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'does not complete checkout from an existing automatic trial before StoreKit confirms',
    (tester) async {
      final fakeIapController = _FakeIapController(
        const IapState(
          storeAvailable: true,
          productDetailsById: {},
          lastError: null,
          lastErrorCode: null,
        ),
        completesPurchase: false,
      );
      final automaticTrial = SubscriptionDetails(
        subscription: Subscription(
          id: 'trial_1',
          userId: 'user_1',
          provider: 'stripe',
          plan: 'plus',
          status: 'trialing',
          billingInterval: 'yearly',
          currentPeriodEnd: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
        ),
        invoices: const [],
      );
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/plans',
        routes: [
          GoRoute(
            path: '/plans',
            builder: (_, __) => const PlanSelectionPage(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Dashboard')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionManagementProvider.overrideWith(
              () => _FakeSubscriptionManagementNotifier(
                initialValue: automaticTrial,
                refreshedValue: automaticTrial,
              ),
            ),
            subscriptionProductsProvider.overrideWith(
              () => _FakeSubscriptionProductsNotifier(const [monthlyProduct]),
            ),
            iapControllerProvider.overrideWith(() => fakeIapController),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Subscribe'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 2));

      expect(fakeIapController.buyCallCount, 1);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.textContaining('Payment successful'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'shows cancellation once for the active StoreKit attempt and allows retry',
    (tester) async {
      final fakeIapController = _FakeIapController(
        const IapState(
          storeAvailable: true,
          productDetailsById: {},
          lastError: null,
          lastErrorCode: null,
        ),
        completesPurchase: false,
        cancelsFirstPurchase: true,
      );
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/plans',
        routes: [
          GoRoute(
            path: '/plans',
            builder: (_, __) => const PlanSelectionPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionManagementProvider.overrideWith(
              () => _FakeSubscriptionManagementNotifier(
                initialValue: inactiveSubscription,
                refreshedValue: inactiveSubscription,
              ),
            ),
            subscriptionProductsProvider.overrideWith(
              () => _FakeSubscriptionProductsNotifier(const [monthlyProduct]),
            ),
            iapControllerProvider.overrideWith(() => fakeIapController),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Subscribe'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(fakeIapController.buyCallCount, 1);
      expect(find.text('Payment canceled'), findsOneWidget);

      await tester.tap(find.textContaining('Subscribe'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(fakeIapController.buyCallCount, 2);
      await tester.pump(const Duration(seconds: 7));
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
