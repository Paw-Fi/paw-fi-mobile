import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Manages caching of app initialization data for instant startup
///
/// Implements cache-first loading strategy:
/// 1. Show cached data immediately (instant perceived performance)
/// 2. Fetch fresh data in background
/// 3. Update UI when fresh data arrives
///
/// Cache validity: 24 hours
/// Cache invalidation: On logout, app version change, or manual clear
class InitCacheManager {
  static const String _cacheKey = 'app_init_cache_v2';
  static const String _timestampKey = 'app_init_cache_timestamp_v2';
  static const String _versionKey = 'app_init_cache_version';
  static const Duration _cacheValidity = Duration(hours: 24);
  static const Duration _staleCacheMaxAgeDefault = Duration(days: 14);

  final SharedPreferences _prefs;

  InitCacheManager(this._prefs);

  /// Save initialization data to cache
  ///
  /// Stores:
  /// - The init data JSON
  /// - Timestamp for expiry checking
  /// - App version for invalidation on updates
  Future<void> save(Map<String, dynamic> data, String appVersion) async {
    try {
      await Future.wait([
        _prefs.setString(_cacheKey, jsonEncode(data)),
        _prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch),
        _prefs.setString(_versionKey, appVersion),
      ]);
    } catch (e) {}
  }

  /// Load cached initialization data
  ///
  /// Returns null if:
  /// - Cache doesn't exist
  /// - Cache is expired (> 24 hours old)
  /// - Cache is for different app version
  /// - Cache data is corrupted
  Map<String, dynamic>? load(String currentAppVersion) {
    try {
      // Check version first - invalidate if app was updated
      final cachedVersion = _prefs.getString(_versionKey);
      if (cachedVersion != currentAppVersion) {
        return null;
      }

      // Check timestamp - invalidate if expired
      final timestamp = _prefs.getInt(_timestampKey);
      if (timestamp == null) {
        return null;
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;

      if (cacheAge > _cacheValidity.inMilliseconds) {
        return null;
      }

      // Load and parse cached data
      final cached = _prefs.getString(_cacheKey);
      if (cached == null) {
        return null;
      }

      final data = jsonDecode(cached) as Map<String, dynamic>;

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Load cached initialization data with a best-effort strategy.
  ///
  /// Unlike [load], this does NOT invalidate the cache purely because the app
  /// version changed. It still enforces expiry and JSON integrity.
  ///
  /// This is useful for reducing cold-start failures immediately after an app
  /// update when the init payload schema is unchanged.
  Map<String, dynamic>? loadBestEffort(String currentAppVersion) {
    try {
      // Check timestamp - invalidate if expired
      final timestamp = _prefs.getInt(_timestampKey);
      if (timestamp == null) {
        return null;
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;

      if (cacheAge > _cacheValidity.inMilliseconds) {
        return null;
      }

      final cached = _prefs.getString(_cacheKey);
      if (cached == null) {
        return null;
      }

      final data = jsonDecode(cached) as Map<String, dynamic>;

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Load cached initialization data even if it is stale.
  ///
  /// This is a last-resort fallback for users with unreliable connectivity.
  /// It still validates JSON integrity, but relaxes both version matching and
  /// the 24h freshness requirement.
  Map<String, dynamic>? loadStaleBestEffort(
    String currentAppVersion, {
    Duration maxAge = _staleCacheMaxAgeDefault,
  }) {
    try {
      final timestamp = _prefs.getInt(_timestampKey);
      if (timestamp == null) {
        return null;
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;

      if (cacheAge > maxAge.inMilliseconds) {
        return null;
      }

      final cached = _prefs.getString(_cacheKey);
      if (cached == null) {
        return null;
      }

      final data = jsonDecode(cached) as Map<String, dynamic>;

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached data
  ///
  /// Called on:
  /// - User logout
  /// - Manual cache clear
  /// - Cache corruption detection
  Future<void> clear() async {
    try {
      await Future.wait([
        _prefs.remove(_cacheKey),
        _prefs.remove(_timestampKey),
        _prefs.remove(_versionKey),
      ]);
    } catch (e) {}
  }

  /// Check if cache exists and is valid
  ///
  /// Returns true if:
  /// - Cache exists
  /// - Cache is not expired
  /// - Cache is for current app version
  bool isValid(String currentAppVersion) {
    final cachedVersion = _prefs.getString(_versionKey);
    if (cachedVersion != currentAppVersion) {
      return false;
    }

    final timestamp = _prefs.getInt(_timestampKey);
    if (timestamp == null) {
      return false;
    }

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    return cacheAge <= _cacheValidity.inMilliseconds;
  }

  /// Get cache age in hours
  /// Returns null if cache doesn't exist
  double? getCacheAge() {
    final timestamp = _prefs.getInt(_timestampKey);
    if (timestamp == null) return null;

    final ageMs = DateTime.now().millisecondsSinceEpoch - timestamp;
    return ageMs / 1000 / 3600;
  }

  /// Get cache metadata
  Map<String, dynamic> getMetadata() {
    final timestamp = _prefs.getInt(_timestampKey);
    final version = _prefs.getString(_versionKey);
    final exists = _prefs.getString(_cacheKey) != null;

    return {
      'exists': exists,
      'version': version,
      'timestamp': timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()
          : null,
      'age_hours': getCacheAge(),
      'is_valid': exists &&
          version != null &&
          getCacheAge() != null &&
          getCacheAge()! <= _cacheValidity.inHours,
    };
  }
}

/// Provider for cache manager instance
/// Requires SharedPreferences to be initialized first
class InitCacheManagerProvider {
  static InitCacheManager? _instance;

  static Future<InitCacheManager> getInstance() async {
    if (_instance != null) return _instance!;

    final prefs = await SharedPreferences.getInstance();
    _instance = InitCacheManager(prefs);
    return _instance!;
  }

  static void reset() {
    _instance = null;
  }
}
