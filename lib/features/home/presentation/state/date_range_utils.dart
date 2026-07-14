import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

/// Helper function to calculate date range from filter
Map<String, DateTime> getDateRangeFromFilter(
  DateRangeFilter filter,
  DateTime? customStart,
  DateTime? customEnd, {
  DateTime? now,
  int financialMonthStartDay = 1,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final normalizedFinancialStartDay =
      normalizeFinancialMonthStartDay(financialMonthStartDay);

  switch (filter) {
    case DateRangeFilter.today:
      return {'from': today, 'to': today};

    case DateRangeFilter.yesterday:
      final yesterday = today.subtract(const Duration(days: 1));
      return {'from': yesterday, 'to': yesterday};

    case DateRangeFilter.thisWeek:
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return {'from': weekStart, 'to': today};

    case DateRangeFilter.lastWeek:
      final lastWeekEnd = today.subtract(Duration(days: today.weekday));
      final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
      return {'from': lastWeekStart, 'to': lastWeekEnd};

    case DateRangeFilter.last7Days:
      final from = today.subtract(const Duration(days: 6));
      return {'from': from, 'to': today};

    case DateRangeFilter.thisMonth:
      final period = financialCycleForDate(
        today,
        startDay: normalizedFinancialStartDay,
      );
      return {'from': period.start, 'to': today};

    case DateRangeFilter.lastMonth:
      final period = previousFinancialCycleForDate(
        today,
        startDay: normalizedFinancialStartDay,
      );
      return {'from': period.start, 'to': period.end};

    case DateRangeFilter.last3Months:
      final currentPeriodStart = financialCycleStartForDate(
        today,
        startDay: normalizedFinancialStartDay,
      );
      final firstOfThreeCycles = addFinancialCycles(
        currentPeriodStart,
        -2,
        startDay: normalizedFinancialStartDay,
      );
      return {'from': firstOfThreeCycles, 'to': today};

    case DateRangeFilter.thisYear:
      final firstOfYear = DateTime(current.year, 1, 1);
      return {'from': firstOfYear, 'to': today};

    case DateRangeFilter.last30Days:
      final from = today.subtract(const Duration(days: 29));
      return {'from': from, 'to': today};

    case DateRangeFilter.allTime:
      // Treat as unbounded past to today
      final from = DateTime.fromMillisecondsSinceEpoch(0);
      return {'from': from, 'to': today};

    case DateRangeFilter.custom:
      if (customStart != null && customEnd != null) {
        return {'from': customStart, 'to': customEnd};
      }
      // Fallback to last 30 days if custom dates not set
      final from = today.subtract(const Duration(days: 29));
      return {'from': from, 'to': today};
  }
}
