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

extension PocketsAiSuggestionsL10nX on AppLocalizations {
  String get win => 'Win';
  String get strategy => 'Strategy';
  String get mindset => 'Mindset';
  String get covered => 'Covered';
  String get aiBlueprint => 'AI Blueprint';
  String get pocketsChangedWhilePreparingPlan =>
      'Your pockets changed while your plan was being prepared. Please try again.';
}

extension SharedWidgetsL10nX on AppLocalizations {
  String workingForElapsed(String elapsed) => 'Working for $elapsed';
}

extension MonthlyIntroInsightsL10nX on AppLocalizations {
  String get welcome => 'Welcome';
  String get freshStart => 'Fresh start';
  String get progress => 'Progress';
  String get upcoming => 'Upcoming';
  String get milestone => 'Milestone';
  String helloMonthName(String month) => 'Hello, $month ✨';
  String startingMonthWithExtra(String month, String amount) =>
      'You\'re starting $month with $amount extra';
  String introRolloverDescription(String month) =>
      'Your unused budget from $month has rolled forward. Let\'s decide where it can help most.';
  String get carriedForward => 'Carried forward';
  String get newMonthFreshBalance => 'New month, fresh balance';
  String introPocketAdjustmentDescription(
          String pocket, String amount, String month) =>
      '$pocket ran $amount above plan last month. We can adjust $month around how you actually spend.';
  String abovePlanInMonth(String month) => 'Above plan in $month';
  String youFinishedMonthOnPlan(String month) =>
      'You finished $month on plan 🎉';
  String introOnTrackDescription(String month) =>
      'You stayed within your monthly budget. Let\'s build $month around what worked.';
  String onTrackOfTotal(int onTrack, int total) => '$onTrack of $total';
  String get pocketsOnBudget => 'Pockets on budget';
  String get greatProgressLastMonth => 'Great progress last month';
  String introProgressDescription(String amount, String month) =>
      'You spent $amount less than the month before. Let\'s keep that momentum going in $month.';
  String spentVsMonth(String month) => 'Spent vs $month';
  String monthIsLookingBusy(String month) => '$month is looking busy';
  String introUpcomingDescription(String amount) =>
      'You already have $amount of recurring payments coming up. Let\'s make sure the rest of your budget fits around them.';
  String get scheduledBills => 'Scheduled bills';
  String yourOrdinalMonthWithMoneko(String ordinal) =>
      'Your $ordinal month with Moneko';
  String introMilestoneDescription(String month) =>
      'We now have enough history to make $month\'s plan more tailored to how you actually spend.';
  String monthsAbbreviation(int count) => '$count mos';
  String get withMoneko => 'With Moneko';
  String get introFreshStartDescription =>
      'A new month and a clean starting point. Set up your plan and Moneko will learn from how you spend.';
  String monthsWithMoneko(int count) => '$count months with Moneko';
}

extension PaywallCommitmentL10nX on AppLocalizations {
  String get paywallLifetimeAvailableAfterSubscriptionEnds =>
      'Cancel your App Store subscription first. You can buy Lifetime after your current access ends.';
  String get paywallLifetimeAlreadyIncludesPlus =>
      'Lifetime already includes Plus access. No other subscription is needed.';
}

/// Bank-connection recovery copy is intentionally kept in the translation
/// catalog; English is the runtime fallback until the normal l10n export runs.
extension BankConnectionsRecoveryL10nX on AppLocalizations {
  String get bankConnectionPersonal => 'Personal';
  String get bankConnectionHousehold => 'Household';
  String get bankConnectionConnected => 'Connected';
  String get bankConnectionRoleGuidance =>
      'A household owner or admin must manage this bank connection.';
}

extension PlaidClassificationReviewL10nX on AppLocalizations {

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

