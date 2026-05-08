import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';

ExpenseEntry _entry(String id, {String? userId}) => ExpenseEntry(
      id: id,
      userId: userId,
      date: DateTime(2026, 1, 1),
      amountCents: 1234,
      createdAt: DateTime(2026, 1, 1),
      type: 'expense',
    );

void main() {
  test('addOptimisticTransaction keeps only one row per id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(analyticsProvider.notifier);
    final saved = _entry('server-1');

    notifier.addOptimisticTransaction(saved);
    notifier.addOptimisticTransaction(saved);

    final state = container.read(analyticsProvider);
    expect(state.expenses.where((e) => e.id == 'server-1').length, 1);
    expect(state.allExpenses.where((e) => e.id == 'server-1').length, 1);
  });

  test(
      'replaceOptimisticTransaction removes optimistic row and dedupes saved id',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(analyticsProvider.notifier);
    final optimistic = _entry('optimistic-1');
    final saved = _entry('server-1');

    // Simulate race: server row already present from a background refresh.
    notifier.addOptimisticTransaction(saved);
    notifier.addOptimisticTransaction(optimistic);

    notifier.replaceOptimisticTransaction(optimistic.id, saved);

    final state = container.read(analyticsProvider);
    expect(state.expenses.where((e) => e.id == optimistic.id), isEmpty);
    expect(state.allExpenses.where((e) => e.id == optimistic.id), isEmpty);
    expect(state.expenses.where((e) => e.id == saved.id).length, 1);
    expect(state.allExpenses.where((e) => e.id == saved.id).length, 1);
  });

  test('hydrateFromLocalCache renders cached rows before network refresh',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions([
      _entry('cached-1', userId: 'user-1'),
    ]);

    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(analyticsProvider.notifier);
    final hydrated = await notifier.hydrateFromLocalCache('user-1');

    final state = container.read(analyticsProvider);
    expect(hydrated, isTrue);
    expect(state.hasLoadedOnce, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.allExpenses.map((entry) => entry.id), ['cached-1']);
  });
}
