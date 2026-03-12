import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';

final preferredLanguageSyncServiceProvider =
    Provider<PreferredLanguageSyncService>((ref) {
  return const PreferredLanguageSyncService();
});

class PreferredLanguageSyncService {
  const PreferredLanguageSyncService();

  static const _lastSyncedPrefix = 'preferred_language_synced';
  static const _timezoneCheckedPrefix = 'preferred_timezone_checked';
  static const _platformCheckedPrefix = 'preferred_platform_checked';

  Future<void> syncForUser({
    required String userId,
    Locale? locale,
    bool force = false,
  }) async {
    if (userId.trim().isEmpty) return;

    final effectiveLocale = locale ?? await resolveEffectiveAppLocale();
    final language = preferredLanguageCodeFromLocale(effectiveLocale);

    final prefs = await SharedPreferences.getInstance();
    Object? languageError;
    StackTrace? languageStackTrace;

    if (language != null && language.isNotEmpty) {
      try {
        await _syncPreferredLanguage(
          userId: userId,
          language: language,
          force: force,
          prefs: prefs,
        );
      } catch (error, stackTrace) {
        languageError = error;
        languageStackTrace = stackTrace;
      }
    }

    await _syncMissingTimezoneAndPlatform(userId: userId, prefs: prefs);

    if (languageError != null && languageStackTrace != null) {
      Error.throwWithStackTrace(languageError, languageStackTrace);
    }
  }

  Future<void> _syncPreferredLanguage({
    required String userId,
    required String language,
    required bool force,
    required SharedPreferences prefs,
  }) async {
    final cacheKey = '$_lastSyncedPrefix:$userId';
    final lastSyncedLanguage = prefs.getString(cacheKey);

    if (!force && lastSyncedLanguage == language) {
      return;
    }

    final response = await Supabase.instance.client.functions.invoke(
      'update-preferred-language',
      body: {
        'language': language,
      },
    );

    if (response.status >= 400) {
      throw Exception('Language sync failed (${response.status})');
    }

    final data = response.data;
    final ok = data is Map<String, dynamic>
        ? data['ok'] == true || data['success'] == true
        : false;
    if (!ok) {
      throw Exception('Failed to sync preferred language');
    }

    await prefs.setString(cacheKey, language);
  }

  Future<void> _syncMissingTimezoneAndPlatform({
    required String userId,
    required SharedPreferences prefs,
  }) async {
    final timezoneCacheKey = '$_timezoneCheckedPrefix:$userId';
    final platformCacheKey = '$_platformCheckedPrefix:$userId';
    final hasCheckedTimezone = prefs.getBool(timezoneCacheKey) ?? false;
    final hasCheckedPlatform = prefs.getBool(platformCacheKey) ?? false;

    if (hasCheckedTimezone && hasCheckedPlatform) {
      return;
    }

    final contact = await _fetchLatestContact(userId);

    if (!hasCheckedTimezone) {
      await _syncMissingTimezone(
        userId: userId,
        currentTimezone: _readNonEmptyString(contact?['preferred_timezone']),
        cacheKey: timezoneCacheKey,
        prefs: prefs,
      );
    }

    if (!hasCheckedPlatform) {
      await _syncMissingPlatform(
        userId: userId,
        currentPlatform: _readNonEmptyString(contact?['platform']),
        cacheKey: platformCacheKey,
        prefs: prefs,
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestContact(String userId) async {
    final response = await Supabase.instance.client
        .from('user_contacts')
        .select('preferred_timezone,platform,updated_at,created_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1);

    final contacts = (response as List).cast<Map<String, dynamic>>();
    return contacts.isEmpty ? null : contacts.first;
  }

  Future<void> _syncMissingTimezone({
    required String userId,
    required String? currentTimezone,
    required String cacheKey,
    required SharedPreferences prefs,
  }) async {
    if (currentTimezone != null) {
      await prefs.setBool(cacheKey, true);
      return;
    }

    final timezone = await resolveCanonicalDeviceTimezone();
    final response = await Supabase.instance.client.functions.invoke(
      'update-preferred-timezone',
      body: {
        'userId': userId,
        'timezone': timezone,
      },
    );

    _ensureSuccessfulFunctionResponse(
      response,
      errorMessage: 'Failed to sync preferred timezone',
    );
    await prefs.setBool(cacheKey, true);
  }

  Future<void> _syncMissingPlatform({
    required String userId,
    required String? currentPlatform,
    required String cacheKey,
    required SharedPreferences prefs,
  }) async {
    if (currentPlatform != null) {
      await prefs.setBool(cacheKey, true);
      return;
    }

    final platform = _resolvePreferredPlatform();
    if (platform == null) {
      await prefs.setBool(cacheKey, true);
      return;
    }

    final response = await Supabase.instance.client.functions.invoke(
      'update-preferred-platform',
      body: {
        'userId': userId,
        'platform': platform,
      },
    );

    _ensureSuccessfulFunctionResponse(
      response,
      errorMessage: 'Failed to sync preferred platform',
    );
    await prefs.setBool(cacheKey, true);
  }

  String? _resolvePreferredPlatform() {
    if (kIsWeb) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'IOS',
      TargetPlatform.android => 'Android',
      _ => null,
    };
  }

  String? _readNonEmptyString(Object? value) {
    final trimmed = value?.toString().trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _ensureSuccessfulFunctionResponse(
    FunctionResponse response, {
    required String errorMessage,
  }) {
    if (response.status >= 400) {
      throw Exception('$errorMessage (${response.status})');
    }

    final data = response.data;
    final ok = data is Map<String, dynamic>
        ? data['ok'] == true || data['success'] == true
        : false;
    if (!ok) {
      throw Exception(errorMessage);
    }
  }

  Future<void> clearCachedSync(String userId) async {
    if (userId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_lastSyncedPrefix:$userId');
    await prefs.remove('$_timezoneCheckedPrefix:$userId');
    await prefs.remove('$_platformCheckedPrefix:$userId');
  }

  Future<void> syncForUserSafely({
    required String userId,
    Locale? locale,
    bool force = false,
  }) async {
    try {
      await syncForUser(userId: userId, locale: locale, force: force);
    } catch (error) {
      debugPrint('Preferred preference sync failed: $error');
    }
  }
}
