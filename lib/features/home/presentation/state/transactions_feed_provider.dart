import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionsFeedQuery {
  final String userId;
  final String? householdId;
  final String? selectedCurrency;
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
        normalizedCurrency == other.normalizedCurrency &&
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
        normalizedCurrency,
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

class TransactionsFeedSummary {
  final int transactionCount;
  final double expenseTotal;
  final double incomeTotal;
  final bool hasMultipleCurrencies;
  final List<TransactionsFeedCategorySummary> categorySummaries;
  final Map<DateTime, double> yearlyPeriodTotals;
  final Map<DateTime, double> periodTotals;

  const TransactionsFeedSummary({
    required this.transactionCount,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.hasMultipleCurrencies,
    required this.categorySummaries,
    required this.yearlyPeriodTotals,
    this.periodTotals = const <DateTime, double>{},
  });

  const TransactionsFeedSummary.empty()
      : transactionCount = 0,
        expenseTotal = 0,
        incomeTotal = 0,
        hasMultipleCurrencies = false,
        categorySummaries = const <TransactionsFeedCategorySummary>[],
        yearlyPeriodTotals = const <DateTime, double>{},
        periodTotals = const <DateTime, double>{};

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

    final categoryMap = {
      for (final summary in categorySummaries)
        summary.category: summary.copyWith(),
    };

    for (final expense in expenseRows) {
      final category = (expense.category ?? 'uncategorized').toLowerCase();
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
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  });

  Future<TransactionsFeedSummary> fetchSummary(TransactionsFeedQuery query);

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

class SupabaseTransactionsFeedService implements TransactionsFeedService {
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
    final categoryRows = ((payload['category_summaries'] as List?) ?? const [])
        .cast<Map>()
        .map(
          (row) => TransactionsFeedCategorySummary(
            category:
                (row['category'] as String? ?? 'uncategorized').toLowerCase(),
            amount: _centsToDouble(row['amount_cents']),
            transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

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
    );
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
  }) {
    return TransactionsFeedState(
      summary: summary ?? this.summary,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }
}

final transactionsFeedServiceProvider =
    Provider<TransactionsFeedService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseTransactionsFeedService(client);
});

final transactionsFeedRefreshSignalProvider = StateProvider<int>((ref) => 0);

final transactionsFeedProvider = StateNotifierProvider.autoDispose.family<
    TransactionsFeedNotifier, TransactionsFeedState, TransactionsFeedQuery>(
  (ref, query) {
    ref.watch(transactionsFeedRefreshSignalProvider);
    final notifier = TransactionsFeedNotifier(
      service: ref.watch(transactionsFeedServiceProvider),
      query: query,
    );
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

  final TransactionsFeedService _service;
  final TransactionsFeedQuery _query;

  Future<void> loadInitial() async {
    if (state.isLoading || state.isLoadingMore) {
      return;
    }

    if (_query.userId.isEmpty) {
      state = const TransactionsFeedState();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );

    try {
      final results = await Future.wait<dynamic>([
        _service.fetchSummary(_query),
        _service.fetchPage(_query),
      ]);
      final summary = results[0] as TransactionsFeedSummary;
      final page = results[1] as TransactionsFeedPageResult;
      state = TransactionsFeedState(
        summary: summary,
        items: page.items,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
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

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );

    try {
      final results = await Future.wait<dynamic>([
        _service.fetchSummary(_query),
        _service.fetchPage(_query),
      ]);
      final summary = results[0] as TransactionsFeedSummary;
      final page = results[1] as TransactionsFeedPageResult;
      state = TransactionsFeedState(
        summary: summary,
        items: page.items,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
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

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _service.fetchPage(_query, cursor: cursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        isLoadingMore: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }
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
