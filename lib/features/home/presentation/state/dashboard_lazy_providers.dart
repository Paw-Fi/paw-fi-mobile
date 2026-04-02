import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DashboardDataService {
  Future<DashboardSnapshotSummary> fetchSnapshot(DashboardScopeQuery query);

  Future<List<ExpenseEntry>> fetchRecentTransactions(
    DashboardRecentTransactionsRequest request,
  );

  Future<List<ExpenseEntry>> fetchCalendarTransactions(
      DashboardScopeQuery query);
}


class PreviewDashboardDataService implements DashboardDataService {
  const PreviewDashboardDataService();

  @override
  Future<DashboardSnapshotSummary> fetchSnapshot(DashboardScopeQuery query) async {
    final expenses = PreviewMockData.expenses.where((entry) {
      final matchesHousehold = query.householdId == null
          ? (entry.householdId == null || (entry.householdId?.isEmpty ?? false))
          : entry.householdId == query.householdId;
      final matchesCurrency = query.normalizedCurrency == null ||
          (entry.currency ?? '').toUpperCase() == query.normalizedCurrency;
      final matchesStart = query.startDate == null || !entry.date.isBefore(query.startDate!);
      final matchesEnd = query.endDate == null || !entry.date.isAfter(query.endDate!);
      return !entry.isRecurring && matchesHousehold && matchesCurrency && matchesStart && matchesEnd;
    }).toList();

    final expenseRows = expenses.where((entry) => (entry.type ?? 'expense').toLowerCase() != 'income');
    final incomeRows = expenses.where((entry) => (entry.type ?? 'expense').toLowerCase() == 'income');
    final categoryTotals = <String, DashboardCategorySummary>{};
    for (final entry in expenseRows) {
      final category = (entry.category ?? 'uncategorized').toLowerCase();
      final existing = categoryTotals[category];
      categoryTotals[category] = DashboardCategorySummary(
        category: category,
        amount: (existing?.amount ?? 0) + entry.amount.abs(),
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
    }
    return DashboardSnapshotSummary(
      transactionCount: expenses.length,
      expenseTotal: expenseRows.fold<double>(0, (sum, entry) => sum + entry.amount.abs()),
      incomeTotal: incomeRows.fold<double>(0, (sum, entry) => sum + entry.amount.abs()),
      hasMultipleCurrencies: expenses.map((e) => (e.currency ?? '').toUpperCase()).where((e) => e.isNotEmpty).toSet().length > 1,
      categorySummaries: categoryTotals.values.toList(growable: false),
      periodTotals: const <DateTime, double>{},
    );
  }

  @override
  Future<List<ExpenseEntry>> fetchRecentTransactions(DashboardRecentTransactionsRequest request) async {
    final all = await fetchCalendarTransactions(request.query);
    all.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return all.take(request.limit).toList(growable: false);
  }

  @override
  Future<List<ExpenseEntry>> fetchCalendarTransactions(DashboardScopeQuery query) async {
    return PreviewMockData.expenses.where((entry) {
      final matchesHousehold = query.householdId == null
          ? (entry.householdId == null || (entry.householdId?.isEmpty ?? false))
          : entry.householdId == query.householdId;
      final matchesCurrency = query.normalizedCurrency == null ||
          (entry.currency ?? '').toUpperCase() == query.normalizedCurrency;
      final matchesStart = query.startDate == null || !entry.date.isBefore(query.startDate!);
      final matchesEnd = query.endDate == null || !entry.date.isAfter(query.endDate!);
      return !entry.isRecurring && matchesHousehold && matchesCurrency && matchesStart && matchesEnd;
    }).map((entry) => entry.copyWith()).toList(growable: false);
  }
}

class SupabaseDashboardDataService implements DashboardDataService {
  const SupabaseDashboardDataService(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardSnapshotSummary> fetchSnapshot(
      DashboardScopeQuery query) async {
    final response = await _client.rpc(
      'get_dashboard_snapshot_v1',
      params: <String, dynamic>{
        'p_user_id': query.userId,
        'p_household_id': query.householdId,
        'p_currency': query.normalizedCurrency,
        'p_start_date': query.formattedStartDate,
        'p_end_date': query.formattedEndDate,
        'p_interval_granularity': query.normalizedIntervalGranularity,
      },
    );

    final payload = Map<String, dynamic>.from(response as Map);
    final categorySummaries = ((payload['category_summaries'] as List?) ??
            const [])
        .cast<Map>()
        .map(
          (row) => DashboardCategorySummary(
            category:
                (row['category'] as String? ?? 'uncategorized').toLowerCase(),
            amount: _centsToDouble(row['amount_cents']),
            transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);

    final periodTotals = <DateTime, double>{};
    for (final row
        in ((payload['period_totals'] as List?) ?? const []).cast<Map>()) {
      final bucketRaw = row['bucket_start'];
      if (bucketRaw == null) {
        continue;
      }
      periodTotals[DateTime.parse(bucketRaw.toString())] =
          _centsToDouble(row['amount_cents']);
    }

    return DashboardSnapshotSummary(
      transactionCount: (payload['transaction_count'] as num?)?.toInt() ?? 0,
      expenseTotal: _centsToDouble(payload['expense_total_cents']),
      incomeTotal: _centsToDouble(payload['income_total_cents']),
      hasMultipleCurrencies: payload['has_multiple_currencies'] == true,
      categorySummaries: categorySummaries,
      periodTotals: periodTotals,
    );
  }

  @override
  Future<List<ExpenseEntry>> fetchRecentTransactions(
    DashboardRecentTransactionsRequest request,
  ) async {
    final response = await _client.rpc(
      'get_dashboard_recent_transactions_v1',
      params: <String, dynamic>{
        'p_user_id': request.query.userId,
        'p_household_id': request.query.householdId,
        'p_currency': request.query.normalizedCurrency,
        'p_limit': request.limit,
      },
    );

    return _parseExpenseEntries(response);
  }

  @override
  Future<List<ExpenseEntry>> fetchCalendarTransactions(
      DashboardScopeQuery query) async {
    final response = await _client.rpc(
      'get_dashboard_calendar_transactions_v1',
      params: <String, dynamic>{
        'p_user_id': query.userId,
        'p_household_id': query.householdId,
        'p_currency': query.normalizedCurrency,
        'p_start_date': query.formattedStartDate,
        'p_end_date': query.formattedEndDate,
      },
    );

    return _parseExpenseEntries(response);
  }

  List<ExpenseEntry> _parseExpenseEntries(dynamic response) {
    final rows = (response as List? ?? const [])
        .cast<Map>()
        .map((row) => ExpenseEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return rows;
  }

  double _centsToDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble() / 100;
    }
    return (num.tryParse(value.toString()) ?? 0).toDouble() / 100;
  }
}

final dashboardDataServiceProvider = Provider<DashboardDataService>((ref) {
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    return const PreviewDashboardDataService();
  }
  return SupabaseDashboardDataService(supabase);
});

final dashboardRefreshSignalProvider = StateProvider<int>((ref) => 0);

final dashboardSummaryProvider = FutureProvider.autoDispose
    .family<DashboardSnapshotSummary, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(dashboardRefreshSignalProvider);
    final service = ref.watch(dashboardDataServiceProvider);
    return service.fetchSnapshot(query);
  },
);

final dashboardRecentTransactionsProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, DashboardRecentTransactionsRequest>(
  (ref, request) async {
    ref.watch(dashboardRefreshSignalProvider);
    final service = ref.watch(dashboardDataServiceProvider);
    return service.fetchRecentTransactions(request);
  },
);

final dashboardCalendarTransactionsProvider =
    FutureProvider.autoDispose.family<List<ExpenseEntry>, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(dashboardRefreshSignalProvider);
    final service = ref.watch(dashboardDataServiceProvider);
    return service.fetchCalendarTransactions(query);
  },
);
