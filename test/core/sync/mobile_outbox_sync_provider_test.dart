import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';

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

    test('ignores syncing mutations because they are not retryable', () {
      final now = DateTime(2026, 5, 13, 10);

      expect(
        resolveNextMobileOutboxRetryDelay([
          _mutation(id: 1, status: localMutationStatusSyncing),
        ], now: now),
        isNull,
      );
    });
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
}

LocalMutationOutboxData _mutation({
  required int id,
  required String status,
  String? clientMutationId,
  String entityType = 'transaction',
  String payloadJson = '{}',
  DateTime? retryAfter,
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
    updatedAt: now,
    attemptCount: 0,
    status: status,
    lastError: null,
    retryAfter: retryAfter,
  );
}
