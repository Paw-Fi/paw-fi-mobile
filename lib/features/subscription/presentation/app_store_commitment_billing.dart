import 'package:flutter/services.dart';

class AppStoreCommitmentTerms {
  const AppStoreCommitmentTerms({
    required this.monthlyPrice,
    required this.totalCommitmentPrice,
  });

  final String monthlyPrice;
  final String totalCommitmentPrice;

  factory AppStoreCommitmentTerms.fromMap(Map<Object?, Object?> map) {
    return AppStoreCommitmentTerms(
      monthlyPrice: map['monthlyPrice']?.toString() ?? '',
      totalCommitmentPrice: map['totalCommitmentPrice']?.toString() ?? '',
    );
  }
}

class AppStoreCommitmentBilling {
  static const _channel = MethodChannel('moneko/app_store_commitment');

  static Future<AppStoreCommitmentTerms?> getTerms(String productId) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getTerms',
      {'productId': productId},
    );
    if (result == null) return null;
    final terms = AppStoreCommitmentTerms.fromMap(result);
    if (terms.monthlyPrice.isEmpty || terms.totalCommitmentPrice.isEmpty) {
      return null;
    }
    return terms;
  }

  static Future<AppStoreCommitmentPurchase> purchase({
    required String productId,
    required String appAccountToken,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'purchase',
      {
        'productId': productId,
        'appAccountToken': appAccountToken,
      },
    );
    return AppStoreCommitmentPurchase.fromMap(result ?? const {});
  }

  static Future<void> finish(String transactionId) {
    return _channel.invokeMethod<void>(
      'finish',
      {'transactionId': transactionId},
    );
  }
}

class AppStoreCommitmentPurchase {
  const AppStoreCommitmentPurchase({
    required this.status,
    this.transactionId,
    this.signedTransaction,
  });

  final String status;
  final String? transactionId;
  final String? signedTransaction;

  factory AppStoreCommitmentPurchase.fromMap(Map<Object?, Object?> map) {
    return AppStoreCommitmentPurchase(
      status: map['status']?.toString() ?? 'failed',
      transactionId: map['transactionId']?.toString(),
      signedTransaction: map['signedTransaction']?.toString(),
    );
  }
}
