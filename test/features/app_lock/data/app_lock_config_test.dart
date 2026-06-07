import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/app_lock/data/app_lock_config.dart';

void main() {
  group('AppLockConfig', () {
    test('round-trips secure storage json', () {
      final config = AppLockConfig(
        userId: 'user-1',
        passcodeHashBase64: 'hash',
        saltBase64: 'salt',
        hashVersion: 1,
        biometricEnabled: true,
        lockTimeout: AppLockTimeout.afterOneMinute,
        failedAttempts: 2,
        lockoutUntil: DateTime.utc(2026, 6, 7, 12, 30),
      );

      final decoded = AppLockConfig.fromJson(config.toJson());

      expect(decoded.userId, 'user-1');
      expect(decoded.passcodeHashBase64, 'hash');
      expect(decoded.saltBase64, 'salt');
      expect(decoded.hashVersion, 1);
      expect(decoded.biometricEnabled, isTrue);
      expect(decoded.lockTimeout, AppLockTimeout.afterOneMinute);
      expect(decoded.failedAttempts, 2);
      expect(decoded.lockoutUntil, DateTime.utc(2026, 6, 7, 12, 30));
    });

    test('reports active lockout only while lockoutUntil is in the future', () {
      final config = AppLockConfig(
        userId: 'user-1',
        passcodeHashBase64: 'hash',
        saltBase64: 'salt',
        hashVersion: 1,
        biometricEnabled: false,
        lockTimeout: AppLockTimeout.immediately,
        failedAttempts: 5,
        lockoutUntil: DateTime.utc(2026, 6, 7, 12, 30),
      );

      expect(
        config.isLockedOut(DateTime.utc(2026, 6, 7, 12, 29)),
        isTrue,
      );
      expect(
        config.isLockedOut(DateTime.utc(2026, 6, 7, 12, 31)),
        isFalse,
      );
    });
  });
}
