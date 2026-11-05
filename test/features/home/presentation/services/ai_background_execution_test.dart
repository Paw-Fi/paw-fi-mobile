import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/services/ai_background_execution.dart';

class _Bridge extends AiExecutionBridge {
  final events = StreamController<String>.broadcast(sync: true);
  final stops = StreamController<String>.broadcast(sync: true);
  @override
  Stream<String> get stopped => stops.stream;
  final calls = <Map<String, dynamic>>[];
  bool granted = true;
  Completer<bool>? startGate;
  @override
  Stream<String> get expired => events.stream;
  @override
  Future<bool> start(Map<String, dynamic> payload) async {
    calls.add({'method': 'start', ...payload});
    return startGate == null ? granted : await startGate!.future;
  }

  @override
  Future<void> update(Map<String, dynamic> payload) async =>
      calls.add({'method': 'update', ...payload});
  @override
  Future<void> finish(Map<String, dynamic> payload) async =>
      calls.add({'method': 'finish', ...payload});
  @override
  Future<void> dispose() async {
    await events.close();
    await stops.close();
  }
}

const _messages = {
  'title': 'Moneko',
  'analyzing': 'Analyzing',
  'saving': 'Preparing transactions',
  'needsInput': 'Open Moneko to answer',
  'queued': 'Analysis complete; queued to sync',
  'paused': 'Open Moneko to continue',
};

void main() {
  for (final outcome in [
    AiExecutionOutcome.error,
    AiExecutionOutcome.needsInput
  ]) {
    test(
        'restored $outcome is attention UI without a background execution grant',
        () async {
      final bridge = _Bridge();
      final owner = AiBackgroundExecution(bridge);
      final lease = await owner.start('capture',
          messages: _messages, initialOutcome: outcome);
      expect(bridge.calls.single['outcome'], outcome.name);
      expect(lease.canRunInBackground, isFalse);
      await owner.finish(lease, outcome);
      await owner.setPresentationAllowed(false);
      expect(bridge.calls.last['method'], 'update');
      expect(bridge.calls.last['background'], isTrue);
      await owner.dispose();
    });
  }
  test('Stop is terminal, discards deferred UI and ignores stale attempts',
      () async {
    final bridge = _Bridge();
    var reconciled = 0;
    final owner = AiBackgroundExecution(bridge, onStopped: () async {
      reconciled++;
    });
    final first = await owner.start('capture', messages: _messages);
    final next = await owner.start('capture', messages: _messages);
    bridge.stops.add(first.id);
    expect(next.isCancelled, isFalse);
    await owner.setPresentationAllowed(false);
    var presented = false;
    owner.presentWhenAllowed(() => presented = true);
    bridge.stops.add(next.id);
    expect(next.isCancelled, isTrue);
    expect(next.canRunInBackground, isFalse);
    await owner.finish(next, AiExecutionOutcome.queued);
    expect(bridge.calls.last['outcome'], 'cancelled');
    await owner.setPresentationAllowed(true);
    expect(presented, isFalse);
    expect(reconciled, 2);
    await owner.dispose();
  });

  test('capture attempt is persisted before native start is visible', () async {
    final bridge = _Bridge();
    final owner = AiBackgroundExecution(bridge);
    String? persisted;
    final lease = await owner.start('capture',
        userId: 'owner', messages: _messages, beforeStart: (id) async {
      expect(bridge.calls, isEmpty);
      persisted = id;
    });
    expect(lease.id, persisted);
    expect(bridge.calls.single['userId'], 'owner');
    expect(bridge.calls.single['captureId'], 'capture');
    await owner.dispose();
  });
  test(
      'native expiration releases a waiting HTTP analysis without waiting for its response',
      () async {
    final bridge = _Bridge();
    final owner = AiBackgroundExecution(bridge);
    final lease = await owner.start('capture', messages: _messages);
    final response = Completer<String>();
    final waiting = lease.untilInterrupted(response.future);
    final assertion =
        expectLater(waiting, throwsA(isA<AiExecutionInterrupted>()));
    bridge.events.add(lease.id);
    await assertion;
    response.complete('late result');
    await owner.dispose();
  });

  test('completion UI waits for unlock and is discarded on account changes',
      () async {
    final bridge = _Bridge();
    final owner = AiBackgroundExecution(bridge);
    var callbacks = 0;
    await owner.setPresentationAllowed(false);
    owner.presentWhenAllowed(() => callbacks++);
    expect(callbacks, 0);
    await owner.setPresentationAllowed(true);
    expect(callbacks, 1);
    await owner.setPresentationAllowed(false);
    owner.presentWhenAllowed(() => callbacks++);
    await owner.revoke();
    await owner.setPresentationAllowed(true);
    expect(callbacks, 1);
    await owner.dispose();
  });

  test('a native lease permits background work until its exact attempt expires',
      () async {
    final bridge = _Bridge();
    final owner = AiBackgroundExecution(bridge);
    final first = await owner.start('capture', messages: _messages);
    expect(first.canRunInBackground, isTrue);
    bridge.events.add('different-attempt');
    expect(first.canRunInBackground, isTrue);
    bridge.events.add(first.id);
    expect(first.canRunInBackground, isFalse);
    final next = await owner.start('capture', messages: _messages);
    bridge.events.add(first.id);
    expect(next.canRunInBackground, isTrue);
    await owner.finish(first, AiExecutionOutcome.paused);
    expect(next.canRunInBackground, isTrue);
    await owner.dispose();
  });

  test('missing native authority retains foreground-only processing', () async {
    final bridge = _Bridge()..granted = false;
    final owner = AiBackgroundExecution(bridge);
    final lease = await owner.start('capture', messages: _messages);
    expect(lease.canRunInBackground, isFalse);
    await owner.dispose();
  });

  test('clarification ends execution and publishes attention on backgrounding',
      () async {
    final bridge = _Bridge();
    final owner = AiBackgroundExecution(bridge);
    final lease = await owner.start('capture', messages: _messages);
    await owner.finish(lease, AiExecutionOutcome.needsInput);
    expect(lease.canRunInBackground, isFalse);
    await owner.setPresentationAllowed(false);
    expect(bridge.calls.last['background'], isTrue);
    expect(bridge.calls.last['id'], lease.id);
    final next = await owner.start('capture', messages: _messages);
    expect(next.id, isNot(lease.id));
    await owner.dispose();
  });

  test('account changes revoke native execution including a delayed start',
      () async {
    final bridge = _Bridge()..startGate = Completer<bool>();
    final owner = AiBackgroundExecution(bridge);
    final pending = owner.start('capture', messages: _messages);
    await owner.revoke();
    bridge.startGate!.complete(true);
    final lease = await pending;
    expect(lease.canRunInBackground, isFalse);
    expect(
        bridge.calls.where((call) => call['method'] == 'finish'), isNotEmpty);
    await owner.dispose();
  });

  test('queued completion does not claim remote synchronization', () async {
    final bridge = _Bridge();
    final owner = AiBackgroundExecution(bridge);
    final lease = await owner.start('capture', messages: _messages);
    await owner.update(lease, 'saving');
    await owner.setPresentationAllowed(false);
    await owner.finish(lease, AiExecutionOutcome.queued);
    expect(bridge.calls.last['outcome'], 'queued');
    expect((bridge.calls.last['messages'] as Map)['queued'],
        contains('queued to sync'));
    expect(lease.canRunInBackground, isFalse);
    await owner.dispose();
  });
}
