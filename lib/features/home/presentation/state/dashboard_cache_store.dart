import 'dart:async';
import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';

final dashboardPersistedCacheBypassCountProvider =
    StateProvider<int>((ref) => 0);

final _dashboardSessionCache = <String, ({DateTime cachedAt, Object value})>{};

String dashboardCalendarCacheKey({
  required String userId,
  required String? householdId,
  required String? currency,
  required String? start,
  required String? end,
}) {
  return 'dashboard:calendar:v1:$userId:${householdId ?? 'personal'}:${currency ?? '<none>'}:${start ?? '<none>'}:${end ?? '<none>'}';
}

String dashboardRecentCacheKey({
  required String userId,
  required String? householdId,
  required String? currency,
  required int limit,
}) {
  return 'dashboard:recent:v1:$userId:${householdId ?? 'personal'}:${currency ?? '<none>'}:$limit';
}

String dashboardBudgetsCacheKey({
  required String contactId,
}) {
  return 'dashboard:budgets:v1:$contactId';
}

({DateTime cachedAt, T value})? readDashboardSessionCache<T>(String key) {
  final cached = _dashboardSessionCache[key];
  if (cached == null) {
    return null;
  }
  final value = cached.value;
  if (value is! T) {
    return null;
  }
  return (cachedAt: cached.cachedAt, value: value as T);
}

void writeDashboardSessionCache<T>(String key, T value) {
  _dashboardSessionCache[key] =
      (cachedAt: DateTime.now(), value: value as Object);
}

void clearDashboardSessionCache() {
  _dashboardSessionCache.clear();
}

Map<String, dynamic>? readDashboardPersistedCache(Ref ref, String key) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) return null;
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) return null;

  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

Future<void> writeDashboardPersistedCache(
  Ref ref,
  String key,
  Map<String, dynamic> payload,
) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) return Future<void>.value();
  return prefs.setString(key, jsonEncode(payload));
}

DateTime? readDashboardCachedAt(Map<String, dynamic> payload) {
  final raw = payload['cached_at'] as String?;
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? readDashboardStatePayload(Map<String, dynamic> payload) {
  final state = payload['state'];
  if (state is Map) {
    return Map<String, dynamic>.from(state);
  }
  return payload;
}

Future<void> clearAllDashboardPersistedCachesForUser(
  Ref ref, {
  required String userId,
}) async {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) return;

  final prefixes = [
    'dashboard:calendar:v1:$userId:',
    'dashboard:recent:v1:$userId:',
  ];
  final keys = prefs
      .getKeys()
      .where((key) => prefixes.any((prefix) => key.startsWith(prefix)))
      .toList(growable: false);

  for (final key in keys) {
    await prefs.remove(key);
  }
}

Future<void> clearDashboardBudgetsPersistedCache(
  Ref ref, {
  required String contactId,
}) async {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) return;
  await prefs.remove(dashboardBudgetsCacheKey(contactId: contactId));
}

Duration dashboardTransactionsCacheTtl(DateTime? startDate, DateTime? endDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (startDate == null || endDate == null) {
    return const Duration(minutes: 2);
  }

  if (!endDate.isBefore(today)) {
    return const Duration(minutes: 5);
  }

  return const Duration(minutes: 30);
}

const Duration dashboardBudgetsCacheTtl = Duration(minutes: 30);
const Duration dashboardRecentTransactionsCacheTtl = Duration(minutes: 5);

final dashboardCacheInvalidationProvider = Provider<void>((ref) {
  ref.listen<int>(dashboardRefreshSignalProvider, (previous, next) {
    if (previous == null || previous == next) return;
    final userId = ref.read(authProvider).uid;
    clearDashboardSessionCache();
    ref.read(dashboardPersistedCacheBypassCountProvider.notifier).state++;
    unawaited(() async {
      try {
        if (userId.isNotEmpty) {
          await clearAllDashboardPersistedCachesForUser(ref, userId: userId);
        }
      } finally {
        final notifier =
            ref.read(dashboardPersistedCacheBypassCountProvider.notifier);
        notifier.state = notifier.state > 0 ? notifier.state - 1 : 0;
      }
    }());
  });

  ref.listen(authProvider.select((user) => user.uid), (previous, next) {
    if (previous == null || previous == next) return;
    clearDashboardSessionCache();
    if (previous.isNotEmpty) {
      unawaited(clearAllDashboardPersistedCachesForUser(ref, userId: previous));
    }
  });
});

dynamic _readPrefsOrNull(Ref ref) {
  try {
    return ref.read(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}
