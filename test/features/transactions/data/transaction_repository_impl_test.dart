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
  var defaultDatabaseClosed = false;

  setUp(() {
    defaultDatabaseClosed = false;
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
    if (!defaultDatabaseClosed) {
      await database.close();
    }
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

  test('migrates an older local database before inserting transaction',
      () async {
    await database.close();
    defaultDatabaseClosed = true;

    final legacyDatabase = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
            CREATE TABLE local_transactions (
              id TEXT NOT NULL PRIMARY KEY,
              server_id TEXT UNIQUE,
              client_mutation_id TEXT NOT NULL UNIQUE,
              user_id TEXT NOT NULL,
              household_id TEXT,
              wallet_id TEXT,
              type TEXT NOT NULL,
              amount_cents INTEGER NOT NULL,
              currency TEXT NOT NULL,
              category TEXT,
              merchant TEXT,
              raw_text TEXT,
              description TEXT,
              breakdown_json TEXT NOT NULL,
              date_ymd TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              capture_source TEXT NOT NULL,
              confidence_score REAL,
              sync_status TEXT NOT NULL,
              review_reasons_json TEXT NOT NULL,
              receipt_local_path TEXT,
              receipt_image_url TEXT,
              is_recurring INTEGER NOT NULL DEFAULT 0,
              recurrence_rule_json TEXT,
              payer_user_id TEXT,
              is_portfolio INTEGER NOT NULL DEFAULT 0,
              last_sync_error TEXT
            )
          ''');
          rawDb.execute('''
            CREATE TABLE sync_ops (
              id TEXT NOT NULL PRIMARY KEY,
              aggregate_type TEXT NOT NULL,
              aggregate_local_id TEXT NOT NULL,
              aggregate_server_id TEXT,
              operation_type TEXT NOT NULL,
              status TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              next_retry_at TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          rawDb.userVersion = 1;
        },
      ),
    );
    addTearDown(legacyDatabase.close);
    final legacyRepository = TransactionRepositoryImpl(
      database: legacyDatabase,
      clock: () => DateTime.utc(2026, 4, 30, 12),
      idFactory: () => 'legacy-local-tx-1',
      mutationIdFactory: () => 'legacy-mutation-1',
      syncOpIdFactory: () => 'legacy-sync-op-1',
    );

    final transactionId = await legacyRepository.createLocalTransaction(
      CreateTransactionCommand(
        userId: 'user-1',
        householdId: null,
        walletId: 'wallet-1',
        type: TransactionCommandType.expense,
        amountCents: 1299,
        currency: 'EUR',
        category: 'dining',
        description: 'Lunch',
        date: DateTime.utc(2026, 4, 30),
        captureSource: TransactionCaptureSource.manual,
      ),
    );

    final transaction =
        await legacyDatabase.localTransactionById(transactionId);
    expect(transaction.id, 'legacy-local-tx-1');
    expect(transaction.bankAccountId, isNull);

    final syncOp = await legacyDatabase.syncOpForAggregate(transactionId);
    expect(syncOp.startedAt, isNull);
    expect(syncOp.completedAt, isNull);
  });

  test('releases existing needs review rows back to the sync queue', () async {
    await database.close();
    defaultDatabaseClosed = true;

    final legacyDatabase = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
            CREATE TABLE local_transactions (
              id TEXT NOT NULL PRIMARY KEY,
              server_id TEXT UNIQUE,
              client_mutation_id TEXT NOT NULL UNIQUE,
              user_id TEXT NOT NULL,
              household_id TEXT,
              wallet_id TEXT,
              type TEXT NOT NULL,
              amount_cents INTEGER NOT NULL,
              currency TEXT NOT NULL,
              category TEXT,
              merchant TEXT,
              raw_text TEXT,
              description TEXT,
              breakdown_json TEXT NOT NULL,
              date_ymd TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              capture_source TEXT NOT NULL,
              confidence_score REAL,
              sync_status TEXT NOT NULL,
              review_reasons_json TEXT NOT NULL,
              receipt_local_path TEXT,
              receipt_image_url TEXT,
              is_recurring INTEGER NOT NULL DEFAULT 0,
              recurrence_rule_json TEXT,
              payer_user_id TEXT,
              is_portfolio INTEGER NOT NULL DEFAULT 0,
              last_sync_error TEXT
            )
          ''');
          rawDb.execute('''
            CREATE TABLE sync_ops (
              id TEXT NOT NULL PRIMARY KEY,
              aggregate_type TEXT NOT NULL,
              aggregate_local_id TEXT NOT NULL,
              aggregate_server_id TEXT,
              operation_type TEXT NOT NULL,
              status TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              idempotency_key TEXT NOT NULL UNIQUE,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              next_retry_at TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          rawDb.execute('''
            INSERT INTO local_transactions (
              id,
              client_mutation_id,
              user_id,
              type,
              amount_cents,
              currency,
              category,
              breakdown_json,
              date_ymd,
              created_at,
              updated_at,
              capture_source,
              sync_status,
              review_reasons_json
            ) VALUES (
              'review-tx-1',
              'review-mutation-1',
              'user-1',
              'expense',
              1000,
              'EUR',
              'breakfast',
              '[]',
              '2026-04-30',
              '2026-04-30T12:00:00.000Z',
              '2026-04-30T12:00:00.000Z',
              'aiText',
              'needsReview',
              '["missingWallet"]'
            )
          ''');
          rawDb.execute('''
            INSERT INTO sync_ops (
              id,
              aggregate_type,
              aggregate_local_id,
              operation_type,
              status,
              payload_json,
              idempotency_key,
              created_at,
              updated_at
            ) VALUES (
              'review-sync-op-1',
              'transaction',
              'review-tx-1',
              'create',
              'needsReview',
              '{"type":"expense","amountCents":1000,"currency":"EUR","category":"breakfast","dateYmd":"2026-04-30","userId":"user-1","createdAt":"2026-04-30T12:00:00.000Z","clientMutationId":"review-mutation-1"}',
              'review-mutation-1',
              '2026-04-30T12:00:00.000Z',
              '2026-04-30T12:00:00.000Z'
            )
          ''');
          rawDb.userVersion = 1;
        },
      ),
    );
    addTearDown(legacyDatabase.close);

    final transaction = await legacyDatabase.localTransactionById(
      'review-tx-1',
    );
    expect(transaction.syncStatus, SyncStatus.localOnly.name);
    expect(transaction.reviewReasonsJson, '[]');

    final pending = await legacyDatabase.pendingSyncOps(
      nowIso: '2026-04-30T13:00:00.000Z',
    );
    expect(pending.map((op) => op.aggregateLocalId), contains('review-tx-1'));
    expect(pending.single.status, SyncStatus.localOnly.name);
  });
}
