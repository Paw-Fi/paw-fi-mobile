import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';

void main() {
  late MonekoDatabase database;

  setUp(() {
    database = MonekoDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('drainOutbox dispatches retryable mutations in creation order',
      () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    await database.enqueueMutation(
      clientMutationId: 'first',
      entityType: 'transaction',
      entityId: 'txn_1',
      operation: 'create',
      payload: {'id': 'txn_1'},
      createdAt: now.subtract(const Duration(minutes: 2)),
    );
    await database.enqueueMutation(
      clientMutationId: 'second',
      entityType: 'transaction',
      entityId: 'txn_2',
      operation: 'create',
      payload: {'id': 'txn_2'},
      createdAt: now.subtract(const Duration(minutes: 1)),
    );

    final dispatched = <String>[];
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      dispatchMutation: (mutation) async {
        dispatched.add(mutation.clientMutationId);
      },
    );

    final count = await coordinator.drainOutbox();
    final mutations = await database.getOutboxMutations();

    expect(count, 2);
    expect(dispatched, ['first', 'second']);
    expect(
      mutations.map((mutation) => mutation.status),
      [localMutationStatusSynced, localMutationStatusSynced],
    );
  });

  test('drainOutbox applies retry backoff and continues after failure',
      () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    await database.enqueueMutation(
      clientMutationId: 'failing',
      entityType: 'transaction',
      entityId: 'txn_1',
      operation: 'create',
      payload: {'id': 'txn_1'},
      createdAt: now.subtract(const Duration(minutes: 2)),
    );
    await database.enqueueMutation(
      clientMutationId: 'not-yet',
      entityType: 'transaction',
      entityId: 'txn_2',
      operation: 'create',
      payload: {'id': 'txn_2'},
      createdAt: now.subtract(const Duration(minutes: 1)),
    );

    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      dispatchMutation: (_) async {
        throw StateError('offline');
      },
    );

    final count = await coordinator.drainOutbox();
    final mutations = await database.getOutboxMutations();

    expect(count, 0);
    expect(
      mutations.map((mutation) => mutation.status),
      [localMutationStatusFailed, localMutationStatusFailed],
    );
    expect(mutations.map((mutation) => mutation.attemptCount), [1, 1]);
    expect(mutations.first.lastError, contains('offline'));
    expect(mutations.first.retryAfter, now.add(const Duration(seconds: 2)));
    expect(mutations.last.retryAfter, now.add(const Duration(seconds: 2)));
  });

  test('drainOutbox cancels poison mutation and continues later rows',
      () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    await database.enqueueMutation(
      clientMutationId: 'poison',
      entityType: 'transaction',
      entityId: 'txn_1',
      operation: 'create',
      payload: {'id': 'txn_1'},
      createdAt: now.subtract(const Duration(minutes: 2)),
    );
    await database.enqueueMutation(
      clientMutationId: 'next',
      entityType: 'transaction',
      entityId: 'txn_2',
      operation: 'create',
      payload: {'id': 'txn_2'},
      createdAt: now.subtract(const Duration(minutes: 1)),
    );

    final dispatched = <String>[];
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      maxAttempts: 1,
      dispatchMutation: (mutation) async {
        dispatched.add(mutation.clientMutationId);
        if (mutation.clientMutationId == 'poison') {
          throw StateError('bad payload');
        }
      },
    );

    final count = await coordinator.drainOutbox();
    final mutations = await database.getOutboxMutations();

    expect(count, 1);
    expect(dispatched, ['poison', 'next']);
    expect(
      mutations.map((mutation) => mutation.status),
      [localMutationStatusCancelled, localMutationStatusSynced],
    );
  });
}
