import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';

final walletsListSessionCacheProvider =
    StateProvider<Map<String, List<WalletEntity>>>((ref) => const {});

final walletsPageStateSessionCacheProvider =
    StateProvider<Map<String, WalletsPageState>>((ref) => const {});

final walletsPersistedCacheBypassCountProvider = StateProvider<int>((ref) => 0);

String walletsListCacheKey({
  required String userId,
  required String? householdId,
}) {
  return 'wallets:list:v2:$userId:${householdId ?? 'personal'}';
}

String walletsPageStateCacheKey(WalletsScopeQuery query) {
  return 'wallets:page-state:v2:${query.userId}:${query.householdId ?? 'personal'}:${query.selectedCurrency}:${_cacheDate(query.currentMonthStart)}';
}

List<WalletEntity>? readPersistedWalletsList(
  Ref ref, {
  required String userId,
  required String? householdId,
}) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return null;
  }
  final raw = prefs.getString(
    walletsListCacheKey(userId: userId, householdId: householdId),
  );
  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((row) => WalletEntity.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  } catch (_) {
    return null;
  }
}

Future<void> persistWalletsList(
  Ref ref, {
  required String userId,
  required String? householdId,
  required List<WalletEntity> wallets,
}) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return Future<void>.value();
  }
  return prefs.setString(
    walletsListCacheKey(userId: userId, householdId: householdId),
    jsonEncode(
        wallets.map((wallet) => wallet.toJson()).toList(growable: false)),
  );
}

WalletsPageState? readPersistedWalletsPageState(
  Ref ref,
  WalletsScopeQuery query,
) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return null;
  }
  final raw = prefs.getString(walletsPageStateCacheKey(query));
  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    return WalletsPageState.fromCacheJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  } catch (_) {
    return null;
  }
}

Future<void> persistWalletsPageState(
  Ref ref,
  WalletsScopeQuery query,
  WalletsPageState state,
) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return Future<void>.value();
  }
  return prefs.setString(
    walletsPageStateCacheKey(query),
    jsonEncode(state.toCacheJson()),
  );
}

Future<void> clearWalletsCaches(
  Ref ref, {
  required String userId,
  required String? householdId,
  String? selectedCurrency,
  DateTime? currentMonthStart,
}) async {
  ref.read(walletsListSessionCacheProvider.notifier).state = const {};
  ref.read(walletsPageStateSessionCacheProvider.notifier).state = const {};

  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return;
  }
  await prefs.remove(
    walletsListCacheKey(userId: userId, householdId: householdId),
  );

  if (selectedCurrency != null && currentMonthStart != null) {
    await prefs.remove(
      walletsPageStateCacheKey(
        WalletsScopeQuery(
          userId: userId,
          householdId: householdId,
          selectedCurrency: selectedCurrency,
          currentMonthStart: currentMonthStart,
        ),
      ),
    );
  }
}

Future<void> clearAllWalletsCachesForUser(
  Ref ref, {
  required String userId,
}) async {
  ref.read(walletsListSessionCacheProvider.notifier).state = const {};
  ref.read(walletsPageStateSessionCacheProvider.notifier).state = const {};

  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return;
  }

  final listPrefix = 'wallets:list:v2:$userId:';
  final pageStatePrefix = 'wallets:page-state:v2:$userId:';

  final keysToRemove = prefs
      .getKeys()
      .where(
        (key) => key.startsWith(listPrefix) || key.startsWith(pageStatePrefix),
      )
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

String _cacheDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
