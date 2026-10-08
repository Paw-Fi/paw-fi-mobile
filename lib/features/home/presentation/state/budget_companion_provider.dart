import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/async_value_extensions.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/spending_daily_overview_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';

import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

enum BudgetCompanionReaction {
  happy,
  encouraging,
  concerned,
  overBudget,
  planning
}

/// Presentation of canonical totals; no persisted or independently fetched state.
class BudgetCompanionSummary {
  const BudgetCompanionSummary({required this.spent, this.budget});

  final double spent;
  final double? budget;

  bool get hasBudget => budget != null && budget!.isFinite && budget! > 0;
  double? get progress => hasBudget ? spent / budget! : null;
  double get barProgress => (progress ?? 0).clamp(0.0, 1.0);
  double? get remaining => hasBudget ? budget! - spent : null;

  BudgetCompanionReaction get reaction {
    final ratio = progress;
    if (ratio == null) return BudgetCompanionReaction.planning;
    if (ratio > 1) return BudgetCompanionReaction.overBudget;
    if (ratio >= .8) return BudgetCompanionReaction.concerned;
    if (ratio >= .6) return BudgetCompanionReaction.encouraging;
    return BudgetCompanionReaction.happy;
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetCompanionSummary &&
      other.spent == spent &&
      other.budget == budget;

  @override
  int get hashCode => Object.hash(spent, budget);
}

class BudgetCompanionCategory {
  const BudgetCompanionCategory(this.category, this.amount, this.heightFactor);
  final String category;
  final double amount;
  final double heightFactor;
}

List<BudgetCompanionCategory> budgetCompanionCategories(
    Map<String, double> totals) {
  final sorted = totals.entries
      .where((item) => item.value.isFinite && item.value > 0)
      .toList()
    ..sort((a, b) {
      final byAmount = b.value.compareTo(a.value);
      return byAmount == 0 ? a.key.compareTo(b.key) : byAmount;
    });
  if (sorted.isEmpty) return const [];
  return List.unmodifiable(sorted.map((item) => BudgetCompanionCategory(
        item.key,
        item.value,
        (item.value / sorted.first.value).clamp(.08, 1.0),
      )));
}

AsyncValue<BudgetCompanionSummary> budgetCompanionPocketsSummary(
    PocketsState state) {
  if (!state.hasDisplayData) {
    return state.error == null
        ? const AsyncLoading()
        : AsyncError(StateError(state.error!), StackTrace.current);
  }
  if (!state.totalSpent.isFinite || !state.totalBudget.isFinite) {
    return AsyncError(StateError('Invalid budget totals'), StackTrace.current);
  }
  final summary = AsyncData(BudgetCompanionSummary(
    spent: state.totalSpent,
    budget: state.totalBudget,
  ));
  return state.isLoading
      ? const AsyncLoading<BudgetCompanionSummary>().copyWithPrevious(summary)
      : summary;
}

final budgetCompanionMonthlySummaryProvider = Provider.autoDispose
    .family<AsyncValue<BudgetCompanionSummary>, PocketsScopeParams>(
        (ref, params) {
  if (ref.watch(previewModeProvider).isActive) {
    // Match the existing Pocket preview totals without creating a live notifier.
    final pockets = PreviewMockData.pockets;

    return AsyncData(BudgetCompanionSummary(
      spent: pockets.fold<double>(0, (sum, pocket) => sum + pocket.spent),
      budget: pockets.fold<double>(
          0, (sum, pocket) => sum + pocket.budgetAmountCents / 100),
    ));
  }
  final pockets = ref.watch(pocketsProvider(params));

  return budgetCompanionPocketsSummary(pockets);
});

/// Identical calendar family keys to the existing lazy dashboard cards. Derived
/// summaries are cached by Riverpod and rebuilt only when their inputs change.
final budgetCompanionPeriodSummaryProvider = Provider.autoDispose
    .family<AsyncValue<TransactionsFeedSummary>, DashboardScopeQuery>(
        (ref, query) {
  final actual = ref.watch(spendingScopedActualTransactionsProvider(query));

  if (!actual.hasValue) {
    return actual.hasError
        ? AsyncError(actual.error!, actual.stackTrace ?? StackTrace.current)
        : const AsyncLoading();
  }
  final isPreview = ref.watch(previewModeProvider).isActive;
  final includeRecurring = ref.watch(includeUpcomingRecurringInPocketsProvider);
  final resolution = isPreview
      ? const RecurringOccurrenceProjectionResolution()
      : ref.watch(recurringOccurrenceProjectionResolutionProvider(
          RecurringOccurrenceProjectionResolutionQuery(
            userId: query.userId,
            householdId: query.householdId,
            startDate: query.startDate!,
            endDate: query.endDate!,
          ),
        ));
  final actualExpenses = actual.valueOrNull!;
  var projected = const <ExpenseEntry>[];
  if (includeRecurring) {
    final recurring = isPreview
        ? RecurringTransactionsState(
            data: AsyncData(PreviewMockData.recurringTransactions),
            hasLoadedOnce: true,
          )
        : ref.watch(recurringTransactionsProvider(query.householdId));
    if (!recurring.data.hasValue) {
      return recurring.data.hasError
          ? AsyncError(recurring.data.error!,
              recurring.data.stackTrace ?? StackTrace.current)
          : const AsyncLoading();
    }
    projected = dedupeProjectedRecurringExpenseEntries(
      projectedExpenses: projectRecurringTransactionsAsExpenseEntries(
        // Keep the eligibility default used by loadProjectedPocketMonthExpenses;
        // this card must not independently enable unconfirmed forecasts.
        recurringTransactions: recurring.data.valueOrNull!
            .where((item) => item.type.toLowerCase() == 'expense')
            .toList(growable: false),
        rangeStart: query.startDate!,
        rangeEnd: query.endDate!,
        selectedCurrency: query.selectedCurrency,
        selectedCurrencies: query.normalizedCurrencies,
      ),
      actualExpenses: [...actualExpenses, ...resolution.suppressionEntries],
    );
  }
  final currency = ref.watch(selectedHomeCurrencyCodeProvider);
  final needsRates = [...actualExpenses, ...projected].any((entry) =>
      entry.currency?.trim().isNotEmpty == true &&
      entry.currency!.trim().toUpperCase() != currency);
  final rates = needsRates && !isPreview
      ? ref.watch(currencyRateTableProvider).valueOrNull ??
          const CurrencyRateTable(
              baseCurrency: 'USD', rates: CurrencyRates.rates, isStale: true)
      : const CurrencyRateTable(
          baseCurrency: 'USD', rates: CurrencyRates.rates, isStale: true);
  try {
    return actual.whenDataWithPrevious((_) => summarizeTransactionsInCurrency(
          [...actualExpenses, ...projected],
          targetCurrency: currency,
          rates: rates,
        ));
  } catch (error, stack) {
    return AsyncError(error, stack);
  }
});

class BudgetCompanionRequest {
  const BudgetCompanionRequest({
    required this.query,
    required this.pocketsScope,
    required this.mode,
    required this.currency,
  });
  final DashboardScopeQuery query;
  final PocketsScopeParams pocketsScope;
  final HomePeriodMode mode;
  final String currency;

  @override
  bool operator ==(Object other) =>
      other is BudgetCompanionRequest &&
      other.query == query &&
      other.pocketsScope == pocketsScope &&
      other.mode == mode &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(query, pocketsScope, mode, currency);
}

class BudgetCompanionData {
  const BudgetCompanionData({
    required this.summary,
    required this.categories,
    this.isRefreshing = false,
  });
  final AsyncValue<BudgetCompanionSummary> summary;
  final AsyncValue<List<BudgetCompanionCategory>> categories;
  final bool isRefreshing;

  bool get isSummaryRefreshing => summary.isLoading && summary.hasValue;
}

final budgetCompanionRequestProvider = Provider<BudgetCompanionRequest?>((ref) {
  final authenticatedUserId =
      ref.watch(authProvider.select((user) => user.uid));
  final isPreview = ref.watch(previewModeProvider).isActive;
  final userId = isPreview
      ? PreviewMockData.contact.userId ?? 'preview-user'
      : authenticatedUserId;
  if (userId.isEmpty) {
    return null;
  }
  if (!ref.watch(financialMonthStartDayStateProvider).hasValue) {
    return null;
  }
  final selection = ref.watch(homePeriodSelectionProvider(userId));
  if (!selection.isHydrated) return null;
  final range = ref.watch(homePeriodDateRangeProvider(userId));
  final financialStartDay = ref.watch(homePeriodFinancialMonthStartDayProvider);
  final scope = ref.watch(householdScopeProvider);
  // An unresolved Space selection must not briefly publish Personal totals.
  if (scope.viewMode == ViewMode.household && !scope.hasSelectedHousehold) {
    return null;
  }
  final filter = ref.watch(homeFilterProvider);
  final currency = ref.watch(selectedHomeCurrencyCodeProvider);
  final includeRecurring = ref.watch(includeUpcomingRecurringInPocketsProvider);
  final scopeType = switch (scope.activeAccountType) {
    ActiveWalletType.personal => PocketsScopeType.personal,
    ActiveWalletType.portfolio => PocketsScopeType.portfolio,
    ActiveWalletType.household => PocketsScopeType.household,
  };
  final householdId = scopeType == PocketsScopeType.personal
      ? null
      : scope.activeAccountHouseholdId;

  return BudgetCompanionRequest(
    query: DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: filter.selectedCurrency,
      selectedCurrencies: filter.normalizedSelectedCurrencies,
      startDate: range.start,
      endDate: range.end,
    ),
    pocketsScope: PocketsScopeParams(
      scope: scopeType,
      householdId: householdId,
      periodMonth: selection.selectedDate,
      currency: currency,
      selectedCurrencies: filter.normalizedSelectedCurrencies,
      financialMonthStartDay: financialStartDay,
      isBootstrapCurrency: false,
      includeUpcomingRecurring: includeRecurring,
    ),
    mode: selection.mode,
    currency: currency,
  );
});

final budgetCompanionDataProvider =
    Provider.autoDispose<BudgetCompanionData>((ref) {
  final request = ref.watch(budgetCompanionRequestProvider);
  if (request == null) {
    final financialDay = ref.watch(financialMonthStartDayStateProvider);
    if (financialDay.hasError && !financialDay.hasValue) {
      return BudgetCompanionData(
        summary: AsyncError(
            financialDay.error!, financialDay.stackTrace ?? StackTrace.current),
        categories: AsyncError(
            financialDay.error!, financialDay.stackTrace ?? StackTrace.current),
      );
    }

    return const BudgetCompanionData(
        summary: AsyncLoading(), categories: AsyncLoading());
  }
  final period = ref.watch(budgetCompanionPeriodSummaryProvider(request.query));
  final categories =
      period.whenDataWithPrevious((summary) => budgetCompanionCategories({
            for (final item in summary.categorySummaries)
              item.category: item.amount,
          }));
  if (request.mode == HomePeriodMode.daily) {
    return BudgetCompanionData(
      summary: period.whenDataWithPrevious(
          (value) => BudgetCompanionSummary(spent: value.expenseTotal)),
      categories: categories,
      isRefreshing: period.isLoading && period.hasValue,
    );
  }
  final current =
      ref.watch(budgetCompanionMonthlySummaryProvider(request.pocketsScope));

  return BudgetCompanionData(
    summary: current,
    categories: categories,
    isRefreshing: (current.isLoading && current.hasValue) ||
        (categories.isLoading && categories.hasValue),
  );
});
