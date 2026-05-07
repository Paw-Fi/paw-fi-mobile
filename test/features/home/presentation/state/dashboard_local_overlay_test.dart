import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';

void main() {
  group('mergeDashboardTransactionsWithLocalOverlay', () {
    test('prepends matching optimistic transaction before recent limit', () {
      final olderServer = _entry(
        id: 'server-1',
        date: DateTime(2026, 5, 1),
        createdAt: DateTime(2026, 5, 1, 10),
      );
      final newerOptimistic = _entry(
        id: 'optimistic_1',
        date: DateTime(2026, 5, 7),
        createdAt: DateTime(2026, 5, 7, 12),
      );

      final merged = mergeDashboardTransactionsWithLocalOverlay(
        base: [olderServer],
        localOverlay: [newerOptimistic],
        query: const DashboardScopeQuery(
          userId: 'user-1',
          householdId: null,
          selectedCurrency: 'USD',
          startDate: null,
          endDate: null,
        ),
        limit: 1,
      );

      expect(merged, [newerOptimistic]);
    });

    test('uses local overlay when it has the same id as a stale base row', () {
      final staleServer = _entry(
        id: 'expense-1',
        date: DateTime(2026, 5, 7),
        createdAt: DateTime(2026, 5, 7, 10),
      );
      final optimisticUpdate = _entry(
        id: 'expense-1',
        date: DateTime(2026, 5, 7),
        createdAt: DateTime(2026, 5, 7, 10),
        amountCents: 3400,
      );

      final merged = mergeDashboardTransactionsWithLocalOverlay(
        base: [staleServer],
        localOverlay: [optimisticUpdate],
        query: const DashboardScopeQuery(
          userId: 'user-1',
          householdId: null,
          selectedCurrency: 'USD',
          startDate: null,
          endDate: null,
        ),
      );

      expect(merged.single.amountCents, 3400);
    });

    test('filters local overlay by household currency and date range', () {
      final included = _entry(
        id: 'optimistic-included',
        householdId: 'household-1',
        currency: 'USD',
        date: DateTime(2026, 5, 7),
      );
      final wrongHousehold = _entry(
        id: 'optimistic-wrong-household',
        householdId: 'household-2',
        currency: 'USD',
        date: DateTime(2026, 5, 7),
      );
      final wrongCurrency = _entry(
        id: 'optimistic-wrong-currency',
        householdId: 'household-1',
        currency: 'EUR',
        date: DateTime(2026, 5, 7),
      );
      final outOfRange = _entry(
        id: 'optimistic-out-of-range',
        householdId: 'household-1',
        currency: 'USD',
        date: DateTime(2026, 4, 30),
      );

      final merged = mergeDashboardTransactionsWithLocalOverlay(
        base: const [],
        localOverlay: [included, wrongHousehold, wrongCurrency, outOfRange],
        query: DashboardScopeQuery(
          userId: 'user-1',
          householdId: 'household-1',
          selectedCurrency: 'USD',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 31),
        ),
      );

      expect(merged, [included]);
    });
  });
}

ExpenseEntry _entry({
  required String id,
  String? householdId,
  String currency = 'USD',
  DateTime? date,
  DateTime? createdAt,
  int amountCents = 1200,
}) {
  return ExpenseEntry(
    id: id,
    userId: 'user-1',
    householdId: householdId,
    date: date ?? DateTime(2026, 5, 7),
    amountCents: amountCents,
    currency: currency,
    category: 'food',
    createdAt: createdAt ?? DateTime(2026, 5, 7, 11),
    type: 'expense',
  );
}
