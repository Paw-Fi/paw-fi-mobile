import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

/// Identifier for home/household cards that support their own date filters
enum HomeCardFilterId {
  spending,
  netCashflow,
  recentTransactions,
  spendingBreakdown,
  householdSpending,
  householdBudgetOverview,
  householdRecentTransactions,
  householdSpendingBreakdown,
  householdMemberSpending,
}

/// Per-card date filter state (date range only; currency remains global)
class CardDateFilterState {
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const CardDateFilterState({
    this.dateRangeFilter = DateRangeFilter.thisMonth,
    this.customStartDate,
    this.customEndDate,
  });

  CardDateFilterState copyWith({
    DateRangeFilter? dateRangeFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearCustom = false,
  }) {
    return CardDateFilterState(
      dateRangeFilter: dateRangeFilter ?? this.dateRangeFilter,
      customStartDate: clearCustom ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearCustom ? null : (customEndDate ?? this.customEndDate),
    );
  }
}

/// Notifier for per-card date filters
class CardDateFilterNotifier extends StateNotifier<CardDateFilterState> {
  CardDateFilterNotifier() : super(const CardDateFilterState());

  void setFilter(DateRangeFilter filter, {DateTime? startDate, DateTime? endDate}) {
    state = state.copyWith(
      dateRangeFilter: filter,
      customStartDate: startDate,
      customEndDate: endDate,
      clearCustom: filter != DateRangeFilter.custom,
    );
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      dateRangeFilter: DateRangeFilter.custom,
      customStartDate: start,
      customEndDate: end,
      clearCustom: false,
    );
  }
}

/// Provider family for per-card date filter state
final cardDateFilterProvider = StateNotifierProvider.family<
    CardDateFilterNotifier, CardDateFilterState, HomeCardFilterId>(
  (ref, _) => CardDateFilterNotifier(),
);
