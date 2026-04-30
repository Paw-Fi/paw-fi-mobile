import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/local_database/app_database_provider.dart';
import 'package:moneko/core/sync/domain/sync_operation_type.dart';
import 'package:moneko/core/sync/domain/sync_status.dart';
import 'package:moneko/features/transactions/data/transaction_repository_impl.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';
import 'package:moneko/features/transactions/presentation/state/transaction_capture_controller.dart';

void main() {
  late AppDatabase database;
  late TransactionRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TransactionRepositoryImpl(
      database: database,
      clock: () => DateTime.utc(2026, 4, 30, 12),
      idFactory: () => 'local-tx-1',
      mutationIdFactory: () => 'mutation-1',
      syncOpIdFactory: () => 'sync-op-1',
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'createLocalTransaction persists transaction and outbox operation atomically',
    () async {
      final transactionId = await repository.createLocalTransaction(
        CreateTransactionCommand(
          userId: 'user-1',
          householdId: null,
          walletId: 'wallet-1',
          type: TransactionCommandType.expense,
          amountCents: 1299,
          currency: 'EUR',
          category: 'dining',
          merchant: 'Cafe Nero',
          description: 'Lunch',
          date: DateTime.utc(2026, 4, 30),
          captureSource: TransactionCaptureSource.manual,
        ),
      );

      expect(transactionId, 'local-tx-1');

      final transaction = await database.localTransactionById(transactionId);

      expect(transaction.serverId, isNull);
      expect(transaction.clientMutationId, 'mutation-1');
      expect(transaction.userId, 'user-1');
      expect(transaction.walletId, 'wallet-1');
      expect(transaction.type, TransactionCommandType.expense.name);
      expect(transaction.amountCents, 1299);
      expect(transaction.currency, 'EUR');
      expect(transaction.category, 'dining');
      expect(transaction.merchant, 'Cafe Nero');
      expect(transaction.description, 'Lunch');
      expect(transaction.dateYmd, '2026-04-30');
      expect(transaction.captureSource, TransactionCaptureSource.manual.name);
      expect(transaction.syncStatus, SyncStatus.localOnly.name);
      expect(transaction.reviewReasonsJson, '[]');

      final syncOp = await database.syncOpForAggregate(transactionId);

      expect(syncOp.id, 'sync-op-1');
      expect(syncOp.aggregateType, 'transaction');
      expect(syncOp.operationType, SyncOperationType.create.name);
      expect(syncOp.status, SyncStatus.localOnly.name);
      expect(syncOp.idempotencyKey, 'mutation-1');
      expect(syncOp.attemptCount, 0);
      expect(syncOp.payloadJson, contains('"amountCents":1299'));
      expect(syncOp.payloadJson, contains('"captureSource":"manual"'));
    },
  );

  test('transactionCaptureController writes through the local repository',
      () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(container.dispose);

    final transactionId = await container
        .read(transactionCaptureControllerProvider.notifier)
        .createLocalTransaction(
          CreateTransactionCommand(
            userId: 'user-1',
            householdId: null,
            walletId: 'wallet-1',
            type: TransactionCommandType.expense,
            amountCents: 550,
            currency: 'eur',
            category: 'transport',
            merchant: 'Metro',
            description: 'Train',
            date: DateTime.utc(2026, 4, 30),
            captureSource: TransactionCaptureSource.manual,
          ),
        );

    expect(transactionId, isNotEmpty);
    expect(
      container.read(transactionCaptureControllerProvider),
      const AsyncData<void>(null),
    );

    final transaction = await database.localTransactionById(transactionId);
    expect(transaction.amountCents, 550);
    expect(transaction.currency, 'EUR');
    expect(transaction.syncStatus, SyncStatus.localOnly.name);
  });

  test('createLocalTransaction allows missing wallet for review later',
      () async {
    final transactionId = await repository.createLocalTransaction(
      CreateTransactionCommand(
        userId: 'user-1',
        householdId: null,
        walletId: null,
        type: TransactionCommandType.expense,
        amountCents: 1200,
        currency: 'EUR',
        category: 'dining',
        date: DateTime.utc(2026, 4, 30),
        captureSource: TransactionCaptureSource.aiText,
        reviewReasons: const ['missingWallet'],
      ),
    );

    final transaction = await database.localTransactionById(transactionId);

    expect(transaction.walletId, isNull);
    expect(transaction.syncStatus, SyncStatus.needsReview.name);

    final syncOp = await database.syncOpForAggregate(transactionId);
    expect(syncOp.status, SyncStatus.needsReview.name);
    expect(syncOp.payloadJson, contains('"walletId":null'));
  });

  test('createLocalTransaction preserves AI sync metadata', () async {
    final transactionId = await repository.createLocalTransaction(
      CreateTransactionCommand(
        userId: 'user-1',
        householdId: 'household-1',
        walletId: 'wallet-1',
        type: TransactionCommandType.expense,
        amountCents: 2500,
        currency: 'EUR',
        category: 'groceries',
        description: 'Weekly shop',
        date: DateTime.utc(2026, 4, 30),
        captureSource: TransactionCaptureSource.receiptPhoto,
        breakdown: const ['Milk', 'Bread'],
        receiptImageUrl: 'https://example.com/receipt.jpg',
        recurrenceRule: const {
          'frequency': 'monthly',
          'anchor_date': '2026-04-30',
        },
        customSplits: const {
          'splitType': 'percentage',
          'memberSplits': [
            {'userId': 'user-1', 'percentage': 60},
            {'userId': 'user-2', 'percentage': 40},
          ],
        },
      ),
    );

    final syncOp = await database.syncOpForAggregate(transactionId);

    expect(syncOp.payloadJson, contains('"breakdown":["Milk","Bread"]'));
    expect(
      syncOp.payloadJson,
      contains('"receiptImageUrl":"https://example.com/receipt.jpg"'),
    );
    expect(syncOp.payloadJson, contains('"recurrenceRule"'));
    expect(syncOp.payloadJson, contains('"customSplits"'));

    final transaction = await database.localTransactionById(transactionId);
    expect(transaction.receiptImageUrl, 'https://example.com/receipt.jpg');
  });

  test('markTransactionReviewed moves a review item back to pending sync',
      () async {
    final transactionId = await repository.createLocalTransaction(
      CreateTransactionCommand(
        userId: 'user-1',
        householdId: null,
        walletId: null,
        type: TransactionCommandType.expense,
        amountCents: 1200,
        currency: 'EUR',
        category: 'dining',
        date: DateTime.utc(2026, 4, 30),
        captureSource: TransactionCaptureSource.aiText,
        reviewReasons: const ['missingWallet'],
      ),
    );

    expect(
      await repository.needsReviewTransactions(userId: 'user-1'),
      hasLength(1),
    );
    expect(
      await database.pendingSyncOps(nowIso: '2026-04-30T13:00:00.000Z'),
      isEmpty,
    );

    await repository.markTransactionReviewed(transactionId);

    final transaction = await database.localTransactionById(transactionId);
    expect(transaction.syncStatus, SyncStatus.localOnly.name);
    expect(transaction.reviewReasonsJson, '[]');
    expect(
      await repository.needsReviewTransactions(userId: 'user-1'),
      isEmpty,
    );

    final pending =
        await database.pendingSyncOps(nowIso: '2026-04-30T13:00:00.000Z');
    expect(pending, hasLength(1));
    expect(pending.single.aggregateLocalId, transactionId);
    expect(pending.single.status, SyncStatus.localOnly.name);
  });

  test('updateReviewCategory patches local row and queued sync payload',
      () async {
    final transactionId = await repository.createLocalTransaction(
      CreateTransactionCommand(
        userId: 'user-1',
        householdId: null,
        walletId: 'wallet-1',
        type: TransactionCommandType.expense,
        amountCents: 1200,
        currency: 'EUR',
        category: '',
        date: DateTime.utc(2026, 4, 30),
        captureSource: TransactionCaptureSource.aiText,
        reviewReasons: const ['missingCategory', 'lowConfidence'],
      ),
    );

    await repository.updateReviewCategory(
      transactionId: transactionId,
      category: 'groceries',
    );

    final transaction = await database.localTransactionById(transactionId);
    expect(transaction.category, 'groceries');
    expect(transaction.syncStatus, SyncStatus.needsReview.name);
    expect(transaction.reviewReasonsJson, '["lowConfidence"]');

    final syncOp = await database.syncOpForAggregate(transactionId);
    expect(syncOp.status, SyncStatus.needsReview.name);
    expect(syncOp.payloadJson, contains('"category":"groceries"'));
    expect(syncOp.payloadJson, contains('"reviewReasons":["lowConfidence"]'));
  });
}
