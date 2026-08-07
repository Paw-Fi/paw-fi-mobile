import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';

import '../../data/models/subscription_product.dart';
import 'subscription_products_provider.dart';
import 'subscription_management_provider.dart';
import '../app_store_commitment_billing.dart';

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
  final Map<String, AppStoreCommitmentTerms> commitmentTermsByProductId;
  final String? lastError;
  final String? lastErrorCode;
  final bool isProcessing;

  /// The product ID that the user initiated a purchase for in this session.
  /// Used to distinguish between user-initiated purchases and pending purchases
  /// from previous sessions that get processed when the listener is set up.
  final String? initiatedProductId;

  /// The product ID of the last successfully completed purchase.
  /// Set when a purchase matching initiatedProductId completes successfully.
  final String? lastCompletedProductId;

  /// The product ID of the last user-cancelled purchase attempt. Cancellation
  /// is a normal terminal outcome, not an error that should poison retries.
  final String? lastCanceledProductId;

  const IapState({
    required this.storeAvailable,
    required this.productDetailsById,
    this.commitmentTermsByProductId = const {},
    required this.lastError,
    this.lastErrorCode,
    this.isProcessing = false,
    this.initiatedProductId,
    this.lastCompletedProductId,
    this.lastCanceledProductId,
  });

  IapState copyWith({
    bool? storeAvailable,
    Map<String, ProductDetails>? productDetailsById,
    Map<String, AppStoreCommitmentTerms>? commitmentTermsByProductId,
    String? lastError,
    String? lastErrorCode,
    bool? isProcessing,
    String? initiatedProductId,
    String? lastCompletedProductId,
    String? lastCanceledProductId,
    bool clearInitiatedProductId = false,
    bool clearLastCompletedProductId = false,
    bool clearLastCanceledProductId = false,
  }) {
    return IapState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      productDetailsById: productDetailsById ?? this.productDetailsById,
      commitmentTermsByProductId:
          commitmentTermsByProductId ?? this.commitmentTermsByProductId,
      lastError: lastError,
      lastErrorCode: lastErrorCode,
      isProcessing: isProcessing ?? this.isProcessing,
      initiatedProductId: clearInitiatedProductId
          ? null
          : (initiatedProductId ?? this.initiatedProductId),
      lastCompletedProductId: clearLastCompletedProductId
          ? null
          : (lastCompletedProductId ?? this.lastCompletedProductId),
      lastCanceledProductId: clearLastCanceledProductId
          ? null
          : (lastCanceledProductId ?? this.lastCanceledProductId),
    );
  }
}

class IapController extends AsyncNotifier<IapState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _processingTimeout;
  Completer<void>? _restoreAttemptCompleter;

  static const _processingTimeoutDuration = Duration(minutes: 2);

  IapState _fallbackState() => const IapState(
        storeAvailable: false,
        productDetailsById: {},
        lastError: null,
        lastErrorCode: null,
      );

  void _completeRestoreAttempt() {
    final completer = _restoreAttemptCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete();
    _restoreAttemptCompleter = null;
  }

  void _setState({
    bool? storeAvailable,
    Map<String, ProductDetails>? productDetailsById,
    String? lastError,
    String? lastErrorCode,
    bool? isProcessing,
    String? initiatedProductId,
    String? lastCompletedProductId,
    String? lastCanceledProductId,
    bool clearInitiatedProductId = false,
    bool clearLastCompletedProductId = false,
    bool clearLastCanceledProductId = false,
  }) {
    final current = state.valueOrNull ?? _fallbackState();
    final next = current.copyWith(
      storeAvailable: storeAvailable,
      productDetailsById: productDetailsById,
      lastError: lastError,
      lastErrorCode: lastErrorCode,
      isProcessing: isProcessing,
      initiatedProductId: initiatedProductId,
      lastCompletedProductId: lastCompletedProductId,
      lastCanceledProductId: lastCanceledProductId,
      clearInitiatedProductId: clearInitiatedProductId,
      clearLastCompletedProductId: clearLastCompletedProductId,
      clearLastCanceledProductId: clearLastCanceledProductId,
    );

    print('📊 _setState called: isProcessing=${next.isProcessing}, '
        'lastError=${next.lastError}, lastErrorCode=${next.lastErrorCode}, '
        'initiatedProductId=${next.initiatedProductId}, '
        'lastCompletedProductId=${next.lastCompletedProductId}, '
        'lastCanceledProductId=${next.lastCanceledProductId}');

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
            lastErrorCode: null,
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

  ({String message, String? code}) _extractFunctionError(Object? value) {
    if (value is Map) {
      final rawMessage = value['error'];
      final rawCode = value['code'];
      final message = rawMessage is String && rawMessage.trim().isNotEmpty
          ? rawMessage.trim()
          : 'Verification failed';
      final code = rawCode is String && rawCode.trim().isNotEmpty
          ? rawCode.trim()
          : null;
      return (message: message, code: code);
    }

    return (message: 'Verification failed', code: null);
  }

  @override
  Future<IapState> build() async {
    print('🏗️ IapController.build() called');
    print('🌐 Platform: ${defaultTargetPlatform.toString()}, isWeb: $kIsWeb');

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      print('⚠️ IAP not supported on this platform');
      return const IapState(
        storeAvailable: false,
        productDetailsById: {},
        lastError: null,
        lastErrorCode: null,
      );
    }

    final products = ref.watch(subscriptionProductsProvider).value ??
        const <SubscriptionProduct>[];
    print('📦 Loaded ${products.length} products from catalog');
    print('🏷️ Product IDs: ${products.map((p) => p.storeProductId).toList()}');

    if (products.isEmpty) {
      print('⚠️ No products loaded from catalog');
      _ensurePurchaseListener();
      return const IapState(
        storeAvailable: false,
        productDetailsById: {},
        lastError: null,
        lastErrorCode: null,
      );
    }

    _ensurePurchaseListener();

    print('🔍 Checking if IAP store is available...');
    final isAvailable = await InAppPurchase.instance.isAvailable();
    print('🏪 Store available: $isAvailable');

    if (!isAvailable) {
      print('❌ Store not available');
      return const IapState(
        storeAvailable: false,
        productDetailsById: {},
        lastError: null,
        lastErrorCode: null,
      );
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
        lastErrorCode: null,
      );
    }

    print('✅ Found ${response.productDetails.length} product details');
    print(
        '📋 Product details IDs: ${response.productDetails.map((p) => p.id).toList()}');

    final map = <String, ProductDetails>{
      for (final d in response.productDetails) d.id: d,
    };

    final commitmentTerms = <String, AppStoreCommitmentTerms>{};
    for (final product in products.where(
      (product) => product.billingInterval == 'yearly',
    )) {
      try {
        final terms =
            await AppStoreCommitmentBilling.getTerms(product.storeProductId);
        if (terms != null) {
          commitmentTerms[product.storeProductId] = terms;
        }
      } on PlatformException catch (error) {
        print('App Store commitment terms unavailable: ${error.code}');
      }
    }

    return IapState(
      storeAvailable: true,
      productDetailsById: map,
      commitmentTermsByProductId: commitmentTerms,
      lastError: null,
    );
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
        final current = state.valueOrNull ?? _fallbackState();
        if (!current.isProcessing && _restoreAttemptCompleter == null) {
          print('Ignoring purchase stream error without an active attempt');
          return;
        }
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

  Future<void> buy(
    SubscriptionProduct product, {
    bool useMonthlyCommitment = false,
  }) async {
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

      final managedSubscription =
          ref.read(subscriptionManagementProvider).valueOrNull?.subscription;
      final hasActiveStripeSubscription =
          managedSubscription?.isActiveStripeManagedSubscription ?? false;
      print(
        '🧾 Stripe ownership guard | '
        'provider=${managedSubscription?.provider} '
        'plan=${managedSubscription?.plan} '
        'status=${managedSubscription?.status} '
        'stripeSubscriptionId=${managedSubscription?.stripeSubscriptionId} '
        'stripeCustomerId=${managedSubscription?.stripeCustomerId} '
        'systemGrantedTrial=${managedSubscription?.isSystemGrantedTrial} '
        'blocksAppStorePurchase=$hasActiveStripeSubscription',
      );
      if (hasActiveStripeSubscription) {
        throw Exception(
          'Your subscription is managed through Stripe. Cancel it before purchasing through the App Store.',
        );
      }

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
        lastErrorCode: null,
        initiatedProductId: product.storeProductId,
        clearLastCompletedProductId: true,
        clearLastCanceledProductId: true,
      );
      print(
          '✅ Processing state set to true, initiatedProductId=${product.storeProductId}');

      if (useMonthlyCommitment) {
        final commitmentPurchase = await AppStoreCommitmentBilling.purchase(
          productId: product.storeProductId,
          appAccountToken: user.uid,
        );
        if (commitmentPurchase.status == 'cancelled') {
          _setState(
            isProcessing: false,
            lastError: null,
            lastErrorCode: null,
            lastCanceledProductId: product.storeProductId,
            clearInitiatedProductId: true,
          );
          return;
        }
        if (commitmentPurchase.status == 'pending') {
          _setState(isProcessing: false, lastError: null);
          return;
        }
        final signedTransaction = commitmentPurchase.signedTransaction;
        final transactionId = commitmentPurchase.transactionId;
        if (commitmentPurchase.status != 'success' ||
            signedTransaction == null ||
            signedTransaction.isEmpty ||
            transactionId == null ||
            transactionId.isEmpty) {
          throw Exception('Failed to verify App Store commitment purchase');
        }

        final response = await supabase.functions.invoke(
          'verify-iap-purchase',
          body: {
            'platform': 'ios',
            'storeProductId': product.storeProductId,
            'appAccountToken': user.uid,
            'expectedBillingPlanType': 'MONTHLY',
            'expectedCommitmentMonths': 12,
            'verificationData': {
              'source': 'app_store',
              'localVerificationData': signedTransaction,
              'serverVerificationData': signedTransaction,
            },
            'purchaseId': transactionId,
          },
        );
        if (response.status >= 400) {
          final error = _extractFunctionError(response.data);
          throw Exception(error.message);
        }

        await ref.read(subscriptionManagementProvider.notifier).refresh();
        final refreshedSubscription =
            ref.read(subscriptionManagementProvider).valueOrNull?.subscription;
        if (refreshedSubscription?.confirmsAppStorePurchase(
              product.storeProductId,
            ) !=
            true) {
          throw Exception(
            'Purchase was received but subscription access was not activated. Please try Restore Purchases.',
          );
        }

        await AppStoreCommitmentBilling.finish(transactionId);
        _setState(
          isProcessing: false,
          lastError: null,
          lastCompletedProductId: product.storeProductId,
          clearInitiatedProductId: true,
        );
        return;
      }

      PurchaseParam purchaseParam;

      print('🧭 buy() step 7: build purchase param');
      if (platform == 'android' && details is GooglePlayProductDetails) {
        print('🤖 Android purchase flow');
        // For Google subscriptions, an offer token is required.
        // GooglePlayProductDetails exposes a convenience getter for the selected offer.
        final offerToken = details.offerToken;

        if (!product.isLifetime && (offerToken == null || offerToken.isEmpty)) {
          print('❌ No offer token available for Android subscription');
          _setState(
            isProcessing: false,
            lastError: 'No subscription offer',
            lastErrorCode: null,
          );
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

      // `buyNonConsumable` only confirms that StoreKit accepted the purchase
      // request. It does not mean the user has approved the StoreKit sheet.
      // The purchase stream is the only completion authority: it can arrive
      // after biometric/password confirmation, Ask to Buy approval, or an
      // app resume. Keep the attempt pending until that stream reports a
      // terminal state (or the bounded processing timeout fires).
      print(
          '✅ Purchase request started; waiting for purchase stream confirmation...');
    } catch (error, stackTrace) {
      print('❌ buy() threw: $error');
      print('🧵 buy() stackTrace: $stackTrace');

      // If we error before receiving any purchaseStream updates, ensure the UI
      // is not stuck in a processing state.
      _setState(
        isProcessing: false,
        lastError: error.toString(),
        lastErrorCode: null,
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

    _setState(
      isProcessing: true,
      lastError: null,
      lastErrorCode: null,
      clearLastCompletedProductId: true,
      clearLastCanceledProductId: true,
    );

    final completer = Completer<void>();
    _restoreAttemptCompleter = completer;

    await InAppPurchase.instance
        .restorePurchases(applicationUserName: user.uid);

    await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        final current = state.valueOrNull ?? _fallbackState();
        if (current.isProcessing) {
          _setState(
            isProcessing: false,
            lastError: current.lastError,
            lastErrorCode: current.lastErrorCode,
          );
        }
        _completeRestoreAttempt();
      },
    );
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    print('🔔 _onPurchaseUpdated called with ${purchases.length} purchase(s)');
    print(
        '🧭 _onPurchaseUpdated at ${DateTime.now().toIso8601String()} processing=${state.valueOrNull?.isProcessing}');

    var sawTerminalPurchaseUpdate = false;

    for (final purchase in purchases) {
      var entitlementConfirmed = false;
      print(
          '📦 Processing purchase: id=${purchase.purchaseID}, productId=${purchase.productID}, status=${purchase.status}');

      try {
        if (purchase.status == PurchaseStatus.pending) {
          print('⏳ Purchase pending, skipping...');
          continue;
        }

        final currentState = state.valueOrNull;
        final isCurrentPurchaseAttempt =
            currentState?.initiatedProductId == purchase.productID;
        final isRestoreAttempt = _restoreAttemptCompleter != null;

        if (purchase.status == PurchaseStatus.canceled) {
          if (!isCurrentPurchaseAttempt) {
            print(
              'Ignoring cancellation for ${purchase.productID}; no matching '
              'user-initiated purchase is active',
            );
            continue;
          }
          sawTerminalPurchaseUpdate = true;
          print('🚫 Purchase cancelled by store');
          _setState(
            isProcessing: false,
            lastError: null,
            lastErrorCode: null,
            lastCanceledProductId: purchase.productID,
            clearInitiatedProductId: true,
          );
          continue;
        }

        if (purchase.status == PurchaseStatus.error) {
          if (!isCurrentPurchaseAttempt && !isRestoreAttempt) {
            print(
              'Ignoring purchase error for ${purchase.productID}; no matching '
              'purchase or restore attempt is active',
            );
            continue;
          }
          sawTerminalPurchaseUpdate = true;
          print('❌ Purchase error: ${purchase.error?.message}');
          _setState(
            isProcessing: false,
            lastError: purchase.error?.message ?? 'Purchase error',
            lastErrorCode: null,
            clearInitiatedProductId: true,
          );
          continue;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          sawTerminalPurchaseUpdate = true;
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
              lastErrorCode: null,
              clearInitiatedProductId: true,
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
          print(
              '🔍 Purchase match check: initiatedProductId=$initiatedProductId, purchaseProductId=${purchase.productID}, isUserInitiated=$isUserInitiated');
          print(
              '🔍 Purchase type check: status=${purchase.status}, isNewPurchase=$isNewPurchase, shouldTriggerNavigation=$shouldTriggerNavigation');

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
          final serverPrefix =
              serverData.length > 8 ? serverData.substring(0, 8) : serverData;
          final localPrefix =
              localData.length > 8 ? localData.substring(0, 8) : localData;
          print('🧾 Receipt data source: ${verificationData.source}');
          print(
              '🧾 Receipt data lengths: server=${serverData.length}, local=${localData.length}');
          print(
              '🧾 Receipt data prefix: server=$serverPrefix, local=$localPrefix');
          final startedAt = DateTime.now();
          final authUser = ref.read(authProvider);
          try {
            final response = await supabase.functions.invoke(
              'verify-iap-purchase',
              body: {
                'platform': platform,
                'storeProductId': catalog.storeProductId,
                'appAccountToken': authUser.uid,
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
            print('📡 Edge Function response data: ${response.data}');

            if (response.status >= 400) {
              print('❌ Verification failed with status ${response.status}');
              print('📡 Response data: ${response.data}');

              final extractedError = _extractFunctionError(response.data);
              print('🔍 Extracted error message: ${extractedError.message}');
              print(
                  '🔍 Extracted error code: ${extractedError.code ?? "none"}');

              _setState(
                isProcessing: false,
                lastError: extractedError.message,
                lastErrorCode: extractedError.code,
                clearInitiatedProductId: true,
              );

              continue;
            }

            // Refresh subscription state - cross-invalidation ensures both providers stay in sync
            await ref.read(subscriptionManagementProvider.notifier).refresh();
            // Note: subscriptionNotifierProvider is cross-invalidated automatically
            final refreshedSubscription = ref
                .read(subscriptionManagementProvider)
                .valueOrNull
                ?.subscription;
            print(
              '🧾 Post-verify subscription snapshot: '
              'plan=${refreshedSubscription?.plan} '
              'status=${refreshedSubscription?.status} '
              'provider=${refreshedSubscription?.provider} '
              'billingInterval=${refreshedSubscription?.billingInterval} '
              'currentPeriodEnd=${refreshedSubscription?.currentPeriodEnd} '
              'isSubscribed=${refreshedSubscription?.isSubscribed}',
            );
            if (refreshedSubscription?.confirmsAppStorePurchase(
                  catalog.storeProductId,
                ) !=
                true) {
              print(
                '❌ Backend returned without activating the matching App Store entitlement',
              );
              _setState(
                isProcessing: false,
                lastError:
                    'Purchase was received but subscription access was not activated. Please try Restore Purchases.',
                lastErrorCode: null,
                clearInitiatedProductId: true,
              );
              continue;
            }
            entitlementConfirmed = true;

            // Clear processing state and set lastCompletedProductId only if:
            // 1. This was user-initiated (product ID matches what user clicked to buy)
            // 2. This is a NEW purchase (status == purchased), not a restored purchase
            //
            // Restored purchases should NOT trigger navigation because they are either:
            // - Pending purchases from previous sessions being processed
            // - User trying to buy something they already own (iOS auto-restores)
            if (shouldTriggerNavigation) {
              print(
                  '✅ NEW user-initiated purchase completed successfully: ${purchase.productID}');
              _setState(
                isProcessing: false,
                lastError: null,
                lastErrorCode: null,
                lastCompletedProductId: purchase.productID,
                clearInitiatedProductId: true,
              );
            } else if (isUserInitiated && !isNewPurchase) {
              print(
                  '⚠️ User-initiated but RESTORED purchase (already owned): ${purchase.productID}');
              // User tried to buy something they already own - iOS restored it instead
              // Clear processing state but DON'T set lastCompletedProductId (no navigation)
              _setState(
                isProcessing: false,
                lastError:
                    'You already own this subscription. It has been restored.',
                lastErrorCode: null,
                clearInitiatedProductId: true,
              );
            } else {
              print(
                  'ℹ️ Background purchase processed (not user-initiated): ${purchase.productID}');
              // For non-user-initiated purchases, just clear processing without triggering navigation
              _setState(
                isProcessing: false,
                lastError: null,
                lastErrorCode: null,
                clearInitiatedProductId: true,
              );
            }
          } catch (error, stackTrace) {
            final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
            print('❌ Edge Function invoke threw after ${elapsed}ms: $error');
            print('🧵 Edge Function stackTrace: $stackTrace');

            // Extract actual error message from FunctionException
            String errorMessage = 'Verification failed';
            String? errorCode;
            if (error is FunctionException) {
              final details = error.details;
              final extractedError = _extractFunctionError(details);
              errorMessage = extractedError.message;
              errorCode = extractedError.code;
              print('🔍 FunctionException details: $details');
              print('🔍 Extracted error message: $errorMessage');
              print('🔍 Extracted error code: ${errorCode ?? "none"}');
            }

            print(
                '🚨 Setting error state: isProcessing=false, lastError=$errorMessage, lastErrorCode=${errorCode ?? "none"}');
            _setState(
              isProcessing: false,
              lastError: errorMessage,
              lastErrorCode: errorCode,
              clearInitiatedProductId: true,
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
          lastErrorCode: null,
          clearInitiatedProductId: true,
        );
      } finally {
        if (purchase.pendingCompletePurchase && entitlementConfirmed) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {
            // Ignore completion errors; store will retry.
          }
        } else if (purchase.pendingCompletePurchase) {
          print(
            '⏸️ Leaving StoreKit transaction pending until the matching '
            'App Store entitlement is confirmed',
          );
        }
      }
    }

    if (sawTerminalPurchaseUpdate) {
      _completeRestoreAttempt();
    }
  }
}

final iapControllerProvider = AsyncNotifierProvider<IapController, IapState>(
  () => IapController(),
);
