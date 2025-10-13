/// Date range filter options
enum DateRangeFilter {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  last30Days,
  custom,
}

extension DateRangeFilterExtension on DateRangeFilter {
  String get label {
    switch (this) {
      case DateRangeFilter.today:
        return 'Today';
      case DateRangeFilter.yesterday:
        return 'Yesterday';
      case DateRangeFilter.thisWeek:
        return 'This week';
      case DateRangeFilter.lastWeek:
        return 'Last week';
      case DateRangeFilter.thisMonth:
        return 'This month';
      case DateRangeFilter.last30Days:
        return 'Last 30 days';
      case DateRangeFilter.custom:
        return 'Custom range';
    }
  }

  String get spentLabel {
    switch (this) {
      case DateRangeFilter.today:
        return 'Spent today';
      case DateRangeFilter.yesterday:
        return 'Spent yesterday';
      case DateRangeFilter.thisWeek:
        return 'Spent this week';
      case DateRangeFilter.lastWeek:
        return 'Spent last week';
      case DateRangeFilter.thisMonth:
        return 'Spent this month';
      case DateRangeFilter.last30Days:
        return 'Spent (last 30 days)';
      case DateRangeFilter.custom:
        return 'Spent (custom)';
    }
  }
}
