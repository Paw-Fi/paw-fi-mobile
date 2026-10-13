import 'dart:async';

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
  test('a stale alias cleanup cannot overwrite a newer local edit', () async {
    final pending = Completer<MonekoDatabase>();
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) => pending.future),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(analyticsProvider.notifier);
    final old = _entry('optimistic_overlap', userId: 'user-1');
    notifier.addOptimisticTransaction(old);
    final cleanup =
        notifier.reconcileOptimisticTransactionsFromLocalCache('user-1');
    notifier.replaceOptimisticTransaction(
        old.id, old.copyWith(amountCents: 2000));
    pending.complete(database);
    await cleanup;
    expect(
        container.read(analyticsProvider).allExpenses.single.amountCents, 2000);
  });

  test('completed canonical rows are retired after deletion too', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final optimistic = _entry('optimistic_canonical_deleted', userId: 'user-1');
    await database.writeOptimisticTransaction(
      entry: optimistic,
      clientMutationId: 'mobile:${optimistic.id}',
      operation: 'create',
      payload: {'transaction': optimistic.toJson()},
    );
    final saved = await database.replaceOptimisticTransaction(
      optimisticId: optimistic.id,
      savedEntry: optimistic.copyWith(id: 'deleted-canonical'),
      clientMutationId: 'mobile:${optimistic.id}',
    );
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(analyticsProvider.notifier);
    notifier.addOptimisticTransaction(optimistic);
    notifier.replaceOptimisticTransaction(optimistic.id, saved!);
    await database.deleteTransactionsByIds([saved.id]);
    await notifier.reconcileOptimisticTransactionsFromLocalCache('user-1');
    expect(container.read(analyticsProvider).allExpenses, isEmpty);
  });

  test('the durable row wins when an older canonical copy precedes its alias',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final optimistic = _entry('optimistic_canonical', userId: 'user-1');
    await database.writeOptimisticTransaction(
      entry: optimistic,
      clientMutationId: 'mobile:${optimistic.id}',
      operation: 'create',
      payload: {'transaction': optimistic.toJson()},
    );
    final saved = await database.replaceOptimisticTransaction(
      optimisticId: optimistic.id,
      savedEntry: optimistic.copyWith(id: 'canonical', amountCents: 2000),
      clientMutationId: 'mobile:${optimistic.id}',
    );
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(analyticsProvider.notifier);
    notifier.addOptimisticTransaction(optimistic);
    notifier.addOptimisticTransaction(saved!.copyWith(amountCents: 1000));
    await notifier.reconcileOptimisticTransactionsFromLocalCache('user-1');
    final rows = container.read(analyticsProvider).allExpenses;
    expect(rows.single.id, saved.id);
    expect(rows.single.amountCents, 2000);
  });
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

  test('hydration retires a synced alias whose canonical row was deleted',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final optimistic = _entry('optimistic_deleted', userId: 'user-1');
    await database.writeOptimisticTransaction(
      entry: optimistic,
      clientMutationId: 'mobile:optimistic_deleted',
      operation: 'create',
      payload: {'transaction': optimistic.toJson()},
    );
    await database.replaceOptimisticTransaction(
      optimisticId: optimistic.id,
      savedEntry: optimistic.copyWith(id: 'server-deleted'),
      clientMutationId: 'mobile:optimistic_deleted',
    );
    await database.deleteTransactionsByIds(['server-deleted']);
    await database.upsertTransactions([_entry('kept', userId: 'user-1')]);
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(analyticsProvider.notifier);
    notifier.addOptimisticTransaction(optimistic);

    await notifier.hydrateFromLocalCache('user-1');

    expect(container.read(analyticsProvider).allExpenses.map((e) => e.id),
        ['kept']);
  });

  test('hydration replaces a synced alias with its latest durable row',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final optimistic = _entry('optimistic_synced', userId: 'user-1');
    await database.writeOptimisticTransaction(
      entry: optimistic,
      clientMutationId: 'mobile:optimistic_synced',
      operation: 'create',
      payload: {'transaction': optimistic.toJson()},
    );
    await database.replaceOptimisticTransaction(
      optimisticId: optimistic.id,
      savedEntry: optimistic.copyWith(id: 'server-synced'),
      clientMutationId: 'mobile:optimistic_synced',
    );
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(analyticsProvider.notifier);
    notifier.addOptimisticTransaction(optimistic);

    await notifier.hydrateFromLocalCache('user-1');

    expect(container.read(analyticsProvider).allExpenses.map((e) => e.id),
        ['server-synced']);
  });

  test('hydration preserves queued and not-yet-persisted optimistic rows',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final queued = _entry('optimistic_queued', userId: 'user-1');
    final preparing = _entry('optimistic_preparing', userId: 'user-1');
    await database.writeOptimisticTransaction(
      entry: queued,
      clientMutationId: 'mobile:optimistic_queued',
      operation: 'create',
      payload: {'transaction': queued.toJson()},
    );
    await database.markMutationFailed(
      clientMutationId: 'mobile:optimistic_queued',
      error: 'offline',
      retryAfter: DateTime.now().add(const Duration(minutes: 1)),
    );
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(analyticsProvider.notifier);
    notifier.addOptimisticTransaction(queued);
    notifier.addOptimisticTransaction(preparing);

    await notifier.hydrateFromLocalCache('user-1');

    expect(
        container.read(analyticsProvider).allExpenses.map((e) => e.id).toSet(),
        {queued.id, preparing.id});
  });
}
