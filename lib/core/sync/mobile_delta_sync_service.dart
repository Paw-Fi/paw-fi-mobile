import 'dart:convert';

import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

const String mobileDeltaEntityName = 'mobile_delta_v1';
const int _maxDeltaPagesPerPull = 20;

typedef MobileDeltaFetcher = Future<MobileDelta> Function({
  required String userId,
  required DateTime? since,
  required String? sinceId,
  required int limit,
});

class MobileDelta {
  const MobileDelta({
    this.transactions = const <ExpenseEntry>[],
    this.deletedTransactionIds = const <String>[],
    this.nextCursor,
    this.nextCursorId,
    this.hasMore = false,
  });

  factory MobileDelta.fromJson(Map<String, dynamic> json) {
    final transactionRows = json['transactions'];
    final deletedRows = json['deletedTransactionIds'];
    final cursor = json['nextCursor']?.toString();

    return MobileDelta(
      transactions: transactionRows is List
          ? transactionRows
              .whereType<Map>()
              .map((row) => ExpenseEntry.fromJson(
                    Map<String, dynamic>.from(row),
                  ))
              .toList(growable: false)
          : const <ExpenseEntry>[],
      deletedTransactionIds: deletedRows is List
          ? deletedRows.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      nextCursor:
          cursor == null || cursor.isEmpty ? null : DateTime.tryParse(cursor),
      nextCursorId: json['nextCursorId']?.toString(),
      hasMore: json['hasMore'] == true,
    );
  }

  final List<ExpenseEntry> transactions;
  final List<String> deletedTransactionIds;
  final DateTime? nextCursor;
  final String? nextCursorId;
  final bool hasMore;
}

class MobileDeltaSyncService {
  const MobileDeltaSyncService({
    required this.database,
    required this.fetchDelta,
  });

  final MonekoDatabase database;
  final MobileDeltaFetcher fetchDelta;

  Future<MobileDelta> pullAndApply({
    required String userId,
    DateTime? since,
    int limit = 500,
  }) async {
    final scopeKey = _cursorScopeKey(userId);
    final storedCursor = since == null
        ? _MobileDeltaStoredCursor.fromValue(
            await database.getSyncCursorValue(
              entityName: mobileDeltaEntityName,
              scopeKey: scopeKey,
            ),
          )
        : _MobileDeltaStoredCursor(changedAt: since);

    var pageCursor = storedCursor;
    var lastDelta = const MobileDelta();
    final transactions = <ExpenseEntry>[];
    final deletedTransactionIds = <String>[];

    for (var page = 0; page < _maxDeltaPagesPerPull; page++) {
      final delta = await fetchDelta(
        userId: userId,
        since: pageCursor.changedAt,
        sinceId: pageCursor.id,
        limit: limit,
      );
      await database.upsertTransactions(delta.transactions);
      await database.deleteTransactionsByIds(delta.deletedTransactionIds);

      transactions.addAll(delta.transactions);
      deletedTransactionIds.addAll(delta.deletedTransactionIds);
      lastDelta = delta;

      if (delta.nextCursor == null) break;

      pageCursor = _MobileDeltaStoredCursor(
        changedAt: delta.nextCursor,
        id: delta.nextCursorId,
      );
      await database.setSyncCursorValue(
        entityName: mobileDeltaEntityName,
        scopeKey: scopeKey,
        cursor: pageCursor.toValue(),
      );

      if (!delta.hasMore) break;
    }

    return MobileDelta(
      transactions: transactions,
      deletedTransactionIds: deletedTransactionIds,
      nextCursor: lastDelta.nextCursor,
      nextCursorId: lastDelta.nextCursorId,
      hasMore: lastDelta.hasMore,
    );
  }

  String _cursorScopeKey(String userId) => '$userId:all';
}

MobileDeltaFetcher supabaseMobileDeltaFetcher() {
  return ({
    required String userId,
    required DateTime? since,
    required String? sinceId,
    required int limit,
  }) async {
    final response = await supabase.rpc(
      'get_mobile_delta_v1',
      params: {
        'p_user_id': userId,
        'p_since': since?.toUtc().toIso8601String(),
        'p_since_id': sinceId,
        'p_limit': limit,
      },
    );
    final data = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
    return MobileDelta.fromJson(data);
  };
}

class _MobileDeltaStoredCursor {
  const _MobileDeltaStoredCursor({
    required this.changedAt,
    this.id,
  });

  factory _MobileDeltaStoredCursor.fromValue(String? value) {
    if (value == null || value.isEmpty) {
      return const _MobileDeltaStoredCursor(changedAt: null);
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final json = Map<String, dynamic>.from(decoded);
        final changedAt = json['changedAt']?.toString();
        return _MobileDeltaStoredCursor(
          changedAt: changedAt == null ? null : DateTime.tryParse(changedAt),
          id: json['id']?.toString(),
        );
      }
    } catch (_) {}

    return _MobileDeltaStoredCursor(changedAt: DateTime.tryParse(value));
  }

  final DateTime? changedAt;
  final String? id;

  String toValue() {
    return jsonEncode({
      'changedAt': changedAt?.toUtc().toIso8601String(),
      if (id != null && id!.isNotEmpty) 'id': id,
    });
  }
}
