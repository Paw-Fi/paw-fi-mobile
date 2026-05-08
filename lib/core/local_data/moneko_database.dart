import 'dart:async';
import 'dart:convert';

import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const String localSyncStatusSynced = 'synced';
const String localSyncStatusLocal = 'local';
const String localSyncStatusFailed = 'failed';
const String localMutationStatusQueued = 'queued';
const String localMutationStatusSyncing = 'syncing';
const String localMutationStatusFailed = 'failed';
const String localMutationStatusSynced = 'synced';
const String localMutationStatusCancelled = 'cancelled';

String localScopeKey({
  required String userId,
  required String? householdId,
}) {
  final trimmedHouseholdId = householdId?.trim();
  if (trimmedHouseholdId != null && trimmedHouseholdId.isNotEmpty) {
    return 'household:$trimmedHouseholdId';
  }
  return '$userId:personal';
}

DateTime localMonthBucket(DateTime value) => DateTime(value.year, value.month);

class MonthlySummary {
  const MonthlySummary({
    required this.scopeKey,
    required this.month,
    required this.currency,
    required this.incomeCents,
    required this.expenseCents,
    required this.transactionCount,
    required this.updatedAt,
  });

  final String scopeKey;
  final DateTime month;
  final String currency;
  final int incomeCents;
  final int expenseCents;
  final int transactionCount;
  final DateTime updatedAt;
}

class LocalTransactionFeedCursor {
  const LocalTransactionFeedCursor({
    required this.date,
    required this.createdAt,
    required this.id,
  });

  final DateTime date;
  final DateTime createdAt;
  final String id;
}

class LocalTransactionsFeedQuery {
  const LocalTransactionsFeedQuery({
    required this.userId,
    required this.householdId,
    this.currency,
    this.category,
    this.categories,
    this.accountId,
    this.includeUnassignedAccount = false,
    this.type = 'all',
    this.searchQuery,
    this.startDate,
    this.endDate,
    this.pageSize = 60,
    this.cursor,
    this.intervalGranularity = 'yearly',
  });

  final String userId;
  final String? householdId;
  final String? currency;
  final String? category;
  final List<String>? categories;
  final String? accountId;
  final bool includeUnassignedAccount;
  final String type;
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final int pageSize;
  final LocalTransactionFeedCursor? cursor;
  final String intervalGranularity;

  LocalTransactionsFeedQuery copyWith({
    LocalTransactionFeedCursor? cursor,
    int? pageSize,
  }) {
    return LocalTransactionsFeedQuery(
      userId: userId,
      householdId: householdId,
      currency: currency,
      category: category,
      categories: categories,
      accountId: accountId,
      includeUnassignedAccount: includeUnassignedAccount,
      type: type,
      searchQuery: searchQuery,
      startDate: startDate,
      endDate: endDate,
      pageSize: pageSize ?? this.pageSize,
      cursor: cursor ?? this.cursor,
      intervalGranularity: intervalGranularity,
    );
  }
}

class LocalTransactionsFeedPage {
  const LocalTransactionsFeedPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<ExpenseEntry> items;
  final bool hasMore;
  final LocalTransactionFeedCursor? nextCursor;
}

class LocalTransactionCategorySummary {
  const LocalTransactionCategorySummary({
    required this.category,
    required this.amountCents,
    required this.transactionCount,
  });

  final String category;
  final int amountCents;
  final int transactionCount;
}

class LocalTransactionsFeedSummary {
  const LocalTransactionsFeedSummary({
    required this.transactionCount,
    required this.expenseTotalCents,
    required this.incomeTotalCents,
    required this.hasMultipleCurrencies,
    required this.categorySummaries,
    required this.yearlyPeriodTotalsCents,
    required this.periodTotalsCents,
  });

  final int transactionCount;
  final int expenseTotalCents;
  final int incomeTotalCents;
  final bool hasMultipleCurrencies;
  final List<LocalTransactionCategorySummary> categorySummaries;
  final Map<DateTime, int> yearlyPeriodTotalsCents;
  final Map<DateTime, int> periodTotalsCents;
}

class LocalMutationOutboxData {
  const LocalMutationOutboxData({
    required this.id,
    required this.clientMutationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.createdAt,
    required this.updatedAt,
    required this.attemptCount,
    required this.status,
    required this.lastError,
    required this.retryAfter,
  });

  final int id;
  final String clientMutationId;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attemptCount;
  final String status;
  final String? lastError;
  final DateTime? retryAfter;
}

class MonekoDatabase {
  MonekoDatabase._(this._db) {
    _createSchema();
  }

  factory MonekoDatabase.inMemory() => MonekoDatabase._(sqlite3.openInMemory());

  static Future<MonekoDatabase> openDefault() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final dbPath = p.join(directory.path, 'moneko_local.sqlite');
    return MonekoDatabase._(sqlite3.open(dbPath));
  }

  final Database _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Future<void> close() async {
    await _changes.close();
    _db.dispose();
  }

  Future<void> upsertTransactions(
    List<ExpenseEntry> entries, {
    String syncStatus = localSyncStatusSynced,
  }) async {
    if (entries.isEmpty) return;

    final touched = <_SummaryKey>{};
    _runInTransaction(() {
      for (final entry in entries) {
        _upsertTransaction(entry, syncStatus: syncStatus);
        touched.add(_SummaryKey.fromEntry(entry));
      }

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> writeOptimisticTransaction({
    required ExpenseEntry entry,
    required String clientMutationId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    _runInTransaction(() {
      _upsertTransaction(entry, syncStatus: localSyncStatusLocal);
      _enqueueMutationRow(
        clientMutationId: clientMutationId,
        entityType: 'transaction',
        entityId: entry.id,
        operation: operation,
        payload: payload,
      );
      _rebuildSummary(_SummaryKey.fromEntry(entry));
    });

    _notifyChanged();
  }

  Future<void> writeOptimisticTransactionUpdate({
    required ExpenseEntry originalEntry,
    required ExpenseEntry updatedEntry,
    required String clientMutationId,
    required Map<String, dynamic> payload,
  }) async {
    final touched = <_SummaryKey>{
      _SummaryKey.fromEntry(originalEntry),
      _SummaryKey.fromEntry(updatedEntry),
    };

    _runInTransaction(() {
      _upsertTransaction(updatedEntry, syncStatus: localSyncStatusLocal);
      _enqueueMutationRow(
        clientMutationId: clientMutationId,
        entityType: 'transaction',
        entityId: updatedEntry.id,
        operation: 'update_transaction',
        payload: payload,
      );

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> markOptimisticTransactionUpdateSynced({
    required ExpenseEntry entry,
    required String clientMutationId,
  }) async {
    _runInTransaction(() {
      _upsertTransaction(entry, syncStatus: localSyncStatusSynced);
      _markMutationStatus(
        clientMutationId: clientMutationId,
        status: localMutationStatusSynced,
      );
      _rebuildSummary(_SummaryKey.fromEntry(entry));
    });

    _notifyChanged();
  }

  Future<void> rollbackOptimisticTransactionUpdate({
    required ExpenseEntry originalEntry,
    required String clientMutationId,
    required Object error,
  }) async {
    final touched = <_SummaryKey>{_SummaryKey.fromEntry(originalEntry)};
    final updatedKey = _summaryKeyForTransactionId(originalEntry.id);
    if (updatedKey != null) touched.add(updatedKey);

    _runInTransaction(() {
      _upsertTransaction(originalEntry, syncStatus: localSyncStatusSynced);
      _markMutationCancelledRow(
        clientMutationId: clientMutationId,
        error: error,
      );

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> writeOptimisticTransactionDelete({
    required List<ExpenseEntry> entries,
    required String clientMutationId,
    required Map<String, dynamic> payload,
  }) async {
    if (entries.isEmpty) return;

    final touched = entries.map(_SummaryKey.fromEntry).toSet();
    _runInTransaction(() {
      for (final entry in entries) {
        _db.execute(
          'DELETE FROM local_transactions WHERE id = ?',
          [entry.id],
        );
      }
      _enqueueMutationRow(
        clientMutationId: clientMutationId,
        entityType: 'transaction',
        entityId: entries.map((entry) => entry.id).join(','),
        operation: 'delete_transaction',
        payload: payload,
      );

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> markOptimisticTransactionDeleteSynced({
    required String clientMutationId,
  }) async {
    _markMutationStatus(
      clientMutationId: clientMutationId,
      status: localMutationStatusSynced,
    );
  }

  Future<void> rollbackOptimisticTransactionDelete({
    required List<ExpenseEntry> entries,
    required String clientMutationId,
    required Object error,
  }) async {
    if (entries.isEmpty) return;

    final touched = entries.map(_SummaryKey.fromEntry).toSet();
    _runInTransaction(() {
      for (final entry in entries) {
        _upsertTransaction(entry, syncStatus: localSyncStatusSynced);
      }
      _markMutationCancelledRow(
        clientMutationId: clientMutationId,
        error: error,
      );

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> replaceOptimisticTransaction({
    required String optimisticId,
    required ExpenseEntry savedEntry,
    required String clientMutationId,
  }) async {
    final touched = <_SummaryKey>{};
    _runInTransaction(() {
      final optimisticKey = _summaryKeyForTransactionId(optimisticId);
      if (optimisticKey != null) touched.add(optimisticKey);

      _db.execute(
        'DELETE FROM local_transactions WHERE id = ?',
        [optimisticId],
      );

      _upsertTransaction(savedEntry, syncStatus: localSyncStatusSynced);
      touched.add(_SummaryKey.fromEntry(savedEntry));
      _markMutationStatus(
        clientMutationId: clientMutationId,
        status: localMutationStatusSynced,
      );

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> rollbackOptimisticTransaction({
    required String optimisticId,
    required String clientMutationId,
    required Object error,
  }) async {
    final touched = <_SummaryKey>{};
    _runInTransaction(() {
      final optimisticKey = _summaryKeyForTransactionId(optimisticId);
      if (optimisticKey != null) touched.add(optimisticKey);

      _db.execute(
        'DELETE FROM local_transactions WHERE id = ?',
        [optimisticId],
      );
      _markMutationCancelledRow(
        clientMutationId: clientMutationId,
        error: error,
      );

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> deleteTransactionsByIds(List<String> ids) async {
    final normalizedIds =
        ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (normalizedIds.isEmpty) return;

    final touched = <_SummaryKey>{};
    _runInTransaction(() {
      for (final id in normalizedIds) {
        final key = _summaryKeyForTransactionId(id);
        if (key != null) touched.add(key);
        _db.execute('DELETE FROM local_transactions WHERE id = ?', [id]);
      }

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<void> reconcileTransactionsFeedPage({
    required LocalTransactionsFeedQuery query,
    required List<ExpenseEntry> authoritativeItems,
    required bool remoteHasMore,
  }) async {
    final authoritativeIds = authoritativeItems
        .map((entry) => entry.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final boundary =
        authoritativeItems.isEmpty ? null : authoritativeItems.last;

    if (remoteHasMore && boundary == null) {
      return;
    }

    final filter = _localFeedFilter(query, includeCursor: false);
    final deleteConditions = <String>[
      filter.whereSql,
      'sync_status = ?',
    ];
    final deleteArgs = <Object?>[
      ...filter.args,
      localSyncStatusSynced,
    ];

    if (authoritativeIds.isNotEmpty) {
      deleteConditions.add(
        'id NOT IN (${List.filled(authoritativeIds.length, '?').join(', ')})',
      );
      deleteArgs.addAll(authoritativeIds);
    }

    if (remoteHasMore) {
      deleteConditions.add('''
        (
          date > ?
          OR (
            date = ?
            AND (
              created_at > ?
              OR (created_at = ? AND id >= ?)
            )
          )
        )
      ''');
      deleteArgs.addAll([
        _dateOnly(boundary!.date),
        _dateOnly(boundary.date),
        _instant(boundary.createdAt),
        _instant(boundary.createdAt),
        boundary.id,
      ]);
    }

    final whereSql = deleteConditions.join(' AND ');
    final touched = <_SummaryKey>{};

    _runInTransaction(() {
      final rows = _db.select(
        '''
        SELECT user_id, household_id, date, currency
        FROM local_transactions
        WHERE $whereSql
        ''',
        deleteArgs,
      );
      for (final row in rows) {
        touched.add(_SummaryKey(
          scopeKey: localScopeKey(
            userId: row['user_id'] as String,
            householdId: row['household_id'] as String?,
          ),
          month: localMonthBucket(DateTime.parse(row['date'] as String)),
          currency: (row['currency'] as String).toUpperCase(),
        ));
      }

      if (rows.isEmpty) {
        return;
      }

      _db.execute(
        '''
        DELETE FROM local_transactions
        WHERE $whereSql
        ''',
        deleteArgs,
      );

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    if (touched.isNotEmpty) {
      _notifyChanged();
    }
  }

  Future<void> replaceRecurringTransactionsForScope({
    required String userId,
    required String? householdId,
    required List<ExpenseEntry> entries,
  }) async {
    final scope = localScopeKey(userId: userId, householdId: householdId);
    final touched = <_SummaryKey>{};

    _runInTransaction(() {
      final existingRows = _db.select(
        '''
        SELECT user_id, household_id, date, currency
        FROM local_transactions
        WHERE scope_key = ?
          AND is_recurring = 1
          AND sync_status = ?
        ''',
        [scope, localSyncStatusSynced],
      );
      for (final row in existingRows) {
        touched.add(_SummaryKey(
          scopeKey: scope,
          month: localMonthBucket(DateTime.parse(row['date'] as String)),
          currency: (row['currency'] as String).toUpperCase(),
        ));
      }

      _db.execute(
        '''
        DELETE FROM local_transactions
        WHERE scope_key = ?
          AND is_recurring = 1
          AND sync_status = ?
        ''',
        [scope, localSyncStatusSynced],
      );

      for (final entry in entries) {
        _upsertTransaction(entry, syncStatus: localSyncStatusSynced);
        touched.add(_SummaryKey.fromEntry(entry));
      }

      for (final key in touched) {
        _rebuildSummary(key);
      }
    });

    _notifyChanged();
  }

  Future<List<ExpenseEntry>> getRecentTransactions({
    required String userId,
    required String? householdId,
    int limit = 60,
  }) async {
    final scope = localScopeKey(userId: userId, householdId: householdId);
    final rows = _db.select(
      '''
      SELECT *
      FROM local_transactions
      WHERE scope_key = ? AND deleted_at IS NULL
      ORDER BY date DESC, created_at DESC
      LIMIT ?
      ''',
      [scope, limit],
    );

    return rows.map(_entryFromTransactionRow).toList(growable: false);
  }

  Future<List<ExpenseEntry>> getRecurringTransactions({
    required String userId,
    required String? householdId,
    int limit = 250,
  }) async {
    final scope = localScopeKey(userId: userId, householdId: householdId);
    final rows = _db.select(
      '''
      SELECT *
      FROM local_transactions
      WHERE scope_key = ?
        AND deleted_at IS NULL
        AND is_recurring = 1
      ORDER BY date DESC, created_at DESC
      LIMIT ?
      ''',
      [scope, limit.clamp(1, 1000)],
    );

    return rows.map(_entryFromTransactionRow).toList(growable: false);
  }

  Future<LocalTransactionsFeedPage> getTransactionsFeedPage(
    LocalTransactionsFeedQuery query,
  ) async {
    final filter = _localFeedFilter(query, includeCursor: true);
    final pageSize = query.pageSize.clamp(1, 500);
    final rows = _db.select(
      '''
      SELECT *
      FROM local_transactions
      WHERE ${filter.whereSql}
      ORDER BY date DESC, created_at DESC, id DESC
      LIMIT ?
      ''',
      [...filter.args, pageSize + 1],
    );

    final visibleRows = rows.take(pageSize).toList(growable: false);
    final items = visibleRows.map(_entryFromTransactionRow).toList(
          growable: false,
        );
    final last = items.isEmpty ? null : items.last;

    return LocalTransactionsFeedPage(
      items: items,
      hasMore: rows.length > pageSize,
      nextCursor: last == null
          ? null
          : LocalTransactionFeedCursor(
              date: last.date,
              createdAt: last.createdAt,
              id: last.id,
            ),
    );
  }

  Future<List<ExpenseEntry>> getTransactionsFeedItems(
    LocalTransactionsFeedQuery query,
  ) async {
    final items = <ExpenseEntry>[];
    LocalTransactionFeedCursor? cursor = query.cursor;
    var hasMore = true;
    while (hasMore) {
      final page = await getTransactionsFeedPage(query.copyWith(
        cursor: cursor,
        pageSize: query.pageSize,
      ));
      items.addAll(page.items);
      hasMore = page.hasMore;
      cursor = page.nextCursor;
      if (page.items.isEmpty) break;
    }
    return items;
  }

  Future<LocalTransactionsFeedSummary> getTransactionsFeedSummary(
    LocalTransactionsFeedQuery query,
  ) async {
    final filter = _localFeedFilter(query, includeCursor: false);
    final totals = _db.select(
      '''
      SELECT
        COUNT(*) AS transaction_count,
        SUM(CASE WHEN LOWER(COALESCE(type, 'expense')) = 'income'
          THEN ABS(amount_cents) ELSE 0 END) AS income_total_cents,
        SUM(CASE WHEN LOWER(COALESCE(type, 'expense')) = 'income'
          THEN 0 ELSE ABS(amount_cents) END) AS expense_total_cents,
        COUNT(DISTINCT currency) AS currency_count
      FROM local_transactions
      WHERE ${filter.whereSql}
      ''',
      filter.args,
    ).first;

    final categoryRows = _db.select(
      '''
      SELECT
        LOWER(COALESCE(NULLIF(TRIM(category), ''), 'uncategorized')) AS category_key,
        SUM(ABS(amount_cents)) AS amount_cents,
        COUNT(*) AS transaction_count
      FROM local_transactions
      WHERE ${filter.whereSql}
        AND LOWER(COALESCE(type, 'expense')) != 'income'
      GROUP BY category_key
      ORDER BY amount_cents DESC, category_key ASC
      ''',
      filter.args,
    );

    final yearlyRows = _db.select(
      '''
      SELECT
        SUBSTR(date, 1, 4) || '-01-01' AS bucket_start,
        SUM(ABS(amount_cents)) AS amount_cents
      FROM local_transactions
      WHERE ${filter.whereSql}
        AND LOWER(COALESCE(type, 'expense')) != 'income'
      GROUP BY bucket_start
      ORDER BY bucket_start ASC
      ''',
      filter.args,
    );

    final periodRows = _db.select(
      '''
      SELECT
        ${_periodBucketExpression(query.intervalGranularity)} AS bucket_start,
        SUM(ABS(amount_cents)) AS amount_cents
      FROM local_transactions
      WHERE ${filter.whereSql}
        AND LOWER(COALESCE(type, 'expense')) != 'income'
      GROUP BY bucket_start
      ORDER BY bucket_start ASC
      ''',
      filter.args,
    );

    return LocalTransactionsFeedSummary(
      transactionCount: _rowInt(totals['transaction_count']),
      expenseTotalCents: _rowInt(totals['expense_total_cents']),
      incomeTotalCents: _rowInt(totals['income_total_cents']),
      hasMultipleCurrencies: _rowInt(totals['currency_count']) > 1,
      categorySummaries: categoryRows
          .map((row) => LocalTransactionCategorySummary(
                category: row['category_key']?.toString() ?? 'uncategorized',
                amountCents: _rowInt(row['amount_cents']),
                transactionCount: _rowInt(row['transaction_count']),
              ))
          .toList(growable: false),
      yearlyPeriodTotalsCents: _bucketMapFromRows(yearlyRows),
      periodTotalsCents: _bucketMapFromRows(periodRows),
    );
  }

  Future<int> getTransactionsFeedCount(
    LocalTransactionsFeedQuery query, {
    String? syncStatus,
  }) async {
    final filter = _localFeedFilter(query, includeCursor: false);
    final conditions = <String>[filter.whereSql];
    final args = <Object?>[...filter.args];
    if (syncStatus != null) {
      conditions.add('sync_status = ?');
      args.add(syncStatus);
    }

    final rows = _db.select(
      '''
      SELECT COUNT(*) AS transaction_count
      FROM local_transactions
      WHERE ${conditions.join(' AND ')}
      ''',
      args,
    );

    return rows.isEmpty ? 0 : _rowInt(rows.first['transaction_count']);
  }

  Stream<List<ExpenseEntry>> watchRecentTransactions({
    required String userId,
    required String? householdId,
    int limit = 60,
  }) async* {
    yield await getRecentTransactions(
      userId: userId,
      householdId: householdId,
      limit: limit,
    );

    await for (final _ in _changes.stream) {
      yield await getRecentTransactions(
        userId: userId,
        householdId: householdId,
        limit: limit,
      );
    }
  }

  Future<MonthlySummary?> getMonthlySummary({
    required String scopeKey,
    required DateTime month,
    required String currency,
  }) async {
    final rows = _db.select(
      '''
      SELECT *
      FROM monthly_summaries
      WHERE scope_key = ? AND month = ? AND currency = ?
      LIMIT 1
      ''',
      [
        scopeKey,
        _dateOnly(localMonthBucket(month)),
        currency.toUpperCase(),
      ],
    );
    if (rows.isEmpty) return null;
    return _monthlySummaryFromRow(rows.first);
  }

  Future<DateTime?> getSyncCursor({
    required String entityName,
    required String scopeKey,
  }) async {
    final cursor = await getSyncCursorValue(
      entityName: entityName,
      scopeKey: scopeKey,
    );
    if (cursor == null || cursor.isEmpty) return null;

    final decodedCursor = _tryDecodeJsonObject(cursor);
    final changedAt = decodedCursor?['changedAt']?.toString();
    if (changedAt != null && changedAt.isNotEmpty) {
      return DateTime.tryParse(changedAt);
    }

    return DateTime.tryParse(cursor);
  }

  Future<String?> getSyncCursorValue({
    required String entityName,
    required String scopeKey,
  }) async {
    final rows = _db.select(
      '''
      SELECT cursor
      FROM local_sync_cursors
      WHERE entity_name = ? AND scope_key = ?
      LIMIT 1
      ''',
      [entityName, scopeKey],
    );
    if (rows.isEmpty) return null;
    return rows.first['cursor']?.toString();
  }

  Future<void> setSyncCursor({
    required String entityName,
    required String scopeKey,
    required DateTime? cursor,
  }) async {
    await setSyncCursorValue(
      entityName: entityName,
      scopeKey: scopeKey,
      cursor: cursor == null ? null : _instant(cursor),
    );
  }

  Future<void> setSyncCursorValue({
    required String entityName,
    required String scopeKey,
    required String? cursor,
  }) async {
    final now = DateTime.now().toUtc();
    _db.execute(
      '''
      INSERT INTO local_sync_cursors (
        entity_name, scope_key, cursor, updated_at
      ) VALUES (?, ?, ?, ?)
      ON CONFLICT(entity_name, scope_key) DO UPDATE SET
        cursor = excluded.cursor,
        updated_at = excluded.updated_at
      ''',
      [
        entityName,
        scopeKey,
        cursor,
        _instant(now),
      ],
    );
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueueMutation({
    required String clientMutationId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    DateTime? createdAt,
  }) async {
    _enqueueMutationRow(
      clientMutationId: clientMutationId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: createdAt,
    );
  }

  Future<List<LocalMutationOutboxData>> getOutboxMutations() async {
    final rows = _db.select(
      '''
      SELECT *
      FROM local_mutation_outbox
      ORDER BY created_at ASC
      ''',
    );
    return rows.map(_mutationFromRow).toList(growable: false);
  }

  Future<LocalMutationOutboxData?> nextRetryableMutation(DateTime now) async {
    final rows = _db.select(
      '''
      SELECT *
      FROM local_mutation_outbox
      WHERE status IN (?, ?)
        AND (retry_after IS NULL OR retry_after <= ?)
      ORDER BY created_at ASC
      LIMIT 1
      ''',
      [
        localMutationStatusQueued,
        localMutationStatusFailed,
        _instant(now),
      ],
    );
    if (rows.isEmpty) return null;
    return _mutationFromRow(rows.first);
  }

  Future<void> markMutationSyncing(String clientMutationId) async {
    _markMutationStatus(
      clientMutationId: clientMutationId,
      status: localMutationStatusSyncing,
    );
  }

  Future<void> markMutationSynced(String clientMutationId) async {
    _markMutationStatus(
      clientMutationId: clientMutationId,
      status: localMutationStatusSynced,
    );
  }

  Future<void> markMutationFailed({
    required String clientMutationId,
    required Object error,
    required DateTime retryAfter,
  }) async {
    _markMutationFailedRow(
      clientMutationId: clientMutationId,
      error: error,
      retryAfter: retryAfter,
    );
  }

  void _markMutationStatus({
    required String clientMutationId,
    required String status,
  }) {
    _db.execute(
      '''
      UPDATE local_mutation_outbox
      SET status = ?, updated_at = ?
      WHERE client_mutation_id = ?
      ''',
      [status, _instant(DateTime.now()), clientMutationId],
    );
  }

  void _markMutationFailedRow({
    required String clientMutationId,
    required Object error,
    required DateTime retryAfter,
  }) {
    _db.execute(
      '''
      UPDATE local_mutation_outbox
      SET status = ?,
          attempt_count = attempt_count + 1,
          last_error = ?,
          retry_after = ?,
          updated_at = ?
      WHERE client_mutation_id = ?
      ''',
      [
        localMutationStatusFailed,
        error.toString(),
        _instant(retryAfter),
        _instant(DateTime.now()),
        clientMutationId,
      ],
    );
  }

  void _markMutationCancelledRow({
    required String clientMutationId,
    required Object error,
  }) {
    _db.execute(
      '''
      UPDATE local_mutation_outbox
      SET status = ?,
          last_error = ?,
          retry_after = NULL,
          updated_at = ?
      WHERE client_mutation_id = ?
      ''',
      [
        localMutationStatusCancelled,
        error.toString(),
        _instant(DateTime.now()),
        clientMutationId,
      ],
    );
  }

  void _createSchema() {
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS local_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        contact_id TEXT,
        household_id TEXT,
        scope_key TEXT NOT NULL,
        date TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        currency TEXT NOT NULL,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        raw_text TEXT,
        merchant TEXT,
        breakdown_json TEXT,
        receipt_image_url TEXT,
        shared_member_ids_json TEXT,
        split_group_id TEXT,
        bank_account_id TEXT,
        wallet_id TEXT,
        account_name TEXT,
        account_icon TEXT,
        account_color TEXT,
        type TEXT NOT NULL DEFAULT 'expense',
        is_recurring INTEGER NOT NULL DEFAULT 0,
        client_record_id TEXT,
        client_mutation_id TEXT,
        idempotency_key TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        local_revision INTEGER NOT NULL DEFAULT 0,
        server_revision INTEGER,
        last_error TEXT,
        created_device_id TEXT,
        deleted_at TEXT
      );
    ''');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_transactions_scope_date '
      'ON local_transactions(scope_key, date DESC, created_at DESC);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_transactions_search '
      'ON local_transactions(scope_key, merchant, raw_text, category);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_transactions_filter_currency '
      'ON local_transactions(scope_key, currency, date DESC, created_at DESC);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_transactions_filter_category '
      'ON local_transactions(scope_key, category, date DESC, created_at DESC);',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_transactions_filter_wallet '
      'ON local_transactions(scope_key, wallet_id, date DESC, created_at DESC);',
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS local_mutation_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_mutation_id TEXT NOT NULL UNIQUE,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'queued',
        last_error TEXT,
        retry_after TEXT
      );
    ''');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_outbox_retry '
      'ON local_mutation_outbox(status, retry_after, created_at);',
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS local_sync_cursors (
        entity_name TEXT NOT NULL,
        scope_key TEXT NOT NULL,
        cursor TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (entity_name, scope_key)
      );
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_summaries (
        scope_key TEXT NOT NULL,
        month TEXT NOT NULL,
        currency TEXT NOT NULL,
        income_cents INTEGER NOT NULL DEFAULT 0,
        expense_cents INTEGER NOT NULL DEFAULT 0,
        transaction_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (scope_key, month, currency)
      );
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS category_monthly_summaries (
        scope_key TEXT NOT NULL,
        month TEXT NOT NULL,
        currency TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        amount_cents INTEGER NOT NULL DEFAULT 0,
        transaction_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (scope_key, month, currency, category, type)
      );
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS wallet_balance_snapshots (
        scope_key TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        currency TEXT NOT NULL,
        balance_cents INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (scope_key, wallet_id, currency)
      );
    ''');
  }

  void _runInTransaction(void Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _upsertTransaction(
    ExpenseEntry entry, {
    required String syncStatus,
  }) {
    final userId = entry.userId?.trim();
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('Local transactions require userId');
    }

    final currency = (entry.currency?.trim().isNotEmpty == true
            ? entry.currency!.trim()
            : 'USD')
        .toUpperCase();

    _db.execute(
      '''
      INSERT INTO local_transactions (
        id, user_id, contact_id, household_id, scope_key, date, amount_cents,
        currency, category, created_at, updated_at, raw_text, merchant,
        breakdown_json, receipt_image_url, shared_member_ids_json,
        split_group_id, bank_account_id, wallet_id, account_name, account_icon,
        account_color, type, is_recurring, sync_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        user_id = excluded.user_id,
        contact_id = excluded.contact_id,
        household_id = excluded.household_id,
        scope_key = excluded.scope_key,
        date = excluded.date,
        amount_cents = excluded.amount_cents,
        currency = excluded.currency,
        category = excluded.category,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        raw_text = excluded.raw_text,
        merchant = excluded.merchant,
        breakdown_json = excluded.breakdown_json,
        receipt_image_url = excluded.receipt_image_url,
        shared_member_ids_json = excluded.shared_member_ids_json,
        split_group_id = excluded.split_group_id,
        bank_account_id = excluded.bank_account_id,
        wallet_id = excluded.wallet_id,
        account_name = excluded.account_name,
        account_icon = excluded.account_icon,
        account_color = excluded.account_color,
        type = excluded.type,
        is_recurring = excluded.is_recurring,
        sync_status = excluded.sync_status
      ''',
      [
        entry.id,
        userId,
        entry.contactId,
        entry.householdId,
        localScopeKey(userId: userId, householdId: entry.householdId),
        _dateOnly(entry.date),
        entry.amountCents,
        currency,
        entry.category,
        _instant(entry.createdAt),
        entry.updatedAt == null ? null : _instant(entry.updatedAt!),
        entry.rawText,
        entry.merchant,
        _encodeStringList(entry.breakdown),
        entry.receiptImageUrl,
        _encodeStringList(entry.sharedMemberIds),
        entry.splitGroupId,
        entry.bankAccountId,
        entry.walletId,
        entry.accountName,
        entry.accountIcon,
        entry.accountColor,
        entry.type ?? 'expense',
        entry.isRecurring ? 1 : 0,
        syncStatus,
      ],
    );
  }

  void _enqueueMutationRow({
    required String clientMutationId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    DateTime? createdAt,
  }) {
    final now = DateTime.now().toUtc();
    final created = createdAt ?? now;
    _db.execute(
      '''
      INSERT INTO local_mutation_outbox (
        client_mutation_id, entity_type, entity_id, operation, payload_json,
        created_at, updated_at, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(client_mutation_id) DO UPDATE SET
        entity_type = excluded.entity_type,
        entity_id = excluded.entity_id,
        operation = excluded.operation,
        payload_json = excluded.payload_json,
        updated_at = excluded.updated_at,
        status = excluded.status,
        last_error = NULL,
        retry_after = NULL
      ''',
      [
        clientMutationId,
        entityType,
        entityId,
        operation,
        jsonEncode(payload),
        _instant(created),
        _instant(now),
        localMutationStatusQueued,
      ],
    );
  }

  void _rebuildSummary(_SummaryKey key) {
    final nextMonth = DateTime(key.month.year, key.month.month + 1);
    final rows = _db.select(
      '''
      SELECT amount_cents, type, category, wallet_id
      FROM local_transactions
      WHERE scope_key = ?
        AND currency = ?
        AND date >= ?
        AND date < ?
        AND deleted_at IS NULL
      ''',
      [key.scopeKey, key.currency, _dateOnly(key.month), _dateOnly(nextMonth)],
    );

    var expenseCents = 0;
    var incomeCents = 0;
    final categoryTotals = <_CategorySummaryKey, _CategorySummaryValue>{};
    final walletTotals = <String, int>{};

    for (final row in rows) {
      final amountCents = (row['amount_cents'] as int).abs();
      final type = row['type']?.toString().toLowerCase() == 'income'
          ? 'income'
          : 'expense';
      if (type == 'income') {
        incomeCents += amountCents;
      } else {
        expenseCents += amountCents;
      }

      final category = row['category']?.toString().trim();
      if (category != null && category.isNotEmpty) {
        final categoryKey = _CategorySummaryKey(category, type);
        final current =
            categoryTotals[categoryKey] ?? const _CategorySummaryValue();
        categoryTotals[categoryKey] = current.adding(amountCents);
      }

      final walletId = row['wallet_id']?.toString().trim();
      if (walletId != null && walletId.isNotEmpty) {
        final signedAmount = type == 'income' ? amountCents : -amountCents;
        walletTotals[walletId] = (walletTotals[walletId] ?? 0) + signedAmount;
      }
    }

    final now = _instant(DateTime.now());
    _db.execute(
      '''
      INSERT INTO monthly_summaries (
        scope_key, month, currency, income_cents, expense_cents,
        transaction_count, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(scope_key, month, currency) DO UPDATE SET
        income_cents = excluded.income_cents,
        expense_cents = excluded.expense_cents,
        transaction_count = excluded.transaction_count,
        updated_at = excluded.updated_at
      ''',
      [
        key.scopeKey,
        _dateOnly(key.month),
        key.currency,
        incomeCents,
        expenseCents,
        rows.length,
        now,
      ],
    );

    _db.execute(
      '''
      DELETE FROM category_monthly_summaries
      WHERE scope_key = ? AND month = ? AND currency = ?
      ''',
      [key.scopeKey, _dateOnly(key.month), key.currency],
    );
    for (final entry in categoryTotals.entries) {
      _db.execute(
        '''
        INSERT INTO category_monthly_summaries (
          scope_key, month, currency, category, type, amount_cents,
          transaction_count, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          key.scopeKey,
          _dateOnly(key.month),
          key.currency,
          entry.key.category,
          entry.key.type,
          entry.value.amountCents,
          entry.value.transactionCount,
          now,
        ],
      );
    }

    _db.execute(
      '''
      DELETE FROM wallet_balance_snapshots
      WHERE scope_key = ? AND currency = ?
      ''',
      [key.scopeKey, key.currency],
    );
    for (final entry in walletTotals.entries) {
      _db.execute(
        '''
        INSERT INTO wallet_balance_snapshots (
          scope_key, wallet_id, currency, balance_cents, updated_at
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        [key.scopeKey, entry.key, key.currency, entry.value, now],
      );
    }
  }

  _SummaryKey? _summaryKeyForTransactionId(String id) {
    final rows = _db.select(
      '''
      SELECT user_id, household_id, date, currency
      FROM local_transactions
      WHERE id = ?
      LIMIT 1
      ''',
      [id],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    return _SummaryKey(
      scopeKey: localScopeKey(
        userId: row['user_id'] as String,
        householdId: row['household_id'] as String?,
      ),
      month: localMonthBucket(DateTime.parse(row['date'] as String)),
      currency: (row['currency'] as String).toUpperCase(),
    );
  }

  void _notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }
}

ExpenseEntry _entryFromTransactionRow(Row row) {
  return ExpenseEntry(
    id: row['id'] as String,
    contactId: row['contact_id'] as String?,
    userId: row['user_id'] as String?,
    householdId: row['household_id'] as String?,
    date: DateTime.parse(row['date'] as String),
    amountCents: row['amount_cents'] as int,
    currency: row['currency'] as String?,
    category: row['category'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: _parseNullableDate(row['updated_at'] as String?),
    rawText: row['raw_text'] as String?,
    merchant: row['merchant'] as String?,
    breakdown: _decodeStringList(row['breakdown_json'] as String?),
    receiptImageUrl: row['receipt_image_url'] as String?,
    sharedMemberIds:
        _decodeStringList(row['shared_member_ids_json'] as String?),
    splitGroupId: row['split_group_id'] as String?,
    bankAccountId: row['bank_account_id'] as String?,
    walletId: row['wallet_id'] as String?,
    accountName: row['account_name'] as String?,
    accountIcon: row['account_icon'] as String?,
    accountColor: row['account_color'] as String?,
    type: row['type'] as String?,
    isRecurring: (row['is_recurring'] as int? ?? 0) == 1,
  );
}

MonthlySummary _monthlySummaryFromRow(Row row) {
  return MonthlySummary(
    scopeKey: row['scope_key'] as String,
    month: DateTime.parse(row['month'] as String),
    currency: row['currency'] as String,
    incomeCents: row['income_cents'] as int,
    expenseCents: row['expense_cents'] as int,
    transactionCount: row['transaction_count'] as int,
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

LocalMutationOutboxData _mutationFromRow(Row row) {
  return LocalMutationOutboxData(
    id: row['id'] as int,
    clientMutationId: row['client_mutation_id'] as String,
    entityType: row['entity_type'] as String,
    entityId: row['entity_id'] as String,
    operation: row['operation'] as String,
    payloadJson: row['payload_json'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    attemptCount: row['attempt_count'] as int,
    status: row['status'] as String,
    lastError: row['last_error'] as String?,
    retryAfter: _parseNullableDate(row['retry_after'] as String?),
  );
}

String? _encodeStringList(List<String>? values) {
  if (values == null) return null;
  return jsonEncode(values);
}

List<String>? _decodeStringList(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! List) return null;
  return decoded.map((value) => value.toString()).toList(growable: false);
}

String _dateOnly(DateTime value) => formatDateOnlyYmd(value);

String _instant(DateTime value) => value.toUtc().toIso8601String();

DateTime? _parseNullableDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class _LocalFeedFilter {
  const _LocalFeedFilter({
    required this.whereSql,
    required this.args,
  });

  final String whereSql;
  final List<Object?> args;
}

_LocalFeedFilter _localFeedFilter(
  LocalTransactionsFeedQuery query, {
  required bool includeCursor,
}) {
  final conditions = <String>[
    'scope_key = ?',
    'deleted_at IS NULL',
  ];
  final args = <Object?>[
    localScopeKey(userId: query.userId, householdId: query.householdId),
  ];

  final currency = query.currency?.trim().toUpperCase();
  if (currency != null && currency.isNotEmpty) {
    conditions.add('currency = ?');
    args.add(currency);
  }

  final category = _normalizeTextFilter(query.category);
  if (category != null && category != 'all') {
    conditions.add("LOWER(COALESCE(category, '')) = ?");
    args.add(category);
  }

  final categories = query.categories
      ?.map(_normalizeTextFilter)
      .whereType<String>()
      .where((value) => value != 'all')
      .toSet()
      .toList();
  if (categories != null && categories.isNotEmpty) {
    categories.sort();
    conditions.add(
      "LOWER(COALESCE(category, '')) IN (${List.filled(categories.length, '?').join(', ')})",
    );
    args.addAll(categories);
  }

  final accountId = query.accountId?.trim();
  if (accountId != null && accountId.isNotEmpty) {
    if (query.includeUnassignedAccount) {
      conditions.add('''
        (
          wallet_id = ?
          OR bank_account_id = ?
          OR wallet_id IS NULL
          OR TRIM(wallet_id) = ''
          OR bank_account_id IS NULL
          OR TRIM(bank_account_id) = ''
        )
      ''');
      args.addAll([accountId, accountId]);
    } else {
      conditions.add('(wallet_id = ? OR bank_account_id = ?)');
      args.addAll([accountId, accountId]);
    }
  }

  final type = query.type.trim().toLowerCase();
  if (type == 'expense' || type == 'income') {
    conditions.add("LOWER(COALESCE(type, 'expense')) = ?");
    args.add(type);
  }

  final search = query.searchQuery?.trim().toLowerCase();
  if (search != null && search.isNotEmpty) {
    final like = '%$search%';
    conditions.add('''
      (
        LOWER(COALESCE(merchant, '')) LIKE ?
        OR LOWER(COALESCE(raw_text, '')) LIKE ?
        OR LOWER(COALESCE(category, '')) LIKE ?
        OR LOWER(COALESCE(account_name, '')) LIKE ?
        OR date LIKE ?
        OR CAST(ABS(amount_cents) AS TEXT) LIKE ?
      )
    ''');
    args.addAll([like, like, like, like, like, like]);
  }

  if (query.startDate != null) {
    conditions.add('date >= ?');
    args.add(_dateOnly(query.startDate!));
  }
  if (query.endDate != null) {
    conditions.add('date <= ?');
    args.add(_dateOnly(query.endDate!));
  }

  final cursor = query.cursor;
  if (includeCursor && cursor != null) {
    conditions.add('''
      (
        date < ?
        OR (
          date = ?
          AND (
            created_at < ?
            OR (created_at = ? AND id < ?)
          )
        )
      )
    ''');
    args.addAll([
      _dateOnly(cursor.date),
      _dateOnly(cursor.date),
      _instant(cursor.createdAt),
      _instant(cursor.createdAt),
      cursor.id,
    ]);
  }

  return _LocalFeedFilter(
    whereSql: conditions.join(' AND '),
    args: args,
  );
}

String? _normalizeTextFilter(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

String _periodBucketExpression(String intervalGranularity) {
  switch (intervalGranularity.trim().toLowerCase()) {
    case 'daily':
    case 'hourly':
      return 'date';
    case 'weekly':
      return "DATE(date, '-' || ((CAST(STRFTIME('%w', date) AS INTEGER) + 6) % 7) || ' days')";
    case 'monthly':
      return "SUBSTR(date, 1, 7) || '-01'";
    case 'yearly':
    default:
      return "SUBSTR(date, 1, 4) || '-01-01'";
  }
}

int _rowInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}

Map<DateTime, int> _bucketMapFromRows(ResultSet rows) {
  final buckets = <DateTime, int>{};
  for (final row in rows) {
    final bucket = row['bucket_start']?.toString();
    if (bucket == null || bucket.isEmpty) continue;
    final parsed = DateTime.tryParse(bucket);
    if (parsed == null) continue;
    buckets[DateTime(parsed.year, parsed.month, parsed.day)] =
        _rowInt(row['amount_cents']);
  }
  return buckets;
}

class _SummaryKey {
  const _SummaryKey({
    required this.scopeKey,
    required this.month,
    required this.currency,
  });

  factory _SummaryKey.fromEntry(ExpenseEntry entry) {
    final userId = entry.userId?.trim();
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('Local summary requires userId');
    }
    return _SummaryKey(
      scopeKey: localScopeKey(userId: userId, householdId: entry.householdId),
      month: localMonthBucket(entry.date),
      currency: (entry.currency ?? 'USD').toUpperCase(),
    );
  }

  final String scopeKey;
  final DateTime month;
  final String currency;

  @override
  bool operator ==(Object other) {
    return other is _SummaryKey &&
        other.scopeKey == scopeKey &&
        other.month == month &&
        other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(scopeKey, month, currency);
}

class _CategorySummaryKey {
  const _CategorySummaryKey(this.category, this.type);

  final String category;
  final String type;

  @override
  bool operator ==(Object other) {
    return other is _CategorySummaryKey &&
        other.category == category &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(category, type);
}

class _CategorySummaryValue {
  const _CategorySummaryValue({
    this.amountCents = 0,
    this.transactionCount = 0,
  });

  final int amountCents;
  final int transactionCount;

  _CategorySummaryValue adding(int amountCents) {
    return _CategorySummaryValue(
      amountCents: this.amountCents + amountCents,
      transactionCount: transactionCount + 1,
    );
  }
}
