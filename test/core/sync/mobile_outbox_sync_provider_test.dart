import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';

void main() {
  group('resolveNextMobileOutboxRetryDelay', () {
    test('waits until the earliest retry_after for failed queued mutations',
        () {
      final now = DateTime(2026, 5, 13, 10);
      final mutations = [
        _mutation(
          id: 1,
          status: localMutationStatusFailed,
          retryAfter: now.add(const Duration(seconds: 30)),
        ),
        _mutation(
          id: 2,
          status: localMutationStatusFailed,
          retryAfter: now.add(const Duration(seconds: 5)),
        ),
      ];

      expect(
        resolveNextMobileOutboxRetryDelay(mutations, now: now),
        const Duration(seconds: 5),
      );
    });

    test('retries immediately when a queued mutation has no retry_after', () {
      final now = DateTime(2026, 5, 13, 10);

      expect(
        resolveNextMobileOutboxRetryDelay([
          _mutation(id: 1, status: localMutationStatusQueued),
        ], now: now),
        Duration.zero,
      );
    });

    test('ignores synced and cancelled mutations', () {
      final now = DateTime(2026, 5, 13, 10);

      expect(
        resolveNextMobileOutboxRetryDelay([
          _mutation(id: 1, status: localMutationStatusSynced),
          _mutation(id: 2, status: localMutationStatusCancelled),
        ], now: now),
        isNull,
      );
    });

    test('schedules syncing mutations at their existing lease expiry', () {
      final now = DateTime(2026, 5, 13, 10);

      expect(
        resolveNextMobileOutboxRetryDelay([
          _mutation(
            id: 1,
            status: localMutationStatusSyncing,
            updatedAt: now.subtract(const Duration(minutes: 9)),
          ),
        ], now: now),
        const Duration(minutes: 1),
      );
    });

    test('expired leases wake immediately and respect earlier queued retries',
        () {
      final now = DateTime(2026, 5, 13, 10);
      expect(
        resolveNextMobileOutboxRetryDelay([
          _mutation(id: 1, status: localMutationStatusSyncing),
        ], now: now),
        Duration.zero,
      );
      expect(
        resolveNextMobileOutboxRetryDelay([
          _mutation(
              id: 1,
              status: localMutationStatusSyncing,
              updatedAt: now.subtract(const Duration(minutes: 9))),
          _mutation(
              id: 2,
              status: localMutationStatusFailed,
              retryAfter: now.add(const Duration(seconds: 5))),
        ], now: now),
        const Duration(seconds: 5),
      );
    });
  });

  test('drainer schedules retryable failures and cancels timers on dispose',
      () {
    fakeAsync((time) {
      final database = MonekoDatabase.inMemory();
      final clock = time.getClock(DateTime.now());
      var attempts = 0;
      final coordinator = SyncCoordinator(
        database: database,
        now: clock.now,
        dispatchMutation: (_) async {
          attempts += 1;
          if (attempts == 1) throw StateError('temporary outage');
        },
      );
      final drainer =
          MobileOutboxDrainer(() async => coordinator, now: clock.now);
      unawaited(database.enqueueMutation(
        clientMutationId: 'scheduled',
        entityType: 'transaction',
        entityId: 'actual',
        operation: localRecurringOccurrenceConfirmationMutationOperation,
        payload: {},
      ));
      time.flushMicrotasks();
      unawaited(drainer.drain());
      time.flushMicrotasks();
      expect(attempts, 1);
      time.elapse(const Duration(seconds: 1));
      expect(attempts, 1);
      time.elapse(const Duration(seconds: 1));
      time.flushMicrotasks();
      expect(attempts, 2);
      expect(time.nonPeriodicTimerCount, 0);
      unawaited(database.markMutationFailed(
        clientMutationId: 'scheduled',
        error: 'temporary outage',
        retryAfter: clock.now().add(const Duration(seconds: 30)),
      ));
      time.flushMicrotasks();
      unawaited(drainer.drain());
      time.flushMicrotasks();
      expect(time.nonPeriodicTimerCount, 1);
      drainer.dispose();
      time.elapse(const Duration(seconds: 31));
      expect(attempts, 2);
      unawaited(database.close());
      time.flushMicrotasks();
    });
  });

  test('drainer wakes an interrupted request when its lease expires', () async {
    final database = MonekoDatabase.inMemory();
    await database.enqueueMutation(
      clientMutationId: 'interrupted',
      entityType: 'transaction',
      entityId: 'actual',
      operation: localRecurringOccurrenceConfirmationMutationOperation,
      payload: {},
    );
    await database.markMutationSyncing('interrupted');
    final mutation = (await database.getOutboxMutations()).single;
    fakeAsync((time) {
      final clock = time.getClock(mutation.updatedAt);
      var requests = 0;
      final coordinator = SyncCoordinator(
        database: database,
        now: clock.now,
        dispatchMutation: (_) async {
          requests += 1;
        },
      );
      final drainer =
          MobileOutboxDrainer(() async => coordinator, now: clock.now);
      unawaited(drainer.drain());
      time.flushMicrotasks();
      expect(requests, 0);
      expect(time.nonPeriodicTimerCount, 1);
      time.elapse(const Duration(minutes: 9));
      expect(requests, 0);
      time.elapse(const Duration(minutes: 1));
      time.flushMicrotasks();
      expect(requests, 1);
      expect(time.nonPeriodicTimerCount, 0);
      drainer.dispose();
    });
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusSynced);
    await database.close();
  });

  test('overlapping drains share the complete in-flight dispatch', () async {
    final database = MonekoDatabase.inMemory();
    final entered = Completer<void>();
    final release = Completer<void>();
    var attempts = 0;
    final coordinator = SyncCoordinator(
      database: database,
      dispatchMutation: (_) async {
        attempts += 1;
        entered.complete();
        await release.future;
      },
    );
    final drainer = MobileOutboxDrainer(() async => coordinator);
    addTearDown(() async {
      drainer.dispose();
      await database.close();
    });
    await database.enqueueMutation(
      clientMutationId: 'overlap',
      entityType: 'transaction',
      entityId: 'actual',
      operation: localRecurringOccurrenceConfirmationMutationOperation,
      payload: {},
    );
    final first = drainer.drain();
    await entered.future;
    final second = drainer.drain();
    release.complete();
    await Future.wait([first, second]);
    expect(attempts, 1);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusSynced);
  });

  group('pocketEnvelopeReplayConflictTarget', () {
    test('upserts optimistic pockets by budget and name during replay', () {
      expect(
        pocketEnvelopeReplayConflictTarget('optimistic-pocket-123'),
        'budget_id,name',
      );
    });

    test('keeps existing server pockets on direct id updates', () {
      expect(
        pocketEnvelopeReplayConflictTarget('server-pocket-123'),
        isNull,
      );
    });
  });

  group('cancelledPocketMutationStillOwnsOutbox', () {
    test('accepts the same cancelled payload', () {
      final cancelled = _mutation(
        id: 1,
        clientMutationId: 'pockets-month',
        status: localMutationStatusCancelled,
        entityType: 'pockets_month',
        payloadJson: '{"mutationRevision":"1"}',
      );

      expect(
        cancelledPocketMutationStillOwnsOutbox(cancelled, [cancelled]),
        isTrue,
      );
    });

    test('rejects a newer replacement payload', () {
      final cancelled = _mutation(
        id: 1,
        clientMutationId: 'pockets-month',
        status: localMutationStatusCancelled,
        entityType: 'pockets_month',
        payloadJson: '{"mutationRevision":"1"}',
      );
      final replacement = _mutation(
        id: 2,
        clientMutationId: 'pockets-month',
        status: localMutationStatusQueued,
        entityType: 'pockets_month',
        payloadJson: '{"mutationRevision":"2"}',
      );

      expect(
        cancelledPocketMutationStillOwnsOutbox(cancelled, [replacement]),
        isFalse,
      );
    });
  });

  group('batchTransactionResponseMatchesRequest', () {
    test('accepts every requested transaction exactly once', () {
      expect(
        batchTransactionResponseMatchesRequest(
          ['expense-1', 'expense-2'],
          ['expense-2', 'expense-1'],
        ),
        isTrue,
      );
    });

    test('rejects a partial backend response', () {
      expect(
        batchTransactionResponseMatchesRequest(
          ['expense-1', 'expense-2'],
          ['expense-1'],
        ),
        isFalse,
      );
    });
  });
}

LocalMutationOutboxData _mutation({
  required int id,
  required String status,
  String? clientMutationId,
  String entityType = 'transaction',
  String payloadJson = '{}',
  DateTime? retryAfter,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 5, 13, 9);
  return LocalMutationOutboxData(
    id: id,
    clientMutationId: clientMutationId ?? 'mutation-$id',
    entityType: entityType,
    entityId: 'transaction-$id',
    operation: 'create',
    payloadJson: payloadJson,
    createdAt: now,
    updatedAt: updatedAt ?? now,
    attemptCount: 0,
    status: status,
    lastError: null,
    retryAfter: retryAfter,
  );
}
