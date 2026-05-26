import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
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
  final List<Map<String, dynamic>> aggregateTransactions;
  final List<String> linkedCategories;
  final List<CategorySpend> categorySpending;
  final List<DailySpend> dailySpending;
  final double totalSpentLastMonth;
  final double projectedSpend;
  final double dailyAverage;

  PocketDetailsData({
    required this.transactions,
    required this.aggregateTransactions,
    required this.linkedCategories,
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
  final periodSelection = ref.read(periodFilterProvider);
  final selectedCurrency =
      params.scopeParams.currency?.trim().isNotEmpty == true
          ? params.scopeParams.currency!.trim()
          : 'USD';
  final selectedCurrencies = ref.watch(
    homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
  );
  final shouldConvertCurrencies = (selectedCurrencies?.length ?? 0) > 1;
  final rateTable = ref.watch(currencyRateTableProvider).valueOrNull ??
      const CurrencyRateTable(
        baseCurrency: 'USD',
        rates: CurrencyRates.rates,
        isStale: true,
      );
  final end = params.scopeParams.periodMonth ??
      resolvePeriodDateRange(periodSelection).end;
  final monthStart = DateTime(end.year, end.month, 1);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

  // Previous month range
  final prevMonthStart = DateTime(monthStart.year, monthStart.month - 1, 1);
  final prevMonthEnd = monthStart;

  final pocketsState = ref.watch(pocketsProvider(params.scopeParams));
  final cachedCategories =
      pocketsState.envelopeCategories[params.pocketId] ?? const <String>[];
  final categories = cachedCategories.isNotEmpty
      ? cachedCategories
      : await _fetchPocketLinkedCategories(
          pocketId: params.pocketId,
          fallbackCategories: cachedCategories,
          canUseFallback: !pocketsState.isLoading,
        );

  if (categories.isEmpty) {
    return PocketDetailsData(
      transactions: [],
      aggregateTransactions: const [],
      linkedCategories: const <String>[],
      categorySpending: [],
      dailySpending: [],
      totalSpentLastMonth: 0,
      projectedSpend: 0,
      dailyAverage: 0,
    );
  }

  final scopeType = params.scopeParams.scope;
  final householdId = params.scopeParams.householdId;
  if (scopeType != PocketsScopeType.personal && householdId == null) {
    return PocketDetailsData(
      transactions: [],
      aggregateTransactions: const [],
      linkedCategories: const <String>[],
      categorySpending: [],
      dailySpending: [],
      totalSpentLastMonth: 0,
      projectedSpend: 0,
      dailyAverage: 0,
    );
  }

  final feedHouseholdId = switch (scopeType) {
    PocketsScopeType.personal => null,
    PocketsScopeType.portfolio => householdId,
    PocketsScopeType.household => householdId,
  };
  final monthEndInclusive = monthEnd.subtract(const Duration(days: 1));
  final previousMonthEndInclusive =
      prevMonthEnd.subtract(const Duration(days: 1));
  final transactionsFeedService = ref.read(transactionsFeedServiceProvider);

  final currentTransactions = await transactionsFeedService.fetchAllPages(
    TransactionsFeedQuery(
      userId: authUser.uid,
      householdId: feedHouseholdId,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      selectedCategory: null,
      selectedCategories: categories,
      selectedType: 'expense',
      searchQuery: '',
      startDate: monthStart,
      endDate: monthEndInclusive,
      pageSize: 200,
    ),
  );
  final scopedCurrentTransactions = scopeType == PocketsScopeType.portfolio
      ? currentTransactions
          .where((transaction) => transaction.userId == authUser.uid)
          .toList(growable: false)
      : currentTransactions;
  // CRITICAL: keep pocket details aligned with the main pockets page totals.
  // STRICT REQUIREMENT: exclude only income rows here so recurring expenses
  // remain visible and totals stay consistent with the primary pockets flow.
  final actualTransactions = scopedCurrentTransactions
      .where((expense) => (expense.type ?? 'expense').toLowerCase() != 'income')
      .toList(growable: false);

  final preferredTimezone =
      ref.read(analyticsProvider).contact?.preferredTimezone;
  final userNow = effectiveNow(preferredTimezone: preferredTimezone);
  // CRITICAL: mirror the main pockets calculation here.
  // STRICT REQUIREMENT: pocket details must include the same month-by-month
  // recurring projection as the pocket totals, or the detail list/insights
  // will disagree with the pocket card and users will think recurring
  // transactions are missing.
  final projectedTransactions = await loadProjectedPocketMonthExpenses(
    userId: authUser.uid,
    scope: scopeType,
    householdId: householdId,
    monthStart: monthStart,
    selectedCurrency: selectedCurrency,
    selectedCurrencies: selectedCurrencies,
    includeUpcomingRecurring: params.scopeParams.includeUpcomingRecurring,
    actualExpenses: actualTransactions,
  );
  final normalizedCategories =
      categories.map((category) => category.toLowerCase()).toSet();
  final filteredProjectedTransactions = projectedTransactions
      .where((expense) => normalizedCategories.contains(
            (expense.category ?? 'uncategorized').toLowerCase(),
          ))
      .toList(growable: false);
  // CRITICAL: keep the merged list aligned with the pocket's spent amount
  // calculation.
  // STRICT REQUIREMENT: do not remove projected recurring rows here. Removing
  // them reintroduces the classic bug where the pocket total includes recurring
  // spend but the details screen does not.
  final transactions = <ExpenseEntry>[
    ...actualTransactions,
    ...filteredProjectedTransactions,
  ]..sort((a, b) => b.date.compareTo(a.date));
  final aggregateTransactions = shouldConvertCurrencies
      ? convertTransactionsToCurrency(
          transactions,
          targetCurrency: selectedCurrency,
          rates: rateTable,
        )
      : transactions;
  final aggregateActualTransactions = shouldConvertCurrencies
      ? convertTransactionsToCurrency(
          actualTransactions,
          targetCurrency: selectedCurrency,
          rates: rateTable,
        )
      : actualTransactions;

  // 3. Fetch PREVIOUS month expenses (for comparison)
  final prevTransactions = await transactionsFeedService.fetchAllPages(
    TransactionsFeedQuery(
      userId: authUser.uid,
      householdId: feedHouseholdId,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      selectedCategory: null,
      selectedCategories: categories,
      selectedType: 'expense',
      searchQuery: '',
      startDate: prevMonthStart,
      endDate: previousMonthEndInclusive,
      pageSize: 200,
    ),
  );
  final scopedPrevTransactions = scopeType == PocketsScopeType.portfolio
      ? prevTransactions
          .where((transaction) => transaction.userId == authUser.uid)
          .toList(growable: false)
      : prevTransactions;
  final aggregatePrevTransactions = shouldConvertCurrencies
      ? convertTransactionsToCurrency(
          scopedPrevTransactions,
          targetCurrency: selectedCurrency,
          rates: rateTable,
        )
      : scopedPrevTransactions;
  final totalSpentLastMonth = aggregatePrevTransactions.fold<double>(
    0,
    (sum, transaction) {
      // CRITICAL: previous-month comparison must ignore recurring template rows
      // for the same reason as the current-month calculation.
      // STRICT REQUIREMENT: only posted expenses plus projected month rows
      // should affect pocket comparisons.
      if (transaction.isRecurring) {
        return sum;
      }
      if ((transaction.type ?? 'expense').toLowerCase() == 'income') {
        return sum;
      }
      return sum + transaction.amount;
    },
  );

  // 4. Process Data

  // Category Breakdown
  final categoryMap = <String, double>{};
  double totalSpent = 0;

  // Daily Spending
  final dailyMap = <int, double>{};

  for (final tx in aggregateTransactions) {
    final amount = tx.amount;
    final cat = tx.category ?? 'uncategorized';
    final date = DateTime(tx.date.year, tx.date.month, tx.date.day);

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
  final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  // If viewing a past month, use all days. If current month, use days passed so far.
  final isCurrentMonth =
      userNow.year == monthStart.year && userNow.month == monthStart.month;
  final daysPassed = isCurrentMonth ? userNow.day : daysInMonth;

  final actualSpent = aggregateActualTransactions.fold<double>(
    0,
    (sum, expense) => sum + expense.amount,
  );

  final dailyAverage = daysPassed > 0 ? actualSpent / daysPassed : 0.0;
  final projectedSpend = dailyAverage * daysInMonth;

  return PocketDetailsData(
    transactions: transactions.map((expense) => expense.toJson()).toList(),
    aggregateTransactions:
        aggregateTransactions.map((expense) => expense.toJson()).toList(),
    linkedCategories:
        categories.map((category) => category.toLowerCase()).toList(),
    categorySpending: categorySpending,
    dailySpending: dailySpending,
    totalSpentLastMonth: totalSpentLastMonth,
    projectedSpend: projectedSpend,
    dailyAverage: dailyAverage,
  );
});

Future<List<String>> _fetchPocketLinkedCategories({
  required String pocketId,
  required List<String> fallbackCategories,
  required bool canUseFallback,
}) async {
  try {
    final linksRes = await supabase
        .from('envelope_category_links')
        .select('category')
        .eq('envelope_id', pocketId);

    return ((linksRes as List?) ?? const [])
        .map((row) => (row as Map)['category']?.toString() ?? '')
        .map((category) => category.trim().toLowerCase())
        .where((category) => category.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    if (canUseFallback) {
      return fallbackCategories;
    }
    rethrow;
  }
}
