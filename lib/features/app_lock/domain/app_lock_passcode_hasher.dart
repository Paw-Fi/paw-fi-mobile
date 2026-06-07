import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class InvalidPasscodeLengthException implements Exception {
  const InvalidPasscodeLengthException();
}

class AppLockPasscodeHash {
  const AppLockPasscodeHash({
    required this.version,
    required this.saltBase64,
    required this.hashBase64,
  });

  final int version;
  final String saltBase64;
  final String hashBase64;
}

class AppLockPasscodeHasher {
  AppLockPasscodeHasher({
    List<int> Function()? saltBytesFactory,
    Pbkdf2? algorithm,
  })  : _saltBytesFactory = saltBytesFactory ?? _generateSaltBytes,
        _algorithm = algorithm ??
            Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: 120000,
              bits: 256,
            );

  static const int currentVersion = 1;
  static const int requiredPasscodeLength = 6;

  final List<int> Function() _saltBytesFactory;
  final Pbkdf2 _algorithm;

  Future<AppLockPasscodeHash> hashPasscode(String passcode) async {
    _validatePasscode(passcode);
    final salt = _saltBytesFactory();
    final hash = await _deriveHash(passcode: passcode, salt: salt);
    return AppLockPasscodeHash(
      version: currentVersion,
      saltBase64: base64Encode(salt),
      hashBase64: base64Encode(hash),
    );
  }

  Future<bool> verifyPasscode(
    String passcode,
    AppLockPasscodeHash storedHash,
  ) async {
    _validatePasscode(passcode);
    if (storedHash.version != currentVersion) {
      return false;
    }

    final salt = base64Decode(storedHash.saltBase64);
    final expected = base64Decode(storedHash.hashBase64);
    final actual = await _deriveHash(passcode: passcode, salt: salt);
    return _constantTimeEquals(actual, expected);
  }

  Future<List<int>> _deriveHash({
    required String passcode,
    required List<int> salt,
  }) async {
    final secretKey = await _algorithm.deriveKeyFromPassword(
      password: passcode,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  static List<int> _generateSaltBytes() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  static void _validatePasscode(String passcode) {
    final isValidLength = passcode.length == requiredPasscodeLength;
    final isNumeric = RegExp(r'^\d+$').hasMatch(passcode);
    if (!isValidLength || !isNumeric) {
      throw const InvalidPasscodeLengthException();
    }
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final maxLength = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLength; i++) {
      final aByte = i < a.length ? a[i] : 0;
      final bByte = i < b.length ? b[i] : 0;
      diff |= aByte ^ bByte;
    }
    return diff == 0;
  }
}
