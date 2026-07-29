import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/recurring/data/recurring_read_repository.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

void main() {
  late MonekoDatabase database;
  late _FakeRecurringReadRemoteDataSource remote;
  late RecurringReadRepository repository;

  setUp(() {
    database = MonekoDatabase.inMemory();
    remote = _FakeRecurringReadRemoteDataSource();
    repository = RecurringReadRepository(database: database, remote: remote);
  });

  tearDown(() async {
    await database.close();
  });

  test('series summary fetch stores a lightweight page in SQLite', () async {
    remote.responses['recurring-read:listSeries'] = {
      'success': true,
      'data': {
        'items': [_seriesSummaryJson],
        'has_more': true,
        'next_cursor': {
          'next_occurrence_date': '2026-08-15',
          'id': _seriesId,
        },
      },
    };
    const scope = RecurringReadScope(
      userId: _userId,
      householdId: null,
      currencies: ['EUR', 'USD'],
    );

    final fetched = await repository.fetchSeriesPage(scope: scope, limit: 20);
    final cached = await repository.readCachedSeriesPage(
      scope: scope,
      limit: 20,
    );

    expect(fetched.items, hasLength(1));
    expect(fetched.items.single.transaction.id, _seriesId);
    expect(fetched.items.single.nextOccurrenceDate, DateTime(2026, 8, 15));
    expect(fetched.items.single.latestActionableOccurrenceDate,
        DateTime(2026, 7, 15));
    expect(fetched.items.single.actionableCount, 2);
    expect(fetched.hasMore, isTrue);
    expect(cached?.items.single.transaction.attachments, isEmpty);
    expect(cached?.nextCursor?.id, _seriesId);
    expect(remote.calls, ['recurring-read:listSeries']);
  });

  test('authoritative false badge remains a trustworthy cached value',
      () async {
    remote.responses['recurring-read:badge'] = {
      'success': true,
      'data': false,
    };
    const scope = RecurringReadScope(
      userId: _userId,
      householdId: null,
      currencies: ['USD'],
    );

    expect(await repository.fetchBadge(scope), isFalse);
    expect(await repository.readCachedBadge(scope), isFalse);
  });

  test('minimal occurrence history excludes detail and round-trips', () async {
    remote.responses['list-recurring-occurrences:none'] = {
      'success': true,
      'data': {
        'items': [_occurrenceSummaryJson],
        'has_more': false,
        'next_cursor': null,
      },
    };

    final fetched = await repository.fetchOccurrencePage(
      userId: _userId,
      recurringId: _seriesId,
      limit: 20,
    );
    final cached = await repository.readCachedOccurrencePage(
      userId: _userId,
      recurringId: _seriesId,
      limit: 20,
    );

    expect(fetched.items.single.status, 'confirmed');
    expect(fetched.items.single.actualTransactionId, _actualId);
    expect(cached?.items.single.scheduledOccurrenceDate, DateTime(2026, 7, 15));
  });

  test('series and occurrence details use independent cache entries', () async {
    remote.responses['recurring-read:getSeries'] = {
      'success': true,
      'data': {..._seriesSummaryJson, 'attachments': const []},
    };
    remote.responses['recurring-read:getOccurrence'] = {
      'success': true,
      'data': {
        'occurrence': _occurrenceSummaryJson,
        'transaction': {
          'id': _actualId,
          'user_id': _userId,
          'date': '2026-07-15',
          'type': 'expense',
          'amount_cents': 2500,
          'currency': 'USD',
          'category': 'Subscriptions',
          'raw_text': 'Music',
          'created_at': '2026-07-15T10:00:00Z',
        },
        'split_group': null,
        'settlement_locked': false,
      },
    };

    final series = await repository.fetchSeriesDetail(
      userId: _userId,
      recurringId: _seriesId,
    );
    final occurrence = await repository.fetchOccurrenceDetail(
      userId: _userId,
      occurrenceId: _occurrenceId,
    );

    expect(series.id, _seriesId);
    expect(occurrence.occurrence.id, _occurrenceId);
    expect(occurrence.transaction?['id'], _actualId);
    expect(
      (await repository.readCachedSeriesDetail(
        userId: _userId,
        recurringId: _seriesId,
      ))
          ?.id,
      _seriesId,
    );
    expect(
      (await repository.readCachedOccurrenceDetail(
        userId: _userId,
        occurrenceId: _occurrenceId,
      ))
          ?.occurrence
          .id,
      _occurrenceId,
    );
  });

  test('queued recurring update overlays a persisted summary after restart',
      () async {
    remote.responses['recurring-read:listSeries'] = {
      'success': true,
      'data': {
        'items': [_seriesSummaryJson],
        'has_more': false,
        'next_cursor': null,
      },
    };
    const scope = RecurringReadScope(
      userId: _userId,
      householdId: null,
      currencies: ['USD'],
    );
    await repository.fetchSeriesPage(scope: scope);
    await database.writeOptimisticTransactionUpdate(
      originalEntry: _recurringEntry('Music'),
      updatedEntry: _recurringEntry('Local edit'),
      clientMutationId: 'update-recurring',
      payload: const {'functionName': 'update-expense'},
    );

    final cached = await repository.readCachedSeriesPage(scope: scope);

    expect(cached?.items.single.transaction.description, 'Local edit');
  });

  test('queued recurring deletion removes a persisted summary after restart',
      () async {
    remote.responses['recurring-read:listSeries'] = {
      'success': true,
      'data': {
        'items': [_seriesSummaryJson],
        'has_more': false,
        'next_cursor': null,
      },
    };
    const scope = RecurringReadScope(
      userId: _userId,
      householdId: null,
      currencies: ['USD'],
    );
    await repository.fetchSeriesPage(scope: scope);
    await database.writeOptimisticTransactionDelete(
      entries: [_recurringEntry('Music')],
      clientMutationId: 'delete-recurring',
      operation: 'delete_recurring_template',
      payload: const {'functionName': 'delete-expense'},
    );

    final cached = await repository.readCachedSeriesPage(scope: scope);

    expect(cached?.items, isEmpty);
  });
}

ExpenseEntry _recurringEntry(String description) => ExpenseEntry(
      id: _seriesId,
      userId: _userId,
      date: DateTime(2026, 1, 15),
      amountCents: 2500,
      currency: 'USD',
      category: 'Subscriptions',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
      rawText: description,
      type: 'expense',
      isRecurring: true,
      recurrenceRuleJson: const {
        'frequency': 'monthly',
        'anchor_date': '2026-01-15',
        'interval': 1,
        'projection_enabled': true,
      },
    );

class _FakeRecurringReadRemoteDataSource
    implements RecurringReadRemoteDataSource {
  final Map<String, dynamic> responses = {};
  final List<String> calls = [];

  @override
  Future<dynamic> invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    final operation = body['operation']?.toString() ?? 'none';
    final key = '$functionName:$operation';
    calls.add(key);
    return responses[key];
  }
}

const _userId = '11111111-1111-4111-8111-111111111111';
const _seriesId = '22222222-2222-4222-8222-222222222222';
const _occurrenceId = '33333333-3333-4333-8333-333333333333';
const _actualId = '44444444-4444-4444-8444-444444444444';

const _seriesSummaryJson = <String, dynamic>{
  'id': _seriesId,
  'user_id': _userId,
  'date': '2026-01-15',
  'category': 'Subscriptions',
  'raw_text': 'Music',
  'merchant': 'Music Co',
  'source': null,
  'amount_cents': 2500,
  'currency': 'USD',
  'owner_type': 'me',
  'privacy_scope': 'full',
  'household_id': null,
  'split_group_id': null,
  'account_id': null,
  'is_recurring': true,
  'recurrence_rule': {
    'frequency': 'monthly',
    'anchor_date': '2026-01-15',
    'interval': 1,
    'projection_enabled': true,
  },
  'type': 'expense',
  'created_at': '2026-01-01T10:00:00Z',
  'updated_at': '2026-07-01T10:00:00Z',
  'next_occurrence_date': '2026-08-15',
  'latest_actionable_occurrence_date': '2026-07-15',
  'actionable_count': 2,
};

const _occurrenceSummaryJson = <String, dynamic>{
  'id': _occurrenceId,
  'recurring_id': _seriesId,
  'scheduled_occurrence_date': '2026-07-15',
  'status': 'confirmed',
  'confirmation_source': 'user',
  'actual_transaction_id': _actualId,
  'paid_date': '2026-07-15',
  'amount_cents': 2500,
  'currency': 'USD',
  'confirmed_at': '2026-07-15T10:00:00Z',
  'confirmed_by_user_id': _userId,
  'created_at': '2026-07-15T10:00:00Z',
  'updated_at': '2026-07-15T10:00:00Z',
};
