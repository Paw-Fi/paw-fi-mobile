import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';

void main() {
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
      });
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
