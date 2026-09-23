import 'dart:math' as math;

import 'package:moneko/core/local_data/moneko_database.dart';

typedef LocalMutationDispatcher = Future<void> Function(
  LocalMutationOutboxData mutation,
);

typedef LocalMutationCancelledHandler = Future<void> Function(
  LocalMutationOutboxData mutation,
  Object error,
);

/// Signals that replay reached the server but cannot ever succeed by retrying.
class NonRetryableLocalMutationException implements Exception {
  const NonRetryableLocalMutationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A local dependency has not reached its canonical server identity yet.
/// Requeue without consuming a retry attempt.
class DeferredLocalMutationException implements Exception {
  const DeferredLocalMutationException();
}

class SyncCoordinator {
  const SyncCoordinator({
    required this.database,
    required this.dispatchMutation,
    this.onMutationCancelled,
    DateTime Function()? now,
    this.maxAttempts = 8,
  }) : _now = now;

  final MonekoDatabase database;
  final LocalMutationDispatcher dispatchMutation;
  final LocalMutationCancelledHandler? onMutationCancelled;
  final DateTime Function()? _now;
  final int maxAttempts;

  DateTime get _currentTime => (_now ?? DateTime.now)().toUtc();

  Future<int> drainOutbox({int maxMutations = 20}) async {
    var syncedCount = 0;

    for (var index = 0; index < maxMutations; index++) {
      final mutation = await database.nextRetryableMutation(_currentTime);
      if (mutation == null) break;

      final didMarkSyncing = await database.markMutationSyncingIfPayloadMatches(
        clientMutationId: mutation.clientMutationId,
        expectedPayloadJson: mutation.payloadJson,
      );
      if (!didMarkSyncing) continue;

      try {
        await dispatchMutation(mutation);
        final didMarkSynced = await database.markMutationSyncedIfPayloadMatches(
          clientMutationId: mutation.clientMutationId,
          expectedPayloadJson: mutation.payloadJson,
        );
        if (didMarkSynced) syncedCount += 1;
      } catch (error) {
        if (error is DeferredLocalMutationException) {
          await database.deferMutationIfPayloadMatches(
            clientMutationId: mutation.clientMutationId,
            expectedPayloadJson: mutation.payloadJson,
          );
          break;
        }
        final nextAttempt = mutation.attemptCount + 1;
        if (error is NonRetryableLocalMutationException ||
            (!isDurableHouseholdSettlementMutation(mutation) &&
                nextAttempt >= maxAttempts)) {
          final didCancel =
              await database.markMutationCancelledIfPayloadMatches(
            clientMutationId: mutation.clientMutationId,
            expectedPayloadJson: mutation.payloadJson,
            error: error,
          );
          if (didCancel) {
            await onMutationCancelled?.call(mutation, error);
          }
        } else {
          await database.markMutationFailedIfPayloadMatches(
            clientMutationId: mutation.clientMutationId,
            expectedPayloadJson: mutation.payloadJson,
            error: error,
            retryAfter: _currentTime.add(retryDelayForAttempt(nextAttempt)),
          );
        }
      }
    }

    return syncedCount;
  }

  static Duration retryDelayForAttempt(int attempt) {
    final safeAttempt = math.max(1, attempt);
    // Settlement attempts retry indefinitely. Avoid constructing a gigantic
    // integer after a long offline period once the delay has reached its cap.
    final seconds = safeAttempt >= 9 ? 300 : math.min(300, 1 << safeAttempt);
    return Duration(seconds: seconds);
  }
}
