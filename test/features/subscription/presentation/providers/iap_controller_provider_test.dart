import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/subscription/data/models/subscription_product.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionResponse;

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');
}

class _TestProducts extends SubscriptionProductsNotifier {
  @override
  Future<List<SubscriptionProduct>> build() async => const [
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
          sortOrder: 0,
        ),
      ];
}

class _TestIapController extends IapController {
  _TestIapController({this.activeProductId = 'monthly'});

  final String activeProductId;

  @override
  Future<IapState> build() async => IapState(
        storeAvailable: true,
        productDetailsById: const {},
        lastError: null,
        isProcessing: true,
        initiatedProductId: activeProductId,
      );

  @override
  Future<FunctionResponse> invokePurchaseVerification(
    Map<String, dynamic> body,
  ) async {
    expect(body['storeProductId'], 'lifetime_earlybird');
    return FunctionResponse(
      status: 400,
      data: {'error': 'Old transaction could not be verified'},
    );
  }
}

PurchaseDetails _purchase(String productId, PurchaseStatus status) {
  return PurchaseDetails(
    productID: productId,
    purchaseID: 'older-transaction',
    transactionDate: null,
    status: status,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'signed-transaction',
      serverVerificationData: 'signed-transaction',
      source: 'app_store',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('background verification failure preserves a different active purchase',
      () async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      subscriptionProductsProvider.overrideWith(_TestProducts.new),
      iapControllerProvider.overrideWith(_TestIapController.new),
    ]);
    addTearDown(container.dispose);

    await container.read(iapControllerProvider.future);
    await container.read(subscriptionProductsProvider.future);

    await container.read(iapControllerProvider.notifier).handlePurchaseUpdates(
      [_purchase('lifetime_earlybird', PurchaseStatus.purchased)],
    );

    final state = container.read(iapControllerProvider).requireValue;
    expect(state.isProcessing, isTrue);
    expect(state.initiatedProductId, 'monthly');
    expect(state.lastError, isNull);
    expect(state.lastCompletedProductId, isNull);
    expect(state.lastCanceledProductId, isNull);
  });

  test('verification failure for the active product remains visible', () async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      subscriptionProductsProvider.overrideWith(_TestProducts.new),
      iapControllerProvider.overrideWith(
        () => _TestIapController(activeProductId: 'lifetime_earlybird'),
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(iapControllerProvider.future);
    await container.read(subscriptionProductsProvider.future);

    await container.read(iapControllerProvider.notifier).handlePurchaseUpdates(
      [_purchase('lifetime_earlybird', PurchaseStatus.purchased)],
    );

    final state = container.read(iapControllerProvider).requireValue;
    expect(state.isProcessing, isFalse);
    expect(state.initiatedProductId, isNull);
    expect(state.lastError, 'Old transaction could not be verified');
    expect(state.lastCompletedProductId, isNull);
  });

  test('unrelated cancellation, stream error, and unknown product are isolated',
      () async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      subscriptionProductsProvider.overrideWith(_TestProducts.new),
      iapControllerProvider.overrideWith(_TestIapController.new),
    ]);
    addTearDown(container.dispose);

    await container.read(iapControllerProvider.future);
    await container.read(subscriptionProductsProvider.future);
    await container.read(iapControllerProvider.notifier).handlePurchaseUpdates([
      _purchase('lifetime_earlybird', PurchaseStatus.canceled),
      _purchase('lifetime_earlybird', PurchaseStatus.error),
      _purchase('unknown_old_product', PurchaseStatus.purchased),
    ]);

    final state = container.read(iapControllerProvider).requireValue;
    expect(state.isProcessing, isTrue);
    expect(state.initiatedProductId, 'monthly');
    expect(state.lastError, isNull);
    expect(state.lastCompletedProductId, isNull);
    expect(state.lastCanceledProductId, isNull);
  });
}
