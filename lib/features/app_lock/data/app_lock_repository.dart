import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moneko/features/app_lock/data/app_lock_config.dart';

abstract class AppLockKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureAppLockStore implements AppLockKeyValueStore {
  FlutterSecureAppLockStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}

class AppLockRepository {
  const AppLockRepository({required AppLockKeyValueStore store})
      : _store = store;

  final AppLockKeyValueStore _store;

  Future<AppLockConfig?> loadConfig(String userId) async {
    final raw = await _store.read(_keyForUser(userId));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return AppLockConfig.fromJson(decoded);
  }

  Future<void> saveConfig(AppLockConfig config) {
    return _store.write(
        _keyForUser(config.userId), jsonEncode(config.toJson()));
  }

  Future<void> deleteConfig(String userId) {
    return _store.delete(_keyForUser(userId));
  }

  static String _keyForUser(String userId) => 'moneko_app_lock:$userId';
}
