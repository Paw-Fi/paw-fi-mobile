import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';

import '../../data/models/subscription_product.dart';
import 'subscription_products_provider.dart';
import 'subscription_management_provider.dart';

void _debugLog(Object? message) {
  debugPrint(message?.toString() ?? 'null');
}

// Intentionally shadow dart:core print in this file so any existing purchase
// flow logs never ship in release builds.
// ignore: avoid_print
void print(Object? message) => _debugLog(message);

class IapState {
  final bool storeAvailable;
  final Map<String, ProductDetails> productDetailsById;
  final String? lastError;
  final bool isProcessing;
  /// The product ID that the user initiated a purchase for in this session.
  /// Used to distinguish between user-initiated purchases and pending purchases
  /// from previous sessions that get processed when the listener is set up.
  final String? initiatedProductId;
  /// The product ID of the last successfully completed purchase.
  /// Set when a purchase matching initiatedProductId completes successfully.
  final String? lastCompletedProductId;

  const IapState({
    required this.storeAvailable,
    required this.productDetailsById,
    required this.lastError,
    this.isProcessing = false,
    this.initiatedProductId,
    this.lastCompletedProductId,
  });

  IapState copyWith({
    bool? storeAvailable,
    Map<String, ProductDetails>? productDetailsById,
    String? lastError,
    bool? isProcessing,
    String? initiatedProductId,
    String? lastCompletedProductId,
    bool clearInitiatedProductId = false,
    bool clearLastCompletedProductId = false,
  }) {
    return IapState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      productDetailsById: productDetailsById ?? this.productDetailsById,
      lastError: lastError,
      isProcessing: isProcessing ?? this.isProcessing,
      initiatedProductId: clearInitiatedProductId ? null : (initiatedProductId ?? this.initiatedProductId),
      lastCompletedProductId: clearLastCompletedProductId ? null : (lastCompletedProductId ?? this.lastCompletedProductId),
    );
  }
}

class IapController extends AsyncNotifier<IapState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _processingTimeout;

  static const _processingTimeoutDuration = Duration(minutes: 2);

  IapState _fallbackState() => const IapState(
        storeAvailable: false,
        productDetailsById: {},
        lastError: null,
      );

  void _setState({
    bool? storeAvailable,
    Map<String, ProductDetails>? productDetailsById,
    String? lastError,
    bool? isProcessing,
    String? initiatedProductId,
    String? lastCompletedProductId,
    bool clearInitiatedProductId = false,
    bool clearLastCompletedProductId = false,
  }) {
    final current = state.valueOrNull ?? _fallbackState();
    final next = current.copyWith(
      storeAvailable: storeAvailable,
      productDetailsById: productDetailsById,
      lastError: lastError,
      isProcessing: isProcessing,
      initiatedProductId: initiatedProductId,
      lastCompletedProductId: lastCompletedProductId,
      clearInitiatedProductId: clearInitiatedProductId,
      clearLastCompletedProductId: clearLastCompletedProductId,
    );

    print('📊 _setState called: isProcessing=${next.isProcessing}, lastError=${next.lastError}');

    // Safety: never allow the UI to be stuck forever.
    if (next.isProcessing) {
      _processingTimeout?.cancel();
      _processingTimeout = Timer(_processingTimeoutDuration, () {
        final latest = state.valueOrNull ?? _fallbackState();
        if (!latest.isProcessing) return;
        print('⏰ Processing timeout triggered');
        state = AsyncValue.data(
          latest.copyWith(
            isProcessing: false,
            lastError: 'Purchase timed out. Please try again.',
          ),
        );
      });
    } else {
      _processingTimeout?.cancel();
      _processingTimeout = null;
    }

    state = AsyncValue.data(next);
    print('📊 State updated successfully');
  }

  @override
  Future<IapState> build() async {
    print('🏗️ IapController.build() called');
    print('🌐 Platform: ${defaultTargetPlatform.toString()}, isWeb: $kIsWeb');

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      print('⚠️ IAP not supported on this platform');
      return const IapState(
          storeAvailable: false, productDetailsById: {}, lastError: null);
    }

    final products = ref.watch(subscriptionProductsProvider).value ??
        const <SubscriptionProduct>[];
    print('📦 Loaded ${products.length} products from catalog');
    print('🏷️ Product IDs: ${products.map((p) => p.storeProductId).toList()}');

    if (products.isEmpty) {
      print('⚠️ No products loaded from catalog');
      _ensurePurchaseListener();
      return const IapState(
          storeAvailable: false, productDetailsById: {}, lastError: null);
    }

    _ensurePurchaseListener();

    print('🔍 Checking if IAP store is available...');
    final isAvailable = await InAppPurchase.instance.isAvailable();
    print('🏪 Store available: $isAvailable');

    if (!isAvailable) {
      print('❌ Store not available');
      return const IapState(
          storeAvailable: false, productDetailsById: {}, lastError: null);
    }

    final ids = products.map((p) => p.storeProductId).toSet();
    print('🔍 Querying product details for: $ids');

    final response = await InAppPurchase.instance.queryProductDetails(ids);

    if (response.error != null) {
      print('❌ Query error: ${response.error!.message}');
      return IapState(
        storeAvailable: true,
        productDetailsById: const {},
        lastError: response.error!.message,
      );
    }

    print('✅ Found ${response.productDetails.length} product details');
    print(
        '📋 Product details IDs: ${response.productDetails.map((p) => p.id).toList()}');

    final map = <String, ProductDetails>{
      for (final d in response.productDetails) d.id: d,
    };

    return IapState(
        storeAvailable: true, productDetailsById: map, lastError: null);
  }

  void _ensurePurchaseListener() {
    if (_purchaseSubscription != null) {
      print('✅ Purchase listener already active');
      return;
    }

    print('🎧 Setting up purchase stream listener...');
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error) {
        print('❌ Purchase stream error: $error');
        _setState(
          isProcessing: false,
          lastError: error.toString(),
        );
      },
    );
    print('✅ Purchase stream listener set up');
    print(
        '🎧 purchaseStream isBroadcast=${InAppPurchase.instance.purchaseStream.isBroadcast}');

    ref.onDispose(() {
      print('Disposing purchase listener');
      _processingTimeout?.cancel();
      _processingTimeout = null;
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
    print('🚀 buy() called for product: ${product.storeProductId}');
    final startedAt = DateTime.now();

    try {
      print(
          '🧪 IAP preflight: storeAvailable=${state.valueOrNull?.storeAvailable} hasDetails=${state.valueOrNull?.productDetailsById.containsKey(product.storeProductId) == true}');
      print('🧭 buy() step 1: platform check start');
      print('📱 Platform: ${defaultTargetPlatform.toString()}');

      if (defaultTargetPlatform != TargetPlatform.iOS) {
        print('❌ Platform check failed: not iOS');
        throw Exception('In-app purchases are not supported on this platform');
      }
      print('✅ Platform check passed: iOS');

      print('🧭 buy() step 2: read authProvider start');
      final user = ref.read(authProvider);
      print('👤 User present: ${user.uid.isNotEmpty}');
      if (user.isEmpty) {
        print('❌ User check failed: not logged in');
        throw Exception('User not logged in');
      }
      print('✅ User check passed');

      print('🧭 buy() step 3: read state start');
      final current = state.valueOrNull;
      print('📊 Current state: ${current != null ? "has value" : "null"}');
      print(
          '🏪 Available products: ${current?.productDetailsById.keys.toList()}');
      print(
          '🏪 storeAvailable=${current?.storeAvailable} lastError=${current?.lastError ?? ""}');

      print('🧭 buy() step 4: find product details');
      final details = current?.productDetailsById[product.storeProductId];
      print(
          '🔍 Product details lookup for ${product.storeProductId}: ${details != null ? "FOUND" : "NOT FOUND"}');

      if (details == null) {
        print('❌ Product details check failed: not available');
        throw Exception('Product not available');
      }
      print(
          '✅ Product details: id=${details.id}, title=${details.title}, price=${details.price}');

      print('🧭 buy() step 5: platform string');
      final platform = _platformString();
      print('🔧 Platform string: $platform');
      if (platform == null) {
        print('❌ Platform string check failed');
        throw Exception('In-app purchases are not supported on this platform');
      }
      print('✅ Platform string check passed');

      print('🧭 buy() step 6: set processing state');
      // Set processing state and track which product we're buying
      // This is critical to distinguish user-initiated purchases from
      // pending purchases from previous sessions
      _setState(
        isProcessing: true,
        lastError: null,
        initiatedProductId: product.storeProductId,
        clearLastCompletedProductId: true,
      );
      print('✅ Processing state set to true, initiatedProductId=${product.storeProductId}');

      PurchaseParam purchaseParam;

      print('🧭 buy() step 7: build purchase param');
      if (platform == 'android' && details is GooglePlayProductDetails) {
        print('🤖 Android purchase flow');
        // For Google subscriptions, an offer token is required.
        // GooglePlayProductDetails exposes a convenience getter for the selected offer.
        final offerToken = details.offerToken;

        if (!product.isLifetime && (offerToken == null || offerToken.isEmpty)) {
          print('❌ No offer token available for Android subscription');
          _setState(isProcessing: false, lastError: 'No subscription offer');
          throw Exception('No subscription offer available for this product');
        }
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: details,
          applicationUserName: user.uid,
          offerToken: offerToken,
        );
        print('✅ Android purchase param created');
      } else {
        print('🍎 iOS purchase flow');
        purchaseParam = PurchaseParam(
          productDetails: details,
          applicationUserName: user.uid,
        );
        print('✅ iOS purchase param created');
      }

      print('🧭 buy() step 8: call buyNonConsumable');
      print(
          '📋 Purchase param details: productId=${purchaseParam.productDetails.id}, userName=${purchaseParam.applicationUserName}');

      // Subscriptions and non-consumables both use buyNonConsumable.
      final ok = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('💳 buyNonConsumable returned: $ok');
      print(
          '🧭 buyNonConsumable completed at ${DateTime.now().toIso8601String()}');

      if (!ok) {
        print('❌ Purchase failed: buyNonConsumable returned false');
        _setState(isProcessing: false, lastError: 'Failed to start purchase');
        throw Exception('Failed to start purchase');
      }

      print(
          '✅ Purchase initiated successfully, waiting for purchase stream updates...');
    } catch (error, stackTrace) {
      print('❌ buy() threw: $error');
      print('🧵 buy() stackTrace: $stackTrace');

      // If we error before receiving any purchaseStream updates, ensure the UI
      // is not stuck in a processing state.
      _setState(
        isProcessing: false,
        lastError: error.toString(),
      );
      rethrow;
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      print('🏁 buy() finished. elapsed=${elapsed.inMilliseconds}ms');
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
    print('🔔 _onPurchaseUpdated called with ${purchases.length} purchase(s)');
    print(
        '🧭 _onPurchaseUpdated at ${DateTime.now().toIso8601String()} processing=${state.valueOrNull?.isProcessing}');

    for (final purchase in purchases) {
      print(
          '📦 Processing purchase: id=${purchase.purchaseID}, productId=${purchase.productID}, status=${purchase.status}');

      try {
        if (purchase.status == PurchaseStatus.pending) {
          print('⏳ Purchase pending, skipping...');
          continue;
        }

        if (purchase.status == PurchaseStatus.error) {
          print('❌ Purchase error: ${purchase.error?.message}');
          _setState(
            isProcessing: false,
            lastError: purchase.error?.message ?? 'Purchase error',
          );
          continue;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          print(
              '✅ Purchase ${purchase.status == PurchaseStatus.purchased ? "completed" : "restored"}');

          final catalog = _findCatalogProduct(purchase.productID);
          print(
              '🔍 Catalog lookup for ${purchase.productID}: ${catalog != null ? "FOUND" : "NOT FOUND"}');

          if (catalog == null) {
            print('❌ Unknown product purchased');
            _setState(
              isProcessing: false,
              lastError: 'Unknown product purchased',
            );
            continue;
          }

          // Check if this purchase matches what the user initiated
          final currentState = state.valueOrNull;
          final initiatedProductId = currentState?.initiatedProductId;
          final isUserInitiated = initiatedProductId == purchase.productID;
          // Only treat as a NEW purchase if status is 'purchased', not 'restored'
          // Restored purchases are either:
          // 1. Pending purchases from previous sessions
          // 2. User trying to buy something they already own (iOS auto-restores)
          // In both cases, we should NOT trigger navigation to dashboard
          final isNewPurchase = purchase.status == PurchaseStatus.purchased;
          final shouldTriggerNavigation = isUserInitiated && isNewPurchase;
          print('🔍 Purchase match check: initiatedProductId=$initiatedProductId, purchaseProductId=${purchase.productID}, isUserInitiated=$isUserInitiated');
          print('🔍 Purchase type check: status=${purchase.status}, isNewPurchase=$isNewPurchase, shouldTriggerNavigation=$shouldTriggerNavigation');

          final platform = _platformString();
          print('🔧 Platform for verification: $platform');

          if (platform == null) {
            print('❌ Platform string is null');
            _setState(isProcessing: false);
            continue;
          }

          print('🌐 Calling verify-iap-purchase Edge Function...');
          final verificationData = purchase.verificationData;
          final serverData = verificationData.serverVerificationData;
          final localData = verificationData.localVerificationData;
          final serverPrefix = serverData.length > 8
              ? serverData.substring(0, 8)
              : serverData;
          final localPrefix = localData.length > 8
              ? localData.substring(0, 8)
              : localData;
          print('🧾 Receipt data source: ${verificationData.source}');
          print(
              '🧾 Receipt data lengths: server=${serverData.length}, local=${localData.length}');
          print(
              '🧾 Receipt data prefix: server=$serverPrefix, local=$localPrefix');
          final startedAt = DateTime.now();
          try {
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

            final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
            print('⏱️ Edge Function duration: ${elapsed}ms');
            print('📡 Edge Function response status: ${response.status}');

            if (response.status >= 400) {
              print('❌ Verification failed with status ${response.status}');
              print('📡 Response data: ${response.data}');

              // Extract error message from response body
              String errorMessage = 'Verification failed';
              final data = response.data;
              if (data is Map && data['error'] is String) {
                final backendError = (data['error'] as String).trim();
                if (backendError.isNotEmpty) {
                  errorMessage = backendError;
                }
              }
              print('🔍 Extracted error message: $errorMessage');

              _setState(
                isProcessing: false,
                lastError: errorMessage,
              );

              continue;
            }

            // Refresh subscription state - cross-invalidation ensures both providers stay in sync
            await ref.read(subscriptionManagementProvider.notifier).refresh();
            // Note: subscriptionNotifierProvider is cross-invalidated automatically

            // Clear processing state and set lastCompletedProductId only if:
            // 1. This was user-initiated (product ID matches what user clicked to buy)
            // 2. This is a NEW purchase (status == purchased), not a restored purchase
            // 
            // Restored purchases should NOT trigger navigation because they are either:
            // - Pending purchases from previous sessions being processed
            // - User trying to buy something they already own (iOS auto-restores)
            if (shouldTriggerNavigation) {
              print('✅ NEW user-initiated purchase completed successfully: ${purchase.productID}');
              _setState(
                isProcessing: false,
                lastError: null,
                lastCompletedProductId: purchase.productID,
                clearInitiatedProductId: true,
              );
            } else if (isUserInitiated && !isNewPurchase) {
              print('⚠️ User-initiated but RESTORED purchase (already owned): ${purchase.productID}');
              // User tried to buy something they already own - iOS restored it instead
              // Clear processing state but DON'T set lastCompletedProductId (no navigation)
              _setState(
                isProcessing: false,
                lastError: 'You already own this subscription. It has been restored.',
                clearInitiatedProductId: true,
              );
            } else {
              print('ℹ️ Background purchase processed (not user-initiated): ${purchase.productID}');
              // For non-user-initiated purchases, just clear processing without triggering navigation
              _setState(isProcessing: false, lastError: null);
            }
          } catch (error, stackTrace) {
            final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
            print('❌ Edge Function invoke threw after ${elapsed}ms: $error');
            print('🧵 Edge Function stackTrace: $stackTrace');

            // Extract actual error message from FunctionException
            String errorMessage = 'Verification failed';
            if (error is FunctionException) {
              final details = error.details;
              if (details is Map && details['error'] is String) {
                final backendError = (details['error'] as String).trim();
                if (backendError.isNotEmpty) {
                  errorMessage = backendError;
                }
              }
              print('🔍 FunctionException details: $details');
              print('🔍 Extracted error message: $errorMessage');
            }

            print('🚨 Setting error state: isProcessing=false, lastError=$errorMessage');
            _setState(
              isProcessing: false,
              lastError: errorMessage,
            );
            print('✅ Error state set successfully');
          }
        }
      } catch (e, stackTrace) {
        print('❌ Purchase verification threw: $e');
        print('🧵 Purchase verification stackTrace: $stackTrace');
        _setState(
          isProcessing: false,
          lastError: e.toString(),
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
