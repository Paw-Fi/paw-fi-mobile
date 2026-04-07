import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';

void main() {
  WalletEntity wallet({
    required String id,
    required int opening,
    bool isDefault = false,
    bool isSystem = false,
  }) {
    return WalletEntity(
      id: id,
      userId: 'user-1',
      householdId: null,
      name: isSystem ? 'Spending' : id,
      icon: 'wallet',
      color: '#6B7280',
      openingBalanceCents: opening,
      goalAmountCents: null,
      isDefault: isDefault,
      isSystem: isSystem,
      isArchived: false,
      currentBalanceCents: opening,
    );
  }

  ExpenseEntry tx({
    required String id,
    required DateTime date,
    required int cents,
    required String type,
    String? walletId,
    String? householdId,
    String currency = 'USD',
    bool isRecurring = false,
  }) {
    return ExpenseEntry(
      id: id,
      date: date,
      amountCents: cents,
      createdAt: date,
      type: type,
      currency: currency,
      householdId: householdId,
      walletId: walletId,
      isRecurring: isRecurring,
    );
  }

  HouseholdScope personalScope() => const HouseholdScope(
        viewMode: ViewMode.personal,
        selected: SelectedHouseholdState(),
        portfolioHouseholdIds: <String>{},
      );

  test('buildWalletSnapshot is cumulative through selected month end', () {
    final wallets = [wallet(id: 'w1', opening: 10000, isDefault: true)];
    final transactions = [
      tx(
          id: 'i1',
          date: DateTime(2026, 3, 10),
          cents: 5000,
          type: 'income',
          walletId: 'w1'),
      tx(
          id: 'e1',
          date: DateTime(2026, 4, 10),
          cents: 2000,
          type: 'expense',
          walletId: 'w1'),
      tx(
          id: 'e2',
          date: DateTime(2026, 5, 1),
          cents: 9999,
          type: 'expense',
          walletId: 'w1'),
    ];

    final snapshot = buildWalletSnapshot(
      wallets: wallets,
      transactions: transactions,
      endExclusive: DateTime(2026, 5, 1),
    );

    expect(snapshot.totalIncomeCents, 5000);
    expect(snapshot.totalSpentCents, 2000);
    expect(snapshot.walletBalances['w1'], 13000);
    expect(snapshot.netWorthCents, 13000);
  });

  test(
      'filterWalletTransactions applies scope, currency and recurring exclusion',
      () {
    final filtered = filterWalletTransactions(
      allExpenses: [
        tx(
            id: 'ok',
            date: DateTime(2026, 4, 1),
            cents: 1000,
            type: 'expense',
            currency: 'USD'),
        tx(
            id: 'rec',
            date: DateTime(2026, 4, 1),
            cents: 1000,
            type: 'expense',
            currency: 'USD',
            isRecurring: true),
        tx(
            id: 'eur',
            date: DateTime(2026, 4, 1),
            cents: 1000,
            type: 'expense',
            currency: 'EUR'),
        tx(
            id: 'hh',
            date: DateTime(2026, 4, 1),
            cents: 1000,
            type: 'expense',
            currency: 'USD',
            householdId: 'h1'),
      ],
      scope: personalScope(),
      selectedCurrency: 'USD',
    );

    expect(filtered.map((e) => e.id).toList(), ['ok']);
  });

  test('buildWalletSnapshot uses legacy fallback for null wallet id', () {
    final wallets = [
      wallet(id: 'sys', opening: 10000, isSystem: true),
      wallet(id: 'd1', opening: 20000, isDefault: true),
    ];
    final snapshot = buildWalletSnapshot(
      wallets: wallets,
      transactions: [
        tx(id: 'x1', date: DateTime(2026, 4, 5), cents: 3000, type: 'expense'),
      ],
      endExclusive: DateTime(2026, 5, 1),
    );

    expect(snapshot.walletBalances['sys'], 7000);
    expect(snapshot.walletBalances['d1'], 20000);
    expect(snapshot.netWorthCents, 27000);
  });

  test('buildWalletAvailableMonths returns earliest to current shape', () {
    final months = buildWalletAvailableMonths(
      now: DateTime(2026, 4, 20),
      transactions: [
        tx(id: 'm1', date: DateTime(2026, 2, 10), cents: 100, type: 'expense'),
        tx(
            id: 'future',
            date: DateTime(2026, 7, 10),
            cents: 100,
            type: 'expense'),
      ],
    );

    expect(months, [
      DateTime(2026, 4, 1),
      DateTime(2026, 3, 1),
      DateTime(2026, 2, 1),
    ]);
  });
}
