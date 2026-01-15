import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/monitoring/performance_monitor.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

ExpenseEntry _expense(String id) {
  final now = DateTime(2024, 1, 1);
  return ExpenseEntry(
    id: id,
    householdId: 'h1',
    date: now,
    amountCents: 100,
    currency: 'USD',
    createdAt: now,
  );
}

ExpenseSplitGroup _splitGroup(String id) {
  final now = DateTime(2024, 1, 1);
  return ExpenseSplitGroup(
    id: id,
    householdId: 'h1',
    expenseId: 'e$id',
    payerUserId: 'u1',
    splitType: SplitType.equal,
    currency: 'USD',
    totalAmountCents: 100,
    createdAt: now,
    updatedAt: now,
    splitLines: const [],
  );
}

void main() {
  setUp(() {
    PerformanceMonitor.reset();
    CacheInvalidator().invalidateAll();
  });

  test(
      'cachedHouseholdExpensesProvider refreshes after invalidate even with an in-flight request',
      () async {
    final firstCompleter = Completer<List<ExpenseEntry>>();
    var fetchCount = 0;

    final container = ProviderContainer(
      overrides: [
        householdExpensesProvider.overrideWith((ref, params) async {
          fetchCount += 1;
          if (fetchCount == 1) {
            return firstCompleter.future;
          }
          return [_expense('new')];
        }),
      ],
    );
    addTearDown(container.dispose);

    const params = HouseholdExpensesParams(householdId: 'h1');
    final future1 =
        container.read(cachedHouseholdExpensesProvider(params).future);

    container.read(cacheInvalidatorProvider).invalidateHouseholdData('h1');
    container.invalidate(householdExpensesProvider);
    container.invalidate(cachedHouseholdExpensesProvider);
    await Future<void>.delayed(Duration.zero);

    final result2 = await container
        .read(cachedHouseholdExpensesProvider(params).future)
        .timeout(const Duration(seconds: 1));
    expect(result2.map((e) => e.id).toList(), ['new']);

    firstCompleter.complete([_expense('old')]);
    await future1;

    final result3 =
        await container.read(cachedHouseholdExpensesProvider(params).future);
    expect(result3.map((e) => e.id).toList(), ['new']);
    expect(fetchCount, 2);
  });

  test(
      'cachedHouseholdSplitsProvider refreshes after invalidate even with an in-flight request',
      () async {
    final firstCompleter = Completer<List<ExpenseSplitGroup>>();
    var fetchCount = 0;

    final container = ProviderContainer(
      overrides: [
        householdSplitsProvider.overrideWith((ref, params) async {
          fetchCount += 1;
          if (fetchCount == 1) {
            return firstCompleter.future;
          }
          return [_splitGroup('new')];
        }),
      ],
    );
    addTearDown(container.dispose);

    const params = HouseholdSplitsParams(householdId: 'h1');
    final future1 =
        container.read(cachedHouseholdSplitsProvider(params).future);

    container.read(cacheInvalidatorProvider).invalidateHouseholdData('h1');
    container.invalidate(householdSplitsProvider);
    container.invalidate(cachedHouseholdSplitsProvider);
    await Future<void>.delayed(Duration.zero);

    final result2 = await container
        .read(cachedHouseholdSplitsProvider(params).future)
        .timeout(const Duration(seconds: 1));
    expect(result2.map((e) => e.id).toList(), ['new']);

    firstCompleter.complete([_splitGroup('old')]);
    await future1;

    final result3 =
        await container.read(cachedHouseholdSplitsProvider(params).future);
    expect(result3.map((e) => e.id).toList(), ['new']);
    expect(fetchCount, 2);
  });
}
