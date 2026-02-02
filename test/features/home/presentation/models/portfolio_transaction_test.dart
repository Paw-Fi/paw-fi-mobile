import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

void main() {
  group('Portfolio Transaction Tests', () {
    test('Personal transaction has null household_id', () {
      final transaction = ExpenseEntry(
        id: 'tx_1',
        userId: 'user_1',
        amountCents: 5000, // $50.00
        currency: 'USD',
        category: 'food',
        date: DateTime(2024, 1, 1),
        householdId: null, // Personal transaction
        createdAt: DateTime(2024, 1, 1),
      );

      expect(transaction.householdId, null);
      expect(transaction.amount, 50.0);
    });

    test(
        'Portfolio transaction has non-null household_id but should be treated as personal',
        () {
      // This represents a transaction in a portfolio household
      final transaction = ExpenseEntry(
        id: 'tx_2',
        userId: 'user_1',
        amountCents: 10000, // $100.00
        currency: 'USD',
        category: 'investment',
        date: DateTime(2024, 1, 1),
        householdId: 'portfolio_1', // Portfolio household ID
        createdAt: DateTime(2024, 1, 1),
      );

      expect(transaction.householdId, 'portfolio_1');
      // Note: The ExpenseEntry itself doesn't know if it's a portfolio
      // That logic is handled by householdScopeProvider
    });

    test(
        'True household transaction has non-null household_id and is not portfolio',
        () {
      final transaction = ExpenseEntry(
        id: 'tx_3',
        userId: 'user_1',
        amountCents: 20000, // $200.00
        currency: 'USD',
        category: 'groceries',
        date: DateTime(2024, 1, 1),
        householdId: 'household_1', // Regular household ID
        createdAt: DateTime(2024, 1, 1),
      );

      expect(transaction.householdId, 'household_1');
    });

    test('Transaction filtering logic - personal includes null and portfolio',
        () {
      final transactions = [
        ExpenseEntry(
          id: 'tx_1',
          userId: 'user_1',
          amountCents: 5000,
          currency: 'USD',
          category: 'food',
          date: DateTime(2024, 1, 1),
          householdId: null, // Personal
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_2',
          userId: 'user_1',
          amountCents: 10000,
          currency: 'USD',
          category: 'investment',
          date: DateTime(2024, 1, 1),
          householdId: 'portfolio_1', // Portfolio
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_3',
          userId: 'user_1',
          amountCents: 20000,
          currency: 'USD',
          category: 'groceries',
          date: DateTime(2024, 1, 1),
          householdId: 'household_1', // True household
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final portfolioHouseholdIds = {'portfolio_1'};

      // Filter for personal transactions (null OR in portfolio set)
      final personalTransactions = transactions.where((tx) {
        return tx.householdId == null ||
            portfolioHouseholdIds.contains(tx.householdId);
      }).toList();

      expect(personalTransactions.length, 2);
      expect(personalTransactions.map((t) => t.id), ['tx_1', 'tx_2']);
    });

    test('Transaction filtering logic - household excludes null and portfolio',
        () {
      final transactions = [
        ExpenseEntry(
          id: 'tx_1',
          userId: 'user_1',
          amountCents: 5000,
          currency: 'USD',
          category: 'food',
          date: DateTime(2024, 1, 1),
          householdId: null,
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_2',
          userId: 'user_1',
          amountCents: 10000,
          currency: 'USD',
          category: 'investment',
          date: DateTime(2024, 1, 1),
          householdId: 'portfolio_1',
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_3',
          userId: 'user_1',
          amountCents: 20000,
          currency: 'USD',
          category: 'groceries',
          date: DateTime(2024, 1, 1),
          householdId: 'household_1',
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final portfolioHouseholdIds = {'portfolio_1'};

      // Filter for true household transactions (not null AND not in portfolio set)
      final householdTransactions = transactions.where((tx) {
        return tx.householdId != null &&
            !portfolioHouseholdIds.contains(tx.householdId);
      }).toList();

      expect(householdTransactions.length, 1);
      expect(householdTransactions.first.id, 'tx_3');
      expect(householdTransactions.first.householdId, 'household_1');
    });

    test('Transaction update preserves household_id for portfolio', () {
      final original = ExpenseEntry(
        id: 'tx_1',
        userId: 'user_1',
        amountCents: 10000,
        currency: 'USD',
        category: 'investment',
        date: DateTime(2024, 1, 1),
        householdId: 'portfolio_1',
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        amountCents: 15000,
        category: 'stocks',
      );

      expect(updated.householdId, 'portfolio_1');
      expect(updated.amount, 150.0);
      expect(updated.category, 'stocks');
    });

    test('Transaction fromJson correctly parses portfolio transaction', () {
      final json = {
        'id': 'tx_1',
        'user_id': 'user_1',
        'amount_cents': 10000,
        'currency': 'USD',
        'category': 'investment',
        'date': '2024-01-01T00:00:00.000Z',
        'household_id': 'portfolio_1',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final transaction = ExpenseEntry.fromJson(json);

      expect(transaction.householdId, 'portfolio_1');
      expect(transaction.amount, 100.0);
    });

    test('Multiple portfolio households are handled correctly', () {
      final transactions = [
        ExpenseEntry(
          id: 'tx_1',
          userId: 'user_1',
          amountCents: 5000,
          currency: 'USD',
          category: 'stocks',
          date: DateTime(2024, 1, 1),
          householdId: 'portfolio_1',
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_2',
          userId: 'user_1',
          amountCents: 10000,
          currency: 'USD',
          category: 'crypto',
          date: DateTime(2024, 1, 1),
          householdId: 'portfolio_2',
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_3',
          userId: 'user_1',
          amountCents: 20000,
          currency: 'USD',
          category: 'groceries',
          date: DateTime(2024, 1, 1),
          householdId: 'household_1',
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final portfolioHouseholdIds = {'portfolio_1', 'portfolio_2'};

      final personalTransactions = transactions.where((tx) {
        return tx.householdId == null ||
            portfolioHouseholdIds.contains(tx.householdId);
      }).toList();

      expect(personalTransactions.length, 2);
      expect(personalTransactions.map((t) => t.householdId),
          ['portfolio_1', 'portfolio_2']);
    });
  });

  group('Portfolio Transaction Display Tests', () {
    test('Personal view shows null household_id transactions', () {
      final personalTransaction = ExpenseEntry(
        id: 'tx_1',
        userId: 'user_1',
        amountCents: 5000,
        currency: 'USD',
        category: 'food',
        date: DateTime(2024, 1, 1),
        householdId: null,
        createdAt: DateTime(2024, 1, 1),
      );

      final portfolioIds = <String>{};

      // Should be shown in personal view
      final isPersonal = personalTransaction.householdId == null ||
          portfolioIds.contains(personalTransaction.householdId);

      expect(isPersonal, true);
    });

    test('Personal view shows portfolio household transactions', () {
      final portfolioTransaction = ExpenseEntry(
        id: 'tx_1',
        userId: 'user_1',
        amountCents: 10000,
        currency: 'USD',
        category: 'investment',
        date: DateTime(2024, 1, 1),
        householdId: 'portfolio_1',
        createdAt: DateTime(2024, 1, 1),
      );

      final portfolioIds = {'portfolio_1'};

      // Should be shown in personal view
      final isPersonal = portfolioTransaction.householdId == null ||
          portfolioIds.contains(portfolioTransaction.householdId);

      expect(isPersonal, true);
    });

    test('Personal view hides true household transactions', () {
      final householdTransaction = ExpenseEntry(
        id: 'tx_1',
        userId: 'user_1',
        amountCents: 20000,
        currency: 'USD',
        category: 'groceries',
        date: DateTime(2024, 1, 1),
        householdId: 'household_1',
        createdAt: DateTime(2024, 1, 1),
      );

      final portfolioIds = {'portfolio_1'};

      // Should NOT be shown in personal view
      final isPersonal = householdTransaction.householdId == null ||
          portfolioIds.contains(householdTransaction.householdId);

      expect(isPersonal, false);
    });

    test('Household view shows only true household transactions', () {
      final transactions = [
        ExpenseEntry(
          id: 'tx_1',
          userId: 'user_1',
          amountCents: 5000,
          currency: 'USD',
          category: 'food',
          date: DateTime(2024, 1, 1),
          householdId: null,
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_2',
          userId: 'user_1',
          amountCents: 10000,
          currency: 'USD',
          category: 'investment',
          date: DateTime(2024, 1, 1),
          householdId: 'portfolio_1',
          createdAt: DateTime(2024, 1, 1),
        ),
        ExpenseEntry(
          id: 'tx_3',
          userId: 'user_1',
          amountCents: 20000,
          currency: 'USD',
          category: 'groceries',
          date: DateTime(2024, 1, 1),
          householdId: 'household_1',
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      const portfolioIds = {'portfolio_1'};
      const selectedHouseholdId = 'household_1';

      // Household view: show only transactions for the selected household
      // that are NOT portfolio households
      final householdViewTransactions = transactions.where((tx) {
        return tx.householdId == selectedHouseholdId &&
            !portfolioIds.contains(tx.householdId);
      }).toList();

      expect(householdViewTransactions.length, 1);
      expect(householdViewTransactions.first.id, 'tx_3');
    });
  });
}
