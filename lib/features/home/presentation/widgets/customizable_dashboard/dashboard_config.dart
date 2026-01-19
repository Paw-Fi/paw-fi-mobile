import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum DashboardWidgetType {
  // Personal Home Widgets
  spendingSummary,
  netCashflow, // Includes MoM trend for now or separate? Let's keep them separate items
  financialCalendar,
  recentTransactions,
  spendingBreakdownChart,
  whereTheMoneyWent,

  // Household Home Widgets
  householdSpentByYou,
  householdFinancialCalendar,
  householdBudgetOverview,
  householdFairness,
  householdSettlement,
  householdMemberSpending,
  householdRecentTransactions,
  householdSpendingBreakdownChart,
  householdWhereTheMoneyWent;

  List<DashboardWidgetViewMode> get supportedViewModes {
    switch (this) {
      case DashboardWidgetType.financialCalendar:
        return [DashboardWidgetViewMode.wide, DashboardWidgetViewMode.full];
      case DashboardWidgetType.householdFinancialCalendar:
        return [DashboardWidgetViewMode.wide, DashboardWidgetViewMode.full];
      default:
        return [DashboardWidgetViewMode.wide];
    }
  }

  bool get supportsDateRange {
    switch (this) {
      case DashboardWidgetType.spendingSummary:
      case DashboardWidgetType.householdSpentByYou:
      case DashboardWidgetType.householdBudgetOverview:
      case DashboardWidgetType.householdFairness:
      case DashboardWidgetType.spendingBreakdownChart:
      case DashboardWidgetType.householdSpendingBreakdownChart:
      case DashboardWidgetType.whereTheMoneyWent:
      case DashboardWidgetType.householdWhereTheMoneyWent:
        return true;
      default:
        return false;
    }
  }

  bool get supportsViewMode {
    switch (this) {
      case DashboardWidgetType.financialCalendar:
      case DashboardWidgetType.householdFinancialCalendar:
        return true;
      default:
        return false;
    }
  }

  bool get hasEditableOptions => supportsDateRange || supportsViewMode;
}

enum DashboardWidgetViewMode {
  mini, // 1x1
  wide, // 2x1
  full, // 2x2
}

class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;
  final bool isVisible;
  final DateRangeFilter dateRange;
  final int order;
  final DashboardWidgetViewMode viewMode;

  // Optional: Custom date range if 'custom' is selected (not fully implemented in this pass but good to have)
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const DashboardWidgetConfig({
    required this.id,
    required this.type,
    this.isVisible = true,
    this.dateRange = DateRangeFilter.thisMonth,
    required this.order,
    this.viewMode = DashboardWidgetViewMode.wide,
    this.customStartDate,
    this.customEndDate,
  });

  DashboardWidgetConfig copyWith({
    bool? isVisible,
    DateRangeFilter? dateRange,
    int? order,
    DashboardWidgetViewMode? viewMode,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) {
    return DashboardWidgetConfig(
      id: id,
      type: type,
      isVisible: isVisible ?? this.isVisible,
      dateRange: dateRange ?? this.dateRange,
      order: order ?? this.order,
      viewMode: viewMode ?? this.viewMode,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'isVisible': isVisible,
      'dateRange': dateRange.name,
      'order': order,
      'viewMode': viewMode.name,
      'customStartDate': customStartDate?.toIso8601String(),
      'customEndDate': customEndDate?.toIso8601String(),
    };
  }

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    // Handle migration from old enum names
    final String? typeName = json['type'] as String?;
    String migratedTypeName = typeName ?? 'spendingSummary';

    FirebaseCrashlytics.instance
        .log('🔍 DashboardConfig.fromJson: original type=$typeName');

    if (migratedTypeName == 'categoryBreakdown') {
      migratedTypeName = 'recentTransactions';
      FirebaseCrashlytics.instance
          .log('🔄 Migrated categoryBreakdown -> recentTransactions');
    } else if (migratedTypeName == 'householdCategoryBreakdown') {
      migratedTypeName = 'householdRecentTransactions';
      FirebaseCrashlytics.instance.log(
          '🔄 Migrated householdCategoryBreakdown -> householdRecentTransactions');
    }

    return DashboardWidgetConfig(
      id: json['id'] as String,
      type: DashboardWidgetType.values.firstWhere(
        (e) => e.name == migratedTypeName,
        orElse: () => DashboardWidgetType.spendingSummary,
      ),
      isVisible: json['isVisible'] as bool? ?? true,
      dateRange: DateRangeFilter.values.firstWhere(
        (e) => e.name == (json['dateRange'] as String?),
        orElse: () => DateRangeFilter.thisMonth,
      ),
      order: json['order'] as int? ?? 0,
      viewMode: DashboardWidgetViewMode.values.firstWhere(
        (e) => e.name == (json['viewMode'] as String?),
        orElse: () => DashboardWidgetViewMode.wide,
      ),
      customStartDate: json['customStartDate'] != null
          ? DateTime.tryParse(json['customStartDate'] as String)
          : null,
      customEndDate: json['customEndDate'] != null
          ? DateTime.tryParse(json['customEndDate'] as String)
          : null,
    );
  }
}
