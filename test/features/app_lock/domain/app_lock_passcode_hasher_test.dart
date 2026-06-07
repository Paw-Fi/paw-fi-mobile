import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';

void main() {
  group('AppLockPasscodeHasher', () {
    test('creates a salted hash without storing the plaintext passcode',
        () async {
      final hasher = AppLockPasscodeHasher(
        saltBytesFactory: () => List<int>.filled(16, 7),
      );

      final result = await hasher.hashPasscode('123456');

      expect(result.version, AppLockPasscodeHasher.currentVersion);
      expect(base64Decode(result.saltBase64), List<int>.filled(16, 7));
      expect(result.hashBase64, isNot(contains('123456')));
      expect(result.hashBase64, isNotEmpty);
    });

    test('verifies the original passcode and rejects a different passcode',
        () async {
      final hasher = AppLockPasscodeHasher(
        saltBytesFactory: () => List<int>.filled(16, 3),
      );
      final result = await hasher.hashPasscode('481516');

      expect(await hasher.verifyPasscode('481516', result), isTrue);
      expect(await hasher.verifyPasscode('481515', result), isFalse);
    });

    test('rejects invalid passcode lengths', () async {
      final hasher = AppLockPasscodeHasher();

      expect(
        () => hasher.hashPasscode('12345'),
        throwsA(isA<InvalidPasscodeLengthException>()),
      );
      expect(
        () => hasher.hashPasscode('1234567'),
        throwsA(isA<InvalidPasscodeLengthException>()),
      );
    });
  });
}
