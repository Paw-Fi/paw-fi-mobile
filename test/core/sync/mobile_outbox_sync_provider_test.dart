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
}

LocalMutationOutboxData _mutation({
  required int id,
  required String status,
  DateTime? retryAfter,
}) {
  final now = DateTime(2026, 5, 13, 9);
  return LocalMutationOutboxData(
    id: id,
    clientMutationId: 'mutation-$id',
    entityType: 'transaction',
    entityId: 'transaction-$id',
    operation: 'create',
    payloadJson: '{}',
    createdAt: now,
    updatedAt: now,
    attemptCount: 0,
    status: status,
    lastError: null,
    retryAfter: retryAfter,
  );
}
