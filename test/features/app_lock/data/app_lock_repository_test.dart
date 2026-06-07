import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/app_lock/data/app_lock_config.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';

void main() {
  group('AppLockRepository', () {
    test('stores and loads config under a per-user key', () async {
      final store = _MemoryAppLockKeyValueStore();
      final repository = AppLockRepository(store: store);
      const config = AppLockConfig(
        userId: 'user-1',
        passcodeHashBase64: 'hash',
        saltBase64: 'salt',
        hashVersion: 1,
        biometricEnabled: true,
        lockTimeout: AppLockTimeout.afterFiveMinutes,
      );

      await repository.saveConfig(config);

      expect(store.values.keys, contains('moneko_app_lock:user-1'));
      expect(await repository.loadConfig('user-1'), isNotNull);
      expect(await repository.loadConfig('user-2'), isNull);
    });

    test('deletes only the requested user config', () async {
      final store = _MemoryAppLockKeyValueStore();
      final repository = AppLockRepository(store: store);

      await repository.saveConfig(
        const AppLockConfig(
          userId: 'user-1',
          passcodeHashBase64: 'hash-1',
          saltBase64: 'salt-1',
          hashVersion: 1,
          biometricEnabled: false,
          lockTimeout: AppLockTimeout.immediately,
        ),
      );
      await repository.saveConfig(
        const AppLockConfig(
          userId: 'user-2',
          passcodeHashBase64: 'hash-2',
          saltBase64: 'salt-2',
          hashVersion: 1,
          biometricEnabled: false,
          lockTimeout: AppLockTimeout.immediately,
        ),
      );

      await repository.deleteConfig('user-1');

      expect(await repository.loadConfig('user-1'), isNull);
      expect(await repository.loadConfig('user-2'), isNotNull);
    });
  });
}

class _MemoryAppLockKeyValueStore implements AppLockKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
