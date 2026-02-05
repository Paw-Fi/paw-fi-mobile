import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/app/startup_guard.dart';

void main() {
  test('runStartupStep returns action result when successful', () async {
    final result = await runStartupStep(
      label: 'success',
      timeout: const Duration(milliseconds: 50),
      action: () async => 'ok',
    );

    expect(result, 'ok');
  });

  test('runStartupStep uses fallback on timeout', () async {
    final completer = Completer<String>();

    final result = await runStartupStep(
      label: 'timeout',
      timeout: const Duration(milliseconds: 10),
      action: () => completer.future,
      fallback: () async => 'fallback',
    );

    expect(result, 'fallback');
  });

  test('runStartupStep rethrows when no fallback provided', () async {
    await expectLater(
      () => runStartupStep(
        label: 'no-fallback',
        timeout: const Duration(milliseconds: 10),
        action: () => Future<String>.error(TimeoutException('timeout')),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
