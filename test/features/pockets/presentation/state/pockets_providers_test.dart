import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

void main() {
  group('rebalancePocketBudgetAmounts', () {
    test('preserves pocket shares when total budget increases', () {
      final result = rebalancePocketBudgetAmounts(
        currentAmountsCents: const [60000, 40000],
        newTotalBudgetCents: 200000,
      );

      expect(result, const [120000, 80000]);
      expect(result.fold<int>(0, (sum, amount) => sum + amount), 200000);
    });

    test('keeps total exact after rounding', () {
      final result = rebalancePocketBudgetAmounts(
        currentAmountsCents: const [3333, 3333, 3334],
        newTotalBudgetCents: 10001,
      );

      expect(result.fold<int>(0, (sum, amount) => sum + amount), 10001);
      expect(result, const [3333, 3333, 3335]);
    });

    test('splits evenly when all pockets start at zero', () {
      final result = rebalancePocketBudgetAmounts(
        currentAmountsCents: const [0, 0],
        newTotalBudgetCents: 100000,
      );

      expect(result, const [50000, 50000]);
      expect(result.fold<int>(0, (sum, amount) => sum + amount), 100000);
    });
  });

  group('applyRebalancedBudgetToPocketsState', () {
    test('updates editing pockets proportionally and preserves saved pockets',
        () {
      final now = DateTime(2026, 1, 1);
      final saved = [
        PocketEnvelope(
          id: 'a',
          name: 'Pocket A',
          budgetAmountCents: 60000,
          spent: 0,
          currency: 'USD',
          lastUpdated: now,
        ),
        PocketEnvelope(
          id: 'b',
          name: 'Pocket B',
          budgetAmountCents: 40000,
          spent: 0,
          currency: 'USD',
          lastUpdated: now,
        ),
      ];
      final editing = [
        saved[0].copyWith(),
        saved[1].copyWith(),
      ];
      final state = PocketsState(
        isLoading: false,
        saved: saved,
        editing: editing,
        budgetId: 'budget-1',
        periodMonth: now,
        previousBudget: 0,
        hasPreviousMonthPockets: false,
        currency: 'USD',
        totalBudget: 1000,
        savedTotalBudget: 1000,
        unallocatedSpend: 0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      final updated = applyRebalancedBudgetToPocketsState(
        state: state,
        newTotalBudget: 2000,
      );

      expect(updated.totalBudget, 2000);
      expect(
        updated.editing.map((pocket) => pocket.budgetAmountCents).toList(),
        const [120000, 80000],
      );
      expect(
        updated.saved.map((pocket) => pocket.budgetAmountCents).toList(),
        const [60000, 40000],
      );
      expect(updated.hasChanges, isTrue);
    });
  });

  group('buildUniqueEnvelopeCategoryLinks', () {
    test('normalizes template pocket names before persistence', () {
      expect(normalizePocketTemplateName('  Groceries  '), 'Groceries');
    });

    test('normalizes and deduplicates category links', () {
      final result = buildUniqueEnvelopeCategoryLinks(
        envelopeId: 'env-1',
        categories: const ['Food', ' food ', 'Bills', '', 'BILLS'],
      );

      expect(result, const [
        {'envelope_id': 'env-1', 'category': 'food'},
        {'envelope_id': 'env-1', 'category': 'bills'},
      ]);
    });
  });

  group('PocketsScopeParams', () {
    test('toggle participates in equality so providers refresh on change', () {
      final baseParams = PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 3, 1),
        currency: 'GBP',
      );
      final forecastParams = PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 3, 1),
        currency: 'GBP',
        includeUpcomingRecurring: true,
      );

      expect(baseParams, isNot(forecastParams));
      expect(baseParams.hashCode, isNot(forecastParams.hashCode));
    });
  });
}
