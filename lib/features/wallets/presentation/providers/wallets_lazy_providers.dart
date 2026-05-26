import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart'
    show supabaseClientProvider;
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart'
    show PocketsScopeType, loadScopedRecurringTransactions;
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_debug_tracing.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transaction_binding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final walletsRefreshSignalProvider = StateProvider<int>((ref) => 0);

class _WalletsPageStateCacheGeneration {
  const _WalletsPageStateCacheGeneration({
    required this.wallets,
  });

  final int wallets;

  bool get isInitial => wallets == 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _WalletsPageStateCacheGeneration && other.wallets == wallets;
  }

  @override
  int get hashCode => wallets.hashCode;
}

final _walletsPageStateSessionCacheGenerationsProvider =
    StateProvider<Map<String, _WalletsPageStateCacheGeneration>>(
  (ref) => const {},
);

final _walletsPageStateBaseSessionCacheProvider =
    StateProvider<Map<String, WalletsPageState>>((ref) => const {});

_WalletsPageStateCacheGeneration _readWalletsPageStateCacheGeneration(Ref ref) {
  return _WalletsPageStateCacheGeneration(
    wallets: ref.read(walletsRefreshSignalProvider),
  );
}

final walletsScopeQueryProvider = Provider<WalletsScopeQuery>((ref) {
  final auth = ref.watch(authProvider);
  final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
  final selectedCurrencies = ref.watch(
    homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
  );
  final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
  final householdScope = ref.watch(householdScopeProvider);
  final effectiveNowForUser =
      effectiveNow(preferredTimezone: preferredTimezone);

  return WalletsScopeQuery(
    userId: auth.uid,
    householdId: _resolveWalletsScopeHouseholdId(householdScope),
    selectedCurrency: selectedCurrencyCode,
    selectedCurrencies: selectedCurrencies,
    currentMonthStart:
        DateTime(effectiveNowForUser.year, effectiveNowForUser.month),
  );
});

abstract class WalletsDataService {
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query);
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(WalletsMonthQuery query);
}

abstract class WalletsRpcRunner {
  Future<dynamic> run(
    String rpcName, {
    required Map<String, dynamic> params,
  });
}

abstract class WalletsLegacyDataLoader {
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query);
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(WalletsMonthQuery query);
}

class SupabaseWalletsRpcRunner implements WalletsRpcRunner {
  const SupabaseWalletsRpcRunner(this._client);

  final SupabaseClient _client;

  @override
  Future<dynamic> run(
    String rpcName, {
    required Map<String, dynamic> params,
  }) {
    return _client.rpc(rpcName, params: params);
  }
}

class LocalWalletsLegacyDataLoader implements WalletsLegacyDataLoader {
  LocalWalletsLegacyDataLoader(this.ref);

  final Ref ref;

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    final now = _walletProjectionNow(ref);
    final endInclusive = DateTime(now.year, now.month, now.day);
    final rates = await _walletCurrencyRates(ref);
    final recurringAwareData = await _loadWalletRecurringAwareData(
      ref,
      query,
      endInclusive: endInclusive,
    );
    final availableMonths = buildWalletAvailableMonths(
      now: now,
      transactions: recurringAwareData.transactions,
    );
    final netWorthSeries = availableMonths.reversed.map((monthStart) {
      final snapshot = buildWalletSnapshot(
        wallets: recurringAwareData.wallets,
        transactions: recurringAwareData.transactions,
        endExclusive: _walletSnapshotEndExclusive(
          monthStart: monthStart,
          now: now,
        ),
        targetCurrency: query.selectedCurrency,
        rates: rates,
      );
      return WalletNetWorthPoint(
        monthStart: monthStart,
        netWorthCents: snapshot.netWorthCents,
      );
    }).toList(growable: false);

    return WalletsHistorySummary(
      availableMonths: availableMonths,
      netWorthSeries: netWorthSeries,
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    final now = _walletProjectionNow(ref);
    final endExclusive = _walletSnapshotEndExclusive(
      monthStart: query.monthStart,
      now: now,
    );
    final rates = await _walletCurrencyRates(ref);
    final recurringAwareData = await _loadWalletRecurringAwareData(
      ref,
      query.scope,
      endInclusive: endExclusive.subtract(const Duration(days: 1)),
    );
    final snapshot = buildWalletSnapshot(
      wallets: recurringAwareData.wallets,
      transactions: recurringAwareData.transactions,
      endExclusive: endExclusive,
      targetCurrency: query.scope.selectedCurrency,
      rates: rates,
    );

    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive: endExclusive,
      incomeTotalCents: snapshot.totalIncomeCents,
      spentTotalCents: snapshot.totalSpentCents,
      netWorthCents: snapshot.netWorthCents,
      walletBalances: snapshot.walletBalances,
    );
  }
}

class SupabaseWalletsDataService implements WalletsDataService {
  SupabaseWalletsDataService(this.ref);

  final Ref ref;

  WalletsLegacyDataLoader get _legacyLoader =>
      ref.read(walletsLegacyDataLoaderProvider);

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsHistoryRpc',
      contextFields: _walletsScopeDebugFields(query),
    );
    trace.mark('history-rpc-skipped', const {
      'reason': 'account-currency-local-snapshot',
    });
    return _legacyLoader.fetchHistory(query);
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsMonthSnapshotRpc',
      contextFields: _walletsMonthDebugFields(query),
    );
    trace.mark('month-snapshot-rpc-skipped', const {
      'reason': 'account-currency-local-snapshot',
    });
    return _legacyLoader.fetchMonthSnapshot(query);
  }
}

final walletsLegacyDataLoaderProvider =
    Provider<WalletsLegacyDataLoader>((ref) {
  return LocalWalletsLegacyDataLoader(ref);
});

final walletsRpcRunnerProvider = Provider<WalletsRpcRunner>((ref) {
  return SupabaseWalletsRpcRunner(ref.watch(supabaseClientProvider));
});

final walletsDataServiceProvider = Provider<WalletsDataService>((ref) {
  return SupabaseWalletsDataService(ref);
});

final _walletsInMemoryOptimisticTransactionsProvider =
    Provider.family<List<ExpenseEntry>, WalletsScopeQuery>((ref, query) {
  final householdId = query.householdId?.trim();
  final optimisticTransactions = householdId == null || householdId.isEmpty
      ? ref.watch(
          analyticsProvider.select(
            (data) => data.expenses
                .where(_isWalletInMemoryOptimisticTransaction)
                .toList(growable: false),
          ),
        )
      : ref.watch(
          householdOptimisticExpensesProvider.select(
            (state) => (state[householdId] ?? const <ExpenseEntry>[])
                .where(_isWalletInMemoryOptimisticTransaction)
                .toList(growable: false),
          ),
        );
  if (optimisticTransactions.isEmpty) {
    return const <ExpenseEntry>[];
  }

  return filterWalletTransactions(
    allExpenses: optimisticTransactions,
    scope: ref.watch(householdScopeProvider),
    selectedCurrency: query.selectedCurrency,
    selectedCurrencies: query.normalizedSelectedCurrencies,
  );
});

final _walletsTransactionCacheInvalidationProvider = Provider<void>((ref) {
  ref.watch(dashboardRefreshSignalProvider);
  ref.watch(transactionsFeedRefreshSignalProvider);
});

final walletsHistoryProvider =
    FutureProvider.family<WalletsHistorySummary, WalletsScopeQuery>(
  (ref, query) async {
    ref.watch(_walletsTransactionCacheInvalidationProvider);
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(transactionsFeedRefreshSignalProvider);
    final bypassPersistedCache =
        ref.watch(walletsPageStatePersistedCacheBypassProvider) > 0;
    final authHeaders = ref.watch(walletAuthHeadersProvider);
    if (query.userId.trim().isEmpty || authHeaders == null) {
      return WalletsHistorySummary(
        availableMonths: [query.currentMonthStart],
        netWorthSeries: [
          WalletNetWorthPoint(
            monthStart: query.currentMonthStart,
            netWorthCents: 0,
          ),
        ],
      );
    }

    final service = ref.watch(walletsDataServiceProvider);
    try {
      return await service.fetchHistory(query);
    } catch (_) {
      if (bypassPersistedCache) {
        rethrow;
      }
      final cached = readPersistedWalletsPageState(ref, query);
      final history = cached?.history;
      if (history != null) {
        return _overlayPendingLocalWalletHistory(ref, query, history);
      }
      rethrow;
    }
  },
);

final walletsMonthSnapshotProvider =
    FutureProvider.autoDispose.family<WalletsMonthSnapshot, WalletsMonthQuery>(
  (ref, query) async {
    ref.watch(_walletsTransactionCacheInvalidationProvider);
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(transactionsFeedRefreshSignalProvider);
    final bypassPersistedCache =
        ref.watch(walletsPageStatePersistedCacheBypassProvider) > 0;
    final authHeaders = ref.watch(walletAuthHeadersProvider);
    if (query.scope.userId.trim().isEmpty || authHeaders == null) {
      return WalletsMonthSnapshot(
        monthStart: query.monthStart,
        monthEndExclusive: DateTime(
          query.monthStart.year,
          query.monthStart.month + 1,
          1,
        ),
        incomeTotalCents: 0,
        spentTotalCents: 0,
        netWorthCents: 0,
        walletBalances: const <String, int>{},
      );
    }

    final service = ref.watch(walletsDataServiceProvider);
    try {
      return await service.fetchMonthSnapshot(query);
    } catch (_) {
      if (bypassPersistedCache) {
        rethrow;
      }
      final cached = readPersistedWalletsPageState(ref, query.scope);
      final snapshot = cached
          ?.cachedSnapshotsByMonth[normalizeWalletMonthStart(query.monthStart)];
      if (snapshot != null) {
        return _overlayPendingLocalWalletMonthSnapshot(ref, query, snapshot);
      }
      rethrow;
    }
  },
);

final walletsPageStateProvider = AsyncNotifierProvider.family<
    WalletsPageStateNotifier, WalletsPageState, WalletsScopeQuery>(
  WalletsPageStateNotifier.new,
);

class WalletsPageStateNotifier
    extends FamilyAsyncNotifier<WalletsPageState, WalletsScopeQuery> {
  late WalletsScopeQuery _query;
  bool _scheduledLocalDatabaseReadyRefresh = false;
  bool _isDisposed = false;
  bool _hasDisposeListener = false;

  static const _initialVisibleMonthCount = 3;
  static const _appendMonthBatchSize = 3;

  WalletsDataService get _service => ref.read(walletsDataServiceProvider);
  bool get _isOffline =>
      ref.read(networkReachabilityProvider).valueOrNull == false;

  @override
  Future<WalletsPageState> build(WalletsScopeQuery arg) async {
    _query = arg;
    _ensureLifecycleTracking();
    ref.watch(_walletsTransactionCacheInvalidationProvider);
    _listenToInMemoryOptimisticTransactions(arg);
    _scheduleLocalDatabaseReadyRefresh();
    final cacheGeneration = _WalletsPageStateCacheGeneration(
      wallets: ref.watch(walletsRefreshSignalProvider),
    );
    final bypassPersistedCache =
        ref.watch(walletsPageStatePersistedCacheBypassProvider) > 0;
    final shouldScheduleBackgroundRefresh =
        ref.read(dashboardRefreshSignalProvider) == 0 &&
            ref.read(transactionsFeedRefreshSignalProvider) == 0;
    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsPageStateBuild',
      contextFields: _walletsScopeDebugFields(_query),
    );
    try {
      trace.mark('build-start', {
        'bypassPersistedCache': bypassPersistedCache,
      });
      final sessionCache = ref.read(walletsPageStateSessionCacheProvider);
      final cacheKey = walletsPageStateCacheKey(_query);
      final sessionState = sessionCache[cacheKey];
      final sessionGeneration =
          ref.read(_walletsPageStateSessionCacheGenerationsProvider)[cacheKey];
      if (sessionState != null &&
          (sessionGeneration == cacheGeneration ||
              (sessionGeneration == null && cacheGeneration.isInitial))) {
        trace.mark('session-cache-hit', {
          'visibleMonths': sessionState.visibleMonths.length,
          'snapshotCount': sessionState.cachedSnapshotsByMonth.length,
        });
        final overlaidState =
            await _overlayPendingLocalWalletPageState(sessionState);
        if (!_isOffline && shouldScheduleBackgroundRefresh) {
          _scheduleBackgroundRefresh();
        }
        return overlaidState;
      } else if (sessionState != null) {
        trace.mark('session-cache-stale', {
          'visibleMonths': sessionState.visibleMonths.length,
          'snapshotCount': sessionState.cachedSnapshotsByMonth.length,
        });
      }

      final cachedState = await _readPersistedCachedPageState(
        bypassPersistedCache: bypassPersistedCache,
      );
      if (cachedState != null) {
        trace.mark('cache-hit', {
          'visibleMonths': cachedState.visibleMonths.length,
          'snapshotCount': cachedState.cachedSnapshotsByMonth.length,
          'bypassPersistedCache': bypassPersistedCache,
        });
        final overlaidState =
            await _overlayPendingLocalWalletPageState(cachedState);
        if (!_isOffline && shouldScheduleBackgroundRefresh) {
          _scheduleBackgroundRefresh();
        }
        return overlaidState;
      }

      if (_isOffline) {
        trace.mark('offline-cache-miss');
        return _overlayPendingLocalWalletPageState(_emptyPageState());
      }

      trace.mark('cache-miss');
      return _loadInitialState(trace: trace);
    } catch (error) {
      trace.mark('build-error', {'error': error});
      final cachedState = await _readPersistedCachedPageState(
        bypassPersistedCache: bypassPersistedCache,
      );
      if (cachedState != null) {
        return _overlayPendingLocalWalletPageState(cachedState);
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final basePrevious =
        previous == null ? null : (_readSessionCachedPageState() ?? previous);
    final walletsRefreshGeneration = ref.read(walletsRefreshSignalProvider);
    final dashboardRefreshGeneration = ref.read(dashboardRefreshSignalProvider);
    final transactionsRefreshGeneration =
        ref.read(transactionsFeedRefreshSignalProvider);
    final bypassPersistedCache =
        ref.read(walletsPageStatePersistedCacheBypassProvider) > 0;
    if (_isOffline) {
      if (previous != null) {
        state = AsyncData(previous.copyWith(isRefreshing: false));
      } else {
        state = AsyncData(await _overlayPendingLocalWalletPageState(
          await _readPersistedCachedPageState(
                bypassPersistedCache: bypassPersistedCache,
              ) ??
              _emptyPageState(),
        ));
      }
      return;
    }
    if (previous == null) {
      final cachedState = await _readPersistedCachedPageState(
        bypassPersistedCache: bypassPersistedCache,
      );
      if (cachedState != null) {
        state = AsyncData(
          await _overlayPendingLocalWalletPageState(cachedState),
        );
        return refresh();
      }
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => build(_query));
      return;
    }

    final previousBase = basePrevious ?? previous;
    final optimisticPrevious =
        await _overlayPendingLocalWalletPageState(previousBase);
    state = AsyncData(optimisticPrevious.copyWith(isRefreshing: true));

    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsPageRefresh',
      contextFields: _walletsScopeDebugFields(_query),
    );

    try {
      trace.mark('refresh-start');
      final selectedMonth =
          normalizeWalletMonthStart(previousBase.selectedMonthStart);
      final results = await Future.wait<dynamic>([
        _service.fetchHistory(_query),
        _service.fetchMonthSnapshot(
          WalletsMonthQuery(scope: _query, monthStart: selectedMonth),
        ),
      ]);
      if (walletsRefreshGeneration != ref.read(walletsRefreshSignalProvider) ||
          dashboardRefreshGeneration !=
              ref.read(dashboardRefreshSignalProvider) ||
          transactionsRefreshGeneration !=
              ref.read(transactionsFeedRefreshSignalProvider)) {
        final latest = state.valueOrNull;
        if (latest != null) {
          state = AsyncData(latest.copyWith(isRefreshing: false));
        }
        return;
      }
      final history = results[0] as WalletsHistorySummary;
      final refreshedSnapshot = results[1] as WalletsMonthSnapshot;

      final refreshedState = previousBase.copyWith(
        history: history,
        cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
          ...previousBase.cachedSnapshotsByMonth,
          selectedMonth: refreshedSnapshot,
        },
        monthErrorsByMonth: <DateTime, Object>{
          ...previousBase.monthErrorsByMonth,
        }..remove(selectedMonth),
        loadingMonths: <DateTime>{
          ...previousBase.loadingMonths,
        }..remove(selectedMonth),
        lastResolvedSelectedMonthStart: selectedMonth,
        isRefreshing: false,
      );
      final overlaidRefreshedState =
          await _overlayPendingLocalWalletPageState(refreshedState);
      state = AsyncData(overlaidRefreshedState);
      _storePageState(refreshedState);
      trace.mark('refresh-success', {
        'selectedMonth': selectedMonth,
        'visibleMonths': overlaidRefreshedState.visibleMonths.length,
      });

      final monthsToWarm = overlaidRefreshedState.visibleMonths
          .where((month) => month != selectedMonth)
          .toList(growable: false);
      unawaited(_prefetchMonths(monthsToWarm));
    } catch (error) {
      trace.mark('refresh-error', {'error': error});
      state = AsyncData(optimisticPrevious.copyWith(isRefreshing: false));
    }
  }

  Future<void> selectMonth(DateTime monthStart) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final normalizedMonth = normalizeWalletMonthStart(monthStart);
    var nextVisibleMonths = current.visibleMonths;
    final shouldAppendOlderMonths = current.visibleMonths.isNotEmpty &&
        normalizedMonth == current.visibleMonths.last;
    final appendedMonths = shouldAppendOlderMonths
        ? appendOlderWalletMonthBatch(
            visibleMonths: current.visibleMonths,
            batchSize: _appendMonthBatchSize,
          )
        : const <DateTime>[];

    if (appendedMonths.isNotEmpty) {
      nextVisibleMonths = <DateTime>[
        ...current.visibleMonths,
        ...appendedMonths
      ];
    }

    if (current.cachedSnapshotsByMonth.containsKey(normalizedMonth)) {
      state = AsyncData(current.copyWith(
        visibleMonths: nextVisibleMonths,
        selectedMonthStart: normalizedMonth,
        lastResolvedSelectedMonthStart: normalizedMonth,
        monthErrorsByMonth: <DateTime, Object>{
          ...current.monthErrorsByMonth,
        }..remove(normalizedMonth),
      ));
      _storePageState(state.valueOrNull ?? current);
      if (appendedMonths.isNotEmpty) {
        unawaited(_prefetchMonths(appendedMonths));
      }
      return;
    }

    state = AsyncData(current.copyWith(
      visibleMonths: nextVisibleMonths,
      selectedMonthStart: normalizedMonth,
      loadingMonths: <DateTime>{...current.loadingMonths, normalizedMonth},
      monthErrorsByMonth: <DateTime, Object>{
        ...current.monthErrorsByMonth,
      }..remove(normalizedMonth),
    ));
    _storePageState(state.valueOrNull ?? current);

    if (appendedMonths.isNotEmpty) {
      unawaited(_prefetchMonths(
          appendedMonths.where((month) => month != normalizedMonth)));
    }

    unawaited(_resolveSelectedMonth(normalizedMonth));
  }

  Future<WalletsPageState> _loadInitialState({
    required WalletsDebugTrace trace,
  }) async {
    final refreshGeneration = ref.read(walletsRefreshSignalProvider);
    final selectedMonth = normalizeWalletMonthStart(_query.currentMonthStart);
    final visibleMonths = buildWalletMonthWindow(
      anchorMonth: _query.currentMonthStart,
      count: _initialVisibleMonthCount,
    );
    final results = await Future.wait<dynamic>([
      _service.fetchHistory(_query),
      _service.fetchMonthSnapshot(
        WalletsMonthQuery(scope: _query, monthStart: selectedMonth),
      ),
    ]);
    if (refreshGeneration != ref.read(walletsRefreshSignalProvider)) {
      return state.valueOrNull ??
          WalletsPageState(
            history: const WalletsHistorySummary(
              availableMonths: <DateTime>[],
              netWorthSeries: <WalletNetWorthPoint>[],
            ),
            visibleMonths: visibleMonths,
            selectedMonthStart: selectedMonth,
            cachedSnapshotsByMonth: const <DateTime, WalletsMonthSnapshot>{},
            loadingMonths: const <DateTime>{},
            monthErrorsByMonth: const <DateTime, Object>{},
            lastResolvedSelectedMonthStart: selectedMonth,
          );
    }
    final history = results[0] as WalletsHistorySummary;
    final selectedSnapshot = results[1] as WalletsMonthSnapshot;

    trace.mark('history-loaded', {
      'availableMonths': history.availableMonths.length,
      'visibleMonths': visibleMonths.length,
    });
    trace.mark('initial-selected-snapshot-loaded', {
      'walletBalanceCount': selectedSnapshot.walletBalances.length,
    });

    final initialState = WalletsPageState(
      history: history,
      visibleMonths: visibleMonths,
      selectedMonthStart: selectedMonth,
      cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
        selectedMonth: selectedSnapshot,
      },
      loadingMonths: const <DateTime>{},
      monthErrorsByMonth: const <DateTime, Object>{},
      lastResolvedSelectedMonthStart: selectedMonth,
    );
    final overlaidInitialState =
        await _overlayPendingLocalWalletPageState(initialState);
    _storePageState(initialState);
    trace.mark('initial-state-ready', {'snapshotCount': 1});

    Future<void>(() async {
      try {
        await _prefetchMonths(
          visibleMonths.where((month) => month != selectedMonth),
        );
      } catch (_) {}
    });
    return overlaidInitialState;
  }

  Future<void> _prefetchMonths(Iterable<DateTime> months) async {
    if (_isDisposed || _isOffline) return;
    final monthsList =
        months.map(normalizeWalletMonthStart).toList(growable: false);
    final refreshGeneration = ref.read(walletsRefreshSignalProvider);
    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsSnapshotPrefetch',
      contextFields: {
        ..._walletsScopeDebugFields(_query),
        'months':
            monthsList.map(_walletsDebugMonthValue).toList(growable: false),
      },
    );
    trace.mark('prefetch-start', {'count': monthsList.length});
    for (final month in monthsList) {
      final current = state.valueOrNull;
      if (current == null) {
        trace.mark('prefetch-aborted', const {'reason': 'state-unavailable'});
        return;
      }
      final normalizedMonth = normalizeWalletMonthStart(month);
      if (current.cachedSnapshotsByMonth.containsKey(normalizedMonth) ||
          current.loadingMonths.contains(normalizedMonth)) {
        continue;
      }

      state = AsyncData(current.copyWith(
        loadingMonths: <DateTime>{...current.loadingMonths, normalizedMonth},
      ));

      try {
        final snapshot = await _service.fetchMonthSnapshot(
          WalletsMonthQuery(scope: _query, monthStart: normalizedMonth),
        );
        if (_isDisposed) {
          return;
        }
        if (refreshGeneration != ref.read(walletsRefreshSignalProvider)) {
          _clearLoadingMonth(normalizedMonth);
          return;
        }
        final latest = state.valueOrNull;
        if (latest == null) {
          return;
        }
        final nextState = latest.copyWith(
          cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
            ...latest.cachedSnapshotsByMonth,
            normalizedMonth: snapshot,
          },
          loadingMonths: <DateTime>{...latest.loadingMonths}
            ..remove(normalizedMonth),
          monthErrorsByMonth: <DateTime, Object>{
            ...latest.monthErrorsByMonth,
          }..remove(normalizedMonth),
        );
        state = AsyncData(nextState);
        final baseState = _readSessionCachedPageState();
        _storePageState(
          baseState == null
              ? nextState
              : baseState.copyWith(
                  cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
                    ...baseState.cachedSnapshotsByMonth,
                    normalizedMonth: snapshot,
                  },
                  loadingMonths: <DateTime>{...baseState.loadingMonths}
                    ..remove(normalizedMonth),
                  monthErrorsByMonth: <DateTime, Object>{
                    ...baseState.monthErrorsByMonth,
                  }..remove(normalizedMonth),
                ),
        );
        trace.mark('prefetch-success', {'month': normalizedMonth});
      } catch (error) {
        final latest = state.valueOrNull;
        if (latest == null) {
          return;
        }
        state = AsyncData(latest.copyWith(
          loadingMonths: <DateTime>{...latest.loadingMonths}
            ..remove(normalizedMonth),
          monthErrorsByMonth: <DateTime, Object>{
            ...latest.monthErrorsByMonth,
            normalizedMonth: error,
          },
        ));
        trace.mark('prefetch-error', {
          'month': normalizedMonth,
          'error': error,
        });
      }
    }
  }

  Future<void> _resolveSelectedMonth(DateTime monthStart) async {
    if (_isDisposed) {
      return;
    }
    if (_isOffline) {
      _clearLoadingMonth(monthStart);
      return;
    }
    final refreshGeneration = ref.read(walletsRefreshSignalProvider);
    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsSelectedMonth',
      contextFields: {
        ..._walletsScopeDebugFields(_query),
        'month': monthStart,
      },
    );
    trace.mark('selected-month-start');
    try {
      final snapshot = await _service.fetchMonthSnapshot(
        WalletsMonthQuery(scope: _query, monthStart: monthStart),
      );
      if (_isDisposed) {
        return;
      }
      if (refreshGeneration != ref.read(walletsRefreshSignalProvider)) {
        _clearLoadingMonth(monthStart);
        return;
      }
      final current = state.valueOrNull;
      if (current == null) {
        return;
      }
      final nextState = current.copyWith(
        cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
          ...current.cachedSnapshotsByMonth,
          monthStart: snapshot,
        },
        loadingMonths: <DateTime>{...current.loadingMonths}..remove(monthStart),
        monthErrorsByMonth: <DateTime, Object>{
          ...current.monthErrorsByMonth,
        }..remove(monthStart),
        lastResolvedSelectedMonthStart: monthStart,
      );
      state = AsyncData(nextState);
      final baseState = _readSessionCachedPageState();
      _storePageState(
        baseState == null
            ? nextState
            : baseState.copyWith(
                cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
                  ...baseState.cachedSnapshotsByMonth,
                  monthStart: snapshot,
                },
                loadingMonths: <DateTime>{...baseState.loadingMonths}
                  ..remove(monthStart),
                monthErrorsByMonth: <DateTime, Object>{
                  ...baseState.monthErrorsByMonth,
                }..remove(monthStart),
                lastResolvedSelectedMonthStart: monthStart,
              ),
      );
      trace.mark('selected-month-success', {
        'walletBalanceCount': snapshot.walletBalances.length,
      });
    } catch (error) {
      final current = state.valueOrNull;
      if (current == null) {
        return;
      }
      state = AsyncData(current.copyWith(
        loadingMonths: <DateTime>{...current.loadingMonths}..remove(monthStart),
        monthErrorsByMonth: <DateTime, Object>{
          ...current.monthErrorsByMonth,
          monthStart: error,
        },
      ));
      trace.mark('selected-month-error', {'error': error});
    }
  }

  Future<WalletsPageState?> _readPersistedCachedPageState({
    bool bypassPersistedCache = false,
  }) async {
    if (bypassPersistedCache) {
      return null;
    }
    return await readLocalWalletsPageState(ref, _query) ??
        readPersistedWalletsPageState(ref, _query);
  }

  WalletsPageState? _readSessionCachedPageState() {
    final cacheKey = walletsPageStateCacheKey(_query);
    return ref.read(_walletsPageStateBaseSessionCacheProvider)[cacheKey] ??
        ref.read(walletsPageStateSessionCacheProvider)[cacheKey];
  }

  void _listenToInMemoryOptimisticTransactions(WalletsScopeQuery arg) {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    ref.listen<List<ExpenseEntry>>(
      _walletsInMemoryOptimisticTransactionsProvider(arg),
      (previous, next) {
        final expectedCacheKey = walletsPageStateCacheKey(arg);
        final expectedGeneration = _readWalletsPageStateCacheGeneration(ref);
        final baseState = _readSessionCachedPageState() ?? state.valueOrNull;
        if (baseState == null) return;

        unawaited(() async {
          try {
            if (disposed) return;
            final overlaidState = await _overlayPendingLocalWalletPageState(
              baseState,
              inMemoryOptimisticTransactions: next,
            );
            if (disposed ||
                walletsPageStateCacheKey(_query) != expectedCacheKey) {
              return;
            }
            if (_readWalletsPageStateCacheGeneration(ref) !=
                expectedGeneration) {
              return;
            }
            final currentState = state.valueOrNull;
            if (currentState != null) {
              state = AsyncData(
                overlaidState.copyWith(isRefreshing: currentState.isRefreshing),
              );
            }
          } catch (_) {
            // Provider disposal can happen while the local overlay reads async
            // dependencies; the next rebuild/refresh will recompute the overlay.
          }
        }());
      },
    );
  }

  void _storePageState(WalletsPageState pageState) {
    final cacheKey = walletsPageStateCacheKey(_query);
    ref.read(walletsPageStateSessionCacheProvider.notifier).state = {
      ...ref.read(walletsPageStateSessionCacheProvider),
      cacheKey: pageState,
    };
    ref.read(_walletsPageStateBaseSessionCacheProvider.notifier).state = {
      ...ref.read(_walletsPageStateBaseSessionCacheProvider),
      cacheKey: pageState,
    };
    ref.read(_walletsPageStateSessionCacheGenerationsProvider.notifier).state =
        {
      ...ref.read(_walletsPageStateSessionCacheGenerationsProvider),
      cacheKey: _readWalletsPageStateCacheGeneration(ref),
    };
    ref.read(walletsPageStatePersistedCacheBypassProvider.notifier).state = 0;
    unawaited(persistWalletsPageState(ref, _query, pageState));
  }

  void _scheduleBackgroundRefresh() {
    if (_isOffline) return;
    Future<void>(() async {
      try {
        if (_isDisposed) return;
        await refresh();
      } catch (_) {}
    });
  }

  void _scheduleLocalDatabaseReadyRefresh() {
    if (_scheduledLocalDatabaseReadyRefresh ||
        ref.read(localDatabaseProvider).hasValue) {
      return;
    }

    _scheduledLocalDatabaseReadyRefresh = true;
    var disposed = false;
    ref.onDispose(() => disposed = true);
    unawaited(
      ref.read(localDatabaseProvider.future).then(
        (_) {
          if (disposed) return;
          Future<void>(() {
            if (!disposed) {
              ref.invalidateSelf();
            }
          });
        },
        onError: (_) {},
      ),
    );
  }

  void _ensureLifecycleTracking() {
    if (_hasDisposeListener) return;
    _hasDisposeListener = true;
    ref.onDispose(() => _isDisposed = true);
  }

  WalletsPageState _emptyPageState() {
    final selectedMonth = normalizeWalletMonthStart(_query.currentMonthStart);
    return WalletsPageState(
      history: const WalletsHistorySummary(
        availableMonths: <DateTime>[],
        netWorthSeries: <WalletNetWorthPoint>[],
      ),
      visibleMonths: buildWalletMonthWindow(
        anchorMonth: _query.currentMonthStart,
        count: _initialVisibleMonthCount,
      ),
      selectedMonthStart: selectedMonth,
      cachedSnapshotsByMonth: const <DateTime, WalletsMonthSnapshot>{},
      loadingMonths: const <DateTime>{},
      monthErrorsByMonth: const <DateTime, Object>{},
      lastResolvedSelectedMonthStart: selectedMonth,
    );
  }

  void _clearLoadingMonth(DateTime monthStart) {
    if (_isDisposed) return;
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final normalizedMonth = normalizeWalletMonthStart(monthStart);
    if (!current.loadingMonths.contains(normalizedMonth)) {
      return;
    }
    state = AsyncData(current.copyWith(
      loadingMonths: <DateTime>{...current.loadingMonths}
        ..remove(normalizedMonth),
    ));
  }

  Future<WalletsPageState> _overlayPendingLocalWalletPageState(
    WalletsPageState cachedState, {
    List<ExpenseEntry>? inMemoryOptimisticTransactions,
  }) async {
    final history = await _overlayPendingLocalWalletHistory(
      ref,
      _query,
      cachedState.history,
      inMemoryOptimisticTransactions: inMemoryOptimisticTransactions,
    );
    final snapshots = <DateTime, WalletsMonthSnapshot>{};
    for (final entry in cachedState.cachedSnapshotsByMonth.entries) {
      snapshots[entry.key] = await _overlayPendingLocalWalletMonthSnapshot(
        ref,
        WalletsMonthQuery(scope: _query, monthStart: entry.key),
        entry.value,
        inMemoryOptimisticTransactions: inMemoryOptimisticTransactions,
      );
    }
    return cachedState.copyWith(
      history: history,
      cachedSnapshotsByMonth: snapshots,
      isRefreshing: false,
    );
  }
}

class _WalletRecurringAwareData {
  const _WalletRecurringAwareData({
    required this.wallets,
    required this.transactions,
  });

  final List<WalletEntity> wallets;
  final List<ExpenseEntry> transactions;
}

DateTime _walletProjectionNow(Ref ref) {
  final preferredTimezone = ref.read(appPreferredTimezoneProvider);
  final now = effectiveNow(preferredTimezone: preferredTimezone);
  return DateTime(now.year, now.month, now.day);
}

Future<CurrencyRateTable> _walletCurrencyRates(Ref ref) async {
  try {
    return await ref.read(currencyRateTableProvider.future);
  } catch (_) {
    return const CurrencyRateTable(
      baseCurrency: 'USD',
      rates: CurrencyRates.rates,
      isStale: true,
    );
  }
}

int _convertWalletAmountCents({
  required int amountCents,
  required String? fromCurrency,
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final normalizedFrom = fromCurrency?.trim().toUpperCase();
  final normalizedTarget = targetCurrency.trim().toUpperCase();
  if (normalizedFrom == null ||
      normalizedFrom.isEmpty ||
      normalizedTarget.isEmpty) {
    return amountCents;
  }
  final sign = amountCents < 0 ? -1 : 1;
  final converted = rates.convert(
    amountCents.abs() / 100.0,
    normalizedFrom,
    normalizedTarget,
  );
  return (converted * 100).round() * sign;
}

String _formatWalletsRpcDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime _walletSnapshotEndExclusive({
  required DateTime monthStart,
  required DateTime now,
}) {
  final normalizedMonthStart = DateTime(monthStart.year, monthStart.month, 1);
  final currentMonthStart = DateTime(now.year, now.month, 1);
  if (normalizedMonthStart == currentMonthStart) {
    return now.add(const Duration(days: 1));
  }
  return DateTime(
    normalizedMonthStart.year,
    normalizedMonthStart.month + 1,
    1,
  );
}

Future<_WalletRecurringAwareData> _loadWalletRecurringAwareData(
  Ref ref,
  WalletsScopeQuery query, {
  required DateTime endInclusive,
}) async {
  final trace = _createWalletsTrace(
    ref,
    label: 'WalletsLegacyLoad',
    contextFields: {
      ..._walletsScopeDebugFields(query),
      'endInclusive': endInclusive,
    },
  );
  trace.mark('legacy-load-start');
  final wallets = await _fetchScopedWallets(ref, query);
  trace.mark('legacy-wallets-loaded', {'count': wallets.length});
  final actualTransactions = await _fetchWalletActualTransactions(
    ref,
    query,
    endInclusive: endInclusive,
  );
  trace.mark('legacy-actual-transactions-loaded', {
    'count': actualTransactions.length,
  });
  final recurringTransactions = await _fetchScopedRecurringTransactions(
    ref,
    query,
  );
  trace
      .mark('legacy-recurring-loaded', {'count': recurringTransactions.length});
  final projectionRangeStart = _resolveWalletProjectionRangeStart(
    actualTransactions: actualTransactions,
    recurringTransactions: recurringTransactions,
    fallbackMonthStart: DateTime(endInclusive.year, endInclusive.month, 1),
  );
  final projectedTransactions = _buildProjectedWalletRecurringTransactions(
    recurringTransactions: recurringTransactions,
    actualTransactions: actualTransactions,
    selectedCurrency: query.selectedCurrency,
    selectedCurrencies: query.normalizedSelectedCurrencies,
    rangeStart: projectionRangeStart,
    rangeEndInclusive: endInclusive,
  );
  trace.mark('legacy-projection-built', {
    'rangeStart': projectionRangeStart,
    'projectedCount': projectedTransactions.length,
  });
  final combinedTransactions = <ExpenseEntry>[
    ...actualTransactions,
    ...projectedTransactions,
  ];
  return _WalletRecurringAwareData(
    wallets: wallets,
    transactions: combinedTransactions,
  );
}

Future<List<WalletEntity>> _fetchScopedWallets(
    Ref ref, WalletsScopeQuery query) async {
  final householdId = query.householdId;
  final authHeaders = ref.read(walletAuthHeadersProvider);
  if (authHeaders == null) {
    final userId = query.userId;
    if (userId.isEmpty) {
      return const <WalletEntity>[];
    }

    final cacheKey = walletsListCacheKey(
      userId: userId,
      householdId: householdId,
      selectedCurrency: query.selectedCurrency,
      selectedCurrencies: query.normalizedSelectedCurrencies,
      currentMonthStart: query.currentMonthStart,
    );
    final cachedWallets = ref.read(walletsListSessionCacheProvider)[cacheKey] ??
        readPersistedWalletsList(
          ref,
          userId: userId,
          householdId: householdId,
          selectedCurrency: query.selectedCurrency,
          selectedCurrencies: query.normalizedSelectedCurrencies,
          currentMonthStart: query.currentMonthStart,
        ) ??
        const <WalletEntity>[];
    return _filterWalletsForSelectedCurrencies(
      cachedWallets,
      query.normalizedSelectedCurrencies,
    );
  }

  final response = await supabase.functions.invoke(
    'list-wallets',
    headers: authHeaders,
    body: {
      if (householdId != null && householdId.trim().isNotEmpty)
        'householdId': householdId,
      'currency': query.selectedCurrency.trim().toUpperCase(),
      if (query.normalizedSelectedCurrencies != null)
        'currencies': query.normalizedSelectedCurrencies,
      'monthStart': _formatWalletsRpcDate(query.currentMonthStart),
    },
  );

  final payload = response.data as Map<String, dynamic>?;
  if (payload == null || payload['success'] != true) {
    throw Exception(payload?['error']?.toString() ?? 'Failed to load wallets');
  }

  final data = payload['data'] as List<dynamic>? ?? const [];
  return _filterWalletsForSelectedCurrencies(
    data
        .whereType<Map<String, dynamic>>()
        .map(WalletEntity.fromJson)
        .where((wallet) => !wallet.isArchived)
        .toList(growable: false),
    query.normalizedSelectedCurrencies,
  );
}

List<WalletEntity> _filterWalletsForSelectedCurrencies(
  List<WalletEntity> wallets,
  List<String>? selectedCurrencies,
) {
  if (selectedCurrencies == null || selectedCurrencies.isEmpty) {
    return wallets;
  }
  return wallets
      .where(
        (wallet) => selectedCurrencies.contains(
          wallet.currency.trim().toUpperCase(),
        ),
      )
      .toList(growable: false);
}

List<WalletEntity> _cachedScopedWalletsForConversion(
  Ref ref,
  WalletsScopeQuery query,
) {
  final cacheKey = walletsListCacheKey(
    userId: query.userId,
    householdId: query.householdId,
    selectedCurrency: query.selectedCurrency,
    selectedCurrencies: query.normalizedSelectedCurrencies,
    currentMonthStart: query.currentMonthStart,
  );
  final cachedWallets = ref.read(walletsListSessionCacheProvider)[cacheKey] ??
      readPersistedWalletsList(
        ref,
        userId: query.userId,
        householdId: query.householdId,
        selectedCurrency: query.selectedCurrency,
        selectedCurrencies: query.normalizedSelectedCurrencies,
        currentMonthStart: query.currentMonthStart,
      ) ??
      const <WalletEntity>[];
  return _filterWalletsForSelectedCurrencies(
    cachedWallets,
    query.normalizedSelectedCurrencies,
  );
}

Future<List<ExpenseEntry>> _fetchWalletActualTransactions(
  Ref ref,
  WalletsScopeQuery query, {
  required DateTime endInclusive,
}) async {
  final trace = _createWalletsTrace(
    ref,
    label: 'WalletsLegacyActualTransactions',
    contextFields: {
      ..._walletsScopeDebugFields(query),
      'endInclusive': endInclusive,
    },
  );
  trace.mark('fetch-all-pages-start');
  final service = ref.read(transactionsFeedServiceProvider);
  final scope = ref.read(householdScopeProvider);
  final transactions = await service.fetchAllPages(
    TransactionsFeedQuery(
      userId: query.userId,
      householdId: query.householdId,
      selectedCurrency: query.selectedCurrency,
      selectedCurrencies: query.normalizedSelectedCurrencies,
      selectedCategory: null,
      selectedAccountId: null,
      selectedCategories: null,
      selectedType: 'all',
      searchQuery: '',
      startDate: null,
      endDate: endInclusive,
    ),
  );

  final filtered = filterWalletTransactions(
    allExpenses: transactions,
    scope: scope,
    selectedCurrency: query.selectedCurrency,
    selectedCurrencies: query.normalizedSelectedCurrencies,
  );
  trace.mark('fetch-all-pages-success', {
    'rawCount': transactions.length,
    'filteredCount': filtered.length,
  });
  return filtered;
}

Future<List<RecurringTransaction>> _fetchScopedRecurringTransactions(
  Ref ref,
  WalletsScopeQuery query,
) {
  final trace = _createWalletsTrace(
    ref,
    label: 'WalletsLegacyRecurringTransactions',
    contextFields: _walletsScopeDebugFields(query),
  );
  trace.mark('recurring-fetch-start');
  final householdScope = ref.read(householdScopeProvider);
  final scope = switch (householdScope.activeAccountType) {
    ActiveWalletType.personal => PocketsScopeType.personal,
    ActiveWalletType.portfolio => PocketsScopeType.portfolio,
    ActiveWalletType.household => PocketsScopeType.household,
  };

  return loadScopedRecurringTransactions(
    userId: query.userId,
    scope: scope,
    householdId: query.householdId,
  ).then((transactions) {
    trace.mark('recurring-fetch-success', {'count': transactions.length});
    return transactions;
  });
}

Future<List<ExpenseEntry>> _loadPendingLocalWalletTransactions(
  Ref ref,
  WalletsScopeQuery query, {
  DateTime? startDate,
  required DateTime endInclusive,
  List<ExpenseEntry>? inMemoryOptimisticTransactions,
}) async {
  if (query.userId.trim().isEmpty) {
    return const <ExpenseEntry>[];
  }

  final List<ExpenseEntry> inMemoryOptimistic =
      inMemoryOptimisticTransactions ??
          ref.read(_walletsInMemoryOptimisticTransactionsProvider(query));

  try {
    final database = ref.read(localDatabaseProvider).valueOrNull;
    if (database == null) {
      return inMemoryOptimistic;
    }
    final transactions = await database.getTransactionsFeedItems(
      LocalTransactionsFeedQuery(
        userId: query.userId,
        householdId: query.householdId,
        currency: query.selectedCurrency,
        currencies: query.normalizedSelectedCurrencies,
        category: null,
        accountId: null,
        categories: null,
        type: 'all',
        searchQuery: '',
        startDate: startDate,
        endDate: endInclusive,
        pageSize: 500,
      ),
      syncStatus: localSyncStatusLocal,
    );
    final scope = ref.read(householdScopeProvider);
    final filtered = filterWalletTransactions(
      allExpenses: transactions,
      scope: scope,
      selectedCurrency: query.selectedCurrency,
      selectedCurrencies: query.normalizedSelectedCurrencies,
    );
    return _mergeWalletLocalOverlayTransactions(
      inMemoryOptimistic,
      filtered,
    );
  } catch (_) {
    return inMemoryOptimistic;
  }
}

bool _isWalletInMemoryOptimisticTransaction(ExpenseEntry transaction) {
  return transaction.id.trim().startsWith('optimistic_');
}

List<ExpenseEntry> _mergeWalletLocalOverlayTransactions(
  Iterable<ExpenseEntry> first,
  Iterable<ExpenseEntry> second,
) {
  final byId = <String, ExpenseEntry>{};
  for (final transaction in first) {
    if (transaction.id.trim().isEmpty) continue;
    byId[transaction.id] = transaction;
  }
  for (final transaction in second) {
    if (transaction.id.trim().isEmpty) continue;
    byId[transaction.id] = transaction;
  }
  return byId.values.toList(growable: false);
}

Future<WalletsHistorySummary> _overlayPendingLocalWalletHistory(
  Ref ref,
  WalletsScopeQuery query,
  WalletsHistorySummary history, {
  List<ExpenseEntry>? inMemoryOptimisticTransactions,
}) async {
  final now = _walletProjectionNow(ref);
  final pendingTransactions = await _loadPendingLocalWalletTransactions(
    ref,
    query,
    endInclusive: now,
    inMemoryOptimisticTransactions: inMemoryOptimisticTransactions,
  );
  if (pendingTransactions.isEmpty) {
    return history;
  }
  final rates = await _walletCurrencyRates(ref);
  final wallets = _cachedScopedWalletsForConversion(ref, query);
  final walletsById = <String, WalletEntity>{
    for (final wallet in wallets) wallet.id: wallet,
  };

  return WalletsHistorySummary(
    availableMonths: history.availableMonths,
    netWorthSeries: history.netWorthSeries.map((point) {
      final endExclusive = _walletSnapshotEndExclusive(
        monthStart: point.monthStart,
        now: now,
      );
      final localDeltaCents = pendingTransactions.fold<int>(0, (sum, tx) {
        if (!tx.date.isBefore(endExclusive)) return sum;
        return sum +
            _walletTransactionNetDeltaCents(
              tx,
              wallets: wallets,
              walletsById: walletsById,
              targetCurrency: query.selectedCurrency,
              rates: rates,
            );
      });
      if (localDeltaCents == 0) return point;
      return WalletNetWorthPoint(
        monthStart: point.monthStart,
        netWorthCents: point.netWorthCents + localDeltaCents,
      );
    }).toList(growable: false),
  );
}

Future<WalletsMonthSnapshot> _overlayPendingLocalWalletMonthSnapshot(
  Ref ref,
  WalletsMonthQuery query,
  WalletsMonthSnapshot snapshot, {
  List<ExpenseEntry>? inMemoryOptimisticTransactions,
}) async {
  final pendingTransactions = await _loadPendingLocalWalletTransactions(
    ref,
    query.scope,
    endInclusive: snapshot.monthEndExclusive.subtract(const Duration(days: 1)),
    inMemoryOptimisticTransactions: inMemoryOptimisticTransactions,
  );
  if (pendingTransactions.isEmpty) {
    return snapshot;
  }

  var incomeTotalCents = snapshot.incomeTotalCents;
  var spentTotalCents = snapshot.spentTotalCents;
  var netWorthCents = snapshot.netWorthCents;
  final walletBalances = <String, int>{...snapshot.walletBalances};
  final rates = await _walletCurrencyRates(ref);
  final wallets = _cachedScopedWalletsForConversion(ref, query.scope);
  final walletsById = <String, WalletEntity>{
    for (final wallet in wallets) wallet.id: wallet,
  };
  final monthStart =
      DateTime(snapshot.monthStart.year, snapshot.monthStart.month);

  for (final tx in pendingTransactions) {
    if (!tx.date.isBefore(snapshot.monthEndExclusive)) continue;

    final amountCents = _convertWalletAmountCents(
      amountCents: tx.amountCents.abs(),
      fromCurrency: _walletTransactionSourceCurrency(
        tx,
        wallets: wallets,
        walletsById: walletsById,
      ),
      targetCurrency: query.scope.selectedCurrency,
      rates: rates,
    );
    final isIncome = (tx.type ?? 'expense').toLowerCase() == 'income';
    final localDeltaCents = isIncome ? amountCents : -amountCents;
    netWorthCents += localDeltaCents;

    final walletId = _resolvePendingWalletBalanceId(tx, walletBalances);
    if (walletId != null) {
      walletBalances[walletId] =
          (walletBalances[walletId] ?? 0) + localDeltaCents;
    }

    final transactionMonth = DateTime(tx.date.year, tx.date.month);
    if (transactionMonth == monthStart) {
      if (isIncome) {
        incomeTotalCents += amountCents;
      } else {
        spentTotalCents += amountCents;
      }
    }
  }

  return WalletsMonthSnapshot(
    monthStart: snapshot.monthStart,
    monthEndExclusive: snapshot.monthEndExclusive,
    incomeTotalCents: incomeTotalCents,
    spentTotalCents: spentTotalCents,
    netWorthCents: netWorthCents,
    walletBalances: walletBalances,
  );
}

int _walletTransactionNetDeltaCents(
  ExpenseEntry transaction, {
  required List<WalletEntity> wallets,
  required Map<String, WalletEntity> walletsById,
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final amountCents = _convertWalletAmountCents(
    amountCents: transaction.amountCents.abs(),
    fromCurrency: _walletTransactionSourceCurrency(
      transaction,
      wallets: wallets,
      walletsById: walletsById,
    ),
    targetCurrency: targetCurrency,
    rates: rates,
  );
  final isIncome = (transaction.type ?? 'expense').toLowerCase() == 'income';
  return isIncome ? amountCents : -amountCents;
}

String? _walletTransactionSourceCurrency(
  ExpenseEntry transaction, {
  required List<WalletEntity> wallets,
  required Map<String, WalletEntity> walletsById,
}) {
  final transactionCurrency = transaction.currency?.trim().toUpperCase();
  if (transactionCurrency != null && transactionCurrency.isNotEmpty) {
    return transactionCurrency;
  }
  final walletId = resolveTransactionWalletId(
    transaction: transaction,
    wallets: wallets,
  );
  return walletId == null ? null : walletsById[walletId]?.currency;
}

String? _resolvePendingWalletBalanceId(
  ExpenseEntry transaction,
  Map<String, int> walletBalances,
) {
  final accountId = transaction.walletId?.trim();
  if (accountId != null &&
      accountId.isNotEmpty &&
      walletBalances.containsKey(accountId)) {
    return accountId;
  }
  if (walletBalances.length == 1) {
    return walletBalances.keys.single;
  }
  return null;
}

WalletsDebugTrace _createWalletsTrace(
  Ref ref, {
  required String label,
  Map<String, Object?> contextFields = const <String, Object?>{},
}) {
  return WalletsDebugTrace(
    label: label,
    enabled: ref.read(walletsDebugLoggingEnabledProvider),
    logSink: ref.read(walletsDebugLogSinkProvider),
    contextFields: contextFields,
  );
}

Map<String, Object?> _walletsScopeDebugFields(WalletsScopeQuery query) {
  return {
    'user': query.userId,
    'household': query.householdId ?? '<none>',
    'currency': query.selectedCurrency,
    'month': query.currentMonthStart,
  };
}

Map<String, Object?> _walletsMonthDebugFields(WalletsMonthQuery query) {
  return {
    ..._walletsScopeDebugFields(query.scope),
    'targetMonth': query.monthStart,
  };
}

String _walletsDebugMonthValue(DateTime month) {
  final normalized = normalizeWalletMonthStart(month);
  final year = normalized.year.toString().padLeft(4, '0');
  final value = normalized.month.toString().padLeft(2, '0');
  return '$year-$value';
}

String? _resolveWalletsScopeHouseholdId(HouseholdScope scope) {
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return null;
    case ActiveWalletType.portfolio:
      return scope.activeAccountHouseholdId;
    case ActiveWalletType.household:
      return scope.selectedHouseholdId;
  }
}

DateTime _resolveWalletProjectionRangeStart({
  required List<ExpenseEntry> actualTransactions,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime fallbackMonthStart,
}) {
  var earliest = DateTime(
    fallbackMonthStart.year,
    fallbackMonthStart.month,
    1,
  );

  for (final transaction in actualTransactions) {
    final monthStart = DateTime(transaction.date.year, transaction.date.month);
    if (monthStart.isBefore(earliest)) {
      earliest = monthStart;
    }
  }

  for (final recurring in recurringTransactions) {
    final anchor = recurring.recurrenceRule?.anchorDate ?? recurring.date;
    final monthStart = DateTime(anchor.year, anchor.month);
    if (monthStart.isBefore(earliest)) {
      earliest = monthStart;
    }
  }

  return earliest;
}

List<ExpenseEntry> _buildProjectedWalletRecurringTransactions({
  required List<RecurringTransaction> recurringTransactions,
  required List<ExpenseEntry> actualTransactions,
  required String selectedCurrency,
  List<String>? selectedCurrencies,
  required DateTime rangeStart,
  required DateTime rangeEndInclusive,
}) {
  if (recurringTransactions.isEmpty) {
    return const <ExpenseEntry>[];
  }

  final recurringById = <String, RecurringTransaction>{
    for (final recurring in recurringTransactions) recurring.id: recurring,
  };
  final projectedExpenses = projectRecurringTransactionsAsExpenseEntries(
    recurringTransactions: recurringTransactions,
    rangeStart: rangeStart,
    rangeEnd: rangeEndInclusive,
    selectedCurrency: selectedCurrency,
    selectedCurrencies: selectedCurrencies,
  ).map((expense) {
    final recurringId =
        extractRecurringTransactionIdFromProjectedExpenseId(expense.id);
    final source = recurringId == null ? null : recurringById[recurringId];
    final accountId = source?.accountId?.trim();
    // CRITICAL: preserve the source recurring account_id on projected wallet
    // rows.
    // STRICT REQUIREMENT: without this, projected recurring transactions lose
    // wallet ownership and either fall into the legacy default wallet or
    // disappear from wallet-specific calculations.
    return expense.copyWith(
      accountId: accountId == null || accountId.isEmpty ? null : accountId,
    );
  }).toList(growable: false);

  // CRITICAL: wallet month snapshots/history must include projected recurring
  // transactions month-by-month.
  // STRICT REQUIREMENT: keep this local recurring-aware path until every
  // wallet summary RPC used by the app is guaranteed to return the same
  // recurring-expanded balances, or the wallets page will regress again.
  return dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projectedExpenses,
    actualExpenses: actualTransactions,
  );
}
