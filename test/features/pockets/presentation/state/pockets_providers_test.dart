import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/utils/pocket_budget_amount_steps.dart';
import 'package:moneko/features/utils/currency.dart';

void main() {
  group('applySplitPayerToRecurringRows', () {
    test('injects payer_user_id from split group mapping when missing', () {
      final rows = [
        {
          'id': 'exp-1',
          'split_group_id': 'sg-1',
          'user_id': 'creator-1',
        }
      ];

      final result = applySplitPayerToRecurringRows(
        rows: rows,
        splitPayerByGroupId: const {'sg-1': 'payer-1'},
      );

      expect(result.single['payer_user_id'], 'payer-1');
      expect(result.single['user_id'], 'creator-1');
    });

    test('does not overwrite existing payer_user_id', () {
      final rows = [
        {
          'id': 'exp-1',
          'split_group_id': 'sg-1',
          'payer_user_id': 'existing-payer',
        }
      ];

      final result = applySplitPayerToRecurringRows(
        rows: rows,
        splitPayerByGroupId: const {'sg-1': 'mapped-payer'},
      );

      expect(result.single['payer_user_id'], 'existing-payer');
    });

    test('keeps row unchanged when no split group mapping exists', () {
      final rows = [
        {
          'id': 'exp-1',
          'split_group_id': 'sg-unknown',
          'user_id': 'creator-1',
        }
      ];

      final result = applySplitPayerToRecurringRows(
        rows: rows,
        splitPayerByGroupId: const {'sg-1': 'payer-1'},
      );

      expect(result.single.containsKey('payer_user_id'), isFalse);
    });
  });

  group('rebalancePocketBudgetAmounts', () {
    test('pocket card spend stays in each pocket native currency', () {
      final spentByPocket = calculatePocketNativeSpentByEnvelopeId(
        pockets: [
          PocketEnvelope(
            id: 'food-eur',
            name: 'Food EUR',
            budgetAmountCents: 20000,
            spent: 0,
            currency: 'EUR',
            lastUpdated: DateTime(2026),
          ),
          PocketEnvelope(
            id: 'food-usd',
            name: 'Food USD',
            budgetAmountCents: 50000,
            spent: 0,
            currency: 'USD',
            lastUpdated: DateTime(2026),
          ),
        ],
        categoriesByEnvelopeId: const {
          'food-eur': ['groceries'],
          'food-usd': ['groceries'],
        },
        expenses: [
          ExpenseEntry(
            id: 'eur-expense',
            amountCents: 12000,
            currency: 'EUR',
            category: 'groceries',
            date: DateTime(2026, 1, 5),
            createdAt: DateTime(2026, 1, 5),
          ),
          ExpenseEntry(
            id: 'usd-expense',
            amountCents: 10000,
            currency: 'USD',
            category: 'groceries',
            date: DateTime(2026, 1, 6),
            createdAt: DateTime(2026, 1, 6),
          ),
        ],
      );

      expect(spentByPocket['food-eur'], 120);
      expect(spentByPocket['food-usd'], 100);
    });

    test('aggregate total spent can differ from native card spend sum', () {
      final now = DateTime(2026, 1, 1);
      final state = PocketsState(
        isLoading: false,
        saved: const [],
        editing: [
          PocketEnvelope(
            id: 'food-eur',
            name: 'Food EUR',
            budgetAmountCents: 20000,
            spent: 120,
            currency: 'EUR',
            lastUpdated: now,
          ),
          PocketEnvelope(
            id: 'food-usd',
            name: 'Food USD',
            budgetAmountCents: 50000,
            spent: 100,
            currency: 'USD',
            lastUpdated: now,
          ),
        ],
        budgetId: 'budget-eur',
        periodMonth: now,
        previousBudget: 0,
        hasPreviousMonthPockets: false,
        currency: 'EUR',
        totalBudget: 1000,
        savedTotalBudget: 1000,
        aggregateTotalSpent: 205.43,
        unallocatedSpend: 0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      expect(state.totalSpent, 205.43);
    });

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

    test('redistributes a deleted pocket amount across remaining pockets', () {
      final result = rebalancePocketBudgetAmounts(
        currentAmountsCents: const [50000, 30000],
        newTotalBudgetCents: 100000,
      );

      expect(result, const [62500, 37500]);
      expect(result.fold<int>(0, (sum, amount) => sum + amount), 100000);
    });

    test('rounds allocations to currency step without exceeding total', () {
      final result = rebalancePocketBudgetAmounts(
        currentAmountsCents: const [33300, 33300, 33400],
        newTotalBudgetCents: 99500,
        allocationStepCents: pocketBudgetAdjustmentStepCents('EUR'),
      );

      expect(result, const [33000, 33000, 33000]);
      expect(result.every((amount) => amount % 1000 == 0), isTrue);
      expect(result.fold<int>(0, (sum, amount) => sum + amount), 99000);
      expect(
          result.fold<int>(0, (sum, amount) => sum + amount) <= 99500, isTrue);
    });

    test('normalizes currency codes when deriving adjustment steps', () {
      expect(
        pocketBudgetAdjustmentStepCents(' vnd '),
        pocketBudgetAdjustmentStepCents('VND'),
      );
      expect(
        pocketBudgetAdjustmentStepCents(' eur '),
        pocketBudgetAdjustmentStepCents('EUR'),
      );
    });

    test('defines a pockets budget baseline for every supported currency', () {
      final supportedCurrencies = getAvailableCurrencyOptions().keys.toSet();
      final pocketBaselineCurrencies =
          pocketCurrencyBudgetBaselines.keys.toSet();

      expect(
        pocketBaselineCurrencies.difference(supportedCurrencies),
        isEmpty,
        reason:
            'Pocket budget baselines should only contain currencies from currency.dart.',
      );
      expect(
        supportedCurrencies.difference(pocketBaselineCurrencies),
        isEmpty,
        reason:
            'When adding a currency to currency.dart, add its pocket baseline to pocket_budget_amount_steps.dart.',
      );
    });

    test('normalizes restored amounts to the currency adjustment step', () {
      expect(normalizePocketBudgetAmountCentsForCurrency(1234, 'EUR'), 1000);

      final vndStep = pocketBudgetAdjustmentStepCents('VND');
      final normalizedVnd =
          normalizePocketBudgetAmountCentsForCurrency(123456789, 'VND');
      expect(normalizedVnd % vndStep, 0);
      expect(normalizedVnd <= 123456789, isTrue);
    });

    test('normalizes cached pocket amounts when restoring state', () {
      final now = DateTime(2026, 1, 1);
      final rawPocket = PocketEnvelope(
        id: 'eur-food',
        name: 'Food',
        budgetAmountCents: 1234,
        spent: 0,
        currency: 'EUR',
        lastUpdated: now,
      );
      final state = PocketsState(
        isLoading: false,
        saved: [rawPocket],
        editing: [rawPocket.copyWith()],
        budgetId: 'budget-eur',
        periodMonth: now,
        previousBudget: 0,
        hasPreviousMonthPockets: false,
        currency: 'EUR',
        totalBudget: 1000,
        savedTotalBudget: 1000,
        unallocatedSpend: 0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      final restored = PocketsState.fromCacheJson(state.toCacheJson());

      expect(restored.saved.single.budgetAmountCents, 1000);
      expect(restored.editing.single.budgetAmountCents, 1000);
    });

    test('restores cached envelope category links for pocket details', () {
      final now = DateTime(2026, 1, 1);
      final state = PocketsState(
        isLoading: false,
        saved: const [],
        editing: const [],
        budgetId: 'budget',
        periodMonth: now,
        previousBudget: 0,
        hasPreviousMonthPockets: false,
        currency: 'USD',
        totalBudget: 0,
        savedTotalBudget: 0,
        unallocatedSpend: 0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
        envelopeCategories: const {
          'pocket-food': ['Groceries', ' dining '],
        },
      );

      final restored = PocketsState.fromCacheJson(state.toCacheJson());

      expect(
        restored.envelopeCategories['pocket-food'],
        ['groceries', 'dining'],
      );
    });
  });

  group('rebalanceSiblingPocketBudgetAmounts', () {
    test(
        'reduces sibling pockets proportionally when a new pocket exceeds budget',
        () {
      final result = rebalanceSiblingPocketBudgetAmounts(
        siblingAmountsCents: const [50000, 30000, 20000],
        targetPocketAmountCents: 50000,
        totalBudgetCents: 100000,
      );

      expect(result, const [25000, 15000, 10000]);
      expect(result.fold<int>(0, (sum, amount) => sum + amount), 50000);
    });

    test('rebalances sibling pockets to fill the remaining budget exactly', () {
      final result = rebalanceSiblingPocketBudgetAmounts(
        siblingAmountsCents: const [30000, 20000],
        targetPocketAmountCents: 10000,
        totalBudgetCents: 100000,
      );

      expect(result, const [54000, 36000]);
      expect(result.fold<int>(0, (sum, amount) => sum + amount), 90000);
    });

    test('rounds sibling pockets to currency step under remaining budget', () {
      final result = rebalanceSiblingPocketBudgetAmounts(
        siblingAmountsCents: const [33300, 33300, 33400],
        targetPocketAmountCents: 25500,
        totalBudgetCents: 100000,
        allocationStepCents: pocketBudgetAdjustmentStepCents('EUR'),
      );

      expect(result, const [25000, 25000, 25000]);
      expect(result.every((amount) => amount % 1000 == 0), isTrue);
      expect(
          result.fold<int>(0, (sum, amount) => sum + amount) <= 75000, isTrue);
    });
  });

  group('buildPocketsMonthMutationPayload', () {
    test('marks full-month snapshots as authoritative and keeps categories',
        () {
      final payload = buildPocketsMonthMutationPayload(
        userId: 'user-1',
        scopeType: PocketsScopeType.personal,
        householdId: null,
        periodMonth: '2026-05-01',
        currency: 'USD',
        budgetId: 'budget-1',
        totalBudgetCents: 100000,
        pockets: [
          PocketEnvelope(
            id: 'pocket-food',
            name: 'Food',
            budgetAmountCents: 60000,
            spent: 0,
            currency: 'USD',
            icon: 'food',
            color: '#111111',
            budgetId: 'budget-1',
            lastUpdated: DateTime(2026, 5, 1),
          ),
        ],
        envelopeCategories: const {
          'pocket-food': ['Groceries', ' dining '],
        },
      );

      expect(payload['replaceMissingPockets'], isTrue);
      expect(payload['replaceCategories'], isTrue);
      expect(payload['pockets'], hasLength(1));
      expect(
        (payload['pockets'] as List).single,
        containsPair('categories', ['groceries', 'dining']),
      );
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

    test('preserves unallocated budget share when total budget changes', () {
      final now = DateTime(2026, 1, 1);
      final pocket = PocketEnvelope(
        id: 'a',
        name: 'Pocket A',
        budgetAmountCents: 20000,
        spent: 0,
        currency: 'USD',
        lastUpdated: now,
      );
      final state = PocketsState(
        isLoading: false,
        saved: [pocket],
        editing: [pocket.copyWith()],
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
        const [40000],
      );
    });

    test('keeps saved ratios as the baseline across sequential slider updates',
        () {
      final now = DateTime(2026, 1, 1);
      final pocket = PocketEnvelope(
        id: 'a',
        name: 'Pocket A',
        budgetAmountCents: 20000,
        spent: 0,
        currency: 'USD',
        lastUpdated: now,
      );
      final state = PocketsState(
        isLoading: false,
        saved: [pocket],
        editing: [pocket.copyWith()],
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

      final firstTick = applyRebalancedBudgetToPocketsState(
        state: state,
        newTotalBudget: 1010,
      );
      final laterTick = applyRebalancedBudgetToPocketsState(
        state: firstTick,
        newTotalBudget: 2000,
      );

      expect(
        laterTick.editing.map((pocket) => pocket.budgetAmountCents).toList(),
        const [40000],
      );
    });

    test('preserves overallocated budget share when total budget changes', () {
      final now = DateTime(2026, 1, 1);
      final saved = [
        PocketEnvelope(
          id: 'a',
          name: 'Pocket A',
          budgetAmountCents: 80000,
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
      final state = PocketsState(
        isLoading: false,
        saved: saved,
        editing: saved.map((pocket) => pocket.copyWith()).toList(),
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
        newTotalBudget: 500,
      );

      expect(updated.totalBudget, 500);
      final amounts =
          updated.editing.map((pocket) => pocket.budgetAmountCents).toList();
      expect(amounts, const [33000, 17000]);
      expect(amounts.every((amount) => amount % 1000 == 0), isTrue);
      expect(amounts.fold<int>(0, (sum, amount) => sum + amount), 50000);
    });

    test('preserves allocation shares for every supported currency', () {
      final now = DateTime(2026, 1, 1);

      for (final currency in getAvailableCurrencyOptions().keys) {
        final stepCents = pocketBudgetAdjustmentStepCents(currency);
        final previousTotalBudgetCents = stepCents * 100;
        final newTotalBudgetCents = stepCents * 200;
        final saved = [
          PocketEnvelope(
            id: '$currency-a',
            name: 'Pocket A',
            budgetAmountCents: stepCents * 25,
            spent: 0,
            currency: currency,
            lastUpdated: now,
          ),
          PocketEnvelope(
            id: '$currency-b',
            name: 'Pocket B',
            budgetAmountCents: stepCents * 15,
            spent: 0,
            currency: currency,
            lastUpdated: now,
          ),
        ];
        final state = PocketsState(
          isLoading: false,
          saved: saved,
          editing: saved.map((pocket) => pocket.copyWith()).toList(),
          budgetId: 'budget-$currency',
          periodMonth: now,
          previousBudget: 0,
          hasPreviousMonthPockets: false,
          currency: currency,
          totalBudget: previousTotalBudgetCents / 100,
          savedTotalBudget: previousTotalBudgetCents / 100,
          unallocatedSpend: 0,
          uncategorized: const [],
          uncategorizedExpenses: const {},
        );

        final updated = applyRebalancedBudgetToPocketsState(
          state: state,
          newTotalBudget: newTotalBudgetCents / 100,
        );
        final amounts =
            updated.editing.map((pocket) => pocket.budgetAmountCents).toList();

        expect(updated.currency, currency);
        expect(
          amounts,
          [stepCents * 50, stepCents * 30],
          reason: 'Currency $currency should preserve allocation ratio',
        );
        expect(
          amounts.every((amount) => amount % stepCents == 0),
          isTrue,
          reason: 'Currency $currency should use its adjustment step',
        );
        expect(
          amounts.fold<int>(0, (sum, amount) => sum + amount) <=
              newTotalBudgetCents,
          isTrue,
          reason: 'Currency $currency should not exceed budget',
        );
      }
    });

    test('preserves VND jar ratios with Vietnam-scale whole-number budgets',
        () {
      final now = DateTime(2026, 1, 1);
      final saved = [
        PocketEnvelope(
          id: 'vnd-food',
          name: 'Food',
          budgetAmountCents: 500000000,
          spent: 0,
          currency: 'VND',
          lastUpdated: now,
        ),
        PocketEnvelope(
          id: 'vnd-rent',
          name: 'Rent',
          budgetAmountCents: 1000000000,
          spent: 0,
          currency: 'VND',
          lastUpdated: now,
        ),
      ];
      final state = PocketsState(
        isLoading: false,
        saved: saved,
        editing: saved.map((pocket) => pocket.copyWith()).toList(),
        budgetId: 'budget-vnd',
        periodMonth: now,
        previousBudget: 0,
        hasPreviousMonthPockets: false,
        currency: 'VND',
        totalBudget: 25000000,
        savedTotalBudget: 25000000,
        unallocatedSpend: 0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      final updated = applyRebalancedBudgetToPocketsState(
        state: state,
        newTotalBudget: 30000000,
      );

      expect(updated.totalBudget, 30000000);
      expect(updated.currency, 'VND');
      expect(
        updated.editing.map((pocket) => pocket.budgetAmountCents).toList(),
        const [600000000, 1200000000],
      );
      expect(
        updated.editing.every(
          (pocket) =>
              pocket.budgetAmountCents %
                  pocketBudgetAdjustmentStepCents('VND') ==
              0,
        ),
        isTrue,
      );
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

  group('filterPocketActualExpenses', () {
    test('includes recurring expenses and excludes only income', () {
      final now = DateTime(2026, 4, 3);
      final recurringExpense = ExpenseEntry(
        id: 'rec-exp-1',
        date: now,
        amountCents: 40000,
        category: 'rent',
        createdAt: now,
        type: 'expense',
        isRecurring: true,
      );
      final oneOffExpense = ExpenseEntry(
        id: 'exp-1',
        date: now,
        amountCents: 1200,
        category: 'coffee & tea',
        createdAt: now,
        type: 'expense',
        isRecurring: false,
      );
      final income = ExpenseEntry(
        id: 'inc-1',
        date: now,
        amountCents: 500000,
        category: 'salary',
        createdAt: now,
        type: 'income',
        isRecurring: false,
      );

      final filtered = filterPocketActualExpenses([
        recurringExpense,
        oneOffExpense,
        income,
      ]);

      expect(filtered.map((e) => e.id).toList(), const ['rec-exp-1', 'exp-1']);
    });

    test('overlays local and synced cached rows but not failed rows', () {
      expect(
        shouldLoadLocalPocketExpenseOverlaySyncStatus(localSyncStatusLocal),
        isTrue,
      );
      expect(
        shouldLoadLocalPocketExpenseOverlaySyncStatus(localSyncStatusSynced),
        isTrue,
      );
      expect(
        shouldLoadLocalPocketExpenseOverlaySyncStatus(localSyncStatusFailed),
        isFalse,
      );
    });

    test('resolves personal in-memory optimistic expenses before SQLite writes',
        () {
      final month = DateTime(2026, 5, 1);

      final resolved = resolveInMemoryPocketOverlayExpenses(
        scopeType: PocketsScopeType.personal,
        householdId: null,
        monthStart: month,
        selectedCurrency: 'USD',
        personalExpenses: [
          ExpenseEntry(
            id: 'optimistic_food_1',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1500,
            currency: 'USD',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
          ExpenseEntry(
            id: 'income-ignored',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 50000,
            currency: 'USD',
            category: 'salary',
            createdAt: DateTime(2026, 5, 13),
            type: 'income',
          ),
        ],
        householdExpensesByHouseholdId: const {},
      );

      expect(resolved.map((expense) => expense.id), ['optimistic_food_1']);
    });

    test('resolves household in-memory optimistic expenses by active household',
        () {
      final month = DateTime(2026, 5, 1);

      final resolved = resolveInMemoryPocketOverlayExpenses(
        scopeType: PocketsScopeType.household,
        householdId: 'house-1',
        monthStart: month,
        selectedCurrency: 'USD',
        personalExpenses: const [],
        householdExpensesByHouseholdId: {
          'house-1': [
            ExpenseEntry(
              id: 'optimistic_house_1',
              userId: 'user-1',
              householdId: 'house-1',
              date: DateTime(2026, 5, 13),
              amountCents: 1500,
              currency: 'USD',
              category: 'food',
              createdAt: DateTime(2026, 5, 13),
              type: 'expense',
            ),
          ],
          'house-2': [
            ExpenseEntry(
              id: 'wrong-house',
              userId: 'user-1',
              householdId: 'house-2',
              date: DateTime(2026, 5, 13),
              amountCents: 1500,
              currency: 'USD',
              category: 'food',
              createdAt: DateTime(2026, 5, 13),
              type: 'expense',
            ),
          ],
        },
      );

      expect(resolved.map((expense) => expense.id), ['optimistic_house_1']);
    });

    test('filters in-memory optimistic expenses by viewed month and currency',
        () {
      final month = DateTime(2026, 5, 1);

      final resolved = resolveInMemoryPocketOverlayExpenses(
        scopeType: PocketsScopeType.personal,
        householdId: null,
        monthStart: month,
        selectedCurrency: 'USD',
        personalExpenses: [
          ExpenseEntry(
            id: 'wrong-month',
            userId: 'user-1',
            date: DateTime(2026, 4, 30),
            amountCents: 1500,
            currency: 'USD',
            category: 'food',
            createdAt: DateTime(2026, 4, 30),
            type: 'expense',
          ),
          ExpenseEntry(
            id: 'wrong-currency',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1500,
            currency: 'EUR',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
        ],
        householdExpensesByHouseholdId: const {},
      );

      expect(resolved, isEmpty);
    });

    test('allows in-memory optimistic expenses from selected currency set', () {
      final month = DateTime(2026, 5, 1);

      final resolved = resolveInMemoryPocketOverlayExpenses(
        scopeType: PocketsScopeType.personal,
        householdId: null,
        monthStart: month,
        selectedCurrency: 'USD',
        selectedCurrencies: const ['USD', 'EUR'],
        personalExpenses: [
          ExpenseEntry(
            id: 'optimistic_usd',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1000,
            currency: 'USD',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
          ExpenseEntry(
            id: 'optimistic_eur',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1000,
            currency: 'EUR',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
          ExpenseEntry(
            id: 'optimistic_gbp',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1000,
            currency: 'GBP',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
        ],
        householdExpensesByHouseholdId: const {},
      );

      expect(resolved.map((expense) => expense.id), [
        'optimistic_usd',
        'optimistic_eur',
      ]);
    });

    test(
        'ignores non-optimistic in-memory rows to avoid double counting saved rows',
        () {
      final month = DateTime(2026, 5, 1);

      final resolved = resolveInMemoryPocketOverlayExpenses(
        scopeType: PocketsScopeType.personal,
        householdId: null,
        monthStart: month,
        selectedCurrency: 'USD',
        personalExpenses: [
          ExpenseEntry(
            id: 'server-expense-1',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1500,
            currency: 'USD',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
        ],
        householdExpensesByHouseholdId: const {},
      );

      expect(resolved, isEmpty);
    });

    test('applies local expense overlay to matching pocket immediately', () {
      final month = DateTime(2026, 5, 1);
      final state = PocketsState(
        isLoading: false,
        error: null,
        saved: [
          PocketEnvelope(
            id: 'env-bills',
            name: 'Bills',
            budgetAmountCents: 10000,
            spent: 0,
            currency: 'USD',
            icon: null,
            color: null,
            budgetId: 'budget-1',
            householdId: null,
            lastUpdated: month,
          ),
        ],
        editing: [
          PocketEnvelope(
            id: 'env-bills',
            name: 'Bills',
            budgetAmountCents: 10000,
            spent: 0,
            currency: 'USD',
            icon: null,
            color: null,
            budgetId: 'budget-1',
            householdId: null,
            lastUpdated: month,
          ),
        ],
        budgetId: 'budget-1',
        periodMonth: month,
        previousBudget: 0,
        hasPreviousMonthPockets: false,
        currency: 'USD',
        totalBudget: 100,
        savedTotalBudget: 100,
        unallocatedSpend: 0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
        envelopeCategories: const {
          'env-bills': ['bills'],
        },
      );

      final updated = applyLocalPocketExpenseOverlay(
        state: state,
        expenses: [
          ExpenseEntry(
            id: 'optimistic-bills-1',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 2000,
            currency: 'USD',
            category: 'bills',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
        ],
      );

      expect(updated.saved.single.spent, 20);
      expect(updated.editing.single.spent, 20);
      expect(updated.localOverlayExpenseIds, {'optimistic-bills-1'});
      expect(updated.hasChanges, isFalse);
    });

    test('keeps selected-currency-set local overlay in pocket native currency',
        () {
      final month = DateTime(2026, 5, 1);
      final pocket = PocketEnvelope(
        id: 'env-food',
        name: 'Food',
        budgetAmountCents: 10000,
        spent: 0,
        currency: 'USD',
        budgetId: 'budget-1',
        lastUpdated: month,
      );
      final state = PocketsState(
        isLoading: false,
        error: null,
        saved: [pocket],
        editing: [pocket.copyWith()],
        budgetId: 'budget-1',
        periodMonth: month,
        previousBudget: 0,
        hasPreviousMonthPockets: false,
        currency: 'USD',
        totalBudget: 100,
        savedTotalBudget: 100,
        unallocatedSpend: 0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
        envelopeCategories: const {
          'env-food': ['food'],
        },
      );

      final updated = applyLocalPocketExpenseOverlay(
        state: state,
        selectedCurrencies: const ['USD', 'EUR'],
        rates: const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'EUR': 0.5},
        ),
        expenses: [
          ExpenseEntry(
            id: 'local-usd',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1000,
            currency: 'USD',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
          ExpenseEntry(
            id: 'local-eur',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1000,
            currency: 'EUR',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
          ExpenseEntry(
            id: 'local-gbp',
            userId: 'user-1',
            date: DateTime(2026, 5, 13),
            amountCents: 1000,
            currency: 'GBP',
            category: 'food',
            createdAt: DateTime(2026, 5, 13),
            type: 'expense',
          ),
        ],
      );

      expect(updated.saved.single.spent, 10);
      expect(updated.editing.single.spent, 10);
      expect(updated.localOverlayExpenseIds, {'local-usd', 'local-eur'});
    });
  });

  group('resolveEnvelopeRowsForViewedMonth', () {
    test('returns empty when the viewed month has no budget row', () {
      final resolved = resolveEnvelopeRowsForViewedMonth(
        budgetId: null,
        budgetBoundEnvelopeRows: const [
          {'id': 'march-living-costs', 'name': 'Living Costs'},
          {'id': 'march-health', 'name': 'Health'},
        ],
        legacyBudgetlessEnvelopeRows: const [
          {'id': 'legacy-pocket', 'name': 'Legacy Pocket'},
        ],
      );

      expect(resolved, isEmpty);
    });

    test('prefers budget-bound rows over legacy budgetless rows', () {
      final resolved = resolveEnvelopeRowsForViewedMonth(
        budgetId: 'budget-april',
        budgetBoundEnvelopeRows: const [
          {'id': 'april-living-costs', 'name': 'Living Costs'},
        ],
        legacyBudgetlessEnvelopeRows: const [
          {'id': 'legacy-pocket', 'name': 'Legacy Pocket'},
        ],
      );

      expect(resolved, const [
        {'id': 'april-living-costs', 'name': 'Living Costs'},
      ]);
    });

    test('falls back to legacy budgetless rows only for an existing budget',
        () {
      final resolved = resolveEnvelopeRowsForViewedMonth(
        budgetId: 'budget-april',
        budgetBoundEnvelopeRows: const [],
        legacyBudgetlessEnvelopeRows: const [
          {'id': 'legacy-pocket', 'name': 'Legacy Pocket'},
        ],
      );

      expect(resolved, const [
        {'id': 'legacy-pocket', 'name': 'Legacy Pocket'},
      ]);
    });
  });

  group('PocketsScopeParams', () {
    test('toggle participates in equality so providers refresh on change', () {
      final baseParams = PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 3, 1),
        currency: 'GBP',
        includeUpcomingRecurring: false,
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

    test('selected currency set participates in normalized equality', () {
      final usdOnly = PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 3, 1),
        currency: 'USD',
        selectedCurrencies: const ['USD'],
      );
      final multiCurrency = PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 3, 1),
        currency: 'USD',
        selectedCurrencies: const [' eur ', 'USD', 'EUR'],
      );
      final sameMultiCurrency = PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 3, 1),
        currency: 'USD',
        selectedCurrencies: const ['USD', 'EUR'],
      );

      expect(usdOnly, isNot(multiCurrency));
      expect(multiCurrency, sameMultiCurrency);
      expect(multiCurrency.hashCode, sameMultiCurrency.hashCode);
    });
  });

  group('includeUpcomingRecurringInPocketsProvider', () {
    test('defaults to counting upcoming recurring payments as spent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(includeUpcomingRecurringInPocketsProvider),
        isTrue,
      );
    });
  });

  group('normalizePocketTemplateName', () {
    test('returns empty string for whitespace-only names', () {
      expect(normalizePocketTemplateName('   '), '');
    });
  });
}
