import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

ExpenseEntry _entry(int cents) => ExpenseEntry(
      id: 'expense-1',
      userId: 'user-1',
      amountCents: cents,
      currency: 'EUR',
      category: 'food',
      type: 'expense',
      date: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 9, 20, 12),
    );

TransactionsFeedSummary _summary(int cents) => TransactionsFeedSummary(
      transactionCount: 1,
      expenseTotal: cents / 100,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: const [],
      yearlyPeriodTotals: const {},
    );

class _Read {
  final page = Completer<TransactionsFeedPageResult>();
  final summary = Completer<TransactionsFeedSummary>();

  void complete(int cents) {
    summary.complete(_summary(cents));
    page.complete(TransactionsFeedPageResult(
      items: [_entry(cents)],
      hasMore: false,
      nextCursor: null,
    ));
  }
}

class _HeldService extends EmptyTransactionsFeedService {
  final reads = <_Read>[];
  var pageCalls = 0;
  var revision = 0;

  @override
  int get reconciliationRevision => revision;

  @override
  Future<TransactionsFeedState?> fetchCachedSnapshot(
          TransactionsFeedQuery query) async =>
      TransactionsFeedState(
        items: [_entry(2000)],
        summary: _summary(2000),
        hasLoadedInitial: true,
      );

  @override
  Future<TransactionsFeedSummary> fetchSummary(TransactionsFeedQuery query) {
    final read = _Read();
    reads.add(read);
    return read.summary.future;
  }

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) =>
      reads[pageCalls++].page.future;
}

void main() {
  late _HeldService service;
  late TransactionsFeedNotifier notifier;

  setUp(() async {
    service = _HeldService();
    notifier = TransactionsFeedNotifier(service: service, query: _query);
    await notifier.loadInitial();
  });

  tearDown(() async {
    notifier.dispose();
    for (final read in service.reads) {
      if (!read.page.isCompleted) read.complete(2000);
    }
    await pumpEventQueue();
  });

  test('older completion cannot overwrite a newer optimistic refresh',
      () async {
    final states = <TransactionsFeedState>[];
    notifier.addListener(states.add);
    final older = notifier.refresh();
    await pumpEventQueue();
    notifier.applyEditedEntrySnapshot(_entry(4000));
    final newer = notifier.refresh(reason: 'mutation-refresh');
    await pumpEventQueue();
    expect(service.reads.length, 2);
    service.reads.last.complete(4000);
    await newer;
    service.reads.first.complete(2000);
    await older;
    expect(notifier.state.items.single.amount, 40);
    expect(notifier.state.summary.expenseTotal, 40);
    expect(service.reads.length, 2);
    final edited =
        states.indexWhere((state) => state.items.single.amount == 40);
    expect(
        states.skip(edited).every((state) => state.items.single.amount == 40),
        isTrue);
    expect(states.every((state) => state.hasLoadedInitial), isTrue);
  });

  test('an edit during a lone in-flight refresh requires a follow-up',
      () async {
    final pending = notifier.refresh();
    await pumpEventQueue();
    notifier.applyEditedEntrySnapshot(_entry(4000));
    service.reads.first.complete(2000);
    await pumpEventQueue();
    expect(notifier.state.items.single.amount, 40);
    expect(service.reads.length, 2);
    service.reads.last.complete(4000);
    await pending;
    expect(notifier.state.summary.expenseTotal, 40);
    expect(notifier.state.isLoading, isFalse);
  });

  test('a database revision starts new work even without an in-memory edit',
      () async {
    final older = notifier.refresh();
    await pumpEventQueue();
    service.revision++;
    final newer = notifier.refresh();
    await pumpEventQueue();
    expect(service.reads.length, 2);
    service.reads.last.complete(3000);
    await newer;
    service.reads.first.complete(2000);
    await older;
    expect(notifier.state.summary.expenseTotal, 30);
    expect(service.reads.length, 2);
  });

  test('an older failure cannot clear or error a newer successful state',
      () async {
    final older = notifier.refresh();
    await pumpEventQueue();
    notifier.applyEditedEntrySnapshot(_entry(4000));
    final newer = notifier.refresh();
    await pumpEventQueue();
    service.reads.last.complete(4000);
    await newer;
    service.reads.first.summary.completeError(StateError('old failure'));
    service.reads.first.page.completeError(StateError('old failure'));
    await older;
    expect(notifier.state.items.single.amount, 40);
    expect(notifier.state.error, isNull);
    expect(notifier.state.isLoading, isFalse);
    expect(service.reads.length, 2);
  });

  test('a superseding background failure releases an older refresh indicator',
      () async {
    final older = notifier.refresh();
    await pumpEventQueue();
    notifier.applyEditedEntrySnapshot(_entry(4000));
    final newer = notifier.refresh(background: true);
    await pumpEventQueue();
    service.reads.last.summary.completeError(StateError('offline'));
    service.reads.last.page.completeError(StateError('offline'));
    await newer;
    service.reads.first.complete(2000);
    await older;
    expect(notifier.state.items.single.amount, 40);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, isNull);
    expect(service.reads.length, 2);
  });
}
