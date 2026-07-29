import 'package:flutter/foundation.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class RecurringReadRemoteDataSource {
  Future<dynamic> invoke(
    String functionName, {
    required Map<String, dynamic> body,
  });
}

class SupabaseRecurringReadRemoteDataSource
    implements RecurringReadRemoteDataSource {
  const SupabaseRecurringReadRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<dynamic> invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.functions.invoke(functionName, body: body);
    return response.data;
  }
}

class RecurringReadException implements Exception {
  const RecurringReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecurringReadRepository {
  const RecurringReadRepository({
    required MonekoDatabase database,
    required RecurringReadRemoteDataSource remote,
  })  : _database = database,
        _remote = remote;

  static const _badgeNamespace = 'recurring_badge_v1';
  static const _seriesPageNamespace = 'recurring_series_page_v1';
  static const _seriesDetailNamespace = 'recurring_series_detail_v1';
  static const _occurrencePageNamespace = 'recurring_occurrence_page_v2';
  static const _occurrenceDetailNamespace = 'recurring_occurrence_detail_v1';

  final MonekoDatabase _database;
  final RecurringReadRemoteDataSource _remote;

  Future<bool?> readCachedBadge(RecurringReadScope scope) async {
    final cached = await _database.getJsonCache(
      namespace: _badgeNamespace,
      cacheKey: _scopeKey(scope),
    );
    final value = cached?.payload['value'];
    return value is bool ? value : null;
  }

  Future<bool> fetchBadge(RecurringReadScope scope) async {
    final data = await _invokeData(
      'recurring-read',
      body: {
        'operation': 'badge',
        ..._scopeBody(scope),
      },
    );
    if (data is! bool) {
      throw const RecurringReadException('Invalid recurring badge response');
    }
    await _database.upsertJsonCache(
      namespace: _badgeNamespace,
      cacheKey: _scopeKey(scope),
      payload: {'value': data},
    );
    return data;
  }

  Future<RecurringSeriesPage?> readCachedSeriesPage({
    required RecurringReadScope scope,
    RecurringSeriesCursor? cursor,
    int limit = 50,
  }) async {
    final cached = await _database.getJsonCache(
      namespace: _seriesPageNamespace,
      cacheKey: _seriesPageKey(scope, cursor, limit),
    );
    return cached == null
        ? null
        : _overlayPendingSeries(
            scope,
            RecurringSeriesPage.fromJson(cached.payload),
          );
  }

  Future<RecurringSeriesPage> fetchSeriesPage({
    required RecurringReadScope scope,
    RecurringSeriesCursor? cursor,
    int limit = 50,
  }) async {
    final data = _requireMap(await _invokeData(
      'recurring-read',
      body: {
        'operation': 'listSeries',
        ..._scopeBody(scope),
        if (cursor != null)
          'afterNextOccurrenceDate':
              formatDateOnlyYmd(cursor.nextOccurrenceDate),
        if (cursor != null) 'afterId': cursor.id,
        'limit': limit,
      },
    ));
    await _database.upsertJsonCache(
      namespace: _seriesPageNamespace,
      cacheKey: _seriesPageKey(scope, cursor, limit),
      payload: data,
    );
    return _overlayPendingSeries(scope, RecurringSeriesPage.fromJson(data));
  }

  Future<RecurringTransaction?> readCachedSeriesDetail({
    required String userId,
    required String recurringId,
  }) async {
    final cached = await _database.getJsonCache(
      namespace: _seriesDetailNamespace,
      cacheKey: '$userId|$recurringId',
    );
    return cached == null
        ? null
        : RecurringTransaction.fromJson(cached.payload);
  }

  Future<RecurringTransaction> fetchSeriesDetail({
    required String userId,
    required String recurringId,
  }) async {
    final data = _requireMap(await _invokeData(
      'recurring-read',
      body: {
        'operation': 'getSeries',
        'userId': userId,
        'recurringId': recurringId,
      },
    ));
    await _database.upsertJsonCache(
      namespace: _seriesDetailNamespace,
      cacheKey: '$userId|$recurringId',
      payload: data,
    );
    return RecurringTransaction.fromJson(data);
  }

  Future<RecurringOccurrencePage?> readCachedOccurrencePage({
    required String userId,
    required String recurringId,
    DateTime? beforeScheduledDate,
    int limit = 50,
  }) async {
    final cached = await _database.getJsonCache(
      namespace: _occurrencePageNamespace,
      cacheKey: _occurrencePageKey(
        userId,
        recurringId,
        beforeScheduledDate,
        limit,
      ),
    );
    return cached == null
        ? null
        : RecurringOccurrencePage.fromJson(cached.payload);
  }

  Future<RecurringOccurrencePage> fetchOccurrencePage({
    required String userId,
    required String recurringId,
    DateTime? beforeScheduledDate,
    int limit = 50,
  }) async {
    final data = _requireMap(await _invokeData(
      'list-recurring-occurrences',
      body: {
        'userId': userId,
        'recurringId': recurringId,
        if (beforeScheduledDate != null)
          'beforeScheduledDate': formatDateOnlyYmd(beforeScheduledDate),
        'limit': limit,
      },
    ));
    await _database.upsertJsonCache(
      namespace: _occurrencePageNamespace,
      cacheKey: _occurrencePageKey(
        userId,
        recurringId,
        beforeScheduledDate,
        limit,
      ),
      payload: data,
    );
    return RecurringOccurrencePage.fromJson(data);
  }

  Future<RecurringOccurrenceDetail?> readCachedOccurrenceDetail({
    required String userId,
    required String occurrenceId,
  }) async {
    final cached = await _database.getJsonCache(
      namespace: _occurrenceDetailNamespace,
      cacheKey: '$userId|$occurrenceId',
    );
    return cached == null
        ? null
        : RecurringOccurrenceDetail.fromJson(cached.payload);
  }

  Future<RecurringOccurrenceDetail> fetchOccurrenceDetail({
    required String userId,
    required String occurrenceId,
  }) async {
    final data = _requireMap(await _invokeData(
      'recurring-read',
      body: {
        'operation': 'getOccurrence',
        'userId': userId,
        'occurrenceId': occurrenceId,
      },
    ));
    await _database.upsertJsonCache(
      namespace: _occurrenceDetailNamespace,
      cacheKey: '$userId|$occurrenceId',
      payload: data,
    );
    return RecurringOccurrenceDetail.fromJson(data);
  }

  Future<void> invalidateScope(RecurringReadScope scope) async {
    final scopeKey = _scopeKey(scope);
    await _database.deleteJsonCacheByPrefix(
      namespace: _badgeNamespace,
      cacheKeyPrefix: scopeKey,
    );
    await _database.deleteJsonCacheByPrefix(
      namespace: _seriesPageNamespace,
      cacheKeyPrefix: scopeKey,
    );
  }

  Future<dynamic> _invokeData(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _remote.invoke(functionName, body: body);
    if (response is! Map || response['success'] != true) {
      final message = response is Map ? response['error']?.toString() : null;
      throw RecurringReadException(
        message ?? 'Unable to load recurring transactions',
      );
    }
    return response['data'];
  }

  Future<RecurringSeriesPage> _overlayPendingSeries(
    RecurringReadScope scope,
    RecurringSeriesPage page,
  ) async {
    final overlay = await _database.getPendingRecurringMutationOverlay(
      userId: scope.userId,
      householdId: scope.householdId,
    );
    if (overlay.upserts.isEmpty && overlay.deletedIds.isEmpty) return page;

    final byId = <String, RecurringSeriesSummary>{
      for (final item in page.items)
        if (!overlay.deletedIds.contains(item.transaction.id))
          item.transaction.id: item,
    };
    for (final entry in overlay.upserts) {
      final currency = entry.currency?.trim().toUpperCase();
      if (currency == null ||
          !scope.normalizedCurrencies.contains(currency) ||
          overlay.deletedIds.contains(entry.id)) {
        continue;
      }
      final transaction = _recurringTransactionFromEntry(entry);
      final previous = byId[entry.id];
      final sameRule = mapEquals(
        previous?.transaction.recurrenceRule?.toJson(),
        transaction.recurrenceRule?.toJson(),
      );
      byId[entry.id] = RecurringSeriesSummary(
        transaction: transaction,
        nextOccurrenceDate: sameRule
            ? previous?.nextOccurrenceDate
            : transaction.getNextOccurrence(DateTime.now()),
        latestActionableOccurrenceDate:
            sameRule ? previous?.latestActionableOccurrenceDate : null,
        actionableCount: sameRule ? previous?.actionableCount ?? 0 : 0,
      );
    }
    final items = byId.values.toList(growable: false)
      ..sort((left, right) {
        final leftDate = left.nextOccurrenceDate ?? DateTime(9999);
        final rightDate = right.nextOccurrenceDate ?? DateTime(9999);
        final byDate = leftDate.compareTo(rightDate);
        return byDate != 0
            ? byDate
            : left.transaction.id.compareTo(right.transaction.id);
      });
    return RecurringSeriesPage(
      items: items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  RecurringTransaction _recurringTransactionFromEntry(ExpenseEntry entry) {
    final rawRule = entry.recurrenceRuleJson;
    return RecurringTransaction(
      id: entry.id,
      userId: entry.userId,
      date: entry.date,
      category: entry.category ?? 'Uncategorized',
      description: entry.rawText,
      merchant: entry.merchant,
      amount: entry.amount,
      currency: entry.currency ?? 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      householdId: entry.householdId,
      splitGroupId: entry.splitGroupId,
      accountId: entry.walletId,
      recurrenceRule: rawRule == null ? null : RecurrenceRule.fromJson(rawRule),
      type: entry.type ?? 'expense',
      attachments: const [],
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      analyticsClass: entry.analyticsClass,
      analyticsIsFinal: entry.analyticsIsFinal,
      analyticsSpendingMultiplier: entry.analyticsSpendingMultiplier,
      analyticsCountsTowardIncome: entry.analyticsCountsTowardIncome,
    );
  }

  Map<String, dynamic> _requireMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const RecurringReadException('Invalid recurring read response');
  }

  Map<String, dynamic> _scopeBody(RecurringReadScope scope) => {
        'userId': scope.userId,
        if (scope.householdId != null) 'householdId': scope.householdId,
        'currencies': scope.normalizedCurrencies,
      };

  String _scopeKey(RecurringReadScope scope) => [
        scope.userId,
        scope.householdId ?? 'personal',
        scope.normalizedCurrencies.join(','),
      ].join('|');

  String _seriesPageKey(
    RecurringReadScope scope,
    RecurringSeriesCursor? cursor,
    int limit,
  ) =>
      '${_scopeKey(scope)}|${cursor == null ? 'first' : '${formatDateOnlyYmd(cursor.nextOccurrenceDate)}:${cursor.id}'}|$limit';

  String _occurrencePageKey(
    String userId,
    String recurringId,
    DateTime? beforeScheduledDate,
    int limit,
  ) =>
      '$userId|$recurringId|${beforeScheduledDate == null ? 'first' : formatDateOnlyYmd(beforeScheduledDate)}|$limit';
}
