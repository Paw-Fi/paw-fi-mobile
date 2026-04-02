import 'package:moneko/core/utils/user_timezone.dart';

class DashboardScopeQuery {
  final String userId;
  final String? householdId;
  final String? selectedCurrency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? intervalGranularity;

  const DashboardScopeQuery({
    required this.userId,
    required this.householdId,
    required this.selectedCurrency,
    required this.startDate,
    required this.endDate,
    this.intervalGranularity,
  });

  String? get normalizedCurrency {
    final currency = selectedCurrency?.trim().toUpperCase();
    return (currency == null || currency.isEmpty) ? null : currency;
  }

  String? get formattedStartDate =>
      startDate == null ? null : formatDateOnlyYmd(startDate!);

  String? get formattedEndDate =>
      endDate == null ? null : formatDateOnlyYmd(endDate!);

  String? get normalizedIntervalGranularity {
    final value = intervalGranularity?.trim().toLowerCase();
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

  DashboardScopeQuery copyWith({
    String? userId,
    String? householdId,
    String? selectedCurrency,
    DateTime? startDate,
    DateTime? endDate,
    String? intervalGranularity,
  }) {
    return DashboardScopeQuery(
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      intervalGranularity: intervalGranularity ?? this.intervalGranularity,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DashboardScopeQuery &&
            userId == other.userId &&
            householdId == other.householdId &&
            normalizedCurrency == other.normalizedCurrency &&
            formattedStartDate == other.formattedStartDate &&
            formattedEndDate == other.formattedEndDate &&
            normalizedIntervalGranularity ==
                other.normalizedIntervalGranularity;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        normalizedCurrency,
        formattedStartDate,
        formattedEndDate,
        normalizedIntervalGranularity,
      );
}

class DashboardRecentTransactionsRequest {
  final DashboardScopeQuery query;
  final int limit;

  const DashboardRecentTransactionsRequest({
    required this.query,
    this.limit = 5,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DashboardRecentTransactionsRequest &&
            query == other.query &&
            limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(query, limit);
}

class DashboardCategorySummary {
  final String category;
  final double amount;
  final int transactionCount;

  const DashboardCategorySummary({
    required this.category,
    required this.amount,
    required this.transactionCount,
  });
}

class DashboardSnapshotSummary {
  final int transactionCount;
  final double expenseTotal;
  final double incomeTotal;
  final bool hasMultipleCurrencies;
  final List<DashboardCategorySummary> categorySummaries;
  final Map<DateTime, double> periodTotals;

  const DashboardSnapshotSummary({
    required this.transactionCount,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.hasMultipleCurrencies,
    required this.categorySummaries,
    required this.periodTotals,
  });

  const DashboardSnapshotSummary.empty()
      : transactionCount = 0,
        expenseTotal = 0,
        incomeTotal = 0,
        hasMultipleCurrencies = false,
        categorySummaries = const <DashboardCategorySummary>[],
        periodTotals = const <DateTime, double>{};
}
