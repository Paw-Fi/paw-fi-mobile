import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

/// Local filter state for home page only (currency)
class HomeFilterState {
  final String? selectedCurrency; // null = "All Currencies"
  final bool hasExplicitCurrency;

  HomeFilterState({
    this.selectedCurrency,
    this.hasExplicitCurrency = false,
  });

  HomeFilterState copyWith({
    String? selectedCurrency,
    bool? hasExplicitCurrency,
    bool clearCurrency = false,
  }) {
    return HomeFilterState(
      selectedCurrency:
          clearCurrency ? null : (selectedCurrency ?? this.selectedCurrency),
      hasExplicitCurrency: clearCurrency
          ? false
          : (hasExplicitCurrency ?? this.hasExplicitCurrency),
    );
  }
}

/// Notifier for home page filter
class HomeFilterNotifier extends StateNotifier<HomeFilterState> {
  HomeFilterNotifier() : super(HomeFilterState());

  void setSelectedCurrency(String? currency) {
    state = state.copyWith(
      selectedCurrency: currency,
      hasExplicitCurrency: currency != null,
      clearCurrency: currency == null,
    );
  }

  void bootstrapSelectedCurrency(String currency) {
    state = state.copyWith(
      selectedCurrency: currency,
      hasExplicitCurrency: false,
    );
  }
}

/// Provider for home page filter state (local to home page)
final homeFilterProvider =
    StateNotifierProvider<HomeFilterNotifier, HomeFilterState>((ref) {
  return HomeFilterNotifier();
});

final selectedHomeCurrencyCodeProvider = Provider<String>((ref) {
  final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency;
  final normalized = selectedCurrency?.trim().toUpperCase();
  if (normalized != null && normalized.isNotEmpty) {
    return normalized;
  }

  final preferredCurrency = ref.watch(analyticsProvider).preferredCurrency;
  final preferredNormalized = preferredCurrency?.trim().toUpperCase();
  if (preferredNormalized != null && preferredNormalized.isNotEmpty) {
    return preferredNormalized;
  }

  return 'USD';
});

/// Filtered expenses for home page based on local filter (date + currency + view mode)
final homeFilteredExpensesProvider = Provider<List<ExpenseEntry>>((ref) {
  final analyticsData = ref.watch(analyticsProvider);
  final filterState = ref.watch(homeFilterProvider);
  final scope = ref.watch(householdScopeProvider);
  final selectedHouseholdId = scope.selectedHouseholdId;

  // Get all expenses from provider
  final allExpenses = _resolveScopeAwareExpenses(ref, analyticsData, scope);

  final selectedCurrency = filterState.selectedCurrency?.toUpperCase();

  // Filter expenses locally by currency AND view mode
  final filtered = allExpenses
      .where((expense) {
        if (expense.isRecurring) return false;
        final expCurrency = (expense.currency ?? '').toUpperCase();
        final currencyOk = selectedCurrency == null ||
            expCurrency.isEmpty ||
            expCurrency == selectedCurrency;

        final activeOk = switch (scope.activeAccountType) {
          ActiveWalletType.personal => expense.householdId == null ||
              (expense.householdId?.isEmpty ?? false),
          ActiveWalletType.portfolio =>
            scope.activeAccountHouseholdId != null &&
                expense.householdId == scope.activeAccountHouseholdId,
          ActiveWalletType.household => selectedHouseholdId != null &&
              expense.householdId == selectedHouseholdId,
        };

        return currencyOk && activeOk;
      })
      // Treat incomes separately; filteredExpenses represents spending only for UI cards
      .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
      .toList();
  return filtered;
});

/// Filtered transactions (both expense and income) for home page based on local filter
final homeFilteredTransactionsProvider = Provider<List<ExpenseEntry>>((ref) {
  final analyticsData = ref.watch(analyticsProvider);
  final filterState = ref.watch(homeFilterProvider);
  final scope = ref.watch(householdScopeProvider);
  final selectedHouseholdId = scope.selectedHouseholdId;

  final all = _resolveScopeAwareExpenses(ref, analyticsData, scope);
  final selectedCurrency = filterState.selectedCurrency?.toUpperCase();

  return all.where((tx) {
    if (tx.isRecurring) return false;
    final txCurrency = (tx.currency ?? '').toUpperCase();
    final currencyOk = selectedCurrency == null ||
        txCurrency.isEmpty ||
        txCurrency == selectedCurrency;
    final activeOk = switch (scope.activeAccountType) {
      ActiveWalletType.personal =>
        tx.householdId == null || (tx.householdId?.isEmpty ?? false),
      ActiveWalletType.portfolio => scope.activeAccountHouseholdId != null &&
          tx.householdId == scope.activeAccountHouseholdId,
      ActiveWalletType.household =>
        selectedHouseholdId != null && tx.householdId == selectedHouseholdId,
    };
    return currencyOk && activeOk;
  }).toList();
});

/// Filtered budgets for home page based on local filter (date + currency)
/// Uses most recent budget as fallback if no budget exists for the filtered date range
final homeFilteredBudgetsProvider = Provider<List<DailyBudgetEntry>>((ref) {
  final analyticsData = ref.watch(analyticsProvider);
  final filterState = ref.watch(homeFilterProvider);

  // Get all budgets from provider (sorted by date ascending)
  final allBudgets = analyticsData.allBudgets;

  // If no budgets at all, return empty
  if (allBudgets.isEmpty) {
    return [];
  }

  final selectedCurrency = filterState.selectedCurrency?.toUpperCase();

  // Filter budgets by currency (all-time)
  return allBudgets.where((budget) {
    return selectedCurrency == null ||
        (budget.currency?.toUpperCase() == selectedCurrency);
  }).toList();
});

/// Unique list of currencies present in expenses/budgets (uppercased)
final availableCurrenciesProvider = Provider<List<String>>((ref) {
  final data = ref.watch(analyticsProvider);
  final set = <String>{};

  for (final e in data.allExpenses) {
    final c = e.currency?.toUpperCase();
    if (c != null && c.isNotEmpty) set.add(c);
  }

  for (final b in data.allBudgets) {
    final c = b.currency?.toUpperCase();
    if (c != null && c.isNotEmpty) set.add(c);
  }

  final list = set.toList()..sort();
  return list;
});

/// Per-currency summaries across all time
final currencySummariesProvider = Provider<List<CurrencySummary>>((ref) {
  final data = ref.watch(analyticsProvider);
  final scope = ref.watch(householdScopeProvider);
  final scopedExpenses = _resolveScopeAwareExpenses(ref, data, scope);

  String? normalizeHouseholdId(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool matchesScope(String? householdId) {
    final normalizedId = normalizeHouseholdId(householdId);
    switch (scope.activeAccountType) {
      case ActiveWalletType.personal:
        // Personal view should only include personal (non-household) entries.
        return normalizedId == null;
      case ActiveWalletType.household:
      case ActiveWalletType.portfolio:
        final targetId = scope.activeAccountHouseholdId;
        if (targetId == null || targetId.isEmpty) return false;
        return normalizedId == targetId;
    }
  }

  final byCurExpenses = <String, double>{};
  final byCurIncome = <String, double>{};
  final byCurBudgets = <String, double>{};
  final byCurCount = <String, int>{};

  for (final e in scopedExpenses) {
    if (!matchesScope(e.householdId)) continue;
    final currencyCode = (e.currency ?? '').toUpperCase();
    if (currencyCode.isEmpty) continue;

    final type = (e.type ?? 'expense').toLowerCase();
    if (type == 'income') {
      byCurIncome[currencyCode] =
          (byCurIncome[currencyCode] ?? 0) + e.amount.abs();
    } else {
      byCurExpenses[currencyCode] =
          (byCurExpenses[currencyCode] ?? 0) + e.amount.abs();
    }
    byCurCount[currencyCode] = (byCurCount[currencyCode] ?? 0) + 1;
  }

  final shouldIncludeBudgets =
      scope.activeAccountType == ActiveWalletType.personal;
  if (shouldIncludeBudgets) {
    for (final b in data.allBudgets) {
      final currencyCode = (b.currency ?? '').toUpperCase();
      if (currencyCode.isEmpty) continue;

      byCurBudgets[currencyCode] = (byCurBudgets[currencyCode] ?? 0) + b.amount;
    }
  }

  final codes = {
    ...byCurExpenses.keys,
    ...byCurBudgets.keys,
    ...byCurIncome.keys,
  }.toList()
    ..sort();

  return codes
      .map(
        (code) => CurrencySummary(
          currencyCode: code,
          totalExpenses: byCurExpenses[code] ?? 0,
          totalIncome: byCurIncome[code] ?? 0,
          totalBudget: byCurBudgets[code] ?? 0,
          transactionCount: byCurCount[code] ?? 0,
        ),
      )
      .toList();
});

List<ExpenseEntry> _resolveScopeAwareExpenses(
  Ref ref,
  AnalyticsData analyticsData,
  HouseholdScope scope,
) {
  if (scope.activeAccountType == ActiveWalletType.personal) {
    return analyticsData.allExpenses;
  }

  final activeHouseholdId = scope.activeAccountHouseholdId;
  if (activeHouseholdId == null || activeHouseholdId.isEmpty) {
    return analyticsData.allExpenses;
  }

  final optimistic = ref.watch(
    householdOptimisticExpensesProvider.select(
      (state) => state[activeHouseholdId] ?? const <ExpenseEntry>[],
    ),
  );

  if (optimistic.isEmpty) {
    return analyticsData.allExpenses;
  }

  return mergeHouseholdExpenses(analyticsData.allExpenses, optimistic);
}
