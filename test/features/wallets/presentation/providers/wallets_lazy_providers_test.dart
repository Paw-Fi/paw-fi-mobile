import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';

class _FakeWalletsDataService implements WalletsDataService {
  int historyCalls = 0;
  int snapshotCalls = 0;
  WalletsScopeQuery? lastHistoryQuery;
  WalletsMonthQuery? lastSnapshotQuery;

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
}
