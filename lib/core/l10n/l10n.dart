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

/// Settlement cutover copy lives here until the translations catalog is
/// promoted into generated ARB files. Keeping the getters on
/// [AppLocalizations] gives every supported locale the intentional English
/// fallback while `translations.json` remains the source for translators.
extension SettlementBreakdownL10nX on AppLocalizations {
  String get balanceCarriedForward => 'Balance carried forward';

  String get balanceCarriedForwardDescription =>
      'Balance from before detailed settlement history was available.';
}

extension HomeDashboardL10nX on AppLocalizations {
  String get netCashflow => 'Net cashflow';
}

extension MonthlyReportHistoryL10nX on AppLocalizations {
  String get monthlyReportReports => 'Reports';
  String get monthlyReportPreviousPeriod => 'Previous period';
  String get monthlyReportNextPeriod => 'Next period';
  String get monthlyReportSelectPeriod => 'Select report period';
  String get monthlyReportCurrentPeriod => 'Current period';
  String get monthlyReportCompletedPeriod => 'Completed period';
  String get monthlyReportCurrent => 'Current';
  String get monthlyReportReturnToCurrent => 'Return to current period';
  String get monthlyReportClosingBalance => 'Closing balance';
  String get monthlyReportCompletedSafeSpendUnavailable =>
      'Safe to spend only applies to the current period.';
  String get monthlyReportCompletedRecurringUnavailable =>
      'Recurring schedules show current commitments and are not part of a completed report.';

  String monthlyReportCompletedSummary(
    String status,
    String netCashFlow,
    String closingBalance,
    String currencyCode,
  ) =>
      'This period finished $status, with $netCashFlow $currencyCode in net cash flow and a closing balance of $closingBalance $currencyCode.';
}

extension ImportRecurringL10nX on AppLocalizations {
  String get importNotRecurringAction => 'Not recurring?';
  String get importReleaseSeriesTitle => 'Import as separate transactions?';
  String importReleaseSeriesDescription(int count) => count == 1
      ? 'Moneko detected this transaction as recurring. Releasing it will import it as a regular transaction.'
      : 'Moneko detected these $count transactions as a recurring series. Releasing them will import every occurrence as its own transaction.';
  String importReleaseSeriesOverview(int count) =>
      'Transactions in this series ($count)';
  String importSeriesTransactionCount(int count) =>
      count == 1 ? '1 transaction' : '$count transactions';
  String get importReleaseSeriesConfirm => 'Release transactions';
}

extension PaywallCommitmentL10nX on AppLocalizations {
  String paywallCommitmentName(int months) => '$months-month commitment';
  String paywallCommitmentTerms(int months) =>
      'Pay monthly over a $months-month commitment. Cancel anytime to prevent the next commitment from starting.';
  String get paywallCommitmentAnnualPlan => 'Annual Plan';
  String get paywallCommitmentHowItWorks => 'How it works';
  String paywallCommitmentBilledMonthly(int months) =>
      'Billed monthly for $months months';
  String paywallCommitmentBilledMonthlyWithTotal(String total, int months) =>
      'Billed monthly for $months months · $total over $months months';
  String paywallCommitmentPaidUpfront(int months) =>
      'Paid upfront for $months months';
  String paywallCommitmentPaidUpfrontWithTotal(String total, int months) =>
      'Paid upfront: $total for $months months';
  String get paywallCommitmentSavings =>
      'Enjoy annual savings without paying the full amount upfront.';
  String get paywallCommitmentHowItWorksSemantics =>
      'Learn how Annual Plan monthly payments work';
  String get paywallCommitmentDetailsTitle => 'Annual Plan, paid monthly';
  String paywallCommitmentDetailsIntro(
    String monthly,
    String total,
    int months,
  ) =>
      "Instead of paying $total upfront, you'll be charged $monthly each month over a $months-month commitment.";
  String get paywallCommitmentBillingTitle => 'How billing works';
  String paywallCommitmentBillingBody(
    String monthly,
    String total,
    int months,
  ) =>
      "You'll be charged $monthly each month for $months months ($total over the full commitment). You'll enjoy all Plus features throughout your subscription.";
  String get paywallCommitmentCancellationTitle => 'If you cancel';
  String paywallCommitmentCancellationBody(int months) =>
      "Cancelling prevents your subscription from renewing for another $months-month commitment. It doesn't end your current commitment—your remaining monthly payments will continue until all $months payments have been completed.";
  String paywallCommitmentRenewalTitle(int months) => 'After $months months';
  String paywallCommitmentRenewalBody(int months) =>
      'Your subscription renews for another $months-month commitment unless you cancel before the renewal date.';
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
  String get pocketRolloverContributionTitle => 'Where this rollover came from';
  String get pocketRolloverContributionDescription =>
      'Moneko tracks the surviving pieces of your carry-over so the total stays explainable.';
  String get pocketRolloverContributionEmpty =>
      'No rollover has been carried into this month yet.';
  String get pocketRolloverCapAdjustmentLabel => 'Cap adjustment';
  String get pocketRolloverNegativeDroppedLabel => 'Overspend not carried';
  String get pocketRolloverResetLabel => 'Rollover reset';
  String get pocketRolloverMissingMonthWarning =>
      'Some months are missing in this envelope lineage. Review the timeline before relying on the carry-over total.';

  String pocketRolloverMonthLeftover(String month) => '$month leftover';

  String pocketRolloverMonthOverspend(String month) => '$month overspend';

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

extension PlaidClassificationReviewL10nX on AppLocalizations {
  String get failedToSyncTransactions =>
      'Bank transactions could not be synced. Try again before continuing.';
  String get plaidReviewLoadMore => 'Load more transactions';
  String get plaidClassificationNeedsReview => 'Check transaction type';
  String get plaidClassificationNeedsReviewDescription =>
      'Plaid could not identify how this transaction should affect your budget.';
  String get plaidOverrideClassification => 'Set transaction type';
  String get plaidRestoreProviderClassification =>
      'Restore Plaid classification';
  String get plaidClassificationUpdated => 'Transaction type updated';
  String get plaidConsumerSpend => 'Purchase or spending';
  String get plaidIncome => 'Income';
  String get plaidTransferOut => 'Transfer out';
  String get plaidTransferIn => 'Transfer in';
  String get plaidDebtPayment => 'Debt payment';
  String get plaidLoanDisbursement => 'Loan disbursement';
  String get plaidRefundOrReversal => 'Refund or reversal';
  String get plaidBankFee => 'Bank fee';
  String get plaidCashMovement => 'Cash movement';
  String get plaidExcludeFromBudget => 'Exclude from budget totals';
  String get plaidPossibleTransferMatch => 'Possible transfer match';
  String get plaidReviewFlaggedBeforeContinue =>
      'Review every flagged transaction before continuing.';

  String plaidAnalyticsClassLabel(String analyticsClass) =>
      switch (analyticsClass) {
        'consumer_spend' => plaidConsumerSpend,
        'income' => plaidIncome,
        'transfer_out' => plaidTransferOut,
        'transfer_in' => plaidTransferIn,
        'debt_payment' => plaidDebtPayment,
        'loan_disbursement' => plaidLoanDisbursement,
        'refund_or_reversal' => plaidRefundOrReversal,
        'bank_fee' => plaidBankFee,
        'cash_movement' => plaidCashMovement,
        _ => plaidExcludeFromBudget,
      };
}

extension TrialWelcomeL10nX on AppLocalizations {
  String get trialWelcomeTitle => 'You\'ve got 7 days of Plus — free!';
  String get trialWelcomeSubtitle =>
      'Enjoy all Plus features at no cost for the next 7 days. Here\'s what you can try:';
  String get trialWelcomeFeatureMessagingTitle =>
      'Log expenses via Telegram & WhatsApp';
  String get trialWelcomeFeatureMessagingBody =>
      'Forward a message or receipt from your favorite chat app and Moneko captures it automatically.';
  String get trialWelcomeFeatureEmailTitle => 'Email receipt capture';
  String get trialWelcomeFeatureEmailBody =>
      'Forward any receipt email and Moneko will extract and record the transaction for you.';
  String get trialWelcomeFeatureMultiCurrencyTitle => 'Multi-currency display';
  String get trialWelcomeFeatureMultiCurrencyBody =>
      'Track spending across multiple currencies with real-time exchange rates.';
  String get trialWelcomeFeatureInsightsTitle => 'Advanced insights & what-ifs';
  String get trialWelcomeFeatureInsightsBody =>
      'Scenario planning, running balance projections, and 30-day look-ahead analysis.';
  String get trialWelcomeFaqHeader => 'Good to know';
  String get trialWelcomeFaqNoChargeQuestion =>
      'Will I be charged when the trial ends?';
  String get trialWelcomeFaqNoChargeAnswer =>
      'No. We won\'t deduct anything from you. You don\'t need to do anything — the trial simply expires on its own.';
  String get trialWelcomeFaqAfterTrialQuestion =>
      'What happens if I don\'t subscribe?';
  String get trialWelcomeFaqAfterTrialAnswer =>
      'That\'s absolutely fine! You can continue using Moneko for free with some features limited. No pressure, no surprises.';
  String get trialWelcomeCta => 'Start exploring';
}

extension RecurringPageL10nX on AppLocalizations {
  String get monthlyCommitment => 'Monthly Commitment';
  String get monthlyIncome => 'Monthly Income';
  String get activeBills => 'Active Bills';
  String get activePaychecks => 'Active Paychecks';
  String get dueIn7Days => 'Due in 7 Days';
  String get dueThisMonth => 'Due This Month';
  String get dueLater => 'Due Later';
  String get activeSchedules => 'Active Schedules';
}
