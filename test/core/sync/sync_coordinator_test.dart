import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

String _settlementSnapshotToken(String character) =>
    'v1:${List<String>.filled(64, character).join()}';

void main() {
  late MonekoDatabase database;

  setUp(() {
    database = MonekoDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test(
      'a Pocket review survives SQLite reopen and an explicit discard remains retired',
      () async {
    final directory = await Directory.systemTemp.createTemp('pocket-review-');
    final path = '${directory.path}/outbox.sqlite';
    var disk =
        MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
    try {
      await disk.enqueueMutation(
          clientMutationId: 'month',
          entityType: 'pockets_month',
          entityId: 'month',
          operation: 'save_pockets_month',
          payload: {'mutationRevision': '1'});
      final row = (await disk.getOutboxMutations()).single;
      await disk.markMutationNeedsReviewIfPayloadMatches(
          clientMutationId: row.clientMutationId,
          expectedPayloadJson: row.payloadJson,
          error: 'conflict');
      await disk.close();
      disk = MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
      final restored = (await disk.getOutboxMutations()).single;
      expect(restored.status, localMutationStatusNeedsReview);
      expect(restored.payloadJson, row.payloadJson);
      expect(await disk.nextRetryableMutation(DateTime.now()), isNull);
      await disk.discardMutationReviewIfPayloadMatches(
          clientMutationId: restored.clientMutationId,
          expectedPayloadJson: restored.payloadJson);
      await disk.close();
      disk = MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
      expect((await disk.getOutboxMutations()).single.status,
          localMutationStatusCancelled);
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });

  test('a superseded conflict cannot hold or annotate the newer Pocket intent',
      () async {
    await database.enqueueMutation(
        clientMutationId: 'month',
        entityType: 'pockets_month',
        entityId: 'month',
        operation: 'save_pockets_month',
        payload: {'mutationRevision': '1'});
    var reviews = 0;
    final coordinator = SyncCoordinator(
        database: database,
        onMutationNeedsReview: (_, error) async {
          reviews++;
        },
        dispatchMutation: (_) async {
          await database.enqueueMutation(
              clientMutationId: 'month',
              entityType: 'pockets_month',
              entityId: 'month',
              operation: 'save_pockets_month',
              payload: {'mutationRevision': '2'});
          throw const ManualReviewLocalMutationException('stale request');
        });
    await coordinator.drainOutbox(maxMutations: 1);
    final latest = (await database.getOutboxMutations()).single;
    expect(latest.status, localMutationStatusQueued);
    expect(latest.lastError, isNull);
    expect(reviews, 0);
  });

  for (final operation in ['save_pockets_month', 'assign_pocket_category']) {
    test('$operation survives retry exhaustion and later reconciles', () async {
      var now = DateTime.now().toUtc();
      await database.enqueueMutation(
          clientMutationId: 'durable',
          entityType: 'pockets_month',
          entityId: 'month',
          operation: operation,
          payload: {'mutationRevision': '1'});
      var online = false;
      final coordinator = SyncCoordinator(
          database: database,
          now: () => now,
          dispatchMutation: (_) async {
            if (!online) throw StateError('offline');
          });
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(minutes: 10));
        await coordinator.drainOutbox(maxMutations: 1);
      }
      final held = (await database.getOutboxMutations()).single;
      expect(held.status, localMutationStatusFailed);
      expect(held.attemptCount, 10);
      online = true;
      now = now.add(const Duration(minutes: 10));
      expect(await coordinator.drainOutbox(), 1);
      expect((await database.getOutboxMutations()).single.status,
          localMutationStatusSynced);
    });
  }

  test('discarding a review checks the payload and cannot cancel a replacement',
      () async {
    await database.enqueueMutation(
        clientMutationId: 'month',
        entityType: 'pockets_month',
        entityId: 'month',
        operation: 'save_pockets_month',
        payload: {'mutationRevision': '1'});
    final original = (await database.getOutboxMutations()).single;
    await database.markMutationNeedsReviewIfPayloadMatches(
        clientMutationId: 'month',
        expectedPayloadJson: original.payloadJson,
        error: 'conflict');
    await database.enqueueMutation(
        clientMutationId: 'month',
        entityType: 'pockets_month',
        entityId: 'month',
        operation: 'save_pockets_month',
        payload: {'mutationRevision': '2'});
    expect(
        await database.discardMutationReviewIfPayloadMatches(
            clientMutationId: 'month',
            expectedPayloadJson: original.payloadJson),
        isFalse);
    final latest = (await database.getOutboxMutations()).single;
    await database.markMutationNeedsReviewIfPayloadMatches(
        clientMutationId: 'month',
        expectedPayloadJson: latest.payloadJson,
        error: 'conflict');
    expect(
        await database.discardMutationReviewIfPayloadMatches(
            clientMutationId: 'month', expectedPayloadJson: latest.payloadJson),
        isTrue);
    expect(await database.nextRetryableMutation(DateTime.now()), isNull);
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

  test('an older success cannot mark a replacement payload synced', () async {
    final now = DateTime.utc(2026, 9, 22, 12);
    await database.enqueueMutation(
      clientMutationId: 'pockets-month',
      entityType: 'pockets_month',
      entityId: 'personal:2026-09-01:EUR',
      operation: 'save_pockets_month',
      payload: const {'mutationRevision': '1'},
      createdAt: now,
    );
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      dispatchMutation: (_) async {
        await database.enqueueMutation(
          clientMutationId: 'pockets-month',
          entityType: 'pockets_month',
          entityId: 'personal:2026-09-01:EUR',
          operation: 'save_pockets_month',
          payload: const {'mutationRevision': '2'},
        );
      },
    );

    expect(await coordinator.drainOutbox(maxMutations: 1), 0);
    final mutation = (await database.getOutboxMutations()).single;
    expect(mutation.status, localMutationStatusQueued);
    expect(mutation.payloadJson, contains('"mutationRevision":"2"'));
  });

  test('stale pocket writes remain durable for explicit review', () async {
    final now = DateTime.utc(2026, 9, 22, 12);
    await database.enqueueMutation(
      clientMutationId: 'pockets-month',
      entityType: 'pockets_month',
      entityId: 'personal:2026-09-01:EUR',
      operation: 'save_pockets_month',
      payload: const {'mutationRevision': '1'},
      createdAt: now,
    );
    final reviewRequired = <String>[];
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      onMutationNeedsReview: (mutation, _) async {
        reviewRequired.add(mutation.clientMutationId);
      },
      dispatchMutation: (_) async {
        throw const ManualReviewLocalMutationException(
          'Pocket plan changed on another device.',
        );
      },
    );

    expect(await coordinator.drainOutbox(maxMutations: 1), 0);
    final mutation = (await database.getOutboxMutations()).single;
    expect(mutation.status, localMutationStatusNeedsReview);
    expect(mutation.attemptCount, 0);
    expect(mutation.lastError, contains('changed on another device'));
    expect(reviewRequired, ['pockets-month']);
    expect(await database.nextRetryableMutation(now), isNull);
  });

  test('an older terminal failure cannot cancel a replacement payload',
      () async {
    final now = DateTime.utc(2026, 9, 22, 12);
    await database.enqueueMutation(
      clientMutationId: 'pockets-month',
      entityType: 'pockets_month',
      entityId: 'personal:2026-09-01:EUR',
      operation: 'save_pockets_month',
      payload: const {'mutationRevision': '1'},
      createdAt: now,
    );
    final cancelled = <String>[];
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      maxAttempts: 1,
      dispatchMutation: (_) async {
        await database.enqueueMutation(
          clientMutationId: 'pockets-month',
          entityType: 'pockets_month',
          entityId: 'personal:2026-09-01:EUR',
          operation: 'save_pockets_month',
          payload: const {'mutationRevision': '2'},
        );
        throw StateError('old failure');
      },
      onMutationCancelled: (mutation, _) async {
        cancelled.add(mutation.clientMutationId);
      },
    );

    expect(await coordinator.drainOutbox(maxMutations: 1), 0);
    final mutation = (await database.getOutboxMutations()).single;
    expect(mutation.status, localMutationStatusQueued);
    expect(cancelled, isEmpty);
  });

  test('a late retryable failure cannot overwrite a synced payload', () async {
    final now = DateTime.utc(2026, 9, 22, 12);
    await database.enqueueMutation(
      clientMutationId: 'pockets-month',
      entityType: 'pockets_month',
      entityId: 'personal:2026-09-01:EUR',
      operation: 'save_pockets_month',
      payload: const {'mutationRevision': '1'},
      createdAt: now,
    );
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      dispatchMutation: (mutation) async {
        await database.markMutationSyncedIfPayloadMatches(
          clientMutationId: mutation.clientMutationId,
          expectedPayloadJson: mutation.payloadJson,
        );
        throw StateError('late failure');
      },
    );

    expect(await coordinator.drainOutbox(maxMutations: 1), 0);
    final mutation = (await database.getOutboxMutations()).single;
    expect(mutation.status, localMutationStatusSynced);
    expect(mutation.attemptCount, 0);
  });

  test('a late terminal failure cannot cancel a synced payload', () async {
    final now = DateTime.utc(2026, 9, 22, 12);
    await database.enqueueMutation(
      clientMutationId: 'pockets-month',
      entityType: 'pockets_month',
      entityId: 'personal:2026-09-01:EUR',
      operation: 'save_pockets_month',
      payload: const {'mutationRevision': '1'},
      createdAt: now,
    );
    final cancelled = <String>[];
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      maxAttempts: 1,
      dispatchMutation: (mutation) async {
        await database.markMutationSyncedIfPayloadMatches(
          clientMutationId: mutation.clientMutationId,
          expectedPayloadJson: mutation.payloadJson,
        );
        throw StateError('late failure');
      },
      onMutationCancelled: (mutation, _) async {
        cancelled.add(mutation.clientMutationId);
      },
    );

    expect(await coordinator.drainOutbox(maxMutations: 1), 0);
    expect(
      (await database.getOutboxMutations()).single.status,
      localMutationStatusSynced,
    );
    expect(cancelled, isEmpty);
  });

  test('a replacement payload starts with a fresh retry count', () async {
    final now = DateTime.utc(2026, 9, 22, 12);
    await database.enqueueMutation(
      clientMutationId: 'pockets-month',
      entityType: 'pockets_month',
      entityId: 'personal:2026-09-01:EUR',
      operation: 'save_pockets_month',
      payload: const {'mutationRevision': '1'},
      createdAt: now,
    );
    await database.markMutationFailed(
      clientMutationId: 'pockets-month',
      error: 'offline',
      retryAfter: now,
    );

    await database.enqueueMutation(
      clientMutationId: 'pockets-month',
      entityType: 'pockets_month',
      entityId: 'personal:2026-09-01:EUR',
      operation: 'save_pockets_month',
      payload: const {'mutationRevision': '2'},
    );

    final mutation = (await database.getOutboxMutations()).single;
    expect(mutation.status, localMutationStatusQueued);
    expect(mutation.attemptCount, 0);
    expect(mutation.payloadJson, contains('"mutationRevision":"2"'));
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

  test('defers a dependency without consuming a retry attempt', () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    await database.enqueueMutation(
      clientMutationId: 'dependent-transfer-edit',
      entityType: 'wallet',
      entityId: 'optimistic-transfer-1',
      operation: 'invoke_function',
      payload: const {'functionName': 'update-wallet-transfer'},
      createdAt: now,
    );
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      dispatchMutation: (_) async =>
          throw const DeferredLocalMutationException(),
    );

    expect(await coordinator.drainOutbox(), 0);
    final mutation = (await database.getOutboxMutations()).single;
    expect(mutation.status, localMutationStatusQueued);
    expect(mutation.attemptCount, 0);
    expect(mutation.retryAfter, isNull);
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

  test('drainOutbox notifies when a mutation is exhausted', () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    await database.enqueueMutation(
      clientMutationId: 'poison',
      entityType: 'transaction',
      entityId: 'txn_1',
      operation: 'create',
      payload: {'id': 'txn_1'},
      createdAt: now.subtract(const Duration(minutes: 2)),
    );

    final exhausted = <String>[];
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      maxAttempts: 1,
      dispatchMutation: (_) async {
        throw StateError('bad payload');
      },
      onMutationCancelled: (mutation, _) async {
        exhausted.add(mutation.clientMutationId);
      },
    );

    await coordinator.drainOutbox();

    expect(exhausted, ['poison']);
  });

  test('durable settlement mutations never use generic cancellation', () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    await database.enqueueHouseholdSettlementMutation(
      householdId: 'household-1',
      memberUserId: 'member-1',
      mode: 'both',
      amountCents: 6611,
      currency: 'CAD',
      note: null,
      expectedSnapshotToken: _settlementSnapshotToken('a'),
      clientMutationId: 'settlement-1',
    );
    final exhausted = <String>[];
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      maxAttempts: 1,
      dispatchMutation: (_) async {
        throw StateError('unknown remote outcome');
      },
      onMutationCancelled: (mutation, _) async {
        exhausted.add(mutation.clientMutationId);
      },
    );

    expect(await coordinator.drainOutbox(), 0);

    final mutation = (await database.getOutboxMutations()).single;
    expect(mutation.status, localMutationStatusFailed);
    expect(mutation.attemptCount, 1);
    expect(mutation.lastError, contains('unknown remote outcome'));
    expect(exhausted, isEmpty);
  });

  test('retry delay remains bounded for indefinite attempts', () {
    expect(
      SyncCoordinator.retryDelayForAttempt(100000),
      const Duration(minutes: 5),
    );
  });

  for (final operation in [
    localRecurringOccurrenceConfirmationMutationOperation,
    'update_recurring_occurrence',
    'unconfirm_recurring_occurrence',
    'skip_recurring_occurrence',
  ]) {
    test('$operation survives retry exhaustion but cancels terminal rejection',
        () async {
      var now = DateTime.now().toUtc();
      await database.enqueueMutation(
        clientMutationId: 'durable-occurrence',
        entityType: 'transaction',
        entityId: 'occurrence-actual',
        operation: operation,
        payload: const {
          'requestBody': {'recurringId': 'series'}
        },
      );
      var terminal = false;
      var cancellations = 0;
      final coordinator = SyncCoordinator(
        database: database,
        now: () => now,
        dispatchMutation: (_) async {
          if (terminal) {
            throw const NonRetryableLocalMutationException(
                'OCCURRENCE_CONFLICT');
          }
          throw StateError('temporary outage');
        },
        onMutationCancelled: (_, __) async => cancellations += 1,
      );
      for (var attempt = 1; attempt <= 10; attempt++) {
        await coordinator.drainOutbox();
        final mutation = (await database.getOutboxMutations()).single;
        expect(mutation.status, localMutationStatusFailed);
        expect(mutation.attemptCount, attempt);
        expect(cancellations, 0);
        now = now.add(const Duration(minutes: 6));
      }
      terminal = true;
      await coordinator.drainOutbox();
      expect((await database.getOutboxMutations()).single.status,
          localMutationStatusCancelled);
      expect(cancellations, 1);
    });
  }

  test('cancels non-retryable occurrence failures without retrying', () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    final entry = ExpenseEntry(
      id: 'occurrence_1',
      userId: 'user-1',
      date: DateTime(2026, 4, 8),
      amountCents: 1200,
      currency: 'USD',
      category: 'food',
      createdAt: now,
      type: 'expense',
    );
    await database.writeOptimisticTransaction(
      entry: entry,
      clientMutationId: 'recurring-occurrence:v1:user-1:series:2026-04-08',
      operation: localRecurringOccurrenceConfirmationMutationOperation,
      payload: const {'requestBody': {}},
    );

    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      dispatchMutation: (_) async {
        throw const NonRetryableLocalMutationException('not due');
      },
      onMutationCancelled: (mutation, _) =>
          database.markTransactionMutationExhausted(mutation: mutation),
    );
    await coordinator.drainOutbox();

    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
    expect(
      await database.getRecentTransactions(userId: 'user-1', householdId: null),
      isEmpty,
    );
  });

  test('exhausted create mutations are excluded from feed and summaries',
      () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    final entry = ExpenseEntry(
      id: 'txn_1',
      userId: 'user-1',
      date: DateTime(2026, 4, 8),
      amountCents: 1200,
      currency: 'USD',
      category: 'food',
      createdAt: now,
      type: 'expense',
    );
    await database.writeOptimisticTransaction(
      entry: entry,
      clientMutationId: 'create-1',
      operation: 'create',
      payload: {'id': entry.id},
    );

    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      maxAttempts: 1,
      dispatchMutation: (_) async {
        throw StateError('bad payload');
      },
      onMutationCancelled: (mutation, _) async {
        await database.markTransactionMutationExhausted(mutation: mutation);
      },
    );

    await coordinator.drainOutbox();

    final recent = await database.getRecentTransactions(
      userId: 'user-1',
      householdId: null,
    );
    final summary = await database.getTransactionsFeedSummary(
      const LocalTransactionsFeedQuery(
        userId: 'user-1',
        householdId: null,
        currency: 'USD',
      ),
    );

    expect(recent, isEmpty);
    expect(summary.transactionCount, 0);
    expect(summary.expenseTotalCents, 0);
  });

  test('exhausted update mutations restore the original transaction', () async {
    final now = DateTime.utc(2026, 4, 8, 12);
    final original = ExpenseEntry(
      id: 'txn_1',
      userId: 'user-1',
      date: DateTime(2026, 4, 8),
      amountCents: 1200,
      currency: 'USD',
      category: 'food',
      createdAt: now,
      type: 'expense',
    );
    final updated = original.copyWith(amountCents: 1800);
    await database.upsertTransactions([original]);
    await database.writeOptimisticTransactionUpdate(
      originalEntry: original,
      updatedEntry: updated,
      clientMutationId: 'update-1',
      payload: {'id': original.id},
    );

    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      maxAttempts: 1,
      dispatchMutation: (_) async {
        throw StateError('bad payload');
      },
      onMutationCancelled: (mutation, _) async {
        await database.markTransactionMutationExhausted(mutation: mutation);
      },
    );

    await coordinator.drainOutbox();

    final recent = await database.getRecentTransactions(
      userId: 'user-1',
      householdId: null,
    );

    expect(recent.single.amountCents, 1200);
  });
}
