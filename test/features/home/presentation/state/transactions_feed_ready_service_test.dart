import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/monitoring/performance_trace.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';

const _query = TransactionsFeedQuery(
  userId: 'user-1',
  householdId: null,
  selectedCurrency: 'EUR',
  selectedCategory: null,
  selectedType: 'all',
  searchQuery: '',
  startDate: null,
  endDate: null,
);

class _Remote extends EmptyTransactionsFeedService {
  int calls = 0;

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    calls++;
    return [
      ExpenseEntry(
        id: 'remote',
        userId: query.userId,
        amountCents: 3000,
        currency: 'EUR',
        category: 'food',
        type: 'expense',
        date: DateTime(2026, 9, 20),
        createdAt: DateTime(2026, 9, 20, 12),
      )
    ];
  }
}

void main() {
  test('refreshes while opening only continue the newest all-items reader',
      () async {
    final database = MonekoDatabase.inMemory();
    final opening = Completer<MonekoDatabase>();
    final remote = _Remote();
    final events = <Map<String, Object?>>[];
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) => opening.future),
      transactionsRemoteFeedServiceProvider.overrideWithValue(remote),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
    ]);
    final subscription = container.listen(
        transactionsFeedAllItemsProvider(_query), (previous, next) {},
        fireImmediately: true);
    PerformanceTrace.testSink = events.add;
    try {
      await pumpEventQueue();
      container.read(transactionsFeedRefreshSignalProvider.notifier).state++;
      await pumpEventQueue();
      container.read(transactionsFeedRefreshSignalProvider.notifier).state++;
      await pumpEventQueue();
      opening.complete(database);
      expect(
          await container.read(transactionsFeedAllItemsProvider(_query).future),
          isEmpty);
      expect(
          events
              .where((event) =>
                  event['event'] == 'start' &&
                  event['readType'] == 'sqlite.feed.page')
              .length,
          1);
      expect(remote.calls, 0);
    } finally {
      PerformanceTrace.testSink = null;
      subscription.close();
      container.dispose();
      await database.close();
    }
  });

  test('all-items stays unresolved until an opening local database is usable',
      () async {
    final database = MonekoDatabase.inMemory();
    final opening = Completer<MonekoDatabase>();
    final remote = _Remote();
    await database.upsertTransactions([
      ExpenseEntry(
        id: 'local',
        userId: 'user-1',
        amountCents: 2000,
        currency: 'EUR',
        category: 'food',
        type: 'expense',
        date: DateTime(2026, 9, 20),
        createdAt: DateTime(2026, 9, 20, 12),
      )
    ]);
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) => opening.future),
      transactionsRemoteFeedServiceProvider.overrideWithValue(remote),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
    ]);
    final states = <AsyncValue<List<ExpenseEntry>>>[];
    final subscription = container.listen(
        transactionsFeedAllItemsProvider(_query),
        (previous, next) => states.add(next),
        fireImmediately: true);
    try {
      await pumpEventQueue();
      expect(container.read(transactionsFeedAllItemsProvider(_query)).isLoading,
          isTrue);
      expect(states.any((state) => state.hasValue), isFalse);
      expect(remote.calls, 0);
      opening.complete(database);
      final rows =
          await container.read(transactionsFeedAllItemsProvider(_query).future);
      expect(rows.single.id, 'local');
      expect(rows.single.amount, 20);
      expect(remote.calls, 0);
      expect(
          states
              .where((state) => state.hasValue)
              .every((state) => state.requireValue.isNotEmpty),
          isTrue);
    } finally {
      subscription.close();
      container.dispose();
      await database.close();
    }
  });

  test('database-open failure retains the original remote fallback', () async {
    final opening = Completer<MonekoDatabase>();
    final remote = _Remote();
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) => opening.future),
      transactionsRemoteFeedServiceProvider.overrideWithValue(remote),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(true)),
    ]);
    final subscription = container.listen(
        transactionsFeedAllItemsProvider(_query), (previous, next) {},
        fireImmediately: true);
    try {
      final pending =
          container.read(transactionsFeedAllItemsProvider(_query).future);
      await pumpEventQueue();
      expect(remote.calls, 0);
      opening.completeError(StateError('cannot open database'));
      expect((await pending).single.id, 'remote');
      expect(remote.calls, 1);
    } finally {
      subscription.close();
      container.dispose();
    }
  });

  test(
      'a successfully opened empty offline database is a legitimate empty result',
      () async {
    final database = MonekoDatabase.inMemory();
    final opening = Completer<MonekoDatabase>();
    final remote = _Remote();
    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWith((ref) => opening.future),
      transactionsRemoteFeedServiceProvider.overrideWithValue(remote),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
    ]);
    final subscription = container.listen(
        transactionsFeedAllItemsProvider(_query), (previous, next) {},
        fireImmediately: true);
    try {
      await pumpEventQueue();
      opening.complete(database);
      expect(
          await container.read(transactionsFeedAllItemsProvider(_query).future),
          isEmpty);
      expect(remote.calls, 0);
    } finally {
      subscription.close();
      container.dispose();
      await database.close();
    }
  });
}
