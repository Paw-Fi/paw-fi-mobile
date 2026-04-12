import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
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

  test('SupabaseWalletsDataService fetchHistory prefers v2 RPC payload',
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

    expect(capturedParams, buildScope().toHistoryRpcParams());
    expect(
      history.availableMonths,
      [DateTime(2026, 4, 1), DateTime(2026, 3, 1)],
    );
    expect(history.netWorthSeries.last.netWorthCents, 2000);
    expect(legacyLoader.historyCalls, 0);
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

  test('SupabaseWalletsDataService fetchMonthSnapshot prefers v2 RPC payload',
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

    expect(capturedParams, query.toRpcParams());
    expect(snapshot.netWorthCents, 1200);
    expect(snapshot.walletBalances, const {'a1': 1200});
    expect(legacyLoader.snapshotCalls, 0);
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
