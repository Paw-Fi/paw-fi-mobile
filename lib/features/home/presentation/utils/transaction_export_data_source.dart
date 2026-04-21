import 'package:flutter/material.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_export_options_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionExportDataSource {
  const TransactionExportDataSource(this._client);

  static const _pageSize = 1000;
  static const _maxPages = 200;
  static const _queryTimeout = Duration(seconds: 20);
  static const _selectFields =
      'id,contact_id,user_id,household_id,date,amount_cents,currency,category,raw_text,merchant,breakdown,receipt_image_url,created_at,updated_at,split_group_id,type,is_recurring,account_id';

  final SupabaseClient _client;

  Future<List<ExpenseEntry>> fetchExportExpenses({
    required String userId,
    required DateTimeRange dateRange,
    required TransactionExportSpaceOption space,
  }) async {
    final contactIds = space.type == TransactionExportSpaceType.personal
        ? await _fetchContactIds(userId)
        : const <String>[];
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    debugPrint(
      '[TransactionExportDataSource] fetching expenses '
      'user=$userId personalContacts=${contactIds.length} '
      'space=${space.type.name}:${space.householdId ?? "<all>"} '
      'range=${formatDateOnlyYmd(dateRange.start)}..${formatDateOnlyYmd(dateRange.end)}',
    );

    for (var page = 0; page < _maxPages; page++) {
      final batch = await _fetchExpensePage(
        userId: userId,
        contactIds: contactIds,
        dateRange: dateRange,
        space: space,
        from: offset,
        to: offset + _pageSize - 1,
      );
      rows.addAll(batch);

      debugPrint(
        '[TransactionExportDataSource] page=${page + 1} '
        'offset=$offset count=${batch.length} total=${rows.length}',
      );

      if (batch.length < _pageSize) {
        break;
      }
      offset += _pageSize;
    }

    if (rows.length >= _pageSize * _maxPages) {
      debugPrint(
        '[TransactionExportDataSource] max pages reached; export may be truncated at ${rows.length} rows',
      );
    }

    return rows.map(ExpenseEntry.fromJson).toList(growable: false);
  }

  Future<List<String>> _fetchContactIds(String userId) async {
    final response = await _client
        .from('user_contacts')
        .select('id')
        .eq('user_id', userId)
        .timeout(_queryTimeout);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['id'] as String?)
        .where((id) => id != null && id.trim().isNotEmpty)
        .cast<String>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchExpensePage({
    required String userId,
    required List<String> contactIds,
    required DateTimeRange dateRange,
    required TransactionExportSpaceOption space,
    required int from,
    required int to,
  }) async {
    var query = _client
        .from('expenses')
        .select(_selectFields)
        .gte('date', formatDateOnlyYmd(dateRange.start))
        .lte('date', formatDateOnlyYmd(dateRange.end))
        .eq('is_recurring', false);

    switch (space.type) {
      case TransactionExportSpaceType.all:
        break;
      case TransactionExportSpaceType.personal:
        if (contactIds.isNotEmpty) {
          query = query
              .or('user_id.eq.$userId,contact_id.in.(${contactIds.join(',')})');
        } else {
          query = query.eq('user_id', userId);
        }
        query = query.isFilter('household_id', null);
      case TransactionExportSpaceType.household:
        final householdId = space.householdId;
        if (householdId == null || householdId.trim().isEmpty) {
          throw StateError('Household export selected without a household id');
        }
        query = query.eq('household_id', householdId);
    }

    final response = await query
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(from, to)
        .timeout(_queryTimeout);

    return (response as List).cast<Map<String, dynamic>>();
  }
}
