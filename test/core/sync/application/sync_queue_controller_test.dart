import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/sync/application/sync_queue_controller.dart';
import 'package:moneko/core/sync/data/sync_providers.dart';
import 'package:moneko/core/sync/data/sync_queue_service.dart';

class _FakeSyncQueueProcessor implements SyncQueueProcessor {
  _FakeSyncQueueProcessor({
    SyncQueueProcessResult? result,
    this.error,
    this.started,
    this.complete,
  }) : result = result ??
            const SyncQueueProcessResult(
              processed: 1,
              succeeded: 1,
              failed: 0,
            );

  final SyncQueueProcessResult result;
  final Object? error;
  final Completer<void>? started;
  final Completer<void>? complete;
  var callCount = 0;
  final limits = <int>[];

  @override
  Future<SyncQueueProcessResult> processPendingOperations({
    int limit = 20,
  }) async {
    callCount += 1;
    limits.add(limit);
    started?.complete();
    await complete?.future;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return result;
  }
}

void main() {
  ProviderContainer createContainer(_FakeSyncQueueProcessor processor) {
    return ProviderContainer(
      overrides: [
        syncConnectivityProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        syncQueueProcessorProvider.overrideWithValue(processor),
      ],
    );
  }

  test('syncNow keeps stable AsyncData state while processing', () async {
    final processor = _FakeSyncQueueProcessor();
    final container = createContainer(processor);
    addTearDown(container.dispose);

    final controller = container.read(syncQueueControllerProvider.notifier);

    final result = await controller.syncNow(SyncTrigger.manual, limit: 5);

    expect(result?.succeeded, 1);
    expect(processor.callCount, 1);
    expect(processor.limits, [5]);

    final state = container.read(syncQueueControllerProvider);
    expect(state, isA<AsyncData<SyncQueueControllerState>>());
    expect(state.valueOrNull?.isRunning, isFalse);
    expect(state.valueOrNull?.lastTrigger, SyncTrigger.manual);
    expect(state.valueOrNull?.lastResult?.processed, 1);
  });

  test('syncNow ignores concurrent requests', () async {
    final started = Completer<void>();
    final complete = Completer<void>();
    final processor = _FakeSyncQueueProcessor(
      started: started,
      complete: complete,
    );
    final container = createContainer(processor);
    addTearDown(container.dispose);

    final controller = container.read(syncQueueControllerProvider.notifier);

    final first = controller.syncNow(SyncTrigger.appStart);
    await started.future;

    final second = await controller.syncNow(SyncTrigger.appResume);
    expect(second, isNull);
    expect(processor.callCount, 1);
    expect(
      container.read(syncQueueControllerProvider).valueOrNull?.isRunning,
      isTrue,
    );

    complete.complete();
    final firstResult = await first;

    expect(firstResult?.processed, 1);
    expect(processor.callCount, 1);
    expect(
      container.read(syncQueueControllerProvider).valueOrNull?.lastTrigger,
      SyncTrigger.appStart,
    );
  });

  test('syncNow records failures as stable controller state', () async {
    final processor = _FakeSyncQueueProcessor(error: Exception('offline'));
    final container = createContainer(processor);
    addTearDown(container.dispose);

    final controller = container.read(syncQueueControllerProvider.notifier);

    final result = await controller.syncNow(SyncTrigger.networkRestored);

    expect(result, isNull);
    expect(processor.callCount, 1);

    final state = container.read(syncQueueControllerProvider);
    expect(state, isA<AsyncData<SyncQueueControllerState>>());
    expect(state.valueOrNull?.isRunning, isFalse);
    expect(state.valueOrNull?.lastTrigger, SyncTrigger.networkRestored);
    expect(state.valueOrNull?.lastError, contains('offline'));
  });
}
