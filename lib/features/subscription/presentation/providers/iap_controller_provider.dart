import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';

import '../../data/models/subscription_product.dart';
import 'subscription_products_provider.dart';
import 'subscription_management_provider.dart';
import 'subscription_provider.dart';

class IapState {
  final bool storeAvailable;
  final Map<String, ProductDetails> productDetailsById;
  final String? lastError;

  const IapState({
    required this.storeAvailable,
    required this.productDetailsById,
    required this.lastError,
  });

  IapState copyWith({
    bool? storeAvailable,
    Map<String, ProductDetails>? productDetailsById,
    String? lastError,
  }) {
    return IapState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      productDetailsById: productDetailsById ?? this.productDetailsById,
      lastError: lastError,
    );
  }
}

class IapController extends AsyncNotifier<IapState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  Future<IapState> build() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const IapState(
          storeAvailable: false, productDetailsById: {}, lastError: null);
    }

    final products = ref.watch(subscriptionProductsProvider).value ??
        const <SubscriptionProduct>[];
    if (products.isEmpty) {
      _ensurePurchaseListener();
      return const IapState(
          storeAvailable: false, productDetailsById: {}, lastError: null);
    }

    _ensurePurchaseListener();

    final isAvailable = await InAppPurchase.instance.isAvailable();
    if (!isAvailable) {
      return const IapState(
          storeAvailable: false, productDetailsById: {}, lastError: null);
    }

    final ids = products.map((p) => p.storeProductId).toSet();
    final response = await InAppPurchase.instance.queryProductDetails(ids);
    if (response.error != null) {
      return IapState(
        storeAvailable: true,
        productDetailsById: const {},
        lastError: response.error!.message,
      );
    }

    final map = <String, ProductDetails>{
      for (final d in response.productDetails) d.id: d,
    };

    return IapState(
        storeAvailable: true, productDetailsById: map, lastError: null);
  }

  void _ensurePurchaseListener() {
    if (_purchaseSubscription != null) return;

    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error) {
        state = AsyncValue.data(
          (state.value ??
                  const IapState(
                      storeAvailable: false,
                      productDetailsById: {},
                      lastError: null))
              .copyWith(lastError: error.toString()),
        );
      },
    );

    ref.onDispose(() {
      _purchaseSubscription?.cancel();
      _purchaseSubscription = null;
    });
  }

  String? _platformString() {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return null;
  }

  SubscriptionProduct? _findCatalogProduct(String storeProductId) {
    final products = ref.read(subscriptionProductsProvider).value ??
        const <SubscriptionProduct>[];
    try {
      return products.firstWhere((p) => p.storeProductId == storeProductId);
    } catch (_) {
      return null;
    }
  }

  Future<void> buy(SubscriptionProduct product) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw Exception('In-app purchases are not supported on this platform');
    }

    final user = ref.read(authProvider);
    if (user.isEmpty) {
      throw Exception('User not logged in');
    }

    final current = state.valueOrNull;
    final details = current?.productDetailsById[product.storeProductId];
    if (details == null) {
      throw Exception('Product not available');
    }

    final platform = _platformString();
    if (platform == null) {
      throw Exception('In-app purchases are not supported on this platform');
    }

    PurchaseParam purchaseParam;

    if (platform == 'android' && details is GooglePlayProductDetails) {
      // For Google subscriptions, an offer token is required.
      // GooglePlayProductDetails exposes a convenience getter for the selected offer.
      final offerToken = details.offerToken;

      if (!product.isLifetime && (offerToken == null || offerToken.isEmpty)) {
        throw Exception('No subscription offer available for this product');
      }
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: details,
        applicationUserName: user.uid,
        offerToken: offerToken,
      );
    } else {
      purchaseParam = PurchaseParam(
        productDetails: details,
        applicationUserName: user.uid,
      );
    }

    // Subscriptions and non-consumables both use buyNonConsumable.
    final ok = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!ok) {
      throw Exception('Failed to start purchase');
    }
  }

  Future<void> restorePurchases() async {
    final user = ref.read(authProvider);
    if (user.isEmpty) {
      throw Exception('User not logged in');
    }

    await InAppPurchase.instance
        .restorePurchases(applicationUserName: user.uid);
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.pending) {
          continue;
        }

        if (purchase.status == PurchaseStatus.error) {
          state = AsyncValue.data(
            (state.value ??
                    const IapState(
                        storeAvailable: false,
                        productDetailsById: {},
                        lastError: null))
                .copyWith(
                    lastError: purchase.error?.message ?? 'Purchase error'),
          );
          continue;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final catalog = _findCatalogProduct(purchase.productID);
          if (catalog == null) {
            state = AsyncValue.data(
              (state.value ??
                      const IapState(
                          storeAvailable: false,
                          productDetailsById: {},
                          lastError: null))
                  .copyWith(lastError: 'Unknown product purchased'),
            );
            continue;
          }

          final platform = _platformString();
          if (platform == null) continue;

          final response = await supabase.functions.invoke(
            'verify-iap-purchase',
            body: {
              'platform': platform,
              'storeProductId': catalog.storeProductId,
              'verificationData': {
                'source': purchase.verificationData.source,
                'localVerificationData':
                    purchase.verificationData.localVerificationData,
                'serverVerificationData':
                    purchase.verificationData.serverVerificationData,
              },
              'purchaseId': purchase.purchaseID,
              'transactionDate': purchase.transactionDate,
            },
          );

          if (response.status >= 400) {
            state = AsyncValue.data(
              (state.value ??
                      const IapState(
                          storeAvailable: false,
                          productDetailsById: {},
                          lastError: null))
                  .copyWith(lastError: 'Verification failed'),
            );
            continue;
          }

          // Refresh subscription state
          await ref.read(subscriptionManagementProvider.notifier).refresh();
          await ref.read(subscriptionNotifierProvider.notifier).refresh();
        }
      } catch (e) {
        state = AsyncValue.data(
          (state.value ??
                  const IapState(
                      storeAvailable: false,
                      productDetailsById: {},
                      lastError: null))
              .copyWith(lastError: e.toString()),
        );
      } finally {
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {
            // Ignore completion errors; store will retry.
          }
        }
      }
    }
  }
}

final iapControllerProvider = AsyncNotifierProvider<IapController, IapState>(
  () => IapController(),
);
