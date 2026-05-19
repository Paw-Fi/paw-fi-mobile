import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

final walletsRefreshSignalProvider = StateProvider<int>((ref) => 0);

final walletsScopeQueryProvider = Provider<WalletsScopeQuery>((ref) {
  final auth = ref.watch(authProvider);
  final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
  final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
  final householdScope = ref.watch(householdScopeProvider);
  final effectiveNowForUser =
      effectiveNow(preferredTimezone: preferredTimezone);

  return WalletsScopeQuery(
    userId: auth.uid,
    householdId: _resolveWalletsScopeHouseholdId(householdScope),
    selectedCurrency: selectedCurrencyCode,
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
    final recurringAwareData = await _loadWalletRecurringAwareData(
      ref,
      query.scope,
      endInclusive: endExclusive.subtract(const Duration(days: 1)),
    );
    final snapshot = buildWalletSnapshot(
      wallets: recurringAwareData.wallets,
      transactions: recurringAwareData.transactions,
      endExclusive: endExclusive,
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

  WalletsRpcRunner get _rpcRunner => ref.read(walletsRpcRunnerProvider);
  WalletsLegacyDataLoader get _legacyLoader =>
      ref.read(walletsLegacyDataLoaderProvider);

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsHistoryRpc',
      contextFields: _walletsScopeDebugFields(query),
    );
    if (ref.read(walletAuthHeadersProvider) == null) {
      trace.mark('history-rpc-skipped', const {
        'reason': 'missing-auth-headers',
      });
      return _legacyLoader.fetchHistory(query);
    }

    trace.mark('history-rpc-start', const {'rpc': 'get_wallets_history_v2'});
    try {
      final response = await _rpcRunner.run(
        'get_wallets_history_v2',
        params: query.toHistoryRpcParams(),
      );
      final history = WalletsHistorySummary.fromJson(
        _parseWalletsRpcPayload(
          response,
          rpcName: 'get_wallets_history_v2',
        ),
      );
      final historyWithLocalOverlay = await _overlayPendingLocalWalletHistory(
        ref,
        query,
        history,
      );
      trace.mark('history-rpc-success', {
        'months': historyWithLocalOverlay.availableMonths.length,
        'seriesPoints': historyWithLocalOverlay.netWorthSeries.length,
      });
      return historyWithLocalOverlay;
    } catch (error) {
      if (!_isMissingWalletsRpcFunctionError(error,
          rpcName: 'get_wallets_history_v2')) {
        trace.mark('history-rpc-error', {'error': error});
        rethrow;
      }
      _debugWalletsMissingRpc('get_wallets_history_v2');
      trace.mark('history-rpc-fallback', const {'reason': 'missing-v2-rpc'});
      return _legacyLoader.fetchHistory(query);
    }
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsMonthSnapshotRpc',
      contextFields: _walletsMonthDebugFields(query),
    );
    if (ref.read(walletAuthHeadersProvider) == null) {
      trace.mark('month-snapshot-rpc-skipped', const {
        'reason': 'missing-auth-headers',
      });
      return _legacyLoader.fetchMonthSnapshot(query);
    }

    trace.mark('month-snapshot-rpc-start',
        const {'rpc': 'get_wallets_month_snapshot_v2'});
    try {
      final response = await _rpcRunner.run(
        'get_wallets_month_snapshot_v2',
        params: query.toRpcParams(),
      );
      final snapshot = WalletsMonthSnapshot.fromJson(
        _parseWalletsRpcPayload(
          response,
          rpcName: 'get_wallets_month_snapshot_v2',
        ),
      );
      final snapshotWithLocalOverlay =
          await _overlayPendingLocalWalletMonthSnapshot(ref, query, snapshot);
      trace.mark('month-snapshot-rpc-success', {
        'walletBalanceCount': snapshotWithLocalOverlay.walletBalances.length,
        'netWorthCents': snapshotWithLocalOverlay.netWorthCents,
      });
      return snapshotWithLocalOverlay;
    } catch (error) {
      if (!_isMissingWalletsRpcFunctionError(error,
          rpcName: 'get_wallets_month_snapshot_v2')) {
        trace.mark('month-snapshot-rpc-error', {'error': error});
        rethrow;
      }
      _debugWalletsMissingRpc('get_wallets_month_snapshot_v2');
      trace.mark(
          'month-snapshot-rpc-fallback', const {'reason': 'missing-v2-rpc'});
      return _legacyLoader.fetchMonthSnapshot(query);
    }
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

final _walletsTransactionCacheInvalidationProvider = Provider<void>((ref) {
  void clearWalletPageCaches() {
    final userId = ref.read(authProvider).uid;
    ref.read(walletsPageStateSessionCacheProvider.notifier).state = const {};
    if (userId.isEmpty) return;

    ref.read(walletsPersistedCacheBypassCountProvider.notifier).state++;
    unawaited(
      Future<void>.microtask(() {
        final notifier =
            ref.read(walletsPersistedCacheBypassCountProvider.notifier);
        notifier.state = notifier.state > 0 ? notifier.state - 1 : 0;
      }),
    );
  }

  ref.listen(dashboardRefreshSignalProvider, (previous, next) {
    if (previous != null && previous != next) {
      clearWalletPageCaches();
    }
  });
  ref.listen(transactionsFeedRefreshSignalProvider, (previous, next) {
    if (previous != null && previous != next) {
      clearWalletPageCaches();
    }
  });
});

Map<String, dynamic> _parseWalletsRpcPayload(
  dynamic response, {
  required String rpcName,
}) {
  if (response is Map<String, dynamic>) {
    return response;
  }
  if (response is Map) {
    return Map<String, dynamic>.from(response);
  }
  throw StateError('$rpcName returned an unexpected payload: $response');
}

bool _isMissingWalletsRpcFunctionError(
  Object error, {
  required String rpcName,
}) {
  if (error is! PostgrestException) {
    return false;
  }

  if (error.code == '42883') {
    return true;
  }

  return error.message.toLowerCase().contains(rpcName.toLowerCase());
}

void _debugWalletsMissingRpc(String rpcName) {
  debugPrint(
    '[Wallets] RPC $rpcName missing; deploy migration '
    '20260408170000_add_recurring_aware_wallets_and_pockets_rpcs.sql',
  );
}

final walletsHistoryProvider =
    FutureProvider.family<WalletsHistorySummary, WalletsScopeQuery>(
  (ref, query) async {
    ref.watch(_walletsTransactionCacheInvalidationProvider);
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
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
  late final WalletsScopeQuery _query;

  static const _initialVisibleMonthCount = 3;
  static const _appendMonthBatchSize = 3;

  WalletsDataService get _service => ref.read(walletsDataServiceProvider);
  bool get _isOffline =>
      ref.read(networkReachabilityProvider).valueOrNull == false;

  @override
  Future<WalletsPageState> build(WalletsScopeQuery arg) async {
    _query = arg;
    ref.watch(_walletsTransactionCacheInvalidationProvider);
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
    final bypassPersistedCache =
        ref.watch(walletsPersistedCacheBypassCountProvider) > 0;
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
      final sessionState = sessionCache[walletsPageStateCacheKey(_query)];
      if (sessionState != null) {
        trace.mark('session-cache-hit', {
          'visibleMonths': sessionState.visibleMonths.length,
          'snapshotCount': sessionState.cachedSnapshotsByMonth.length,
        });
        final overlaidState =
            await _overlayPendingLocalWalletPageState(sessionState);
        if (!_isOffline) {
          _scheduleBackgroundRefresh();
        }
        return overlaidState;
      }

      final cachedState = _readPersistedCachedPageState();
      if (cachedState != null) {
        trace.mark('cache-hit', {
          'visibleMonths': cachedState.visibleMonths.length,
          'snapshotCount': cachedState.cachedSnapshotsByMonth.length,
          'bypassPersistedCache': bypassPersistedCache,
        });
        final overlaidState =
            await _overlayPendingLocalWalletPageState(cachedState);
        if (!_isOffline) {
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
      final cachedState = _readPersistedCachedPageState();
      if (cachedState != null) {
        return _overlayPendingLocalWalletPageState(cachedState);
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final refreshGeneration = ref.read(walletsRefreshSignalProvider);
    if (_isOffline) {
      if (previous != null) {
        state = AsyncData(previous.copyWith(isRefreshing: false));
      } else {
        state = AsyncData(await _overlayPendingLocalWalletPageState(
          _readPersistedCachedPageState() ?? _emptyPageState(),
        ));
      }
      return;
    }
    if (previous == null) {
      final cachedState = _readPersistedCachedPageState();
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

    state = AsyncData(previous.copyWith(isRefreshing: true));

    final trace = _createWalletsTrace(
      ref,
      label: 'WalletsPageRefresh',
      contextFields: _walletsScopeDebugFields(_query),
    );

    try {
      trace.mark('refresh-start');
      final selectedMonth =
          normalizeWalletMonthStart(previous.selectedMonthStart);
      final results = await Future.wait<dynamic>([
        _service.fetchHistory(_query),
        _service.fetchMonthSnapshot(
          WalletsMonthQuery(scope: _query, monthStart: selectedMonth),
        ),
      ]);
      if (refreshGeneration != ref.read(walletsRefreshSignalProvider)) {
        final latest = state.valueOrNull;
        if (latest != null) {
          state = AsyncData(latest.copyWith(isRefreshing: false));
        }
        return;
      }
      final history = results[0] as WalletsHistorySummary;
      final refreshedSnapshot = results[1] as WalletsMonthSnapshot;

      final refreshedState = previous.copyWith(
        history: history,
        cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
          ...previous.cachedSnapshotsByMonth,
          selectedMonth: refreshedSnapshot,
        },
        monthErrorsByMonth: <DateTime, Object>{
          ...previous.monthErrorsByMonth,
        }..remove(selectedMonth),
        loadingMonths: <DateTime>{
          ...previous.loadingMonths,
        }..remove(selectedMonth),
        lastResolvedSelectedMonthStart: selectedMonth,
        isRefreshing: false,
      );
      state = AsyncData(refreshedState);
      _storePageState(refreshedState);
      trace.mark('refresh-success', {
        'selectedMonth': selectedMonth,
        'visibleMonths': refreshedState.visibleMonths.length,
      });

      final monthsToWarm = refreshedState.visibleMonths
          .where((month) => month != selectedMonth)
          .toList(growable: false);
      unawaited(_prefetchMonths(monthsToWarm));
    } catch (error) {
      trace.mark('refresh-error', {'error': error});
      state = AsyncData(previous.copyWith(isRefreshing: false));
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
    _storePageState(initialState);
    trace.mark('initial-state-ready', {'snapshotCount': 1});

    Future<void>(() async {
      try {
        await _prefetchMonths(
          visibleMonths.where((month) => month != selectedMonth),
        );
      } catch (_) {}
    });
    return initialState;
  }

  Future<void> _prefetchMonths(Iterable<DateTime> months) async {
    if (_isOffline) return;
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
        if (refreshGeneration != ref.read(walletsRefreshSignalProvider)) {
          _clearLoadingMonth(normalizedMonth);
          return;
        }
        final latest = state.valueOrNull;
        if (latest == null) {
          return;
        }
        state = AsyncData(latest.copyWith(
          cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
            ...latest.cachedSnapshotsByMonth,
            normalizedMonth: snapshot,
          },
          loadingMonths: <DateTime>{...latest.loadingMonths}
            ..remove(normalizedMonth),
          monthErrorsByMonth: <DateTime, Object>{
            ...latest.monthErrorsByMonth,
          }..remove(normalizedMonth),
        ));
        _storePageState(state.valueOrNull ?? latest);
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
      if (refreshGeneration != ref.read(walletsRefreshSignalProvider)) {
        _clearLoadingMonth(monthStart);
        return;
      }
      final current = state.valueOrNull;
      if (current == null) {
        return;
      }
      state = AsyncData(current.copyWith(
        cachedSnapshotsByMonth: <DateTime, WalletsMonthSnapshot>{
          ...current.cachedSnapshotsByMonth,
          monthStart: snapshot,
        },
        loadingMonths: <DateTime>{...current.loadingMonths}
          ..remove(monthStart),
        monthErrorsByMonth: <DateTime, Object>{
          ...current.monthErrorsByMonth,
        }..remove(monthStart),
        lastResolvedSelectedMonthStart: monthStart,
      ));
      _storePageState(state.valueOrNull ?? current);
      trace.mark('selected-month-success', {
        'walletBalanceCount': snapshot.walletBalances.length,
      });
    } catch (error) {
      final current = state.valueOrNull;
      if (current == null) {
        return;
      }
      state = AsyncData(current.copyWith(
        loadingMonths: <DateTime>{...current.loadingMonths}
          ..remove(monthStart),
        monthErrorsByMonth: <DateTime, Object>{
          ...current.monthErrorsByMonth,
          monthStart: error,
        },
      ));
      trace.mark('selected-month-error', {'error': error});
    }
  }

  WalletsPageState? _readPersistedCachedPageState() {
    return readPersistedWalletsPageState(ref, _query);
  }

  void _storePageState(WalletsPageState pageState) {
    final cacheKey = walletsPageStateCacheKey(_query);
    ref.read(walletsPageStateSessionCacheProvider.notifier).state = {
      ...ref.read(walletsPageStateSessionCacheProvider),
      cacheKey: pageState,
    };
    unawaited(persistWalletsPageState(ref, _query, pageState));
  }

  void _scheduleBackgroundRefresh() {
    if (_isOffline) return;
    Future<void>(() async {
      try {
        await refresh();
      } catch (_) {}
    });
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
    WalletsPageState cachedState,
  ) async {
    final history = await _overlayPendingLocalWalletHistory(
      ref,
      _query,
      cachedState.history,
    );
    final snapshots = <DateTime, WalletsMonthSnapshot>{};
    for (final entry in cachedState.cachedSnapshotsByMonth.entries) {
      snapshots[entry.key] = await _overlayPendingLocalWalletMonthSnapshot(
        ref,
        WalletsMonthQuery(scope: _query, monthStart: entry.key),
        entry.value,
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
    rangeStart: projectionRangeStart,
    rangeEndInclusive: endInclusive,
  );
  trace.mark('legacy-projection-built', {
    'rangeStart': projectionRangeStart,
    'projectedCount': projectedTransactions.length,
  });

  return _WalletRecurringAwareData(
    wallets: wallets,
    transactions: <ExpenseEntry>[
      ...actualTransactions,
      ...projectedTransactions,
    ],
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
      currentMonthStart: query.currentMonthStart,
    );
    return ref.read(walletsListSessionCacheProvider)[cacheKey] ??
        readPersistedWalletsList(
          ref,
          userId: userId,
          householdId: householdId,
          selectedCurrency: query.selectedCurrency,
          currentMonthStart: query.currentMonthStart,
        ) ??
        const <WalletEntity>[];
  }

  final response = await supabase.functions.invoke(
    'list-wallets',
    headers: authHeaders,
    body: {
      if (householdId != null && householdId.trim().isNotEmpty)
        'householdId': householdId,
      'currency': query.selectedCurrency.trim().toUpperCase(),
      'monthStart': _formatWalletsRpcDate(query.currentMonthStart),
    },
  );

  final payload = response.data as Map<String, dynamic>?;
  if (payload == null || payload['success'] != true) {
    throw Exception(payload?['error']?.toString() ?? 'Failed to load wallets');
  }

  final data = payload['data'] as List<dynamic>? ?? const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(WalletEntity.fromJson)
      .where((wallet) => !wallet.isArchived)
      .toList(growable: false);
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
}) async {
  if (query.userId.trim().isEmpty) {
    return const <ExpenseEntry>[];
  }

  try {
    final database = await ref.read(localDatabaseProvider.future);
    final transactions = await database.getTransactionsFeedItems(
      LocalTransactionsFeedQuery(
        userId: query.userId,
        householdId: query.householdId,
        currency: query.selectedCurrency,
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
    return filterWalletTransactions(
      allExpenses: transactions,
      scope: scope,
      selectedCurrency: query.selectedCurrency,
    );
  } catch (_) {
    return const <ExpenseEntry>[];
  }
}

Future<WalletsHistorySummary> _overlayPendingLocalWalletHistory(
  Ref ref,
  WalletsScopeQuery query,
  WalletsHistorySummary history,
) async {
  final now = _walletProjectionNow(ref);
  final pendingTransactions = await _loadPendingLocalWalletTransactions(
    ref,
    query,
    endInclusive: now,
  );
  if (pendingTransactions.isEmpty) {
    return history;
  }

  return WalletsHistorySummary(
    availableMonths: history.availableMonths,
    netWorthSeries: history.netWorthSeries.map((point) {
      final endExclusive = _walletSnapshotEndExclusive(
        monthStart: point.monthStart,
        now: now,
      );
      final localDeltaCents = pendingTransactions.fold<int>(0, (sum, tx) {
        if (!tx.date.isBefore(endExclusive)) return sum;
        return sum + _walletTransactionNetDeltaCents(tx);
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
  WalletsMonthSnapshot snapshot,
) async {
  final pendingTransactions = await _loadPendingLocalWalletTransactions(
    ref,
    query.scope,
    endInclusive: snapshot.monthEndExclusive.subtract(const Duration(days: 1)),
  );
  if (pendingTransactions.isEmpty) {
    return snapshot;
  }

  var incomeTotalCents = snapshot.incomeTotalCents;
  var spentTotalCents = snapshot.spentTotalCents;
  var netWorthCents = snapshot.netWorthCents;
  final walletBalances = <String, int>{...snapshot.walletBalances};
  final monthStart =
      DateTime(snapshot.monthStart.year, snapshot.monthStart.month);

  for (final tx in pendingTransactions) {
    if (!tx.date.isBefore(snapshot.monthEndExclusive)) continue;

    final amountCents = tx.amountCents.abs();
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

int _walletTransactionNetDeltaCents(ExpenseEntry transaction) {
  final amountCents = transaction.amountCents.abs();
  final isIncome = (transaction.type ?? 'expense').toLowerCase() == 'income';
  return isIncome ? amountCents : -amountCents;
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
