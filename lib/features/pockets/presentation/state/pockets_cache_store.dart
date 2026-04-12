import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

final pocketsPersistedCacheBypassCountProvider = StateProvider<int>((ref) => 0);

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

Map<String, dynamic>? readPersistedPocketsCache(
  Ref ref, {
  required String key,
}) {
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
}) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return Future<void>.value();
  }
  return prefs.setString(key, jsonEncode(payload));
}

Future<void> clearAllPersistedPocketsCachesForUser(
  Ref ref, {
  required String userId,
}) async {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return;
  }

  final prefix = 'pockets:month:v1:$userId:';
  final keysToRemove = prefs
      .getKeys()
      .where((key) => key.startsWith(prefix))
      .toList(growable: false);

  for (final key in keysToRemove) {
    await prefs.remove(key);
  }
}

dynamic _readPrefsOrNull(Ref ref) {
  try {
    return ref.read(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}
