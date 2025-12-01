import 'package:flutter/widgets.dart';
import 'package:moneko/l10n/app_localizations.dart';

/// Date range filter options
enum DateRangeFilter {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  last7Days,
  thisMonth,
  lastMonth,
  last30Days,
  thisYear,
  allTime,
  custom,
}

extension DateRangeFilterExtension on DateRangeFilter {
  String getLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case DateRangeFilter.today:
        return l10n.today;
      case DateRangeFilter.yesterday:
        return l10n.yesterday;
      case DateRangeFilter.thisWeek:
        return l10n.thisWeek;
      case DateRangeFilter.lastWeek:
        return l10n.lastWeek;
      case DateRangeFilter.last7Days:
        return "Last 7 days";
      case DateRangeFilter.thisMonth:
        return l10n.thisMonth;
      case DateRangeFilter.lastMonth:
        return "Last month";
      case DateRangeFilter.last30Days:
        return l10n.last30Days;
      case DateRangeFilter.thisYear:
        return l10n.thisYear;
      case DateRangeFilter.allTime:
        return l10n.allTime;
      case DateRangeFilter.custom:
        return l10n.customRange;
    }
  }

  String getSpentLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case DateRangeFilter.today:
        return l10n.spentToday;
      case DateRangeFilter.yesterday:
        return l10n.spentYesterday;
      case DateRangeFilter.thisWeek:
        return l10n.spentThisWeek;
      case DateRangeFilter.lastWeek:
        return l10n.spentLastWeek;
      case DateRangeFilter.last7Days:
        return 'Spent (Last 7 days)';
      case DateRangeFilter.thisMonth:
        return l10n.spentThisMonth;
      case DateRangeFilter.lastMonth:
        return 'Spent (Last month)';
      case DateRangeFilter.last30Days:
        return l10n.spentLast30Days;
      case DateRangeFilter.thisYear:
        return '${l10n.spent} (${l10n.thisYear})';
      case DateRangeFilter.allTime:
        // Avoid introducing new l10n keys; compose from existing ones
        return '${l10n.spent} (${l10n.allTime})';
      case DateRangeFilter.custom:
        return l10n.spentCustom;
    }
  }
}
