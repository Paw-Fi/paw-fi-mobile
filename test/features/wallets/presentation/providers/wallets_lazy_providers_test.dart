import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';

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

void main() {
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

  test('walletsPageStateProvider bootstraps current month plus two previous',
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
    expect(state.cachedSnapshotsByMonth.keys, state.visibleMonths.toSet());
    expect(service.snapshotMonths, state.visibleMonths);
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
