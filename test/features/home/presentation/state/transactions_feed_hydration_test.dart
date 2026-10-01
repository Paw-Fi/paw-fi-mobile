import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
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
const _localQuery = LocalTransactionsFeedQuery(
  userId: 'user-1',
  householdId: null,
  currency: 'EUR',
  currencies: ['EUR'],
);

ExpenseEntry _entry(String id, int cents) => ExpenseEntry(
      id: id,
      userId: 'user-1',
      date: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 9, 20, 12),
      amountCents: cents,
      currency: 'EUR',
      category: 'food',
      type: 'expense',
    );

class _DelayedBackend extends TransactionsFeedService {
  final gate = Completer<void>();
  List<ExpenseEntry> items = [_entry('expense-1', 3000)];
  Object? failure;
  int pageCalls = 0;
  int summaryCalls = 0;

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    pageCalls++;
    await gate.future;
    if (failure != null) throw failure!;
    return TransactionsFeedPageResult(
      items: items,
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
      TransactionsFeedQuery query) async {
    summaryCalls++;
    await gate.future;
    if (failure != null) throw failure!;
    return TransactionsFeedSummary(
      transactionCount: items.length,
      expenseTotal: items.fold<double>(0, (sum, row) => sum + row.amount),
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: const [],
      yearlyPeriodTotals: const {},
    );
  }
}

void main() {
  late MonekoDatabase database;
  late _DelayedBackend backend;
  late TransactionsFeedNotifier notifier;

  setUp(() {
    database = MonekoDatabase.inMemory();
    backend = _DelayedBackend();
    notifier = TransactionsFeedNotifier(
      service: LocalFirstTransactionsFeedService(
          database: database, remote: backend),
      query: _query,
    );
  });

  tearDown(() async {
    notifier.dispose();
    if (!backend.gate.isCompleted) backend.gate.complete();
    await pumpEventQueue();
    await database.close();
  });

  Future<void> cache(List<ExpenseEntry> rows) async {
    await database.upsertTransactions(rows);
    await database.markTransactionsFeedCacheComplete(_localQuery,
        isComplete: true);
  }

  test(
      'complete local 20 renders before backend 30 without another loading state',
      () async {
    await cache([_entry('expense-1', 2000)]);
    final states = <TransactionsFeedState>[];
    notifier.addListener(states.add);
    await notifier.loadInitial();
    expect(notifier.state.summary.expenseTotal, 20);
    expect(notifier.state.items.single.amount, 20);
    expect(notifier.state.isLoading, isFalse);
    expect(backend.gate.isCompleted, isFalse);
    backend.gate.complete();
    await pumpEventQueue();
    expect(notifier.state.summary.expenseTotal, 30);
    expect(notifier.state.items.single.amount, 30);
    final firstData = states.indexWhere((state) => state.hasLoadedInitial);
    expect(states.skip(firstData).every((state) => !state.isLoading), isTrue);
    expect(
        (await database.getTransactionsFeedPage(_localQuery))
            .items
            .single
            .amount,
        30);
  });

  test('one cached startup avoids the preliminary remote summary', () async {
    await cache([_entry('expense-1', 2000)]);
    await notifier.loadInitial();
    backend.gate.complete();
    await pumpEventQueue();
    // One summary validates reconciliation and one reads the final visible
    // summary with current pending overlays; no network summary precedes cache.
    expect(backend.summaryCalls, 2);
    expect(backend.pageCalls, 1);
  });

  test('failed reconciliation retains the trusted local value', () async {
    await cache([_entry('expense-1', 2000)]);
    await notifier.loadInitial();
    backend.failure = StateError('offline');
    backend.gate.complete();
    await pumpEventQueue();
    expect(notifier.state.items.single.amount, 20);
    expect(notifier.state.summary.expenseTotal, 20);
    expect(notifier.state.error, isNull);
    expect(notifier.state.isLoading, isFalse);
  });

  test('background and concurrent foreground refresh share one reconciliation',
      () async {
    await cache([_entry('expense-1', 2000)]);
    await notifier.loadInitial();
    final first = notifier.refresh();
    final second = notifier.refresh();
    await pumpEventQueue();
    expect(backend.pageCalls, 1);
    backend.gate.complete();
    await Future.wait([first, second]);
    await pumpEventQueue();
    expect(backend.summaryCalls, 2);
    expect(notifier.state.items.single.amount, 30);
  });

  test('independent callers share the local service reconciliation', () async {
    await cache([_entry('expense-1', 2000)]);
    final service =
        LocalFirstTransactionsFeedService(database: database, remote: backend);
    final first = service.refreshFromRemote(_query);
    final second = service.refreshFromRemote(_query);
    await pumpEventQueue();
    expect(backend.pageCalls, 1);
    backend.gate.complete();
    await Future.wait([first, second]);
    expect(backend.summaryCalls, 1);
    expect(backend.pageCalls, 1);
    await service.refreshFromRemote(_query);
    expect(backend.pageCalls, 2);
  });

  test('a local mutation starts a distinct service revision without losing it',
      () async {
    final original = _entry('expense-1', 2000);
    await cache([original]);
    final service =
        LocalFirstTransactionsFeedService(database: database, remote: backend);
    final older = service.refreshFromRemote(_query);
    await pumpEventQueue();
    expect(backend.pageCalls, 1);
    await database.writeOptimisticTransaction(
      entry: _entry('expense-1', 4000),
      clientMutationId: 'edit-new-revision',
      operation: 'update_transaction',
      payload: {'expenseId': original.id, 'originalEntry': original.toJson()},
    );
    final newer = service.refreshFromRemote(_query);
    await pumpEventQueue();
    expect(backend.pageCalls, 2);
    backend.gate.complete();
    await Future.wait([older, newer]);
    expect(
        (await database.getTransactionsFeedPage(_localQuery))
            .items
            .single
            .amount,
        40);
  });

  test('an optimistic edit during reconciliation remains authoritative',
      () async {
    final original = _entry('expense-1', 2000);
    await cache([original]);
    await notifier.loadInitial();
    final edited = _entry('expense-1', 4000);
    await database.writeOptimisticTransaction(
      entry: edited,
      clientMutationId: 'edit-1',
      operation: 'update_transaction',
      payload: {'expenseId': edited.id, 'originalEntry': original.toJson()},
    );
    notifier.applyEditedEntrySnapshot(edited);
    backend.gate.complete();
    await pumpEventQueue();
    expect(notifier.state.items.single.amount, 40);
    expect(notifier.state.summary.expenseTotal, 40);
    expect(notifier.state.isLoading, isFalse);
  });

  test('pull refresh retains cached rows while its request is pending',
      () async {
    await cache([_entry('expense-1', 2000)]);
    await notifier.loadInitial();
    final refresh = notifier.refresh();
    await pumpEventQueue();
    expect(notifier.state.hasLoadedInitial, isTrue);
    expect(notifier.state.items.single.amount, 20);
    expect(notifier.state.summary.expenseTotal, 20);
    backend.gate.complete();
    await refresh;
    await pumpEventQueue();
    expect(notifier.state.summary.expenseTotal, 30);
  });

  test('complete empty snapshot is usable while reconciliation is pending',
      () async {
    await cache([]);
    await notifier.loadInitial();
    expect(notifier.state.hasLoadedInitial, isTrue);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.items, isEmpty);
    backend.gate.complete();
    await pumpEventQueue();
    expect(notifier.state.items.single.id, 'expense-1');
  });

  test('no local cache remains loading until first successful remote read',
      () async {
    final operation = notifier.loadInitial();
    await pumpEventQueue();
    expect(notifier.state.hasLoadedInitial, isFalse);
    expect(notifier.state.isLoading, isTrue);
    backend.gate.complete();
    await operation;
    await pumpEventQueue();
    expect(notifier.state.hasLoadedInitial, isTrue);
    expect(notifier.state.summary.expenseTotal, 30);
  });

  test('partial rows cannot be promoted to a complete cached summary',
      () async {
    await database.upsertTransactions([_entry('expense-1', 2000)]);
    final service =
        LocalFirstTransactionsFeedService(database: database, remote: backend);
    expect(await service.fetchCachedSnapshot(_query), isNull);
    expect(backend.summaryCalls, 0);
    expect(backend.pageCalls, 0);
  });

  test('offline complete cache hydrates without remote reads', () async {
    await cache([_entry('expense-1', 2000)]);
    notifier.updateService(LocalFirstTransactionsFeedService(
      database: database,
      remote: backend,
      remoteEnabled: false,
    ));
    await notifier.loadInitial();
    expect(notifier.state.summary.expenseTotal, 20);
    expect(backend.summaryCalls, 0);
    expect(backend.pageCalls, 0);
  });

  test('an explicitly empty service still finishes its initial load', () async {
    notifier.updateService(const EmptyTransactionsFeedService());
    await notifier.loadInitial();
    expect(notifier.state.hasLoadedInitial, isTrue);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.items, isEmpty);
  });

  test('opening database is unresolved instead of a successful empty feed',
      () async {
    notifier.updateService(const OpeningDatabaseTransactionsFeedService());
    await notifier.loadInitial();
    await notifier.refresh();
    expect(notifier.state.hasLoadedInitial, isFalse);
    expect(notifier.state.isLoading, isTrue);
    await cache([_entry('expense-1', 2000)]);
    notifier.updateService(LocalFirstTransactionsFeedService(
      database: database,
      remote: backend,
      remoteEnabled: false,
    ));
    await pumpEventQueue();
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.summary.expenseTotal, 20);
  });

  test('reopening the feed hydrates canonical SQLite state', () async {
    await cache([_entry('expense-1', 2000)]);
    await notifier.loadInitial();
    backend.gate.complete();
    await pumpEventQueue();
    notifier.dispose();
    notifier = TransactionsFeedNotifier(
      service: LocalFirstTransactionsFeedService(
          database: database, remote: backend, remoteEnabled: false),
      query: _query,
    );
    await notifier.loadInitial();
    expect(notifier.state.items.single.amount, 30);
    expect(notifier.state.isLoading, isFalse);
  });
}
