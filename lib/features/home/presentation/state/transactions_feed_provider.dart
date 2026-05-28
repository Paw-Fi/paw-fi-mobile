import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _homeSpendTrace(String message) {
  assert(() {
    foundation.debugPrint('🧾 [HomeSpendTrace] $message');
    return true;
  }());
}

int _traceExpenseCents(Iterable<ExpenseEntry> entries) {
  return entries.fold<int>(0, (sum, entry) {
    final type = (entry.type ?? 'expense').toLowerCase();
    if (type == 'income') return sum;
    return sum + entry.amountCents.abs();
  });
}

String _traceAmountFromCents(int cents) => (cents / 100.0).toStringAsFixed(2);

String _traceFeedQuery(TransactionsFeedQuery query) {
  final user = query.userId.isEmpty ? '<empty>' : query.userId;
  final household = query.householdId ?? '<personal>';
  final currency = query.normalizedCurrency ?? '<none>';
  final start = query.formattedStartDate ?? '<none>';
  final end = query.formattedEndDate ?? '<none>';
  return 'user=$user '
      'household=$household '
      'currency=$currency '
      'currencies=${query.normalizedCurrencies ?? const <String>[]} '
      'type=${query.normalizedType} '
      'start=$start '
      'end=$end '
      'pageSize=${query.pageSize}';
}

class TransactionsFeedQuery {
  final String userId;
  final String? householdId;
  final String? selectedCurrency;
  final List<String>? selectedCurrencies;
  final String? selectedCategory;
  final String? selectedAccountId;
  final List<String>? selectedCategories;
  final bool includeUnassignedAccount;
  final String selectedType;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final int pageSize;
  final String? summaryIntervalGranularity;

  const TransactionsFeedQuery({
    required this.userId,
    required this.householdId,
    required this.selectedCurrency,
    this.selectedCurrencies,
    required this.selectedCategory,
    this.selectedAccountId,
    this.selectedCategories,
    this.includeUnassignedAccount = false,
    required this.selectedType,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    this.pageSize = 60,
    this.summaryIntervalGranularity,
  });

  String? get normalizedCurrency => _normalizeNullable(selectedCurrency);

  String? get _identityCurrency {
    return normalizedCurrencies == null ? normalizedCurrency : null;
  }

  List<String>? get normalizedCurrencies {
    final source = selectedCurrencies ??
        (selectedCurrency == null ? null : <String>[selectedCurrency!]);
    final normalized = source
        ?.map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (normalized == null || normalized.isEmpty) return null;
    normalized.sort();
    return normalized;
  }

  List<String>? get normalizedSelectedCurrencies {
    final normalized = selectedCurrencies
        ?.map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (normalized == null || normalized.length < 2) return null;
    normalized.sort();
    return normalized;
  }

  String? get normalizedCategory {
    final category = _normalizeNullable(selectedCategory);
    if (category == null || category == 'all') {
      return null;
    }
    return category;
  }

  String? get normalizedAccountId {
    final accountId = selectedAccountId?.trim();
    if (accountId == null || accountId.isEmpty) {
      return null;
    }
    return accountId;
  }

  List<String>? get normalizedCategories {
    final normalized = selectedCategories
        ?.map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    normalized.sort();
    return normalized;
  }

  String get normalizedType {
    final type = selectedType.trim().toLowerCase();
    if (type == 'expense' || type == 'income') {
      return type;
    }
    return 'all';
  }

  String? get normalizedSearchQuery {
    final query = searchQuery.trim();
    return query.isEmpty ? null : query;
  }

  String? get formattedStartDate =>
      startDate == null ? null : formatDateOnlyYmd(startDate!);

  String? get formattedEndDate =>
      endDate == null ? null : formatDateOnlyYmd(endDate!);

  String? get normalizedSummaryIntervalGranularity {
    final value = summaryIntervalGranularity?.trim().toLowerCase();
    switch (value) {
      case 'daily':
      case 'weekly':
      case 'monthly':
      case 'yearly':
        return value;
      default:
        return null;
    }
  }

  TransactionsFeedQuery copyWith({
    String? userId,
    String? householdId,
    String? selectedCurrency,
    List<String>? selectedCurrencies,
    String? selectedCategory,
    String? selectedAccountId,
    List<String>? selectedCategories,
    bool? includeUnassignedAccount,
    String? selectedType,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    int? pageSize,
    String? summaryIntervalGranularity,
  }) {
    return TransactionsFeedQuery(
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      selectedCurrencies: selectedCurrencies ?? this.selectedCurrencies,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      includeUnassignedAccount:
          includeUnassignedAccount ?? this.includeUnassignedAccount,
      selectedType: selectedType ?? this.selectedType,
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pageSize: pageSize ?? this.pageSize,
      summaryIntervalGranularity:
          summaryIntervalGranularity ?? this.summaryIntervalGranularity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is TransactionsFeedQuery &&
        userId == other.userId &&
        householdId == other.householdId &&
        _identityCurrency == other._identityCurrency &&
        _listEquals(normalizedCurrencies, other.normalizedCurrencies) &&
        normalizedCategory == other.normalizedCategory &&
        normalizedAccountId == other.normalizedAccountId &&
        _listEquals(normalizedCategories, other.normalizedCategories) &&
        includeUnassignedAccount == other.includeUnassignedAccount &&
        normalizedType == other.normalizedType &&
        normalizedSearchQuery == other.normalizedSearchQuery &&
        formattedStartDate == other.formattedStartDate &&
        formattedEndDate == other.formattedEndDate &&
        pageSize == other.pageSize &&
        normalizedSummaryIntervalGranularity ==
            other.normalizedSummaryIntervalGranularity;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        _identityCurrency,
        Object.hashAll(normalizedCurrencies ?? const <String>[]),
        normalizedCategory,
        normalizedAccountId,
        Object.hashAll(normalizedCategories ?? const <String>[]),
        includeUnassignedAccount,
        normalizedType,
        normalizedSearchQuery,
        formattedStartDate,
        formattedEndDate,
        pageSize,
        normalizedSummaryIntervalGranularity,
      );
}

class TransactionsFeedCursor {
  final DateTime date;
  final DateTime createdAt;
  final String id;

  const TransactionsFeedCursor({
    required this.date,
    required this.createdAt,
    required this.id,
  });

  factory TransactionsFeedCursor.fromJson(Map<String, dynamic> json) {
    return TransactionsFeedCursor(
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      id: json['id'] as String,
    );
  }
}

class TransactionsFeedCategorySummary {
  final String category;
  final double amount;
  final int transactionCount;

  const TransactionsFeedCategorySummary({
    required this.category,
    required this.amount,
    required this.transactionCount,
  });

  TransactionsFeedCategorySummary copyWith({
    String? category,
    double? amount,
    int? transactionCount,
  }) {
    return TransactionsFeedCategorySummary(
      category: category ?? this.category,
      amount: amount ?? this.amount,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}

class TransactionsFeedCurrencyCategorySummary {
  final String category;
  final String currency;
  final double amount;
  final int transactionCount;

  const TransactionsFeedCurrencyCategorySummary({
    required this.category,
    required this.currency,
    required this.amount,
    required this.transactionCount,
  });
}

class TransactionsFeedCurrencyPeriodTotal {
  final DateTime bucketStart;
  final String currency;
  final double amount;

  const TransactionsFeedCurrencyPeriodTotal({
    required this.bucketStart,
    required this.currency,
    required this.amount,
  });
}

class TransactionsFeedCurrencyTypeTotal {
  final String currency;
  final double expenseTotal;
  final double incomeTotal;
  final int transactionCount;

  const TransactionsFeedCurrencyTypeTotal({
    required this.currency,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.transactionCount,
  });
}

class TransactionsFeedSummary {
  final int transactionCount;
  final double expenseTotal;
  final double incomeTotal;
  final bool hasMultipleCurrencies;
  final List<TransactionsFeedCategorySummary> categorySummaries;
  final Map<DateTime, double> yearlyPeriodTotals;
  final Map<DateTime, double> periodTotals;
  final List<TransactionsFeedCurrencyCategorySummary>
      currencyCategorySummaries;
  final List<TransactionsFeedCurrencyPeriodTotal> currencyYearlyPeriodTotals;
  final List<TransactionsFeedCurrencyPeriodTotal> currencyPeriodTotals;
  final List<TransactionsFeedCurrencyTypeTotal> currencyTypeTotals;

  const TransactionsFeedSummary({
    required this.transactionCount,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.hasMultipleCurrencies,
    required this.categorySummaries,
    required this.yearlyPeriodTotals,
    this.periodTotals = const <DateTime, double>{},
    this.currencyCategorySummaries =
        const <TransactionsFeedCurrencyCategorySummary>[],
    this.currencyYearlyPeriodTotals =
        const <TransactionsFeedCurrencyPeriodTotal>[],
    this.currencyPeriodTotals = const <TransactionsFeedCurrencyPeriodTotal>[],
    this.currencyTypeTotals = const <TransactionsFeedCurrencyTypeTotal>[],
  });

  const TransactionsFeedSummary.empty()
      : transactionCount = 0,
        expenseTotal = 0,
        incomeTotal = 0,
        hasMultipleCurrencies = false,
        categorySummaries = const <TransactionsFeedCategorySummary>[],
        yearlyPeriodTotals = const <DateTime, double>{},
        periodTotals = const <DateTime, double>{},
        currencyCategorySummaries =
            const <TransactionsFeedCurrencyCategorySummary>[],
        currencyYearlyPeriodTotals =
            const <TransactionsFeedCurrencyPeriodTotal>[],
        currencyPeriodTotals = const <TransactionsFeedCurrencyPeriodTotal>[],
        currencyTypeTotals = const <TransactionsFeedCurrencyTypeTotal>[];

  TransactionsFeedSummary addingExpenses(List<ExpenseEntry> expenses) {
    if (expenses.isEmpty) {
      return this;
    }

    final expenseRows = expenses
        .where(
            (expense) => (expense.type ?? 'expense').toLowerCase() != 'income')
        .toList();
    final incomeRows = expenses
        .where(
            (expense) => (expense.type ?? 'expense').toLowerCase() == 'income')
        .toList();

    final categoryMap = <String, TransactionsFeedCategorySummary>{};
    for (final summary in categorySummaries) {
      final category = canonicalizeCategoryKey(summary.category);
      final current = categoryMap[category] ??
          TransactionsFeedCategorySummary(
            category: category,
            amount: 0,
            transactionCount: 0,
          );
      categoryMap[category] = current.copyWith(
        amount: current.amount + summary.amount,
        transactionCount: current.transactionCount + summary.transactionCount,
      );
    }

    for (final expense in expenseRows) {
      final category = canonicalizeCategoryKey(expense.category);
      final current = categoryMap[category] ??
          TransactionsFeedCategorySummary(
            category: category,
            amount: 0,
            transactionCount: 0,
          );
      categoryMap[category] = current.copyWith(
        amount: current.amount + expense.amount.abs(),
        transactionCount: current.transactionCount + 1,
      );
    }

    final yearlyTotals = Map<DateTime, double>.from(yearlyPeriodTotals);
    final addedYearly = groupExpensesByInterval(expenses, 'yearly');
    for (final entry in addedYearly.entries) {
      yearlyTotals[entry.key] = (yearlyTotals[entry.key] ?? 0) + entry.value;
    }

    final periodTotals = Map<DateTime, double>.from(this.periodTotals);

    final extraCurrencies = expenses
        .map((expense) => expense.currency?.trim().toUpperCase())
        .where((currency) => currency != null && currency.isNotEmpty)
        .cast<String>()
        .toSet();

    return TransactionsFeedSummary(
      transactionCount: transactionCount + expenses.length,
      expenseTotal: expenseTotal +
          expenseRows.fold<double>(
              0, (sum, expense) => sum + expense.amount.abs()),
      incomeTotal: incomeTotal +
          incomeRows.fold<double>(
              0, (sum, expense) => sum + expense.amount.abs()),
      hasMultipleCurrencies:
          hasMultipleCurrencies || extraCurrencies.length > 1,
      categorySummaries: categoryMap.values.toList()
        ..sort((left, right) => right.amount.compareTo(left.amount)),
      yearlyPeriodTotals: yearlyTotals,
      periodTotals: periodTotals,
      currencyCategorySummaries: currencyCategorySummaries,
      currencyYearlyPeriodTotals: currencyYearlyPeriodTotals,
      currencyPeriodTotals: currencyPeriodTotals,
      currencyTypeTotals: currencyTypeTotals,
    );
  }
}

class TransactionsFeedPageResult {
  final List<ExpenseEntry> items;
  final bool hasMore;
  final TransactionsFeedCursor? nextCursor;

  const TransactionsFeedPageResult({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });
}

abstract class TransactionsFeedService {
  const TransactionsFeedService();

  bool get supportsBackgroundRefresh => false;

  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  });

  Future<TransactionsFeedSummary> fetchSummary(TransactionsFeedQuery query);

  Future<void> refreshFromRemote(TransactionsFeedQuery query) async {}

  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    final items = <ExpenseEntry>[];
    TransactionsFeedCursor? cursor;
    var hasMore = true;

    while (hasMore) {
      final page = await fetchPage(query, cursor: cursor);
      items.addAll(page.items);
      hasMore = page.hasMore;
      cursor = page.nextCursor;
      if (page.items.isEmpty) {
        break;
      }
    }

    return items;
  }
}

class EmptyTransactionsFeedService extends TransactionsFeedService {
  const EmptyTransactionsFeedService();

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    return const TransactionsFeedPageResult(
      items: <ExpenseEntry>[],
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
    TransactionsFeedQuery query,
  ) async {
    return const TransactionsFeedSummary.empty();
  }
}

class SupabaseTransactionsFeedService extends TransactionsFeedService {
  final SupabaseClient _client;

  const SupabaseTransactionsFeedService(this._client);

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    final items = <ExpenseEntry>[];
    TransactionsFeedCursor? cursor;
    var hasMore = true;

    while (hasMore) {
      final page = await fetchPage(query, cursor: cursor);
      items.addAll(page.items);
      hasMore = page.hasMore;
      cursor = page.nextCursor;
      if (page.items.isEmpty) {
        break;
      }
    }

    return items;
  }

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    final params = <String, dynamic>{
      'p_user_id': query.userId,
      'p_household_id': query.householdId,
      'p_currency': query.normalizedCurrency,
      if (query.normalizedSelectedCurrencies != null)
        'p_currencies': query.normalizedSelectedCurrencies,
      'p_category': query.normalizedCategory,
      'p_account_id': query.normalizedAccountId,
      'p_include_unassigned_account': query.includeUnassignedAccount,
      'p_categories': query.normalizedCategories,
      'p_type': query.normalizedType,
      'p_search_query': query.normalizedSearchQuery,
      'p_start_date': query.formattedStartDate,
      'p_end_date': query.formattedEndDate,
      'p_page_size': query.pageSize,
      'p_cursor_date': cursor == null ? null : formatDateOnlyYmd(cursor.date),
      'p_cursor_created_at': cursor?.createdAt.toUtc().toIso8601String(),
      'p_cursor_id': cursor?.id,
    };

    final response = await _runRpc(
      rpcName: 'get_user_transactions_page_v1',
      params: params,
    );

    final payload = Map<String, dynamic>.from(response as Map);
    final items = ((payload['items'] as List?) ?? const [])
        .cast<Map>()
        .map((row) => ExpenseEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    final nextCursorJson = payload['next_cursor'];

    return TransactionsFeedPageResult(
      items: items,
      hasMore: payload['has_more'] == true,
      nextCursor: nextCursorJson is Map<String, dynamic>
          ? TransactionsFeedCursor.fromJson(nextCursorJson)
          : nextCursorJson is Map
              ? TransactionsFeedCursor.fromJson(
                  Map<String, dynamic>.from(nextCursorJson),
                )
              : null,
    );
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
      TransactionsFeedQuery query) async {
    final params = <String, dynamic>{
      'p_user_id': query.userId,
      'p_household_id': query.householdId,
      'p_currency': query.normalizedCurrency,
      if (query.normalizedSelectedCurrencies != null)
        'p_currencies': query.normalizedSelectedCurrencies,
      'p_category': query.normalizedCategory,
      'p_account_id': query.normalizedAccountId,
      'p_include_unassigned_account': query.includeUnassignedAccount,
      'p_categories': query.normalizedCategories,
      'p_type': query.normalizedType,
      'p_search_query': query.normalizedSearchQuery,
      'p_start_date': query.formattedStartDate,
      'p_end_date': query.formattedEndDate,
      'p_interval_granularity':
          query.normalizedSummaryIntervalGranularity ?? 'yearly',
    };
    final response = await _runRpc(
      rpcName: 'get_user_transactions_summary_v1',
      params: params,
    );

    final payload = Map<String, dynamic>.from(response as Map);
    final categoryMap = <String, TransactionsFeedCategorySummary>{};
    for (final row
        in ((payload['category_summaries'] as List?) ?? const []).cast<Map>()) {
      final category = canonicalizeCategoryKey(
        row['category'] as String? ?? 'uncategorized',
      );
      final current = categoryMap[category] ??
          TransactionsFeedCategorySummary(
            category: category,
            amount: 0,
            transactionCount: 0,
          );
      categoryMap[category] = current.copyWith(
        amount: current.amount + _centsToDouble(row['amount_cents']),
        transactionCount: current.transactionCount +
            ((row['transaction_count'] as num?)?.toInt() ?? 0),
      );
    }
    final categoryRows = categoryMap.values.toList()
      ..sort((left, right) => right.amount.compareTo(left.amount));

    final yearlyPeriodTotals = <DateTime, double>{};
    final periodTotals = <DateTime, double>{};
    for (final row in ((payload['yearly_period_totals'] as List?) ?? const [])
        .cast<Map>()) {
      final bucketRaw = row['bucket_start'];
      if (bucketRaw == null) {
        continue;
      }
      yearlyPeriodTotals[DateTime.parse(bucketRaw.toString())] =
          _centsToDouble(row['amount_cents']);
    }

    for (final row
        in ((payload['period_totals'] as List?) ?? const []).cast<Map>()) {
      final bucketRaw = row['bucket_start'];
      if (bucketRaw == null) {
        continue;
      }
      periodTotals[DateTime.parse(bucketRaw.toString())] =
          _centsToDouble(row['amount_cents']);
    }

    return TransactionsFeedSummary(
      transactionCount: (payload['transaction_count'] as num?)?.toInt() ?? 0,
      expenseTotal: _centsToDouble(payload['expense_total_cents']),
      incomeTotal: _centsToDouble(payload['income_total_cents']),
      hasMultipleCurrencies: payload['has_multiple_currencies'] == true,
      categorySummaries: categoryRows,
      yearlyPeriodTotals: yearlyPeriodTotals,
      periodTotals: periodTotals,
      currencyCategorySummaries:
          _parseCurrencyCategorySummaries(payload['currency_category_summaries']),
      currencyYearlyPeriodTotals:
          _parseCurrencyPeriodTotals(payload['currency_yearly_period_totals']),
      currencyPeriodTotals:
          _parseCurrencyPeriodTotals(payload['currency_period_totals']),
      currencyTypeTotals: _parseCurrencyTypeTotals(
        payload['currency_type_totals'],
      ),
    );
  }

  List<TransactionsFeedCurrencyCategorySummary>
      _parseCurrencyCategorySummaries(dynamic source) {
    return ((source as List?) ?? const [])
        .cast<Map>()
        .map((row) {
          final currency = row['currency']?.toString().trim().toUpperCase();
          if (currency == null || currency.isEmpty) {
            return null;
          }
          return TransactionsFeedCurrencyCategorySummary(
            category: canonicalizeCategoryKey(
              row['category'] as String? ?? 'uncategorized',
            ),
            currency: currency,
            amount: _centsToDouble(row['amount_cents']),
            transactionCount:
                ((row['transaction_count'] as num?)?.toInt() ?? 0),
          );
        })
        .whereType<TransactionsFeedCurrencyCategorySummary>()
        .toList(growable: false);
  }

  List<TransactionsFeedCurrencyPeriodTotal> _parseCurrencyPeriodTotals(
    dynamic source,
  ) {
    return ((source as List?) ?? const [])
        .cast<Map>()
        .map((row) {
          final bucketRaw = row['bucket_start'];
          final currency = row['currency']?.toString().trim().toUpperCase();
          if (bucketRaw == null || currency == null || currency.isEmpty) {
            return null;
          }
          return TransactionsFeedCurrencyPeriodTotal(
            bucketStart: DateTime.parse(bucketRaw.toString()),
            currency: currency,
            amount: _centsToDouble(row['amount_cents']),
          );
        })
        .whereType<TransactionsFeedCurrencyPeriodTotal>()
        .toList(growable: false);
  }

  List<TransactionsFeedCurrencyTypeTotal> _parseCurrencyTypeTotals(
    dynamic source,
  ) {
    return ((source as List?) ?? const [])
        .cast<Map>()
        .map((row) {
          final currency = row['currency']?.toString().trim().toUpperCase();
          if (currency == null || currency.isEmpty) {
            return null;
          }
          return TransactionsFeedCurrencyTypeTotal(
            currency: currency,
            expenseTotal: _centsToDouble(row['expense_total_cents']),
            incomeTotal: _centsToDouble(row['income_total_cents']),
            transactionCount:
                ((row['transaction_count'] as num?)?.toInt() ?? 0),
          );
        })
        .whereType<TransactionsFeedCurrencyTypeTotal>()
        .toList(growable: false);
  }

  double _centsToDouble(dynamic value) {
    if (value is int) return value / 100.0;
    if (value is num) return value.toDouble() / 100.0;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed.toDouble() / 100.0;
      }
    }
    return 0;
  }

  Future<dynamic> _runRpc({
    required String rpcName,
    required Map<String, dynamic> params,
  }) async {
    return _client.rpc(rpcName, params: params);
  }
}

class LocalFirstTransactionsFeedService extends TransactionsFeedService {
  const LocalFirstTransactionsFeedService({
    required MonekoDatabase database,
    required TransactionsFeedService remote,
    bool remoteEnabled = true,
  })  : _database = database,
        _remote = remote,
        _remoteEnabled = remoteEnabled;

  final MonekoDatabase _database;
  final TransactionsFeedService _remote;
  final bool _remoteEnabled;

  @override
  bool get supportsBackgroundRefresh => _remoteEnabled;

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    final localQuery = _localQuery(query, cursor: cursor);
    final localPage = await _database.getTransactionsFeedPage(
      localQuery,
    );
    final isComplete = await _database.isTransactionsFeedCacheComplete(
      _localQuery(query),
    );
    final hasPendingLocalRows = await _hasPendingLocalRows(localQuery);
    _homeSpendTrace(
      'feed-fetchPage start ${_traceFeedQuery(query)} cursor=${cursor != null} '
      'remote=$_remoteEnabled complete=$isComplete pending=$hasPendingLocalRows '
      'localCount=${localPage.items.length} localTotal=${_traceAmountFromCents(_traceExpenseCents(localPage.items))}',
    );
    if (!_remoteEnabled) {
      _homeSpendTrace('feed-fetchPage return=local-offline count=${localPage.items.length}');
      return _pageFromLocal(localPage, query);
    }
    if (isComplete || cursor != null || hasPendingLocalRows) {
      final reason = isComplete ? 'complete' : cursor != null ? 'cursor' : 'pending';
      _homeSpendTrace(
        'feed-fetchPage return=local-authoritative reason=$reason count=${localPage.items.length}',
      );
      return _pageFromLocal(localPage, query);
    }

    try {
      final remotePage = await _remote.fetchPage(query, cursor: cursor);
      _homeSpendTrace(
        'feed-fetchPage remote count=${remotePage.items.length} '
        'total=${_traceAmountFromCents(_traceExpenseCents(remotePage.items))} hasMore=${remotePage.hasMore}',
      );
      await _cacheRemoteItems(remotePage.items);
      if (cursor == null) {
        await _database.markTransactionsFeedCacheComplete(
          _localQuery(query),
          isComplete: !remotePage.hasMore,
        );
      }
      final updatedLocalPage = await _database.getTransactionsFeedPage(
        localQuery,
      );
      _homeSpendTrace(
        'feed-fetchPage return=remote-cached updatedLocalCount=${updatedLocalPage.items.length} '
        'updatedLocalTotal=${_traceAmountFromCents(_traceExpenseCents(updatedLocalPage.items))}',
      );
      if (updatedLocalPage.items.isEmpty) return remotePage;
      return _pageFromLocal(updatedLocalPage, query);
    } catch (error) {
      _homeSpendTrace('feed-fetchPage remote-error return=local error=$error count=${localPage.items.length}');
      return _pageFromLocal(localPage, query);
    }
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
    TransactionsFeedQuery query,
  ) async {
    final localQuery = _localQuery(query);
    final localSummary = await _database.getTransactionsFeedSummary(localQuery);
    final isComplete = await _database.isTransactionsFeedCacheComplete(
      localQuery,
    );
    final hasPendingLocalRows = await _hasPendingLocalRows(localQuery);
    _homeSpendTrace(
      'feed-fetchSummary start ${_traceFeedQuery(query)} '
      'remote=$_remoteEnabled complete=$isComplete pending=$hasPendingLocalRows '
      'localCount=${localSummary.transactionCount} '
      'localExpense=${_traceAmountFromCents(localSummary.expenseTotalCents)} '
      'localIncome=${_traceAmountFromCents(localSummary.incomeTotalCents)}',
    );
    if (!_remoteEnabled) {
      _homeSpendTrace('feed-fetchSummary return=local-offline');
      return _summaryFromLocal(localSummary);
    }
    if (isComplete) {
      _homeSpendTrace('feed-fetchSummary return=local-authoritative reason=complete');
      return _summaryFromLocal(localSummary);
    }
    if (hasPendingLocalRows) {
      _homeSpendTrace('feed-fetchSummary return=local-authoritative reason=pending');
      return _summaryFromLocal(localSummary);
    }
    try {
      final remoteSummary = await _remote.fetchSummary(query);
      _homeSpendTrace(
        'feed-fetchSummary return=remote count=${remoteSummary.transactionCount} '
        'expense=${_traceAmountFromCents((remoteSummary.expenseTotal * 100).round())} '
        'income=${_traceAmountFromCents((remoteSummary.incomeTotal * 100).round())}',
      );
      return remoteSummary;
    } catch (error) {
      _homeSpendTrace('feed-fetchSummary remote-error return=local error=$error');
      return _summaryFromLocal(localSummary);
    }
  }

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    final localQuery = _localQuery(query, pageSize: query.pageSize);
    final localItems = await _database.getTransactionsFeedItems(localQuery);
    final isComplete = await _database.isTransactionsFeedCacheComplete(
      _localQuery(query),
    );
    final hasPendingLocalRows = await _hasPendingLocalRows(localQuery);
    _homeSpendTrace(
      'feed-fetchAllPages start ${_traceFeedQuery(query)} '
      'remote=$_remoteEnabled complete=$isComplete pending=$hasPendingLocalRows '
      'localCount=${localItems.length} localTotal=${_traceAmountFromCents(_traceExpenseCents(localItems))}',
    );
    if (!_remoteEnabled) {
      _homeSpendTrace('feed-fetchAllPages return=local-offline count=${localItems.length}');
      return localItems;
    }
    if (isComplete || hasPendingLocalRows) {
      final reason = isComplete ? 'complete' : 'pending';
      _homeSpendTrace(
        'feed-fetchAllPages return=local-authoritative reason=$reason '
        'count=${localItems.length} total=${_traceAmountFromCents(_traceExpenseCents(localItems))}',
      );
      return localItems;
    }

    try {
      final remoteItems = await _remote.fetchAllPages(query);
      _homeSpendTrace(
        'feed-fetchAllPages remote count=${remoteItems.length} '
        'total=${_traceAmountFromCents(_traceExpenseCents(remoteItems))}',
      );
      await _cacheRemoteItems(remoteItems);
      await _database.markTransactionsFeedCacheComplete(
        _localQuery(query),
        isComplete: true,
      );

      final updatedLocalItems = await _database.getTransactionsFeedItems(
        localQuery,
      );
      _homeSpendTrace(
        'feed-fetchAllPages return=remote-cached updatedLocalCount=${updatedLocalItems.length} '
        'updatedLocalTotal=${_traceAmountFromCents(_traceExpenseCents(updatedLocalItems))}',
      );
      if (updatedLocalItems.isEmpty) return remoteItems;
      return _mergeRemoteWithLocalItems(remoteItems, updatedLocalItems);
    } catch (error) {
      _homeSpendTrace(
        'feed-fetchAllPages remote-error return=local error=$error '
        'count=${localItems.length} total=${_traceAmountFromCents(_traceExpenseCents(localItems))}',
      );
      return localItems;
    }
  }

  List<ExpenseEntry> _mergeRemoteWithLocalItems(
    List<ExpenseEntry> remoteItems,
    List<ExpenseEntry> localItems,
  ) {
    if (localItems.isEmpty) return remoteItems;

    final mergedById = <String, ExpenseEntry>{
      for (final item in remoteItems) item.id: item,
      for (final item in localItems) item.id: item,
    };
    final merged = mergedById.values.toList(growable: false)
      ..sort(compareTransactionsNewestFirst);
    return merged;
  }

  @override
  Future<void> refreshFromRemote(TransactionsFeedQuery query) async {
    if (!_remoteEnabled) return;
    final results = await Future.wait<dynamic>([
      _remote.fetchSummary(query),
      _remote.fetchPage(query),
    ]);
    final summary = results[0] as TransactionsFeedSummary;
    final page = results[1] as TransactionsFeedPageResult;
    final localQuery = _localQuery(query);
    await _cacheRemoteItems(page.items);
    await _database.reconcileTransactionsFeedPage(
      query: localQuery,
      authoritativeItems: page.items,
      remoteHasMore: page.hasMore,
    );
    await _database.markTransactionsFeedCacheComplete(
      localQuery,
      isComplete: !page.hasMore,
    );

    final syncedLocalCount = await _database.getTransactionsFeedCount(
      localQuery,
      syncStatus: localSyncStatusSynced,
    );
    if (syncedLocalCount > summary.transactionCount) {
      final authoritativeItems = await _remote.fetchAllPages(query);
      await _cacheRemoteItems(authoritativeItems);
      await _database.reconcileTransactionsFeedPage(
        query: localQuery,
        authoritativeItems: authoritativeItems,
        remoteHasMore: false,
      );
      await _database.markTransactionsFeedCacheComplete(
        localQuery,
        isComplete: true,
      );
    }
  }

  Future<void> _cacheRemoteItems(List<ExpenseEntry> items) async {
    final cacheable = items
        .where((entry) => entry.userId?.trim().isNotEmpty == true)
        .toList(growable: false);
    if (cacheable.isEmpty) return;
    await _database.upsertTransactions(cacheable);
  }

  Future<bool> _hasPendingLocalRows(LocalTransactionsFeedQuery query) async {
    return await _database.getTransactionsFeedCount(
          query,
          syncStatus: localSyncStatusLocal,
        ) >
        0;
  }

  LocalTransactionsFeedQuery _localQuery(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
    int? pageSize,
  }) {
    return LocalTransactionsFeedQuery(
      userId: query.userId,
      householdId: query.householdId,
      currency: query.normalizedCurrency,
      currencies: query.normalizedCurrencies,
      category: query.normalizedCategory,
      categories: query.normalizedCategories,
      accountId: query.normalizedAccountId,
      includeUnassignedAccount: query.includeUnassignedAccount,
      type: query.normalizedType,
      searchQuery: query.normalizedSearchQuery,
      startDate: query.startDate,
      endDate: query.endDate,
      pageSize: pageSize ?? query.pageSize,
      cursor: cursor == null
          ? null
          : LocalTransactionFeedCursor(
              date: cursor.date,
              createdAt: cursor.createdAt,
              id: cursor.id,
            ),
      intervalGranularity:
          query.normalizedSummaryIntervalGranularity ?? 'yearly',
    );
  }

  TransactionsFeedPageResult _pageFromLocal(
    LocalTransactionsFeedPage page,
    TransactionsFeedQuery query,
  ) {
    return TransactionsFeedPageResult(
      items: page.items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor == null
          ? null
          : TransactionsFeedCursor(
              date: page.nextCursor!.date,
              createdAt: page.nextCursor!.createdAt,
              id: page.nextCursor!.id,
            ),
    );
  }

  TransactionsFeedSummary _summaryFromLocal(
    LocalTransactionsFeedSummary summary,
  ) {
    return TransactionsFeedSummary(
      transactionCount: summary.transactionCount,
      expenseTotal: _centsToDouble(summary.expenseTotalCents),
      incomeTotal: _centsToDouble(summary.incomeTotalCents),
      hasMultipleCurrencies: summary.hasMultipleCurrencies,
      categorySummaries: summary.categorySummaries
          .map(
            (entry) => TransactionsFeedCategorySummary(
              category: canonicalizeCategoryKey(entry.category),
              amount: _centsToDouble(entry.amountCents),
              transactionCount: entry.transactionCount,
            ),
          )
          .toList(growable: false),
      yearlyPeriodTotals: _doubleBucketMap(summary.yearlyPeriodTotalsCents),
      periodTotals: _doubleBucketMap(summary.periodTotalsCents),
      currencyCategorySummaries: summary.currencyCategorySummaries
          .map(
            (entry) => TransactionsFeedCurrencyCategorySummary(
              category: canonicalizeCategoryKey(entry.category),
              currency: entry.currency.trim().toUpperCase(),
              amount: _centsToDouble(entry.amountCents),
              transactionCount: entry.transactionCount,
            ),
          )
          .where((entry) => entry.currency.isNotEmpty)
          .toList(growable: false),
      currencyYearlyPeriodTotals: summary.currencyYearlyPeriodTotals
          .map(
            (entry) => TransactionsFeedCurrencyPeriodTotal(
              bucketStart: entry.bucketStart,
              currency: entry.currency.trim().toUpperCase(),
              amount: _centsToDouble(entry.amountCents),
            ),
          )
          .where((entry) => entry.currency.isNotEmpty)
          .toList(growable: false),
      currencyPeriodTotals: summary.currencyPeriodTotals
          .map(
            (entry) => TransactionsFeedCurrencyPeriodTotal(
              bucketStart: entry.bucketStart,
              currency: entry.currency.trim().toUpperCase(),
              amount: _centsToDouble(entry.amountCents),
            ),
          )
          .where((entry) => entry.currency.isNotEmpty)
          .toList(growable: false),
      currencyTypeTotals: summary.currencyTypeTotals
          .map(
            (entry) => TransactionsFeedCurrencyTypeTotal(
              currency: entry.currency.trim().toUpperCase(),
              expenseTotal: _centsToDouble(entry.expenseTotalCents),
              incomeTotal: _centsToDouble(entry.incomeTotalCents),
              transactionCount: entry.transactionCount,
            ),
          )
          .where((entry) => entry.currency.isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<DateTime, double> _doubleBucketMap(Map<DateTime, int> source) {
    return source.map(
      (bucket, cents) => MapEntry(bucket, _centsToDouble(cents)),
    );
  }

  double _centsToDouble(int cents) => cents / 100.0;
}

class TransactionsFeedState {
  final TransactionsFeedSummary summary;
  final List<ExpenseEntry> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final TransactionsFeedCursor? nextCursor;

  const TransactionsFeedState({
    this.summary = const TransactionsFeedSummary.empty(),
    this.items = const <ExpenseEntry>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.nextCursor,
  });

  TransactionsFeedState copyWith({
    TransactionsFeedSummary? summary,
    List<ExpenseEntry>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    TransactionsFeedCursor? nextCursor,
    bool clearNextCursor = false,
  }) {
    return TransactionsFeedState(
      summary: summary ?? this.summary,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
    );
  }
}

final transactionsRemoteFeedServiceProvider =
    Provider<TransactionsFeedService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseTransactionsFeedService(client);
});

final transactionsFeedServiceProvider =
    Provider<TransactionsFeedService>((ref) {
  final remote = ref.watch(transactionsRemoteFeedServiceProvider);
  final localDatabase = ref.watch(localDatabaseProvider);
  final hasNetworkAccess =
      ref.watch(networkReachabilityProvider).valueOrNull ?? true;
  return localDatabase.when(
    data: (database) => LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
      remoteEnabled: hasNetworkAccess,
    ),
    error: (_, __) => remote,
    loading: () => const EmptyTransactionsFeedService(),
  );
});

final transactionsFeedRefreshSignalProvider = StateProvider<int>((ref) => 0);

final transactionsFeedAllItemsProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, TransactionsFeedQuery>((ref, query) async {
  ref.watch(transactionsFeedRefreshSignalProvider);
  if (query.userId.isEmpty) {
    return const <ExpenseEntry>[];
  }

  return ref.watch(transactionsFeedServiceProvider).fetchAllPages(query);
});

final transactionsFeedProvider = StateNotifierProvider.autoDispose.family<
    TransactionsFeedNotifier, TransactionsFeedState, TransactionsFeedQuery>(
  (ref, query) {
    final notifier = TransactionsFeedNotifier(
      service: ref.read(transactionsFeedServiceProvider),
      query: query,
    );
    ref.listen<TransactionsFeedService>(
      transactionsFeedServiceProvider,
      (previous, next) {
        notifier.updateService(next);
      },
    );
    ref.listen<int>(transactionsFeedRefreshSignalProvider, (previous, next) {
      if (previous == null || previous == next) {
        return;
      }
      unawaited(notifier.refresh());
    });
    unawaited(notifier.loadInitial());
    return notifier;
  },
);

class TransactionsFeedNotifier extends StateNotifier<TransactionsFeedState> {
  TransactionsFeedNotifier({
    required TransactionsFeedService service,
    required TransactionsFeedQuery query,
  })  : _service = service,
        _query = query,
        super(const TransactionsFeedState());

  TransactionsFeedService _service;
  final TransactionsFeedQuery _query;
  Future<void>? _backgroundRefresh;
  int _serviceGeneration = 0;

  void updateService(TransactionsFeedService service) {
    if (identical(_service, service)) {
      return;
    }

    _service = service;
    _serviceGeneration++;

    if (_query.userId.isEmpty || state.isLoading || state.isLoadingMore) {
      return;
    }

    if (state.items.isEmpty) {
      unawaited(loadInitial());
    } else if (service.supportsBackgroundRefresh) {
      _startBackgroundRefresh();
    }
  }

  Future<void> loadInitial() async {
    if (state.isLoading || state.isLoadingMore) {
      return;
    }

    if (_query.userId.isEmpty) {
      state = const TransactionsFeedState();
      return;
    }

    final service = _service;
    final generation = _serviceGeneration;

    if (service.supportsBackgroundRefresh && state.items.isNotEmpty) {
      state = state.copyWith(clearError: true);
      _startBackgroundRefresh();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );

    try {
      final results = await Future.wait<dynamic>([
        service.fetchSummary(_query),
        service.fetchPage(_query),
      ]);
      if (!mounted) return;
      if (generation != _serviceGeneration) {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
        unawaited(loadInitial());
        return;
      }
      final summary = results[0] as TransactionsFeedSummary;
      final page = results[1] as TransactionsFeedPageResult;
      state = TransactionsFeedState(
        summary: summary,
        items: _mergeRefreshedFirstPageWithExistingTail(
          refreshedPage: page,
          existingItems: state.items,
        ),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
      if (service.supportsBackgroundRefresh) {
        _startBackgroundRefresh();
      }
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> refresh() async {
    if (state.isLoadingMore) {
      return;
    }

    if (_query.userId.isEmpty) {
      state = const TransactionsFeedState();
      return;
    }

    final service = _service;
    final generation = _serviceGeneration;

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );

    try {
      if (service.supportsBackgroundRefresh) {
        await service.refreshFromRemote(_query);
        if (!mounted) return;
        if (generation != _serviceGeneration) {
          state = state.copyWith(isLoading: false, isLoadingMore: false);
          unawaited(refresh());
          return;
        }
      }
      final results = await Future.wait<dynamic>([
        service.fetchSummary(_query),
        service.fetchPage(_query),
      ]);
      if (!mounted) return;
      if (generation != _serviceGeneration) {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
        unawaited(refresh());
        return;
      }
      final summary = results[0] as TransactionsFeedSummary;
      final page = results[1] as TransactionsFeedPageResult;
      state = TransactionsFeedState(
        summary: summary,
        items: _mergeRefreshedFirstPageWithExistingTail(
          refreshedPage: page,
          existingItems: state.items,
        ),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    final cursor = state.nextCursor;
    if (cursor == null) {
      return;
    }

    final service = _service;
    final generation = _serviceGeneration;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await service.fetchPage(_query, cursor: cursor);
      if (!mounted) return;
      if (generation != _serviceGeneration) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final mergedItems = _mergePaginatedItems(
        existingItems: state.items,
        nextPageItems: page.items,
      );
      final madeProgress = mergedItems.length > state.items.length;
      final cursorAdvanced = page.nextCursor != null &&
          (page.nextCursor!.date != cursor.date ||
              page.nextCursor!.createdAt != cursor.createdAt ||
              page.nextCursor!.id != cursor.id);
      state = state.copyWith(
        items: mergedItems,
        isLoadingMore: false,
        hasMore: page.hasMore && (madeProgress || cursorAdvanced),
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }

  Future<void> _refreshFromRemoteAndReload() async {
    final service = _service;
    final generation = _serviceGeneration;

    try {
      await service.refreshFromRemote(_query);
      if (!mounted || generation != _serviceGeneration) return;
      final results = await Future.wait<dynamic>([
        service.fetchSummary(_query),
        service.fetchPage(_query),
      ]);
      if (!mounted || generation != _serviceGeneration) return;
      final summary = results[0] as TransactionsFeedSummary;
      final page = results[1] as TransactionsFeedPageResult;
      state = TransactionsFeedState(
        summary: summary,
        items: _mergeRefreshedFirstPageWithExistingTail(
          refreshedPage: page,
          existingItems: state.items,
        ),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (_) {
      // The local snapshot is already rendered. Background refresh failures
      // should not replace usable cached data with an error state.
    }
  }

  void _startBackgroundRefresh() {
    _backgroundRefresh ??= _refreshFromRemoteAndReload().whenComplete(() {
      _backgroundRefresh = null;
    });
  }
}

List<ExpenseEntry> _mergePaginatedItems({
  required List<ExpenseEntry> existingItems,
  required List<ExpenseEntry> nextPageItems,
}) {
  if (existingItems.isEmpty) {
    return _uniqueSortedTransactions(nextPageItems);
  }
  if (nextPageItems.isEmpty) {
    return existingItems;
  }

  return _uniqueSortedTransactions([
    ...existingItems,
    ...nextPageItems,
  ]);
}

List<ExpenseEntry> _mergeRefreshedFirstPageWithExistingTail({
  required TransactionsFeedPageResult refreshedPage,
  required List<ExpenseEntry> existingItems,
}) {
  if (existingItems.isEmpty || refreshedPage.items.isEmpty) {
    return _uniqueSortedTransactions(refreshedPage.items);
  }
  if (!refreshedPage.hasMore || refreshedPage.nextCursor == null) {
    return _uniqueSortedTransactions(refreshedPage.items);
  }

  final boundary = refreshedPage.nextCursor!;
  final retainedTail = existingItems
      .where((item) => _isTransactionOlderThanCursor(item, boundary))
      .toList(growable: false);

  return _uniqueSortedTransactions([
    ...refreshedPage.items,
    ...retainedTail,
  ]);
}

List<ExpenseEntry> _uniqueSortedTransactions(List<ExpenseEntry> items) {
  if (items.length <= 1) {
    return items;
  }

  final byId = <String, ExpenseEntry>{};
  for (final item in items) {
    byId[item.id] = item;
  }

  return byId.values.toList(growable: false)
    ..sort(compareTransactionsNewestFirst);
}

bool _isTransactionOlderThanCursor(
  ExpenseEntry item,
  TransactionsFeedCursor cursor,
) {
  if (item.date.isBefore(cursor.date)) {
    return true;
  }
  if (item.date.isAfter(cursor.date)) {
    return false;
  }
  if (item.createdAt.isBefore(cursor.createdAt)) {
    return true;
  }
  if (item.createdAt.isAfter(cursor.createdAt)) {
    return false;
  }
  return item.id.compareTo(cursor.id) < 0;
}

String? _normalizeNullable(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized.toUpperCase() == normalized
      ? normalized
      : normalized.toLowerCase();
}

bool _listEquals(List<String>? left, List<String>? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null) {
    return left == right;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
