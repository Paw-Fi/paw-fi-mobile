import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/sync/data/sync_queue_service.dart';
import 'package:moneko/core/sync/domain/sync_status.dart';
import 'package:moneko/features/transactions/data/transaction_repository_impl.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';

class _FakeSyncRemoteClient implements SyncRemoteClient {
  _FakeSyncRemoteClient({this.error, this.result = const SyncRemoteResult()});

  final Object? error;
  final SyncRemoteResult result;
  final pushedOperations = <SyncOpRecord>[];

  @override
  Future<SyncRemoteResult> pushOperation(SyncOpRecord operation) async {
    pushedOperations.add(operation);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return result;
  }
}

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

  Future<String> createQueuedTransaction() {
    return repository.createLocalTransaction(
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
  }

  test('processPendingOperations marks successful transaction sync as synced',
      () async {
    final transactionId = await createQueuedTransaction();
    final remote = _FakeSyncRemoteClient();
    final service = SyncQueueService(
      database: database,
      remoteClient: remote,
      clock: () => DateTime.utc(2026, 4, 30, 12, 1),
    );

    final result = await service.processPendingOperations();

    expect(result.processed, 1);
    expect(result.succeeded, 1);
    expect(result.failed, 0);
    expect(remote.pushedOperations.single.id, 'sync-op-1');

    final syncOp = await database.syncOpForAggregate(transactionId);
    expect(syncOp.status, SyncStatus.synced.name);
    expect(syncOp.completedAt, '2026-04-30T12:01:00.000Z');

    final transaction = await database.localTransactionById(transactionId);
    expect(transaction.syncStatus, SyncStatus.synced.name);
  });

  test('processPendingOperations reconciles synced transaction server id',
      () async {
    final transactionId = await createQueuedTransaction();
    final remote = _FakeSyncRemoteClient(
      result: const SyncRemoteResult(
        serverId: 'server-tx-1',
        serverUpdatedAt: '2026-04-30T12:01:03.000Z',
      ),
    );
    final service = SyncQueueService(
      database: database,
      remoteClient: remote,
      clock: () => DateTime.utc(2026, 4, 30, 12, 1),
    );

    final result = await service.processPendingOperations();

    expect(result.succeeded, 1);

    final transaction = await database.localTransactionById(transactionId);
    expect(transaction.serverId, 'server-tx-1');
    expect(transaction.syncStatus, SyncStatus.synced.name);
    expect(transaction.lastSyncError, isNull);
  });

  test('processPendingOperations marks failed transaction sync for retry',
      () async {
    final transactionId = await createQueuedTransaction();
    final remote = _FakeSyncRemoteClient(error: Exception('network down'));
    final service = SyncQueueService(
      database: database,
      remoteClient: remote,
      clock: () => DateTime.utc(2026, 4, 30, 12, 1),
    );

    final result = await service.processPendingOperations();

    expect(result.processed, 1);
    expect(result.succeeded, 0);
    expect(result.failed, 1);

    final syncOp = await database.syncOpForAggregate(transactionId);
    expect(syncOp.status, SyncStatus.failed.name);
    expect(syncOp.attemptCount, 1);
    expect(syncOp.lastError, contains('network down'));
    expect(syncOp.nextRetryAt, '2026-04-30T12:01:02.000Z');

    final transaction = await database.localTransactionById(transactionId);
    expect(transaction.syncStatus, SyncStatus.failed.name);
    expect(transaction.lastSyncError, contains('network down'));
  });
}
