import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? selectedCurrency,
  List<String>? selectedCurrencies,
  DateTime? currentMonthStart,
}) {
  if (selectedCurrency != null && currentMonthStart != null) {
    return 'wallets:list:v4:$userId:${householdId ?? 'personal'}:${selectedCurrency.trim().toUpperCase()}:${_cacheDate(currentMonthStart)}:${_currencySelectionCacheSegment(selectedCurrencies)}';
  }
  return 'wallets:list:v2:$userId:${householdId ?? 'personal'}';
}

String walletsPageStateCacheKey(WalletsScopeQuery query) {
  return 'wallets:page-state:v3:${query.userId}:${query.householdId ?? 'personal'}:${query.selectedCurrency}:${_cacheDate(query.currentMonthStart)}:${_currencySelectionCacheSegment(query.normalizedSelectedCurrencies)}';
}

List<WalletEntity>? readPersistedWalletsList(
  Ref ref, {
  required String userId,
  required String? householdId,
  String? selectedCurrency,
  List<String>? selectedCurrencies,
  DateTime? currentMonthStart,
}) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return null;
  }
  final raw = prefs.getString(
    walletsListCacheKey(
      userId: userId,
      householdId: householdId,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      currentMonthStart: currentMonthStart,
    ),
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
  String? selectedCurrency,
  List<String>? selectedCurrencies,
  DateTime? currentMonthStart,
  required List<WalletEntity> wallets,
}) {
  final prefs = _readPrefsOrNull(ref);
  if (prefs == null) {
    return Future<void>.value();
  }
  return prefs.setString(
    walletsListCacheKey(
      userId: userId,
      householdId: householdId,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      currentMonthStart: currentMonthStart,
    ),
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
  List<String>? selectedCurrencies,
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
      walletsListCacheKey(
        userId: userId,
        householdId: householdId,
        selectedCurrency: selectedCurrency,
        selectedCurrencies: selectedCurrencies,
        currentMonthStart: currentMonthStart,
      ),
    );
    await prefs.remove(
      walletsPageStateCacheKey(
        WalletsScopeQuery(
          userId: userId,
          householdId: householdId,
          selectedCurrency: selectedCurrency,
          selectedCurrencies: selectedCurrencies,
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

  const listPrefix = 'wallets:list:';
  const pageStatePrefix = 'wallets:page-state:';

  final keysToRemove = prefs
      .getKeys()
      .where(
        (String key) =>
            (key.startsWith(listPrefix) && key.contains(':$userId:')) ||
            (key.startsWith(pageStatePrefix) && key.contains(':$userId:')),
      )
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

String _cacheDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _currencySelectionCacheSegment(List<String>? currencies) {
  final values = (currencies ?? const <String>[])
      .map((currency) => currency.trim().toUpperCase())
      .where((currency) => currency.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return values.isEmpty ? 'default' : values.join(',');
}
