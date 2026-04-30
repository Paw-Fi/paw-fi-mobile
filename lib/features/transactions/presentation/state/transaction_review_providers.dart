import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/sync/application/sync_queue_controller.dart';
import 'package:moneko/features/transactions/data/transaction_providers.dart';

class TransactionReviewRequest {
  const TransactionReviewRequest({
    required this.userId,
    this.householdId,
    this.limit = 50,
  });

  final String userId;
  final String? householdId;
  final int limit;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TransactionReviewRequest &&
            userId == other.userId &&
            householdId == other.householdId &&
            limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(userId, householdId, limit);
}

final needsReviewTransactionsProvider = FutureProvider.autoDispose
    .family<List<LocalTransactionRecord>, TransactionReviewRequest>(
  (ref, request) {
    return ref.watch(transactionRepositoryProvider).needsReviewTransactions(
          userId: request.userId,
          householdId: request.householdId,
          limit: request.limit,
        );
  },
);

final transactionReviewControllerProvider =
    AsyncNotifierProvider<TransactionReviewController, void>(
  TransactionReviewController.new,
);

class TransactionReviewController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> markReviewed(String transactionId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(transactionRepositoryProvider)
          .markTransactionReviewed(transactionId);
      ref.invalidate(needsReviewTransactionsProvider);
      unawaited(
        ref
            .read(syncQueueControllerProvider.notifier)
            .syncNow(SyncTrigger.manual),
      );
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> updateCategory({
    required String transactionId,
    required String category,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(transactionRepositoryProvider).updateReviewCategory(
            transactionId: transactionId,
            category: category,
          );
      ref.invalidate(needsReviewTransactionsProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
