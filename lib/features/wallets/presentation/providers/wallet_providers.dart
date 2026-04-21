import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_debug_tracing.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

final walletScopeHouseholdIdProvider = Provider<String?>((ref) {
  final scope = ref.watch(householdScopeProvider);
  return scope.activeAccountType == ActiveWalletType.personal
      ? null
      : scope.activeAccountHouseholdId;
});

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
      body: {
        if (householdId != null && householdId.trim().isNotEmpty)
          'householdId': householdId,
      },
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
    return optimisticOverrides.values.toList(growable: false);
  }

  final merged = baseWallets
      .map((wallet) => optimisticOverrides[wallet.id] ?? wallet)
      .toList(growable: true);

  final existingIds = merged.map((wallet) => wallet.id).toSet();
  for (final optimistic in optimisticOverrides.values) {
    if (!existingIds.contains(optimistic.id)) {
      merged.add(optimistic);
    }
  }

  return merged;
}

final archivedScopedAccountsProvider =
    FutureProvider<List<WalletEntity>>((ref) async {
  final authHeaders = ref.watch(walletAuthHeadersProvider);
  if (authHeaders == null) {
    return const <WalletEntity>[];
  }

  final householdId = ref.watch(walletScopeHouseholdIdProvider);
  final response = await supabase.functions.invoke(
    'list-wallets',
    headers: authHeaders,
    body: {
      'includeArchived': true,
      if (householdId != null) 'householdId': householdId,
    },
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
    final authHeaders = ref.watch(walletAuthHeadersProvider);
    final bypassPersistedCache =
        ref.watch(walletsPersistedCacheBypassCountProvider) > 0;
    final cacheKey = walletsListCacheKey(
      userId: user.uid,
      householdId: householdId,
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
          ) ??
          const <WalletEntity>[];
    }

    final requestKey = walletsListCacheKey(
      userId: user.uid,
      householdId: householdId,
    );
    final wallets =
        await ref.read(walletsByHouseholdIdProvider(householdId).future);
    final currentKey = walletsListCacheKey(
      userId: ref.read(authProvider).uid,
      householdId: ref.read(walletScopeHouseholdIdProvider),
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
        wallets: wallets,
      ),
    );
    state = AsyncData(wallets);
    return wallets;
  }
}

final effectiveScopeWalletsProvider = Provider<List<WalletEntity>>((ref) {
  final baseAccounts = ref.watch(scopedWalletsProvider).valueOrNull ?? const [];
  final optimisticOverrides =
      ref.watch(optimisticScopedAccountsOverridesProvider);
  return _mergeOptimisticAccounts(baseAccounts, optimisticOverrides);
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

    final isSynced = optimistic.name == serverAccount.name &&
        optimistic.icon == serverAccount.icon &&
        optimistic.color == serverAccount.color &&
        optimistic.openingBalanceCents == serverAccount.openingBalanceCents &&
        optimistic.goalAmountCents == serverAccount.goalAmountCents &&
        optimistic.isDefault == serverAccount.isDefault;

    if (!isSynced) {
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
    bool isDefault = false,
  }) async {
    final householdId = ref.read(walletScopeHouseholdIdProvider);
    final authHeaders = _requireAuthHeaders();
    final response = await supabase.functions.invoke(
      'save-wallet',
      headers: authHeaders,
      body: {
        'name': name,
        'icon': icon,
        'color': color,
        'openingBalanceCents': openingBalanceCents,
        'goalAmountCents': goalAmountCents,
        'isDefault': isDefault,
        if (householdId != null) 'householdId': householdId,
      },
    );
    _throwIfFailed(response.data, 'Failed to create wallet');
    _invalidateAll();
  }

  Future<void> updateAccount({
    required String walletId,
    String? name,
    String? icon,
    String? color,
    int? openingBalanceCents,
    int? goalAmountCents,
    bool includeGoalAmount = false,
    bool? isDefault,
    bool invalidate = true,
  }) async {
    final authHeaders = _requireAuthHeaders();
    debugPrint(
      '[Accounts][Update] start accountId=$walletId name=$name icon=$icon color=$color opening=$openingBalanceCents goal=$goalAmountCents includeGoal=$includeGoalAmount isDefault=$isDefault invalidate=$invalidate',
    );
    final response = await supabase.functions.invoke(
      'update-wallet',
      headers: authHeaders,
      body: {
        'accountId': walletId,
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (openingBalanceCents != null)
          'openingBalanceCents': openingBalanceCents,
        if (includeGoalAmount || goalAmountCents != null)
          'goalAmountCents': goalAmountCents,
        if (isDefault != null) 'isDefault': isDefault,
      },
    );
    _throwIfFailed(response.data, 'Failed to update wallet');
    debugPrint('[Accounts][Update] success accountId=$walletId');
    if (invalidate) {
      _invalidateAll();
    }
  }

  Future<void> archiveAccount(String accountId) async {
    final authHeaders = _requireAuthHeaders();
    final response = await supabase.functions.invoke(
      'archive-wallet',
      headers: authHeaders,
      body: {'accountId': accountId},
    );
    _throwIfFailed(response.data, 'Failed to archive wallet');
    _invalidateAll();
  }

  Future<void> restoreAccount(String accountId) async {
    final authHeaders = _requireAuthHeaders();
    final response = await supabase.functions.invoke(
      'restore-wallet',
      headers: authHeaders,
      body: {'accountId': accountId},
    );
    _throwIfFailed(response.data, 'Failed to restore wallet');
    _invalidateAll();
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
    final response = await supabase.functions.invoke(
      'create-wallet-transfer',
      headers: authHeaders,
      body: {
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amountCents': amountCents,
        'currency': currency,
        'date': formatDateOnlyYmd(date),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    _throwIfFailed(response.data, 'Failed to create transfer');
    _invalidateAll();
  }

  Future<void> updateBalance({
    required String walletId,
    required int targetBalanceCents,
    String? note,
    bool invalidate = true,
  }) async {
    final authHeaders = _requireAuthHeaders();
    debugPrint(
      '[Accounts][Balance] start accountId=$walletId targetBalanceCents=$targetBalanceCents invalidate=$invalidate',
    );
    final response = await supabase.functions.invoke(
      'update-wallet-balance',
      headers: authHeaders,
      body: {
        'accountId': walletId,
        'targetBalanceCents': targetBalanceCents,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    _throwIfFailed(response.data, 'Failed to update account balance');
    debugPrint('[Accounts][Balance] success accountId=$walletId');
    if (invalidate) {
      _invalidateAll();
    }
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
    ref.invalidate(scopedWalletsProvider);
    ref.invalidate(archivedScopedAccountsProvider);
    ref.invalidate(walletsHistoryProvider);
    ref.invalidate(walletsMonthSnapshotProvider);
    ref.invalidate(walletsScopeQueryProvider);
    ref.invalidate(walletsPageStateProvider);
    ref.read(walletsRefreshSignalProvider.notifier).state += 1;
    final userId = ref.read(authProvider).uid;
    if (userId.isNotEmpty) {
      ref.read(walletsListSessionCacheProvider.notifier).state = const {};
      ref.read(walletsPageStateSessionCacheProvider.notifier).state = const {};
      ref.read(walletsPersistedCacheBypassCountProvider.notifier).state++;
      unawaited(
        (() async {
          try {
            await clearAllWalletsCachesForUser(
              ref,
              userId: userId,
            );
          } finally {
            final notifier =
                ref.read(walletsPersistedCacheBypassCountProvider.notifier);
            notifier.state = notifier.state > 0 ? notifier.state - 1 : 0;
          }
        })(),
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
