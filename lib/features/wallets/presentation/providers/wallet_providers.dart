import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_debug_tracing.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

final walletScopeHouseholdIdProvider = Provider<String?>((ref) {
  final scope = ref.watch(householdScopeProvider);
  return scope.activeAccountType == ActiveWalletType.personal
      ? null
      : scope.activeAccountHouseholdId;
});

Map<String, dynamic> _listWalletsFunctionBody({
  required String? householdId,
  required String selectedCurrency,
  List<String>? selectedCurrencies,
  required DateTime currentMonthStart,
  bool includeArchived = false,
}) {
  final normalizedCurrencies = selectedCurrencies == null
      ? null
      : (selectedCurrencies
          .map((currency) => currency.trim().toUpperCase())
          .where((currency) => currency.isNotEmpty)
          .toSet()
          .toList()
        ..sort());
  return {
    if (includeArchived) 'includeArchived': true,
    if (householdId != null && householdId.trim().isNotEmpty)
      'householdId': householdId,
    'currency': selectedCurrency.trim().toUpperCase(),
    if (normalizedCurrencies != null && normalizedCurrencies.isNotEmpty)
      'currencies': normalizedCurrencies,
    'monthStart': _formatListWalletsDate(currentMonthStart),
  };
}

String _formatListWalletsDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

final walletsByHouseholdIdProvider =
    FutureProvider.family<List<WalletEntity>, String?>(
        (ref, householdId) async {
  final trace = WalletsDebugTrace(
    label: 'WalletsByHousehold',
    enabled: ref.read(walletsDebugLoggingEnabledProvider),
    logSink: ref.read(walletsDebugLogSinkProvider),
    contextFields: {
      'household': householdId?.trim().isEmpty ?? true ? '<none>' : householdId,
    },
  );
  final authHeaders = ref.watch(walletAuthHeadersProvider);
  final scopeQuery = ref.watch(walletsScopeQueryProvider);
  if (authHeaders == null) {
    // Avoid caching a transient unauthorized fetch during the post-login
    // handoff before auth state is ready in Riverpod.
    trace.mark(
        'wallets-fetch-skipped', const {'reason': 'missing-auth-headers'});
    return const <WalletEntity>[];
  }

  try {
    trace.mark('wallets-fetch-start');
    final response = await supabase.functions.invoke(
      'list-wallets',
      headers: authHeaders,
      body: _listWalletsFunctionBody(
        householdId: householdId,
        selectedCurrency: scopeQuery.selectedCurrency,
        selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
        currentMonthStart: scopeQuery.currentMonthStart,
      ),
    );

    final payload = response.data as Map<String, dynamic>?;
    if (payload == null || payload['success'] != true) {
      final message = payload?['error']?.toString() ?? 'Failed to load wallets';
      throw Exception(message);
    }

    final data = payload['data'] as List<dynamic>? ?? const [];
    final wallets = data
        .whereType<Map<String, dynamic>>()
        .map(WalletEntity.fromJson)
        .toList(growable: false);
    trace.mark('wallets-fetch-success', {'count': wallets.length});
    return wallets;
  } catch (error) {
    trace.mark('wallets-fetch-exception', {'error': error});
    rethrow;
  }
});

class WalletsCurrencyQuery {
  const WalletsCurrencyQuery({
    required this.householdId,
    required this.currency,
  });

  final String? householdId;
  final String currency;

  String get normalizedCurrency => currency.trim().toUpperCase();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WalletsCurrencyQuery &&
            other.householdId == householdId &&
            other.normalizedCurrency == normalizedCurrency;
  }

  @override
  int get hashCode => Object.hash(householdId, normalizedCurrency);
}

final walletsByCurrencyProvider =
    FutureProvider.family<List<WalletEntity>, WalletsCurrencyQuery>(
  (ref, query) async {
    final authHeaders = ref.watch(walletAuthHeadersProvider);
    if (authHeaders == null || query.normalizedCurrency.isEmpty) {
      return const <WalletEntity>[];
    }

    final scopeQuery = ref.watch(walletsScopeQueryProvider);
    final response = await supabase.functions.invoke(
      'list-wallets',
      headers: authHeaders,
      body: _listWalletsFunctionBody(
        householdId: query.householdId,
        selectedCurrency: query.normalizedCurrency,
        selectedCurrencies: <String>[query.normalizedCurrency],
        currentMonthStart: scopeQuery.currentMonthStart,
      ),
    );

    final payload = response.data as Map<String, dynamic>?;
    if (payload == null || payload['success'] != true) {
      final message = payload?['error']?.toString() ?? 'Failed to load wallets';
      throw Exception(message);
    }

    final data = payload['data'] as List<dynamic>? ?? const [];
    final wallets = data
        .whereType<Map<String, dynamic>>()
        .map(WalletEntity.fromJson)
        .toList(growable: false);
    final optimisticOverrides =
        ref.watch(optimisticScopedAccountsOverridesProvider);
    final scopedCurrencyOverrides = Map<String, WalletEntity>.fromEntries(
      optimisticOverrides.entries.where(
        (entry) =>
            entry.value.householdId == query.householdId &&
            entry.value.currency.trim().toUpperCase() ==
                query.normalizedCurrency,
      ),
    );
    return _mergeOptimisticAccounts(wallets, scopedCurrencyOverrides);
  },
);

final optimisticScopedAccountsOverridesProvider =
    StateProvider<Map<String, WalletEntity>>((ref) => const {});

List<WalletEntity> _mergeOptimisticAccounts(
  List<WalletEntity> baseWallets,
  Map<String, WalletEntity> optimisticOverrides,
) {
  if (optimisticOverrides.isEmpty) {
    return baseWallets;
  }

  if (baseWallets.isEmpty) {
    return _sortWalletsByListOrder(optimisticOverrides.values);
  }

  final merged = baseWallets
      .map((wallet) => optimisticOverrides[wallet.id] ?? wallet)
      .toList(growable: true);

  final existingIds = merged.map((wallet) => wallet.id).toSet();
  final newOptimisticWallets = optimisticOverrides.values
      .where((wallet) => !existingIds.contains(wallet.id))
      .toList(growable: false);
  for (final optimistic in _sortWalletsByListOrder(newOptimisticWallets)) {
    final insertIndex = merged.indexWhere(
      (wallet) => _compareWalletListOrder(optimistic, wallet) < 0,
    );
    if (insertIndex == -1) {
      merged.add(optimistic);
    } else {
      merged.insert(insertIndex, optimistic);
    }
  }

  return merged;
}

List<WalletEntity> _sortWalletsByListOrder(Iterable<WalletEntity> wallets) {
  final sorted = wallets.toList(growable: false);
  sorted.sort(_compareWalletListOrder);
  return sorted;
}

int _compareWalletListOrder(WalletEntity left, WalletEntity right) {
  if (left.isDefault != right.isDefault) {
    return left.isDefault ? -1 : 1;
  }
  if (left.isSystem != right.isSystem) {
    return left.isSystem ? -1 : 1;
  }
  final nameComparison = left.name.compareTo(right.name);
  if (nameComparison != 0) {
    return nameComparison;
  }
  return left.id.compareTo(right.id);
}

void _clearSyncedOptimisticAccounts(
  Ref ref,
  List<WalletEntity> serverWallets,
) {
  final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
  if (overrides.isEmpty || serverWallets.isEmpty) {
    return;
  }

  final serverById = <String, WalletEntity>{
    for (final wallet in serverWallets) wallet.id: wallet,
  };
  final nextOverrides = <String, WalletEntity>{};
  for (final entry in overrides.entries) {
    final serverWallet = serverById[entry.key];
    if (serverWallet == null ||
        !_walletOverrideMatchesServer(entry.value, serverWallet)) {
      nextOverrides[entry.key] = entry.value;
    }
  }

  if (nextOverrides.length == overrides.length) {
    return;
  }
  ref.read(optimisticScopedAccountsOverridesProvider.notifier).state =
      nextOverrides;
}

bool _walletOverrideMatchesServer(
  WalletEntity optimistic,
  WalletEntity server,
) {
  return optimistic.name == server.name &&
      optimistic.icon == server.icon &&
      optimistic.color == server.color &&
      optimistic.currency == server.currency &&
      optimistic.openingBalanceCents == server.openingBalanceCents &&
      optimistic.goalAmountCents == server.goalAmountCents &&
      optimistic.isDefault == server.isDefault &&
      optimistic.isArchived == server.isArchived &&
      optimistic.currentBalanceCents == server.currentBalanceCents;
}

bool _walletMatchesSelectedCurrencies(
  WalletEntity wallet,
  List<String>? selectedCurrencies,
) {
  if (selectedCurrencies == null || selectedCurrencies.isEmpty) {
    return true;
  }
  return selectedCurrencies.contains(wallet.currency.trim().toUpperCase());
}

final archivedScopedAccountsProvider =
    FutureProvider<List<WalletEntity>>((ref) async {
  final authHeaders = ref.watch(walletAuthHeadersProvider);
  if (authHeaders == null) {
    return const <WalletEntity>[];
  }

  final householdId = ref.watch(walletScopeHouseholdIdProvider);
  final scopeQuery = ref.watch(walletsScopeQueryProvider);
  final response = await supabase.functions.invoke(
    'list-wallets',
    headers: authHeaders,
    body: _listWalletsFunctionBody(
      householdId: householdId,
      selectedCurrency: scopeQuery.selectedCurrency,
      selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
      currentMonthStart: scopeQuery.currentMonthStart,
      includeArchived: true,
    ),
  );

  final payload = response.data as Map<String, dynamic>?;
  if (payload == null || payload['success'] != true) {
    final message =
        payload?['error']?.toString() ?? 'Failed to load accwalletsounts';
    throw Exception(message);
  }

  final data = payload['data'] as List<dynamic>? ?? const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(WalletEntity.fromJson)
      .where((wallet) => wallet.isArchived)
      .toList(growable: false);
});

final scopedWalletsProvider =
    AsyncNotifierProvider<ScopedWalletsNotifier, List<WalletEntity>>(
        ScopedWalletsNotifier.new);

class ScopedWalletsNotifier extends AsyncNotifier<List<WalletEntity>> {
  @override
  Future<List<WalletEntity>> build() async {
    final user = ref.watch(authProvider);
    final householdId = ref.watch(walletScopeHouseholdIdProvider);
    final scopeQuery = ref.watch(walletsScopeQueryProvider);
    final authHeaders = ref.watch(walletAuthHeadersProvider);
    final bypassPersistedCache =
        ref.watch(walletsPersistedCacheBypassCountProvider) > 0;
    final cacheKey = walletsListCacheKey(
      userId: user.uid,
      householdId: householdId,
      selectedCurrency: scopeQuery.selectedCurrency,
      selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
      currentMonthStart: scopeQuery.currentMonthStart,
    );
    final trace = WalletsDebugTrace(
      label: 'ScopedWalletsProvider',
      enabled: ref.read(walletsDebugLoggingEnabledProvider),
      logSink: ref.read(walletsDebugLogSinkProvider),
      contextFields: {
        'user': user.uid.isEmpty ? '<empty>' : user.uid,
        'household': householdId ?? '<none>',
      },
    );

    if (user.uid.isEmpty) {
      trace.mark('build-skipped', const {'reason': 'empty-user'});
      return const <WalletEntity>[];
    }

    if (authHeaders == null) {
      trace.mark('build-skipped', const {'reason': 'missing-auth-headers'});
      final cachedSessionWallets =
          ref.read(walletsListSessionCacheProvider)[cacheKey];
      if (cachedSessionWallets != null) {
        trace.mark('session-cache-hit-without-auth-headers',
            {'count': cachedSessionWallets.length});
        return cachedSessionWallets;
      }

      final persistedWallets = readPersistedWalletsList(
        ref,
        userId: user.uid,
        householdId: householdId,
        selectedCurrency: scopeQuery.selectedCurrency,
        selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
        currentMonthStart: scopeQuery.currentMonthStart,
      );
      if (persistedWallets != null) {
        trace.mark('persisted-cache-hit-without-auth-headers',
            {'count': persistedWallets.length});
        ref.read(walletsListSessionCacheProvider.notifier).state = {
          ...ref.read(walletsListSessionCacheProvider),
          cacheKey: persistedWallets,
        };
        return persistedWallets;
      }

      return const <WalletEntity>[];
    }

    final sessionCache = ref.read(walletsListSessionCacheProvider);
    final cachedSessionWallets = sessionCache[cacheKey];
    if (cachedSessionWallets != null) {
      trace.mark('session-cache-hit', {'count': cachedSessionWallets.length});
      return cachedSessionWallets;
    }

    if (!bypassPersistedCache) {
      final persistedWallets = readPersistedWalletsList(
        ref,
        userId: user.uid,
        householdId: householdId,
        selectedCurrency: scopeQuery.selectedCurrency,
        selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
        currentMonthStart: scopeQuery.currentMonthStart,
      );
      if (persistedWallets != null) {
        trace.mark('persisted-cache-hit', {'count': persistedWallets.length});
        Future<void>(() {
          ref.read(walletsListSessionCacheProvider.notifier).state = {
            ...ref.read(walletsListSessionCacheProvider),
            cacheKey: persistedWallets,
          };
        });
        Future<void>(() async {
          try {
            await refreshFromNetwork();
          } catch (_) {}
        });
        return persistedWallets;
      }
    }

    trace.mark('cache-miss');
    return refreshFromNetwork();
  }

  Future<List<WalletEntity>> refreshFromNetwork() async {
    final user = ref.read(authProvider);
    final householdId = ref.read(walletScopeHouseholdIdProvider);
    final scopeQuery = ref.read(walletsScopeQueryProvider);
    final refreshGeneration = ref.read(walletsRefreshSignalProvider);
    if (user.uid.isEmpty) {
      return const <WalletEntity>[];
    }

    final authHeaders = ref.read(walletAuthHeadersProvider);
    if (authHeaders == null) {
      return state.valueOrNull ??
          readPersistedWalletsList(
            ref,
            userId: user.uid,
            householdId: householdId,
            selectedCurrency: scopeQuery.selectedCurrency,
            selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
            currentMonthStart: scopeQuery.currentMonthStart,
          ) ??
          const <WalletEntity>[];
    }

    final requestKey = walletsListCacheKey(
      userId: user.uid,
      householdId: householdId,
      selectedCurrency: scopeQuery.selectedCurrency,
      selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
      currentMonthStart: scopeQuery.currentMonthStart,
    );
    final wallets =
        await ref.read(walletsByHouseholdIdProvider(householdId).future);
    _clearSyncedOptimisticAccounts(ref, wallets);
    final currentKey = walletsListCacheKey(
      userId: ref.read(authProvider).uid,
      householdId: ref.read(walletScopeHouseholdIdProvider),
      selectedCurrency: ref.read(walletsScopeQueryProvider).selectedCurrency,
      selectedCurrencies:
          ref.read(walletsScopeQueryProvider).normalizedSelectedCurrencies,
      currentMonthStart: ref.read(walletsScopeQueryProvider).currentMonthStart,
    );
    if (requestKey != currentKey ||
        refreshGeneration != ref.read(walletsRefreshSignalProvider)) {
      return state.valueOrNull ?? const <WalletEntity>[];
    }

    ref.read(walletsListSessionCacheProvider.notifier).state = {
      ...ref.read(walletsListSessionCacheProvider),
      requestKey: wallets,
    };
    unawaited(
      persistWalletsList(
        ref,
        userId: user.uid,
        householdId: householdId,
        selectedCurrency: scopeQuery.selectedCurrency,
        selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
        currentMonthStart: scopeQuery.currentMonthStart,
        wallets: wallets,
      ),
    );
    state = AsyncData(wallets);
    return wallets;
  }
}

final effectiveScopeWalletsProvider = Provider<List<WalletEntity>>((ref) {
  final baseAccounts = ref.watch(scopedWalletsProvider).valueOrNull ?? const [];
  final scopeHouseholdId = ref.watch(walletScopeHouseholdIdProvider);
  final scopeQuery = ref.watch(walletsScopeQueryProvider);
  final selectedCurrencies = scopeQuery.normalizedSelectedCurrencies;
  final optimisticOverrides =
      ref.watch(optimisticScopedAccountsOverridesProvider);
  final scopedOverrides = Map<String, WalletEntity>.fromEntries(
    optimisticOverrides.entries.where(
      (entry) =>
          entry.value.householdId == scopeHouseholdId &&
          _walletMatchesSelectedCurrencies(
            entry.value,
            selectedCurrencies,
          ),
    ),
  );
  final filteredBaseAccounts = baseAccounts
      .where((wallet) => _walletMatchesSelectedCurrencies(
            wallet,
            selectedCurrencies,
          ))
      .toList(growable: false);
  return _mergeOptimisticAccounts(filteredBaseAccounts, scopedOverrides);
});

final defaultScopedAccountProvider = Provider<WalletEntity?>((ref) {
  final wallets = ref.watch(effectiveScopeWalletsProvider);
  for (final wallet in wallets) {
    if (wallet.isDefault) return wallet;
  }
  return wallets.isNotEmpty ? wallets.first : null;
});

final walletByIdProvider = Provider.family<WalletEntity?, String>((ref, id) {
  final wallets = ref.watch(effectiveScopeWalletsProvider);
  for (final wallet in wallets) {
    if (wallet.id == id) return wallet;
  }
  return null;
});

final serverWalletByIdProvider =
    Provider.family<WalletEntity?, String>((ref, id) {
  final accounts = ref.watch(scopedWalletsProvider).valueOrNull ?? const [];
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
});

class WalletActions {
  const WalletActions(this.ref);

  final Ref ref;

  Map<String, String> _requireAuthHeaders() {
    final authHeaders = ref.read(walletAuthHeadersProvider);
    if (authHeaders == null) {
      throw Exception('Authentication session could not be established');
    }
    return authHeaders;
  }

  void setOptimisticWallet(WalletEntity account) {
    debugPrint(
      '[Accounts][Optimistic] set accountId=${account.id} name=${account.name} color=${account.color} opening=${account.openingBalanceCents}',
    );
    final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
    ref.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      ...overrides,
      account.id: account,
    };
    unawaited(_persistOptimisticWallet(account));
  }

  void clearOptimisticWallet(String accountId) {
    debugPrint('[Accounts][Optimistic] clear accountId=$accountId');
    final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
    if (!overrides.containsKey(accountId)) {
      return;
    }
    final nextOverrides = <String, WalletEntity>{...overrides}
      ..remove(accountId);
    ref.read(optimisticScopedAccountsOverridesProvider.notifier).state =
        nextOverrides;
  }

  void reconcileOptimisticAccountWithServer(WalletEntity serverAccount) {
    final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
    final optimistic = overrides[serverAccount.id];
    if (optimistic == null) {
      return;
    }

    if (!_walletOverrideMatchesServer(optimistic, serverAccount)) {
      return;
    }

    debugPrint(
      '[Accounts][Optimistic] reconcile success accountId=${serverAccount.id}; clearing override',
    );
    clearOptimisticWallet(serverAccount.id);
  }

  void refreshAccountData() {
    _invalidateAll();
  }

  Future<void> createAccount({
    required String name,
    required String icon,
    required String color,
    int openingBalanceCents = 0,
    int? goalAmountCents,
    required String currency,
    bool isDefault = false,
  }) async {
    final householdId = ref.read(walletScopeHouseholdIdProvider);
    final user = ref.read(authProvider);
    final authHeaders = _requireAuthHeaders();
    final optimisticId =
        'optimistic-wallet-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticWallet = WalletEntity(
      id: optimisticId,
      userId: user.uid,
      householdId: householdId,
      name: name,
      icon: icon,
      color: color,
      currency: currency.trim().toUpperCase(),
      openingBalanceCents: openingBalanceCents,
      goalAmountCents: goalAmountCents,
      isDefault: isDefault,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: openingBalanceCents,
    );
    setOptimisticWallet(optimisticWallet);
    final requestBody = {
      'name': name,
      'icon': icon,
      'color': color,
      'currency': currency.trim().toUpperCase(),
      'openingBalanceCents': openingBalanceCents,
      'goalAmountCents': goalAmountCents,
      'isDefault': isDefault,
      if (householdId != null) 'householdId': householdId,
    };
    final localDatabase = await _enqueueWalletMutation(
      entityId: optimisticId,
      functionName: 'save-wallet',
      requestBody: requestBody,
    );

    try {
      final response = await supabase.functions.invoke(
        'save-wallet',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to create wallet');
      await localDatabase.markMutationSynced(_walletMutationId(optimisticId));
      clearOptimisticWallet(optimisticId);

      final payload = response.data;
      final saved = payload is Map<String, dynamic>
          ? payload['data'] ?? payload['wallet'] ?? payload['account']
          : null;
      if (saved is Map<String, dynamic>) {
        final savedWallet = WalletEntity.fromJson(saved);
        final hasCurrentBalance = saved['current_balance_cents'] is num;
        setOptimisticWallet(
          hasCurrentBalance
              ? savedWallet
              : savedWallet.copyWith(
                  currentBalanceCents: savedWallet.openingBalanceCents,
                ),
        );
      }
      _invalidateAll();
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        _invalidateAll();
        return;
      }
      await _cancelWalletMutation(optimisticId, error);
      clearOptimisticWallet(optimisticId);
      rethrow;
    }
  }

  Future<void> updateAccount({
    required String walletId,
    String? name,
    String? icon,
    String? color,
    int? openingBalanceCents,
    int? goalAmountCents,
    String? currency,
    bool includeGoalAmount = false,
    bool? isDefault,
    bool invalidate = true,
  }) async {
    final authHeaders = _requireAuthHeaders();
    final existingWallet =
        ref.read(effectiveScopeWalletsProvider).where((wallet) {
      return wallet.id == walletId;
    }).firstOrNull;
    final requestedCurrency = currency?.trim().toUpperCase();
    if (existingWallet != null &&
        requestedCurrency != null &&
        requestedCurrency != existingWallet.currency.trim().toUpperCase()) {
      throw ArgumentError('Wallet currency cannot be changed after creation');
    }
    if (existingWallet != null) {
      final nextOpeningBalanceCents =
          openingBalanceCents ?? existingWallet.openingBalanceCents;
      final nextCurrentBalanceCents = openingBalanceCents == null
          ? existingWallet.currentBalanceCents
          : retargetWalletBalanceForOpeningChange(
              previousOpeningBalanceCents: existingWallet.openingBalanceCents,
              nextOpeningBalanceCents: openingBalanceCents,
              currentBalanceCents: existingWallet.currentBalanceCents,
            );
      setOptimisticWallet(WalletEntity(
        id: existingWallet.id,
        userId: existingWallet.userId,
        householdId: existingWallet.householdId,
        name: name ?? existingWallet.name,
        icon: icon ?? existingWallet.icon,
        color: color ?? existingWallet.color,
        currency: existingWallet.currency,
        openingBalanceCents: nextOpeningBalanceCents,
        goalAmountCents: includeGoalAmount
            ? goalAmountCents
            : (goalAmountCents ?? existingWallet.goalAmountCents),
        isDefault: isDefault ?? existingWallet.isDefault,
        isSystem: existingWallet.isSystem,
        isArchived: existingWallet.isArchived,
        currentBalanceCents: nextCurrentBalanceCents,
      ));
    }
    debugPrint(
      '[Accounts][Update] start accountId=$walletId name=$name icon=$icon color=$color opening=$openingBalanceCents goal=$goalAmountCents includeGoal=$includeGoalAmount isDefault=$isDefault invalidate=$invalidate',
    );

    final requestBody = {
      'accountId': walletId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (requestedCurrency != null) 'currency': requestedCurrency,
      if (openingBalanceCents != null)
        'openingBalanceCents': openingBalanceCents,
      if (includeGoalAmount || goalAmountCents != null)
        'goalAmountCents': goalAmountCents,
      if (isDefault != null) 'isDefault': isDefault,
    };
    try {
      final localDatabase = await _enqueueWalletMutation(
        entityId: walletId,
        functionName: 'update-wallet',
        requestBody: requestBody,
      );
      final response = await supabase.functions.invoke(
        'update-wallet',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to update wallet');
      await localDatabase.markMutationSynced(_walletMutationId(walletId));
      debugPrint('[Accounts][Update] success accountId=$walletId');
      if (invalidate) {
        _invalidateAll();
      }
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        if (invalidate) _invalidateAll();
        return;
      }
      await _cancelWalletMutation(walletId, error);
      clearOptimisticWallet(walletId);
      rethrow;
    }
  }

  Future<void> archiveAccount(String accountId) async {
    final authHeaders = _requireAuthHeaders();
    final existingWallet = ref.read(walletByIdProvider(accountId));
    if (existingWallet != null) {
      setOptimisticWallet(existingWallet.copyWith(isArchived: true));
    }
    try {
      final requestBody = {'accountId': accountId};
      final localDatabase = await _enqueueWalletMutation(
        entityId: accountId,
        functionName: 'archive-wallet',
        requestBody: requestBody,
      );
      final response = await supabase.functions.invoke(
        'archive-wallet',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to archive wallet');
      await localDatabase.markMutationSynced(_walletMutationId(accountId));
      _invalidateAll();
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        _invalidateAll();
        return;
      }
      await _cancelWalletMutation(accountId, error);
      clearOptimisticWallet(accountId);
      rethrow;
    }
  }

  Future<void> restoreAccount(String accountId) async {
    final authHeaders = _requireAuthHeaders();
    final existingWallet = ref
        .read(archivedScopedAccountsProvider)
        .valueOrNull
        ?.firstWhereOrNull((wallet) => wallet.id == accountId);
    if (existingWallet != null) {
      setOptimisticWallet(existingWallet.copyWith(isArchived: false));
    }
    try {
      final requestBody = {'accountId': accountId};
      final localDatabase = await _enqueueWalletMutation(
        entityId: accountId,
        functionName: 'restore-wallet',
        requestBody: requestBody,
      );
      final response = await supabase.functions.invoke(
        'restore-wallet',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to restore wallet');
      await localDatabase.markMutationSynced(_walletMutationId(accountId));
      _invalidateAll();
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        _invalidateAll();
        return;
      }
      await _cancelWalletMutation(accountId, error);
      clearOptimisticWallet(accountId);
      rethrow;
    }
  }

  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    required String currency,
    required DateTime date,
    String? note,
  }) async {
    final authHeaders = _requireAuthHeaders();
    final wallets = ref.read(effectiveScopeWalletsProvider);
    final fromWallet =
        wallets.firstWhereOrNull((wallet) => wallet.id == fromAccountId);
    final toWallet =
        wallets.firstWhereOrNull((wallet) => wallet.id == toAccountId);
    if (fromWallet != null) {
      setOptimisticWallet(fromWallet.copyWith(
        currentBalanceCents: fromWallet.currentBalanceCents - amountCents,
      ));
    }
    if (toWallet != null) {
      setOptimisticWallet(toWallet.copyWith(
        currentBalanceCents: toWallet.currentBalanceCents + amountCents,
      ));
    }
    final transferMutationEntityId =
        '$fromAccountId:$toAccountId:${DateTime.now().microsecondsSinceEpoch}';
    try {
      final requestBody = {
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amountCents': amountCents,
        'currency': currency,
        'date': formatDateOnlyYmd(date),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };
      final localDatabase = await _enqueueWalletMutation(
        entityId: transferMutationEntityId,
        functionName: 'create-wallet-transfer',
        requestBody: requestBody,
      );
      final response = await supabase.functions.invoke(
        'create-wallet-transfer',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to create transfer');
      await localDatabase.markMutationSynced(
        _walletMutationId(transferMutationEntityId),
      );
      _invalidateAll();
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        _invalidateAll();
        return;
      }
      await _cancelWalletMutation(transferMutationEntityId, error);
      clearOptimisticWallet(fromAccountId);
      clearOptimisticWallet(toAccountId);
      rethrow;
    }
  }

  Future<void> updateTransfer({
    required WalletTransfer existingTransfer,
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    required String currency,
    required DateTime date,
    String? note,
  }) async {
    final authHeaders = _requireAuthHeaders();
    final mutationEntityId =
        'update-transfer:${existingTransfer.id}:${DateTime.now().microsecondsSinceEpoch}';
    _applyTransferBalanceDeltas([
      MapEntry(existingTransfer.fromAccountId, existingTransfer.amountCents),
      MapEntry(existingTransfer.toAccountId, -existingTransfer.amountCents),
      MapEntry(fromAccountId, -amountCents),
      MapEntry(toAccountId, amountCents),
    ]);
    try {
      final requestBody = {
        'transferId': existingTransfer.id,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amountCents': amountCents,
        'currency': currency,
        'date': formatDateOnlyYmd(date),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };
      final localDatabase = await _enqueueWalletMutation(
        entityId: mutationEntityId,
        functionName: 'update-wallet-transfer',
        requestBody: requestBody,
        affectedWalletIds: {
          existingTransfer.fromAccountId,
          existingTransfer.toAccountId,
          fromAccountId,
          toAccountId,
        },
      );
      final response = await supabase.functions.invoke(
        'update-wallet-transfer',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to update transfer');
      await localDatabase
          .markMutationSynced(_walletMutationId(mutationEntityId));
      _invalidateAll();
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        _invalidateAll();
        return;
      }
      await _cancelWalletMutation(mutationEntityId, error);
      clearOptimisticWallet(existingTransfer.fromAccountId);
      clearOptimisticWallet(existingTransfer.toAccountId);
      clearOptimisticWallet(fromAccountId);
      clearOptimisticWallet(toAccountId);
      rethrow;
    }
  }

  Future<void> deleteTransfer(WalletTransfer transfer) async {
    final authHeaders = _requireAuthHeaders();
    final mutationEntityId =
        'delete-transfer:${transfer.id}:${DateTime.now().microsecondsSinceEpoch}';
    _applyTransferBalanceDeltas([
      MapEntry(transfer.fromAccountId, transfer.amountCents),
      MapEntry(transfer.toAccountId, -transfer.amountCents),
    ]);
    try {
      final requestBody = {'transferId': transfer.id};
      final localDatabase = await _enqueueWalletMutation(
        entityId: mutationEntityId,
        functionName: 'delete-wallet-transfer',
        requestBody: requestBody,
        affectedWalletIds: {
          transfer.fromAccountId,
          transfer.toAccountId,
        },
      );
      final response = await supabase.functions.invoke(
        'delete-wallet-transfer',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to delete transfer');
      await localDatabase
          .markMutationSynced(_walletMutationId(mutationEntityId));
      _invalidateAll();
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        _invalidateAll();
        return;
      }
      await _cancelWalletMutation(mutationEntityId, error);
      clearOptimisticWallet(transfer.fromAccountId);
      clearOptimisticWallet(transfer.toAccountId);
      rethrow;
    }
  }

  void _applyTransferBalanceDeltas(Iterable<MapEntry<String, int>> deltas) {
    final deltasByWalletId = <String, int>{};
    for (final delta in deltas) {
      deltasByWalletId[delta.key] =
          (deltasByWalletId[delta.key] ?? 0) + delta.value;
    }
    final wallets = ref.read(effectiveScopeWalletsProvider);
    for (final entry in deltasByWalletId.entries) {
      if (entry.value == 0) {
        continue;
      }
      final wallet =
          wallets.firstWhereOrNull((wallet) => wallet.id == entry.key);
      if (wallet == null) {
        continue;
      }
      setOptimisticWallet(wallet.copyWith(
        currentBalanceCents: wallet.currentBalanceCents + entry.value,
      ));
    }
  }

  Future<void> updateBalance({
    required String walletId,
    required int targetBalanceCents,
    String? note,
    bool invalidate = true,
  }) async {
    final authHeaders = _requireAuthHeaders();
    final existingWallet =
        ref.read(effectiveScopeWalletsProvider).where((wallet) {
      return wallet.id == walletId;
    }).firstOrNull;
    if (existingWallet != null) {
      setOptimisticWallet(WalletEntity(
        id: existingWallet.id,
        userId: existingWallet.userId,
        householdId: existingWallet.householdId,
        name: existingWallet.name,
        icon: existingWallet.icon,
        color: existingWallet.color,
        currency: existingWallet.currency,
        openingBalanceCents: existingWallet.openingBalanceCents,
        goalAmountCents: existingWallet.goalAmountCents,
        isDefault: existingWallet.isDefault,
        isSystem: existingWallet.isSystem,
        isArchived: existingWallet.isArchived,
        currentBalanceCents: targetBalanceCents,
      ));
    }
    debugPrint(
      '[Accounts][Balance] start accountId=$walletId targetBalanceCents=$targetBalanceCents invalidate=$invalidate',
    );

    try {
      final requestBody = {
        'accountId': walletId,
        'targetBalanceCents': targetBalanceCents,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };
      final localDatabase = await _enqueueWalletMutation(
        entityId: walletId,
        functionName: 'update-wallet-balance',
        requestBody: requestBody,
      );
      final response = await supabase.functions.invoke(
        'update-wallet-balance',
        headers: authHeaders,
        body: requestBody,
      );
      _throwIfFailed(response.data, 'Failed to update account balance');
      await localDatabase.markMutationSynced(_walletMutationId(walletId));
      debugPrint('[Accounts][Balance] success accountId=$walletId');
      if (invalidate) {
        _invalidateAll();
      }
    } catch (error) {
      if (_shouldKeepQueuedLocalMutation(error)) {
        if (invalidate) _invalidateAll();
        return;
      }
      await _cancelWalletMutation(walletId, error);
      clearOptimisticWallet(walletId);
      rethrow;
    }
  }

  Future<void> _persistOptimisticWallet(WalletEntity account) async {
    final user = ref.read(authProvider);
    if (user.uid.isEmpty) return;
    final householdId = account.householdId;
    final scopeQuery = ref.read(walletsScopeQueryProvider);
    final cacheKey = walletsListCacheKey(
      userId: user.uid,
      householdId: householdId,
      selectedCurrency: scopeQuery.selectedCurrency,
      selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
      currentMonthStart: scopeQuery.currentMonthStart,
    );
    final current = ref.read(walletsListSessionCacheProvider)[cacheKey] ??
        readPersistedWalletsList(
          ref,
          userId: user.uid,
          householdId: householdId,
          selectedCurrency: scopeQuery.selectedCurrency,
          selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
          currentMonthStart: scopeQuery.currentMonthStart,
        ) ??
        ref.read(scopedWalletsProvider).valueOrNull ??
        const <WalletEntity>[];
    final next = _mergeOptimisticAccounts(current, {account.id: account});
    ref.read(walletsListSessionCacheProvider.notifier).state = {
      ...ref.read(walletsListSessionCacheProvider),
      cacheKey: next,
    };
    await persistWalletsList(
      ref,
      userId: user.uid,
      householdId: householdId,
      selectedCurrency: scopeQuery.selectedCurrency,
      selectedCurrencies: scopeQuery.normalizedSelectedCurrencies,
      currentMonthStart: scopeQuery.currentMonthStart,
      wallets: next,
    );
  }

  Future<MonekoDatabase> _enqueueWalletMutation({
    required String entityId,
    required String functionName,
    required Map<String, dynamic> requestBody,
    Set<String>? affectedWalletIds,
  }) async {
    final database = await ref.read(localDatabaseProvider.future);
    await database.enqueueMutation(
      clientMutationId: _walletMutationId(entityId),
      entityType: 'wallet',
      entityId: entityId,
      operation: 'invoke_function',
      payload: {
        'functionName': functionName,
        'requestBody': requestBody,
        if (affectedWalletIds != null)
          'affectedWalletIds': affectedWalletIds
              .where((id) => id.trim().isNotEmpty)
              .toSet()
              .toList(growable: false),
      },
    );
    return database;
  }

  Future<void> _cancelWalletMutation(String entityId, Object error) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.markMutationCancelled(
        clientMutationId: _walletMutationId(entityId),
        error: error,
      );
    } catch (cancelError) {
      debugPrint('[Accounts][Outbox] failed to cancel mutation: $cancelError');
    }
    await _clearWalletCachesForCurrentUser();
  }

  Future<void> _clearWalletCachesForCurrentUser() async {
    final userId = ref.read(authProvider).uid;
    if (userId.isEmpty) return;
    await clearAllWalletsCachesForUser(ref, userId: userId);
  }

  String _walletMutationId(String entityId) {
    final normalized = entityId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return 'mobile:wallet_$normalized';
  }

  void _throwIfFailed(dynamic data, String fallback) {
    if (data is Map<String, dynamic> && data['success'] == true) {
      return;
    }
    if (data is Map<String, dynamic>) {
      final message = (data['error'] ?? data['message'])?.toString().trim();
      throw {
        'error': (message == null || message.isEmpty) ? fallback : message,
        if (data['code'] != null) 'code': data['code'].toString(),
        if (data['status'] is int) 'status': data['status'] as int,
        if (data['details'] != null) 'details': data['details'],
        if (data['hint'] != null) 'hint': data['hint'],
      };
    }

    throw Exception(fallback);
  }

  void _invalidateAll() {
    final overridesCountBefore =
        ref.read(optimisticScopedAccountsOverridesProvider).length;
    debugPrint(
      '[Accounts][Invalidate] start optimisticOverridesBefore=$overridesCountBefore',
    );
    ref.invalidate(walletsByHouseholdIdProvider);
    ref.invalidate(walletsByCurrencyProvider);
    ref.invalidate(scopedWalletsProvider);
    ref.invalidate(archivedScopedAccountsProvider);
    ref.invalidate(walletsHistoryProvider);
    ref.invalidate(walletsMonthSnapshotProvider);
    ref.invalidate(walletsScopeQueryProvider);
    ref.invalidate(walletsPageStateProvider);
    ref.read(walletsRefreshSignalProvider.notifier).state += 1;
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
    final userId = ref.read(authProvider).uid;
    if (userId.isNotEmpty) {
      ref.read(walletsListSessionCacheProvider.notifier).state = const {};
      ref.read(walletsPageStateSessionCacheProvider.notifier).state = const {};
      ref.read(walletsPersistedCacheBypassCountProvider.notifier).state++;
      unawaited(
        Future<void>.microtask(() {
          final notifier =
              ref.read(walletsPersistedCacheBypassCountProvider.notifier);
          notifier.state = notifier.state > 0 ? notifier.state - 1 : 0;
        }),
      );
    }
    if (userId.isNotEmpty) {
      debugPrint(
          '[Accounts][Invalidate] trigger analytics reload userId=$userId');
      unawaited(
        ref.read(analyticsProvider.notifier).loadData(
              userId,
              forceReload: true,
            ),
      );
    }
    ref.invalidate(householdExpensesProvider);
    ref.invalidate(recurringTransactionsProvider);
    debugPrint('[Accounts][Invalidate] done');
  }
}

final walletActionsProvider = Provider<WalletActions>((ref) {
  return WalletActions(ref);
});

bool _shouldKeepQueuedLocalMutation(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('network') ||
      message.contains('socket') ||
      message.contains('failed host lookup') ||
      message.contains('connection') ||
      message.contains('timed out') ||
      message.contains('timeout') ||
      message.contains('status: 502') ||
      message.contains('status: 503') ||
      message.contains('status: 504') ||
      message.contains('service is temporarily unavailable') ||
      message.contains('supabase_edge_runtime_error');
}
