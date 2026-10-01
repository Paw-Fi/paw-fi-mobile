import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/monitoring/performance_trace.dart';
import 'package:moneko/core/utils/in_flight_requests.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

Map<String, Object?> describeTransactionsFeedRequest(
        TransactionsFeedQuery query) =>
    {
      'user': query.userId,
      'household': query.householdId,
      'currencies': query.normalizedCurrencies,
      'category': query.normalizedCategory,
      'categories': query.normalizedCategories,
      'wallet': query.normalizedAccountId,
      'includeUnassigned': query.includeUnassignedAccount,
      'type': query.normalizedType,
      'searchFingerprint': query.normalizedSearchQuery?.hashCode,
      'start': query.formattedStartDate,
      'end': query.formattedEndDate,
      'interval': query.normalizedSummaryIntervalGranularity,
      'pageSize': query.pageSize,
    };

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
  final List<TransactionsFeedCurrencyCategorySummary> currencyCategorySummaries;
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
    final summaryExpenses = expenses
        .where((expense) => !expense.id.startsWith('transfer:'))
        .toList(growable: false);
    if (summaryExpenses.isEmpty) {
      return this;
    }

    final expenseRows = summaryExpenses
        .where((expense) => expense.effectiveSpendingMultiplier != 0)
        .toList();
    final incomeRows =
        summaryExpenses.where((expense) => expense.countsTowardIncome).toList();

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
        amount: current.amount + expense.spendingEffect,
        transactionCount: current.transactionCount + 1,
      );
    }

    final yearlyTotals = Map<DateTime, double>.from(yearlyPeriodTotals);
    final addedYearly = groupExpensesByInterval(summaryExpenses, 'yearly');
    for (final entry in addedYearly.entries) {
      yearlyTotals[entry.key] = (yearlyTotals[entry.key] ?? 0) + entry.value;
    }

    final periodTotals = Map<DateTime, double>.from(this.periodTotals);

    final extraCurrencies = summaryExpenses
        .map((expense) => expense.currency?.trim().toUpperCase())
        .where((currency) => currency != null && currency.isNotEmpty)
        .cast<String>()
        .toSet();

    return TransactionsFeedSummary(
      transactionCount: transactionCount + summaryExpenses.length,
      expenseTotal: expenseTotal +
          expenseRows.fold<double>(
              0, (sum, expense) => sum + expense.spendingEffect),
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

/// The transaction feed is the posted-transaction source. Recurring templates
/// are schedule definitions and must be read from the recurring provider so a
/// confirmed occurrence is never rendered or aggregated beside its template.
@foundation.visibleForTesting
List<ExpenseEntry> postedTransactionFeedEntries(
  Iterable<ExpenseEntry> entries,
) =>
    entries.where((entry) => !entry.isRecurring).toList(growable: false);

abstract class TransactionsFeedService {
  int get reconciliationRevision => 0;
  const TransactionsFeedService();

  bool get supportsBackgroundRefresh => false;

  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  });

  Future<TransactionsFeedSummary> fetchSummary(TransactionsFeedQuery query);

  /// Returns a trustworthy local page and summary without contacting remote.
  /// A partial row cache must not be presented as a complete financial summary.
  Future<TransactionsFeedState?> fetchCachedSnapshot(
    TransactionsFeedQuery query,
  ) async =>
      null;

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

/// The database has not resolved yet; this is not a successfully empty feed.
class OpeningDatabaseTransactionsFeedService
    extends EmptyTransactionsFeedService {
  const OpeningDatabaseTransactionsFeedService();
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
    const rpcName = _transactionsPageRpcName;
    final params = _transactionsPageRpcParams(
      query,
      cursor: cursor,
      includeGeneralFilters: true,
    );

    final response = await _runRpc(rpcName: rpcName, params: params);

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

  Map<String, dynamic> _transactionsPageRpcParams(
    TransactionsFeedQuery query, {
    required TransactionsFeedCursor? cursor,
    required bool includeGeneralFilters,
  }) {
    return <String, dynamic>{
      'p_user_id': query.userId,
      'p_household_id': query.householdId,
      'p_currency': query.normalizedCurrency,
      if (query.normalizedSelectedCurrencies != null)
        'p_currencies': query.normalizedSelectedCurrencies,
      if (includeGeneralFilters) ...{
        'p_category': query.normalizedCategory,
        'p_account_id': query.normalizedAccountId,
        'p_include_unassigned_account': query.includeUnassignedAccount,
        'p_categories': query.normalizedCategories,
        'p_search_query': query.normalizedSearchQuery,
      },
      'p_type': query.normalizedType,
      'p_start_date': query.formattedStartDate,
      'p_end_date': query.formattedEndDate,
      'p_page_size': query.pageSize,
      'p_cursor_date': cursor == null ? null : formatDateOnlyYmd(cursor.date),
      'p_cursor_created_at': cursor?.createdAt.toUtc().toIso8601String(),
      'p_cursor_id': cursor?.id,
    };
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
      rpcName: _transactionsSummaryRpcName,
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
      currencyCategorySummaries: _parseCurrencyCategorySummaries(
          payload['currency_category_summaries']),
      currencyYearlyPeriodTotals:
          _parseCurrencyPeriodTotals(payload['currency_yearly_period_totals']),
      currencyPeriodTotals:
          _parseCurrencyPeriodTotals(payload['currency_period_totals']),
      currencyTypeTotals: _parseCurrencyTypeTotals(
        payload['currency_type_totals'],
      ),
    );
  }

  List<TransactionsFeedCurrencyCategorySummary> _parseCurrencyCategorySummaries(
      dynamic source) {
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
    return PerformanceTrace.measureAsync(
        'rpc.$rpcName', () async => _client.rpc(rpcName, params: params),
        identity: () => {
              for (final entry in params.entries)
                if (entry.key != 'p_search_query') entry.key: entry.value,
              'searchFingerprint': params['p_search_query']?.hashCode,
            });
  }
}

const _transactionsPageRpcName = 'get_user_transactions_page_v6';

@foundation.visibleForTesting
String transactionsPageRpcNameForTesting(TransactionsFeedQuery query) =>
    _transactionsPageRpcName;

const _transactionsSummaryRpcName = 'get_user_transactions_summary_v2';

@foundation.visibleForTesting
String transactionsSummaryRpcNameForTesting() => _transactionsSummaryRpcName;

class LocalFirstTransactionsFeedService extends TransactionsFeedService {
  LocalFirstTransactionsFeedService({
    required MonekoDatabase database,
    required TransactionsFeedService remote,
    bool remoteEnabled = true,
  })  : _database = database,
        _remote = remote,
        _remoteEnabled = remoteEnabled;

  final MonekoDatabase _database;
  final TransactionsFeedService _remote;
  final bool _remoteEnabled;
  final _remoteRefreshRequests =
      InFlightRequests<(TransactionsFeedQuery, int), void>();

  @override
  int get reconciliationRevision => _database.transactionRevision;

  @override
  bool get supportsBackgroundRefresh => _remoteEnabled;

  @override
  Future<TransactionsFeedState?> fetchCachedSnapshot(
    TransactionsFeedQuery query,
  ) async {
    final localQuery = _localQuery(query);
    if (!await _database.isTransactionsFeedCacheComplete(localQuery)) {
      return null;
    }
    final page = await _database.getTransactionsFeedPage(localQuery);
    final summary = await _database.getTransactionsFeedSummary(localQuery);
    final localPage = _pageFromLocal(page, query);
    return TransactionsFeedState(
      summary: _summaryFromLocal(summary),
      items: localPage.items,
      hasMore: localPage.hasMore,
      nextCursor: localPage.nextCursor,
      hasLoadedInitial: true,
    );
  }

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
    if (!_remoteEnabled) {
      return _pageFromLocal(localPage, query);
    }
    if (isComplete || (cursor == null && localPage.items.isNotEmpty)) {
      return _pageFromLocal(localPage, query);
    }

    try {
      final rawRemotePage = await _remote.fetchPage(query, cursor: cursor);
      final remotePage = TransactionsFeedPageResult(
        items: postedTransactionFeedEntries(rawRemotePage.items),
        hasMore: rawRemotePage.hasMore,
        nextCursor: rawRemotePage.nextCursor,
      );
      await _cacheRemoteItems(remotePage.items);
      if (cursor == null || !remotePage.hasMore) {
        await _database.markTransactionsFeedCacheComplete(
          _localQuery(query),
          isComplete: !remotePage.hasMore,
        );
      }
      final updatedLocalPage = await _database.getTransactionsFeedPage(
        localQuery,
      );
      if (updatedLocalPage.items.isEmpty) return remotePage;
      return _pageFromLocal(
        updatedLocalPage,
        query,
        hasMore: remotePage.hasMore || updatedLocalPage.hasMore,
        nextCursor: remotePage.nextCursor,
      );
    } catch (error) {
      if (_isAuthorizationError(error)) rethrow;
      return _pageFromLocal(localPage, query);
    }
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
    TransactionsFeedQuery query,
  ) async {
    final localQuery = _localQuery(query);
    final localSummary = await _database.getTransactionsFeedSummary(localQuery);
    final hasPendingLocalRows = await _hasPendingLocalRows(localQuery);
    final hasPendingUpdatesOrDeletes =
        await _database.hasPendingTransactionUpdatesOrDeletes();
    if (!_remoteEnabled) {
      return _summaryFromLocal(localSummary);
    }
    if (hasPendingUpdatesOrDeletes) {
      return _summaryFromLocal(localSummary);
    }
    try {
      var remoteSummary = await _remote.fetchSummary(query);
      if (hasPendingLocalRows) {
        final pendingUpdateIds =
            await _database.getPendingTransactionUpdateIds();
        final pendingCreates = (await _database.getTransactionsFeedItems(
          localQuery,
          syncStatus: localSyncStatusLocal,
        ))
            .where((expense) => !pendingUpdateIds.contains(expense.id))
            .toList(growable: false);
        remoteSummary = remoteSummary.addingExpenses(pendingCreates);
      }
      return remoteSummary;
    } catch (error) {
      if (_isAuthorizationError(error)) rethrow;
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
    if (!_remoteEnabled) {
      return localItems;
    }
    if (isComplete) {
      return localItems;
    }

    try {
      final remoteItems = postedTransactionFeedEntries(
        await _remote.fetchAllPages(query),
      );
      await _cacheRemoteItems(remoteItems);
      await _database.reconcileTransactionsFeedPage(
        query: _localQuery(query),
        authoritativeItems: remoteItems,
        remoteHasMore: false,
      );
      await _database.markTransactionsFeedCacheComplete(
        _localQuery(query),
        isComplete: true,
      );

      final updatedLocalItems = await _database.getTransactionsFeedItems(
        localQuery,
      );
      if (updatedLocalItems.isEmpty) return remoteItems;
      return _mergeRemoteWithLocalItems(remoteItems, updatedLocalItems);
    } catch (error) {
      if (_isAuthorizationError(error)) rethrow;
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
    final revision = reconciliationRevision;
    PerformanceTrace.event('feed.reconcile-request',
        () => describeTransactionsFeedRequest(query)..['revision'] = revision);
    return _remoteRefreshRequests.run((query, revision), () {
      return PerformanceTrace.measureAsync(
          'feed.reconcile', () => _refreshFromRemote(query),
          identity: () =>
              describeTransactionsFeedRequest(query)..['revision'] = revision);
    });
  }

  Future<void> _refreshFromRemote(TransactionsFeedQuery query) async {
    final localQuery = _localQuery(query);
    final cacheWasComplete =
        await _database.isTransactionsFeedCacheComplete(localQuery);
    final results = await Future.wait<dynamic>([
      _remote.fetchSummary(query),
      _remote.fetchPage(query),
    ]);
    final summary = results[0] as TransactionsFeedSummary;
    final rawPage = results[1] as TransactionsFeedPageResult;
    final page = TransactionsFeedPageResult(
      items: postedTransactionFeedEntries(rawPage.items),
      hasMore: rawPage.hasMore,
      nextCursor: rawPage.nextCursor,
    );
    await _cacheRemoteItems(page.items);
    await _database.reconcileTransactionsFeedPage(
      query: localQuery,
      authoritativeItems: page.items,
      remoteHasMore: page.hasMore,
    );
    await _database.markTransactionsFeedCacheComplete(
      localQuery,
      isComplete: cacheWasComplete || !page.hasMore,
    );

    final syncedLocalCount = await _database.getTransactionsFeedCount(
      localQuery,
      syncStatus: localSyncStatusSynced,
      excludeWalletTransferFeedRows: true,
    );
    final cacheIsComplete = await _database.isTransactionsFeedCacheComplete(
      localQuery,
    );
    if (!cacheIsComplete || syncedLocalCount != summary.transactionCount) {
      final authoritativeItems = postedTransactionFeedEntries(
        await _remote.fetchAllPages(query),
      );
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
    TransactionsFeedQuery query, {
    bool? hasMore,
    TransactionsFeedCursor? nextCursor,
  }) {
    final localNextCursor = page.nextCursor == null
        ? null
        : TransactionsFeedCursor(
            date: page.nextCursor!.date,
            createdAt: page.nextCursor!.createdAt,
            id: page.nextCursor!.id,
          );
    return TransactionsFeedPageResult(
      items: page.items,
      hasMore: hasMore ?? page.hasMore,
      nextCursor: nextCursor ?? localNextCursor,
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
  final bool hasLoadedInitial;
  final String? error;
  final TransactionsFeedCursor? nextCursor;

  const TransactionsFeedState({
    this.summary = const TransactionsFeedSummary.empty(),
    this.items = const <ExpenseEntry>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.hasLoadedInitial = false,
    this.error,
    this.nextCursor,
  });

  TransactionsFeedState copyWith({
    TransactionsFeedSummary? summary,
    List<ExpenseEntry>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasLoadedInitial,
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
      hasLoadedInitial: hasLoadedInitial ?? this.hasLoadedInitial,
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
    );
  }
}

bool _isAuthorizationError(Object error) =>
    error is PostgrestException && error.code == '42501';

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
    loading: () => const OpeningDatabaseTransactionsFeedService(),
  );
});

final transactionsFeedRefreshSignalProvider = StateProvider<int>((ref) => 0);

class TransactionsFeedEditedEntry {
  TransactionsFeedEditedEntry({
    required this.entry,
    Set<String> replacingIds = const <String>{},
  }) : replacingIds = Set<String>.unmodifiable(replacingIds);

  final ExpenseEntry entry;
  final Set<String> replacingIds;
}

final transactionsFeedEditedEntryProvider =
    StateProvider<TransactionsFeedEditedEntry?>(
  (ref) => null,
);

final transactionsFeedAllItemsProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, TransactionsFeedQuery>((ref, query) async {
  ref.watch(transactionsFeedRefreshSignalProvider);
  if (query.userId.isEmpty) {
    return const <ExpenseEntry>[];
  }

  var active = true;
  ref.onDispose(() => active = false);
  final service = await ref.watch(transactionsFeedReadyServiceProvider.future);
  // A dependency can rebuild this provider while SQLite is opening. The old
  // generation's result is discarded; it must not continue into a second read.
  if (!active) return const <ExpenseEntry>[];
  return service.fetchAllPages(query);
});

/// Waiting readers never interpret an opening database as a valid empty list.
/// Dependencies are captured before awaiting; no disposed ref is used later.
final transactionsFeedReadyServiceProvider =
    FutureProvider<TransactionsFeedService>((ref) async {
  final service = ref.watch(transactionsFeedServiceProvider);
  if (service is! OpeningDatabaseTransactionsFeedService) return service;
  final remote = ref.watch(transactionsRemoteFeedServiceProvider);
  final online = ref.watch(networkReachabilityProvider).valueOrNull ?? true;
  final opening = ref.watch(localDatabaseProvider.future);
  try {
    final database = await opening;
    return LocalFirstTransactionsFeedService(
        database: database, remote: remote, remoteEnabled: online);
  } catch (_) {
    return remote;
  }
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
      unawaited(notifier.refresh(reason: 'mutation-refresh'));
    });
    ref.listen<TransactionsFeedEditedEntry?>(
        transactionsFeedEditedEntryProvider, (previous, next) {
      if (next == null) {
        return;
      }
      notifier.applyEditedEntrySnapshot(
        next.entry,
        replacingIds: next.replacingIds,
      );
    });
    unawaited(PerformanceTrace.withReason(
        'provider-initialization', notifier.loadInitial));
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
  final _refreshRequests = InFlightRequests<(int, int, int), void>();
  (int, int, int)? _latestRefreshKey;
  int _localEditGeneration = 0;
  Future<void>? _initialLoadOperation;
  int _serviceGeneration = 0;

  void updateService(TransactionsFeedService service) {
    if (identical(_service, service)) {
      return;
    }

    final wasWaitingForDatabase =
        _service is OpeningDatabaseTransactionsFeedService;
    _service = service;
    _serviceGeneration++;
    if (wasWaitingForDatabase &&
        service is! OpeningDatabaseTransactionsFeedService) {
      state = state.copyWith(isLoading: false);
      unawaited(loadInitial());
      return;
    }

    if (_query.userId.isEmpty || state.isLoading || state.isLoadingMore) {
      return;
    }

    if (state.items.isEmpty && !state.hasLoadedInitial) {
      unawaited(loadInitial());
    } else if (service.supportsBackgroundRefresh) {
      _startBackgroundRefresh();
    }
  }

  void applyEditedEntrySnapshot(
    ExpenseEntry entry, {
    Set<String> replacingIds = const <String>{},
  }) {
    final idsToReplace = {...replacingIds, entry.id};
    final existingIndex =
        state.items.indexWhere((item) => idsToReplace.contains(item.id));
    final matches = _entryMatchesQuery(entry);
    if (state.items.isEmpty) {
      return;
    }
    if (existingIndex == -1 && !matches) {
      return;
    }

    final nextItems = state.items
        .where((item) => !idsToReplace.contains(item.id))
        .toList(growable: true);
    if (matches) {
      nextItems.add(entry);
    }

    _localEditGeneration++;
    state = state.copyWith(
      items: _uniqueSortedTransactions(nextItems),
      clearError: true,
    );
  }

  void applyOptimisticEntries(Iterable<ExpenseEntry> entries) {
    final matchingEntries = entries.where(_entryMatchesQuery).toList();
    if (matchingEntries.isEmpty) return;
    final matchingIds = matchingEntries.map((entry) => entry.id).toSet();
    _localEditGeneration++;
    state = state.copyWith(
      items: _uniqueSortedTransactions([
        ...state.items.where((entry) => !matchingIds.contains(entry.id)),
        ...matchingEntries,
      ]),
      clearError: true,
    );
  }

  /// Atomically replaces stale optimistic rows with their canonical rows.
  void replaceEntries({
    required Iterable<String> removedIds,
    required Iterable<ExpenseEntry> entries,
  }) {
    final ids = removedIds.where((id) => id.isNotEmpty).toSet();
    final matchingEntries = entries.where(_entryMatchesQuery).toList();
    _localEditGeneration++;
    state = state.copyWith(
      items: _uniqueSortedTransactions([
        ...state.items.where((entry) => !ids.contains(entry.id)),
        ...matchingEntries,
      ]),
      clearError: true,
    );
  }

  bool _entryMatchesQuery(ExpenseEntry entry) {
    final userId = entry.userId?.trim();
    if (userId == null || userId.isEmpty || userId != _query.userId) {
      return false;
    }

    final entryHouseholdId = entry.householdId?.trim();
    final queryHouseholdId = _query.householdId?.trim();
    if (queryHouseholdId == null || queryHouseholdId.isEmpty) {
      if (entryHouseholdId != null && entryHouseholdId.isNotEmpty) {
        return false;
      }
    } else if (entryHouseholdId != queryHouseholdId) {
      return false;
    }

    final entryCurrency = entry.currency?.trim().toUpperCase();
    final currencies = _query.normalizedCurrencies;
    if (currencies != null &&
        (entryCurrency == null || !currencies.contains(entryCurrency))) {
      return false;
    }

    final category = (entry.category ?? 'uncategorized').trim().toLowerCase();
    final queryCategory = _query.normalizedCategory?.trim().toLowerCase();
    if (queryCategory != null && category != queryCategory) {
      return false;
    }
    final queryCategories = _query.normalizedCategories;
    if (queryCategories != null && !queryCategories.contains(category)) {
      return false;
    }

    final queryAccountId = _query.normalizedAccountId;
    if (queryAccountId != null && entry.walletId != queryAccountId) {
      return false;
    }

    final type = (entry.type ?? 'expense').trim().toLowerCase();
    final queryType = _query.normalizedType;
    if (queryType != 'all' && type != queryType) {
      return false;
    }

    final search = _query.normalizedSearchQuery?.toLowerCase();
    if (search != null) {
      final rawText = (entry.rawText ?? '').toLowerCase();
      final merchant = (entry.merchant ?? '').toLowerCase();
      final amount = entry.amount.toString();
      if (!category.contains(search) &&
          !rawText.contains(search) &&
          !merchant.contains(search) &&
          !amount.contains(search)) {
        return false;
      }
    }

    final entryDate =
        DateTime(entry.date.year, entry.date.month, entry.date.day);
    final startDate = _query.startDate;
    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      if (entryDate.isBefore(start)) {
        return false;
      }
    }
    final endDate = _query.endDate;
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      if (entryDate.isAfter(end)) {
        return false;
      }
    }

    return true;
  }

  Future<void> loadInitial() {
    if (state.isLoading || state.isLoadingMore) {
      return _initialLoadOperation ?? Future<void>.value();
    }

    final operation = _loadInitial();
    _initialLoadOperation = operation;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_initialLoadOperation, operation)) {
            _initialLoadOperation = null;
          }
        },
        onError: (Object _, StackTrace __) {
          if (identical(_initialLoadOperation, operation)) {
            _initialLoadOperation = null;
          }
        },
      ),
    );
    return operation;
  }

  Future<void> _loadInitial() async {
    if (_query.userId.isEmpty) {
      state = const TransactionsFeedState();
      return;
    }

    final service = _service;
    final generation = _serviceGeneration;
    if (service is OpeningDatabaseTransactionsFeedService) {
      state = state.copyWith(isLoading: true);
      return;
    }

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
      final cached = await service.fetchCachedSnapshot(_query);
      if (!mounted) return;
      if (generation != _serviceGeneration) {
        state = state.copyWith(isLoading: false);
        unawaited(loadInitial());
        return;
      }
      if (cached != null) {
        state = cached;
        if (service.supportsBackgroundRefresh) _startBackgroundRefresh();
        return;
      }
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
      final mergedPage = await _reloadVisibleRefreshItems(
        service: service,
        refreshedPage: page,
        existingItems: state.items,
      );
      if (!mounted) return;
      if (generation != _serviceGeneration) {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
        unawaited(loadInitial());
        return;
      }
      state = TransactionsFeedState(
        summary: summary,
        items: mergedPage.items,
        hasMore: mergedPage.hasMore,
        hasLoadedInitial: true,
        nextCursor: mergedPage.nextCursor,
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

  Future<void> refresh(
      {String reason = 'explicit-refresh', bool background = false}) async {
    if (_service is OpeningDatabaseTransactionsFeedService) {
      await loadInitial();
      return;
    }
    if (state.isLoadingMore) return;
    if (_query.userId.isEmpty) {
      state = const TransactionsFeedState();
      return;
    }
    final service = _service;
    final generation = _serviceGeneration;
    final editGeneration = _localEditGeneration;
    final key = (generation, service.reconciliationRevision, editGeneration);
    PerformanceTrace.withReason(reason, () {
      PerformanceTrace.event(
          'feed.notifier-request',
          () => describeTransactionsFeedRequest(_query)
            ..addAll({
              'serviceGeneration': generation,
              'editGeneration': editGeneration,
              'revision': key.$2,
              'background': background,
            }));
    });
    if (!background) {
      state = state.copyWith(
          isLoading: true, isLoadingMore: false, clearError: true);
    }
    try {
      await _refreshRequests.run(key, () {
        _latestRefreshKey = key;
        return PerformanceTrace.withReason(
            reason,
            () => PerformanceTrace.measureAsync('feed.notifier-reconcile',
                () => _reconcileAndReload(service, key),
                identity: () => describeTransactionsFeedRequest(_query)
                  ..addAll({
                    'serviceGeneration': generation,
                    'editGeneration': editGeneration,
                    'revision': key.$2
                  })));
      });
    } catch (error) {
      if (_isCurrentRefresh(key) && !background) {
        state = state.copyWith(isLoading: false, error: error.toString());
      } else if (_isCurrentRefresh(key) && state.isLoading) {
        // A newer silent pass can supersede a foreground pass. Its failure
        // must still release that pass's indicator while retaining content.
        state = state.copyWith(isLoading: false);
      }
    }
    if (!mounted) return;
    if (generation != _serviceGeneration ||
        editGeneration != _localEditGeneration) {
      // A newer caller already owns the required generation, including when
      // it completed before this older response. Do not start a third pass.
      final latest = _latestRefreshKey;
      if (latest != key &&
          latest?.$1 == _serviceGeneration &&
          latest?.$3 == _localEditGeneration) {
        return;
      }
      await refresh(reason: 'revision-followup', background: background);
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

  bool _isCurrentRefresh((int, int, int) key) =>
      mounted &&
      key == _latestRefreshKey &&
      key.$1 == _serviceGeneration &&
      key.$3 == _localEditGeneration;

  Future<void> _reconcileAndReload(
      TransactionsFeedService service, (int, int, int) key) async {
    if (service.supportsBackgroundRefresh) {
      await service.refreshFromRemote(_query);
      if (!_isCurrentRefresh(key)) return;
    }
    final results = await Future.wait<dynamic>([
      service.fetchSummary(_query),
      service.fetchPage(_query),
    ]);
    if (!_isCurrentRefresh(key)) return;
    final summary = results[0] as TransactionsFeedSummary;
    final page = results[1] as TransactionsFeedPageResult;
    final mergedPage = await _reloadVisibleRefreshItems(
      service: service,
      refreshedPage: page,
      existingItems: state.items,
    );
    if (!_isCurrentRefresh(key)) return;
    state = TransactionsFeedState(
      summary: summary,
      items: mergedPage.items,
      hasMore: mergedPage.hasMore,
      hasLoadedInitial: true,
      nextCursor: mergedPage.nextCursor,
    );
  }

  void _startBackgroundRefresh() {
    unawaited(refresh(reason: 'background-reconciliation', background: true));
  }

  Future<_RefreshMergeResult> _reloadVisibleRefreshItems({
    required TransactionsFeedService service,
    required TransactionsFeedPageResult refreshedPage,
    required List<ExpenseEntry> existingItems,
  }) async {
    var mergedItems = _uniqueSortedTransactions(refreshedPage.items);
    var hasMore = refreshedPage.hasMore;
    var nextCursor = refreshedPage.nextCursor;

    if (existingItems.isEmpty ||
        !hasMore ||
        nextCursor == null ||
        mergedItems.length >= existingItems.length) {
      return _RefreshMergeResult(
        items: _mergeRefreshedFirstPageWithExistingTail(
          refreshedPage: refreshedPage,
          existingItems: existingItems,
        ),
        hasMore: hasMore,
        nextCursor: nextCursor,
      );
    }

    while (hasMore &&
        nextCursor != null &&
        mergedItems.length < existingItems.length) {
      final previousLength = mergedItems.length;
      final previousCursor = nextCursor;
      final nextPage = await service.fetchPage(_query, cursor: nextCursor);
      mergedItems = _uniqueSortedTransactions([
        ...mergedItems,
        ...nextPage.items,
      ]);
      hasMore = nextPage.hasMore;
      nextCursor = nextPage.nextCursor;

      final cursorAdvanced = nextCursor != null &&
          (nextCursor.date != previousCursor.date ||
              nextCursor.createdAt != previousCursor.createdAt ||
              nextCursor.id != previousCursor.id);
      if (mergedItems.length == previousLength && !cursorAdvanced) {
        break;
      }
    }

    return _RefreshMergeResult(
      items: mergedItems,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }
}

class _RefreshMergeResult {
  final List<ExpenseEntry> items;
  final bool hasMore;
  final TransactionsFeedCursor? nextCursor;

  const _RefreshMergeResult({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });
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
