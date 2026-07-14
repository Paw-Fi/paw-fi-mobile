import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_rollover_breakdown.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final List<PocketRolloverHistoryMonth> rolloverHistory;
  final PocketRolloverBreakdown? rolloverBreakdown;

  PocketDetailsData({
    required this.transactions,
    required this.aggregateTransactions,
    required this.linkedCategories,
    required this.categorySpending,
    required this.dailySpending,
    required this.totalSpentLastMonth,
    required this.projectedSpend,
    required this.dailyAverage,
    required this.rolloverHistory,
    required this.rolloverBreakdown,
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
  final financialMonthStartDay =
      params.scopeParams.normalizedFinancialMonthStartDay;
  final monthStart = params.scopeParams.periodMonth != null
      ? financialCycleStartForDate(
          params.scopeParams.periodMonth!,
          startDay: financialMonthStartDay,
        )
      : resolvePeriodDateRange(
          periodSelection,
          financialMonthStartDay: financialMonthStartDay,
        ).start;
  final monthEnd = nextFinancialCycleStart(
    monthStart,
    startDay: financialMonthStartDay,
  );

  // Previous month range
  final prevMonthStart = previousFinancialCycleStart(
    monthStart,
    startDay: financialMonthStartDay,
  );
  final prevMonthEnd = monthStart;

  final pocketsState = ref.watch(pocketsProvider(params.scopeParams));
  final pocket = _findPocketEnvelope(pocketsState, params.pocketId);
  final shouldFetchRolloverBreakdown = pocket?.hasRolloverFields == true &&
      pocket?.rolloverGroupId?.trim().isNotEmpty == true;
  final rolloverBreakdown = shouldFetchRolloverBreakdown
      ? await _fetchPocketRolloverBreakdown(
          userId: authUser.uid,
          scopeType: params.scopeParams.scope,
          householdId: params.scopeParams.householdId,
          currency: selectedCurrency,
          rolloverGroupId: pocket?.rolloverGroupId,
          periodMonth: monthStart,
        )
      : null;
  final rolloverHistory = rolloverBreakdown?.monthlyHistory.isNotEmpty == true
      ? rolloverBreakdown!.monthlyHistory
      : shouldFetchRolloverBreakdown
          ? await _fetchPocketRolloverHistory(
              userId: authUser.uid,
              scopeType: params.scopeParams.scope,
              householdId: params.scopeParams.householdId,
              currency: selectedCurrency,
              rolloverGroupId: pocket?.rolloverGroupId,
              periodMonth: monthStart,
            )
          : const <PocketRolloverHistoryMonth>[];
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
      rolloverHistory: rolloverHistory,
      rolloverBreakdown: rolloverBreakdown,
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
      rolloverHistory: rolloverHistory,
      rolloverBreakdown: rolloverBreakdown,
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

  // 3. Fetch PREVIOUS month aggregate (for comparison)
  final double totalSpentLastMonth;
  if (scopeType == PocketsScopeType.portfolio) {
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
    final scopedPrevTransactions = prevTransactions
        .where((transaction) => transaction.userId == authUser.uid)
        .toList(growable: false);
    final aggregatePrevTransactions = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            scopedPrevTransactions,
            targetCurrency: selectedCurrency,
            rates: rateTable,
          )
        : scopedPrevTransactions;
    totalSpentLastMonth = aggregatePrevTransactions.fold<double>(
      0,
      (sum, transaction) {
        if (transaction.isRecurring) {
          return sum;
        }
        if ((transaction.type ?? 'expense').toLowerCase() == 'income') {
          return sum;
        }
        return sum + transaction.amount;
      },
    );
  } else {
    final previousMonthSummary = await transactionsFeedService.fetchSummary(
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
    final aggregatePreviousMonthSummary = shouldConvertCurrencies
        ? summarizeTransactionRollupsInCurrency(
              previousMonthSummary,
              targetCurrency: selectedCurrency,
              rates: rateTable,
            ) ??
            previousMonthSummary
        : previousMonthSummary;
    totalSpentLastMonth = aggregatePreviousMonthSummary.expenseTotal;
  }

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
  final daysInMonth = monthEnd.difference(monthStart).inDays;
  final currentCycleStart = financialCycleStartForDate(
    userNow,
    startDay: financialMonthStartDay,
  );
  final isCurrentMonth = currentCycleStart == monthStart;
  final daysPassed = isCurrentMonth
      ? DateTime(userNow.year, userNow.month, userNow.day)
              .difference(monthStart)
              .inDays +
          1
      : daysInMonth;

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
    rolloverHistory: rolloverHistory,
    rolloverBreakdown: rolloverBreakdown,
  );
});

PocketEnvelope? _findPocketEnvelope(PocketsState state, String pocketId) {
  for (final pocket in [...state.editing, ...state.saved]) {
    if (pocket.id == pocketId) return pocket;
  }
  return null;
}

Future<List<PocketRolloverHistoryMonth>> _fetchPocketRolloverHistory({
  required String userId,
  required PocketsScopeType scopeType,
  required String? householdId,
  required String currency,
  required String? rolloverGroupId,
  required DateTime periodMonth,
}) async {
  if (rolloverGroupId == null || rolloverGroupId.trim().isEmpty) {
    return const <PocketRolloverHistoryMonth>[];
  }

  final scope = switch (scopeType) {
    PocketsScopeType.personal => 'personal',
    PocketsScopeType.portfolio => 'portfolio',
    PocketsScopeType.household => 'household',
  };
  final budgetMonth = DateTime(periodMonth.year, periodMonth.month, 1)
      .toIso8601String()
      .substring(0, 10);
  Object? response;
  try {
    final params = <String, dynamic>{
      'p_user_id': userId,
      'p_scope': scope,
      'p_household_id': householdId,
      'p_currency': currency,
      'p_rollover_group_id': rolloverGroupId,
      'p_budget_month': budgetMonth,
      'p_limit_months': 12,
    };
    try {
      response = await supabase.rpc(
        'get_pocket_rollover_history_v2',
        params: params,
      );
    } on PostgrestException catch (error) {
      if (error.code != '42883' &&
          !error.message.contains('get_pocket_rollover_history_v2')) {
        rethrow;
      }
      response = await supabase.rpc(
        'get_pocket_rollover_history_v1',
        params: <String, dynamic>{
          ...params,
          'p_period_month': periodMonth.toIso8601String().substring(0, 10),
        }..remove('p_budget_month'),
      );
    }
  } catch (error, stackTrace) {
    if (foundation.kDebugMode) {
      foundation.debugPrint(
        '[PocketDetails] Failed to load rollover history: $error\n$stackTrace',
      );
    }
    return const <PocketRolloverHistoryMonth>[];
  }

  return ((response as List?) ?? const []).whereType<Map>().map((row) {
    final data = Map<String, dynamic>.from(row);
    return PocketRolloverHistoryMonth(
      periodMonth: DateTime.parse(data['period_month'].toString()),
      baseBudgetCents: (data['base_budget_cents'] as num?)?.toInt() ?? 0,
      rolloverFromPreviousCents:
          (data['rollover_from_previous_cents'] as num?)?.toInt() ?? 0,
      openingRolloverCents:
          (data['opening_rollover_cents'] as num?)?.toInt() ?? 0,
      availableBudgetCents:
          (data['available_budget_cents'] as num?)?.toInt() ?? 0,
      spentCents: (data['spent_cents'] as num?)?.toInt() ?? 0,
      remainingCents: (data['remaining_cents'] as num?)?.toInt() ?? 0,
      carryToNextCents: (data['carry_to_next_cents'] as num?)?.toInt() ??
          (data['remaining_cents'] as num?)?.toInt() ??
          0,
      rolloverEnabled: data['rollover_enabled'] == true,
      rolloverNegative: data['rollover_negative'] == true,
      rolloverCapCents: (data['rollover_cap_cents'] as num?)?.toInt(),
      capAppliedCents: (data['cap_applied_cents'] as num?)?.toInt() ?? 0,
      negativeDroppedCents:
          (data['negative_dropped_cents'] as num?)?.toInt() ?? 0,
    );
  }).toList(growable: false);
}

Future<PocketRolloverBreakdown?> _fetchPocketRolloverBreakdown({
  required String userId,
  required PocketsScopeType scopeType,
  required String? householdId,
  required String currency,
  required String? rolloverGroupId,
  required DateTime periodMonth,
}) async {
  if (rolloverGroupId == null || rolloverGroupId.trim().isEmpty) {
    return null;
  }

  try {
    final params = <String, dynamic>{
      'p_user_id': userId,
      'p_scope': switch (scopeType) {
        PocketsScopeType.personal => 'personal',
        PocketsScopeType.portfolio => 'portfolio',
        PocketsScopeType.household => 'household',
      },
      'p_household_id': householdId,
      'p_currency': currency,
      'p_rollover_group_id': rolloverGroupId,
      'p_budget_month': DateTime(periodMonth.year, periodMonth.month, 1)
          .toIso8601String()
          .substring(0, 10),
    };
    Object? response;
    try {
      response = await supabase.rpc(
        'get_pocket_rollover_breakdown_v2',
        params: params,
      );
    } on PostgrestException catch (error) {
      if (error.code != '42883' &&
          !error.message.contains('get_pocket_rollover_breakdown_v2')) {
        rethrow;
      }
      response = await supabase.rpc(
        'get_pocket_rollover_breakdown_v1',
        params: <String, dynamic>{
          ...params,
          'p_period_month': periodMonth.toIso8601String().substring(0, 10),
        }..remove('p_budget_month'),
      );
    }
    if (response is! Map) return null;
    return PocketRolloverBreakdown.fromJson(
      Map<String, dynamic>.from(response),
    );
  } catch (error, stackTrace) {
    if (foundation.kDebugMode) {
      foundation.debugPrint(
        '[PocketDetails] Failed to load rollover breakdown: $error\n$stackTrace',
      );
    }
    return null;
  }
}

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
