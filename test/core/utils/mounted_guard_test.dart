import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/mounted_guard.dart';

void main() {
  test('runIfMounted returns result when still mounted', () async {
    final result = await runIfMounted(
      isMounted: () => true,
      action: () async => 'ok',
    );

    expect(result, 'ok');
  });

  test('runIfMounted returns null when unmounted after await', () async {
    var mounted = true;
    final completer = Completer<String>();

    final future = runIfMounted(
      isMounted: () => mounted,
      action: () => completer.future,
    );

    mounted = false;
    completer.complete('value');

    expect(await future, isNull);
  });
}
