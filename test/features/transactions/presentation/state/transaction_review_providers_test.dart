import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/sync/application/sync_queue_controller.dart';
import 'package:moneko/core/sync/data/sync_providers.dart';
import 'package:moneko/core/sync/data/sync_queue_service.dart';
import 'package:moneko/features/transactions/data/transaction_providers.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';
import 'package:moneko/features/transactions/domain/transaction_repository.dart';
import 'package:moneko/features/transactions/presentation/state/transaction_review_providers.dart';

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository(this.rows);

  final List<LocalTransactionRecord> rows;
  final reviewedIds = <String>[];
  final updatedCategories = <String, String>{};

  @override
  Future<String> createLocalTransaction(CreateTransactionCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<List<LocalTransactionRecord>> needsReviewTransactions({
    required String userId,
    String? householdId,
    int limit = 50,
  }) async {
    return rows.take(limit).toList(growable: false);
  }

  @override
  Future<void> markTransactionReviewed(String transactionId) async {
    reviewedIds.add(transactionId);
  }

  @override
  Future<void> updateReviewCategory({
    required String transactionId,
    required String category,
  }) async {
    updatedCategories[transactionId] = category;
  }
}

class _FakeSyncQueueProcessor implements SyncQueueProcessor {
  var callCount = 0;

  @override
  Future<SyncQueueProcessResult> processPendingOperations({
    int limit = 20,
  }) async {
    callCount += 1;
    return const SyncQueueProcessResult(
      processed: 1,
      succeeded: 1,
      failed: 0,
    );
  }
}

void main() {
  test('needsReviewTransactionsProvider reads review rows', () async {
    final repository = _FakeTransactionRepository([
      _reviewRecord('tx-1'),
    ]);
    final container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final rows = await container.read(
      needsReviewTransactionsProvider(
        const TransactionReviewRequest(userId: 'user-1'),
      ).future,
    );

    expect(rows.single.id, 'tx-1');
  });

  test('transactionReviewController marks reviewed and kicks sync', () async {
    final repository = _FakeTransactionRepository([_reviewRecord('tx-1')]);
    final syncProcessor = _FakeSyncQueueProcessor();
    final container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(repository),
        syncConnectivityProvider.overrideWith((ref) => const Stream.empty()),
        syncQueueProcessorProvider.overrideWithValue(syncProcessor),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transactionReviewControllerProvider.notifier)
        .markReviewed('tx-1');
    await container.pump();

    expect(repository.reviewedIds, ['tx-1']);
    expect(syncProcessor.callCount, 1);
  });

  test('transactionReviewController updates review category without syncing',
      () async {
    final repository = _FakeTransactionRepository([_reviewRecord('tx-1')]);
    final syncProcessor = _FakeSyncQueueProcessor();
    final container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(repository),
        syncConnectivityProvider.overrideWith((ref) => const Stream.empty()),
        syncQueueProcessorProvider.overrideWithValue(syncProcessor),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transactionReviewControllerProvider.notifier)
        .updateCategory(
          transactionId: 'tx-1',
          category: 'groceries',
        );
    await container.pump();

    expect(repository.updatedCategories, {'tx-1': 'groceries'});
    expect(syncProcessor.callCount, 0);
  });
}

LocalTransactionRecord _reviewRecord(String id) {
  return LocalTransactionRecord(
    id: id,
    serverId: null,
    clientMutationId: 'mutation-$id',
    userId: 'user-1',
    householdId: null,
    walletId: null,
    bankAccountId: null,
    contactId: null,
    splitGroupId: null,
    type: 'expense',
    amountCents: 1200,
    currency: 'EUR',
    category: 'dining',
    merchant: null,
    rawText: null,
    description: null,
    breakdownJson: '[]',
    dateYmd: '2026-04-30',
    createdAt: '2026-04-30T12:00:00.000Z',
    updatedAt: '2026-04-30T12:00:00.000Z',
    captureSource: 'aiText',
    syncStatus: 'needsReview',
    reviewReasonsJson: '["missingWallet"]',
    receiptImageUrl: null,
    isRecurring: false,
    lastSyncError: null,
  );
}
