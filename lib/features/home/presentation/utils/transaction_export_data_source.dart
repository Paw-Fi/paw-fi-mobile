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
      'id,contact_id,user_id,household_id,date,amount_cents,currency,category,raw_text,merchant,breakdown,receipt_image_url,created_at,updated_at,split_group_id,parent_recurring_id,scheduled_occurrence_date,recurring_confirmed_at,recurring_confirmation_source,type,is_recurring,account_id';

  final SupabaseClient _client;

  Future<List<ExpenseEntry>> fetchExportExpenses({
    required String userId,
    required DateTimeRange dateRange,
    required TransactionExportSpaceOption space,
    Set<String> excludedExpenseIds = const <String>{},
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

    return rows
        .where((row) => !excludedExpenseIds.contains(row['id']))
        .map(ExpenseEntry.fromJson)
        .toList(growable: false);
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
        .eq('is_recurring', false)
        .isFilter('deleted_at', null);

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

List<ExpenseEntry> mergeExportExpenses({
  required Iterable<ExpenseEntry> remoteExpenses,
  required Iterable<ExpenseEntry> pendingLocalExpenses,
  required TransactionExportSpaceOption space,
  required DateTimeRange dateRange,
  Set<String> excludedExpenseIds = const <String>{},
}) {
  final expensesById = <String, ExpenseEntry>{
    for (final expense in remoteExpenses)
      if (!excludedExpenseIds.contains(expense.id)) expense.id: expense,
  };

  for (final expense in pendingLocalExpenses) {
    // A pending local update replaces the remote row even when it has moved
    // outside this export's date range or space.
    expensesById.remove(expense.id);
    if (expense.isRecurring ||
        excludedExpenseIds.contains(expense.id) ||
        !_isInExportDateRange(expense, dateRange) ||
        !_belongsToExportSpace(expense, space)) {
      continue;
    }
    expensesById[expense.id] = expense;
  }

  final expenses = expensesById.values.toList(growable: false)
    ..sort((left, right) {
      final dateOrder = right.date.compareTo(left.date);
      if (dateOrder != 0) return dateOrder;
      final createdOrder = right.createdAt.compareTo(left.createdAt);
      if (createdOrder != 0) return createdOrder;
      return right.id.compareTo(left.id);
    });
  return expenses;
}

bool _belongsToExportSpace(
  ExpenseEntry expense,
  TransactionExportSpaceOption space,
) {
  switch (space.type) {
    case TransactionExportSpaceType.all:
      return true;
    case TransactionExportSpaceType.personal:
      return expense.householdId?.trim().isEmpty ?? true;
    case TransactionExportSpaceType.household:
      return expense.householdId?.trim() == space.householdId?.trim();
  }
}

bool _isInExportDateRange(ExpenseEntry expense, DateTimeRange dateRange) {
  final date =
      DateTime(expense.date.year, expense.date.month, expense.date.day);
  final start = DateTime(
    dateRange.start.year,
    dateRange.start.month,
    dateRange.start.day,
  );
  final end =
      DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
  return !date.isBefore(start) && !date.isAfter(end);
}
