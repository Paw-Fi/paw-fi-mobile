import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

/// Determines the chart interval type based on date range filter
String getChartIntervalTypeFromFilter(DateRangeFilter filter) {
  switch (filter) {
    case DateRangeFilter.today:
    case DateRangeFilter.yesterday:
      return 'hourly'; // Show hourly intervals for single day views
    case DateRangeFilter.thisWeek:
    case DateRangeFilter.lastWeek:
    case DateRangeFilter.last7Days:
    case DateRangeFilter.last30Days:
    case DateRangeFilter.thisMonth:
    case DateRangeFilter.lastMonth:
      return 'daily'; // Show daily intervals for week/month views
    case DateRangeFilter.thisYear:
      return 'monthly'; // Show monthly intervals for year view
    case DateRangeFilter.allTime:
      return 'yearly'; // Show yearly intervals for all-time view
    case DateRangeFilter.custom:
      return 'daily'; // Default to daily for custom ranges
  }
}

/// Determines the chart interval type based on period string (for transactions page)
String getChartIntervalTypeFromPeriod(String period) {
  switch (period) {
    case '1W':
    case '1M':
      return 'daily';
    case '6M':
    case '1Y':
      return 'monthly';
    case 'All':
      return 'yearly';
    default:
      return 'daily';
  }
}

/// Helper class for hour ranges
class HourRange {
  final int startHour;
  final int endHour;
  final String label;

  HourRange(this.startHour, this.endHour, this.label);
}

/// Groups expenses by the appropriate interval with fixed bucket counts
/// Returns exactly 7 data points for daily/yearly, 6 for hourly/monthly
Map<DateTime, double> groupExpensesByInterval(
  List<ExpenseEntry> expenses,
  String intervalType,
  {DateTime? rangeStart, DateTime? rangeEnd}
) {
  // Exclude income entries; this util is used for spending charts
  final spendOnly = expenses
      .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
      .toList();
  if (spendOnly.isEmpty) return {};

  switch (intervalType) {
    case 'hourly':
      return _groupByHourRanges(spendOnly);
    case 'daily':
      return _groupBySevenDays(
        spendOnly,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    case 'monthly':
      return _groupByMonthPairs(spendOnly);
    case 'yearly':
      return _groupBySevenYears(spendOnly);
    default:
      return _groupBySevenDays(
        spendOnly,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
  }
}

/// Groups expenses into 6 4-hour blocks for a single day
Map<DateTime, double> _groupByHourRanges(List<ExpenseEntry> expenses) {
  final Map<DateTime, double> buckets = {};

  // Get the date from the first expense
  if (expenses.isEmpty) return buckets;
  final baseDate = expenses.first.date;
  final today = DateTime(baseDate.year, baseDate.month, baseDate.day);

  // Create 6 4-hour buckets
  final hourRanges = [
    HourRange(0, 4, '0-4'),
    HourRange(4, 8, '4-8'),
    HourRange(8, 12, '8-12'),
    HourRange(12, 16, '12-16'),
    HourRange(16, 20, '16-20'),
    HourRange(20, 24, '20-24'),
  ];

  // Initialize buckets with zero
  for (var range in hourRanges) {
    final key = DateTime(today.year, today.month, today.day, range.startHour);
    buckets[key] = 0.0;
  }

  // Fill buckets with expense data
  for (final expense in expenses) {
    final hour = expense.date.hour;
    for (var range in hourRanges) {
      if (hour >= range.startHour && hour < range.endHour) {
        final key =
            DateTime(today.year, today.month, today.day, range.startHour);
        buckets[key] = (buckets[key] ?? 0) + expense.amount.abs();
        break;
      }
    }
  }

  return buckets;
}

/// Groups expenses into exactly 7 days going backwards from today
Map<DateTime, double> _groupBySevenDays(
  List<ExpenseEntry> expenses, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  if (expenses.isEmpty) return {};

  // Normalize and order expenses to compute the proper span
  final sortedExpenses = expenses.toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final oldestExpenseDate = DateTime(
    sortedExpenses.first.date.year,
    sortedExpenses.first.date.month,
    sortedExpenses.first.date.day,
  );
  final newestExpenseDate = DateTime(
    sortedExpenses.last.date.year,
    sortedExpenses.last.date.month,
    sortedExpenses.last.date.day,
  );

  // Respect the requested range when provided; otherwise, fall back to
  // the actual data boundaries.
  final normalizedStart = rangeStart != null
      ? DateTime(rangeStart.year, rangeStart.month, rangeStart.day)
      : oldestExpenseDate;
  final normalizedEnd = rangeEnd != null
      ? DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day)
      : newestExpenseDate;

  // Ensure start <= end to avoid negative spans.
  final start = normalizedEnd.isBefore(normalizedStart)
      ? normalizedEnd
      : normalizedStart;
  final end = normalizedEnd.isBefore(normalizedStart)
      ? normalizedStart
      : normalizedEnd;

  final daySpan = end.difference(start).inDays + 1;
  final bucketCount = daySpan < 7 ? daySpan : 7;

  // Evenly distribute buckets across the requested range so every selected
  // date window (e.g., "this month", custom ranges) produces visible points.
  final Map<DateTime, double> buckets = {};
  if (bucketCount == 1) {
    buckets[start] = 0.0;
  } else {
    for (int i = 0; i < bucketCount; i++) {
      final offset = ((daySpan - 1) * i / (bucketCount - 1)).round();
      final bucketDate = start.add(Duration(days: offset));
      buckets[bucketDate] = 0.0;
    }
  }

  final sortedBuckets = buckets.keys.toList()..sort();

  for (final expense in expenses) {
    final expenseDate = DateTime(
      expense.date.year,
      expense.date.month,
      expense.date.day,
    );

    // Assign to the bucket whose start is <= expenseDate and whose next bucket
    // start is > expenseDate; clamp beyond edges to nearest bucket.
    if (expenseDate.isBefore(sortedBuckets.first)) {
      buckets[sortedBuckets.first] =
          (buckets[sortedBuckets.first] ?? 0) + expense.amount.abs();
      continue;
    }

    if (expenseDate.isAfter(sortedBuckets.last) ||
        expenseDate.isAtSameMomentAs(sortedBuckets.last)) {
      buckets[sortedBuckets.last] =
          (buckets[sortedBuckets.last] ?? 0) + expense.amount.abs();
      continue;
    }

    for (int i = 0; i < sortedBuckets.length - 1; i++) {
      final bucketStart = sortedBuckets[i];
      final bucketEnd = sortedBuckets[i + 1];

      if ((expenseDate.isAtSameMomentAs(bucketStart) ||
              expenseDate.isAfter(bucketStart)) &&
          expenseDate.isBefore(bucketEnd)) {
        buckets[bucketStart] =
            (buckets[bucketStart] ?? 0) + expense.amount.abs();
        break;
      }
    }
  }

  return buckets;
}

/// Groups expenses into 6 2-month pairs
Map<DateTime, double> _groupByMonthPairs(List<ExpenseEntry> expenses) {
  if (expenses.isEmpty) return {};
  final Map<DateTime, double> buckets = {};

  // Anchor the last bucket to the current month pair that includes "today"
  final now = DateTime.now();
  int pairStartMonth =
      (now.month % 2 == 0) ? now.month - 1 : now.month; // 1,3,5,7,9,11
  int year = now.year;

  // Build 6 pairs going back in time
  final List<DateTime> keys = [];
  for (int i = 5; i >= 0; i--) {
    int month = pairStartMonth - (i * 2);
    int y = year;
    while (month <= 0) {
      month += 12;
      y -= 1;
    }
    keys.add(DateTime(y, month));
  }
  for (final k in keys) {
    buckets[k] = 0.0;
  }

  // Fill buckets with expense data into their corresponding month pair
  for (final expense in expenses) {
    int m = expense.date.month;
    int y = expense.date.year;
    int startMonth = (m % 2 == 0) ? m - 1 : m;
    final key = DateTime(y, startMonth);
    if (buckets.containsKey(key)) {
      buckets[key] = (buckets[key] ?? 0) + expense.amount.abs();
    }
  }

  return buckets;
}

/// Groups expenses into last 7 years
Map<DateTime, double> _groupBySevenYears(List<ExpenseEntry> expenses) {
  if (expenses.isEmpty) return {};
  final Map<DateTime, double> buckets = {};

  // Anchor to current year for the last bucket
  final currentYear = DateTime.now().year;
  for (int i = 6; i >= 0; i--) {
    final y = currentYear - (6 - i);
    buckets[DateTime(y)] = 0.0;
  }

  // Fill buckets with expense data if they fall into the 7-year window
  for (final expense in expenses) {
    final y = expense.date.year;
    final key = DateTime(y);
    if (buckets.containsKey(key)) {
      buckets[key] = (buckets[key] ?? 0) + expense.amount.abs();
    }
  }
  return buckets;
}

/// Formats a date based on the interval type for chart labels
String formatDateForInterval(DateTime date, String intervalType) {
  switch (intervalType) {
    case 'hourly':
      // Format as hour range (e.g., "0-4", "4-8")
      final startHour = date.hour;
      final endHour = startHour + 4;
      return '$startHour-${endHour == 24 ? "24" : endHour.toString()}';
    case 'daily':
      // Format as day of month or day name
      return DateFormat('d').format(date);
    case 'monthly':
      // Format as month pair (e.g., "Jan-Feb")
      final firstMonth = DateFormat('MMM').format(date);
      final secondMonth =
          DateFormat('MMM').format(DateTime(date.year, date.month + 1));
      return '$firstMonth-$secondMonth';
    case 'yearly':
      return date.year.toString();
    default:
      return date.day.toString();
  }
}

/// Groups expenses for bar chart with both totals and dates for sorting
class BarChartPeriodData {
  final Map<String, double> periodTotals;
  final Map<String, DateTime> periodDates;
  final List<String> sortedPeriods;

  BarChartPeriodData({
    required this.periodTotals,
    required this.periodDates,
    required this.sortedPeriods,
  });
}

/// Groups expenses by interval for bar chart with proper labels and sorting
/// Uses same bucketing as line chart to ensure consistency
BarChartPeriodData groupExpensesForBarChart(
  List<ExpenseEntry> expenses,
  String intervalType,
) {
  // Use the same grouping function as line chart
  final periodTotalsMap = groupExpensesByInterval(expenses, intervalType);

  // Convert to bar chart format with string labels
  final Map<String, double> periodTotals = {};
  final Map<String, DateTime> periodDates = {};

  for (final entry in periodTotalsMap.entries) {
    final date = entry.key;
    final label = formatDateForInterval(date, intervalType);
    periodTotals[label] = entry.value;
    periodDates[label] = date;
  }

  // Sort by date
  final sortedPeriods = periodTotals.keys.toList()
    ..sort((a, b) => periodDates[a]!.compareTo(periodDates[b]!));

  return BarChartPeriodData(
    periodTotals: periodTotals,
    periodDates: periodDates,
    sortedPeriods: sortedPeriods,
  );
}
