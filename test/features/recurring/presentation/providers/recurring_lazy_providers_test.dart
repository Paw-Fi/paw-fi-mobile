import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/recurring/data/recurring_read_repository.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';

void main() {
  late MonekoDatabase database;
  late _ControlledRemote remote;
  late RecurringReadRepository repository;

  setUp(() {
    database = MonekoDatabase.inMemory();
    remote = _ControlledRemote();
    repository = RecurringReadRepository(database: database, remote: remote);
  });

  tearDown(() async {
    await database.close();
  });

  test('occurrence summary preserves pre-confirmation skip provenance', () {
    final occurrence = RecurringOccurrenceSummary.fromJson(const {
      'id': 'occurrence-1',
      'recurring_id': 'recurring-1',
      'scheduled_occurrence_date': '2026-07-01',
      'status': 'confirmed',
      'was_skipped_before_confirmation': true,
    });

    expect(occurrence.wasSkippedBeforeConfirmation, isTrue);
  });

  test('uncached series remains loading until the remote response resolves',
      () async {
    final response = Completer<dynamic>();
    remote.responses['recurring-read:listSeries'] = response.future;
    final container = _container(repository);
    addTearDown(container.dispose);
    const query = RecurringSeriesPageQuery(scope: _scope, pageSize: 20);
    final subscription = container.listen(
      recurringSeriesPageProvider(query),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
        container.read(recurringSeriesPageProvider(query)).isLoading, isTrue);

    response.complete(_seriesEnvelope('Fresh'));
    final state =
        await container.read(recurringSeriesPageProvider(query).future);

    expect(state.items.single.transaction.description, 'Fresh');
    expect(state.isRefreshing, isFalse);
  });

  test('cached series remains visible during background revalidation',
      () async {
    remote.responses['recurring-read:listSeries'] = _seriesEnvelope('Cached');
    await repository.fetchSeriesPage(scope: _scope, limit: 20);
    final refresh = Completer<dynamic>();
    remote.responses['recurring-read:listSeries'] = refresh.future;
    final container = _container(repository);
    addTearDown(container.dispose);
    const query = RecurringSeriesPageQuery(scope: _scope, pageSize: 20);
    final subscription = container.listen(
      recurringSeriesPageProvider(query),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final cached =
        await container.read(recurringSeriesPageProvider(query).future);
    expect(cached.items.single.transaction.description, 'Cached');
    await _flushEvents();
    final refreshing = container.read(recurringSeriesPageProvider(query));
    expect(
        refreshing.valueOrNull?.items.single.transaction.description, 'Cached');
    expect(refreshing.valueOrNull?.isRefreshing, isTrue);

    refresh.complete(_seriesEnvelope('Refreshed'));
    await _flushEvents();
    expect(
      container
          .read(recurringSeriesPageProvider(query))
          .valueOrNull
          ?.items
          .single
          .transaction
          .description,
      'Refreshed',
    );
  });

  test('cached false badge is retained while revalidating', () async {
    remote.responses['recurring-read:badge'] = {
      'success': true,
      'data': false,
    };
    await repository.fetchBadge(_scope);
    final refresh = Completer<dynamic>();
    remote.responses['recurring-read:badge'] = refresh.future;
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      recurringActionableBadgeProvider(_scope),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      await container.read(recurringActionableBadgeProvider(_scope).future),
      isFalse,
    );
    await _flushEvents();
    expect(
      container.read(recurringActionableBadgeProvider(_scope)).valueOrNull,
      isFalse,
    );

    refresh.complete({'success': true, 'data': true});
    await _flushEvents();
    expect(
      container.read(recurringActionableBadgeProvider(_scope)).valueOrNull,
      isTrue,
    );
  });

  test('older failed series mutation cannot roll back a newer edit', () {
    final notifier = RecurringSeriesOptimisticNotifier();
    final first = notifier.upsert(
      mutationId: 'first',
      transaction: _transaction('First'),
    );
    final second = notifier.upsert(
      mutationId: 'second',
      transaction: _transaction('Second'),
    );

    expect(notifier.rollback(first), isFalse);
    expect(notifier.state[_seriesId]?.transaction?.description, 'Second');
    expect(notifier.rollback(second), isTrue);
    expect(notifier.state[_seriesId]?.transaction?.description, 'First');
  });

  test('series overlay removes and restores the matching scoped row', () {
    final notifier = RecurringSeriesOptimisticNotifier();
    final base = [
      RecurringSeriesSummary(
        transaction: _transaction('Original'),
        nextOccurrenceDate: DateTime(2026, 8, 15),
        latestActionableOccurrenceDate: null,
      ),
    ];
    final handle = notifier.remove(
      mutationId: 'delete',
      recurringId: _seriesId,
      householdId: null,
    );

    expect(notifier.apply(_scope, base), isEmpty);
    expect(notifier.rollback(handle), isTrue);
    expect(notifier.apply(_scope, base).single.transaction.description,
        'Original');
  });

  test('series overlay applies a current-month confirmation delta', () {
    final notifier = RecurringSeriesOptimisticNotifier();
    final base = [
      RecurringSeriesSummary(
        transaction: _transaction('Original'),
        nextOccurrenceDate: DateTime(2026, 8, 15),
        latestActionableOccurrenceDate: null,
      ),
    ];

    notifier.upsert(
      mutationId: 'confirm-current-month',
      transaction: _transaction('Original'),
      currentMonthConfirmedAmountDeltaCents: -500,
    );

    expect(
      notifier.apply(_scope, base).single.currentMonthConfirmedAmountDeltaCents,
      -500,
    );
  });

  test('older failed occurrence mutation cannot overwrite a newer state', () {
    final notifier = RecurringOccurrenceOptimisticNotifier();
    final first = notifier.upsert(
      mutationId: 'first-occurrence',
      occurrence: _occurrence('confirmed', 2500),
    );
    final second = notifier.upsert(
      mutationId: 'second-occurrence',
      occurrence: _occurrence('confirmed', 3200),
    );

    expect(notifier.rollback(first), isFalse);
    expect(notifier.state.values.single.occurrence?.amountCents, 3200);
    expect(notifier.rollback(second), isTrue);
    expect(notifier.state.values.single.occurrence?.amountCents, 2500);
  });

  test('complete cached summaries drive a revision-safe optimistic badge',
      () async {
    remote.responses['recurring-read:listSeries'] = _seriesEnvelope('Cached');
    remote.responses['recurring-read:badge'] = {
      'success': true,
      'data': true,
    };
    await repository.fetchSeriesPage(scope: _scope);
    await repository.fetchBadge(_scope);

    final pendingSeriesRefresh = Completer<dynamic>();
    final pendingBadgeRefresh = Completer<dynamic>();
    remote.responses['recurring-read:listSeries'] = pendingSeriesRefresh.future;
    remote.responses['recurring-read:badge'] = pendingBadgeRefresh.future;
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      recurringActionableBadgeProvider(_scope),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      await container.read(recurringActionableBadgeProvider(_scope).future),
      isTrue,
    );

    final first =
        container.read(recurringSeriesOptimisticProvider.notifier).upsert(
              mutationId: 'confirm-first',
              transaction: _transaction('Confirmed').copyWith(
                clearServerLatestActionableOccurrenceDate: true,
              ),
            );
    await _flushEvents();
    expect(
      container.read(recurringActionableBadgeProvider(_scope)).valueOrNull,
      isFalse,
    );

    container.read(recurringSeriesOptimisticProvider.notifier).upsert(
          mutationId: 'confirm-second',
          transaction: _transaction('Newer').copyWith(
            serverLatestActionableOccurrenceDate: DateTime(2026, 7, 15),
          ),
        );
    expect(
      container
          .read(recurringSeriesOptimisticProvider.notifier)
          .rollback(first),
      isFalse,
    );
    await _flushEvents();
    expect(
      container.read(recurringActionableBadgeProvider(_scope)).valueOrNull,
      isTrue,
    );
  });
}

ProviderContainer _container(RecurringReadRepository repository) {
  return ProviderContainer(
    overrides: [
      recurringReadRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
}

Future<void> _flushEvents() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _ControlledRemote implements RecurringReadRemoteDataSource {
  final Map<String, dynamic> responses = {};

  @override
  Future<dynamic> invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    final operation = body['operation']?.toString() ?? 'none';
    return await responses['$functionName:$operation'];
  }
}

const _scope = RecurringReadScope(
  userId: '11111111-1111-4111-8111-111111111111',
  householdId: null,
  currencies: ['USD'],
);

const _seriesId = '22222222-2222-4222-8222-222222222222';

RecurringTransaction _transaction(String description) => RecurringTransaction(
      id: _seriesId,
      userId: _scope.userId,
      date: DateTime(2026, 1, 15),
      category: 'Subscriptions',
      description: description,
      amount: 25,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 1, 15),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 1, 1),
    );

RecurringOccurrenceSummary _occurrence(String status, int amountCents) =>
    RecurringOccurrenceSummary(
      id: '33333333-3333-4333-8333-333333333333',
      recurringId: _seriesId,
      scheduledOccurrenceDate: DateTime(2026, 7, 15),
      status: status,
      confirmationSource: 'user',
      actualTransactionId: '44444444-4444-4444-8444-444444444444',
      paidDate: DateTime(2026, 7, 15),
      amountCents: amountCents,
      currency: 'USD',
      confirmedAt: DateTime(2026, 7, 15),
      confirmedByUserId: _scope.userId,
      createdAt: DateTime(2026, 7, 15),
      updatedAt: DateTime(2026, 7, 15),
    );

Map<String, dynamic> _seriesEnvelope(String description) => {
      'success': true,
      'data': {
        'items': [
          {
            'id': _seriesId,
            'user_id': _scope.userId,
            'date': '2026-01-15',
            'category': 'Subscriptions',
            'raw_text': description,
            'amount_cents': 2500,
            'currency': 'USD',
            'owner_type': 'me',
            'privacy_scope': 'full',
            'is_recurring': true,
            'recurrence_rule': {
              'frequency': 'monthly',
              'anchor_date': '2026-01-15',
              'interval': 1,
              'projection_enabled': true,
            },
            'type': 'expense',
            'created_at': '2026-01-01T10:00:00Z',
            'next_occurrence_date': '2026-08-15',
            'latest_actionable_occurrence_date': '2026-07-15',
            'actionable_count': 1,
          },
        ],
        'has_more': false,
        'next_cursor': null,
      },
    };
