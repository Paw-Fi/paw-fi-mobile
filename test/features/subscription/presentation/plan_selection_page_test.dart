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
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _FakeSubscriptionManagementNotifier
    extends SubscriptionManagementNotifier {
  _FakeSubscriptionManagementNotifier({
    required this.initialValue,
    required this.refreshedValue,
  });

  final SubscriptionDetails? initialValue;
  final SubscriptionDetails? refreshedValue;

  @override
  Future<SubscriptionDetails?> build() async => initialValue;

  @override
  Future<void> refresh() async {
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
  _FakeIapController(this.initialState);

  final IapState initialState;

  @override
  Future<IapState> build() async => initialState;

  @override
  Future<void> buy(SubscriptionProduct product) async {
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
  Future<void> restorePurchases() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'shows a success toast after a completed purchase on the plan selection page',
    (tester) async {
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

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start your free month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        find.text('✅ Payment successful! Checking subscription...'),
        findsOneWidget,
      );
    },
  );
}
