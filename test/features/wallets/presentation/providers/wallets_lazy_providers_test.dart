import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transfer_feed_entries.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockWalletsRpcRunner extends Mock implements WalletsRpcRunner {}

class _RecordingTransactionsFeedService extends EmptyTransactionsFeedService {
  int refreshCalls = 0;
  TransactionsFeedQuery? lastRefreshQuery;

  @override
  Future<void> refreshFromRemote(TransactionsFeedQuery query) async {
    refreshCalls += 1;
    lastRefreshQuery = query;
  }
}

class _StaticTransactionsFeedService extends EmptyTransactionsFeedService {
  const _StaticTransactionsFeedService(this.entries);

  final List<ExpenseEntry> entries;

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async =>
      entries;
}

class _FakeWalletsDataService implements WalletsDataService {
  int historyCalls = 0;
  int snapshotCalls = 0;
  WalletsScopeQuery? lastHistoryQuery;
  WalletsMonthQuery? lastSnapshotQuery;
  final List<DateTime> snapshotMonths = <DateTime>[];

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    historyCalls += 1;
    lastHistoryQuery = query;
    return WalletsHistorySummary(
      availableMonths: [DateTime(2026, 4, 1), DateTime(2026, 3, 1)],
      netWorthSeries: [
        WalletNetWorthPoint(
            monthStart: DateTime(2026, 3, 1), netWorthCents: 1000),
        WalletNetWorthPoint(
            monthStart: DateTime(2026, 4, 1), netWorthCents: 2000),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    snapshotCalls += 1;
    lastSnapshotQuery = query;
    snapshotMonths.add(query.monthStart);
    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive:
          DateTime(query.monthStart.year, query.monthStart.month + 1, 1),
      incomeTotalCents: 300,
      spentTotalCents: 100,
      netWorthCents: 200,
      walletBalances: const {'w1': 200},
    );
  }
}

class _StaleRefreshWalletsDataService implements WalletsDataService {
  final refreshSnapshotGate = Completer<void>();
  int historyCalls = 0;
  int snapshotCalls = 0;

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    historyCalls += 1;
    return WalletsHistorySummary(
      availableMonths: [DateTime(2026, 4, 1)],
      netWorthSeries: [
        WalletNetWorthPoint(
          monthStart: DateTime(2026, 4, 1),
          netWorthCents: 10000,
        ),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async {
    snapshotCalls += 1;
    if (snapshotCalls > 1) {
      await refreshSnapshotGate.future;
    }
    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive:
          DateTime(query.monthStart.year, query.monthStart.month + 1, 1),
      incomeTotalCents: 0,
      spentTotalCents: 0,
      netWorthCents: 10000,
      walletBalances: const {'w1': 10000},
    );
  }
}

class _UpdatedWalletsDataService implements WalletsDataService {
  int historyCalls = 0;
  int snapshotCalls = 0;

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    historyCalls += 1;
    return WalletsHistorySummary(
      availableMonths: [DateTime(2026, 4, 1)],
      netWorthSeries: [
        WalletNetWorthPoint(
          monthStart: DateTime(2026, 4, 1),
          netWorthCents: 8500,
        ),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async {
    snapshotCalls += 1;
    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive:
          DateTime(query.monthStart.year, query.monthStart.month + 1, 1),
      incomeTotalCents: 0,
      spentTotalCents: 1500,
      netWorthCents: 8500,
      walletBalances: const {'w1': 8500},
    );
  }
}

class _FakeWalletsLegacyDataLoader implements WalletsLegacyDataLoader {
  _FakeWalletsLegacyDataLoader({
    this.historyResult,
    this.snapshotResult,
  });

  int historyCalls = 0;
  int snapshotCalls = 0;
  WalletsScopeQuery? lastHistoryQuery;
  WalletsMonthQuery? lastSnapshotQuery;
  final WalletsHistorySummary? historyResult;
  final WalletsMonthSnapshot? snapshotResult;

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    historyCalls += 1;
    lastHistoryQuery = query;
    return historyResult ??
        WalletsHistorySummary(
          availableMonths: [DateTime(2026, 4, 1)],
          netWorthSeries: [
            WalletNetWorthPoint(
              monthStart: DateTime(2026, 4, 1),
              netWorthCents: 777,
            ),
          ],
        );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async {
    snapshotCalls += 1;
    lastSnapshotQuery = query;
    return snapshotResult ??
        WalletsMonthSnapshot(
          monthStart: query.monthStart,
          monthEndExclusive:
              DateTime(query.monthStart.year, query.monthStart.month + 1, 1),
          incomeTotalCents: 111,
          spentTotalCents: 22,
          netWorthCents: 333,
          walletBalances: const {'legacy-wallet': 333},
        );
  }
}

WalletsPageState _cachedWalletState({
  required DateTime monthStart,
  required int balanceCents,
  required int spentCents,
  Set<String> appliedKeys = const <String>{},
}) {
  return WalletsPageState(
    history: WalletsHistorySummary(
      availableMonths: [monthStart],
      netWorthSeries: [
        WalletNetWorthPoint(
          monthStart: monthStart,
          netWorthCents: balanceCents,
          appliedPendingTransactionKeys: appliedKeys,
        ),
      ],
    ),
    visibleMonths: [monthStart],
    selectedMonthStart: monthStart,
    cachedSnapshotsByMonth: {
      monthStart: WalletsMonthSnapshot(
        monthStart: monthStart,
        monthEndExclusive: DateTime(monthStart.year, monthStart.month + 1, 1),
        incomeTotalCents: 0,
        spentTotalCents: spentCents,
        netWorthCents: balanceCents,
        walletBalances: {'w1': balanceCents},
        appliedPendingTransactionKeys: appliedKeys,
      ),
    },
    loadingMonths: const <DateTime>{},
    monthErrorsByMonth: const <DateTime, Object>{},
    lastResolvedSelectedMonthStart: monthStart,
  );
}

ProviderContainer _offlineWalletContainer(
  MonekoDatabase database,
  WalletsScopeQuery scope, {
  WalletsPageState? sessionState,
}) {
  final container = ProviderContainer(overrides: [
    appPreferredTimezoneProvider.overrideWith((ref) => null),
    walletAuthHeadersProvider
        .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
    networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
    localDatabaseProvider.overrideWith((ref) async => database),
    householdScopeProvider.overrideWithValue(
      const HouseholdScope(
        viewMode: ViewMode.personal,
        selected: SelectedHouseholdState(),
        portfolioHouseholdIds: <String>{},
      ),
    ),
  ]);
  container.read(walletsListSessionCacheProvider.notifier).state = {
    walletsListCacheKey(
      userId: scope.userId,
      householdId: scope.householdId,
      selectedCurrency: scope.selectedCurrency,
      selectedCurrencies: scope.selectedCurrencies,
      currentMonthStart: scope.currentMonthStart,
    ): const [
      WalletEntity(
        id: 'w1',
        userId: 'user-1',
        householdId: null,
        name: 'PayPal',
        icon: 'wallet',
        color: '#6B7280',
        currency: 'USD',
        openingBalanceCents: 10000,
        goalAmountCents: null,
        isDefault: false,
        isSystem: false,
        isArchived: false,
        currentBalanceCents: 10000,
        hasProviderBalance: true,
      ),
    ],
  };
  if (sessionState != null) {
    container.read(walletsPageStateSessionCacheProvider.notifier).state = {
      walletsPageStateCacheKey(scope): sessionState,
    };
  }
  return container;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(<String, dynamic>{});
    try {
      await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'test-anon-key',
      );
    } catch (_) {
      // The singleton may already be initialized by another test file.
    }
  });

  WalletsScopeQuery buildScope() => WalletsScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        currentMonthStart: DateTime(2026, 4, 1),
      );

  test(
      'overview current cycle key matches wallet details for custom start days',
      () {
    final now = effectiveNow(preferredTimezone: 'UTC');
    for (final startDay in [1, 2, 25, 31]) {
      final container = ProviderContainer(overrides: [
        appPreferredTimezoneProvider.overrideWith((ref) => 'UTC'),
        financialMonthStartDayProvider.overrideWithValue(startDay),
        householdScopeProvider.overrideWithValue(const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: {},
        )),
      ]);
      addTearDown(container.dispose);
      final overview = container.read(walletsScopeQueryProvider);
      final detailsCycle = financialCycleStartForDate(now, startDay: startDay);
      expect(overview.currentMonthStart, detailsCycle,
          reason:
              'Overview must not default to a previous cycle for start day $startDay');
    }
  });

  test('empty pending overlay does not wait for exchange rates', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final gate = Completer<CurrencyRateTable>();
    var ratesRequested = false;
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
      currencyRateTableProvider.overrideWith((ref) {
        ratesRequested = true;
        return gate.future;
      }),
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
      householdScopeProvider.overrideWithValue(const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{})),
    ]);
    addTearDown(container.dispose);
    await container.read(localDatabaseProvider.future);
    final pending =
        container.read(walletsPageStateProvider(buildScope()).future);
    await pumpEventQueue(times: 8);
    gate.complete(
        const CurrencyRateTable(baseCurrency: 'USD', rates: {'USD': 1}));
    await pending;
    expect(ratesRequested, isFalse);
  });

  test('wallet page state cache uses analytics-exclusion-aware version', () {
    expect(walletsPageStateCacheKey(buildScope()),
        startsWith('wallets:page-state:v8:'));
  });

  test('wallet page cache preserves applied pending transaction keys', () {
    final monthStart = DateTime(2026, 4, 1);
    final restored = WalletsPageState.fromCacheJson(
      WalletsPageState(
        history: WalletsHistorySummary(
          availableMonths: [monthStart],
          netWorthSeries: [
            WalletNetWorthPoint(
              monthStart: monthStart,
              netWorthCents: 8500,
              appliedPendingTransactionKeys: const {
                'optimistic_create|mutation-create',
              },
            ),
          ],
        ),
        visibleMonths: [monthStart],
        selectedMonthStart: monthStart,
        cachedSnapshotsByMonth: {
          monthStart: WalletsMonthSnapshot(
            monthStart: monthStart,
            monthEndExclusive: DateTime(2026, 5, 1),
            incomeTotalCents: 0,
            spentTotalCents: 1500,
            netWorthCents: 8500,
            walletBalances: const {'w1': 8500},
            appliedPendingTransactionKeys: const {
              'optimistic_create|mutation-create',
            },
          ),
        },
        loadingMonths: const <DateTime>{},
        monthErrorsByMonth: const <DateTime, Object>{},
        lastResolvedSelectedMonthStart: monthStart,
      ).toCacheJson(),
    );

    expect(
      restored.displayedSnapshot?.appliedPendingTransactionKeys,
      {'optimistic_create|mutation-create'},
    );
    expect(
      restored.history.netWorthSeries.single.appliedPendingTransactionKeys,
      {'optimistic_create|mutation-create'},
    );
  });

  test('v8 wallet cache does not read a pre-contract v7 snapshot', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final currentKey = walletsPageStateCacheKey(scope);
    final legacyKey = currentKey.replaceFirst(
      'wallets:page-state:v8:',
      'wallets:page-state:v7:',
    );
    await database.upsertJsonCache(
      namespace: 'wallets_page_state',
      cacheKey: legacyKey,
      payload: const <String, dynamic>{'legacy': true},
    );
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    await container.read(localDatabaseProvider.future);
    final readCacheProvider = FutureProvider<WalletsPageState?>(
      (ref) => readLocalWalletsPageState(ref, scope),
    );

    expect(await container.read(readCacheProvider.future), isNull);
  });

  test('analytics exclusion change clears persisted wallet page state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final monthStart = DateTime(2026, 4, 1);
    final state = WalletsPageState(
      history: WalletsHistorySummary(
        availableMonths: [monthStart],
        netWorthSeries: [
          WalletNetWorthPoint(monthStart: monthStart, netWorthCents: 10000),
        ],
      ),
      visibleMonths: [monthStart],
      selectedMonthStart: monthStart,
      cachedSnapshotsByMonth: {
        monthStart: WalletsMonthSnapshot(
          monthStart: monthStart,
          monthEndExclusive: DateTime(2026, 5, 1),
          incomeTotalCents: 0,
          spentTotalCents: 0,
          netWorthCents: 10000,
          walletBalances: const {'w1': 10000},
        ),
      },
      loadingMonths: const <DateTime>{},
      monthErrorsByMonth: const <DateTime, Object>{},
      lastResolvedSelectedMonthStart: monthStart,
    );
    final persistProvider = FutureProvider<void>(
      (ref) => persistWalletsPageState(ref, scope, state),
    );
    final clearProvider = FutureProvider<void>(
      (ref) => clearWalletAnalyticsPageStateCachesForUser(
        ref,
        userId: scope.userId,
      ),
    );
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);

    await container.read(persistProvider.future);
    final cacheKey = walletsPageStateCacheKey(scope);
    expect(prefs.getString(cacheKey), isNotNull);
    expect(
      await database.getJsonCache(
        namespace: 'wallets_page_state',
        cacheKey: cacheKey,
      ),
      isNotNull,
    );

    await container.read(clearProvider.future);

    expect(prefs.getString(cacheKey), isNull);
    expect(
      await database.getJsonCache(
        namespace: 'wallets_page_state',
        cacheKey: cacheKey,
      ),
      isNull,
    );
  });

  test('walletsHistoryProvider delegates to wallets data service', () async {
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final history =
        await container.read(walletsHistoryProvider(buildScope()).future);

    expect(history.availableMonths.first, DateTime(2026, 4, 1));
    expect(service.lastHistoryQuery, buildScope());
    expect(service.historyCalls, 1);
  });

  test('walletsMonthSnapshotProvider delegates to wallets data service',
      () async {
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final query = WalletsMonthQuery(
        scope: buildScope(), monthStart: DateTime(2026, 4, 1));
    final snapshot =
        await container.read(walletsMonthSnapshotProvider(query).future);

    expect(snapshot.netWorthCents, 200);
    expect(service.lastSnapshotQuery, query);
    expect(service.snapshotCalls, 1);
  });

  test('walletsHistoryProvider refreshes when walletsRefreshSignal changes',
      () async {
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final scope = buildScope();
    await container.read(walletsHistoryProvider(scope).future);
    expect(service.historyCalls, 1);

    container.read(walletsRefreshSignalProvider.notifier).state += 1;
    await container.read(walletsHistoryProvider(scope).future);
    expect(service.historyCalls, 2);
  });

  test('SupabaseWalletsDataService fetchHistory uses local account snapshot',
      () async {
    final rpcRunner = _MockWalletsRpcRunner();
    final legacyLoader = _FakeWalletsLegacyDataLoader();
    Map<String, dynamic>? capturedParams;

    when(
      () => rpcRunner.run(
        'get_wallets_history_v2',
        params: any(named: 'params'),
      ),
    ).thenAnswer((invocation) async {
      capturedParams = Map<String, dynamic>.from(
        invocation.namedArguments[#params] as Map<String, dynamic>,
      );
      return {
        'available_months': ['2026-04-01', '2026-03-01'],
        'net_worth_series': [
          {'month_start': '2026-03-01', 'net_worth_cents': 1000},
          {'month_start': '2026-04-01', 'net_worth_cents': 2000},
        ],
      };
    });

    final container = ProviderContainer(overrides: [
      walletsRpcRunnerProvider.overrideWithValue(rpcRunner),
      walletsLegacyDataLoaderProvider.overrideWithValue(legacyLoader),
    ]);
    addTearDown(container.dispose);

    final service = container.read(walletsDataServiceProvider);
    final history = await service.fetchHistory(buildScope());

    expect(capturedParams, isNull);
    expect(history.availableMonths, [DateTime(2026, 4, 1)]);
    expect(history.netWorthSeries.single.netWorthCents, 777);
    expect(legacyLoader.historyCalls, 1);
    expect(legacyLoader.lastHistoryQuery, buildScope());
  });

  test('SupabaseWalletsDataService fetchHistory falls back when v2 RPC missing',
      () async {
    final rpcRunner = _MockWalletsRpcRunner();
    final legacyLoader = _FakeWalletsLegacyDataLoader(
      historyResult: WalletsHistorySummary(
        availableMonths: [DateTime(2026, 4, 1)],
        netWorthSeries: [
          WalletNetWorthPoint(
            monthStart: DateTime(2026, 4, 1),
            netWorthCents: 777,
          ),
        ],
      ),
    );

    when(
      () => rpcRunner.run(
        'get_wallets_history_v2',
        params: any(named: 'params'),
      ),
    ).thenThrow(
      const PostgrestException(
        message: 'function public.get_wallets_history_v2 does not exist',
        code: '42883',
      ),
    );

    final container = ProviderContainer(overrides: [
      walletsRpcRunnerProvider.overrideWithValue(rpcRunner),
      walletsLegacyDataLoaderProvider.overrideWithValue(legacyLoader),
    ]);
    addTearDown(container.dispose);

    final service = container.read(walletsDataServiceProvider);
    final history = await service.fetchHistory(buildScope());

    expect(history.netWorthSeries.single.netWorthCents, 777);
    expect(legacyLoader.historyCalls, 1);
    expect(legacyLoader.lastHistoryQuery, buildScope());
  });

  test('wallets history and snapshot stay inert while auth query is empty',
      () async {
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider.overrideWith((ref) => null),
      walletsDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final emptyScope = WalletsScopeQuery(
      userId: '',
      householdId: null,
      selectedCurrency: 'USD',
      currentMonthStart: DateTime(2026, 4, 1),
    );
    final snapshotQuery = WalletsMonthQuery(
      scope: emptyScope,
      monthStart: DateTime(2026, 4, 1),
    );

    final history =
        await container.read(walletsHistoryProvider(emptyScope).future);
    final snapshot = await container
        .read(walletsMonthSnapshotProvider(snapshotQuery).future);

    expect(service.historyCalls, 0);
    expect(service.snapshotCalls, 0);
    expect(history.availableMonths, [DateTime(2026, 4, 1)]);
    expect(history.netWorthSeries, hasLength(1));
    expect(history.netWorthSeries.single.monthStart, DateTime(2026, 4, 1));
    expect(history.netWorthSeries.single.netWorthCents, 0);
    expect(snapshot.netWorthCents, 0);
    expect(snapshot.incomeTotalCents, 0);
    expect(snapshot.spentTotalCents, 0);
    expect(snapshot.walletBalances, isEmpty);
  });

  test(
      'SupabaseWalletsDataService fetchMonthSnapshot uses local account snapshot',
      () async {
    final rpcRunner = _MockWalletsRpcRunner();
    final legacyLoader = _FakeWalletsLegacyDataLoader();
    final query = WalletsMonthQuery(
      scope: buildScope(),
      monthStart: DateTime(2026, 4, 1),
    );
    Map<String, dynamic>? capturedParams;

    when(
      () => rpcRunner.run(
        'get_wallets_month_snapshot_v2',
        params: any(named: 'params'),
      ),
    ).thenAnswer((invocation) async {
      capturedParams = Map<String, dynamic>.from(
        invocation.namedArguments[#params] as Map<String, dynamic>,
      );
      return {
        'month_start': '2026-04-01',
        'month_end_exclusive': '2026-05-01',
        'income_total_cents': 500,
        'spent_total_cents': 300,
        'net_worth_cents': 1200,
        'wallet_balances': [
          {'wallet_id': 'a1', 'balance_cents': 1200},
        ],
      };
    });

    final container = ProviderContainer(overrides: [
      walletsRpcRunnerProvider.overrideWithValue(rpcRunner),
      walletsLegacyDataLoaderProvider.overrideWithValue(legacyLoader),
    ]);
    addTearDown(container.dispose);

    final service = container.read(walletsDataServiceProvider);
    final snapshot = await service.fetchMonthSnapshot(query);

    expect(capturedParams, isNull);
    expect(snapshot.netWorthCents, 333);
    expect(snapshot.walletBalances, const {'legacy-wallet': 333});
    expect(legacyLoader.snapshotCalls, 1);
    expect(legacyLoader.lastSnapshotQuery, query);
  });

  test(
      'SupabaseWalletsDataService fetchMonthSnapshot falls back when v2 RPC missing',
      () async {
    final rpcRunner = _MockWalletsRpcRunner();
    final query = WalletsMonthQuery(
      scope: buildScope(),
      monthStart: DateTime(2026, 4, 1),
    );
    final legacyLoader = _FakeWalletsLegacyDataLoader(
      snapshotResult: WalletsMonthSnapshot(
        monthStart: query.monthStart,
        monthEndExclusive: DateTime(2026, 5, 1),
        incomeTotalCents: 111,
        spentTotalCents: 22,
        netWorthCents: 333,
        walletBalances: const {'legacy-wallet': 333},
      ),
    );

    when(
      () => rpcRunner.run(
        'get_wallets_month_snapshot_v2',
        params: any(named: 'params'),
      ),
    ).thenThrow(
      const PostgrestException(
        message: 'function public.get_wallets_month_snapshot_v2 does not exist',
        code: '42883',
      ),
    );

    final container = ProviderContainer(overrides: [
      walletsRpcRunnerProvider.overrideWithValue(rpcRunner),
      walletsLegacyDataLoaderProvider.overrideWithValue(legacyLoader),
    ]);
    addTearDown(container.dispose);

    final service = container.read(walletsDataServiceProvider);
    final snapshot = await service.fetchMonthSnapshot(query);

    expect(snapshot.netWorthCents, 333);
    expect(snapshot.walletBalances, const {'legacy-wallet': 333});
    expect(legacyLoader.snapshotCalls, 1);
    expect(legacyLoader.lastSnapshotQuery, query);
  });

  test('local history leaves pending key unapplied without wallet metadata',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final pending = ExpenseEntry(
      id: 'client-record-income-1',
      userId: 'user-1',
      date: DateTime(2026, 4, 12),
      amountCents: 50,
      currency: 'USD',
      category: 'income',
      createdAt: DateTime.utc(2026, 4, 12, 10),
      type: 'income',
      walletId: 'wallet-1',
      clientMutationId: 'mutation-create',
    );
    await database.writeOptimisticTransaction(
      entry: pending,
      clientMutationId: 'mutation-create',
      operation: 'create',
      payload: const {'id': 'client-record-income-1'},
    );
    final scope = buildScope();
    final loadHistoryProvider = FutureProvider<WalletsHistorySummary>(
      (ref) => LocalWalletsLegacyDataLoader(ref).fetchHistory(scope),
    );
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider.overrideWith((ref) => null),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(
        _StaticTransactionsFeedService([pending]),
      ),
      currencyRateTableProvider.overrideWith(
        (ref) async => const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1},
        ),
      ),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await container.read(localDatabaseProvider.future);

    final history = await container.read(loadHistoryProvider.future);

    expect(history.netWorthSeries.last.netWorthCents, 0);
    expect(
      history.netWorthSeries.last.appliedPendingTransactionKeys,
      isNot(contains('client-record-income-1|mutation-create')),
    );

    final pageState =
        await container.read(walletsPageStateProvider(scope).future);
    expect(pageState.history.netWorthSeries.last.netWorthCents, 0);
    expect(pageState.displayedSnapshot?.incomeTotalCents, 50);
    expect(pageState.displayedSnapshot?.netWorthCents, 0);
  });

  test(
      'walletsPageStateProvider bootstraps current month and defers older months',
      () async {
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final state =
        await container.read(walletsPageStateProvider(buildScope()).future);

    expect(
      state.visibleMonths,
      [DateTime(2026, 4, 1), DateTime(2026, 3, 1), DateTime(2026, 2, 1)],
    );
    expect(state.selectedMonthStart, DateTime(2026, 4, 1));
    expect(state.lastResolvedSelectedMonthStart, DateTime(2026, 4, 1));
    expect(
      state.cachedSnapshotsByMonth.keys,
      {DateTime(2026, 4, 1)},
    );
    expect(service.snapshotMonths.first, DateTime(2026, 4, 1));
  });

  test('wallet refresh reconciles the active household transaction feed',
      () async {
    final service = _FakeWalletsDataService();
    final feedService = _RecordingTransactionsFeedService();
    final scope = WalletsScopeQuery(
      userId: 'user-1',
      householdId: 'house-1',
      selectedCurrency: 'USD',
      currentMonthStart: DateTime(2026, 4, 1),
    );
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
      transactionsFeedServiceProvider.overrideWithValue(feedService),
    ]);
    addTearDown(container.dispose);

    final provider = walletsPageStateProvider(scope);
    await container.read(provider.future);
    await container.read(provider.notifier).refresh();

    expect(feedService.refreshCalls, 1);
    expect(feedService.lastRefreshQuery?.householdId, 'house-1');
    expect(feedService.lastRefreshQuery?.selectedType, 'all');
    expect(feedService.lastRefreshQuery?.startDate, isNull);
  });

  test('wallet refresh consumes cache bypass without invalidating its own ref',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final scope = buildScope();
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      sharedPreferencesProvider.overrideWithValue(prefs),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    final provider = walletsPageStateProvider(scope);
    await container.read(provider.future);
    await pumpEventQueue();
    await prefs.remove(walletsPageStateCacheKey(scope));

    container
        .read(walletsPageStatePersistedCacheBypassProvider.notifier)
        .state = 1;
    await container.read(provider.future);
    await container.read(provider.notifier).refresh();
    await pumpEventQueue();

    expect(container.read(walletsPageStatePersistedCacheBypassProvider), 0);
    expect(prefs.getString(walletsPageStateCacheKey(scope)), isNotNull);
    expect(container.read(provider).requireValue.isRefreshing, isFalse);
    expect(container.read(provider).requireValue.displayedSnapshot, isNotNull);
  });

  test('mounted wallet snapshot observes a durable transfer without refresh',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final month = scope.currentMonthStart;
    final initial = _cachedWalletState(
      monthStart: month,
      balanceCents: 10000,
      spentCents: 0,
    );
    final container =
        _offlineWalletContainer(database, scope, sessionState: initial);
    addTearDown(container.dispose);
    final networkSubscription =
        container.listen(networkReachabilityProvider, (_, __) {});
    addTearDown(networkSubscription.close);
    await container.read(localDatabaseProvider.future);
    await container.read(networkReachabilityProvider.future);
    final provider = walletsPageStateProvider(scope);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    await pumpEventQueue();

    final entries = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'optimistic-transfer-test',
        'from_account_id': 'w1',
        'to_account_id': 'other-wallet',
        'amount_cents': 1500,
        'currency': 'USD',
        'date': '2026-04-12',
        'created_by_user_id': scope.userId,
      },
      fallbackUserId: scope.userId,
    );
    await database.writeOptimisticWalletTransfer(
      entries: entries,
      clientMutationId: 'transfer-create',
      entityId: 'optimistic-transfer-test',
      payload: const {'functionName': 'create-wallet-transfer'},
    );
    await pumpEventQueue();

    final state = container.read(provider).requireValue;
    expect(state.displayedSnapshot?.walletBalances['w1'], 8500);
    expect(state.displayedSnapshot?.spentTotalCents, 0);

    await database.markMutationFailed(
      clientMutationId: 'transfer-create',
      error: 'offline',
      retryAfter: DateTime.now().add(const Duration(minutes: 1)),
    );
    await pumpEventQueue();
    expect(
        container
            .read(provider)
            .requireValue
            .displayedSnapshot
            ?.walletBalances['w1'],
        8500);

    await database.replaceOptimisticWalletTransfer(
      optimisticIds: entries.map((entry) => entry.id),
      savedEntries: entries
          .map((entry) => ExpenseEntry.fromJson({
                ...entry.toJson(),
                'id': entry.id
                    .replaceFirst('optimistic-transfer-test', 'canonical'),
              }))
          .toList(),
      clientMutationId: 'transfer-create',
    );
    await pumpEventQueue();
    expect(
        container
            .read(provider)
            .requireValue
            .displayedSnapshot
            ?.walletBalances['w1'],
        8500);

    final secondEntries = entries
        .map((entry) => ExpenseEntry.fromJson({
              ...entry.toJson(),
              'id': entry.id.replaceFirst(
                  'optimistic-transfer-test', 'optimistic-transfer-second'),
              'amount_cents': 500,
            }))
        .toList();
    await database.writeOptimisticWalletTransfer(
      entries: secondEntries,
      clientMutationId: 'transfer-second',
      entityId: 'optimistic-transfer-second',
      payload: const {'functionName': 'create-wallet-transfer'},
    );
    await pumpEventQueue();
    expect(
        container
            .read(provider)
            .requireValue
            .displayedSnapshot
            ?.walletBalances['w1'],
        8000);
    await database.rollbackOptimisticWalletTransfer(
      optimisticIds: secondEntries.map((entry) => entry.id),
      clientMutationId: 'transfer-second',
      error: StateError('terminal rejection'),
    );
    await pumpEventQueue();
    expect(
        container
            .read(provider)
            .requireValue
            .displayedSnapshot
            ?.walletBalances['w1'],
        8500);
  });

  test(
      'walletsPageStateProvider preserves pending local overlay after stale refresh completes',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _StaleRefreshWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final scope = buildScope();
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'Spending',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 10000,
          goalAmountCents: null,
          isDefault: true,
          isSystem: true,
          isArchived: false,
          currentBalanceCents: 10000,
        ),
      ],
    };

    final provider = walletsPageStateProvider(scope);
    final initialState = await container.read(provider.future);
    expect(initialState.displayedSnapshot?.netWorthCents, 10000);

    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'pending_1',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 10),
        type: 'expense',
        walletId: 'w1',
      ),
      clientMutationId: 'mutation-wallet-1',
      operation: 'create',
      payload: const {'id': 'pending_1'},
    );

    final refreshFuture = container.read(provider.notifier).refresh();
    await pumpEventQueue(times: 4);

    final refreshingState = container.read(provider).requireValue;
    expect(refreshingState.isRefreshing, isTrue);
    expect(refreshingState.displayedSnapshot?.netWorthCents, 8500);
    expect(refreshingState.displayedSnapshot?.spentTotalCents, 1500);
    expect(refreshingState.displayedSnapshot?.walletBalances['w1'], 8500);

    service.refreshSnapshotGate.complete();
    await refreshFuture;

    final finalState = container.read(provider).requireValue;
    expect(finalState.isRefreshing, isFalse);
    expect(finalState.displayedSnapshot?.netWorthCents, 8500);
    expect(finalState.displayedSnapshot?.spentTotalCents, 1500);
    expect(finalState.displayedSnapshot?.walletBalances['w1'], 8500);
  });

  test(
      'provider balance ignores whole-row update overlay but includes pending create once',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _StaleRefreshWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final scope = buildScope();
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'PayPal',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 0,
          goalAmountCents: null,
          isDefault: false,
          isSystem: false,
          isArchived: false,
          currentBalanceCents: 10000,
          hasProviderBalance: true,
        ),
      ],
    };

    final original = ExpenseEntry(
      id: 'server-transaction',
      userId: 'user-1',
      date: DateTime(2026, 4, 12),
      amountCents: 1500,
      currency: 'USD',
      category: 'food',
      createdAt: DateTime.utc(2026, 4, 12, 10),
      type: 'expense',
      walletId: 'w1',
      merchant: 'Original',
    );
    await database.upsertTransactions([original]);
    await database.writeOptimisticTransactionUpdate(
      originalEntry: original,
      updatedEntry: original.copyWith(merchant: 'Updated'),
      clientMutationId: 'merchant-update',
      payload: const {
        'expenseId': 'server-transaction',
        'updates': {'merchant': 'Updated'},
      },
    );

    final provider = walletsPageStateProvider(scope);
    var state = await container.read(provider.future);
    expect(state.displayedSnapshot?.walletBalances['w1'], 10000);
    expect(state.displayedSnapshot?.spentTotalCents, 0);

    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'optimistic_create',
        userId: 'user-1',
        date: DateTime(2026, 4, 13),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 13, 10),
        type: 'expense',
        walletId: 'w1',
      ),
      clientMutationId: 'pending-create',
      operation: 'create',
      payload: const {'id': 'optimistic_create'},
    );
    container.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    container.invalidate(provider);
    state = await container.read(provider.future);

    expect(state.displayedSnapshot?.walletBalances['w1'], 8500);
    expect(state.displayedSnapshot?.spentTotalCents, 1500);
  });

  test('production service overlays a pending create added after its snapshot',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final legacyLoader = _FakeWalletsLegacyDataLoader(
      historyResult: WalletsHistorySummary(
        availableMonths: [DateTime(2026, 4, 1)],
        netWorthSeries: [
          WalletNetWorthPoint(
            monthStart: DateTime(2026, 4, 1),
            netWorthCents: 200,
          ),
        ],
      ),
      snapshotResult: WalletsMonthSnapshot(
        monthStart: DateTime(2026, 4, 1),
        monthEndExclusive: DateTime(2026, 5, 1),
        incomeTotalCents: 300,
        spentTotalCents: 100,
        netWorthCents: 200,
        walletBalances: const {'w1': 200},
      ),
    );
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsLegacyDataLoaderProvider.overrideWithValue(legacyLoader),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);
    final scope = buildScope();
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'PayPal',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 200,
          goalAmountCents: null,
          isDefault: false,
          isSystem: false,
          isArchived: false,
          currentBalanceCents: 200,
        ),
      ],
    };
    final provider = walletsPageStateProvider(scope);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    expect(
      (await container.read(provider.future)).displayedSnapshot?.netWorthCents,
      200,
    );

    final pending = ExpenseEntry(
      id: 'client-record-income-1',
      userId: 'user-1',
      date: DateTime(2026, 4, 12),
      amountCents: 50,
      currency: 'USD',
      category: 'food',
      createdAt: DateTime.utc(2026, 4, 12, 10),
      type: 'income',
      walletId: 'w1',
      clientMutationId: 'mutation-create',
    );
    await database.writeOptimisticTransaction(
      entry: pending,
      clientMutationId: 'mutation-create',
      operation: 'create',
      payload: const {'id': 'client-record-income-1'},
    );
    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'client-record-eur-1',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 900,
        currency: 'EUR',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 11),
        type: 'expense',
        walletId: 'w1',
        clientMutationId: 'mutation-eur-create',
      ),
      clientMutationId: 'mutation-eur-create',
      operation: 'create',
      payload: const {'id': 'client-record-eur-1'},
    );
    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'client-record-household-1',
        userId: 'user-1',
        householdId: 'household-1',
        date: DateTime(2026, 4, 12),
        amountCents: 800,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 12),
        type: 'expense',
        walletId: 'w1',
        clientMutationId: 'mutation-household-create',
      ),
      clientMutationId: 'mutation-household-create',
      operation: 'create',
      payload: const {'id': 'client-record-household-1'},
    );
    container
        .read(analyticsProvider.notifier)
        .addOptimisticTransaction(pending);
    await pumpEventQueue(times: 4);

    final state = container.read(provider).requireValue;
    expect(state.history.netWorthSeries.last.netWorthCents, 250);
    expect(state.displayedSnapshot?.netWorthCents, 250);
    expect(state.displayedSnapshot?.walletBalances['w1'], 250);
  });

  test('merchant metadata update contributes zero to cached wallet history',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final monthStart = DateTime(2026, 4, 1);
    await database.upsertJsonCache(
      namespace: 'wallets_page_state',
      cacheKey: walletsPageStateCacheKey(scope),
      payload: _cachedWalletState(
        monthStart: monthStart,
        balanceCents: 8500,
        spentCents: 1500,
      ).toCacheJson(),
    );
    final original = ExpenseEntry(
      id: '4d055fac-88b0-4750-b606-92f37c008975',
      userId: 'user-1',
      date: DateTime(2026, 4, 12),
      amountCents: 1500,
      currency: 'USD',
      category: 'food',
      createdAt: DateTime.utc(2026, 4, 12, 10),
      type: 'expense',
      walletId: 'w1',
      merchant: 'Old',
    );
    await database.upsertTransactions([original]);
    await database.writeOptimisticTransactionUpdate(
      originalEntry: original,
      updatedEntry: original.copyWith(merchant: 'Oura'),
      clientMutationId: 'mutation-merchant',
      payload: {
        'expenseId': original.id,
        'updates': const {'merchant': 'Oura'},
      },
    );
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'PayPal',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 10000,
          goalAmountCents: null,
          isDefault: false,
          isSystem: false,
          isArchived: false,
          currentBalanceCents: 10000,
          hasProviderBalance: true,
        ),
      ],
    };
    await container.read(localDatabaseProvider.future);
    await container.read(networkReachabilityProvider.future);

    final state = await container.read(walletsPageStateProvider(scope).future);

    expect(state.history.netWorthSeries.single.netWorthCents, 8500);
    expect(state.displayedSnapshot?.walletBalances['w1'], 8500);
    expect(state.displayedSnapshot?.netWorthCents, 8500);
    expect(state.displayedSnapshot?.spentTotalCents, 1500);
  });

  test('terminal rollback reverses an applied cached create offline', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final monthStart = DateTime(2026, 4, 1);
    await database.upsertJsonCache(
      namespace: 'wallets_page_state',
      cacheKey: walletsPageStateCacheKey(scope),
      payload: _cachedWalletState(
        monthStart: monthStart,
        balanceCents: 8500,
        spentCents: 1500,
        appliedKeys: const {'optimistic_create|mutation-create'},
      ).toCacheJson(),
    );
    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'optimistic_create',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 10),
        type: 'expense',
        walletId: 'w1',
        clientMutationId: 'mutation-create',
      ),
      clientMutationId: 'mutation-create',
      operation: 'create',
      payload: const {'id': 'optimistic_create'},
    );
    await database.rollbackOptimisticTransaction(
      optimisticId: 'optimistic_create',
      clientMutationId: 'mutation-create',
      error: 'terminal',
    );
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'PayPal',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 10000,
          goalAmountCents: null,
          isDefault: false,
          isSystem: false,
          isArchived: false,
          currentBalanceCents: 10000,
          hasProviderBalance: true,
        ),
      ],
    };
    await container.read(localDatabaseProvider.future);
    await container.read(networkReachabilityProvider.future);

    final state = await container.read(walletsPageStateProvider(scope).future);

    expect(state.history.netWorthSeries.single.netWorthCents, 10000);
    expect(state.displayedSnapshot?.walletBalances['w1'], 10000);
    expect(state.displayedSnapshot?.netWorthCents, 10000);
    expect(state.displayedSnapshot?.spentTotalCents, 0);
  });

  for (final scenario in [
    'two merchant edits',
    'batch then individual',
    'amount edit chain'
  ]) {
    test('$scenario projects one financial difference offline', () async {
      final database = MonekoDatabase.inMemory();
      addTearDown(database.close);
      final scope = buildScope();
      final monthStart = DateTime(2026, 4, 1);
      final initial = _cachedWalletState(
        monthStart: monthStart,
        balanceCents: 8500,
        spentCents: 1500,
      );
      await database.upsertJsonCache(
        namespace: 'wallets_page_state',
        cacheKey: walletsPageStateCacheKey(scope),
        payload: initial.toCacheJson(),
      );
      final original = ExpenseEntry(
        id: '4d055fac-88b0-4750-b606-92f37c008975',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 10),
        type: 'expense',
        walletId: 'w1',
        merchant: 'Old',
      );
      await database.upsertTransactions([original]);
      final first = original.copyWith(merchant: 'First');
      if (scenario == 'batch then individual') {
        await database.writeOptimisticTransactionBatchUpdate(
          originalEntries: [original],
          updatedEntries: [first],
          clientMutationId: 'mutation-batch',
          payload: {
            'transactionIds': [original.id],
            'updates': {'merchant': 'First'},
          },
        );
      } else {
        await database.writeOptimisticTransactionUpdate(
          originalEntry: original,
          updatedEntry: first,
          clientMutationId: 'mutation-first',
          payload: {'expenseId': original.id},
        );
      }
      await database.writeOptimisticTransactionUpdate(
        originalEntry: first.copyWith(
          clientMutationId: scenario == 'batch then individual'
              ? 'mutation-batch'
              : 'mutation-first',
        ),
        updatedEntry: first.copyWith(
          merchant: 'Final',
          amountCents: scenario == 'amount edit chain' ? 1700 : 1500,
        ),
        clientMutationId: 'mutation-second',
        payload: {'expenseId': original.id},
      );
      final container = _offlineWalletContainer(database, scope);
      addTearDown(container.dispose);
      await container.read(localDatabaseProvider.future);
      await container.read(networkReachabilityProvider.future);

      final state =
          await container.read(walletsPageStateProvider(scope).future);
      final expected = scenario == 'amount edit chain' ? 8300 : 8500;
      expect(state.history.netWorthSeries.single.netWorthCents, expected);
      expect(state.displayedSnapshot?.walletBalances['w1'], expected);
      expect(state.displayedSnapshot?.netWorthCents, expected);
      expect(state.displayedSnapshot?.spentTotalCents,
          scenario == 'amount edit chain' ? 1700 : 1500);
    });
  }

  test('delete-only outbox effects update cached history without pending rows',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final original = ExpenseEntry(
      id: '4d055fac-88b0-4750-b606-92f37c008975',
      userId: 'user-1',
      date: DateTime(2026, 4, 12),
      amountCents: 1500,
      currency: 'USD',
      category: 'food',
      createdAt: DateTime.utc(2026, 4, 12, 10),
      type: 'expense',
      walletId: 'w1',
    );
    await database.upsertTransactions([original]);
    await database.writeOptimisticTransactionDelete(
      entries: [original],
      clientMutationId: 'mutation-delete',
      payload: {'expenseId': original.id},
    );
    final container = _offlineWalletContainer(database, scope,
        sessionState: _cachedWalletState(
            monthStart: DateTime(2026, 4, 1),
            balanceCents: 8500,
            spentCents: 1500));
    addTearDown(container.dispose);
    await container.read(localDatabaseProvider.future);
    await container.read(networkReachabilityProvider.future);
    final state = await container.read(walletsPageStateProvider(scope).future);
    expect(state.history.netWorthSeries.single.netWorthCents, 10000);
    expect(state.displayedSnapshot?.walletBalances['w1'], 10000);
    expect(state.displayedSnapshot?.spentTotalCents, 0);
  });

  test('cached first amount edit only applies the later difference', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final original = ExpenseEntry(
      id: '4d055fac-88b0-4750-b606-92f37c008975',
      userId: 'user-1',
      date: DateTime(2026, 4, 12),
      amountCents: 1500,
      currency: 'USD',
      category: 'food',
      createdAt: DateTime.utc(2026, 4, 12, 10),
      type: 'expense',
      walletId: 'w1',
    );
    final first = original.copyWith(amountCents: 1700);
    await database.upsertTransactions([original]);
    await database.writeOptimisticTransactionUpdate(
      originalEntry: original,
      updatedEntry: first,
      clientMutationId: 'mutation-first',
      payload: {'expenseId': original.id},
    );
    final includedKey =
        '${original.id}|mutation-first|2026-04-12|1700|expense|USD|w1|food';
    await database.upsertJsonCache(
      namespace: 'wallets_page_state',
      cacheKey: walletsPageStateCacheKey(scope),
      payload: _cachedWalletState(
        monthStart: DateTime(2026, 4, 1),
        balanceCents: 8300,
        spentCents: 1700,
        appliedKeys: {includedKey},
      ).toCacheJson(),
    );
    await database.writeOptimisticTransactionUpdate(
      originalEntry: first.copyWith(clientMutationId: 'mutation-first'),
      updatedEntry: first.copyWith(amountCents: 1800),
      clientMutationId: 'mutation-second',
      payload: {'expenseId': original.id},
    );
    final container = _offlineWalletContainer(database, scope);
    addTearDown(container.dispose);
    await container.read(localDatabaseProvider.future);
    await container.read(networkReachabilityProvider.future);

    final state = await container.read(walletsPageStateProvider(scope).future);
    expect(state.history.netWorthSeries.single.netWorthCents, 8200);
    expect(state.displayedSnapshot?.netWorthCents, 8200);
    expect(state.displayedSnapshot?.walletBalances['w1'], 8200);
    expect(state.displayedSnapshot?.spentTotalCents, 1800);
  });

  test('terminal rollback rebuilds session and mounted wallet state offline',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final cached = _cachedWalletState(
      monthStart: DateTime(2026, 4, 1),
      balanceCents: 8500,
      spentCents: 1500,
      appliedKeys: const {'optimistic_create|mutation-create'},
    );
    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'optimistic_create',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 10),
        type: 'expense',
        walletId: 'w1',
        clientMutationId: 'mutation-create',
      ),
      clientMutationId: 'mutation-create',
      operation: 'create',
      payload: const {'id': 'optimistic_create'},
    );
    final container =
        _offlineWalletContainer(database, scope, sessionState: cached);
    addTearDown(container.dispose);
    await container.read(localDatabaseProvider.future);
    await container.read(networkReachabilityProvider.future);
    final provider = walletsPageStateProvider(scope);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    expect(
        (await container.read(provider.future))
            .displayedSnapshot
            ?.netWorthCents,
        8500);

    await database.rollbackOptimisticTransaction(
      optimisticId: 'optimistic_create',
      clientMutationId: 'mutation-create',
      error: 'terminal',
    );
    await container.read(provider.notifier).refresh();
    final mounted = container.read(provider).requireValue;
    expect(mounted.history.netWorthSeries.single.netWorthCents, 10000);
    expect(mounted.displayedSnapshot?.walletBalances['w1'], 10000);
    expect(mounted.displayedSnapshot?.spentTotalCents, 0);

    final restored =
        _offlineWalletContainer(database, scope, sessionState: cached);
    addTearDown(restored.dispose);
    await restored.read(localDatabaseProvider.future);
    await restored.read(networkReachabilityProvider.future);
    final restarted =
        await restored.read(walletsPageStateProvider(scope).future);
    expect(restarted.history.netWorthSeries.single.netWorthCents, 10000);
    expect(restarted.displayedSnapshot?.walletBalances['w1'], 10000);
    expect(restarted.displayedSnapshot?.spentTotalCents, 0);
  });

  test('persisted snapshot does not apply the same pending create twice',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final scope = buildScope();
    final monthStart = DateTime(2026, 4, 1);
    final cachedState = WalletsPageState(
      history: WalletsHistorySummary(
        availableMonths: [monthStart],
        netWorthSeries: [
          WalletNetWorthPoint(
            monthStart: monthStart,
            netWorthCents: 8500,
            appliedPendingTransactionKeys: const {
              'optimistic_create|mutation-create',
            },
          ),
        ],
      ),
      visibleMonths: [monthStart],
      selectedMonthStart: monthStart,
      cachedSnapshotsByMonth: {
        monthStart: WalletsMonthSnapshot(
          monthStart: monthStart,
          monthEndExclusive: DateTime(2026, 5, 1),
          incomeTotalCents: 0,
          spentTotalCents: 1500,
          netWorthCents: 8500,
          walletBalances: const {'w1': 8500},
          appliedPendingTransactionKeys: const {
            'optimistic_create|mutation-create',
          },
        ),
      },
      loadingMonths: const <DateTime>{},
      monthErrorsByMonth: const <DateTime, Object>{},
      lastResolvedSelectedMonthStart: monthStart,
    );
    await database.upsertJsonCache(
      namespace: 'wallets_page_state',
      cacheKey: walletsPageStateCacheKey(scope),
      payload: cachedState.toCacheJson(),
    );
    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'optimistic_create',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 10),
        type: 'expense',
        walletId: 'w1',
        clientMutationId: 'mutation-create',
      ),
      clientMutationId: 'mutation-create',
      operation: 'create',
      payload: const {'id': 'optimistic_create'},
    );
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'PayPal',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 10000,
          goalAmountCents: null,
          isDefault: false,
          isSystem: false,
          isArchived: false,
          currentBalanceCents: 10000,
          hasProviderBalance: true,
        ),
      ],
    };
    await container.read(localDatabaseProvider.future);
    await container.read(networkReachabilityProvider.future);

    final state = await container.read(walletsPageStateProvider(scope).future);

    expect(state.displayedSnapshot?.walletBalances['w1'], 8500);
    expect(state.history.netWorthSeries.single.netWorthCents, 8500);
    expect(state.displayedSnapshot?.netWorthCents, 8500);
    expect(state.displayedSnapshot?.spentTotalCents, 1500);
  });

  test(
      'pending local transaction updates excluded wallet balance without changing aggregates',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _UpdatedWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final scope = buildScope();
    final monthStart = DateTime(2026, 4, 1);
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'Reserve',
          icon: 'savings',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 10000,
          goalAmountCents: null,
          isDefault: false,
          isSystem: false,
          isArchived: false,
          currentBalanceCents: 10000,
          excludeFromAnalytics: true,
        ),
      ],
    };
    container.read(walletsPageStateSessionCacheProvider.notifier).state = {
      walletsPageStateCacheKey(scope): WalletsPageState(
        history: WalletsHistorySummary(
          availableMonths: [monthStart],
          netWorthSeries: [
            WalletNetWorthPoint(monthStart: monthStart, netWorthCents: 0),
          ],
        ),
        visibleMonths: [monthStart],
        selectedMonthStart: monthStart,
        cachedSnapshotsByMonth: {
          monthStart: WalletsMonthSnapshot(
            monthStart: monthStart,
            monthEndExclusive: DateTime(2026, 5, 1),
            incomeTotalCents: 0,
            spentTotalCents: 0,
            netWorthCents: 0,
            walletBalances: const {'w1': 10000},
          ),
        },
        loadingMonths: const <DateTime>{},
        monthErrorsByMonth: const <DateTime, Object>{},
        lastResolvedSelectedMonthStart: monthStart,
      ),
    };
    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'pending_excluded',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 10),
        type: 'expense',
        walletId: 'w1',
      ),
      clientMutationId: 'mutation-excluded-wallet',
      operation: 'create',
      payload: const {'id': 'pending_excluded'},
    );

    container.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    final state = await container.read(walletsPageStateProvider(scope).future);

    expect(service.historyCalls, 0);
    expect(service.snapshotCalls, 0);
    expect(state.history.netWorthSeries.single.netWorthCents, 0);
    expect(state.displayedSnapshot?.netWorthCents, 0);
    expect(state.displayedSnapshot?.spentTotalCents, 0);
    expect(state.displayedSnapshot?.walletBalances['w1'], 8500);
  });

  test(
      'walletsPageStateProvider reacts to provider state after durable local write',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _FakeWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final scope = buildScope();
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'Spending',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 200,
          goalAmountCents: null,
          isDefault: true,
          isSystem: true,
          isArchived: false,
          currentBalanceCents: 200,
        ),
      ],
    };
    final provider = walletsPageStateProvider(scope);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);

    final initialState = await container.read(provider.future);
    expect(initialState.displayedSnapshot?.netWorthCents, 200);
    expect(initialState.displayedSnapshot?.walletBalances['w1'], 200);
    await pumpEventQueue(times: 4);
    final historyCallsBeforeOptimistic = service.historyCalls;
    final snapshotCallsBeforeOptimistic = service.snapshotCalls;

    final optimisticEntry = ExpenseEntry(
      id: 'optimistic_ai_1',
      userId: 'user-1',
      date: DateTime(2026, 4, 12),
      amountCents: 50,
      currency: 'USD',
      category: 'food',
      createdAt: DateTime.utc(2026, 4, 12, 10),
      type: 'expense',
      walletId: 'w1',
    );
    await database.writeOptimisticTransaction(
      entry: optimisticEntry,
      clientMutationId: 'mutation-ai-1',
      operation: 'create',
      payload: const {'id': 'optimistic_ai_1'},
    );

    container.read(analyticsProvider.notifier).addOptimisticTransaction(
          optimisticEntry,
        );
    await pumpEventQueue(times: 4);

    final overlaidState = container.read(provider).requireValue;
    expect(service.historyCalls, historyCallsBeforeOptimistic);
    expect(service.snapshotCalls, snapshotCallsBeforeOptimistic);
    expect(overlaidState.displayedSnapshot?.netWorthCents, 150);
    expect(overlaidState.displayedSnapshot?.spentTotalCents, 150);
    expect(overlaidState.displayedSnapshot?.walletBalances['w1'], 150);
  });

  test(
      'walletsPageStateProvider keeps cached snapshot and overlays local transaction after refresh signal',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _UpdatedWalletsDataService();
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: <String>{},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final scope = buildScope();
    final monthStart = DateTime(2026, 4, 1);
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.selectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const [
        WalletEntity(
          id: 'w1',
          userId: 'user-1',
          householdId: null,
          name: 'Spending',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'USD',
          openingBalanceCents: 10000,
          goalAmountCents: null,
          isDefault: true,
          isSystem: true,
          isArchived: false,
          currentBalanceCents: 10000,
        ),
      ],
    };
    container.read(walletsPageStateSessionCacheProvider.notifier).state = {
      walletsPageStateCacheKey(scope): WalletsPageState(
        history: WalletsHistorySummary(
          availableMonths: [monthStart],
          netWorthSeries: [
            WalletNetWorthPoint(
              monthStart: monthStart,
              netWorthCents: 10000,
            ),
          ],
        ),
        visibleMonths: [monthStart],
        selectedMonthStart: monthStart,
        cachedSnapshotsByMonth: {
          monthStart: WalletsMonthSnapshot(
            monthStart: monthStart,
            monthEndExclusive: DateTime(2026, 5, 1),
            incomeTotalCents: 0,
            spentTotalCents: 0,
            netWorthCents: 10000,
            walletBalances: const {'w1': 10000},
          ),
        },
        loadingMonths: const <DateTime>{},
        monthErrorsByMonth: const <DateTime, Object>{},
        lastResolvedSelectedMonthStart: monthStart,
      ),
    };
    await database.writeOptimisticTransaction(
      entry: ExpenseEntry(
        id: 'pending_1',
        userId: 'user-1',
        date: DateTime(2026, 4, 12),
        amountCents: 1500,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 12, 10),
        type: 'expense',
        walletId: 'w1',
      ),
      clientMutationId: 'mutation-wallet-signal-1',
      operation: 'create',
      payload: const {'id': 'pending_1'},
    );

    container.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;

    final state = await container.read(walletsPageStateProvider(scope).future);

    expect(service.historyCalls, 0);
    expect(service.snapshotCalls, 0);
    expect(state.displayedSnapshot?.netWorthCents, 8500);
    expect(state.displayedSnapshot?.spentTotalCents, 1500);
    expect(state.displayedSnapshot?.walletBalances['w1'], 8500);
  });

  test(
      'walletsPageStateProvider appends older batch and preserves last resolved month while loading uncached month',
      () async {
    final januaryCompleter = Completer<void>();
    final service = _SelectiveDelayWalletsDataService(
      delayedMonths: <DateTime, Completer<void>>{
        DateTime(2026, 1, 1): januaryCompleter,
      },
    );
    final container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletsDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final provider = walletsPageStateProvider(buildScope());
    await container.read(provider.future);

    final notifier = container.read(provider.notifier);
    await notifier.selectMonth(DateTime(2026, 2, 1));
    await notifier.selectMonth(DateTime(2026, 1, 1));

    final loadingState = container.read(provider).requireValue;
    expect(
      loadingState.visibleMonths,
      [
        DateTime(2026, 4, 1),
        DateTime(2026, 3, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 1, 1),
        DateTime(2025, 12, 1),
        DateTime(2025, 11, 1),
      ],
    );
    expect(loadingState.selectedMonthStart, DateTime(2026, 1, 1));
    expect(loadingState.lastResolvedSelectedMonthStart, DateTime(2026, 2, 1));
    expect(loadingState.loadingMonths, contains(DateTime(2026, 1, 1)));

    januaryCompleter.complete();
    await pumpEventQueue();

    final resolvedState = container.read(provider).requireValue;
    expect(resolvedState.lastResolvedSelectedMonthStart, DateTime(2026, 1, 1));
    expect(
        resolvedState.cachedSnapshotsByMonth, contains(DateTime(2026, 1, 1)));
  });
}

class _SelectiveDelayWalletsDataService extends _FakeWalletsDataService {
  _SelectiveDelayWalletsDataService({required this.delayedMonths});

  final Map<DateTime, Completer<void>> delayedMonths;

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    final completer = delayedMonths[query.monthStart];
    if (completer != null) {
      await completer.future;
    }
    return super.fetchMonthSnapshot(query);
  }
}
