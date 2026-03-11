import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/app/locale_provider.dart';

final preferredLanguageSyncServiceProvider =
    Provider<PreferredLanguageSyncService>((ref) {
  return const PreferredLanguageSyncService();
});

class PreferredLanguageSyncService {
  const PreferredLanguageSyncService();

  static const _lastSyncedPrefix = 'preferred_language_synced';

  Future<void> syncForUser({
    required String userId,
    Locale? locale,
    bool force = false,
  }) async {
    if (userId.trim().isEmpty) return;

    final effectiveLocale = locale ?? await resolveEffectiveAppLocale();
    final language = preferredLanguageCodeFromLocale(effectiveLocale);
    if (language == null || language.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
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

  Future<void> clearCachedSync(String userId) async {
    if (userId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_lastSyncedPrefix:$userId');
  }

  Future<void> syncForUserSafely({
    required String userId,
    Locale? locale,
    bool force = false,
  }) async {
    try {
      await syncForUser(userId: userId, locale: locale, force: force);
    } catch (error) {
      debugPrint('Preferred language sync failed: $error');
    }
  }
}
