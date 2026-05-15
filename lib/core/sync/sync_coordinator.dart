import 'dart:math' as math;

import 'package:moneko/core/local_data/moneko_database.dart';

typedef LocalMutationDispatcher = Future<void> Function(
  LocalMutationOutboxData mutation,
);

typedef LocalMutationCancelledHandler = Future<void> Function(
  LocalMutationOutboxData mutation,
  Object error,
);

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

      await database.markMutationSyncing(mutation.clientMutationId);

      try {
        await dispatchMutation(mutation);
        await database.markMutationSynced(mutation.clientMutationId);
        syncedCount += 1;
      } catch (error) {
        final nextAttempt = mutation.attemptCount + 1;
        if (nextAttempt >= maxAttempts) {
          await database.markMutationCancelled(
            clientMutationId: mutation.clientMutationId,
            error: error,
          );
          await onMutationCancelled?.call(mutation, error);
        } else {
          await database.markMutationFailed(
            clientMutationId: mutation.clientMutationId,
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
    final seconds = math.min(300, 1 << safeAttempt);
    return Duration(seconds: seconds);
  }
}
