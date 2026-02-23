import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';

ExpenseEntry _entry(String id) => ExpenseEntry(
      id: id,
      date: DateTime(2026, 1, 1),
      amountCents: 1234,
      createdAt: DateTime(2026, 1, 1),
      type: 'expense',
    );

void main() {
  test('householdOptimisticExpensesProvider removeExpense removes by id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const householdId = 'household-1';
    final notifier =
        container.read(householdOptimisticExpensesProvider.notifier);

    notifier.addExpense(householdId, _entry('a'));
    notifier.addExpense(householdId, _entry('b'));

    notifier.removeExpense(householdId, 'a');

    final state = container.read(householdOptimisticExpensesProvider);
    expect(state[householdId]?.any((e) => e.id == 'a'), false);
    expect(state[householdId]?.any((e) => e.id == 'b'), true);
  });

  test('householdOptimisticExpensesProvider replaceExpense swaps entries', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const householdId = 'household-1';
    final notifier =
        container.read(householdOptimisticExpensesProvider.notifier);

    notifier.addExpense(householdId, _entry('old'));

    notifier.replaceExpense(householdId, 'old', _entry('new'));

    final state = container.read(householdOptimisticExpensesProvider);
    expect(state[householdId]?.any((e) => e.id == 'old'), false);
    expect(state[householdId]?.any((e) => e.id == 'new'), true);
  });

  test('replaceExpense dedupes when saved id already exists', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const householdId = 'household-1';
    final notifier =
        container.read(householdOptimisticExpensesProvider.notifier);

    notifier.addExpense(householdId, _entry('server-id'));
    notifier.addExpense(householdId, _entry('optimistic-id'));

    notifier.replaceExpense(householdId, 'optimistic-id', _entry('server-id'));

    final state = container.read(householdOptimisticExpensesProvider);
    final entries = state[householdId] ?? const <ExpenseEntry>[];
    expect(entries.where((e) => e.id == 'server-id').length, 1);
    expect(entries.where((e) => e.id == 'optimistic-id').length, 0);
  });
}
