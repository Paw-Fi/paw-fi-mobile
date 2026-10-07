import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';

void main() {
  test('negative balances survive RPC parsing and page cache round-trip', () {
    final month = DateTime(2026, 4);
    final snapshot = WalletsMonthSnapshot.fromJson({
      'month_start': '2026-04-01',
      'month_end_exclusive': '2026-05-01',
      'income_total_cents': 0,
      'spent_total_cents': 0,
      'net_worth_cents': -7500,
      'wallet_balances': [
        {'wallet_id': 'debt', 'balance_cents': -7500},
      ],
    });
    final state = WalletsPageState(
      history: WalletsHistorySummary(
        availableMonths: [month],
        netWorthSeries: [
          WalletNetWorthPoint(monthStart: month, netWorthCents: -7500),
        ],
      ),
      visibleMonths: [month],
      selectedMonthStart: month,
      cachedSnapshotsByMonth: {month: snapshot},
      loadingMonths: const {},
      monthErrorsByMonth: const {},
      lastResolvedSelectedMonthStart: month,
    );
    final restored = WalletsPageState.fromCacheJson(state.toCacheJson());
    expect(restored.displayedSnapshot?.walletBalances['debt'], -7500);
    expect(restored.displayedSnapshot?.netWorthCents, -7500);
    expect(restored.history.netWorthSeries.single.netWorthCents, -7500);
  });

  group('WalletsScopeQuery', () {
    test('normalizes month and keeps equality/hash stable', () {
      final a = WalletsScopeQuery(
        userId: 'user-1',
        householdId: 'house-1',
        selectedCurrency: 'USD',
        currentMonthStart: DateTime(2026, 4, 29, 12, 1),
      );
      final b = WalletsScopeQuery(
        userId: 'user-1',
        householdId: 'house-1',
        selectedCurrency: 'USD',
        currentMonthStart: DateTime(2026, 4, 1),
      );

      expect(a.currentMonthStart, DateTime(2026, 4, 1));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toHistoryRpcParams()['p_current_month_start'], '2026-04-01');
    });

    test('normalizes custom financial cycle anchors and keys by start day', () {
      final a = WalletsScopeQuery(
        userId: 'user-1',
        householdId: 'house-1',
        selectedCurrency: 'USD',
        currentMonthStart: DateTime(2026, 8, 10),
        financialMonthStartDay: 25,
      );
      final b = WalletsScopeQuery(
        userId: 'user-1',
        householdId: 'house-1',
        selectedCurrency: 'USD',
        currentMonthStart: DateTime(2026, 7, 25),
        financialMonthStartDay: 25,
      );
      final calendar = WalletsScopeQuery(
        userId: 'user-1',
        householdId: 'house-1',
        selectedCurrency: 'USD',
        currentMonthStart: DateTime(2026, 8, 10),
      );

      expect(a.currentMonthStart, DateTime(2026, 7, 25));
      expect(a, b);
      expect(a, isNot(calendar));
      expect(a.toHistoryRpcParams()['p_current_month_start'], '2026-07-25');
      expect(a.toHistoryRpcParams()['p_financial_month_start_day'], 25);
    });
  });

  group('WalletsMonthQuery', () {
    test('normalizes month and maps rpc params', () {
      final scope = WalletsScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'EUR',
        currentMonthStart: DateTime(2026, 4, 1),
      );
      final query = WalletsMonthQuery(
        scope: scope,
        monthStart: DateTime(2026, 3, 28, 23),
      );

      expect(query.monthStart, DateTime(2026, 3, 1));
      expect(query.toRpcParams(), {
        'p_user_id': 'user-1',
        'p_household_id': null,
        'p_currency': 'EUR',
        'p_month_start': '2026-03-01',
        'p_include_archived': false,
        'p_financial_month_start_day': 1,
      });
    });

    test('normalizes month query to a custom financial cycle', () {
      final scope = WalletsScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'EUR',
        currentMonthStart: DateTime(2026, 8, 10),
        financialMonthStartDay: 25,
      );
      final query = WalletsMonthQuery(
        scope: scope,
        monthStart: DateTime(2026, 8, 24, 23),
      );

      expect(query.monthStart, DateTime(2026, 7, 25));
      expect(query.toRpcParams()['p_month_start'], '2026-07-25');
      expect(query.toRpcParams()['p_financial_month_start_day'], 25);
    });
  });

  test('WalletsMonthSnapshot parses rpc payload', () {
    final snapshot = WalletsMonthSnapshot.fromJson({
      'month_start': '2026-04-01',
      'month_end_exclusive': '2026-05-01',
      'income_total_cents': 540000,
      'spent_total_cents': 240000,
      'net_worth_cents': 300000,
      'wallet_balances': [
        {'wallet_id': 'w1', 'balance_cents': 180000},
        {'wallet_id': 'w2', 'balance_cents': 120000},
      ],
    });

    expect(snapshot.monthStart, DateTime(2026, 4, 1));
    expect(snapshot.monthEndExclusive, DateTime(2026, 5, 1));
    expect(snapshot.incomeTotalCents, 540000);
    expect(snapshot.spentTotalCents, 240000);
    expect(snapshot.netWorthCents, 300000);
    expect(snapshot.walletBalances, {'w1': 180000, 'w2': 120000});
  });

  test('WalletsHistorySummary parses available months and series', () {
    final history = WalletsHistorySummary.fromJson({
      'available_months': ['2026-04-01', '2026-03-01', '2026-02-01'],
      'net_worth_series': [
        {'month_start': '2026-02-01', 'net_worth_cents': 220000},
        {'month_start': '2026-03-01', 'net_worth_cents': 260000},
        {'month_start': '2026-04-01', 'net_worth_cents': 300000},
      ],
    });

    expect(history.availableMonths, [
      DateTime(2026, 4, 1),
      DateTime(2026, 3, 1),
      DateTime(2026, 2, 1),
    ]);
    expect(history.netWorthSeries.length, 3);
    expect(history.netWorthSeries.last.netWorthCents, 300000);
  });
}
