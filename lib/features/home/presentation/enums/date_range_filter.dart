import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
      case DateRangeFilter.thisMonth:
        return l10n.thisMonth;
      case DateRangeFilter.last30Days:
        return l10n.last30Days;
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
      case DateRangeFilter.thisMonth:
        return l10n.spentThisMonth;
      case DateRangeFilter.last30Days:
        return l10n.spentLast30Days;
      case DateRangeFilter.custom:
        return l10n.spentCustom;
    }
  }
  }