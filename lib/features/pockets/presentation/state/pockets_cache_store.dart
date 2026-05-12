import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

final pocketsPersistedCacheBypassCountProvider = StateProvider<int>((ref) => 0);

const String _pocketsCacheNamespace = 'pockets_month';

String pocketsPersistedCacheKey({
  required String userId,
  required String scope,
  required String? householdId,
  required String periodMonth,
  required String currency,
  required bool includeUpcomingRecurring,
  required bool allowCurrencyFallback,
}) {
  return 'pockets:month:v1:$userId:$scope:${householdId ?? 'personal'}:$periodMonth:$currency:$includeUpcomingRecurring:$allowCurrencyFallback';
}

Future<Map<String, dynamic>?> readPersistedPocketsCache(
  Ref ref, {
  required String key,
}) async {
  try {
    final database = await ref.read(localDatabaseProvider.future);
    final entry = await database.getJsonCache(
      namespace: _pocketsCacheNamespace,
      cacheKey: key,
    );
    if (entry != null) {
      return {
        'cached_at': entry.cachedAt.toIso8601String(),
        ...entry.payload,
      };
    }
  } catch (_) {}

  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return null;
  }
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? resolvePersistedPocketsStatePayload(
  Map<String, dynamic> payload,
) {
  final wrappedState = payload['state'];
  if (wrappedState is Map) {
    return Map<String, dynamic>.from(wrappedState);
  }
  return payload;
}

DateTime? resolvePersistedPocketsCachedAt(Map<String, dynamic> payload) {
  final raw = payload['cached_at'] as String?;
  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

Future<void> persistPocketsCache(
  Ref ref, {
  required String key,
  required Map<String, dynamic> payload,
}) async {
  try {
    final database = await ref.read(localDatabaseProvider.future);
    final cachedAt = resolvePersistedPocketsCachedAt(payload) ?? DateTime.now();
    await database.upsertJsonCache(
      namespace: _pocketsCacheNamespace,
      cacheKey: key,
      payload: payload,
      cachedAt: cachedAt,
    );
    return;
  } catch (_) {}

  final prefs = _readPrefsOrNull(ref);
  await prefs?.setString(key, jsonEncode(payload));
}

Future<void> clearAllPersistedPocketsCachesForUser(
  Ref ref, {
  required String userId,
}) async {
  final prefix = 'pockets:month:v1:$userId:';
  try {
    final database = await ref.read(localDatabaseProvider.future);
    await database.deleteJsonCacheByPrefix(
      namespace: _pocketsCacheNamespace,
      cacheKeyPrefix: prefix,
    );
  } catch (_) {}

  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return;
  }

  final keysToRemove = prefs
      .getKeys()
      .where((String key) => key.startsWith(prefix))
      .toList(growable: false);

  for (final key in keysToRemove) {
    await prefs.remove(key);
  }
}

SharedPreferences? _readPrefsOrNull(Ref ref) {
  try {
    return ref.read(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}
