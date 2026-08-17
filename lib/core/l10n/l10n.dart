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

  String get spendByYou => 'Your share in this space';
}

extension ImportReviewL10nX on AppLocalizations {
  String get comparePlans => 'Compare plans';
  String get importReviewCompleteTitle => 'Import complete';
  String get importReviewClosePage => 'Close this page';
  String get importReviewResultsTitle => 'Import results';
  String get importReviewTransactionLogged => 'Transaction logged';
  String get importReviewSourceTitle => 'Forwarded import';
}

extension SiriExpenseTutorialL10nX on AppLocalizations {
  String get logExpenseWithSiri => 'Log expense with Siri';
  String get siriNoSetupRequired => 'No setup required.';
}

extension WalletPickerL10nX on AppLocalizations {
  String get noWallet => 'No wallet';
  String get walletCreatedSuccessfully => 'Wallet created successfully.';
  String get walletUpdatedSuccessfully => 'Wallet updated successfully.';
  String get transferCompletedSuccessfully =>
      'Transfer completed successfully.';
  String get transferUpdatedSuccessfully => 'Transfer updated successfully.';
  String get transferDeletedSuccessfully => 'Transfer deleted successfully.';
}

extension WalletAnalyticsL10nX on AppLocalizations {
  String get excludeFromWalletAnalytics => 'Exclude from wallet analytics';
  String get excludeFromWalletAnalyticsDescription =>
      'Keep this wallet visible without including it in Wallets totals.';
  String get excludeFromWalletAnalyticsDetails =>
      'Excludes this wallet\'s balance, wallet-linked income and spending from the Wallets net worth total, monthly summary, history, and chart. The wallet, its balance, and its transactions remain visible in the wallet card and details. No data is hidden or deleted.';
  String get excludedFromAnalytics => 'Excluded from analytics';
}

extension MonthlyReportHistoryL10nX on AppLocalizations {
  String get reports => 'Reports';
  String get monthlyReportPreviousPeriod => 'Previous period';
  String get monthlyReportNextPeriod => 'Next period';
  String get monthlyReportSelectPeriod => 'Select report period';
  String get currentPeriod => 'Current period';
  String get completedPeriod => 'Completed period';
  String get returnToCurrentPeriod => 'Return to current period';
  String get closingBalance => 'Closing balance';
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
  String get paywallCommitmentAnnualPlan => 'Yearly';
  String get paywallCommitmentHowItWorks => 'How it works';
  String get paywallCommitmentBilledMonthlyShort => 'Billed monthly';
  String get paywallCancelAnytime => 'Cancel anytime';
  String paywallBadgeSavePercent(int percent) => 'SAVE $percent%';
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
  String get paywallLifetimeAvailableAfterSubscriptionEnds =>
      'Cancel your App Store subscription first. You can buy Lifetime after your current access ends.';
  String get paywallLifetimeAlreadyIncludesPlus =>
      'Lifetime already includes Plus access. No other subscription is needed.';
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

extension PocketAssignmentL10nX on AppLocalizations {
  String get transactionsAssignedToPocket => 'Transactions assigned to pocket';
}

/// Bank-connection recovery copy is intentionally kept in the translation
/// catalog; English is the runtime fallback until the normal l10n export runs.
extension BankConnectionsRecoveryL10nX on AppLocalizations {
  String get bankConnections => 'Bank connections';
  String get bankConnectionPersonal => 'Personal';
  String get bankConnectionHousehold => 'Household';
  String get bankConnectionConnected => 'Connected';
  String get bankConnectionDisconnecting => 'Disconnecting';
  String get bankConnectionRemoved => 'Removed';
  String get bankConnectionNotAssigned => 'Not assigned to a wallet';
  String get bankConnectionFinishSetup => 'Finish setup';
  String get bankConnectionReconnect => 'Reconnect';
  String get bankConnectionRoleGuidance =>
      'A household owner or admin must manage this bank connection.';
  String bankConnectionWalletCount(int count) =>
      count == 1 ? '1 linked wallet' : '$count linked wallets';
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
  String activePaycheckCount(int count) =>
      count == 1 ? '1 active paycheck' : '$count active paychecks';
  String activeBillCount(int count) =>
      count == 1 ? '1 active bill' : '$count active bills';
}

extension CancelReasonL10nX on AppLocalizations {
  String get manageMembershipTitle => 'Manage membership';
  String get manageMembershipViewStatus => 'View membership status';
  String get manageMembershipViewStatusDescription =>
      'See your current plan, renewal date, and billing details.';
  String get manageMembershipCancelPlan => 'Cancel my plan';
  String get manageMembershipCancelPlanDescription =>
      'We\'d love to know why you\'re leaving so we can improve.';
  String get cancelReasonTitle => 'Why are you cancelling?';
  String get cancelReasonSubtitle =>
      'Help us improve Moneko. Your answer won\'t affect the cancellation.';
  String get cancelReasonTooExpensive => 'Too expensive';
  String get cancelReasonFoundAlternative => 'Found an alternative';
  String get cancelReasonNotUsingEnough => 'Not using it enough';
  String get cancelReasonAppIssue => 'App issue';
  String get cancelReasonAppIssuePlaceholder =>
      'Describe the issue you experienced';
  String get cancelReasonMissingSpecificFeature => 'Missing a specific feature';
  String get cancelReasonMissingSpecificFeaturePlaceholder =>
      'Which feature were you looking for?';
  String get cancelReasonOther => 'Other';
  String get cancelReasonOtherPlaceholder => 'Tell us more';
  String get cancelReasonContinue => 'Continue to cancel';
}

/// Recurring occurrence confirmation sheet copy. English is the runtime
/// fallback until the keys are promoted into generated ARB files.
extension RecurringOccurrenceL10nX on AppLocalizations {
  String get editPayment => 'Edit payment';
  String get recurringOccurrenceEnterAmount =>
      'Enter an amount greater than zero.';
  String get recurringOccurrenceNotAvailable =>
      'This occurrence is not available for confirmation yet.';
  String get recurringOccurrenceUnableToLoadWallets =>
      'Unable to load wallets.';
  String get recurringOccurrenceWalletsLoading => 'Wallets are still loading.';
  String get recurringOccurrenceChooseWalletInCurrency =>
      'Choose a wallet in this currency.';
  String get recurringOccurrencePaidDateAfterToday =>
      'The paid date cannot be later than today.';
  String get recurringOccurrenceSignInToConfirm =>
      'Sign in to confirm this payment.';
  String get recurringOccurrenceUnableToUpdate => 'Unable to update payment.';
  String get recurringOccurrenceUnableToConfirm => 'Unable to confirm payment.';
  String get recurringOccurrenceUpdateSaved => 'Payment update saved.';
  String get recurringOccurrenceConfirmationSaved =>
      'Payment confirmation saved.';
  String get recurringOccurrenceUnconfirmQuestion => 'Unconfirm payment?';
  String get recurringOccurrenceUnconfirmDescription =>
      'The payment will be removed and the occurrence restored.';
  String get recurringOccurrenceUnconfirm => 'Unconfirm';
  String get recurringOccurrenceUnableToUnconfirm =>
      'Unable to unconfirm payment.';
  String get recurringOccurrenceUnconfirmed => 'Payment unconfirmed.';
  String get recurringOccurrenceWalletsUnavailable => 'Wallets unavailable';
  String get recurringOccurrenceLoadingWallets => 'Loading wallets...';
  String get recurringOccurrenceChooseWallet => 'Choose wallet';
  String get recurringOccurrenceDateReceived => 'Date received';
  String get recurringOccurrenceDatePaid => 'Date paid';
  String get recurringOccurrenceActualAmount => 'Actual amount';
  String get recurringOccurrenceSettlementLocked =>
      'This payment has settlement activity. Only notes can be edited.';
  String get recurringOccurrenceUpdateFutureAmount =>
      'Update future default amount';
  String get recurringOccurrenceConfirming => 'Confirming...';
  String get recurringOccurrenceUnconfirmPayment => 'Unconfirm payment';
  String get signInToConfirmPayments => 'Sign in to confirm payments.';
  String get chooseAWalletForConfirmation =>
      'Choose a wallet for confirmation.';
  String get unableToConfirmRemainingPayments =>
      'Unable to confirm remaining past payments.';
  String successfullyConfirmedPastPayments(int count) =>
      'Successfully confirmed $count past payments.';
  String get depositWithdrawWallet => 'Deposit/Withdraw Wallet';
  String get importedPayment => 'Imported payment';
  String get skipped => 'Skipped';
  String get unableToSkipOccurrence => 'Unable to skip occurrence.';
}

/// Unsaved-changes navigation copy. English is the runtime fallback until
/// the keys are promoted into generated ARB files.
extension UnsavedChangesL10nX on AppLocalizations {
  String get unsavedChanges => 'Unsaved changes';
  String get leaveWithoutSavingChanges => 'Leave without saving your changes?';
  String get leave => 'Leave';
  String get equal => 'Equal';
  String get replaceReceiptPhoto => 'Replace receipt photo';
  String expiresInDays(int count) =>
      count == 1 ? 'Expires in 1 day' : 'Expires in $count days';
  String expiresInHours(int count) =>
      count == 1 ? 'Expires in 1 hour' : 'Expires in $count hours';
  String expiredDaysAgo(int count) =>
      count == 1 ? 'Expired 1 day ago' : 'Expired $count days ago';
  String get noInternetWhilePayingWithApplePay =>
      'No internet while paying with Apple Pay?';
  String get applePayOfflineSyncDescription =>
      'Don\'t worry. Moneko saves the transaction on your iPhone and automatically syncs it the next time you open the app with internet.';
  String dayOfTotal(int current, int total) => 'Day $current of $total';
}

/// AI processing progress and status messages. English is the runtime
/// fallback until the keys are promoted into generated ARB files.
extension AiProgressL10nX on AppLocalizations {
  String get aiProgressGettingThingsReady => 'Getting things ready...';
  String get aiProgressReadingTheDetails => 'Reading the details...';
  String get aiProgressLookingThroughReceipt =>
      'Looking through your receipt...';
  String get aiProgressReviewingTransactions => 'Reviewing transactions...';
  String get aiProgressFinishingUp => 'Finishing up...';
  String get aiProgressWorkingOnIt => 'Working on it...';
  String get aiProcessingPdfDocument => 'Processing PDF document...';
  String get aiReadingWhatYouTyped => 'Reading what you typed...';
  String get aiLookingThroughYourImage => 'Looking through your image...';
  String get aiListeningToYourRecording => 'Listening to your recording...';
  String get aiProcessingFile => 'Processing file...';
  String get aiProcessingLargeFile => 'Processing large file...';
  String get aiExtractingTransactionsFromPdf =>
      'Extracting transactions from PDF...';
  String get aiFileTooLargeToAnalyze =>
      'File is too large to analyze. Keep it under 20MB or split it into smaller files.';
  String get whereDidYouHearAboutUs => 'Where did you hear about us?';
  String get heardAboutSubtitle =>
      'Pick the option that fits best. If it was somewhere else, choose Other.';
  String get tellUsWhere => 'Tell us where';
  String get importAndContinue => 'Import and continue';
  String get areYouCurrentlyUsingOtherApp =>
      'Are you currently using other app?';
  String get pickYourSourceSubtitle =>
      'Pick your source to see exactly which file to upload. We import into your personal account in the next step.';
  String get friendOrFamily => 'Friend or family';
}
