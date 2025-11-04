// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Pakistan Sign Language (`pks`).
class AppLocalizationsPks extends AppLocalizations {
  AppLocalizationsPks([String locale = 'pks']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'ابھی تک کوئی خرچ نہیں';

  @override
  String get loginWelcomeBack => 'دوبارہ خوش آمدید';

  @override
  String get orContinueWithEmail => 'یا ای میل کے ساتھ جاری رکھیں';

  @override
  String get emailAddress => 'ای میل ایڈریس';

  @override
  String get password => 'پاس ورڈ';

  @override
  String get forgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get signIn => 'سائن ان کریں';

  @override
  String get newToMoneko => 'مونیکو پر نئے ہیں؟';

  @override
  String get createAccount => 'اکاؤنٹ بنائیں';

  @override
  String get resetYourPassword => 'اپنا پاس ورڈ ری سیٹ کریں';

  @override
  String get email => 'ای میل';

  @override
  String get exampleEmail => 'you@example.com';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String get sendResetLink => 'ری سیٹ لنک بھیجیں';

  @override
  String get passwordResetEmailSent => 'پاس ورڈ ری سیٹ ای میل بھیج دی گئی ہے۔ اپنا ان باکس چیک کریں۔';

  @override
  String get enterValidEmail => 'براہ کرم ایک درست ای میل ایڈریس درج کریں۔';

  @override
  String passwordMinLength(int min) {
    return 'پاس ورڈ کم از کم $min حروف پر مشتمل ہونا چاہیے۔';
  }

  @override
  String fullNameMinLength(int min) {
    return 'پورا نام کم از کم $min حروف پر مشتمل ہونا چاہیے۔';
  }

  @override
  String get createYourAccount => 'اپنا اکاؤنٹ بنائیں';

  @override
  String get fullName => 'پورا نام';

  @override
  String get createPassword => 'پاس ورڈ بنائیں';

  @override
  String get passwordComplexityRequirement => 'پاس ورڈ میں کم از کم ایک بڑا حرف (uppercase)، ایک چھوٹا حرف (lowercase)، اور ایک نمبر ہونا چاہیے۔';

  @override
  String get passwordRequirementShort => 'پاس ورڈ: 8+ حروف، بشمول بڑا، چھوٹا حرف اور نمبر۔';

  @override
  String get termsAgreement => 'اکاؤنٹ بنا کر، آپ ہماری سروس کی شرائط (Terms of Service) اور رازداری کی پالیسی (Privacy Policy) سے اتفاق کرتے ہیں۔';

  @override
  String get alreadyHaveAccount => 'پہلے سے اکاؤنٹ ہے؟';

  @override
  String get signInLower => 'سائن ان کریں';

  @override
  String get verificationCodeSent => 'تصدیقی کوڈ کامیابی سے بھیج دیا گیا۔';

  @override
  String get verifyYourEmail => 'اپنا ای میل تصدیق کریں';

  @override
  String verificationEmailSentTo(String email) {
    return 'ہم نے $email پر 6 ہندسوں کا تصدیقی کوڈ بھیجا ہے۔';
  }

  @override
  String get enterCompleteCode => 'براہ کرم 6 ہندسوں کا مکمل کوڈ درج کریں۔';

  @override
  String get invalidVerificationCode => 'غلط تصدیقی کوڈ';

  @override
  String get verificationCodeExpired => 'تصدیقی کوڈ کی میعاد ختم ہو گیا ہے۔ براہ کرم نیا کوڈ طلب کریں۔';

  @override
  String get verifyEmail => 'ای میل کی تصدیق کریں';

  @override
  String get didntReceiveTheCode => 'کوڈ موصول نہیں ہوا؟ اپنا اسپام فولڈر چیک کریں یا';

  @override
  String resendInSeconds(int seconds) {
    return '$seconds سیکنڈ میں دوبارہ بھیجیں';
  }

  @override
  String get resendVerificationEmail => 'تصدیقی ای میل دوبارہ بھیجیں';

  @override
  String get continueWithGoogle => 'گوگل کے ساتھ سائن ان کریں';

  @override
  String get signingInWithGoogle => 'گوگل کے ساتھ سائن ان ہو رہا ہے۔۔۔';

  @override
  String get error => 'خرابی';

  @override
  String get anErrorOccurred => 'ایک خرابی پیش آئی۔';

  @override
  String get unknownError => 'نامعلوم خرابی۔';

  @override
  String get goToHome => 'ہوم پر جائیں';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ ادائیگی کامیاب! سبسکرپشن چیک کی جا رہی ہے۔۔۔';

  @override
  String get paymentFailed => 'ادائیگی ناکام';

  @override
  String get paymentCanceled => 'ℹ️ ادائیگی منسوخ کر دی گئی';

  @override
  String get whatsappVerifiedSuccessfully => '✅ واٹس ایپ کامیابی سے تصدیق ہو گیا!';

  @override
  String get settings => 'سیٹنگز';

  @override
  String get enableNotificationsInSettings => 'اپنے ڈیوائس کی سیٹنگز میں مونیکو کے لیے نوٹیفکیشنز آن کریں۔';

  @override
  String get appearance => 'ظاہری شکل';

  @override
  String get darkMode => 'ڈارک موڈ';

  @override
  String get notifications => 'نوٹیفکیشنز';

  @override
  String get pushNotifications => 'پش نوٹیفکیشنز';

  @override
  String get receiveAlertsAndUpdates => 'الرٹس اور اپ ڈیٹس موصول کریں';

  @override
  String get language => 'زبان';

  @override
  String get systemDefault => 'سسٹم ڈیفالٹ';

  @override
  String get membership => 'ممبرشپ';

  @override
  String get loading => 'لوڈ ہو رہا ہے۔۔۔';

  @override
  String get failedToLoadMembership => 'ممبرشپ لوڈ کرنے میں ناکامی';

  @override
  String get couldNotOpenMembershipPage => 'ممبرشپ صفحہ نہیں کھل سکا';

  @override
  String get freePlan => 'مفت';

  @override
  String get freePlanStatus => 'مفت پلان';

  @override
  String get lifetimePlan => 'لائف ٹائم';

  @override
  String get plusPlan => 'پلس';

  @override
  String get plusMonthlyPlan => 'پلس ماہانہ';

  @override
  String get plusYearlyPlan => 'پلس سالانہ';

  @override
  String get activeStatus => 'فعال';

  @override
  String get activeLifetimeStatus => 'فعال • لائف ٹائم';

  @override
  String get canceledStatus => 'منسوخ شدہ';

  @override
  String get pastDueStatus => 'واجب الادا';

  @override
  String get trialStatus => 'ٹرائل';

  @override
  String trialEndsInDays(int days) {
    return 'ٹرائل $days دنوں میں ختم ہو جائے گا';
  }

  @override
  String get trialEnded => 'ٹرائل ختم ہو گیا';

  @override
  String renewsInDays(int days) {
    return '$days دنوں میں تجدید ہو گی';
  }

  @override
  String accessEndsInDays(int days) {
    return 'رسائی $days دنوں میں ختم ہو جائے گی';
  }

  @override
  String get subscriptionEnded => 'سبسکرپشن ختم ہو گئی';

  @override
  String get profile => 'پروفائل';

  @override
  String get errorLoadingProfile => 'پروفائل لوڈ کرنے میں خرابی';

  @override
  String get user => 'صارف';

  @override
  String get proBadge => 'پرو';

  @override
  String get whatsAppConnected => 'واٹس ایپ منسلک ہے';

  @override
  String get logExpensesViaWhatsApp => 'واٹس ایپ پیغامات کے ذریعے اخراجات لاگ کریں';

  @override
  String get connectWhatsApp => 'واٹس ایپ منسلک کریں';

  @override
  String get newBadge => 'نیا';

  @override
  String get logExpensesInstantly => 'چیٹ کے ذریعے فوری طور پر اخراجات لاگ کریں';

  @override
  String get fast => 'تیز';

  @override
  String get photo => 'تصویر';

  @override
  String get autoSync => 'آٹو-سنک';

  @override
  String get naturalLanguage => 'عام زبان';

  @override
  String get describeExpenseAutomatically => 'اپنا خرچ بیان کریں۔ ہم اسے خود بخود لاگ کر لیں گے۔';

  @override
  String get snapReceipt => 'رسید کی تصویر لیں';

  @override
  String get snapReceiptDescription => 'اپنی رسید کی تصویر لیں۔ AI تفصیلات نکال کر لاگ کر دے گا۔';

  @override
  String get previous => 'پچھلا';

  @override
  String get next => 'اگلا';

  @override
  String get overview => 'جائزہ';

  @override
  String get activity => 'سرگرمی';

  @override
  String get accountInformation => 'اکاؤنٹ کی معلومات';

  @override
  String get userId => 'صارف آئی ڈی';

  @override
  String get recentActivity => 'حالیہ سرگرمی';

  @override
  String get noActivityYet => 'ابھی تک کوئی سرگرمی نہیں';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get insights => 'تجزیے';

  @override
  String get runningTab => 'موجودہ';

  @override
  String get day30Tab => '30-دن';

  @override
  String get longTermTab => 'طویل مدتی';

  @override
  String get scenarioTab => 'منظرنامہ';

  @override
  String get runningAndDailyBalances => 'رننگ اور یومیہ بیلنس';

  @override
  String get budgetVsSpentDescription => 'بجٹ بمقابلہ خرچ (روزانہ) مع مجموعی رننگ بیلنس۔';

  @override
  String get runningBalanceLegend => 'رننگ بیلنس';

  @override
  String get budgetLegend => 'بجٹ';

  @override
  String get spentLegend => 'خرچ شدہ';

  @override
  String get runningBalanceGuide => 'رننگ بیلنس گائیڈ';

  @override
  String get runningBalanceIntro => 'اس چارٹ کو اپنا ذاتی منی کوچ سمجھیں۔ آئیے دیکھتے ہیں کہ یہ کیا دکھاتا ہے اور اسے کیسے استعمال کرنا ہے۔';

  @override
  String get day30LookAhead => '30-دن کا پیش منظر';

  @override
  String get projectedFromTrailing30Days => 'گزشتہ 30 دن کے اوسط کی بنیاد پر تخمینہ۔';

  @override
  String get projectedSpendingLegend => 'متوقع اخراجات';

  @override
  String get peek30DaysAhead => 'آگے 30 دنوں پر ایک نظر';

  @override
  String get day30ForecastIntro => 'یہ پیشن گوئی پچھلے مہینے کی سرگرمی کی بنیاد پر اگلے مہینے کا اندازہ لگاتی ہے۔ اسے اپنے بٹوے (wallet) کا موسمی رپورٹ سمجھیں۔';

  @override
  String get longTermProjection => 'طویل مدتی تخمینہ';

  @override
  String get basedOnHistoricalAverages => 'تاریخی اوسط کی بنیاد پر؛ آپ کے ڈیٹا کے ساتھ خود بخود اپ ڈیٹ ہوتا ہے۔';

  @override
  String get month18ProjectionLegend => '18-ماہ کا تخمینہ';

  @override
  String get your18MonthHorizon => 'آپ کا 18-ماہ کا افق۔';

  @override
  String get longTermIntro => 'یہ تخمینہ آپ کی مستقل عادات کو معمولی ترقی کے مفروضوں کے ساتھ ملاتا ہے تاکہ آپ دیکھ سکیں کہ آپ کے آج کے فیصلے کہاں لے جاتے ہیں۔';

  @override
  String get aiScenarioPlanning => 'AI منظر نامہ کی منصوبہ بندی';

  @override
  String get askAiFinancialAdvisor => 'اپنے AI مالیاتی مشیر سے پوچھیں کہ کیا آپ مستقبل کے کسی خرچ کے متحمل ہو سکتے ہیں';

  @override
  String get canI => 'کیا میں';

  @override
  String get before => 'سے پہلے';

  @override
  String get beforePrefix => 'سے پہلے';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'تاریخ منتخب کریں';

  @override
  String get check => 'چیک کریں';

  @override
  String get enterQuestionAndPickDate => 'براہ کرم ایک سوال درج کریں اور تاریخ منتخب کریں';

  @override
  String get analyzingScenario => 'منظر نامے کا تجزیہ کیا جا رہا ہے۔۔۔';

  @override
  String get thisMightTakeAWhile => 'اس میں کچھ وقت لگ سکتا ہے۔';

  @override
  String get whereTheMoneyWent => 'پیسہ کہاں گیا';

  @override
  String get categoryTotalsForSelectedRange => 'منتخب مدت کے لیے کیٹیگری کے کل اخراجات۔';

  @override
  String get scenarioCategoriesGuide => 'کیٹیگریز کو سمجھیں';

  @override
  String get categoryGuideIntro => 'اس چارٹ کو ایک فضائی منظر کے طور پر سوچیں کہ ہر روپیہ کہاں گیا۔ اسے پڑھنے کا طریقہ یہاں ہے، بغیر کیلکولیٹر کے۔';

  @override
  String get readTheBarChartLikeAPro => 'بار چارٹ کو ایک پرو کی طرح پڑھیں';

  @override
  String get categoryChartDesc => 'منتخب مدت کے لیے کیٹیگری کے لحاظ سے تفصیل۔';

  @override
  String get whyThisViewIsHelpful => 'یہ منظر کیوں مددگار ہے';

  @override
  String get categoryWhyHelpfulDesc => 'اپنے سب سے بڑے اخراجات کی کیٹیگریز کو تیزی سے شناخت کریں اور وقت کے ساتھ رجحانات کو دیکھیں۔';

  @override
  String get whatToDoWithTheInsight => 'اس معلومات کا کیا کریں';

  @override
  String get categoryWhatToDoDesc => 'اس معلومات کو اپنے بجٹ اور اخراجات کی عادات کو ایڈجسٹ کرنے کے لیے استعمال کریں۔';

  @override
  String get scenarioAnalysis => 'منظر نامے کا تجزیہ';

  @override
  String get target => 'ہدف';

  @override
  String get quickStats => 'فوری اعدادوشمار';

  @override
  String get currentBalance => 'موجودہ بیلنس';

  @override
  String get projectedNoChange => 'متوقع (بغیر تبدیلی کے)';

  @override
  String get avgDailyNet => 'اوسط یومیہ نیٹ کیش فلو';

  @override
  String get noDataAvailable => 'کوئی ڈیٹا دستیاب نہیں۔';

  @override
  String get day => 'دن';

  @override
  String get close => 'بند کریں';

  @override
  String get done => 'ہو گیا';

  @override
  String get whatYouAreSeeing => 'آپ کیا دیکھ رہے ہیں';

  @override
  String get whyItMatters => 'یہ کیوں اہم ہے';

  @override
  String get howToRespond => 'کیسے جواب دیں';

  @override
  String get runningBalanceWhatYouSeeDesc => 'آپ کا رننگ بیلنس ٹریک کرتا ہے کہ ہر دن کے خرچ کے بعد آپ کے پاس کتنی گنجائش ہے۔ یومیہ بارز دکھاتے ہیں کہ آپ نے کیا منصوبہ بنایا تھا بمقابلہ اصل میں کیا خرچ کیا۔';

  @override
  String get runningBalanceWhyMattersDesc => 'اسے ایک دوستانہ پلس چیک سمجھیں۔ یہ آپ کو یہ جاننے میں مدد کرتا ہے کہ آپ کب منصوبے سے آگے ہیں تاکہ آپ سرمایہ کاری جاری رکھ سکیں، یا کب تھوڑی سی اصلاح آپ کو ٹریک پر رکھے گی۔';

  @override
  String get runningBalanceHowToRespondDesc => 'چارٹ کو ایک کوچ کی طرح استعمال کریں۔ کامیابیوں کا جشن منائیں، ضرورت پڑنے پر توقعات کو دوبارہ ترتیب دیں، اور خود کو رعایت دیں — یہ مستقل ترقی کے بارے میں ہے، کمال کے بارے میں نہیں۔';

  @override
  String get whatTheForecastShows => 'پیشن گوئی کیا دکھاتی ہے';

  @override
  String get day30WhatShowsDesc => 'ہم گزشتہ 30 دنوں کے اخراجات اور آمدنی کو ملا کر آنے والے اوسط ہفتے کا خاکہ بناتے ہیں۔ یہ ایک بار کے بڑے اخراجات کو ہموار کرتا ہے تاکہ آپ معمول کی رفتار دیکھ سکیں۔';

  @override
  String get day30WhyMattersDesc => 'مستقبل پر نظر رکھنے والے بجٹ آپ کو فعال رہنے میں مدد دیتے ہیں۔ آگے بڑے دنوں کو دیکھ کر آپ بعد میں ہاتھ پاؤں مارنے کے بجائے پہلے سے کیش ایک طرف رکھ سکتے ہیں۔';

  @override
  String get day30HowToPlaySmartDesc => 'اسے ایک دوستانہ اشارہ سمجھیں، نہ کہ سخت اصولوں کی کتاب۔ اپنے منصوبے کو چھوٹی چھوٹی تبدیلیوں کے ساتھ ایڈجسٹ کریں جو قابل عمل محسوس ہوں۔';

  @override
  String get howTheProjectionWorks => 'تخمینہ کیسے کام کرتا ہے';

  @override
  String get longTermHowWorksDesc => 'ہم آپ کی اوسط آمدنی اور اخراجات کو آگے بڑھاتے ہیں، جس میں معمولی اضافہ شامل کرتے ہیں تاکہ آپ دیکھ سکیں کہ کیا آپ کا منصوبہ مہینوں آگے تک کیش کو آرام دہ رکھتا ہے۔';

  @override
  String get longTermWhyMattersDesc => 'طویل افق بڑے خوابوں کو حقیقت بناتے ہیں۔ دیکھیں کہ کیا آپ کا ایمرجنسی فنڈ، سرمایہ کاری، یا بڑی خریداری ٹریک پر رہتی ہیں۔';

  @override
  String get longTermMovesToConsiderDesc => 'مستقبل کے فیصلوں کی ریہرسل کے لیے چارٹ کا استعمال کریں۔ آج کی چھوٹی تبدیلیاں بعد میں بڑی جیت میں بدل جاتی ہیں۔';

  @override
  String get forMe => 'میرے لیے';

  @override
  String get forUs => 'ہمارے لیے';

  @override
  String get home => 'ہوم';

  @override
  String get reminder => 'یاد دہانی';

  @override
  String get analyzingReceipt => 'رسید کا تجزیہ کیا جا رہا ہے۔۔۔';

  @override
  String get analyzingExpense => 'خرچ کا تجزیہ کیا جا رہا ہے۔۔۔';

  @override
  String get noExpenseInformationExtracted => 'خرچ کی کوئی معلومات نہیں ملی';

  @override
  String get failedToAnalyzeNoData => 'تجزیہ ناکام: کوئی ڈیٹا واپس نہیں آیا';

  @override
  String get failedToAnalyze => 'تجزیہ ناکام';

  @override
  String get updateBudget => 'بجٹ اپ ڈیٹ کریں';

  @override
  String get enterNewTotalDailyBudget => 'نیا کل یومیہ بجٹ درج کریں۔';

  @override
  String get budgetAmount => 'بجٹ کی رقم';

  @override
  String get save => 'محفوظ کریں';

  @override
  String get enterValidAmountGreaterThan0 => '0 سے زیادہ درست رقم درج کریں';

  @override
  String get updatingBudget => 'بجٹ اپ ڈیٹ ہو رہا ہے۔۔۔';

  @override
  String get budgetUpdated => 'بجٹ اپ ڈیٹ ہو گیا';

  @override
  String get failedToUpdateBudget => 'بجٹ اپ ڈیٹ کرنے میں ناکامی';

  @override
  String get loggedSuccessfully => 'کامیابی سے لاگ ہو گیا';

  @override
  String get view => 'دیکھیں';

  @override
  String get retry => 'دوبارہ کوشش کریں';

  @override
  String get failedToCapturePhoto => 'تصویر لینے میں ناکامی';

  @override
  String get noSpendingData => 'اخراجات کا کوئی ڈیٹا نہیں';

  @override
  String get byCategory => 'کیٹیگری کے لحاظ سے';

  @override
  String get noExpensesYet => 'ابھی تک کوئی اخراجات نہیں';

  @override
  String get startLoggingExpensesToSeeCategories => 'کیٹیگریز دیکھنے کے لیے اخراجات لاگ کرنا شروع کریں';

  @override
  String get selectDateRange => 'تاریخ کی حد منتخب کریں';

  @override
  String get addExpense => 'خرچ شامل کریں';

  @override
  String get describeYourExpense => 'اپنا خرچ بیان کریں (مثال: \"برگر 500، کافی 300\")';

  @override
  String get enterExpenseDetails => 'خرچ کی تفصیلات درج کریں۔۔۔';

  @override
  String get freeFormText => 'فری فارم ٹیکسٹ';

  @override
  String get takePhoto => 'تصویر لیں';

  @override
  String get transactions => 'ٹرانزیکشنز';

  @override
  String get negative => 'منفی';

  @override
  String get positive => 'مثبت';

  @override
  String get spendingBreakdown => 'اخراجات کی تفصیل';

  @override
  String get spent => 'خرچ شدہ';

  @override
  String get today => 'آج';

  @override
  String get yesterday => 'گزشتہ کل';

  @override
  String get thisWeek => 'اس ہفتے';

  @override
  String get lastWeek => 'پچھلے ہفتے';

  @override
  String get thisMonth => 'اس مہینے';

  @override
  String get last30Days => 'پچھلے 30 دن';

  @override
  String get customRange => 'مخصوص مدت';

  @override
  String get spentToday => 'آپ کے آج کے اخراجات';

  @override
  String get spentYesterday => 'آپ کے کل کے اخراجات';

  @override
  String get spentThisWeek => 'آپ کے اس ہفتے کے اخراجات';

  @override
  String get spentLastWeek => 'آپ کے پچھلے ہفتے کے اخراجات';

  @override
  String get spentThisMonth => 'آپ کے اس مہینے کے اخراجات';

  @override
  String get spentLast30Days => 'آپ کے اخراجات (پچھلے 30 دن)';

  @override
  String get spentCustom => 'خرچ شدہ (مخصوص)';

  @override
  String get todaysBudget => 'آج کا بجٹ';

  @override
  String get yesterdaysBudget => 'گزشتہ کل کا بجٹ';

  @override
  String get sumOfDailyBudgetsThisWeek => 'اس ہفتے کے یومیہ بجٹ کا مجموعہ';

  @override
  String get sumOfDailyBudgetsLastWeek => 'پچھلے ہفتے کے یومیہ بجٹ کا مجموعہ';

  @override
  String get sumOfDailyBudgetsThisMonth => 'اس مہینے کے یومیہ بجٹ کا مجموعہ';

  @override
  String get sumOfDailyBudgetsLast30Days => 'پچھلے 30 دنوں کے یومیہ بجٹ کا مجموعہ';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'منتخب مدت کے لیے یومیہ بجٹ کا مجموعہ';

  @override
  String get netCashflowToday => 'آج کا نیٹ کیش فلو';

  @override
  String get netCashflowYesterday => 'گزشتہ کل کا نیٹ کیش فلو';

  @override
  String get netCashflowThisWeek => 'اس ہفتے کا نیٹ کیش فلو';

  @override
  String get netCashflowLastWeek => 'پچھلے ہفتے کا نیٹ کیش فلو';

  @override
  String get netCashflowThisMonth => 'اس مہینے کا نیٹ کیش فلو';

  @override
  String get netCashflowLast30Days => 'نیٹ کیش فلو (پچھلے 30 دن)';

  @override
  String get netCashflowCustom => 'نیٹ کیش فلو (مخصوص)';

  @override
  String get selectCurrency => 'کرنسی منتخب کریں';

  @override
  String get showLessCurrencies => 'کم کرنسیاں دکھائیں';

  @override
  String showAllCurrencies(int count) {
    return '$count مزید کرنسیاں دکھائیں';
  }

  @override
  String get budget => 'بجٹ';

  @override
  String get spentLabel => 'خرچ شدہ';

  @override
  String get net => 'نیٹ';

  @override
  String get txn => 'ٹرانزیکشن';

  @override
  String get txns => 'ٹرانزیکشنز';

  @override
  String get pleaseEnterExpenseDetails => 'براہ کرم خرچ کی تفصیلات درج کریں';

  @override
  String get userNotLoggedIn => 'صارف لاگ ان نہیں ہے';

  @override
  String get errorLoadingHouseholds => 'گروپس لوڈ کرنے میں خرابی';

  @override
  String get welcomeToHouseholds => 'گروپس میں خوش آمدید';

  @override
  String get householdsDescription => 'اپنے خاندان، پارٹنر، یا روم میٹس کے ساتھ مشترکہ مالیات کا انتظام کریں۔ بجٹ ٹریک کریں، اخراجات تقسیم کریں، اور پیسوں کے فیصلوں پر مل کر کام کریں۔';

  @override
  String get createHousehold => 'گروپ بنائیں';

  @override
  String get joinWithInvite => 'دعوت کے ساتھ شامل ہوں';

  @override
  String get pleaseUseInvitationLink => 'براہ کرم گروپ میں شامل ہونے کے لیے دعوتی لنک استعمال کریں';

  @override
  String get householdName => 'گروپ کا نام';

  @override
  String get householdNameHint => 'مثلاً، \'علی فیملی\'';

  @override
  String get pleaseEnterHouseholdName => 'براہ کرم گروپ کا نام درج کریں';

  @override
  String get errorCreatingHousehold => 'گروپ بنانے میں خرابی';

  @override
  String get householdsFeature => 'گروپس کا فیچر';

  @override
  String get householdsFeatureDescription => 'گروپس کا فیچر اب دستیاب ہے! خاندان، پارٹنرز، یا روم میٹس کے ساتھ مشترکہ مالیات کا انتظام کریں۔';

  @override
  String get gotIt => 'سمجھ گیا!';

  @override
  String get confirmExpense => 'خرچ کی تصدیق کریں';

  @override
  String get expenseDetails => 'خرچ کی تفصیلات';

  @override
  String get details => 'تفصیلات';

  @override
  String get category => 'کیٹیگری';

  @override
  String get currency => 'کرنسی';

  @override
  String get date => 'تاریخ';

  @override
  String get time => 'وقت';

  @override
  String get notes => 'نوٹس';

  @override
  String get receipt => 'رسید';

  @override
  String get saveExpense => 'خرچ محفوظ کریں';

  @override
  String get shareWithHousehold => 'گروپ کے ساتھ شیئر کریں';

  @override
  String get loadingHouseholdMembers => 'گروپ کے اراکین لوڈ ہو رہے ہیں۔۔۔';

  @override
  String get selectHouseholdToConfigureSplit => 'تقسیم سیٹ کرنے کے لیے گروپ منتخب کریں';

  @override
  String get currencyManagedByHousehold => 'کرنسی کا انتظام گروپ کے پاس ہے اور اسے تبدیل نہیں کیا جا سکتا';

  @override
  String get currencyCannotBeChanged => 'گروپ کے ساتھ شیئر کرتے وقت کرنسی تبدیل نہیں کی جا سکتی';

  @override
  String get failedToLoadImage => 'تصویر لوڈ کرنے میں ناکامی';

  @override
  String get editAmount => 'رقم میں ترمیم کریں';

  @override
  String get amount => 'رقم';

  @override
  String get editNotes => 'نوٹس میں ترمیم کریں';

  @override
  String get addANote => 'ایک نوٹ شامل کریں۔۔۔';

  @override
  String get noMembersFoundInHousehold => 'گروپ میں کوئی اراکین نہیں ملے';

  @override
  String get errorLoadingMembers => 'اراکین لوڈ کرنے میں خرابی';

  @override
  String get noExpenseToSave => 'محفوظ کرنے کے لیے کوئی خرچ نہیں';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'خرچ محفوظ اور شیئر ہو گیا$splitInfo!';
  }

  @override
  String get expenseSaved => 'خرچ محفوظ ہو گیا!';

  @override
  String failedToSave(String error) {
    return 'محفوظ کرنے میں ناکامی: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'کرنسی کی ترجیح سنک کرنے میں ناکامی: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'کرنسی کامیابی سے اپ ڈیٹ ہو گئی';

  @override
  String retryFailed(Object error) {
    return 'دوبارہ کوشش ناکام: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'میں نے $category پر $currencySymbol$amount خرچ کیے';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'نیا کل یومیہ بجٹ درج کریں۔';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'براہ کرم گروپ کی خصوصیات تک رسائی کے لیے سائن ان کریں';

  @override
  String get quickActions => 'فوری ایکشنز';

  @override
  String get members => 'اراکین';

  @override
  String get invites => 'دعوتیں';

  @override
  String get errorLoadingExpenses => 'اخراجات لوڈ کرنے میں خرابی';

  @override
  String get budgets => 'بجٹس';

  @override
  String get loadingHousehold => 'گروپ لوڈ ہو رہا ہے۔۔۔';

  @override
  String get remaining => 'باقی';

  @override
  String get overBudget => 'بجٹ سے زیادہ';

  @override
  String get sharedBudgets => 'مشترکہ بجٹس';

  @override
  String get netPosition => 'حتمی حساب';

  @override
  String get spentByHousehold => 'گروپ کے خرچے';

  @override
  String get memberSpending => 'ممبر کے لحاظ سے خرچے';

  @override
  String get spentByHouseholdTooltip => 'یہ منتخب مدت کے دوران تمام گروپ ممبرز کی طرف سے خرچ کی گئی کل رقم دکھاتا ہے۔ اس میں گروپ کے کسی بھی ممبر کی طرف سے درج کردہ تمام مشترکہ اخراجات شامل ہیں۔';

  @override
  String get manageMoneyTogether => 'اپنے پارٹنر، فیملی، یا روم میٹس کے ساتھ ایک مشترکہ جگہ پر مل کر پیسوں کا انتظام کریں۔';

  @override
  String get sharedBudgetsExpenses => 'مشترکہ بجٹ اور اخراجات';

  @override
  String get sharedBudgetsExpensesDesc => 'بجٹ سیٹ کریں، اخراجات کو ٹریک کریں، اور دیکھیں کہ آپ کے گروپ کا پیسہ حقیقی وقت میں کہاں جاتا ہے۔';

  @override
  String get smartExpenseSplitting => 'اسمارٹ خرچ کی تقسیم';

  @override
  String get smartExpenseSplittingDesc => 'خود بخود حساب لگائیں کہ کس نے کتنے پیسے دینے ہیں لچکدار تقسیم کے اختیارات کے ساتھ: برابر، فیصد، یا مخصوص رقمیں۔';

  @override
  String get stayInSync => 'مطابقت میں رہیں';

  @override
  String get stayInSyncDesc => 'جب اخراجات شامل ہوں، بجٹ پورا ہو، یا تقسیم کو طے کرنے کی ضرورت ہو تو مطلع رہیں۔';

  @override
  String get householdSettings => 'گروپ کی سیٹنگز';

  @override
  String get householdNotFound => 'گروپ نہیں ملا';

  @override
  String get coverPhoto => 'کور فوٹو';

  @override
  String get changeCoverPhoto => 'کور فوٹو تبدیل کریں';

  @override
  String get saveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get errorLoadingHousehold => 'گروپ لوڈ کرنے میں خرابی';

  @override
  String get householdUpdatedSuccessfully => 'گروپ کامیابی سے اپ ڈیٹ ہو گیا';

  @override
  String get failedToUpdateHousehold => 'گروپ اپ ڈیٹ کرنے میں ناکامی';

  @override
  String get inviteMember => 'رکن کو مدعو کریں';

  @override
  String get removeMember => 'رکن کو ہٹائیں';

  @override
  String get remove => 'ہٹائیں';

  @override
  String get confirmRemoveMember => 'کیا آپ واقعی ہٹانا چاہتے ہیں';

  @override
  String get updatedMemberRole => 'رکن کا کردار اپ ڈیٹ ہو گیا';

  @override
  String get unknown => 'نامعلوم';

  @override
  String get makeAdmin => 'ایڈمن بنائیں';

  @override
  String get makeMember => 'رکن بنائیں';

  @override
  String get invitations => 'دعوتیں';

  @override
  String get errorLoadingInvites => 'دعوتیں لوڈ کرنے میں خرابی';

  @override
  String get createInvitation => 'دعوت بنائیں';

  @override
  String get pendingInvitations => 'زیر التواء دعوتیں';

  @override
  String get noPendingInvitations => 'کوئی زیر التواء دعوتیں نہیں';

  @override
  String get invitationHistory => 'دعوت کی تاریخ';

  @override
  String get noInvitationHistory => 'کوئی دعوت کی تاریخ نہیں';

  @override
  String get emailOptional => 'ای میل (اختیاری)';

  @override
  String get friendEmailExample => 'friend@example.com';

  @override
  String get personalMessageOptional => 'ذاتی پیغام (اختیاری)';

  @override
  String get joinHouseholdBudget => 'ہمارے گروپ کا بجٹ جوائن کریں!';

  @override
  String get expiresIn => 'ختم ہونے میں';

  @override
  String get oneDay => '1 دن';

  @override
  String get threeDays => '3 دن';

  @override
  String get sevenDays => '7 دن';

  @override
  String get fourteenDays => '14 دن';

  @override
  String get thirtyDays => '30 دن';

  @override
  String get unlimited => 'لامحدود';

  @override
  String get create => 'بنائیں';

  @override
  String get invitationCreatedSuccessfully => 'دعوت کامیابی سے بن گئی';

  @override
  String get inviteLinkCopiedToClipboard => 'دعوت کا لنک کلپ بورڈ پر کاپی ہو گیا!';

  @override
  String get errorCreatingInvite => 'دعوت بنانے میں خرابی';

  @override
  String get revokeInvitation => 'دعوت منسوخ کریں';

  @override
  String get confirmRevokeInvitation => 'کیا آپ واقعی اس دعوت کو منسوخ کرنا چاہتے ہیں؟';

  @override
  String get revoke => 'منسوخ کریں';

  @override
  String get invitationRevoked => 'دعوت منسوخ کر دی گئی';

  @override
  String get errorRevokingInvite => 'دعوت منسوخ کرنے میں خرابی';

  @override
  String get anyoneWithLink => 'کوئی بھی جس کے پاس لنک ہو';

  @override
  String get noExpiry => 'کوئی میعاد ختم نہیں';

  @override
  String get expired => 'میعاد ختم ہو گئی';

  @override
  String get expires => 'میعاد ختم ہوتی ہے';

  @override
  String get copyLink => 'لنک کاپی کریں';

  @override
  String get selectCoverImage => 'کور تصویر منتخب کریں';

  @override
  String get failedToLoadImages => 'تصاویر لوڈ کرنے میں ناکامی';

  @override
  String get chooseFromGallery => 'گیلری سے منتخب کریں';

  @override
  String get failedToLoad => 'لوڈ کرنے میں ناکامی';

  @override
  String get imageTooLarge => 'تصویر بہت بڑی ہے';

  @override
  String get maxIs => 'زیادہ سے زیادہ ہے';

  @override
  String get unsupportedFileFormat => 'ناقابل قبول فائل فارمیٹ۔ براہ کرم JPG, PNG, یا WebP استعمال کریں۔';

  @override
  String get cropCoverImage => 'کور تصویر کروپ کریں';

  @override
  String get editBudget => 'بجٹ میں ترمیم کریں';

  @override
  String get budgetDetails => 'بجٹ کی تفصیلات';

  @override
  String get budgetName => 'بجٹ کا نام';

  @override
  String get period => 'مدت';

  @override
  String get alertThresholds => 'الرٹ کی حدیں';

  @override
  String get warningThreshold => 'انتباہی حد (%)';

  @override
  String get alertThreshold => 'الرٹ کی حد (%)';

  @override
  String get warningThresholdHelper => 'جب بجٹ کا استعمال اس فیصد تک پہنچ جائے تو الرٹ کریں';

  @override
  String get alertThresholdHelper => 'اس فیصد پر تشویشناک الرٹ';

  @override
  String get budgetStatus => 'بجٹ کی حیثیت';

  @override
  String get active => 'فعال';

  @override
  String get inactive => 'غیر فعال';

  @override
  String get deletingBudget => 'بجٹ حذف کیا جا رہا ہے۔۔۔';

  @override
  String get savingChanges => 'تبدیلیاں محفوظ کی جا رہی ہیں۔۔۔';

  @override
  String get budgetNameCannotBeEmpty => 'بجٹ کا نام خالی نہیں ہو سکتا';

  @override
  String get pleaseEnterValidAmount => 'براہ کرم ایک درست رقم درج کریں';

  @override
  String get warningThresholdRange => 'انتباہی حد 0 اور 100 کے درمیان ہونی چاہیے';

  @override
  String get alertThresholdRange => 'الرٹ کی حد 0 اور 100 کے درمیان ہونی چاہیے';

  @override
  String get warningThresholdLessThanAlert => 'انتباہی حد الرٹ کی حد سے کم یا برابر ہونی چاہیے';

  @override
  String get deleteBudget => 'بجٹ حذف کریں';

  @override
  String get confirmDeleteBudget => 'کیا آپ واقعی حذف کرنا چاہتے ہیں';

  @override
  String get thisActionCannotBeUndone => 'یہ عمل واپس نہیں کیا جا سکتا';

  @override
  String get budgetUpdatedSuccessfully => 'بجٹ کامیابی سے اپ ڈیٹ ہو گیا';

  @override
  String get budgetDeletedSuccessfully => 'بجٹ کامیابی سے حذف ہو گیا';

  @override
  String get categoryTransfers => 'منتقلیاں';

  @override
  String get categoryShopping => 'خریداری';

  @override
  String get categoryUtilities => 'یوٹیلٹیز';

  @override
  String get categoryEntertainment => 'تفریح';

  @override
  String get categoryEntertainmentSubscriptions => 'تفریحی سبسکرپشنز';

  @override
  String get categoryRestaurants => 'ریستوراں';

  @override
  String get categoryFood => 'کھانا';

  @override
  String get categoryGroceries => 'گروسری';

  @override
  String get categoryTransport => 'ٹرانسپورٹ';

  @override
  String get categoryTransportation => 'نقل و حمل';

  @override
  String get categoryTravel => 'سفر';

  @override
  String get categoryFlights => 'پروازیں';

  @override
  String get categoryVacation => 'چھٹیاں';

  @override
  String get categoryHealth => 'صحت';

  @override
  String get categoryMedical => 'طبی';

  @override
  String get categoryText => 'ٹیکسٹ';

  @override
  String get categoryEducation => 'تعلیم';

  @override
  String get categoryTuition => 'ٹیوشن';

  @override
  String get categorySubscriptions => 'سبسکرپشنز';

  @override
  String get categoryServices => 'خدمات';

  @override
  String get categoryHousing => 'رہائش';

  @override
  String get categoryRent => 'کرایہ';

  @override
  String get categoryMortgage => 'رہن';

  @override
  String get categoryBills => 'بلز';

  @override
  String get categoryInsurance => 'انشورنس';

  @override
  String get categorySavings => 'بچت';

  @override
  String get categoryInvestment => 'سرمایہ کاری';

  @override
  String get categoryInvestments => 'سرمایہ کاریاں';

  @override
  String get categoryIncome => 'آمدنی';

  @override
  String get categorySalary => 'تنخواہ';

  @override
  String get categoryBonus => 'بونس';

  @override
  String get categoryPets => 'پالتو جانور';

  @override
  String get categoryKids => 'بچے';

  @override
  String get categoryFamily => 'خاندان';

  @override
  String get categoryGifts => 'تحائف';

  @override
  String get categoryCharity => 'خیرات';

  @override
  String get categoryFees => 'فیس';

  @override
  String get categoryLoan => 'قرض';

  @override
  String get categoryLoans => 'قرضے';

  @override
  String get categoryDebt => 'قرضہ';

  @override
  String get categoryPersonalCare => 'ذاتی دیکھ بھال';

  @override
  String get categoryBeauty => 'بیوٹی';

  @override
  String get categoryMisc => 'متفرق';

  @override
  String get categoryUncategorized => 'بغیر کیٹیگری';

  @override
  String get deleteBudgetCannotBeUndone => 'یہ عمل واپس نہیں کیا جا سکتا';

  @override
  String get delete => 'حذف کریں';

  @override
  String get failedToDeleteBudget => 'بجٹ حذف کرنے میں ناکامی';

  @override
  String get owner => 'مالک';

  @override
  String get admin => 'ایڈمن';

  @override
  String get member => 'رکن';

  @override
  String get pending => 'زیر التواء';

  @override
  String get accepted => 'قبول شدہ';

  @override
  String get revoked => 'منسوخ شدہ';

  @override
  String get tapToChangeCover => 'کور تبدیل کرنے کے لیے ٹیپ کریں';

  @override
  String get personalMessageHint => 'اپنے مدعوین کو کچھ کہیں (جیسے، \"ہمارے گروپ کا بجٹ جوائن کریں!\")';

  @override
  String get invitationExpiresIn => 'دعوت ختم ہونے میں';

  @override
  String daysCount(int days) {
    return '$days دن';
  }

  @override
  String get createHouseholdDescription => 'خاندان یا روم میٹس کے ساتھ بجٹ اور اخراجات کو ٹریک کرنے کے لیے ایک مشترکہ جگہ بنائیں۔';

  @override
  String get uploadingImage => 'تصویر اپ لوڈ ہو رہی ہے۔۔۔';

  @override
  String get creating => 'بنایا جا رہا ہے۔۔۔';

  @override
  String get generatingInvite => 'دعوت تیار کی جا رہی ہے۔۔۔';

  @override
  String get pleaseSelectValidCurrency => 'براہ کرم گروپ کی ایک درست کرنسی منتخب کریں';

  @override
  String nameMaxLength(int max) {
    return 'نام $max حروف سے کم ہونا چاہیے۔';
  }

  @override
  String get createHouseholdPage => 'گروپ بنانے کا صفحہ';

  @override
  String get invitationPersonalMessageInput => 'دعوت کا ذاتی پیغام ان پٹ';

  @override
  String get householdNameInput => 'گروپ کا نام ان پٹ';

  @override
  String get invitationExpirationSelector => 'دعوت کی میعاد ختم ہونے کا سلیکٹر';

  @override
  String get unlimitedExpiration => 'لامحدود میعاد';

  @override
  String daysExpiration(int days) {
    return '$days دن کی میعاد';
  }

  @override
  String get householdInformation => 'گروپ کی معلومات';

  @override
  String get creatingHousehold => 'گروپ بنایا جا رہا ہے';

  @override
  String get createHouseholdButton => 'گروپ بنانے کا بٹن';

  @override
  String get searchExpenses => 'اخراجات تلاش کریں۔۔۔';

  @override
  String get clearAll => 'سب صاف کریں';

  @override
  String get allCategories => 'تمام کیٹیگریز';

  @override
  String get allMembers => 'تمام اراکین';

  @override
  String get balanceSummary => 'بیلنس کا خلاصہ';

  @override
  String get youAreOwed => 'آپ کو رقم ملنی ہے';

  @override
  String get youOwe => 'آپ کے ذمہ ہیں';

  @override
  String get youOweOthers => 'آپ نے دوسروں کو دینے ہیں';

  @override
  String get othersOweYou => 'دوسروں نے آپ کو دینے ہیں';

  @override
  String get viewDetails => 'تفصیلات دیکھیں';

  @override
  String get settleUp => 'حساب برابر کریں';

  @override
  String get markExpensesAsSettled => 'بیلنس اپ ڈیٹ کرنے کے لیے اخراجات کو \'طے شدہ\' کے طور پر نشان زد کریں';

  @override
  String get whoAreYouSettlingWith => 'آپ کس کے ساتھ حساب برابر کر رہے ہیں؟';

  @override
  String get selectMember => 'رکن منتخب کریں';

  @override
  String get amountToSettle => 'طے کرنے کی رقم';

  @override
  String get howDidYouSettle => 'آپ نے کیسے حساب برابر کیا؟';

  @override
  String get cash => 'کیش';

  @override
  String get paidInCash => 'کیش میں ادائیگی کی';

  @override
  String get bankTransfer => 'بینک ٹرانسفر';

  @override
  String get transferredViaBank => 'بینک کے ذریعے منتقل کیا';

  @override
  String get mobilePayment => 'موبائل پیمنٹ';

  @override
  String get venmoPaypalEtc => 'ایزی پیسہ، جاز کیش، وغیرہ۔';

  @override
  String get search => 'تلاش';

  @override
  String get noData => 'کوئی ڈیٹا نہیں';

  @override
  String get filterTransactions => 'ٹرانزیکشنز فلٹر کریں';

  @override
  String get noTransactionsFound => 'کوئی ٹرانزیکشنز نہیں ملیں';

  @override
  String get failedToLoadHouseholdTransactions => 'گروپ کی ٹرانزیکشنز لوڈ کرنے میں ناکامی';

  @override
  String get reset => 'ری سیٹ';

  @override
  String get apply => 'لاگو کریں';

  @override
  String get expenses => 'اخراجات';

  @override
  String get dateRange => 'تاریخ کی حد';

  @override
  String get noMatchingExpenses => 'کوئی مماثل اخراجات نہیں';

  @override
  String get startLoggingExpenses => 'یہاں دیکھنے کے لیے اخراجات لاگ کرنا شروع کریں';

  @override
  String get tryAdjustingFilters => 'اپنے فلٹرز کو ایڈجسٹ کرنے کی کوشش کریں';

  @override
  String get split => 'تقسیم کریں';

  @override
  String get note => 'نوٹ';

  @override
  String get currencyCannotBeChangedWhenSharing => 'گروپ کے ساتھ شیئر کرتے وقت کرنسی تبدیل نہیں کی جا سکتی';

  @override
  String get createBudget => 'بجٹ بنائیں';

  @override
  String get pleaseEnterABudgetName => 'براہ کرم بجٹ کا نام درج کریں';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'براہ کرم 0 سے زیادہ درست رقم درج کریں';

  @override
  String get warningThresholdMustBeBetween0And100 => 'انتباہی حد 0 اور 100% کے درمیان ہونی چاہیے';

  @override
  String get alertThresholdMustBeBetween0And100 => 'الرٹ کی حد 0 اور 100% کے درمیان ہونی چاہیے';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'انتباہی حد الرٹ کی حد سے کم یا برابر ہونی چاہیے';

  @override
  String get budgetCreatedSuccessfully => 'بجٹ کامیابی سے بن گیا!';

  @override
  String get failedToCreateBudget => 'بجٹ بنانے میں ناکامی';

  @override
  String get groceriesRentEntertainment => 'مثلاً، گروسری، کرایہ، تفریح';

  @override
  String get budgetType => 'بجٹ کی قسم';

  @override
  String get sharedWithAllHouseholdMembers => 'گھرانے کے تمام اراکین کے ساتھ مشترکہ';

  @override
  String get personalBudgetForYourExpensesOnly => 'صرف آپ کے اخراجات کے لیے ذاتی بجٹ';

  @override
  String get countSplitPortionOnly => 'صرف تقسیم شدہ حصہ شمار کریں';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'اس بجٹ میں تقسیم شدہ اخراجات میں صرف اپنا حصہ شمار کریں';

  @override
  String get joinHousehold => 'گھرانے میں شامل ہوں';

  @override
  String get joinAHousehold => 'کسی گھرانے میں شامل ہوں';

  @override
  String get enterYourInvitationLinkToJoin => 'مشترکہ مالیاتی اسپیس میں شامل ہونے کے لیے\nاپنا دعوتی لنک درج کریں';

  @override
  String get pasteTheInvitationLinkYouReceived => 'گھرانے کے رکن سے موصول دعوتی لنک پیسٹ کریں';

  @override
  String get pasteInvitationLink => 'دعوتی لنک پیسٹ کریں';

  @override
  String get pleaseEnterAnInvitationLink => 'براہ کرم ایک دعوتی لنک درج کریں';

  @override
  String get pleaseEnterAValidInvitationLink => 'براہ کرم ایک درست دعوتی لنک درج کریں';

  @override
  String get paste => 'پیسٹ کریں';

  @override
  String get validating => 'توثیق ہو رہی ہے...';

  @override
  String get continueAction => 'جاری رکھیں';

  @override
  String get welcomeAboard => 'خوش آمدید!';

  @override
  String get youreNowPartOfTheHousehold => 'آپ اب گھرانے کا حصہ ہیں۔\nاپنی مالیات پر مل کر کام شروع کریں!';

  @override
  String get thisWillOnlyTakeAMoment => 'اس میں صرف ایک لمحہ لگے گا';

  @override
  String get unableToJoin => 'شامل ہونے سے قاصر';

  @override
  String get tryAgain => 'دوبارہ کوشش کریں';

  @override
  String get goToHousehold => 'گھرانے پر جائیں';

  @override
  String get expiresSoon => 'جلد ختم ہو رہی ہے';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'دعوت $formattedDate تک معتبر ہے';
  }

  @override
  String get whatYoullGet => 'آپ کو کیا ملے گا';

  @override
  String get viewSharedBudgetsAndExpenses => 'مشترکہ بجٹ اور اخراجات دیکھیں';

  @override
  String get trackHouseholdFinancialHealth => 'گھرانے کی مالی صحت پر نظر رکھیں';

  @override
  String get collaborateOnFinancialDecisions => 'مالی فیصلوں پر مل کر کام کریں';

  @override
  String get household => 'گروپ';

  @override
  String get viewAll => 'سب دیکھیں';

  @override
  String get manage => 'انتظام کریں';

  @override
  String get noBudgetsYet => 'ابھی تک کوئی بجٹ نہیں';

  @override
  String get createSharedBudgetDescription => 'مل کر اخراجات کو ٹریک کرنے کے لیے ایک مشترکہ بجٹ بنائیں';

  @override
  String get errorLoadingBudgets => 'بجٹ لوڈ کرنے میں خرابی';

  @override
  String get recentSplits => 'حالیہ تقسیمات';

  @override
  String get invite => 'دعوت دیں';

  @override
  String get last6Months => 'پچھلے 6 مہینے';

  @override
  String get thisYear => 'اس سال';

  @override
  String get allTime => 'تمام وقت';

  @override
  String nameMinLength(int min) {
    return 'نام کم از کم $min حروف پر مشتمل ہونا چاہیے۔';
  }

  @override
  String get splitExpense => 'خرچ تقسیم کریں';

  @override
  String get percent => 'فیصد';

  @override
  String get splitShare => 'حصہ';

  @override
  String get owes => 'ذمہ ہے';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'تقسیم شدہ رقمیں $currency$amount کے برابر ہونی چاہئیں';
  }

  @override
  String get percentagesMustTotal100 => 'فیصد کا کل 100% ہونا چاہیے';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'ہر شخص کا کم از کم 1 حصہ ہونا چاہیے';

  @override
  String get whatsappVerified => 'واٹس ایپ تصدیق شدہ';

  @override
  String get whatsappVerification => 'واٹس ایپ تصدیق';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'آپ کا واٹس ایپ نمبر کامیابی سے آپ کے اکاؤنٹ سے منسلک ہو گیا ہے';

  @override
  String get verifyingYourWhatsAppNumber => 'آپ کے واٹس ایپ نمبر کی تصدیق کی جا رہی ہے۔۔۔';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'واٹس ایپ سے 6 ہندسوں کا کوڈ درج کریں';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'براہ کرم 6 ہندسوں کا تصدیقی کوڈ درج کریں';

  @override
  String get failedToVerifyCode => 'کوڈ کی تصدیق کرنے میں ناکامی';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'کوڈ کی تصدیق کرنے میں ناکامی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get codeAutoFilledFromVerificationLink => 'کوڈ تصدیقی لنک سے خود بخود بھر گیا';

  @override
  String get verify => 'تصدیق کریں';

  @override
  String get verifying => 'تصدیق کی جا رہی ہے۔۔۔';

  @override
  String get avatarStudio => 'اوتار اسٹوڈیو';

  @override
  String get preview => 'پیش منظر';

  @override
  String get colors => 'رنگ';

  @override
  String get randomize => 'رینڈمائز';

  @override
  String get saveAvatar => 'اوتار محفوظ کریں';

  @override
  String get saving => 'محفوظ ہو رہا ہے۔۔۔';

  @override
  String get skipForNow => 'فی الحال چھوڑ دیں';

  @override
  String get selectColor => 'رنگ منتخب کریں';

  @override
  String get failedToSaveAvatar => 'اوتار محفوظ کرنے میں ناکامی';

  @override
  String get hair => 'بال';

  @override
  String get eyes => 'آنکھیں';

  @override
  String get mouth => 'منہ';

  @override
  String get background => 'پس منظر';

  @override
  String get face => 'چہرہ';

  @override
  String get ears => 'کان';

  @override
  String get shirts => 'شرٹس';

  @override
  String get brow => 'بھنویں';

  @override
  String get nose => 'ناک';

  @override
  String get blush => 'بلاشر';

  @override
  String get accessories => 'لوازمات';

  @override
  String get stars => 'ستارے';

  @override
  String get currencyIsManagedByHousehold => 'کرنسی کا انتظام گروپ کے پاس ہے اور اسے تبدیل نہیں کیا جا سکتا';

  @override
  String get buyALaptop => '50,000 روپے کا لیپ ٹاپ خریدنا';

  @override
  String get selectTargetDate => 'ہدف کی تاریخ منتخب کریں';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'کیا میں $date سے پہلے $action کر سکتا ہوں؟';
  }

  @override
  String get scenarioDateFormat => 'dd/MM/yyyy';

  @override
  String analysisFailed(String error) {
    return 'تجزیہ ناکام: $error';
  }

  @override
  String get leftHandChamps => 'بائیں ہاتھ والے چیمپئنز آپ کے سب سے بڑے اخراجات ہیں — فوری جائزے کے لیے بہترین امیدوار۔';

  @override
  String get smallButFrequent => 'چھوٹی لیکن بار بار ہونے والی کیٹیگریز ان عادات کی نشاندہی کرتی ہیں جو وقت کے ساتھ بڑھ سکتی ہیں۔';

  @override
  String get colorMatches => 'رنگ ہوم ٹیب پر نظر آنے والے رنگوں سے ملتا ہے تاکہ آپ کا دماغ آرام دہ رہے۔';

  @override
  String get planningNewGoal => 'نئے مقصد کی منصوبہ بندی کر رہے ہیں؟ تفریحی چیزوں کو چھیڑے بغیر کٹوتی کے لیے کیٹیگریز تلاش کریں۔';

  @override
  String get eyeingTreatYourself => 'ایک \'ٹریٹ یورسیلف\' مہینے کا سوچ رہے ہیں؟ دیکھیں کہ کون سے شعبے محفوظ طریقے سے لچکدار ہو سکتے ہیں۔';

  @override
  String get doubleCheckTagging => 'اسے یہ چیک کرنے کے لیے استعمال کریں کہ نئے اخراجات صحیح طریقے سے ٹیگ ہوئے تھے — کوئی غلطی نہیں۔';

  @override
  String get slideHighBar => 'ایک چھوٹی حد مقرر کر کے یا کم لاگت والے متبادل پر جا کر ایک اونچے بار کو تھوڑا نیچے لائیں۔';

  @override
  String get nonNegotiable => 'اگر کوئی بار ناقابل تغیر ہے (جیسے کرایہ)، تو اس سے لڑنے کے بجائے اس کے ارد گرد منصوبہ بندی کریں۔';

  @override
  String get revisitAfterScenario => 'ایک منظر نامہ چلانے کے بعد دوبارہ دیکھیں کہ کیا آپ کی ایڈجسٹمنٹس کام کر رہی ہیں۔';

  @override
  String get purpleLineCushion => 'جامنی لکیر: ہر دن کے بعد بچی ہوئی گنجائش۔ بڑھتی ہوئی لکیروں کا مطلب ہے کہ آپ رفتار بنا رہے ہیں۔';

  @override
  String get blueBarsBudget => 'نیلے بارز: وہ بجٹ جو آپ نے اس دن کے لیے مقرر کیا تھا۔';

  @override
  String get redBarsSpent => 'سرخ بارز: جو اصل میں آپ کے اکاؤنٹ سے گیا۔';

  @override
  String get lineTrendingUpward => 'اوپر جاتی لکیر = اضافی نقد جسے آپ بچت کے اہداف کی طرف موڑ سکتے ہیں۔';

  @override
  String get flatDippingLine => 'سپاٹ یا نیچے جاتی لکیر = رکنے اور بڑی ٹکٹ والی اشیاء کا جائزہ لینے کا وقت۔';

  @override
  String get sharpDrops => 'تیز گراوٹ اکثر غیر منصوبہ بند خریداریوں سے مطابقت رکھتی ہے — تفصیلات دیکھنے کے لیے ان پر ٹیپ کریں۔';

  @override
  String get lineRisingDays => 'لکیر کئی دنوں سے بڑھ رہی ہے؟ تھوڑا اضافی بچت یا قرض کی ادائیگی میں منتقل کرنے پر غور کریں۔';

  @override
  String get lineDippingWeekend => 'مصروف ویک اینڈ کے بعد لکیر نیچے جا رہی ہے؟ چھوٹے اختیاری اخراجات میں کمی کر کے آنے والے دنوں کو دوبارہ متوازن کریں۔';

  @override
  String get feelStuckRed => 'سرخ میں پھنسا ہوا محسوس کر رہے ہیں؟ ہوم ٹیب میں اپنے بجٹ پر نظر ثانی کریں — چھوٹی ایڈجسٹمنٹس تیزی سے جمع ہوتی ہیں۔';

  @override
  String get thirtyDayForecastDesc => 'یہ پیشن گوئی پچھلے مہینے کی سرگرمی کی بنیاد پر اگلے مہینے کا اندازہ لگاتی ہے۔ اسے اپنے بٹوے (wallet) کا موسمی رپورٹ سمجھیں۔';

  @override
  String get greenLineExpected => 'سبز لکیر = متوقع یومیہ خرچ اگر آنے والا مہینہ پچھلے مہینے کی طرح برتاؤ کرے۔';

  @override
  String get spikesHighlight => 'اسپائکس ان ہفتوں کو نمایاں کرتے ہیں جہاں آپ کی عادات عام طور پر مہنگی ہو جاتی ہیں (جیسے، جمعہ کا ٹیک اوے)۔';

  @override
  String get forecastUpdates => 'جب آپ تازہ ٹرانزیکشنز لاگ کرتے ہیں، تو پیشن گوئی آہستہ سے اپ ڈیٹ ہوتی ہے — ریفریش کرنے کی ضرورت نہیں۔';

  @override
  String get spotExpensivePatterns => 'مہنگے پیٹرنز کو جلد پہچانیں اور ان کے آنے سے پہلے ایک چھوٹا بفر رکھیں۔';

  @override
  String get catchQuieterWeeks => 'پرسکون ہفتوں کو پکڑیں جہاں آپ اضافی نقد کو بچت یا قرض کی ادائیگی میں منتقل کر سکتے ہیں۔';

  @override
  String get timeRecurringPayments => 'بار بار ہونے والی ادائیگیوں، سبسکرپشنز، یا ٹاپ اپس کا وقت مقرر کرنے کے لیے اس بصیرت کا استعمال کریں۔';

  @override
  String get bigSpikeComing => 'بڑا اسپائک آ رہا ہے؟ سستے اختیارات پہلے سے بک کریں یا لچکدار اخراجات کو پرسکون دنوں میں منتقل کریں۔';

  @override
  String get forecastDipping => 'پیشن گوئی کم ہو رہی ہے؟ ایک اضافی بچت کی منتقلی کا شیڈول بنا کر خود کو انعام دیں۔';

  @override
  String get forecastLooksOff => 'اگر پیشن گوئی غلط لگ رہی ہے، تو کسی بھی غلط لیبل کو ٹھیک کرنے کے لیے ہوم ٹیب میں کیٹیگریز کا جائزہ لیں۔';

  @override
  String get greenLineTrends => 'سبز لکیر آپ کی عام بچت کی شرح کے ساتھ چلتی ہے — اوپر کی رفتار کا مطلب ہے کہ آپ کے اہداف فنڈ ہو رہے ہیں۔';

  @override
  String get lineDipsSignals => 'اگر لکیر نیچے آتی ہے، تو یہ مستقبل کے مہینوں کا اشارہ دیتی ہے جہاں اخراجات آمدنی سے بڑھ جاتے ہیں۔';

  @override
  String get largeGoalsDebts => 'بڑے اہداف یا قرضے شامل ہوتے ہیں جب آپ انہیں ہوم ٹیب میں ٹیگ کرتے ہیں۔';

  @override
  String get upwardSlope => 'اوپر کی ڈھلوان؟ جشن منائیں اور ریٹائرمنٹ یا سفری بچت کو بڑھانے پر غور کریں۔';

  @override
  String get flatSlipping => 'سپاٹ یا پھسلتی ہوئی؟ اس سے پہلے کہ یہ بڑا مسئلہ بنے، بجٹ کو ٹیون کرنے یا آمدنی کے ذرائع کو بڑھانے کا وقت ہے۔';

  @override
  String get watchSeasonalTrends => 'موسمی رجحانات پر نظر رکھیں — چھٹیاں، اسکول کی مدتیں، یا سالانہ تجدید اکثر یہاں پہلے نظر آتی ہیں۔';

  @override
  String get schedulePaymentIncreases => 'جب کرو (curve) بڑھ رہا ہو تو قرضوں پر ادائیگی میں ہلکے اضافے کا شیڈول بنائیں۔';

  @override
  String get planAheadDips => 'ڈوبنے والے فنڈز مختص کر کے یا اختیاری اخراجات میں کمی کر کے گراوٹ کے لیے پہلے سے منصوبہ بندی کریں۔';

  @override
  String get checkProjectionMonthly => 'اپنے طویل مدتی کھیل کو پرلطف اور لچکدار رکھنے کے لیے ماہانہ تخمینہ چیک کریں۔';

  @override
  String get categoryHealthcare => 'صحت کی دیکھ بھال';

  @override
  String get categoryOther => 'دیگر';

  @override
  String get deleteExpense => 'خرچ حذف کریں';

  @override
  String get confirmDeleteExpense => 'کیا آپ واقعی اس خرچ کو حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں کیا جا سکتا۔';

  @override
  String get expenseDeletedSuccessfully => 'خرچ کامیابی سے حذف ہو گیا';

  @override
  String get failedToDeleteExpense => 'خرچ حذف کرنے میں ناکامی';

  @override
  String get expenseNotFoundOrDeleted => 'خرچ نہیں ملا یا حذف ہو چکا ہے';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'صرف ایڈمنز اور مالک ہی گھر کی ترتیبات میں ترمیم کر سکتے ہیں';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'صرف ایڈمنز اور مالک ہی دعوت نامے بنا سکتے ہیں';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'گھر $householdName کی دعوت شیئر کریں';
  }

  @override
  String get shareInvitation => 'دعوت شیئر کریں';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'گھر $householdName کامیابی سے بنایا گیا';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'گھر \"$householdName\" کامیابی سے بنایا گیا!';
  }

  @override
  String get invitationLink => 'دعوت لنک';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'دعوت لنک: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'دعوت لنک کاپی کریں';

  @override
  String get copyInvitationLinkToClipboard => 'دعوت لنک کلپ بورڈ میں کاپی کریں';

  @override
  String get shareInvitationLink => 'دعوت لنک شیئر کریں';

  @override
  String get share => 'شیئر کریں';

  @override
  String get closeShareSheet => 'شیئر شیٹ بند کریں';

  @override
  String get invitationLinkCopiedToClipboard => 'دعوت لنک کلپ بورڈ میں کاپی ہو گیا!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'میرے گھر \"$householdName\" میں مونیکو پر شامل ہوں!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'میرے گھر میں مونیکو پر شامل ہوں';

  @override
  String get zeroAmount => '0.00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'نوٹیفیکیشن ترتیبات';

  @override
  String get budgetBoop => 'بجٹ الرٹ';

  @override
  String get getGentleReminder => 'جب آپ اس حد تک پہنچ جائیں تو نرم یاد دہانی حاصل کریں';

  @override
  String get purrSuasiveNudge => 'پیار سے تاکید';

  @override
  String get getStrongerNudge => 'جب آپ اس حد تک پہنچ جائیں تو زوردار یاد دہانی حاصل کریں';

  @override
  String get createBudgetButton => 'بجٹ بنائیں';

  @override
  String get daily => 'روزانہ';

  @override
  String get weekly => 'ہفتہ وار';

  @override
  String get monthly => 'ماہانہ';

  @override
  String get yearly => 'سالانہ';

  @override
  String get householdBudgetType => 'گھریلو بجٹ';

  @override
  String get personalBudgetType => 'ذاتی بجٹ';

  @override
  String joinHouseholdName(String householdName) {
    return '\"$householdName\" میں شامل ہوں';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'گھرانے کا پیش منظر: $householdName، مدعو کنندہ: $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return '$inviterEmail کی دعوت';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'دعوت جلد ختم ہو جائے گی: $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'دعوت معتبر ہے تا';

  @override
  String get personalMessageFromInviter => 'دعوت دہندے کا ذاتی پیغام';

  @override
  String get messageFromInviter => 'دعوت دہندے کا پیغام';

  @override
  String get joiningHousehold => 'گھرانے میں شمولیت ہو رہی ہے...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'خرابی: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'غیر متوقع خرابی پیش آ گئی';

  @override
  String get invalidInvitationLinkFormat => 'دعوتی لنک کا فارمٹ درست نہیں';

  @override
  String get invalidOrExpiredInvitation => 'دعوت نامعتبر یا میعاد ختم';

  @override
  String get tomorrow => 'کل';

  @override
  String inDays(int days) {
    return '$days دن میں';
  }

  @override
  String get january => 'جنوری';

  @override
  String get february => 'فروری';

  @override
  String get march => 'مارچ';

  @override
  String get april => 'اپریل';

  @override
  String get may => 'مئی';

  @override
  String get june => 'جون';

  @override
  String get july => 'جولائی';

  @override
  String get august => 'اگست';

  @override
  String get september => 'ستمبر';

  @override
  String get october => 'اکتوبر';

  @override
  String get november => 'نومبر';

  @override
  String get december => 'دسمبر';

  @override
  String remindUser(String name) {
    return '$name کو یاد دہانی بھیجیں';
  }

  @override
  String get sendFriendlySpendingReminder => 'اخراجات کی ایک دوستانہ یاددہانی بھیجیں';

  @override
  String get addMessageOptional => 'پیغام شامل کریں (اختیاری)';

  @override
  String get messageHintExample => 'مثلاً: \"آپ کے بٹوے کو آرام چاہیے!\"';

  @override
  String get sendReminder => 'یاد دہانی بھیجیں';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'براہِ کرم $name کو دوبارہ یاد دہانی بھیجنے سے پہلے 24 گھنٹے انتظار کریں';
  }

  @override
  String reminderSentToName(String name) {
    return '$name کو یاد دہانی بھیج دی گئی 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'یاد دہانی بھیجنے میں ناکامی۔ دوبارہ کوشش کریں۔';
}
