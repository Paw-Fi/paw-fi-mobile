import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';

const _retainedSummary = HouseholdSummary(
  householdId: 'household-1',
  currency: 'USD',
  period: DatePeriod(
    startDate: '2026-08-01T00:00:00.000',
    endDate: '2026-08-31T00:00:00.000',
  ),
  totals: Totals(
    totalExpensesCents: 2000,
    totalIncomeCents: 0,
    netCents: -2000,
    transactionCount: 1,
    splitCount: 1,
  ),
  memberContributions: <MemberContribution>[],
  categoryBreakdown: <CategoryBreakdown>[],
  budgets: <BudgetStatus>[],
  balances: <String, int>{},
);

void main() {
  group('mergeHouseholdDashboardExpenses', () {
    const householdId = 'household-1';
    final query = DashboardScopeQuery(
      userId: 'user-1',
      householdId: householdId,
      selectedCurrency: 'USD',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );

    ExpenseEntry entry({
      required String id,
      required int amountCents,
      required DateTime date,
    }) {
      return ExpenseEntry(
        id: id,
        userId: 'user-1',
        householdId: householdId,
        date: date,
        amountCents: amountCents,
        currency: 'USD',
        createdAt: date,
        type: 'expense',
      );
    }

    test(
        'applies current local edits, creates, and tombstones before cards read',
        () {
      final original = entry(
        id: 'server-expense',
        amountCents: 1000,
        date: DateTime(2026, 8, 10),
      );
      final edited = entry(
        id: 'server-expense',
        amountCents: 1500,
        date: DateTime(2026, 8, 10),
      );
      final created = entry(
        id: 'optimistic-created',
        amountCents: 2500,
        date: DateTime(2026, 8, 11),
      );
      final deleted = entry(
        id: 'deleted-expense',
        amountCents: 500,
        date: DateTime(2026, 8, 9),
      );

      final merged = mergeHouseholdDashboardExpenses(
        base: [original, deleted],
        localOverlay: const <ExpenseEntry>[],
        query: query,
        optimisticExpenses: [edited, created],
        deletedIds: const {'deleted-expense'},
      );

      expect(
        merged.map((candidate) => candidate.id),
        ['optimistic-created', 'server-expense'],
      );
      expect(
        merged
            .singleWhere((candidate) => candidate.id == 'server-expense')
            .amountCents,
        1500,
      );
    });

    test('limits Recent after all overlays are merged', () {
      final older = entry(
        id: 'older',
        amountCents: 1000,
        date: DateTime(2026, 8, 1),
      );
      final newest = entry(
        id: 'newest',
        amountCents: 1000,
        date: DateTime(2026, 8, 2),
      );

      final merged = mergeHouseholdDashboardExpenses(
        base: [older],
        localOverlay: const <ExpenseEntry>[],
        query: query,
        optimisticExpenses: [newest],
        deletedIds: const <String>{},
        limit: 1,
      );

      expect(merged.single.id, 'newest');
    });
  });

  group('householdDashboardDependencyState', () {
    test('does not expose a partial summary while any input is unresolved', () {
      final state = householdDashboardDependencyState(<AsyncValue<Object?>>[
        const AsyncValue.data(<Object>[]),
        const AsyncValue.loading(),
        const AsyncValue.data(<Object>[]),
      ]);

      expect(state.isLoading, isTrue);
      expect(state.hasValue, isFalse);
    });

    test('preserves usable cached inputs while they refresh', () {
      final refreshing = const AsyncValue<List<Object>>.loading()
          .copyWithPrevious(const AsyncValue.data(<Object>[]));

      final state = householdDashboardDependencyState(<AsyncValue<Object?>>[
        refreshing,
        const AsyncValue.data(<Object>[]),
      ]);

      expect(state.valueOrNull, isTrue);
    });

    test('propagates an input error when no cached value exists', () {
      final error = StateError('splits failed');
      final state = householdDashboardDependencyState(<AsyncValue<Object?>>[
        const AsyncValue.data(<Object>[]),
        AsyncValue.error(error, StackTrace.current),
      ]);

      expect(state.hasError, isTrue);
      expect(state.error, same(error));
    });

    test('retains the last complete summary while inputs refresh', () {
      final retained = retainHouseholdSummaryDuringRefresh(
        dependencyState: const AsyncValue.loading(),
        retainedSummary: _retainedSummary,
      );

      expect(retained?.valueOrNull, same(_retainedSummary));
      expect(retained?.isLoading, isFalse);
    });

    test('retains the last complete summary when a refresh fails', () {
      final retained = retainHouseholdSummaryDuringRefresh(
        dependencyState: AsyncValue.error(
          StateError('refresh failed'),
          StackTrace.current,
        ),
        retainedSummary: _retainedSummary,
      );

      expect(retained?.valueOrNull, same(_retainedSummary));
      expect(retained?.hasError, isFalse);
    });
  });
}
