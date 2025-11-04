// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'No spending yet';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get orContinueWithEmail => 'Or continue with email';

  @override
  String get emailAddress => 'Email address';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get signIn => 'Sign In';

  @override
  String get newToMoneko => 'New to Moneko?';

  @override
  String get createAccount => 'Create account';

  @override
  String get resetYourPassword => 'Reset your password';

  @override
  String get email => 'Email';

  @override
  String get exampleEmail => 'you@example.com';

  @override
  String get cancel => 'Cancel';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get passwordResetEmailSent => 'Password reset email sent. Check your inbox.';

  @override
  String get enterValidEmail => 'Please enter a valid email address';

  @override
  String passwordMinLength(int min) {
    return 'Password must be at least $min characters long';
  }

  @override
  String fullNameMinLength(int min) {
    return 'Full name must be at least $min characters long';
  }

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get fullName => 'Full name';

  @override
  String get createPassword => 'Create a password';

  @override
  String get passwordComplexityRequirement => 'Password must contain at least one uppercase letter, one lowercase letter, and one number';

  @override
  String get passwordRequirementShort => 'Password must be 8+ characters with uppercase, lowercase, and number';

  @override
  String get termsAgreement => 'By creating an account, you agree to our Terms of Service and Privacy Policy';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signInLower => 'Sign in';

  @override
  String get verificationCodeSent => 'Verification code sent successfully';

  @override
  String get verifyYourEmail => 'Verify Your Email';

  @override
  String verificationEmailSentTo(String email) {
    return 'We\'ve sent a 6-digit verification code to $email';
  }

  @override
  String get enterCompleteCode => 'Please enter the complete 6-digit code';

  @override
  String get invalidVerificationCode => 'Invalid verification code';

  @override
  String get verificationCodeExpired => 'Verification code has expired. Please request a new one.';

  @override
  String get verifyEmail => 'Verify Email';

  @override
  String get didntReceiveTheCode => 'Didn\'t receive the code? Check your spam folder or';

  @override
  String resendInSeconds(int seconds) {
    return 'resend in ${seconds}s';
  }

  @override
  String get resendVerificationEmail => 'resend verification email';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signingInWithGoogle => 'Signing in with Google...';

  @override
  String get error => 'Error';

  @override
  String get anErrorOccurred => 'An error occurred';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get goToHome => 'Go to Home';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ Payment successful! Checking subscription...';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get paymentCanceled => 'ℹ️ Payment canceled';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp verified successfully!';

  @override
  String get settings => 'Settings';

  @override
  String get enableNotificationsInSettings => 'Enable notifications for Moneko in your device settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get receiveAlertsAndUpdates => 'Receive alerts and updates';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get membership => 'Membership';

  @override
  String get loading => 'Loading...';

  @override
  String get failedToLoadMembership => 'Failed to load membership';

  @override
  String get couldNotOpenMembershipPage => 'Could not open membership page';

  @override
  String get freePlan => 'Free';

  @override
  String get freePlanStatus => 'Free plan';

  @override
  String get lifetimePlan => 'Lifetime';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus Monthly';

  @override
  String get plusYearlyPlan => 'Plus Yearly';

  @override
  String get activeStatus => 'Active';

  @override
  String get activeLifetimeStatus => 'Active • Lifetime';

  @override
  String get canceledStatus => 'Canceled';

  @override
  String get pastDueStatus => 'Past due';

  @override
  String get trialStatus => 'Trial';

  @override
  String trialEndsInDays(int days) {
    return 'Trial ends in $days days';
  }

  @override
  String get trialEnded => 'Trial ended';

  @override
  String renewsInDays(int days) {
    return 'Renews in $days days';
  }

  @override
  String accessEndsInDays(int days) {
    return 'Access ends in $days days';
  }

  @override
  String get subscriptionEnded => 'Subscription ended';

  @override
  String get profile => 'Profile';

  @override
  String get errorLoadingProfile => 'Error loading profile';

  @override
  String get user => 'User';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp Connected';

  @override
  String get logExpensesViaWhatsApp => 'Log expenses via WhatsApp messages';

  @override
  String get connectWhatsApp => 'Connect WhatsApp';

  @override
  String get newBadge => 'NEW';

  @override
  String get logExpensesInstantly => 'Log expenses instantly via chat';

  @override
  String get fast => 'Fast';

  @override
  String get photo => 'Photo';

  @override
  String get autoSync => 'Auto-sync';

  @override
  String get naturalLanguage => 'Natural Language';

  @override
  String get describeExpenseAutomatically => 'Describe your expense. We’ll log it automatically.';

  @override
  String get snapReceipt => 'Snap Receipt';

  @override
  String get snapReceiptDescription => 'Snap your receipt. AI extracts and logs it.';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get overview => 'Overview';

  @override
  String get activity => 'Activity';

  @override
  String get accountInformation => 'Account Information';

  @override
  String get userId => 'User ID';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get noActivityYet => 'No activity yet';

  @override
  String get signOut => 'Sign Out';

  @override
  String get insights => 'Insights';

  @override
  String get runningTab => 'Running';

  @override
  String get day30Tab => '30-Day';

  @override
  String get longTermTab => 'Long-Term';

  @override
  String get scenarioTab => 'Scenario';

  @override
  String get runningAndDailyBalances => 'Running & Daily Balances';

  @override
  String get budgetVsSpentDescription => 'Budget vs Spent per day with cumulative running balance.';

  @override
  String get runningBalanceLegend => 'Running Balance';

  @override
  String get budgetLegend => 'Budget';

  @override
  String get spentLegend => 'Spent';

  @override
  String get runningBalanceGuide => 'Running balance guide';

  @override
  String get runningBalanceIntro => 'Think of this chart as your personal money coach. Let\'s walk through what it shows and how to use it.';

  @override
  String get day30LookAhead => '30-Day Look-Ahead';

  @override
  String get projectedFromTrailing30Days => 'Projected from trailing 30-day averages.';

  @override
  String get projectedSpendingLegend => 'Projected Spending';

  @override
  String get peek30DaysAhead => 'Peek 30 days ahead';

  @override
  String get day30ForecastIntro => 'This forecast uses the last month of activity to guess how lively the next month might be. Think of it as a weather report for your wallet.';

  @override
  String get longTermProjection => 'Long-Term Projection';

  @override
  String get basedOnHistoricalAverages => 'Based on historical averages; updates automatically with your data.';

  @override
  String get month18ProjectionLegend => '18-Month Projection';

  @override
  String get your18MonthHorizon => 'Your 18-month horizon';

  @override
  String get longTermIntro => 'This projection blends your steady habits with gentle growth assumptions so you can see where today\'s choices lead.';

  @override
  String get aiScenarioPlanning => 'AI Scenario Planning';

  @override
  String get askAiFinancialAdvisor => 'Ask your AI financial advisor if you can afford a future expense';

  @override
  String get canI => 'Can I';

  @override
  String get before => 'before';

  @override
  String get beforePrefix => 'before';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Pick date';

  @override
  String get check => 'Check';

  @override
  String get enterQuestionAndPickDate => 'Please enter a question and pick a date';

  @override
  String get analyzingScenario => 'Analyzing scenario...';

  @override
  String get thisMightTakeAWhile => 'This might take a while';

  @override
  String get whereTheMoneyWent => 'Where the Money Went';

  @override
  String get categoryTotalsForSelectedRange => 'Category totals for the selected range.';

  @override
  String get scenarioCategoriesGuide => 'Make sense of categories';

  @override
  String get categoryGuideIntro => 'Think of this chart as a bird\'s-eye view of where each dollar flew. Here\'s how to read it without needing a calculator.';

  @override
  String get readTheBarChartLikeAPro => 'Read the bar chart like a pro';

  @override
  String get categoryChartDesc => 'Category breakdown for the selected period.';

  @override
  String get whyThisViewIsHelpful => 'Why this view is helpful';

  @override
  String get categoryWhyHelpfulDesc => 'Quickly identify your biggest spending categories and spot trends over time.';

  @override
  String get whatToDoWithTheInsight => 'What to do with the insight';

  @override
  String get categoryWhatToDoDesc => 'Use this information to adjust your budget and spending habits.';

  @override
  String get scenarioAnalysis => 'Scenario Analysis';

  @override
  String get target => 'Target';

  @override
  String get quickStats => 'Quick Stats';

  @override
  String get currentBalance => 'Current Balance';

  @override
  String get projectedNoChange => 'Projected (No Change)';

  @override
  String get avgDailyNet => 'Avg Daily Net';

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get day => 'Day';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get whatYouAreSeeing => 'What you are seeing';

  @override
  String get whyItMatters => 'Why it matters';

  @override
  String get howToRespond => 'How to respond';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Your running balance tracks how much breathing room you have after each day of spending. The daily bars show what you planned versus what you actually spent.';

  @override
  String get runningBalanceWhyMattersDesc => 'Treat this as a friendly pulse check. It helps you notice when you are ahead of plan so you can keep investing, or when a course correction will keep you on track.';

  @override
  String get runningBalanceHowToRespondDesc => 'Use the chart like a coach. Celebrate gains, reset expectations when needed, and give yourself grace—it is about steady progress, not perfection.';

  @override
  String get whatTheForecastShows => 'What the forecast shows';

  @override
  String get day30WhatShowsDesc => 'We blend the past 30 days of spending and income to sketch an average week ahead. It smooths out one-off splurges so you can see the usual rhythm.';

  @override
  String get day30WhyMattersDesc => 'Forward-looking budgets help you stay proactive. Seeing big days ahead lets you set aside cash instead of scrambling later.';

  @override
  String get day30HowToPlaySmartDesc => 'Treat it like a friendly nudge, not a strict rulebook. Adjust your plan with tiny moves that feel doable.';

  @override
  String get howTheProjectionWorks => 'How the projection works';

  @override
  String get longTermHowWorksDesc => 'We roll forward your average income and spending, sprinkling in modest growth so you can see if your plan keeps cash comfortable months ahead.';

  @override
  String get longTermWhyMattersDesc => 'Long horizons make big dreams real. See whether your emergency fund, investments, or big purchases stay on track.';

  @override
  String get longTermMovesToConsiderDesc => 'Use the chart to rehearse future decisions. Small tweaks today compound into big wins later.';

  @override
  String get forMe => 'For me';

  @override
  String get forUs => 'For us';

  @override
  String get home => 'Home';

  @override
  String get reminder => 'Reminder';

  @override
  String get analyzingReceipt => 'Analyzing receipt...';

  @override
  String get analyzingExpense => 'Analyzing expense...';

  @override
  String get noExpenseInformationExtracted => 'No expense information extracted';

  @override
  String get failedToAnalyzeNoData => 'Failed to analyze: No data returned';

  @override
  String get failedToAnalyze => 'Failed to analyze';

  @override
  String get updateBudget => 'Update budget';

  @override
  String get enterNewTotalDailyBudget => 'Enter the new total daily budget.';

  @override
  String get budgetAmount => 'Budget amount';

  @override
  String get save => 'Save';

  @override
  String get enterValidAmountGreaterThan0 => 'Enter a valid amount greater than 0';

  @override
  String get updatingBudget => 'Updating budget...';

  @override
  String get budgetUpdated => 'Budget updated';

  @override
  String get failedToUpdateBudget => 'Failed to update budget';

  @override
  String get loggedSuccessfully => 'Logged successfully';

  @override
  String get view => 'View';

  @override
  String get retry => 'Retry';

  @override
  String get failedToCapturePhoto => 'Failed to capture photo';

  @override
  String get noSpendingData => 'No spending data';

  @override
  String get byCategory => 'By Category';

  @override
  String get noExpensesYet => 'No Expenses Yet';

  @override
  String get startLoggingExpensesToSeeCategories => 'Start logging expenses to see categories';

  @override
  String get selectDateRange => 'Select Date Range';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get describeYourExpense => 'Describe your expense (eg: \"5 for burger, 3 for coffee\")';

  @override
  String get enterExpenseDetails => 'Enter expense details...';

  @override
  String get freeFormText => 'Free-form text';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get transactions => 'Transactions';

  @override
  String get negative => 'Negative';

  @override
  String get positive => 'Positive';

  @override
  String get spendingBreakdown => 'Spending Breakdown';

  @override
  String get spent => 'Spent';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This week';

  @override
  String get lastWeek => 'Last week';

  @override
  String get thisMonth => 'This month';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get customRange => 'Custom range';

  @override
  String get spentToday => 'Your Spending Today';

  @override
  String get spentYesterday => 'Your Spending Yesterday';

  @override
  String get spentThisWeek => 'Your Spending This Week';

  @override
  String get spentLastWeek => 'Your Spending Last Week';

  @override
  String get spentThisMonth => 'Your Spending This Month';

  @override
  String get spentLast30Days => 'Your Spending (last 30 days)';

  @override
  String get spentCustom => 'Spent (custom)';

  @override
  String get todaysBudget => 'Today\'s budget';

  @override
  String get yesterdaysBudget => 'Yesterday\'s budget';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Sum of daily budgets this week';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Sum of daily budgets last week';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Sum of daily budgets this month';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Sum of daily budgets over the last 30 days';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Sum of daily budgets for the selected range';

  @override
  String get netCashflowToday => 'Net cashflow today';

  @override
  String get netCashflowYesterday => 'Net cashflow yesterday';

  @override
  String get netCashflowThisWeek => 'Net cashflow this week';

  @override
  String get netCashflowLastWeek => 'Net cashflow last week';

  @override
  String get netCashflowThisMonth => 'Net cashflow this month';

  @override
  String get netCashflowLast30Days => 'Net cashflow (last 30 days)';

  @override
  String get netCashflowCustom => 'Net cashflow (custom)';

  @override
  String get selectCurrency => 'Select Currency';

  @override
  String get showLessCurrencies => 'Show less currencies';

  @override
  String showAllCurrencies(int count) {
    return 'Show all currencies ($count more)';
  }

  @override
  String get budget => 'Budget';

  @override
  String get spentLabel => 'Spent';

  @override
  String get net => 'Net';

  @override
  String get txn => 'txn';

  @override
  String get txns => 'txns';

  @override
  String get pleaseEnterExpenseDetails => 'Please enter expense details';

  @override
  String get userNotLoggedIn => 'User not logged in';

  @override
  String get errorLoadingHouseholds => 'Error Loading Households';

  @override
  String get welcomeToHouseholds => 'Welcome to Households';

  @override
  String get householdsDescription => 'Manage shared finances with your family, partner, or roommates. Track budgets, split expenses, and collaborate on money decisions.';

  @override
  String get createHousehold => 'Create Household';

  @override
  String get joinWithInvite => 'Join with Invite';

  @override
  String get pleaseUseInvitationLink => 'Please use an invitation link to join a household';

  @override
  String get householdName => 'Household Name';

  @override
  String get householdNameHint => 'e.g., The Smiths';

  @override
  String get pleaseEnterHouseholdName => 'Please enter a household name';

  @override
  String get errorCreatingHousehold => 'Error creating household';

  @override
  String get householdsFeature => 'Households Feature';

  @override
  String get householdsFeatureDescription => 'The Households feature is now available! Manage shared finances with family, partners, or roommates.';

  @override
  String get gotIt => 'Got it!';

  @override
  String get confirmExpense => 'Confirm Expense';

  @override
  String get expenseDetails => 'Expense Details';

  @override
  String get details => 'Details';

  @override
  String get category => 'Category';

  @override
  String get currency => 'Currency';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get notes => 'Notes';

  @override
  String get receipt => 'Receipt';

  @override
  String get saveExpense => 'Save Expense';

  @override
  String get shareWithHousehold => 'Share with household';

  @override
  String get loadingHouseholdMembers => 'Loading household members...';

  @override
  String get selectHouseholdToConfigureSplit => 'Select a household to configure split';

  @override
  String get currencyManagedByHousehold => 'Currency is managed by the household and cannot be changed';

  @override
  String get currencyCannotBeChanged => 'Currency cannot be changed when sharing with a household';

  @override
  String get failedToLoadImage => 'Failed to load image';

  @override
  String get editAmount => 'Edit Amount';

  @override
  String get amount => 'Amount';

  @override
  String get editNotes => 'Edit Notes';

  @override
  String get addANote => 'Add a note...';

  @override
  String get noMembersFoundInHousehold => 'No members found in household';

  @override
  String get errorLoadingMembers => 'Error loading members';

  @override
  String get noExpenseToSave => 'No expense to save';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'Expense saved and shared$splitInfo!';
  }

  @override
  String get expenseSaved => 'Expense saved!';

  @override
  String failedToSave(String error) {
    return 'Failed to save: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Failed to sync currency preference: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Currency updated successfully';

  @override
  String retryFailed(Object error) {
    return 'Retry failed: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'I spent $currencySymbol$amount on $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Enter the new total daily budget.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Please sign in to access household features';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get members => 'Members';

  @override
  String get invites => 'Invites';

  @override
  String get errorLoadingExpenses => 'Error Loading Expenses';

  @override
  String get budgets => 'Budgets';

  @override
  String get loadingHousehold => 'Loading household...';

  @override
  String get remaining => 'Remaining';

  @override
  String get overBudget => 'Over Budget';

  @override
  String get sharedBudgets => 'Shared Budgets';

  @override
  String get netPosition => 'Net position';

  @override
  String get spentByHousehold => 'Spent by Household';

  @override
  String get memberSpending => 'Member Spending';

  @override
  String get spentByHouseholdTooltip => 'This shows the total amount spent by all household members during the selected period. It includes all shared expenses logged by any member of the household.';

  @override
  String get manageMoneyTogether => 'Manage money together with your partner, family, or roommates in one shared space.';

  @override
  String get sharedBudgetsExpenses => 'Shared Budgets & Expenses';

  @override
  String get sharedBudgetsExpensesDesc => 'Set budgets, track spending, and see where your household money goes in real-time.';

  @override
  String get smartExpenseSplitting => 'Smart Expense Splitting';

  @override
  String get smartExpenseSplittingDesc => 'Automatically calculate who owes what with flexible split options: equal, percentage, or custom amounts.';

  @override
  String get stayInSync => 'Stay in Sync';

  @override
  String get stayInSyncDesc => 'Get notified when expenses are added, budgets are reached, or splits need settling.';

  @override
  String get householdSettings => 'Household Settings';

  @override
  String get householdNotFound => 'Household not found';

  @override
  String get coverPhoto => 'Cover Photo';

  @override
  String get changeCoverPhoto => 'Change Cover Photo';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get errorLoadingHousehold => 'Error loading household';

  @override
  String get householdUpdatedSuccessfully => 'Household updated successfully';

  @override
  String get failedToUpdateHousehold => 'Failed to update household';

  @override
  String get inviteMember => 'Invite Member';

  @override
  String get removeMember => 'Remove Member';

  @override
  String get remove => 'Remove';

  @override
  String get confirmRemoveMember => 'Are you sure you want to remove';

  @override
  String get updatedMemberRole => 'Updated member role';

  @override
  String get unknown => 'Unknown';

  @override
  String get makeAdmin => 'Make Admin';

  @override
  String get makeMember => 'Make Member';

  @override
  String get invitations => 'Invitations';

  @override
  String get errorLoadingInvites => 'Error loading invites';

  @override
  String get createInvitation => 'Create Invitation';

  @override
  String get pendingInvitations => 'Pending Invitations';

  @override
  String get noPendingInvitations => 'No pending invitations';

  @override
  String get invitationHistory => 'Invitation History';

  @override
  String get noInvitationHistory => 'No invitation history';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get friendEmailExample => 'friend@example.com';

  @override
  String get personalMessageOptional => 'Personal Message (optional)';

  @override
  String get joinHouseholdBudget => 'Join our household budget!';

  @override
  String get expiresIn => 'Expires In';

  @override
  String get oneDay => '1 Day';

  @override
  String get threeDays => '3 Days';

  @override
  String get sevenDays => '7 Days';

  @override
  String get fourteenDays => '14 Days';

  @override
  String get thirtyDays => '30 Days';

  @override
  String get unlimited => 'Unlimited';

  @override
  String get create => 'Create';

  @override
  String get invitationCreatedSuccessfully => 'Invitation created successfully';

  @override
  String get inviteLinkCopiedToClipboard => 'Invite link copied to clipboard!';

  @override
  String get errorCreatingInvite => 'Error creating invite';

  @override
  String get revokeInvitation => 'Revoke Invitation';

  @override
  String get confirmRevokeInvitation => 'Are you sure you want to revoke this invitation?';

  @override
  String get revoke => 'Revoke';

  @override
  String get invitationRevoked => 'Invitation revoked';

  @override
  String get errorRevokingInvite => 'Error revoking invite';

  @override
  String get anyoneWithLink => 'Anyone with link';

  @override
  String get noExpiry => 'No expiry';

  @override
  String get expired => 'Expired';

  @override
  String get expires => 'Expires';

  @override
  String get copyLink => 'Copy Link';

  @override
  String get selectCoverImage => 'Select Cover Image';

  @override
  String get failedToLoadImages => 'Failed to load images';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get failedToLoad => 'Failed to load';

  @override
  String get imageTooLarge => 'Image too large';

  @override
  String get maxIs => 'Max is';

  @override
  String get unsupportedFileFormat => 'Unsupported file format. Please use JPG, PNG, or WebP.';

  @override
  String get cropCoverImage => 'Crop Cover Image';

  @override
  String get editBudget => 'Edit Budget';

  @override
  String get budgetDetails => 'Budget Details';

  @override
  String get budgetName => 'Budget Name';

  @override
  String get period => 'Period';

  @override
  String get alertThresholds => 'Alert Thresholds';

  @override
  String get warningThreshold => 'Warning Threshold (%)';

  @override
  String get alertThreshold => 'Alert Threshold (%)';

  @override
  String get warningThresholdHelper => 'Alert when budget usage reaches this percentage';

  @override
  String get alertThresholdHelper => 'Critical alert at this percentage';

  @override
  String get budgetStatus => 'Budget Status';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get deletingBudget => 'Deleting budget...';

  @override
  String get savingChanges => 'Saving changes...';

  @override
  String get budgetNameCannotBeEmpty => 'Budget name cannot be empty';

  @override
  String get pleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String get warningThresholdRange => 'Warning threshold must be between 0 and 100';

  @override
  String get alertThresholdRange => 'Alert threshold must be between 0 and 100';

  @override
  String get warningThresholdLessThanAlert => 'Warning threshold must be less than or equal to alert threshold';

  @override
  String get deleteBudget => 'Delete Budget';

  @override
  String get confirmDeleteBudget => 'Are you sure you want to delete';

  @override
  String get thisActionCannotBeUndone => 'This action cannot be undone';

  @override
  String get budgetUpdatedSuccessfully => 'Budget updated successfully';

  @override
  String get budgetDeletedSuccessfully => 'Budget deleted successfully';

  @override
  String get categoryTransfers => 'Transfers';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryUtilities => 'Utilities';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryEntertainmentSubscriptions => 'Entertainment Subscriptions';

  @override
  String get categoryRestaurants => 'Restaurants';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryGroceries => 'Groceries';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryTransportation => 'Transportation';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryFlights => 'Flights';

  @override
  String get categoryVacation => 'Vacation';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryMedical => 'Medical';

  @override
  String get categoryText => 'Text';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryTuition => 'Tuition';

  @override
  String get categorySubscriptions => 'Subscriptions';

  @override
  String get categoryServices => 'Services';

  @override
  String get categoryHousing => 'Housing';

  @override
  String get categoryRent => 'Rent';

  @override
  String get categoryMortgage => 'Mortgage';

  @override
  String get categoryBills => 'Bills';

  @override
  String get categoryInsurance => 'Insurance';

  @override
  String get categorySavings => 'Savings';

  @override
  String get categoryInvestment => 'Investment';

  @override
  String get categoryInvestments => 'Investments';

  @override
  String get categoryIncome => 'Income';

  @override
  String get categorySalary => 'Salary';

  @override
  String get categoryBonus => 'Bonus';

  @override
  String get categoryPets => 'Pets';

  @override
  String get categoryKids => 'Kids';

  @override
  String get categoryFamily => 'Family';

  @override
  String get categoryGifts => 'Gifts';

  @override
  String get categoryCharity => 'Charity';

  @override
  String get categoryFees => 'Fees';

  @override
  String get categoryLoan => 'Loan';

  @override
  String get categoryLoans => 'Loans';

  @override
  String get categoryDebt => 'Debt';

  @override
  String get categoryPersonalCare => 'Personal Care';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryMisc => 'Misc';

  @override
  String get categoryUncategorized => 'Uncategorized';

  @override
  String get deleteBudgetCannotBeUndone => 'This action cannot be undone';

  @override
  String get delete => 'Delete';

  @override
  String get failedToDeleteBudget => 'Failed to delete budget';

  @override
  String get owner => 'Owner';

  @override
  String get admin => 'Admin';

  @override
  String get member => 'Member';

  @override
  String get pending => 'Pending';

  @override
  String get accepted => 'Accepted';

  @override
  String get revoked => 'Revoked';

  @override
  String get tapToChangeCover => 'Tap to change cover';

  @override
  String get personalMessageHint => 'Say something to your invitees (e.g., \"Join our household budget!\")';

  @override
  String get invitationExpiresIn => 'Invitation Expires In';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$days day$_temp0';
  }

  @override
  String get createHouseholdDescription => 'Create a shared space for tracking budgets and expenses with family or roommates.';

  @override
  String get uploadingImage => 'Uploading Image...';

  @override
  String get creating => 'Creating...';

  @override
  String get generatingInvite => 'Generating Invite...';

  @override
  String get pleaseSelectValidCurrency => 'Please select a valid household currency';

  @override
  String nameMaxLength(int max) {
    return 'Name must be less than $max characters';
  }

  @override
  String get createHouseholdPage => 'Create household page';

  @override
  String get invitationPersonalMessageInput => 'Invitation personal message input';

  @override
  String get householdNameInput => 'Household name input';

  @override
  String get invitationExpirationSelector => 'Invitation expiration selector';

  @override
  String get unlimitedExpiration => 'Unlimited expiration';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$days day$_temp0 expiration';
  }

  @override
  String get householdInformation => 'Household information';

  @override
  String get creatingHousehold => 'Creating household';

  @override
  String get createHouseholdButton => 'Create household button';

  @override
  String get searchExpenses => 'Search expenses...';

  @override
  String get clearAll => 'Clear All';

  @override
  String get allCategories => 'All Categories';

  @override
  String get allMembers => 'All Members';

  @override
  String get balanceSummary => 'Balance Summary';

  @override
  String get youAreOwed => 'You are owed';

  @override
  String get youOwe => 'You owe';

  @override
  String get youOweOthers => 'You owe others';

  @override
  String get othersOweYou => 'Others owe you';

  @override
  String get viewDetails => 'View Details';

  @override
  String get settleUp => 'Settle Up';

  @override
  String get markExpensesAsSettled => 'Mark expenses as settled to update balances';

  @override
  String get whoAreYouSettlingWith => 'Who are you settling with?';

  @override
  String get selectMember => 'Select Member';

  @override
  String get amountToSettle => 'Amount to settle';

  @override
  String get howDidYouSettle => 'How did you settle?';

  @override
  String get cash => 'Cash';

  @override
  String get paidInCash => 'Paid in cash';

  @override
  String get bankTransfer => 'Bank Transfer';

  @override
  String get transferredViaBank => 'Transferred via bank';

  @override
  String get mobilePayment => 'Mobile Payment';

  @override
  String get venmoPaypalEtc => 'Venmo, PayPal, etc.';

  @override
  String get search => 'Search';

  @override
  String get noData => 'No data';

  @override
  String get filterTransactions => 'Filter Transactions';

  @override
  String get noTransactionsFound => 'No transactions found';

  @override
  String get failedToLoadHouseholdTransactions => 'Failed to load household transactions';

  @override
  String get reset => 'Reset';

  @override
  String get apply => 'Apply';

  @override
  String get expenses => 'Expenses';

  @override
  String get dateRange => 'Date Range';

  @override
  String get noMatchingExpenses => 'No Matching Expenses';

  @override
  String get startLoggingExpenses => 'Start logging expenses to see them here';

  @override
  String get tryAdjustingFilters => 'Try adjusting your filters';

  @override
  String get split => 'Split';

  @override
  String get note => 'Note';

  @override
  String get currencyCannotBeChangedWhenSharing => 'Currency cannot be changed when sharing with a household';

  @override
  String get createBudget => 'Create Budget';

  @override
  String get pleaseEnterABudgetName => 'Please enter a budget name';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Please enter a valid amount greater than 0';

  @override
  String get warningThresholdMustBeBetween0And100 => 'Warning threshold must be between 0 and 100%';

  @override
  String get alertThresholdMustBeBetween0And100 => 'Alert threshold must be between 0 and 100%';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'Warning threshold must be less than or equal to alert threshold';

  @override
  String get budgetCreatedSuccessfully => 'Budget created successfully!';

  @override
  String get failedToCreateBudget => 'Failed to create budget';

  @override
  String get groceriesRentEntertainment => 'e.g., Groceries, Rent, Entertainment';

  @override
  String get budgetType => 'Budget Type';

  @override
  String get sharedWithAllHouseholdMembers => 'Shared with all household members';

  @override
  String get personalBudgetForYourExpensesOnly => 'Personal budget for your expenses only';

  @override
  String get countSplitPortionOnly => 'Count Split Portion Only';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Only count your portion of split expenses towards this budget';

  @override
  String get joinHousehold => 'Join Household';

  @override
  String get joinAHousehold => 'Join a Household';

  @override
  String get enterYourInvitationLinkToJoin => 'Enter your invitation link to join\na shared financial space';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Paste the invitation link you received from a household member';

  @override
  String get pasteInvitationLink => 'Paste invitation link';

  @override
  String get pleaseEnterAnInvitationLink => 'Please enter an invitation link';

  @override
  String get pleaseEnterAValidInvitationLink => 'Please enter a valid invitation link';

  @override
  String get paste => 'Paste';

  @override
  String get validating => 'Validating...';

  @override
  String get continueAction => 'Continue';

  @override
  String get welcomeAboard => 'Welcome Aboard!';

  @override
  String get youreNowPartOfTheHousehold => 'You\'re now part of the household.\nStart collaborating on your finances!';

  @override
  String get thisWillOnlyTakeAMoment => 'This will only take a moment';

  @override
  String get unableToJoin => 'Unable to Join';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get goToHousehold => 'Go to Household';

  @override
  String get expiresSoon => 'Expires soon';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Invitation valid until $formattedDate';
  }

  @override
  String get whatYoullGet => 'What you\'ll get';

  @override
  String get viewSharedBudgetsAndExpenses => 'View shared budgets and expenses';

  @override
  String get trackHouseholdFinancialHealth => 'Track household financial health';

  @override
  String get collaborateOnFinancialDecisions => 'Collaborate on financial decisions';

  @override
  String get household => 'Household';

  @override
  String get viewAll => 'View All';

  @override
  String get manage => 'Manage';

  @override
  String get noBudgetsYet => 'No budgets yet';

  @override
  String get createSharedBudgetDescription => 'Create a shared budget to track spending together';

  @override
  String get errorLoadingBudgets => 'Error loading budgets';

  @override
  String get recentSplits => 'Recent Splits';

  @override
  String get invite => 'Invite';

  @override
  String get last6Months => 'Last 6 months';

  @override
  String get thisYear => 'This year';

  @override
  String get allTime => 'All time';

  @override
  String nameMinLength(int min) {
    return 'Name must be at least $min characters';
  }

  @override
  String get splitExpense => 'Split Expense';

  @override
  String get percent => 'Percent';

  @override
  String get splitShare => 'Share';

  @override
  String get owes => 'Owes';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'Split amounts must equal $currency$amount';
  }

  @override
  String get percentagesMustTotal100 => 'Percentages must total 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'Each person must have at least 1 share';

  @override
  String get whatsappVerified => 'WhatsApp Verified';

  @override
  String get whatsappVerification => 'WhatsApp Verification';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Your WhatsApp number is successfully linked to your account';

  @override
  String get verifyingYourWhatsAppNumber => 'Verifying your WhatsApp number...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Enter the 6-digit code from WhatsApp';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Please enter the 6-digit verification code';

  @override
  String get failedToVerifyCode => 'Failed to verify code';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Failed to verify code. Please try again.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Code auto-filled from verification link';

  @override
  String get verify => 'Verify';

  @override
  String get verifying => 'Verifying...';

  @override
  String get avatarStudio => 'Avatar Studio';

  @override
  String get preview => 'Preview';

  @override
  String get colors => 'Colors';

  @override
  String get randomize => 'Randomize';

  @override
  String get saveAvatar => 'Save Avatar';

  @override
  String get saving => 'Saving...';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get selectColor => 'Select Color';

  @override
  String get failedToSaveAvatar => 'Failed to save avatar';

  @override
  String get hair => 'Hair';

  @override
  String get eyes => 'Eyes';

  @override
  String get mouth => 'Mouth';

  @override
  String get background => 'Background';

  @override
  String get face => 'Face';

  @override
  String get ears => 'Ears';

  @override
  String get shirts => 'Shirts';

  @override
  String get brow => 'Brow';

  @override
  String get nose => 'Nose';

  @override
  String get blush => 'Blush';

  @override
  String get accessories => 'Accessories';

  @override
  String get stars => 'Stars';

  @override
  String get currencyIsManagedByHousehold => 'Currency is managed by the household and cannot be changed';

  @override
  String get buyALaptop => 'buy a \$1,200 laptop';

  @override
  String get selectTargetDate => 'Select target date';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'Can I $action before $date';
  }

  @override
  String get scenarioDateFormat => 'MM/dd/yyyy';

  @override
  String analysisFailed(String error) {
    return 'Analysis failed: $error';
  }

  @override
  String get leftHandChamps => 'The left-hand champs are your heavy hitters—perfect candidates for a quick review.';

  @override
  String get smallButFrequent => 'Small but frequent categories hint at habits that may sneak up over time.';

  @override
  String get colorMatches => 'Color matches what you see on the Home tab so your brain stays comfy.';

  @override
  String get planningNewGoal => 'Planning a new goal? Spot categories to trim without touching the fun stuff.';

  @override
  String get eyeingTreatYourself => 'Eyeing a treat-yourself month? See which areas can flex safely.';

  @override
  String get doubleCheckTagging => 'Use it to double-check that new expenses were tagged correctly—no ghosts allowed.';

  @override
  String get slideHighBar => 'Slide a high bar down a notch by setting a mini limit or switching to lower-cost swaps.';

  @override
  String get nonNegotiable => 'If a bar is non-negotiable (hello, rent), plan around it instead of fighting it.';

  @override
  String get revisitAfterScenario => 'Revisit after running a scenario to see whether your adjustments stick.';

  @override
  String get purpleLineCushion => 'Purple line: the cushion left after each day. Rising lines mean you are building momentum.';

  @override
  String get blueBarsBudget => 'Blue bars: the budget you set for that day.';

  @override
  String get redBarsSpent => 'Red bars: what actually left your account.';

  @override
  String get lineTrendingUpward => 'Line trending upward = extra cash you can redirect toward savings goals.';

  @override
  String get flatDippingLine => 'Flat or dipping line = time to pause and review big-ticket items.';

  @override
  String get sharpDrops => 'Sharp drops often match unplanned purchases—tap them to inspect the details.';

  @override
  String get lineRisingDays => 'Line rising for several days? Consider moving a little extra into savings or debt payoff.';

  @override
  String get lineDippingWeekend => 'Line dipping after a busy weekend? Rebalance upcoming days by trimming small discretionary spends.';

  @override
  String get feelStuckRed => 'Feel stuck in the red? Revisit your budget in the Home tab—small adjustments add up quickly.';

  @override
  String get thirtyDayForecastDesc => 'This forecast uses the last month of activity to guess how lively the next month might be. Think of it as a weather report for your wallet.';

  @override
  String get greenLineExpected => 'Green line = expected daily spend if the coming month behaves like the last one.';

  @override
  String get spikesHighlight => 'Spikes highlight weeks where your habits usually get pricier (hello, Friday takeaway).';

  @override
  String get forecastUpdates => 'When you log fresh transactions, the forecast gently updates—no need to refresh.';

  @override
  String get spotExpensivePatterns => 'Spot expensive patterns early and stash a mini-buffer before they arrive.';

  @override
  String get catchQuieterWeeks => 'Catch quieter weeks where you can sweep extra cash into savings or debt payoff.';

  @override
  String get timeRecurringPayments => 'Use the insight to time recurring payments, subscriptions, or top-ups.';

  @override
  String get bigSpikeComing => 'Big spike coming? Pre-book cheaper options or shuffle flexible spends to calmer days.';

  @override
  String get forecastDipping => 'Forecast dipping? Reward yourself by scheduling an extra savings transfer.';

  @override
  String get forecastLooksOff => 'If the forecast looks off, review categories in the Home tab to tidy up any mislabels.';

  @override
  String get greenLineTrends => 'Green line trends with your typical savings rate—upward momentum means your goals are funded.';

  @override
  String get lineDipsSignals => 'If the line dips, it signals future months where expenses tend to outrun income.';

  @override
  String get largeGoalsDebts => 'Large goals or debts are included when you tag them in the Home tab.';

  @override
  String get upwardSlope => 'An upward slope? Celebrate and consider boosting retirement or travel savings.';

  @override
  String get flatSlipping => 'Flat or slipping? Time to tune budgets or boost income streams before it snowballs.';

  @override
  String get watchSeasonalTrends => 'Watch for seasonal trends—holidays, school terms, or annual renewals often show here first.';

  @override
  String get schedulePaymentIncreases => 'Schedule gentle payment increases on loans when the curve is rising.';

  @override
  String get planAheadDips => 'Plan ahead for dips by earmarking sinking funds or trimming optional spends.';

  @override
  String get checkProjectionMonthly => 'Check the projection monthly to keep your long game fun and flexible.';

  @override
  String get categoryHealthcare => 'Healthcare';

  @override
  String get categoryOther => 'Other';

  @override
  String get deleteExpense => 'Delete Expense';

  @override
  String get confirmDeleteExpense => 'Are you sure you want to delete this expense? This action cannot be undone.';

  @override
  String get expenseDeletedSuccessfully => 'Expense deleted successfully';

  @override
  String get failedToDeleteExpense => 'Failed to delete expense';

  @override
  String get expenseNotFoundOrDeleted => 'Expense not found or has been deleted';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Only admins and owners can edit household settings';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Only admins and owners can create invitations';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Share invitation for $householdName household';
  }

  @override
  String get shareInvitation => 'Share Invitation';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Household $householdName created successfully';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'Household \"$householdName\" created successfully!';
  }

  @override
  String get invitationLink => 'Invitation Link';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Invitation link: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Copy invitation link';

  @override
  String get copyInvitationLinkToClipboard => 'Copy invitation link to clipboard';

  @override
  String get shareInvitationLink => 'Share invitation link';

  @override
  String get share => 'Share';

  @override
  String get closeShareSheet => 'Close share sheet';

  @override
  String get invitationLinkCopiedToClipboard => 'Invitation link copied to clipboard!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Join my household \"$householdName\" on Moneko!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Join my household on Moneko';

  @override
  String get zeroAmount => '0.00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get budgetBoop => 'Budget Boop';

  @override
  String get getGentleReminder => 'Get a gentle reminder when you reach this threshold';

  @override
  String get purrSuasiveNudge => 'Purr-suasive Nudge';

  @override
  String get getStrongerNudge => 'Get a stronger nudge when you reach this threshold';

  @override
  String get createBudgetButton => 'Create Budget';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get householdBudgetType => 'Household Budget';

  @override
  String get personalBudgetType => 'Personal Budget';

  @override
  String joinHouseholdName(String householdName) {
    return 'Join \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Household preview: $householdName, invited by $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Invited by $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'Invitation expires soon on $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Invitation valid until';

  @override
  String get personalMessageFromInviter => 'Personal message from inviter';

  @override
  String get messageFromInviter => 'Message from inviter';

  @override
  String get joiningHousehold => 'Joining household...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Error: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'An unexpected error occurred';

  @override
  String get invalidInvitationLinkFormat => 'Invalid invitation link format';

  @override
  String get invalidOrExpiredInvitation => 'Invalid or expired invitation';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String inDays(int days) {
    return 'in $days days';
  }

  @override
  String get january => 'Jan';

  @override
  String get february => 'Feb';

  @override
  String get march => 'Mar';

  @override
  String get april => 'Apr';

  @override
  String get may => 'May';

  @override
  String get june => 'Jun';

  @override
  String get july => 'Jul';

  @override
  String get august => 'Aug';

  @override
  String get september => 'Sep';

  @override
  String get october => 'Oct';

  @override
  String get november => 'Nov';

  @override
  String get december => 'Dec';

  @override
  String remindUser(String name) {
    return 'Remind $name';
  }

  @override
  String get sendFriendlySpendingReminder => 'Send a friendly spending reminder';

  @override
  String get addMessageOptional => 'Add a message (optional)';

  @override
  String get messageHintExample => 'e.g. \"Your wallet needs a rest!\"';

  @override
  String get sendReminder => 'Send Reminder';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Please wait 24 hours before sending another reminder to $name';
  }

  @override
  String reminderSentToName(String name) {
    return 'Reminder sent to $name! 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'Failed to send reminder. Please try again.';
}
