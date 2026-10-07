import 'package:flutter/foundation.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

import 'dashboard_config.dart';

const personalDashboardDefaults = <DashboardWidgetConfig>[
  DashboardWidgetConfig(
      id: 'categories', type: DashboardWidgetType.recentTransactions, order: 0),
  DashboardWidgetConfig(
      id: 'calendar',
      type: DashboardWidgetType.financialCalendar,
      order: 1,
      viewMode: DashboardWidgetViewMode.full),
  DashboardWidgetConfig(
      id: 'upcoming_transactions',
      type: DashboardWidgetType.upcomingTransactions,
      order: 2),
  DashboardWidgetConfig(
      id: 'spending_chart',
      type: DashboardWidgetType.spendingBreakdownChart,
      order: 3),
  DashboardWidgetConfig(
      id: 'where_the_money_went',
      type: DashboardWidgetType.whereTheMoneyWent,
      order: 4),
];

const householdDashboardDefaults = <DashboardWidgetConfig>[
  DashboardWidgetConfig(
      id: 'settlement',
      type: DashboardWidgetType.householdSettlement,
      order: 0),
  DashboardWidgetConfig(
      id: 'member_spending',
      type: DashboardWidgetType.householdMemberSpending,
      order: 1),
  DashboardWidgetConfig(
      id: 'categories',
      type: DashboardWidgetType.householdRecentTransactions,
      order: 2),
  DashboardWidgetConfig(
      id: 'budget_overview',
      type: DashboardWidgetType.householdBudgetOverview,
      order: 3),
  DashboardWidgetConfig(
      id: 'fairness', type: DashboardWidgetType.householdFairness, order: 4),
  DashboardWidgetConfig(
      id: 'calendar',
      type: DashboardWidgetType.householdFinancialCalendar,
      order: 5,
      viewMode: DashboardWidgetViewMode.full),
  DashboardWidgetConfig(
      id: 'household_upcoming_transactions',
      type: DashboardWidgetType.householdUpcomingTransactions,
      order: 6),
  DashboardWidgetConfig(
      id: 'spending_chart',
      type: DashboardWidgetType.householdSpendingBreakdownChart,
      order: 7),
  DashboardWidgetConfig(
      id: 'where_the_money_went',
      type: DashboardWidgetType.householdWhereTheMoneyWent,
      order: 8),
];

// Keep retired enum names readable in persisted layouts, but never render or
// reinsert their SpendingCard or Net Cashflow slots.
bool isRetiredDashboardWidget(DashboardWidgetType type) =>
    type == DashboardWidgetType.spendingSummary ||
    type == DashboardWidgetType.netCashflow ||
    type == DashboardWidgetType.householdSpentByYou;

const _legacyPersonalOrder = [
  DashboardWidgetType.spendingSummary,
  DashboardWidgetType.netCashflow,
  DashboardWidgetType.financialCalendar,
  DashboardWidgetType.recentTransactions,
  DashboardWidgetType.upcomingTransactions,
  DashboardWidgetType.spendingBreakdownChart,
  DashboardWidgetType.whereTheMoneyWent,
];

const _legacyHouseholdOrder = [
  DashboardWidgetType.householdSettlement,
  DashboardWidgetType.householdMemberSpending,
  DashboardWidgetType.householdSpentByYou,
  DashboardWidgetType.householdFinancialCalendar,
  DashboardWidgetType.householdBudgetOverview,
  DashboardWidgetType.householdFairness,
  DashboardWidgetType.householdRecentTransactions,
  DashboardWidgetType.householdUpcomingTransactions,
  DashboardWidgetType.householdSpendingBreakdownChart,
  DashboardWidgetType.householdWhereTheMoneyWent,
];

const _originalHouseholdOrder = [
  DashboardWidgetType.householdSpentByYou,
  DashboardWidgetType.householdFinancialCalendar,
  DashboardWidgetType.householdBudgetOverview,
  DashboardWidgetType.householdFairness,
  DashboardWidgetType.householdSettlement,
  DashboardWidgetType.householdMemberSpending,
  DashboardWidgetType.householdRecentTransactions,
  DashboardWidgetType.householdUpcomingTransactions,
  DashboardWidgetType.householdSpendingBreakdownChart,
  DashboardWidgetType.householdWhereTheMoneyWent,
];

bool _matchesLegacyDefaults(
    List<DashboardWidgetConfig> configs, bool isHousehold) {
  for (var index = 0; index < configs.length; index++) {
    final config = configs[index];
    if (config.order != index ||
        !config.isVisible ||
        config.dateRange != DateRangeFilter.thisMonth ||
        config.viewMode != DashboardWidgetViewMode.wide ||
        config.customStartDate != null ||
        config.customEndDate != null) {
      return false;
    }
  }

  final orders = isHousehold
      ? [_legacyHouseholdOrder, _originalHouseholdOrder]
      : [_legacyPersonalOrder];
  final upcoming = isHousehold
      ? DashboardWidgetType.householdUpcomingTransactions
      : DashboardWidgetType.upcomingTransactions;
  final where = isHousehold
      ? DashboardWidgetType.householdWhereTheMoneyWent
      : DashboardWidgetType.whereTheMoneyWent;
  final types = configs.map((config) => config.type).toList();
  // Historical defaults predate Where the Money Went and Upcoming. Accept
  // only these known omissions, never arbitrary subsets of a saved layout.
  for (final order in orders) {
    for (final includeUpcoming in [false, true]) {
      for (final includeWhere in [false, true]) {
        final candidate = order
            .where((type) =>
                (includeUpcoming || type != upcoming) &&
                (includeWhere || type != where))
            .toList();
        if (listEquals(types, candidate)) return true;
      }
    }
  }
  return false;
}

List<DashboardWidgetConfig> resolveDashboardLayout(
  List<DashboardWidgetConfig>? saved, {
  required bool isHousehold,
  required bool isCustomized,
}) {
  final defaults =
      isHousehold ? householdDashboardDefaults : personalDashboardDefaults;
  if (saved == null || saved.isEmpty) return List.of(defaults);

  final sorted = List<DashboardWidgetConfig>.of(saved)
    ..sort((a, b) => a.order.compareTo(b.order));
  final updateDefaults =
      !isCustomized && _matchesLegacyDefaults(sorted, isHousehold);
  final result =
      sorted.where((config) => !isRetiredDashboardWidget(config.type)).toList();
  final calendar = isHousehold
      ? DashboardWidgetType.householdFinancialCalendar
      : DashboardWidgetType.financialCalendar;
  final recent = isHousehold
      ? DashboardWidgetType.householdRecentTransactions
      : DashboardWidgetType.recentTransactions;
  final upcoming = isHousehold
      ? DashboardWidgetType.householdUpcomingTransactions
      : DashboardWidgetType.upcomingTransactions;

  // Preserve existing choices and relative order. Newly introduced slots use
  // the current default options; Upcoming keeps its existing insertion rule.
  for (final config in defaults) {
    if (result.any((item) => item.type == config.type)) continue;
    if (config.type == upcoming) {
      final recentIndex = result.indexWhere((item) => item.type == recent);
      result.insert(recentIndex < 0 ? result.length : recentIndex + 1, config);
    } else {
      result.add(config);
    }
  }
  if (updateDefaults) {
    final calendarIndex =
        result.indexWhere((config) => config.type == calendar);
    final recentIndex = result.indexWhere((config) => config.type == recent);
    final calendarConfig = result[calendarIndex];
    result[calendarIndex] = result[recentIndex];
    result[recentIndex] =
        calendarConfig.copyWith(viewMode: DashboardWidgetViewMode.full);
  }

  return result
      .asMap()
      .entries
      .map((entry) => entry.value.copyWith(order: entry.key))
      .toList(growable: false);
}
