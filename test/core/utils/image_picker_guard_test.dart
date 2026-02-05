import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';

void main() {
  test('runWithImagePickerLock returns null when already in progress',
      () async {
    final completer = Completer<String?>();

    final first = runWithImagePickerLock(() => completer.future);
    final second = await runWithImagePickerLock(() async => 'second');

    expect(second, isNull);

    completer.complete('first');
    expect(await first, 'first');
  });
}
