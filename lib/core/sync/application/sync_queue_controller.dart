import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/sync_providers.dart';
import '../data/sync_queue_service.dart';

enum SyncTrigger {
  appStart,
  appResume,
  networkRestored,
  pullToRefresh,
  manual,
}

final syncConnectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final syncQueueControllerProvider =
    AsyncNotifierProvider<SyncQueueController, SyncQueueControllerState>(
  SyncQueueController.new,
);

class SyncQueueControllerState {
  const SyncQueueControllerState({
    required this.isRunning,
    this.lastTrigger,
    this.lastResult,
    this.lastError,
    this.lastStartedAt,
    this.lastCompletedAt,
  });

  const SyncQueueControllerState.idle()
      : isRunning = false,
        lastTrigger = null,
        lastResult = null,
        lastError = null,
        lastStartedAt = null,
        lastCompletedAt = null;

  final bool isRunning;
  final SyncTrigger? lastTrigger;
  final SyncQueueProcessResult? lastResult;
  final String? lastError;
  final DateTime? lastStartedAt;
  final DateTime? lastCompletedAt;

  bool get hasFailures => (lastResult?.failed ?? 0) > 0;

  SyncQueueControllerState running({
    required SyncTrigger trigger,
    required DateTime startedAt,
  }) {
    return SyncQueueControllerState(
      isRunning: true,
      lastTrigger: trigger,
      lastResult: lastResult,
      lastError: null,
      lastStartedAt: startedAt,
      lastCompletedAt: lastCompletedAt,
    );
  }

  SyncQueueControllerState completed({
    required SyncTrigger trigger,
    required SyncQueueProcessResult result,
    required DateTime completedAt,
  }) {
    return SyncQueueControllerState(
      isRunning: false,
      lastTrigger: trigger,
      lastResult: result,
      lastError: null,
      lastStartedAt: lastStartedAt,
      lastCompletedAt: completedAt,
    );
  }

  SyncQueueControllerState failed({
    required SyncTrigger trigger,
    required Object error,
    required DateTime completedAt,
  }) {
    return SyncQueueControllerState(
      isRunning: false,
      lastTrigger: trigger,
      lastResult: lastResult,
      lastError: error.toString(),
      lastStartedAt: lastStartedAt,
      lastCompletedAt: completedAt,
    );
  }
}

class SyncQueueController extends AsyncNotifier<SyncQueueControllerState> {
  bool _isRunning = false;

  @override
  FutureOr<SyncQueueControllerState> build() {
    ref.listen<AsyncValue<List<ConnectivityResult>>>(
      syncConnectivityProvider,
      (previous, next) {
        final previousOnline =
            _hasNetworkRoute(previous?.valueOrNull ?? const []);
        final nextOnline = _hasNetworkRoute(next.valueOrNull ?? const []);
        if (!previousOnline && nextOnline) {
          unawaited(syncNow(SyncTrigger.networkRestored));
        }
      },
    );
    return const SyncQueueControllerState.idle();
  }

  Future<SyncQueueProcessResult?> syncNow(
    SyncTrigger trigger, {
    int limit = 20,
  }) async {
    if (_isRunning) {
      return null;
    }

    _isRunning = true;
    final startedAt = DateTime.now();
    final current = state.valueOrNull ?? const SyncQueueControllerState.idle();
    state = AsyncData(
      current.running(
        trigger: trigger,
        startedAt: startedAt,
      ),
    );

    try {
      final result = await ref
          .read(syncQueueProcessorProvider)
          .processPendingOperations(limit: limit);
      state = AsyncData(
        (state.valueOrNull ?? current).completed(
          trigger: trigger,
          result: result,
          completedAt: DateTime.now(),
        ),
      );
      return result;
    } catch (error) {
      state = AsyncData(
        (state.valueOrNull ?? current).failed(
          trigger: trigger,
          error: error,
          completedAt: DateTime.now(),
        ),
      );
      return null;
    } finally {
      _isRunning = false;
    }
  }

  static bool _hasNetworkRoute(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
