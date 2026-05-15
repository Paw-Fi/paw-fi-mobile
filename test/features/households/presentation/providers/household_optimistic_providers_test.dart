import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';

ExpenseEntry _entry(String id) => ExpenseEntry(
      id: id,
      date: DateTime(2026, 1, 1),
      amountCents: 1234,
      createdAt: DateTime(2026, 1, 1),
      type: 'expense',
    );

Household _household(String id, {String name = 'Space'}) => Household(
      id: id,
      name: name,
      ownerId: 'user-1',
      currency: 'USD',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

class _FakeHouseholdRepository implements HouseholdRepository {
  @override
  Future<List<Household>> getUserHouseholds(String userId) async =>
      const <Household>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  test('mergeHouseholdExpenses lets optimistic rows override stale base rows',
      () {
    final base = _entry('expense-1');
    final optimistic = _entry('expense-1').copyWith(amountCents: 9999);

    final merged = mergeHouseholdExpenses([base], [optimistic]);

    expect(merged.length, 1);
    expect(merged.single.amountCents, 9999);
  });

  test('mergeHouseholdExpenses hides optimistically deleted base rows', () {
    final merged = mergeHouseholdExpenses(
      [_entry('deleted'), _entry('kept')],
      const [],
      deletedIds: {'deleted'},
    );

    expect(merged.map((entry) => entry.id), ['kept']);
  });

  test('household optimistic deleted ids can be restored', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const householdId = 'household-1';
    final notifier =
        container.read(householdOptimisticDeletedExpenseIdsProvider.notifier);

    notifier.markDeleted(householdId, ['a', 'b']);
    notifier.restore(householdId, ['a']);

    final state = container.read(householdOptimisticDeletedExpenseIdsProvider);
    expect(state[householdId], {'b'});
  });

  test('addOrReplaceHousehold inserts and updates user household state', () {
    final container = ProviderContainer(
      overrides: [
        householdRepositoryProvider
            .overrideWithValue(_FakeHouseholdRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(userHouseholdsProvider('user-1').notifier);

    notifier.hydrate([_household('space-1')]);
    notifier.addOrReplaceHousehold(_household('space-2', name: 'New Space'));
    notifier.addOrReplaceHousehold(
      _household('space-1', name: 'Renamed Space'),
    );

    final households = container.read(userHouseholdsProvider('user-1')).value!;

    expect(households.map((h) => h.id), ['space-1', 'space-2']);
    expect(households.first.name, 'Renamed Space');
    expect(households.last.name, 'New Space');
  });
}
