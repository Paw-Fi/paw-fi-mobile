import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

class PocketTransactionsParams {
  final String pocketId;
  final PocketsScopeParams scopeParams;

  const PocketTransactionsParams(
      {required this.pocketId, required this.scopeParams});

  @override
  bool operator ==(Object other) =>
      other is PocketTransactionsParams &&
      other.pocketId == pocketId &&
      other.scopeParams == scopeParams;

  @override
  int get hashCode => Object.hash(pocketId, scopeParams);
}

class CategorySpend {
  final String category;
  final double amount;
  final double share; // 0-1

  CategorySpend(
      {required this.category, required this.amount, required this.share});
}

class DailySpend {
  final int day;
  final double amount;

  DailySpend({required this.day, required this.amount});
}

class PocketDetailsData {
  final List<Map<String, dynamic>> transactions;
  final List<CategorySpend> categorySpending;
  final List<DailySpend> dailySpending;
  final double totalSpentLastMonth;
  final double projectedSpend;
  final double dailyAverage;

  PocketDetailsData({
    required this.transactions,
    required this.categorySpending,
    required this.dailySpending,
    required this.totalSpentLastMonth,
    required this.projectedSpend,
    required this.dailyAverage,
  });
}

final pocketDetailsProvider =
    FutureProvider.family<PocketDetailsData, PocketTransactionsParams>(
        (ref, params) async {
  final authUser = ref.read(authProvider);
  final filter = ref.read(homeFilterProvider);
  final selectedCurrency = filter.selectedCurrency ?? 'USD';
  final range = getDateRangeFromFilter(
    filter.dateRangeFilter,
    filter.customStartDate,
    filter.customEndDate,
  );

  final end = range['to'] ?? DateTime.now();
  final monthStart = DateTime(end.year, end.month, 1);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

  // Previous month range
  final prevMonthStart = DateTime(monthStart.year, monthStart.month - 1, 1);
  final prevMonthEnd = monthStart;

  // 1. Get categories linked to this pocket
  final linksRes = await supabase
      .from('envelope_category_links')
      .select('category')
      .eq('envelope_id', params.pocketId);

  final categories =
      (linksRes as List?)?.map((r) => r['category'] as String).toList() ?? [];

  if (categories.isEmpty) {
    return PocketDetailsData(
      transactions: [],
      categorySpending: [],
      dailySpending: [],
      totalSpentLastMonth: 0,
      projectedSpend: 0,
      dailyAverage: 0,
    );
  }

  // 2. Fetch CURRENT month expenses
  var query = supabase
      .from('expenses')
      .select('*')
      .eq('currency', selectedCurrency)
      .gte('date', monthStart.toIso8601String())
      .lt('date', monthEnd.toIso8601String())
      .inFilter('category', categories);

  final scopeType = params.scopeParams.scope;
  final householdId = params.scopeParams.householdId;
  if (scopeType != PocketsScopeType.personal && householdId == null) {
    return PocketDetailsData(
      transactions: [],
      categorySpending: [],
      dailySpending: [],
      totalSpentLastMonth: 0,
      projectedSpend: 0,
      dailyAverage: 0,
    );
  }

  query = switch (scopeType) {
    PocketsScopeType.personal =>
      query.eq('user_id', authUser.uid).isFilter('household_id', null),
    PocketsScopeType.portfolio =>
      query.eq('user_id', authUser.uid).eq('household_id', householdId!),
    PocketsScopeType.household => query.eq('household_id', householdId!),
  };

  final res = await query.order('date', ascending: false);
  final transactions = (res as List?)?.cast<Map<String, dynamic>>() ?? [];

  // 3. Fetch PREVIOUS month expenses (for comparison)
  var prevQuery = supabase
      .from('expenses')
      .select('amount_cents')
      .eq('currency', selectedCurrency)
      .gte('date', prevMonthStart.toIso8601String())
      .lt('date', prevMonthEnd.toIso8601String())
      .inFilter('category', categories);

  prevQuery = switch (scopeType) {
    PocketsScopeType.personal =>
      prevQuery.eq('user_id', authUser.uid).isFilter('household_id', null),
    PocketsScopeType.portfolio =>
      prevQuery.eq('user_id', authUser.uid).eq('household_id', householdId!),
    PocketsScopeType.household => prevQuery.eq('household_id', householdId!),
  };

  final prevRes = await prevQuery;
  final prevTransactions =
      (prevRes as List?)?.cast<Map<String, dynamic>>() ?? [];
  final totalSpentLastMonth = prevTransactions.fold<double>(
      0, (sum, t) => sum + ((t['amount_cents'] as num).toDouble() / 100.0));

  // 4. Process Data

  // Category Breakdown
  final categoryMap = <String, double>{};
  double totalSpent = 0;

  // Daily Spending
  final dailyMap = <int, double>{};

  for (final tx in transactions) {
    final amount = (tx['amount_cents'] as num).toDouble() / 100.0;
    final cat = tx['category'] as String;
    final date = DateTime.parse(tx['date']);

    totalSpent += amount;
    categoryMap.update(cat, (v) => v + amount, ifAbsent: () => amount);
    dailyMap.update(date.day, (v) => v + amount, ifAbsent: () => amount);
  }

  final categorySpending = categoryMap.entries.map((e) {
    return CategorySpend(
      category: e.key,
      amount: e.value,
      share: totalSpent > 0 ? e.value / totalSpent : 0,
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final dailySpending = dailyMap.entries.map((e) {
    return DailySpend(day: e.key, amount: e.value);
  }).toList()
    ..sort((a, b) => a.day.compareTo(b.day));

  // Projections
  final now = DateTime.now();
  final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  // If viewing a past month, use all days. If current month, use days passed so far.
  final isCurrentMonth =
      now.year == monthStart.year && now.month == monthStart.month;
  final daysPassed = isCurrentMonth ? now.day : daysInMonth;

  final dailyAverage = daysPassed > 0 ? totalSpent / daysPassed : 0.0;
  final projectedSpend = dailyAverage * daysInMonth;

  return PocketDetailsData(
    transactions: transactions,
    categorySpending: categorySpending,
    dailySpending: dailySpending,
    totalSpentLastMonth: totalSpentLastMonth,
    projectedSpend: projectedSpend,
    dailyAverage: dailyAverage,
  );
});
