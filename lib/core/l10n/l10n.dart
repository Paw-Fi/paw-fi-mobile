import 'package:flutter/widgets.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

extension L10nX on BuildContext {
  /// Safe localization getter.
  /// Returns generated English localizations if the context is not yet
  /// wrapped with Localizations (early frames) or the locale is unsupported.
  AppLocalizations get l10n {
    final loc = AppLocalizations.of(this);
    if (loc != null) return loc;
    return AppLocalizationsEn('en');
  }
}

extension PocketRolloverL10nX on AppLocalizations {
  String get pocketRolloverActivityTitle => 'Rollover activity';
  String get pocketRolloverAvailableBudgetLabel => 'Available';
  String get pocketRolloverBaseBudgetLabel => 'Base budget';
  String get pocketRolloverBreakdownTitle => 'Budget breakdown';
  String get pocketRolloverCarryOverspendingLabel => 'Carry overspending';
  String get pocketRolloverOpeningLabel => 'Opening rollover';
  String get pocketRolloverSettingsTitle => 'Carry unused budget forward';
  String get pocketRolloverSummaryTitle => 'Budget rollover summary';
  String get pocketRolloverHistoryTitle => 'Rollover history';
  String get pocketRolloverNextMonthTitle => 'Next month carry-over';
  String get pocketRolloverLabel => 'Rollover';
  String get pocketRolloverSpentLabel => 'Spent';
  String get pocketRolloverRemainingLabel => 'Remaining';
  String get pocketRolloverSummaryDescription =>
      'Available budgets include carry-over from previous periods.';
  String get pocketRolloverCarryOverFromPreviousMonthLabel =>
      'Carry-over from previous month';
  String get pocketRolloverSettingsDescription =>
      'Unused money stays available next month.';
  String get pocketRolloverOverspendingEnabledDescription =>
      'Overspending reduces next month.';
  String get pocketRolloverOverspendingDisabledDescription =>
      'Overspending will not reduce next month.';
  String get pocketRolloverOpeningDescription =>
      'Use this when moving an existing envelope balance into Moneko.';
  String get pocketRolloverMaximumLabel => 'Maximum rollover';
  String get pocketRolloverUnlimitedPlaceholder => 'Unlimited';
  String get pocketRolloverInvalidCapError =>
      'Enter a valid maximum rollover amount, or leave it blank for unlimited.';
  String get pocketRolloverInvalidOpeningError =>
      'Enter a valid opening rollover amount, or leave it blank for zero.';
  String get pocketRolloverNegativeOpeningRequiresOverspendingError =>
      'Turn on carry overspending before using a negative opening rollover.';
  String get pocketRolloverNegativeNotCarriedDescription =>
      'Overspending is not carried, so next month will start from the base budget.';
  String get pocketRolloverCapLimitedDescription =>
      'The rollover cap limits how much unused budget can move forward.';
  String get pocketRolloverNoCarryExpectedDescription =>
      'There is no carry-over expected from this month yet.';
  String get pocketRolloverNextMonthDescription =>
      'When next month is created, this amount is added to the base budget.';

  String pocketRolloverSettingsExample(String currencySymbol) =>
      'Example: if June has ${currencySymbol}400 budget and ${currencySymbol}350 spent, July starts with ${currencySymbol}450 available. Moneko still shows the ${currencySymbol}400 base budget separately.';

  String pocketRolloverMoreCount(int count) => '+$count more';

  String pocketRolloverCarryOverBadge(String amount) => 'Carry-over $amount';

  String pocketRolloverHistorySummary({
    required String base,
    required String rollover,
    required String spent,
  }) =>
      'Base $base - Rollover $rollover - Spent $spent';
}
