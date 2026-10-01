import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/in_flight_requests.dart';

void main() {
  test('shares concurrent exact keys without caching a completed result',
      () async {
    final requests = InFlightRequests<(String, int), int>();
    final gate = Completer<int>();
    var calls = 0;
    Future<int> action() {
      calls++;
      return gate.future;
    }

    final first = requests.run(('personal', 1), action);
    final second = requests.run(('personal', 1), action);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    gate.complete(20);
    expect(await first, 20);
    expect(await second, 20);
    expect(await requests.run(('personal', 1), () async => ++calls), 2);
  });

  test('scope and mutation revision changes start independent work', () async {
    final requests = InFlightRequests<(String, int), int>();
    final old = Completer<int>();
    final first = requests.run(('personal', 1), () => old.future);
    expect(await requests.run(('personal', 2), () async => 30), 30);
    expect(await requests.run(('household', 1), () async => 40), 40);
    old.complete(20);
    expect(await first, 20);
  });

  test('a failed shared request is removed so a retry can run', () async {
    final requests = InFlightRequests<String, int>();
    final gate = Completer<int>();
    final first = requests.run('scope', () => gate.future);
    final second = requests.run('scope', () => gate.future);
    final firstFailure = expectLater(first, throwsStateError);
    final secondFailure = expectLater(second, throwsStateError);
    gate.completeError(StateError('offline'));
    await Future.wait([firstFailure, secondFailure]);
    expect(await requests.run('scope', () async => 30), 30);
  });

  test('synchronous errors do not poison the key', () async {
    final requests = InFlightRequests<String, int>();
    await expectLater(
      requests.run('scope', () => throw StateError('sync failure')),
      throwsStateError,
    );
    expect(await requests.run('scope', () async => 30), 30);
  });

  test('registers the future before a synchronous reentrant caller', () async {
    final requests = InFlightRequests<String, int>();
    Future<int>? nested;
    final first = requests.run('scope', () {
      nested = requests.run('scope', () async => 99);
      return Future.value(20);
    });
    expect(identical(first, nested), isTrue);
    expect(await first, 20);
    expect(await nested, 20);
  });
}
