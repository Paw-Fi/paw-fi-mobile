import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_kr.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pks.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('kr'),
    Locale('nl'),
    Locale('pks'),
    Locale('ru'),
    Locale('uk'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Moneko'**
  String get appTitle;

  /// No description provided for @noSpendingYet.
  ///
  /// In en, this message translates to:
  /// **'No spending yet'**
  String get noSpendingYet;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @orContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Or continue with email'**
  String get orContinueWithEmail;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @newToMoneko.
  ///
  /// In en, this message translates to:
  /// **'New to Moneko?'**
  String get newToMoneko;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @resetYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetYourPassword;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @exampleEmail.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get exampleEmail;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get passwordResetEmailSent;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get enterValidEmail;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {min} characters long'**
  String passwordMinLength(int min);

  /// No description provided for @fullNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Full name must be at least {min} characters long'**
  String fullNameMinLength(int min);

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get createPassword;

  /// No description provided for @passwordComplexityRequirement.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one uppercase letter, one lowercase letter, and one number'**
  String get passwordComplexityRequirement;

  /// No description provided for @passwordRequirementShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be 8+ characters with uppercase, lowercase, and number'**
  String get passwordRequirementShort;

  /// No description provided for @termsAgreement.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms of Service and Privacy Policy'**
  String get termsAgreement;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @signInLower.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInLower;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent successfully'**
  String get verificationCodeSent;

  /// No description provided for @verifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyYourEmail;

  /// No description provided for @verificationEmailSentTo.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit verification code to {email}'**
  String verificationEmailSentTo(String email);

  /// No description provided for @enterCompleteCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the complete 6-digit code'**
  String get enterCompleteCode;

  /// No description provided for @invalidVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code'**
  String get invalidVerificationCode;

  /// No description provided for @verificationCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Verification code has expired. Please request a new one.'**
  String get verificationCodeExpired;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmail;

  /// No description provided for @didntReceiveTheCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? Check your spam folder or'**
  String get didntReceiveTheCode;

  /// No description provided for @resendInSeconds.
  ///
  /// In en, this message translates to:
  /// **'resend in {seconds}s'**
  String resendInSeconds(int seconds);

  /// No description provided for @resendVerificationEmail.
  ///
  /// In en, this message translates to:
  /// **'resend verification email'**
  String get resendVerificationEmail;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @signingInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signing in with Google...'**
  String get signingInWithGoogle;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @goToHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goToHome;

  /// No description provided for @paymentSuccessfulCheckingSubscription.
  ///
  /// In en, this message translates to:
  /// **'✅ Payment successful! Checking subscription...'**
  String get paymentSuccessfulCheckingSubscription;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @paymentCanceled.
  ///
  /// In en, this message translates to:
  /// **'ℹ️ Payment canceled'**
  String get paymentCanceled;

  /// No description provided for @whatsappVerifiedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'✅ WhatsApp verified successfully!'**
  String get whatsappVerifiedSuccessfully;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @enableNotificationsInSettings.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications for Moneko in your device settings'**
  String get enableNotificationsInSettings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @receiveAlertsAndUpdates.
  ///
  /// In en, this message translates to:
  /// **'Receive alerts and updates'**
  String get receiveAlertsAndUpdates;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @membership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get membership;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @failedToLoadMembership.
  ///
  /// In en, this message translates to:
  /// **'Failed to load membership'**
  String get failedToLoadMembership;

  /// No description provided for @couldNotOpenMembershipPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open membership page'**
  String get couldNotOpenMembershipPage;

  /// No description provided for @freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freePlan;

  /// No description provided for @freePlanStatus.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get freePlanStatus;

  /// No description provided for @lifetimePlan.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get lifetimePlan;

  /// No description provided for @plusPlan.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get plusPlan;

  /// No description provided for @plusMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Plus Monthly'**
  String get plusMonthlyPlan;

  /// No description provided for @plusYearlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Plus Yearly'**
  String get plusYearlyPlan;

  /// No description provided for @activeStatus.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeStatus;

  /// No description provided for @activeLifetimeStatus.
  ///
  /// In en, this message translates to:
  /// **'Active • Lifetime'**
  String get activeLifetimeStatus;

  /// No description provided for @canceledStatus.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceledStatus;

  /// No description provided for @pastDueStatus.
  ///
  /// In en, this message translates to:
  /// **'Past due'**
  String get pastDueStatus;

  /// No description provided for @trialStatus.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get trialStatus;

  /// No description provided for @trialEndsInDays.
  ///
  /// In en, this message translates to:
  /// **'Trial ends in {days} days'**
  String trialEndsInDays(int days);

  /// No description provided for @trialEnded.
  ///
  /// In en, this message translates to:
  /// **'Trial ended'**
  String get trialEnded;

  /// No description provided for @renewsInDays.
  ///
  /// In en, this message translates to:
  /// **'Renews in {days} days'**
  String renewsInDays(int days);

  /// No description provided for @accessEndsInDays.
  ///
  /// In en, this message translates to:
  /// **'Access ends in {days} days'**
  String accessEndsInDays(int days);

  /// No description provided for @subscriptionEnded.
  ///
  /// In en, this message translates to:
  /// **'Subscription ended'**
  String get subscriptionEnded;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error loading profile'**
  String get errorLoadingProfile;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @whatsAppConnected.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Connected'**
  String get whatsAppConnected;

  /// No description provided for @logExpensesViaWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Log expenses via WhatsApp messages'**
  String get logExpensesViaWhatsApp;

  /// No description provided for @connectWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Connect WhatsApp'**
  String get connectWhatsApp;

  /// No description provided for @newBadge.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newBadge;

  /// No description provided for @logExpensesInstantly.
  ///
  /// In en, this message translates to:
  /// **'Log expenses instantly via chat'**
  String get logExpensesInstantly;

  /// No description provided for @fast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get fast;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync'**
  String get autoSync;

  /// No description provided for @naturalLanguage.
  ///
  /// In en, this message translates to:
  /// **'Natural Language'**
  String get naturalLanguage;

  /// No description provided for @describeExpenseAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Describe your expense. We’ll log it automatically.'**
  String get describeExpenseAutomatically;

  /// No description provided for @snapReceipt.
  ///
  /// In en, this message translates to:
  /// **'Snap Receipt'**
  String get snapReceipt;

  /// No description provided for @snapReceiptDescription.
  ///
  /// In en, this message translates to:
  /// **'Snap your receipt. AI extracts and logs it.'**
  String get snapReceiptDescription;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivityYet;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @runningTab.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get runningTab;

  /// No description provided for @day30Tab.
  ///
  /// In en, this message translates to:
  /// **'30-Day'**
  String get day30Tab;

  /// No description provided for @longTermTab.
  ///
  /// In en, this message translates to:
  /// **'Long-Term'**
  String get longTermTab;

  /// No description provided for @scenarioTab.
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get scenarioTab;

  /// No description provided for @runningAndDailyBalances.
  ///
  /// In en, this message translates to:
  /// **'Running & Daily Balances'**
  String get runningAndDailyBalances;

  /// No description provided for @budgetVsSpentDescription.
  ///
  /// In en, this message translates to:
  /// **'Budget vs Spent per day with cumulative running balance.'**
  String get budgetVsSpentDescription;

  /// No description provided for @runningBalanceLegend.
  ///
  /// In en, this message translates to:
  /// **'Running Balance'**
  String get runningBalanceLegend;

  /// No description provided for @budgetLegend.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetLegend;

  /// No description provided for @spentLegend.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentLegend;

  /// No description provided for @runningBalanceGuide.
  ///
  /// In en, this message translates to:
  /// **'Running balance guide'**
  String get runningBalanceGuide;

  /// No description provided for @runningBalanceIntro.
  ///
  /// In en, this message translates to:
  /// **'Think of this chart as your personal money coach. Let\'s walk through what it shows and how to use it.'**
  String get runningBalanceIntro;

  /// No description provided for @day30LookAhead.
  ///
  /// In en, this message translates to:
  /// **'30-Day Look-Ahead'**
  String get day30LookAhead;

  /// No description provided for @projectedFromTrailing30Days.
  ///
  /// In en, this message translates to:
  /// **'Projected from trailing 30-day averages.'**
  String get projectedFromTrailing30Days;

  /// No description provided for @projectedSpendingLegend.
  ///
  /// In en, this message translates to:
  /// **'Projected Spending'**
  String get projectedSpendingLegend;

  /// No description provided for @peek30DaysAhead.
  ///
  /// In en, this message translates to:
  /// **'Peek 30 days ahead'**
  String get peek30DaysAhead;

  /// No description provided for @day30ForecastIntro.
  ///
  /// In en, this message translates to:
  /// **'This forecast uses the last month of activity to guess how lively the next month might be. Think of it as a weather report for your wallet.'**
  String get day30ForecastIntro;

  /// No description provided for @longTermProjection.
  ///
  /// In en, this message translates to:
  /// **'Long-Term Projection'**
  String get longTermProjection;

  /// No description provided for @basedOnHistoricalAverages.
  ///
  /// In en, this message translates to:
  /// **'Based on historical averages; updates automatically with your data.'**
  String get basedOnHistoricalAverages;

  /// No description provided for @month18ProjectionLegend.
  ///
  /// In en, this message translates to:
  /// **'18-Month Projection'**
  String get month18ProjectionLegend;

  /// No description provided for @your18MonthHorizon.
  ///
  /// In en, this message translates to:
  /// **'Your 18-month horizon'**
  String get your18MonthHorizon;

  /// No description provided for @longTermIntro.
  ///
  /// In en, this message translates to:
  /// **'This projection blends your steady habits with gentle growth assumptions so you can see where today\'s choices lead.'**
  String get longTermIntro;

  /// No description provided for @aiScenarioPlanning.
  ///
  /// In en, this message translates to:
  /// **'AI Scenario Planning'**
  String get aiScenarioPlanning;

  /// No description provided for @askAiFinancialAdvisor.
  ///
  /// In en, this message translates to:
  /// **'Ask your AI financial advisor if you can afford a future expense'**
  String get askAiFinancialAdvisor;

  /// No description provided for @canI.
  ///
  /// In en, this message translates to:
  /// **'Can I'**
  String get canI;

  /// No description provided for @before.
  ///
  /// In en, this message translates to:
  /// **'before'**
  String get before;

  /// No description provided for @beforePrefix.
  ///
  /// In en, this message translates to:
  /// **'before'**
  String get beforePrefix;

  /// No description provided for @beforeSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get beforeSuffix;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get pickDate;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @enterQuestionAndPickDate.
  ///
  /// In en, this message translates to:
  /// **'Please enter a question and pick a date'**
  String get enterQuestionAndPickDate;

  /// No description provided for @analyzingScenario.
  ///
  /// In en, this message translates to:
  /// **'Analyzing scenario...'**
  String get analyzingScenario;

  /// No description provided for @thisMightTakeAWhile.
  ///
  /// In en, this message translates to:
  /// **'This might take a while'**
  String get thisMightTakeAWhile;

  /// No description provided for @whereTheMoneyWent.
  ///
  /// In en, this message translates to:
  /// **'Where the Money Went'**
  String get whereTheMoneyWent;

  /// No description provided for @categoryTotalsForSelectedRange.
  ///
  /// In en, this message translates to:
  /// **'Category totals for the selected range.'**
  String get categoryTotalsForSelectedRange;

  /// No description provided for @scenarioCategoriesGuide.
  ///
  /// In en, this message translates to:
  /// **'Make sense of categories'**
  String get scenarioCategoriesGuide;

  /// No description provided for @categoryGuideIntro.
  ///
  /// In en, this message translates to:
  /// **'Think of this chart as a bird\'s-eye view of where each dollar flew. Here\'s how to read it without needing a calculator.'**
  String get categoryGuideIntro;

  /// No description provided for @readTheBarChartLikeAPro.
  ///
  /// In en, this message translates to:
  /// **'Read the bar chart like a pro'**
  String get readTheBarChartLikeAPro;

  /// No description provided for @categoryChartDesc.
  ///
  /// In en, this message translates to:
  /// **'Category breakdown for the selected period.'**
  String get categoryChartDesc;

  /// No description provided for @whyThisViewIsHelpful.
  ///
  /// In en, this message translates to:
  /// **'Why this view is helpful'**
  String get whyThisViewIsHelpful;

  /// No description provided for @categoryWhyHelpfulDesc.
  ///
  /// In en, this message translates to:
  /// **'Quickly identify your biggest spending categories and spot trends over time.'**
  String get categoryWhyHelpfulDesc;

  /// No description provided for @whatToDoWithTheInsight.
  ///
  /// In en, this message translates to:
  /// **'What to do with the insight'**
  String get whatToDoWithTheInsight;

  /// No description provided for @categoryWhatToDoDesc.
  ///
  /// In en, this message translates to:
  /// **'Use this information to adjust your budget and spending habits.'**
  String get categoryWhatToDoDesc;

  /// No description provided for @scenarioAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Scenario Analysis'**
  String get scenarioAnalysis;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @quickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick Stats'**
  String get quickStats;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @projectedNoChange.
  ///
  /// In en, this message translates to:
  /// **'Projected (No Change)'**
  String get projectedNoChange;

  /// No description provided for @avgDailyNet.
  ///
  /// In en, this message translates to:
  /// **'Avg Daily Net'**
  String get avgDailyNet;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @whatYouAreSeeing.
  ///
  /// In en, this message translates to:
  /// **'What you are seeing'**
  String get whatYouAreSeeing;

  /// No description provided for @whyItMatters.
  ///
  /// In en, this message translates to:
  /// **'Why it matters'**
  String get whyItMatters;

  /// No description provided for @howToRespond.
  ///
  /// In en, this message translates to:
  /// **'How to respond'**
  String get howToRespond;

  /// No description provided for @runningBalanceWhatYouSeeDesc.
  ///
  /// In en, this message translates to:
  /// **'Your running balance tracks how much breathing room you have after each day of spending. The daily bars show what you planned versus what you actually spent.'**
  String get runningBalanceWhatYouSeeDesc;

  /// No description provided for @runningBalanceWhyMattersDesc.
  ///
  /// In en, this message translates to:
  /// **'Treat this as a friendly pulse check. It helps you notice when you are ahead of plan so you can keep investing, or when a course correction will keep you on track.'**
  String get runningBalanceWhyMattersDesc;

  /// No description provided for @runningBalanceHowToRespondDesc.
  ///
  /// In en, this message translates to:
  /// **'Use the chart like a coach. Celebrate gains, reset expectations when needed, and give yourself grace—it is about steady progress, not perfection.'**
  String get runningBalanceHowToRespondDesc;

  /// No description provided for @whatTheForecastShows.
  ///
  /// In en, this message translates to:
  /// **'What the forecast shows'**
  String get whatTheForecastShows;

  /// No description provided for @day30WhatShowsDesc.
  ///
  /// In en, this message translates to:
  /// **'We blend the past 30 days of spending and income to sketch an average week ahead. It smooths out one-off splurges so you can see the usual rhythm.'**
  String get day30WhatShowsDesc;

  /// No description provided for @day30WhyMattersDesc.
  ///
  /// In en, this message translates to:
  /// **'Forward-looking budgets help you stay proactive. Seeing big days ahead lets you set aside cash instead of scrambling later.'**
  String get day30WhyMattersDesc;

  /// No description provided for @day30HowToPlaySmartDesc.
  ///
  /// In en, this message translates to:
  /// **'Treat it like a friendly nudge, not a strict rulebook. Adjust your plan with tiny moves that feel doable.'**
  String get day30HowToPlaySmartDesc;

  /// No description provided for @howTheProjectionWorks.
  ///
  /// In en, this message translates to:
  /// **'How the projection works'**
  String get howTheProjectionWorks;

  /// No description provided for @longTermHowWorksDesc.
  ///
  /// In en, this message translates to:
  /// **'We roll forward your average income and spending, sprinkling in modest growth so you can see if your plan keeps cash comfortable months ahead.'**
  String get longTermHowWorksDesc;

  /// No description provided for @longTermWhyMattersDesc.
  ///
  /// In en, this message translates to:
  /// **'Long horizons make big dreams real. See whether your emergency fund, investments, or big purchases stay on track.'**
  String get longTermWhyMattersDesc;

  /// No description provided for @longTermMovesToConsiderDesc.
  ///
  /// In en, this message translates to:
  /// **'Use the chart to rehearse future decisions. Small tweaks today compound into big wins later.'**
  String get longTermMovesToConsiderDesc;

  /// No description provided for @forMe.
  ///
  /// In en, this message translates to:
  /// **'For me'**
  String get forMe;

  /// No description provided for @forUs.
  ///
  /// In en, this message translates to:
  /// **'For us'**
  String get forUs;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @analyzingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Analyzing receipt...'**
  String get analyzingReceipt;

  /// No description provided for @analyzingExpense.
  ///
  /// In en, this message translates to:
  /// **'Analyzing expense...'**
  String get analyzingExpense;

  /// No description provided for @noExpenseInformationExtracted.
  ///
  /// In en, this message translates to:
  /// **'No expense information extracted'**
  String get noExpenseInformationExtracted;

  /// No description provided for @failedToAnalyzeNoData.
  ///
  /// In en, this message translates to:
  /// **'Failed to analyze: No data returned'**
  String get failedToAnalyzeNoData;

  /// No description provided for @failedToAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Failed to analyze'**
  String get failedToAnalyze;

  /// No description provided for @updateBudget.
  ///
  /// In en, this message translates to:
  /// **'Update budget'**
  String get updateBudget;

  /// No description provided for @enterNewTotalDailyBudget.
  ///
  /// In en, this message translates to:
  /// **'Enter the new total daily budget.'**
  String get enterNewTotalDailyBudget;

  /// No description provided for @budgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget amount'**
  String get budgetAmount;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enterValidAmountGreaterThan0.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount greater than 0'**
  String get enterValidAmountGreaterThan0;

  /// No description provided for @updatingBudget.
  ///
  /// In en, this message translates to:
  /// **'Updating budget...'**
  String get updatingBudget;

  /// No description provided for @budgetUpdated.
  ///
  /// In en, this message translates to:
  /// **'Budget updated'**
  String get budgetUpdated;

  /// No description provided for @failedToUpdateBudget.
  ///
  /// In en, this message translates to:
  /// **'Failed to update budget'**
  String get failedToUpdateBudget;

  /// No description provided for @loggedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Logged successfully'**
  String get loggedSuccessfully;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @failedToCapturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to capture photo'**
  String get failedToCapturePhoto;

  /// No description provided for @noSpendingData.
  ///
  /// In en, this message translates to:
  /// **'No spending data'**
  String get noSpendingData;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get byCategory;

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No Expenses Yet'**
  String get noExpensesYet;

  /// No description provided for @startLoggingExpensesToSeeCategories.
  ///
  /// In en, this message translates to:
  /// **'Start logging expenses to see categories'**
  String get startLoggingExpensesToSeeCategories;

  /// No description provided for @selectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range'**
  String get selectDateRange;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @describeYourExpense.
  ///
  /// In en, this message translates to:
  /// **'Describe your expense (eg: \"5 for burger, 3 for coffee\")'**
  String get describeYourExpense;

  /// No description provided for @enterExpenseDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter expense details...'**
  String get enterExpenseDetails;

  /// No description provided for @freeFormText.
  ///
  /// In en, this message translates to:
  /// **'Free-form text'**
  String get freeFormText;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @negative.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get negative;

  /// No description provided for @positive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get positive;

  /// No description provided for @spendingBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Spending Breakdown'**
  String get spendingBreakdown;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get lastWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days;

  /// No description provided for @customRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get customRange;

  /// No description provided for @spentToday.
  ///
  /// In en, this message translates to:
  /// **'Your Spending Today'**
  String get spentToday;

  /// No description provided for @spentYesterday.
  ///
  /// In en, this message translates to:
  /// **'Your Spending Yesterday'**
  String get spentYesterday;

  /// No description provided for @spentThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Your Spending This Week'**
  String get spentThisWeek;

  /// No description provided for @spentLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Your Spending Last Week'**
  String get spentLastWeek;

  /// No description provided for @spentThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Your Spending This Month'**
  String get spentThisMonth;

  /// No description provided for @spentLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Your Spending (last 30 days)'**
  String get spentLast30Days;

  /// No description provided for @spentCustom.
  ///
  /// In en, this message translates to:
  /// **'Spent (custom)'**
  String get spentCustom;

  /// No description provided for @todaysBudget.
  ///
  /// In en, this message translates to:
  /// **'Today\'s budget'**
  String get todaysBudget;

  /// No description provided for @yesterdaysBudget.
  ///
  /// In en, this message translates to:
  /// **'Yesterday\'s budget'**
  String get yesterdaysBudget;

  /// No description provided for @sumOfDailyBudgetsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Sum of daily budgets this week'**
  String get sumOfDailyBudgetsThisWeek;

  /// No description provided for @sumOfDailyBudgetsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Sum of daily budgets last week'**
  String get sumOfDailyBudgetsLastWeek;

  /// No description provided for @sumOfDailyBudgetsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Sum of daily budgets this month'**
  String get sumOfDailyBudgetsThisMonth;

  /// No description provided for @sumOfDailyBudgetsLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Sum of daily budgets over the last 30 days'**
  String get sumOfDailyBudgetsLast30Days;

  /// No description provided for @sumOfDailyBudgetsForSelectedRange.
  ///
  /// In en, this message translates to:
  /// **'Sum of daily budgets for the selected range'**
  String get sumOfDailyBudgetsForSelectedRange;

  /// No description provided for @netCashflowToday.
  ///
  /// In en, this message translates to:
  /// **'Net cashflow today'**
  String get netCashflowToday;

  /// No description provided for @netCashflowYesterday.
  ///
  /// In en, this message translates to:
  /// **'Net cashflow yesterday'**
  String get netCashflowYesterday;

  /// No description provided for @netCashflowThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Net cashflow this week'**
  String get netCashflowThisWeek;

  /// No description provided for @netCashflowLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Net cashflow last week'**
  String get netCashflowLastWeek;

  /// No description provided for @netCashflowThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Net cashflow this month'**
  String get netCashflowThisMonth;

  /// No description provided for @netCashflowLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Net cashflow (last 30 days)'**
  String get netCashflowLast30Days;

  /// No description provided for @netCashflowCustom.
  ///
  /// In en, this message translates to:
  /// **'Net cashflow (custom)'**
  String get netCashflowCustom;

  /// No description provided for @selectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get selectCurrency;

  /// No description provided for @showLessCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Show less currencies'**
  String get showLessCurrencies;

  /// No description provided for @showAllCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Show all currencies ({count} more)'**
  String showAllCurrencies(int count);

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @spentLabel.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentLabel;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get net;

  /// No description provided for @txn.
  ///
  /// In en, this message translates to:
  /// **'txn'**
  String get txn;

  /// No description provided for @txns.
  ///
  /// In en, this message translates to:
  /// **'txns'**
  String get txns;

  /// No description provided for @pleaseEnterExpenseDetails.
  ///
  /// In en, this message translates to:
  /// **'Please enter expense details'**
  String get pleaseEnterExpenseDetails;

  /// No description provided for @userNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in'**
  String get userNotLoggedIn;

  /// No description provided for @errorLoadingHouseholds.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Households'**
  String get errorLoadingHouseholds;

  /// No description provided for @welcomeToHouseholds.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Households'**
  String get welcomeToHouseholds;

  /// No description provided for @householdsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage shared finances with your family, partner, or roommates. Track budgets, split expenses, and collaborate on money decisions.'**
  String get householdsDescription;

  /// No description provided for @createHousehold.
  ///
  /// In en, this message translates to:
  /// **'Create Household'**
  String get createHousehold;

  /// No description provided for @joinWithInvite.
  ///
  /// In en, this message translates to:
  /// **'Join with Invite'**
  String get joinWithInvite;

  /// No description provided for @pleaseUseInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'Please use an invitation link to join a household'**
  String get pleaseUseInvitationLink;

  /// No description provided for @householdName.
  ///
  /// In en, this message translates to:
  /// **'Household Name'**
  String get householdName;

  /// No description provided for @householdNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., The Smiths'**
  String get householdNameHint;

  /// No description provided for @pleaseEnterHouseholdName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a household name'**
  String get pleaseEnterHouseholdName;

  /// No description provided for @errorCreatingHousehold.
  ///
  /// In en, this message translates to:
  /// **'Error creating household'**
  String get errorCreatingHousehold;

  /// No description provided for @householdsFeature.
  ///
  /// In en, this message translates to:
  /// **'Households Feature'**
  String get householdsFeature;

  /// No description provided for @householdsFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'The Households feature is now available! Manage shared finances with family, partners, or roommates.'**
  String get householdsFeatureDescription;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get gotIt;

  /// No description provided for @confirmExpense.
  ///
  /// In en, this message translates to:
  /// **'Confirm Expense'**
  String get confirmExpense;

  /// No description provided for @expenseDetails.
  ///
  /// In en, this message translates to:
  /// **'Expense Details'**
  String get expenseDetails;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save Expense'**
  String get saveExpense;

  /// No description provided for @shareWithHousehold.
  ///
  /// In en, this message translates to:
  /// **'Share with Household'**
  String get shareWithHousehold;

  /// No description provided for @loadingHouseholdMembers.
  ///
  /// In en, this message translates to:
  /// **'Loading household members...'**
  String get loadingHouseholdMembers;

  /// No description provided for @selectHouseholdToConfigureSplit.
  ///
  /// In en, this message translates to:
  /// **'Select a household to configure split'**
  String get selectHouseholdToConfigureSplit;

  /// No description provided for @currencyManagedByHousehold.
  ///
  /// In en, this message translates to:
  /// **'Currency is managed by the household and cannot be changed'**
  String get currencyManagedByHousehold;

  /// No description provided for @currencyCannotBeChanged.
  ///
  /// In en, this message translates to:
  /// **'Currency cannot be changed when sharing with a household'**
  String get currencyCannotBeChanged;

  /// No description provided for @cannotEditOthersExpenses.
  ///
  /// In en, this message translates to:
  /// **'You can only edit your own expenses'**
  String get cannotEditOthersExpenses;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @editAmount.
  ///
  /// In en, this message translates to:
  /// **'Edit Amount'**
  String get editAmount;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @editNotes.
  ///
  /// In en, this message translates to:
  /// **'Edit Notes'**
  String get editNotes;

  /// No description provided for @addANote.
  ///
  /// In en, this message translates to:
  /// **'Add a note...'**
  String get addANote;

  /// No description provided for @noMembersFoundInHousehold.
  ///
  /// In en, this message translates to:
  /// **'No members found in household'**
  String get noMembersFoundInHousehold;

  /// No description provided for @errorLoadingMembers.
  ///
  /// In en, this message translates to:
  /// **'Error loading members'**
  String get errorLoadingMembers;

  /// No description provided for @noExpenseToSave.
  ///
  /// In en, this message translates to:
  /// **'No expense to save'**
  String get noExpenseToSave;

  /// No description provided for @expenseSavedAndShared.
  ///
  /// In en, this message translates to:
  /// **'Expense saved and shared{splitInfo}!'**
  String expenseSavedAndShared(String splitInfo);

  /// No description provided for @expenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense saved!'**
  String get expenseSaved;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSave(String error);

  /// No description provided for @failedToSyncCurrencyPreference.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync currency preference: {error}'**
  String failedToSyncCurrencyPreference(Object error);

  /// No description provided for @currencyUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Currency updated successfully'**
  String get currencyUpdatedSuccessfully;

  /// No description provided for @retryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed: {error}'**
  String retryFailed(Object error);

  /// No description provided for @iSpentAmountOnCategory.
  ///
  /// In en, this message translates to:
  /// **'I spent {currencySymbol}{amount} on {category}'**
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol);

  /// No description provided for @enterNewTotalDailyBudgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the new total daily budget.'**
  String get enterNewTotalDailyBudgetDescription;

  /// No description provided for @pleaseSignInToAccessHouseholdFeatures.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to access household features'**
  String get pleaseSignInToAccessHouseholdFeatures;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @invites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get invites;

  /// No description provided for @errorLoadingExpenses.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Expenses'**
  String get errorLoadingExpenses;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @loadingHousehold.
  ///
  /// In en, this message translates to:
  /// **'Loading household...'**
  String get loadingHousehold;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'Over Budget'**
  String get overBudget;

  /// No description provided for @sharedBudgets.
  ///
  /// In en, this message translates to:
  /// **'Shared Budgets'**
  String get sharedBudgets;

  /// No description provided for @netPosition.
  ///
  /// In en, this message translates to:
  /// **'Net position'**
  String get netPosition;

  /// No description provided for @spentByHousehold.
  ///
  /// In en, this message translates to:
  /// **'Spent by Household'**
  String get spentByHousehold;

  /// No description provided for @memberSpending.
  ///
  /// In en, this message translates to:
  /// **'Member Spending'**
  String get memberSpending;

  /// No description provided for @spentByHouseholdTooltip.
  ///
  /// In en, this message translates to:
  /// **'This shows the total amount spent by all household members during the selected period. It includes all shared expenses logged by any member of the household.'**
  String get spentByHouseholdTooltip;

  /// No description provided for @manageMoneyTogether.
  ///
  /// In en, this message translates to:
  /// **'Manage money together with your partner, family, or roommates in one shared space.'**
  String get manageMoneyTogether;

  /// No description provided for @sharedBudgetsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Shared Budgets & Expenses'**
  String get sharedBudgetsExpenses;

  /// No description provided for @sharedBudgetsExpensesDesc.
  ///
  /// In en, this message translates to:
  /// **'Set budgets, track spending, and see where your household money goes in real-time.'**
  String get sharedBudgetsExpensesDesc;

  /// No description provided for @smartExpenseSplitting.
  ///
  /// In en, this message translates to:
  /// **'Smart Expense Splitting'**
  String get smartExpenseSplitting;

  /// No description provided for @smartExpenseSplittingDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically calculate who owes what with flexible split options: equal, percentage, or custom amounts.'**
  String get smartExpenseSplittingDesc;

  /// No description provided for @stayInSync.
  ///
  /// In en, this message translates to:
  /// **'Stay in Sync'**
  String get stayInSync;

  /// No description provided for @stayInSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Get notified when expenses are added, budgets are reached, or splits need settling.'**
  String get stayInSyncDesc;

  /// No description provided for @householdSettings.
  ///
  /// In en, this message translates to:
  /// **'Household Settings'**
  String get householdSettings;

  /// No description provided for @householdNotFound.
  ///
  /// In en, this message translates to:
  /// **'Household not found'**
  String get householdNotFound;

  /// No description provided for @coverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover Photo'**
  String get coverPhoto;

  /// No description provided for @changeCoverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Cover Photo'**
  String get changeCoverPhoto;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @errorLoadingHousehold.
  ///
  /// In en, this message translates to:
  /// **'Error loading household'**
  String get errorLoadingHousehold;

  /// No description provided for @householdUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Household updated successfully'**
  String get householdUpdatedSuccessfully;

  /// No description provided for @failedToUpdateHousehold.
  ///
  /// In en, this message translates to:
  /// **'Failed to update household'**
  String get failedToUpdateHousehold;

  /// No description provided for @inviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get inviteMember;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get removeMember;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @confirmRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove'**
  String get confirmRemoveMember;

  /// No description provided for @updatedMemberRole.
  ///
  /// In en, this message translates to:
  /// **'Updated member role'**
  String get updatedMemberRole;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin'**
  String get makeAdmin;

  /// No description provided for @makeMember.
  ///
  /// In en, this message translates to:
  /// **'Make Member'**
  String get makeMember;

  /// No description provided for @invitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get invitations;

  /// No description provided for @errorLoadingInvites.
  ///
  /// In en, this message translates to:
  /// **'Error loading invites'**
  String get errorLoadingInvites;

  /// No description provided for @createInvitation.
  ///
  /// In en, this message translates to:
  /// **'Create Invitation'**
  String get createInvitation;

  /// No description provided for @pendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'Pending Invitations'**
  String get pendingInvitations;

  /// No description provided for @noPendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations'**
  String get noPendingInvitations;

  /// No description provided for @invitationHistory.
  ///
  /// In en, this message translates to:
  /// **'Invitation History'**
  String get invitationHistory;

  /// No description provided for @noInvitationHistory.
  ///
  /// In en, this message translates to:
  /// **'No invitation history'**
  String get noInvitationHistory;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @friendEmailExample.
  ///
  /// In en, this message translates to:
  /// **'friend@example.com'**
  String get friendEmailExample;

  /// No description provided for @personalMessageOptional.
  ///
  /// In en, this message translates to:
  /// **'Personal Message (optional)'**
  String get personalMessageOptional;

  /// No description provided for @joinHouseholdBudget.
  ///
  /// In en, this message translates to:
  /// **'Join our household budget!'**
  String get joinHouseholdBudget;

  /// No description provided for @expiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires In'**
  String get expiresIn;

  /// No description provided for @oneDay.
  ///
  /// In en, this message translates to:
  /// **'1 Day'**
  String get oneDay;

  /// No description provided for @threeDays.
  ///
  /// In en, this message translates to:
  /// **'3 Days'**
  String get threeDays;

  /// No description provided for @sevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get sevenDays;

  /// No description provided for @fourteenDays.
  ///
  /// In en, this message translates to:
  /// **'14 Days'**
  String get fourteenDays;

  /// No description provided for @thirtyDays.
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get thirtyDays;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @invitationCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Invitation created successfully'**
  String get invitationCreatedSuccessfully;

  /// No description provided for @inviteLinkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied to clipboard!'**
  String get inviteLinkCopiedToClipboard;

  /// No description provided for @errorCreatingInvite.
  ///
  /// In en, this message translates to:
  /// **'Error creating invite'**
  String get errorCreatingInvite;

  /// No description provided for @revokeInvitation.
  ///
  /// In en, this message translates to:
  /// **'Revoke Invitation'**
  String get revokeInvitation;

  /// No description provided for @confirmRevokeInvitation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to revoke this invitation?'**
  String get confirmRevokeInvitation;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @invitationRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invitation revoked'**
  String get invitationRevoked;

  /// No description provided for @errorRevokingInvite.
  ///
  /// In en, this message translates to:
  /// **'Error revoking invite'**
  String get errorRevokingInvite;

  /// No description provided for @anyoneWithLink.
  ///
  /// In en, this message translates to:
  /// **'Anyone with link'**
  String get anyoneWithLink;

  /// No description provided for @noExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry'**
  String get noExpiry;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get copyLink;

  /// No description provided for @selectCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Select Cover Image'**
  String get selectCoverImage;

  /// No description provided for @failedToLoadImages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load images'**
  String get failedToLoadImages;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failedToLoad;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image too large'**
  String get imageTooLarge;

  /// No description provided for @maxIs.
  ///
  /// In en, this message translates to:
  /// **'Max is'**
  String get maxIs;

  /// No description provided for @unsupportedFileFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file format. Please use JPG, PNG, or WebP.'**
  String get unsupportedFileFormat;

  /// No description provided for @cropCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Crop Cover Image'**
  String get cropCoverImage;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit Budget'**
  String get editBudget;

  /// No description provided for @budgetDetails.
  ///
  /// In en, this message translates to:
  /// **'Budget Details'**
  String get budgetDetails;

  /// No description provided for @budgetName.
  ///
  /// In en, this message translates to:
  /// **'Budget Name'**
  String get budgetName;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @alertThresholds.
  ///
  /// In en, this message translates to:
  /// **'Alert Thresholds'**
  String get alertThresholds;

  /// No description provided for @warningThreshold.
  ///
  /// In en, this message translates to:
  /// **'Warning Threshold (%)'**
  String get warningThreshold;

  /// No description provided for @alertThreshold.
  ///
  /// In en, this message translates to:
  /// **'Alert Threshold (%)'**
  String get alertThreshold;

  /// No description provided for @warningThresholdHelper.
  ///
  /// In en, this message translates to:
  /// **'Alert when budget usage reaches this percentage'**
  String get warningThresholdHelper;

  /// No description provided for @alertThresholdHelper.
  ///
  /// In en, this message translates to:
  /// **'Critical alert at this percentage'**
  String get alertThresholdHelper;

  /// No description provided for @budgetStatus.
  ///
  /// In en, this message translates to:
  /// **'Budget Status'**
  String get budgetStatus;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @deletingBudget.
  ///
  /// In en, this message translates to:
  /// **'Deleting budget...'**
  String get deletingBudget;

  /// No description provided for @savingChanges.
  ///
  /// In en, this message translates to:
  /// **'Saving changes...'**
  String get savingChanges;

  /// No description provided for @budgetNameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Budget name cannot be empty'**
  String get budgetNameCannotBeEmpty;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @warningThresholdRange.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold must be between 0 and 100'**
  String get warningThresholdRange;

  /// No description provided for @alertThresholdRange.
  ///
  /// In en, this message translates to:
  /// **'Alert threshold must be between 0 and 100'**
  String get alertThresholdRange;

  /// No description provided for @warningThresholdLessThanAlert.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold must be less than or equal to alert threshold'**
  String get warningThresholdLessThanAlert;

  /// No description provided for @deleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Delete Budget'**
  String get deleteBudget;

  /// No description provided for @confirmDeleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get confirmDeleteBudget;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get thisActionCannotBeUndone;

  /// No description provided for @budgetUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Budget updated successfully'**
  String get budgetUpdatedSuccessfully;

  /// No description provided for @budgetDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Budget deleted successfully'**
  String get budgetDeletedSuccessfully;

  /// No description provided for @categoryTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get categoryTransfers;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryUtilities;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryEntertainmentSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Entertainment Subscriptions'**
  String get categoryEntertainmentSubscriptions;

  /// No description provided for @categoryRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get categoryRestaurants;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoryGroceries;

  /// No description provided for @categoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransport;

  /// No description provided for @categoryTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get categoryTransportation;

  /// No description provided for @categoryTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// No description provided for @categoryFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get categoryFlights;

  /// No description provided for @categoryVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get categoryVacation;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get categoryMedical;

  /// No description provided for @categoryText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get categoryText;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryTuition.
  ///
  /// In en, this message translates to:
  /// **'Tuition'**
  String get categoryTuition;

  /// No description provided for @categorySubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get categorySubscriptions;

  /// No description provided for @categoryServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get categoryServices;

  /// No description provided for @categoryHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get categoryHousing;

  /// No description provided for @categoryRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get categoryRent;

  /// No description provided for @categoryMortgage.
  ///
  /// In en, this message translates to:
  /// **'Mortgage'**
  String get categoryMortgage;

  /// No description provided for @categoryBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get categoryBills;

  /// No description provided for @categoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoryInsurance;

  /// No description provided for @categorySavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get categorySavings;

  /// No description provided for @categoryInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get categoryInvestment;

  /// No description provided for @categoryInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get categoryInvestments;

  /// No description provided for @categoryIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get categoryIncome;

  /// No description provided for @categorySalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categorySalary;

  /// No description provided for @categoryBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get categoryBonus;

  /// No description provided for @categoryPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get categoryPets;

  /// No description provided for @categoryKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get categoryKids;

  /// No description provided for @categoryFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get categoryFamily;

  /// No description provided for @categoryGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryGifts;

  /// No description provided for @categoryCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity'**
  String get categoryCharity;

  /// No description provided for @categoryFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get categoryFees;

  /// No description provided for @categoryLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get categoryLoan;

  /// No description provided for @categoryLoans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get categoryLoans;

  /// No description provided for @categoryDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get categoryDebt;

  /// No description provided for @categoryPersonalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal Care'**
  String get categoryPersonalCare;

  /// No description provided for @categoryBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryBeauty;

  /// No description provided for @categoryMisc.
  ///
  /// In en, this message translates to:
  /// **'Misc'**
  String get categoryMisc;

  /// No description provided for @categoryUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get categoryUncategorized;

  /// No description provided for @deleteBudgetCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get deleteBudgetCannotBeUndone;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @failedToDeleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete budget'**
  String get failedToDeleteBudget;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @revoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get revoked;

  /// No description provided for @tapToChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Tap to change cover'**
  String get tapToChangeCover;

  /// No description provided for @personalMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Say something to your invitees (e.g., \"Join our household budget!\")'**
  String get personalMessageHint;

  /// No description provided for @invitationExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Invitation Expires In'**
  String get invitationExpiresIn;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} day{days, plural, =1 {} other {s}}'**
  String daysCount(int days);

  /// No description provided for @createHouseholdDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a shared space for tracking budgets and expenses with family or roommates.'**
  String get createHouseholdDescription;

  /// No description provided for @uploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading Image...'**
  String get uploadingImage;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creating;

  /// No description provided for @generatingInvite.
  ///
  /// In en, this message translates to:
  /// **'Generating Invite...'**
  String get generatingInvite;

  /// No description provided for @pleaseSelectValidCurrency.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid household currency'**
  String get pleaseSelectValidCurrency;

  /// No description provided for @nameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be less than {max} characters'**
  String nameMaxLength(int max);

  /// No description provided for @createHouseholdPage.
  ///
  /// In en, this message translates to:
  /// **'Create household page'**
  String get createHouseholdPage;

  /// No description provided for @invitationPersonalMessageInput.
  ///
  /// In en, this message translates to:
  /// **'Invitation personal message input'**
  String get invitationPersonalMessageInput;

  /// No description provided for @householdNameInput.
  ///
  /// In en, this message translates to:
  /// **'Household name input'**
  String get householdNameInput;

  /// No description provided for @invitationExpirationSelector.
  ///
  /// In en, this message translates to:
  /// **'Invitation expiration selector'**
  String get invitationExpirationSelector;

  /// No description provided for @unlimitedExpiration.
  ///
  /// In en, this message translates to:
  /// **'Unlimited expiration'**
  String get unlimitedExpiration;

  /// No description provided for @daysExpiration.
  ///
  /// In en, this message translates to:
  /// **'{days} day{days, plural, =1 {} other {s}} expiration'**
  String daysExpiration(int days);

  /// No description provided for @householdInformation.
  ///
  /// In en, this message translates to:
  /// **'Household information'**
  String get householdInformation;

  /// No description provided for @creatingHousehold.
  ///
  /// In en, this message translates to:
  /// **'Creating household'**
  String get creatingHousehold;

  /// No description provided for @createHouseholdButton.
  ///
  /// In en, this message translates to:
  /// **'Create household button'**
  String get createHouseholdButton;

  /// No description provided for @searchExpenses.
  ///
  /// In en, this message translates to:
  /// **'Search expenses...'**
  String get searchExpenses;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @allMembers.
  ///
  /// In en, this message translates to:
  /// **'All Members'**
  String get allMembers;

  /// No description provided for @balanceSummary.
  ///
  /// In en, this message translates to:
  /// **'Balance Summary'**
  String get balanceSummary;

  /// No description provided for @youAreOwed.
  ///
  /// In en, this message translates to:
  /// **'You are owed'**
  String get youAreOwed;

  /// No description provided for @youOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get youOwe;

  /// No description provided for @youOweOthers.
  ///
  /// In en, this message translates to:
  /// **'You owe others'**
  String get youOweOthers;

  /// No description provided for @othersOweYou.
  ///
  /// In en, this message translates to:
  /// **'Others owe you'**
  String get othersOweYou;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @settleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle Up'**
  String get settleUp;

  /// No description provided for @markExpensesAsSettled.
  ///
  /// In en, this message translates to:
  /// **'Mark expenses as settled to update balances'**
  String get markExpensesAsSettled;

  /// No description provided for @whoAreYouSettlingWith.
  ///
  /// In en, this message translates to:
  /// **'Who are you settling with?'**
  String get whoAreYouSettlingWith;

  /// No description provided for @selectMember.
  ///
  /// In en, this message translates to:
  /// **'Select Member'**
  String get selectMember;

  /// No description provided for @amountToSettle.
  ///
  /// In en, this message translates to:
  /// **'Amount to settle'**
  String get amountToSettle;

  /// No description provided for @howDidYouSettle.
  ///
  /// In en, this message translates to:
  /// **'How did you settle?'**
  String get howDidYouSettle;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @paidInCash.
  ///
  /// In en, this message translates to:
  /// **'Paid in cash'**
  String get paidInCash;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @transferredViaBank.
  ///
  /// In en, this message translates to:
  /// **'Transferred via bank'**
  String get transferredViaBank;

  /// No description provided for @mobilePayment.
  ///
  /// In en, this message translates to:
  /// **'Mobile Payment'**
  String get mobilePayment;

  /// No description provided for @venmoPaypalEtc.
  ///
  /// In en, this message translates to:
  /// **'Venmo, PayPal, etc.'**
  String get venmoPaypalEtc;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @filterTransactions.
  ///
  /// In en, this message translates to:
  /// **'Filter Transactions'**
  String get filterTransactions;

  /// No description provided for @noTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get noTransactionsFound;

  /// No description provided for @failedToLoadHouseholdTransactions.
  ///
  /// In en, this message translates to:
  /// **'Failed to load household transactions'**
  String get failedToLoadHouseholdTransactions;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @noMatchingExpenses.
  ///
  /// In en, this message translates to:
  /// **'No Matching Expenses'**
  String get noMatchingExpenses;

  /// No description provided for @startLoggingExpenses.
  ///
  /// In en, this message translates to:
  /// **'Start logging expenses to see them here'**
  String get startLoggingExpenses;

  /// No description provided for @tryAdjustingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get tryAdjustingFilters;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @currencyCannotBeChangedWhenSharing.
  ///
  /// In en, this message translates to:
  /// **'Currency cannot be changed when sharing with a household'**
  String get currencyCannotBeChangedWhenSharing;

  /// No description provided for @createBudget.
  ///
  /// In en, this message translates to:
  /// **'Create Budget'**
  String get createBudget;

  /// No description provided for @pleaseEnterABudgetName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a budget name'**
  String get pleaseEnterABudgetName;

  /// No description provided for @pleaseEnterAValidAmountGreaterThan0.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount greater than 0'**
  String get pleaseEnterAValidAmountGreaterThan0;

  /// No description provided for @warningThresholdMustBeBetween0And100.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold must be between 0 and 100%'**
  String get warningThresholdMustBeBetween0And100;

  /// No description provided for @alertThresholdMustBeBetween0And100.
  ///
  /// In en, this message translates to:
  /// **'Alert threshold must be between 0 and 100%'**
  String get alertThresholdMustBeBetween0And100;

  /// No description provided for @warningThresholdMustBeLessThanOrEqualToAlert.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold must be less than or equal to alert threshold'**
  String get warningThresholdMustBeLessThanOrEqualToAlert;

  /// No description provided for @budgetCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Budget created successfully!'**
  String get budgetCreatedSuccessfully;

  /// No description provided for @failedToCreateBudget.
  ///
  /// In en, this message translates to:
  /// **'Failed to create budget'**
  String get failedToCreateBudget;

  /// No description provided for @groceriesRentEntertainment.
  ///
  /// In en, this message translates to:
  /// **'e.g., Groceries, Rent, Entertainment'**
  String get groceriesRentEntertainment;

  /// No description provided for @budgetType.
  ///
  /// In en, this message translates to:
  /// **'Budget Type'**
  String get budgetType;

  /// No description provided for @sharedWithAllHouseholdMembers.
  ///
  /// In en, this message translates to:
  /// **'Shared with all household members'**
  String get sharedWithAllHouseholdMembers;

  /// No description provided for @personalBudgetForYourExpensesOnly.
  ///
  /// In en, this message translates to:
  /// **'Personal budget for your expenses only'**
  String get personalBudgetForYourExpensesOnly;

  /// No description provided for @countSplitPortionOnly.
  ///
  /// In en, this message translates to:
  /// **'Count Split Portion Only'**
  String get countSplitPortionOnly;

  /// No description provided for @onlyCountYourPortionOfSplitExpenses.
  ///
  /// In en, this message translates to:
  /// **'Only count your portion of split expenses towards this budget'**
  String get onlyCountYourPortionOfSplitExpenses;

  /// No description provided for @joinHousehold.
  ///
  /// In en, this message translates to:
  /// **'Join Household'**
  String get joinHousehold;

  /// No description provided for @joinAHousehold.
  ///
  /// In en, this message translates to:
  /// **'Join a Household'**
  String get joinAHousehold;

  /// No description provided for @enterYourInvitationLinkToJoin.
  ///
  /// In en, this message translates to:
  /// **'Enter your invitation link to join\na shared financial space'**
  String get enterYourInvitationLinkToJoin;

  /// No description provided for @pasteTheInvitationLinkYouReceived.
  ///
  /// In en, this message translates to:
  /// **'Paste the invitation link you received from a household member'**
  String get pasteTheInvitationLinkYouReceived;

  /// No description provided for @pasteInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'Paste invitation link'**
  String get pasteInvitationLink;

  /// No description provided for @pleaseEnterAnInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'Please enter an invitation link'**
  String get pleaseEnterAnInvitationLink;

  /// No description provided for @pleaseEnterAValidInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid invitation link'**
  String get pleaseEnterAValidInvitationLink;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @validating.
  ///
  /// In en, this message translates to:
  /// **'Validating...'**
  String get validating;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @welcomeAboard.
  ///
  /// In en, this message translates to:
  /// **'Welcome Aboard!'**
  String get welcomeAboard;

  /// No description provided for @youreNowPartOfTheHousehold.
  ///
  /// In en, this message translates to:
  /// **'You\'re now part of the household.\nStart collaborating on your finances!'**
  String get youreNowPartOfTheHousehold;

  /// No description provided for @thisWillOnlyTakeAMoment.
  ///
  /// In en, this message translates to:
  /// **'This will only take a moment'**
  String get thisWillOnlyTakeAMoment;

  /// No description provided for @unableToJoin.
  ///
  /// In en, this message translates to:
  /// **'Unable to Join'**
  String get unableToJoin;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @goToHousehold.
  ///
  /// In en, this message translates to:
  /// **'Go to Household'**
  String get goToHousehold;

  /// No description provided for @expiresSoon.
  ///
  /// In en, this message translates to:
  /// **'Expires soon'**
  String get expiresSoon;

  /// No description provided for @invitationValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Invitation valid until {formattedDate}'**
  String invitationValidUntil(String formattedDate);

  /// No description provided for @whatYoullGet.
  ///
  /// In en, this message translates to:
  /// **'What you\'ll get'**
  String get whatYoullGet;

  /// No description provided for @viewSharedBudgetsAndExpenses.
  ///
  /// In en, this message translates to:
  /// **'View shared budgets and expenses'**
  String get viewSharedBudgetsAndExpenses;

  /// No description provided for @trackHouseholdFinancialHealth.
  ///
  /// In en, this message translates to:
  /// **'Track household financial health'**
  String get trackHouseholdFinancialHealth;

  /// No description provided for @collaborateOnFinancialDecisions.
  ///
  /// In en, this message translates to:
  /// **'Collaborate on financial decisions'**
  String get collaborateOnFinancialDecisions;

  /// No description provided for @household.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get household;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @noBudgetsYet.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get noBudgetsYet;

  /// No description provided for @createSharedBudgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a shared budget to track spending together'**
  String get createSharedBudgetDescription;

  /// No description provided for @errorLoadingBudgets.
  ///
  /// In en, this message translates to:
  /// **'Error loading budgets'**
  String get errorLoadingBudgets;

  /// No description provided for @recentSplits.
  ///
  /// In en, this message translates to:
  /// **'Recent Splits'**
  String get recentSplits;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @last6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 months'**
  String get last6Months;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @nameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least {min} characters'**
  String nameMinLength(int min);

  /// No description provided for @splitExpense.
  ///
  /// In en, this message translates to:
  /// **'Split Expense'**
  String get splitExpense;

  /// No description provided for @percent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get percent;

  /// No description provided for @splitShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get splitShare;

  /// No description provided for @owes.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get owes;

  /// No description provided for @splitAmountsMustEqual.
  ///
  /// In en, this message translates to:
  /// **'Split amounts must equal {currency}{amount}'**
  String splitAmountsMustEqual(String currency, String amount);

  /// No description provided for @percentagesMustTotal100.
  ///
  /// In en, this message translates to:
  /// **'Percentages must total 100%'**
  String get percentagesMustTotal100;

  /// No description provided for @eachPersonMustHaveAtLeast1Share.
  ///
  /// In en, this message translates to:
  /// **'Each person must have at least 1 share'**
  String get eachPersonMustHaveAtLeast1Share;

  /// No description provided for @whatsappVerified.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Verified'**
  String get whatsappVerified;

  /// No description provided for @whatsappVerification.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Verification'**
  String get whatsappVerification;

  /// No description provided for @yourWhatsAppNumberIsSuccessfullyLinked.
  ///
  /// In en, this message translates to:
  /// **'Your WhatsApp number is successfully linked to your account'**
  String get yourWhatsAppNumberIsSuccessfullyLinked;

  /// No description provided for @verifyingYourWhatsAppNumber.
  ///
  /// In en, this message translates to:
  /// **'Verifying your WhatsApp number...'**
  String get verifyingYourWhatsAppNumber;

  /// No description provided for @enterThe6DigitCodeFromWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from WhatsApp'**
  String get enterThe6DigitCodeFromWhatsApp;

  /// No description provided for @pleaseEnterThe6DigitVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit verification code'**
  String get pleaseEnterThe6DigitVerificationCode;

  /// No description provided for @failedToVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify code'**
  String get failedToVerifyCode;

  /// No description provided for @failedToVerifyCodePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify code. Please try again.'**
  String get failedToVerifyCodePleaseTryAgain;

  /// No description provided for @codeAutoFilledFromVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Code auto-filled from verification link'**
  String get codeAutoFilledFromVerificationLink;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @avatarStudio.
  ///
  /// In en, this message translates to:
  /// **'Avatar Studio'**
  String get avatarStudio;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @colors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get colors;

  /// No description provided for @randomize.
  ///
  /// In en, this message translates to:
  /// **'Randomize'**
  String get randomize;

  /// No description provided for @saveAvatar.
  ///
  /// In en, this message translates to:
  /// **'Save Avatar'**
  String get saveAvatar;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectColor;

  /// No description provided for @failedToSaveAvatar.
  ///
  /// In en, this message translates to:
  /// **'Failed to save avatar'**
  String get failedToSaveAvatar;

  /// No description provided for @hair.
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get hair;

  /// No description provided for @eyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get eyes;

  /// No description provided for @mouth.
  ///
  /// In en, this message translates to:
  /// **'Mouth'**
  String get mouth;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @face.
  ///
  /// In en, this message translates to:
  /// **'Face'**
  String get face;

  /// No description provided for @ears.
  ///
  /// In en, this message translates to:
  /// **'Ears'**
  String get ears;

  /// No description provided for @shirts.
  ///
  /// In en, this message translates to:
  /// **'Shirts'**
  String get shirts;

  /// No description provided for @brow.
  ///
  /// In en, this message translates to:
  /// **'Brow'**
  String get brow;

  /// No description provided for @nose.
  ///
  /// In en, this message translates to:
  /// **'Nose'**
  String get nose;

  /// No description provided for @blush.
  ///
  /// In en, this message translates to:
  /// **'Blush'**
  String get blush;

  /// No description provided for @accessories.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessories;

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get stars;

  /// No description provided for @currencyIsManagedByHousehold.
  ///
  /// In en, this message translates to:
  /// **'Currency is managed by the household and cannot be changed'**
  String get currencyIsManagedByHousehold;

  /// No description provided for @buyALaptop.
  ///
  /// In en, this message translates to:
  /// **'buy a \$1,200 laptop'**
  String get buyALaptop;

  /// No description provided for @selectTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Select target date'**
  String get selectTargetDate;

  /// Template for scenario planning questions. CRITICAL: Adjust word order for your language's grammar structure.
  ///
  /// LANGUAGE STRUCTURE EXAMPLES:
  /// • English (SVO): Can I {action} before {date}?
  /// • Chinese (STV): 我可以在{date}前{action}吗？
  /// • Japanese (SOV): {date}前に{action}できますか？
  /// • Korean (SOV): {date} 전에 {action}할 수 있나요?
  /// • Spanish (VSO): ¿Puedo {action} antes del {date}?
  /// • French (VSO): Puis-je {action} avant le {date}?
  /// • German (V2): Kann ich {action} vor dem {date}?
  /// • Russian (SVO): Могу ли я {action} до {date}?
  /// • Arabic (VSO): هل يمكنني {action} قبل {date}؟
  /// • Hindi (SOV): क्या मैं {date} से पहले {action} कर सकता हूँ?
  /// • Urdu (SOV): کیا میں {date} سے پہلے {action} کر سکتا ہوں؟
  /// • Turkish (SOV): {date} öncesi {action} yapabilir miyim?
  /// • Dutch (SVO): Kan ik {action} voor {date}?
  /// • Swedish (SVO): Kan jag {action} före {date}?
  /// • Polish (SVO): Czy mogę {action} przed {date}?
  /// • Thai (SVO): ฉันสามารถ {action} ก่อน {date} ได้ไหม?
  /// • Vietnamese (SVO): Tôi có thể {action} trước {date} không?
  /// • Indonesian (SVO): Bisakah saya {action} sebelum {date}?
  ///
  /// IMPORTANT: Consider your language's unique features:
  /// - Gender agreement (Romance languages)
  /// - Case systems (Germanic, Slavic languages)
  /// - Honorific levels (Asian languages)
  /// - Right-to-left script (Arabic, Hebrew)
  /// - Postpositions (Indian languages)
  /// - Verb position variations
  ///
  /// In en, this message translates to:
  /// **'Can I {action} before {date}'**
  String scenarioQuestionTemplate(String action, String date);

  /// Date format for scenario planning. Use standard ICU DateFormat patterns.
  ///
  /// REGIONAL DATE FORMAT EXAMPLES:
  /// • United States: MM/dd/yyyy (01/25/2025)
  /// • United Kingdom: dd/MM/yyyy (25/01/2025)
  /// • China/Japan/Korea: yyyy/MM/dd (2025/01/25)
  /// • Germany: dd.MM.yyyy (25.01.2025)
  /// • France: dd/MM/yyyy (25/01/2025)
  /// • Spain: dd/MM/yyyy (25/01/2025)
  /// • Italy: dd/MM/yyyy (25/01/2025)
  /// • Russia: dd.MM.yyyy (25.01.2025)
  /// • Arabic (Egypt): dd/MM/yyyy (25/01/2025)
  /// • Hindi: dd-MM-yyyy (25-01-2025)
  /// • Urdu: dd/MM/yyyy (25/01/2025)
  /// • Thai: dd/MM/yyyy (25/01/2565) [Note: Buddhist calendar]
  /// • Vietnamese: dd/MM/yyyy (25/01/2025)
  /// • Indonesian: dd/MM/yyyy (25/01/2025)
  /// • Turkish: dd.MM.yyyy (25.01.2025)
  /// • Dutch: dd-MM-yyyy (25-01-2025)
  /// • Swedish: yyyy-MM-dd (2025-01-25)
  /// • Polish: dd.MM.yyyy (25.01.2025)
  ///
  /// SPECIAL CONSIDERATIONS:
  /// - Buddhist calendar (Thailand): Year + 543
  /// - Islamic calendar (Arabic countries): Different year system
  /// - Hebrew calendar (Israel): Different year system
  /// - Era naming (Japanese): Reiwa, Heisei, etc.
  /// - Lunar calendars (Chinese, Korean, Vietnamese)
  /// - Week start day (Sunday vs Monday)
  /// - Use of separators: /, -, ., or spaces
  ///
  /// In en, this message translates to:
  /// **'MM/dd/yyyy'**
  String get scenarioDateFormat;

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed: {error}'**
  String analysisFailed(String error);

  /// No description provided for @leftHandChamps.
  ///
  /// In en, this message translates to:
  /// **'The left-hand champs are your heavy hitters—perfect candidates for a quick review.'**
  String get leftHandChamps;

  /// No description provided for @smallButFrequent.
  ///
  /// In en, this message translates to:
  /// **'Small but frequent categories hint at habits that may sneak up over time.'**
  String get smallButFrequent;

  /// No description provided for @colorMatches.
  ///
  /// In en, this message translates to:
  /// **'Color matches what you see on the Home tab so your brain stays comfy.'**
  String get colorMatches;

  /// No description provided for @planningNewGoal.
  ///
  /// In en, this message translates to:
  /// **'Planning a new goal? Spot categories to trim without touching the fun stuff.'**
  String get planningNewGoal;

  /// No description provided for @eyeingTreatYourself.
  ///
  /// In en, this message translates to:
  /// **'Eyeing a treat-yourself month? See which areas can flex safely.'**
  String get eyeingTreatYourself;

  /// No description provided for @doubleCheckTagging.
  ///
  /// In en, this message translates to:
  /// **'Use it to double-check that new expenses were tagged correctly—no ghosts allowed.'**
  String get doubleCheckTagging;

  /// No description provided for @slideHighBar.
  ///
  /// In en, this message translates to:
  /// **'Slide a high bar down a notch by setting a mini limit or switching to lower-cost swaps.'**
  String get slideHighBar;

  /// No description provided for @nonNegotiable.
  ///
  /// In en, this message translates to:
  /// **'If a bar is non-negotiable (hello, rent), plan around it instead of fighting it.'**
  String get nonNegotiable;

  /// No description provided for @revisitAfterScenario.
  ///
  /// In en, this message translates to:
  /// **'Revisit after running a scenario to see whether your adjustments stick.'**
  String get revisitAfterScenario;

  /// No description provided for @purpleLineCushion.
  ///
  /// In en, this message translates to:
  /// **'Purple line: the cushion left after each day. Rising lines mean you are building momentum.'**
  String get purpleLineCushion;

  /// No description provided for @blueBarsBudget.
  ///
  /// In en, this message translates to:
  /// **'Blue bars: the budget you set for that day.'**
  String get blueBarsBudget;

  /// No description provided for @redBarsSpent.
  ///
  /// In en, this message translates to:
  /// **'Red bars: what actually left your account.'**
  String get redBarsSpent;

  /// No description provided for @lineTrendingUpward.
  ///
  /// In en, this message translates to:
  /// **'Line trending upward = extra cash you can redirect toward savings goals.'**
  String get lineTrendingUpward;

  /// No description provided for @flatDippingLine.
  ///
  /// In en, this message translates to:
  /// **'Flat or dipping line = time to pause and review big-ticket items.'**
  String get flatDippingLine;

  /// No description provided for @sharpDrops.
  ///
  /// In en, this message translates to:
  /// **'Sharp drops often match unplanned purchases—tap them to inspect the details.'**
  String get sharpDrops;

  /// No description provided for @lineRisingDays.
  ///
  /// In en, this message translates to:
  /// **'Line rising for several days? Consider moving a little extra into savings or debt payoff.'**
  String get lineRisingDays;

  /// No description provided for @lineDippingWeekend.
  ///
  /// In en, this message translates to:
  /// **'Line dipping after a busy weekend? Rebalance upcoming days by trimming small discretionary spends.'**
  String get lineDippingWeekend;

  /// No description provided for @feelStuckRed.
  ///
  /// In en, this message translates to:
  /// **'Feel stuck in the red? Revisit your budget in the Home tab—small adjustments add up quickly.'**
  String get feelStuckRed;

  /// No description provided for @thirtyDayForecastDesc.
  ///
  /// In en, this message translates to:
  /// **'This forecast uses the last month of activity to guess how lively the next month might be. Think of it as a weather report for your wallet.'**
  String get thirtyDayForecastDesc;

  /// No description provided for @greenLineExpected.
  ///
  /// In en, this message translates to:
  /// **'Green line = expected daily spend if the coming month behaves like the last one.'**
  String get greenLineExpected;

  /// No description provided for @spikesHighlight.
  ///
  /// In en, this message translates to:
  /// **'Spikes highlight weeks where your habits usually get pricier (hello, Friday takeaway).'**
  String get spikesHighlight;

  /// No description provided for @forecastUpdates.
  ///
  /// In en, this message translates to:
  /// **'When you log fresh transactions, the forecast gently updates—no need to refresh.'**
  String get forecastUpdates;

  /// No description provided for @spotExpensivePatterns.
  ///
  /// In en, this message translates to:
  /// **'Spot expensive patterns early and stash a mini-buffer before they arrive.'**
  String get spotExpensivePatterns;

  /// No description provided for @catchQuieterWeeks.
  ///
  /// In en, this message translates to:
  /// **'Catch quieter weeks where you can sweep extra cash into savings or debt payoff.'**
  String get catchQuieterWeeks;

  /// No description provided for @timeRecurringPayments.
  ///
  /// In en, this message translates to:
  /// **'Use the insight to time recurring payments, subscriptions, or top-ups.'**
  String get timeRecurringPayments;

  /// No description provided for @bigSpikeComing.
  ///
  /// In en, this message translates to:
  /// **'Big spike coming? Pre-book cheaper options or shuffle flexible spends to calmer days.'**
  String get bigSpikeComing;

  /// No description provided for @forecastDipping.
  ///
  /// In en, this message translates to:
  /// **'Forecast dipping? Reward yourself by scheduling an extra savings transfer.'**
  String get forecastDipping;

  /// No description provided for @forecastLooksOff.
  ///
  /// In en, this message translates to:
  /// **'If the forecast looks off, review categories in the Home tab to tidy up any mislabels.'**
  String get forecastLooksOff;

  /// No description provided for @greenLineTrends.
  ///
  /// In en, this message translates to:
  /// **'Green line trends with your typical savings rate—upward momentum means your goals are funded.'**
  String get greenLineTrends;

  /// No description provided for @lineDipsSignals.
  ///
  /// In en, this message translates to:
  /// **'If the line dips, it signals future months where expenses tend to outrun income.'**
  String get lineDipsSignals;

  /// No description provided for @largeGoalsDebts.
  ///
  /// In en, this message translates to:
  /// **'Large goals or debts are included when you tag them in the Home tab.'**
  String get largeGoalsDebts;

  /// No description provided for @upwardSlope.
  ///
  /// In en, this message translates to:
  /// **'An upward slope? Celebrate and consider boosting retirement or travel savings.'**
  String get upwardSlope;

  /// No description provided for @flatSlipping.
  ///
  /// In en, this message translates to:
  /// **'Flat or slipping? Time to tune budgets or boost income streams before it snowballs.'**
  String get flatSlipping;

  /// No description provided for @watchSeasonalTrends.
  ///
  /// In en, this message translates to:
  /// **'Watch for seasonal trends—holidays, school terms, or annual renewals often show here first.'**
  String get watchSeasonalTrends;

  /// No description provided for @schedulePaymentIncreases.
  ///
  /// In en, this message translates to:
  /// **'Schedule gentle payment increases on loans when the curve is rising.'**
  String get schedulePaymentIncreases;

  /// No description provided for @planAheadDips.
  ///
  /// In en, this message translates to:
  /// **'Plan ahead for dips by earmarking sinking funds or trimming optional spends.'**
  String get planAheadDips;

  /// No description provided for @checkProjectionMonthly.
  ///
  /// In en, this message translates to:
  /// **'Check the projection monthly to keep your long game fun and flexible.'**
  String get checkProjectionMonthly;

  /// No description provided for @categoryHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Healthcare'**
  String get categoryHealthcare;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @deleteExpense.
  ///
  /// In en, this message translates to:
  /// **'Delete Expense'**
  String get deleteExpense;

  /// No description provided for @confirmDeleteExpense.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this expense? This action cannot be undone.'**
  String get confirmDeleteExpense;

  /// No description provided for @expenseDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted successfully'**
  String get expenseDeletedSuccessfully;

  /// No description provided for @failedToDeleteExpense.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete expense'**
  String get failedToDeleteExpense;

  /// No description provided for @expenseNotFoundOrDeleted.
  ///
  /// In en, this message translates to:
  /// **'Expense not found or has been deleted'**
  String get expenseNotFoundOrDeleted;

  /// No description provided for @onlyAdminsAndOwnersCanEditHouseholdSettings.
  ///
  /// In en, this message translates to:
  /// **'Only admins and owners can edit household settings'**
  String get onlyAdminsAndOwnersCanEditHouseholdSettings;

  /// No description provided for @onlyAdminsAndOwnersCanCreateInvitations.
  ///
  /// In en, this message translates to:
  /// **'Only admins and owners can create invitations'**
  String get onlyAdminsAndOwnersCanCreateInvitations;

  /// No description provided for @shareInvitationForHousehold.
  ///
  /// In en, this message translates to:
  /// **'Share invitation for {householdName} household'**
  String shareInvitationForHousehold(String householdName);

  /// No description provided for @shareInvitation.
  ///
  /// In en, this message translates to:
  /// **'Share Invitation'**
  String get shareInvitation;

  /// No description provided for @householdCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Household {householdName} created successfully'**
  String householdCreatedSuccessfully(String householdName);

  /// No description provided for @householdCreatedSuccessfullyWithQuotes.
  ///
  /// In en, this message translates to:
  /// **'Household \"{householdName}\" created successfully!'**
  String householdCreatedSuccessfullyWithQuotes(String householdName);

  /// No description provided for @invitationLink.
  ///
  /// In en, this message translates to:
  /// **'Invitation Link'**
  String get invitationLink;

  /// No description provided for @invitationLinkWithUrl.
  ///
  /// In en, this message translates to:
  /// **'Invitation link: {inviteUrl}'**
  String invitationLinkWithUrl(String inviteUrl);

  /// No description provided for @copyInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'Copy invitation link'**
  String get copyInvitationLink;

  /// No description provided for @copyInvitationLinkToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy invitation link to clipboard'**
  String get copyInvitationLinkToClipboard;

  /// No description provided for @shareInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'Share invitation link'**
  String get shareInvitationLink;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @closeShareSheet.
  ///
  /// In en, this message translates to:
  /// **'Close share sheet'**
  String get closeShareSheet;

  /// No description provided for @invitationLinkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Invitation link copied to clipboard!'**
  String get invitationLinkCopiedToClipboard;

  /// No description provided for @joinMyHouseholdMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my household \"{householdName}\" on Moneko!\n\n{inviteUrl}'**
  String joinMyHouseholdMessage(String householdName, String inviteUrl);

  /// No description provided for @joinMyHouseholdSubject.
  ///
  /// In en, this message translates to:
  /// **'Join my household on Moneko'**
  String get joinMyHouseholdSubject;

  /// No description provided for @zeroAmount.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get zeroAmount;

  /// No description provided for @dollarPrefix.
  ///
  /// In en, this message translates to:
  /// **'\$ '**
  String get dollarPrefix;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @budgetBoop.
  ///
  /// In en, this message translates to:
  /// **'Budget Boop'**
  String get budgetBoop;

  /// No description provided for @getGentleReminder.
  ///
  /// In en, this message translates to:
  /// **'Get a gentle reminder when you reach this threshold'**
  String get getGentleReminder;

  /// No description provided for @purrSuasiveNudge.
  ///
  /// In en, this message translates to:
  /// **'Purr-suasive Nudge'**
  String get purrSuasiveNudge;

  /// No description provided for @getStrongerNudge.
  ///
  /// In en, this message translates to:
  /// **'Get a stronger nudge when you reach this threshold'**
  String get getStrongerNudge;

  /// No description provided for @createBudgetButton.
  ///
  /// In en, this message translates to:
  /// **'Create Budget'**
  String get createBudgetButton;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @householdBudgetType.
  ///
  /// In en, this message translates to:
  /// **'Household Budget'**
  String get householdBudgetType;

  /// No description provided for @personalBudgetType.
  ///
  /// In en, this message translates to:
  /// **'Personal Budget'**
  String get personalBudgetType;

  /// No description provided for @joinHouseholdName.
  ///
  /// In en, this message translates to:
  /// **'Join \"{householdName}\"'**
  String joinHouseholdName(String householdName);

  /// No description provided for @householdPreview.
  ///
  /// In en, this message translates to:
  /// **'Household preview: {householdName}, invited by {inviterEmail}'**
  String householdPreview(String householdName, String inviterEmail);

  /// No description provided for @invitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {inviterEmail}'**
  String invitedBy(String inviterEmail);

  /// No description provided for @invitationExpiresSoon.
  ///
  /// In en, this message translates to:
  /// **'Invitation expires soon on {formattedDate}'**
  String invitationExpiresSoon(String formattedDate);

  /// No description provided for @invitationValidUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation valid until'**
  String get invitationValidUntilLabel;

  /// No description provided for @personalMessageFromInviter.
  ///
  /// In en, this message translates to:
  /// **'Personal message from inviter'**
  String get personalMessageFromInviter;

  /// No description provided for @messageFromInviter.
  ///
  /// In en, this message translates to:
  /// **'Message from inviter'**
  String get messageFromInviter;

  /// No description provided for @joiningHousehold.
  ///
  /// In en, this message translates to:
  /// **'Joining household...'**
  String get joiningHousehold;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {errorMessage}'**
  String errorWithMessage(String errorMessage);

  /// No description provided for @anUnexpectedErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get anUnexpectedErrorOccurred;

  /// No description provided for @invalidInvitationLinkFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid invitation link format'**
  String get invalidInvitationLinkFormat;

  /// No description provided for @invalidOrExpiredInvitation.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired invitation'**
  String get invalidOrExpiredInvitation;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @inDays.
  ///
  /// In en, this message translates to:
  /// **'in {days} days'**
  String inDays(int days);

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get december;

  /// No description provided for @remindUser.
  ///
  /// In en, this message translates to:
  /// **'Remind {name}'**
  String remindUser(String name);

  /// No description provided for @sendFriendlySpendingReminder.
  ///
  /// In en, this message translates to:
  /// **'Send a friendly spending reminder'**
  String get sendFriendlySpendingReminder;

  /// No description provided for @addMessageOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a message (optional)'**
  String get addMessageOptional;

  /// No description provided for @messageHintExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Your wallet needs a rest!\"'**
  String get messageHintExample;

  /// No description provided for @sendReminder.
  ///
  /// In en, this message translates to:
  /// **'Send Reminder'**
  String get sendReminder;

  /// No description provided for @pleaseWait24HoursBeforeSendingAnotherReminder.
  ///
  /// In en, this message translates to:
  /// **'Please wait 24 hours before sending another reminder to {name}'**
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name);

  /// No description provided for @reminderSentToName.
  ///
  /// In en, this message translates to:
  /// **'Reminder sent to {name}! 🔔'**
  String reminderSentToName(String name);

  /// No description provided for @failedToSendReminderTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reminder. Please try again.'**
  String get failedToSendReminderTryAgain;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @addIncome.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get addIncome;

  /// No description provided for @incomeAdded.
  ///
  /// In en, this message translates to:
  /// **'Income added successfully'**
  String get incomeAdded;

  /// No description provided for @noIncome.
  ///
  /// In en, this message translates to:
  /// **'No Income Yet'**
  String get noIncome;

  /// No description provided for @noIncomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Record your income to track your household\'s financial health'**
  String get noIncomeDescription;

  /// No description provided for @totalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get totalIncome;

  /// No description provided for @monthToDate.
  ///
  /// In en, this message translates to:
  /// **'Month-to-Date'**
  String get monthToDate;

  /// No description provided for @yearToDate.
  ///
  /// In en, this message translates to:
  /// **'YTD'**
  String get yearToDate;

  /// No description provided for @failedToLoadIncome.
  ///
  /// In en, this message translates to:
  /// **'Failed to load income'**
  String get failedToLoadIncome;

  /// No description provided for @incomeAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Income acknowledged'**
  String get incomeAcknowledged;

  /// No description provided for @acknowledge.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get acknowledge;

  /// No description provided for @acknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get acknowledged;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @sourceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Employer, Client'**
  String get sourceHint;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @privacyScope.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyScope;

  /// No description provided for @privacyFull.
  ///
  /// In en, this message translates to:
  /// **'Full Details'**
  String get privacyFull;

  /// No description provided for @privacyBalancesOnly.
  ///
  /// In en, this message translates to:
  /// **'Balances Only'**
  String get privacyBalancesOnly;

  /// No description provided for @privacyPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privacyPrivate;

  /// No description provided for @privacyFullExplanation.
  ///
  /// In en, this message translates to:
  /// **'Partner can see all details including amount, source, and description.'**
  String get privacyFullExplanation;

  /// No description provided for @privacyBalancesOnlyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Partner can see this income in totals but not the details (source, description hidden).'**
  String get privacyBalancesOnlyExplanation;

  /// No description provided for @privacyPrivateExplanation.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this income. It contributes to household totals but partner cannot see details.'**
  String get privacyPrivateExplanation;

  /// No description provided for @incomeSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get incomeSalary;

  /// No description provided for @incomeFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get incomeFreelance;

  /// No description provided for @incomeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get incomeInvestment;

  /// No description provided for @incomeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get incomeRefund;

  /// No description provided for @incomeGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get incomeGift;

  /// No description provided for @incomeBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get incomeBonus;

  /// No description provided for @incomeRental.
  ///
  /// In en, this message translates to:
  /// **'Rental'**
  String get incomeRental;

  /// No description provided for @incomeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get incomeOther;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @createGoal.
  ///
  /// In en, this message translates to:
  /// **'Create Goal'**
  String get createGoal;

  /// No description provided for @goalCreated.
  ///
  /// In en, this message translates to:
  /// **'Goal created successfully'**
  String get goalCreated;

  /// No description provided for @goalTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal Title'**
  String get goalTitle;

  /// No description provided for @enterGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter goal title'**
  String get enterGoalTitle;

  /// No description provided for @pleaseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// No description provided for @pleaseEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get pleaseEnterAmount;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount greater than 0'**
  String get invalidAmount;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target Amount'**
  String get targetAmount;

  /// No description provided for @currentAmount.
  ///
  /// In en, this message translates to:
  /// **'Current Amount'**
  String get currentAmount;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target Date'**
  String get targetDate;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional note'**
  String get descriptionHint;

  /// No description provided for @savings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savings;

  /// No description provided for @paydown.
  ///
  /// In en, this message translates to:
  /// **'Pay Down'**
  String get paydown;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @offTrack.
  ///
  /// In en, this message translates to:
  /// **'Off Track'**
  String get offTrack;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On Track'**
  String get onTrack;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @overallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get overallProgress;

  /// No description provided for @totalGoals.
  ///
  /// In en, this message translates to:
  /// **'Total Goals'**
  String get totalGoals;

  /// No description provided for @noGoals.
  ///
  /// In en, this message translates to:
  /// **'No goals yet. Create your first goal to get started!'**
  String get noGoals;

  /// No description provided for @noSavingsGoals.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet. Create one to start saving!'**
  String get noSavingsGoals;

  /// No description provided for @noPaydownGoals.
  ///
  /// In en, this message translates to:
  /// **'No paydown goals yet. Create one to start reducing debt!'**
  String get noPaydownGoals;

  /// No description provided for @goalAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Goal acknowledged'**
  String get goalAcknowledged;

  /// No description provided for @balancesOnly.
  ///
  /// In en, this message translates to:
  /// **'Balances Only'**
  String get balancesOnly;

  /// No description provided for @contribution.
  ///
  /// In en, this message translates to:
  /// **'Contribution'**
  String get contribution;

  /// No description provided for @withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get withdrawal;

  /// No description provided for @interest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interest;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustment;

  /// No description provided for @addContribution.
  ///
  /// In en, this message translates to:
  /// **'Add Contribution'**
  String get addContribution;

  /// No description provided for @contributionAmount.
  ///
  /// In en, this message translates to:
  /// **'Contribution Amount'**
  String get contributionAmount;

  /// No description provided for @contributionType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get contributionType;

  /// No description provided for @contributionAdded.
  ///
  /// In en, this message translates to:
  /// **'Contribution added successfully'**
  String get contributionAdded;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'es', 'fr', 'it', 'ja', 'kr', 'nl', 'pks', 'ru', 'uk', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'it': return AppLocalizationsIt();
    case 'ja': return AppLocalizationsJa();
    case 'kr': return AppLocalizationsKr();
    case 'nl': return AppLocalizationsNl();
    case 'pks': return AppLocalizationsPks();
    case 'ru': return AppLocalizationsRu();
    case 'uk': return AppLocalizationsUk();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
