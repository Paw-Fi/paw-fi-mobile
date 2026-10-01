import 'dart:async';

/// Shares only concurrent work with an exactly equal semantic/revision key.
/// Completed and failed operations are removed; this is not a result cache.
class InFlightRequests<K, V> {
  final Map<K, Future<V>> _requests = {};

  Future<V> run(K key, Future<V> Function() action) {
    final existing = _requests[key];
    if (existing != null) return existing;
    final completer = Completer<V>();
    final future = completer.future;
    _requests[key] = future;
    // Register before invoking action, including synchronous/reentrant callers.
    Future<V>.sync(action).then((value) {
      if (identical(_requests[key], future)) _requests.remove(key);
      completer.complete(value);
    }, onError: (Object error, StackTrace stack) {
      if (identical(_requests[key], future)) _requests.remove(key);
      completer.completeError(error, stack);
    });
    return future;
  }
}
