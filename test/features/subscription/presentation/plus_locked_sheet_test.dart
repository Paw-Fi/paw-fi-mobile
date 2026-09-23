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
  _TestIapController({this.outcome = 'waiting'});

  final String outcome;
  String? purchasedProductId;
  bool? usedCommitment;

  @override
  Future<IapState> build() async => const IapState(
        storeAvailable: true,
        productDetailsById: {},
        commitmentTermsByProductId: {
          'yearly': AppStoreCommitmentTerms(
            monthlyPrice: r'$2.49',
            totalCommitmentPrice: r'$29.88',
            totalCommitmentPriceValue: 29.88,
          ),
        },
        lastError: null,
      );

  @override
  Future<void> buy(
    SubscriptionProduct product, {
    bool useMonthlyCommitment = false,
  }) async {
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
}) async {
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
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => PlusLockedSheet.show(context),
            child: const Text('Open locked sheet'),
          );
        }),
      ),
    ),
  ));
  await tester.tap(find.text('Open locked sheet'));
  await tester.pumpAndSettle();
  expect(find.byType(PlusLockedSheet), findsOneWidget);
  return controller;
}

Future<void> _tapCheckout(WidgetTester tester) async {
  final button = find.byType(PaywallCheckoutActionButton);
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

  for (final scenario in [
    (product: 'yearly', commitment: true),
    (product: 'monthly', commitment: false),
    (product: 'lifetime_earlybird', commitment: false),
  ]) {
    testWidgets(
        'locked sheet starts ${scenario.product} with matching terms',
        (tester) => _runOnIos(() async {
              final controller = _TestIapController();
              await _showLockedSheet(tester, controller: controller);
              if (scenario.product == 'monthly') {
                await tester.tap(find.text('Monthly').first);
                await tester.pumpAndSettle();
              } else if (scenario.product == 'lifetime_earlybird') {
                await tester.tap(find.text('Lifetime').first);
                await tester.pumpAndSettle();
              }
              expect(find.byType(PaywallAutoRenewCheckbox), findsNothing);
              await _tapCheckout(tester);
              expect(controller.purchasedProductId, scenario.product);
              expect(controller.usedCommitment, scenario.commitment);
              expect(find.byType(PlusLockedSheet), findsOneWidget);
              controller.complete();
              await tester.pump(const Duration(milliseconds: 500));
              await tester.pump(const Duration(seconds: 8));
            }));
  }

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
