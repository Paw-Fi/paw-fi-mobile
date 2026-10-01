import 'dart:async';

import 'package:moneko/core/utils/in_flight_requests.dart';

/// Shares a complete reconciliation only for the same captured scope/revision.
/// A surviving caller retries if the original lifecycle owner was cancelled.
class ForegroundReconciler<K> {
  final _requests = InFlightRequests<K, bool>();
  final Map<Object, Future<void>> _serialTails = {};

  Future<void> run({
    required K identity,
    required bool Function() isActive,
    required List<Future<void> Function()> phases,
    Object? serializationKey,
  }) async {
    while (isActive()) {
      Future<bool> reconcile() async {
        for (final phase in phases) {
          if (!isActive()) return false;
          await phase();
        }
        return isActive();
      }

      final completed = await _requests.run(
          identity,
          () => serializationKey == null
              ? reconcile()
              : _serialize(serializationKey, reconcile));
      if (completed) return;
    }
  }

  Future<bool> _serialize(Object key, Future<bool> Function() action) async {
    final previous = _serialTails[key];
    final release = Completer<void>();
    final tail = release.future;
    _serialTails[key] = tail;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      // The lane always completes successfully; failures still propagate to
      // this request but must not prevent a newer revision from reconciling.
      if (identical(_serialTails[key], tail)) _serialTails.remove(key);
      release.complete();
    }
  }
}
