import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockWalletsRpcRunner extends Mock implements WalletsRpcRunner {}

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

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  WalletsScopeQuery buildScope() => WalletsScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        currentMonthStart: DateTime(2026, 4, 1),
      );

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
      'walletsPageStateProvider overlays in-memory optimistic transaction before local database write',
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

    final provider = walletsPageStateProvider(buildScope());
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
