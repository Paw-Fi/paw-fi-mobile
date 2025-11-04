// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'Ще немає витрат';

  @override
  String get loginWelcomeBack => 'З поверненням!';

  @override
  String get orContinueWithEmail => 'Або увійдіть через email';

  @override
  String get emailAddress => 'Адреса email';

  @override
  String get password => 'Пароль';

  @override
  String get forgotPassword => 'Забули пароль?';

  @override
  String get signIn => 'Увійти';

  @override
  String get newToMoneko => 'Вперше в Moneko?';

  @override
  String get createAccount => 'Створити акаунт';

  @override
  String get resetYourPassword => 'Відновити пароль';

  @override
  String get email => 'Email';

  @override
  String get exampleEmail => 'vy@example.com';

  @override
  String get cancel => 'Скасувати';

  @override
  String get sendResetLink => 'Надіслати посилання';

  @override
  String get passwordResetEmailSent => 'Лист для відновлення пароля надіслано. Перевірте пошту.';

  @override
  String get enterValidEmail => 'Введіть дійсну адресу email';

  @override
  String passwordMinLength(int min) {
    return 'Пароль має містити щонайменше $min символів';
  }

  @override
  String fullNameMinLength(int min) {
    return 'Повне ім\'я має містити щонайменше $min символів';
  }

  @override
  String get createYourAccount => 'Створення акаунту';

  @override
  String get fullName => 'Повне ім\'я';

  @override
  String get createPassword => 'Створіть пароль';

  @override
  String get passwordComplexityRequirement => 'Пароль має містити принаймні одну велику літеру, одну малу літеру та одну цифру';

  @override
  String get passwordRequirementShort => 'Пароль: 8+ символів, з великою, малою літерою та цифрою';

  @override
  String get termsAgreement => 'Створюючи акаунт, ви погоджуєтесь з нашими Умовами надання послуг та Політикою конфіденційності';

  @override
  String get alreadyHaveAccount => 'Вже маєте акаунт?';

  @override
  String get signInLower => 'Увійти';

  @override
  String get verificationCodeSent => 'Код підтвердження надіслано';

  @override
  String get verifyYourEmail => 'Підтвердьте ваш email';

  @override
  String verificationEmailSentTo(String email) {
    return 'Ми надіслали 6-значний код підтвердження на $email';
  }

  @override
  String get enterCompleteCode => 'Будь ласка, введіть повний 6-значний код';

  @override
  String get invalidVerificationCode => 'Невірний код підтвердження';

  @override
  String get verificationCodeExpired => 'Термін дії коду минув. Будь ласка, надішліть новий.';

  @override
  String get verifyEmail => 'Підтвердити email';

  @override
  String get didntReceiveTheCode => 'Не отримали код? Перевірте папку \"Спам\" або';

  @override
  String resendInSeconds(int seconds) {
    return 'надіслати повторно через $seconds с';
  }

  @override
  String get resendVerificationEmail => 'надіслати код повторно';

  @override
  String get continueWithGoogle => 'Продовжити з Google';

  @override
  String get signingInWithGoogle => 'Вхід через Google...';

  @override
  String get error => 'Помилка';

  @override
  String get anErrorOccurred => 'Сталася помилка';

  @override
  String get unknownError => 'Невідома помилка';

  @override
  String get goToHome => 'На головну';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ Оплата успішна! Перевіряємо підписку...';

  @override
  String get paymentFailed => 'Оплата не вдалася';

  @override
  String get paymentCanceled => 'ℹ️ Оплату скасовано';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp успішно підтверджено!';

  @override
  String get settings => 'Налаштування';

  @override
  String get enableNotificationsInSettings => 'Увімкніть сповіщення для Moneko в налаштуваннях пристрою';

  @override
  String get appearance => 'Вигляд';

  @override
  String get darkMode => 'Темний режим';

  @override
  String get notifications => 'Сповіщення';

  @override
  String get pushNotifications => 'Push-сповіщення';

  @override
  String get receiveAlertsAndUpdates => 'Отримувати сповіщення та оновлення';

  @override
  String get language => 'Мова';

  @override
  String get systemDefault => 'Як у системі';

  @override
  String get membership => 'Підписка';

  @override
  String get loading => 'Завантаження...';

  @override
  String get failedToLoadMembership => 'Не вдалося завантажити дані підписки';

  @override
  String get couldNotOpenMembershipPage => 'Не вдалося відкрити сторінку підписки';

  @override
  String get freePlan => 'Безкоштовно';

  @override
  String get freePlanStatus => 'Безкоштовний';

  @override
  String get lifetimePlan => 'Довічна';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus (місячна)';

  @override
  String get plusYearlyPlan => 'Plus (річна)';

  @override
  String get activeStatus => 'Активна';

  @override
  String get activeLifetimeStatus => 'Активна • Довічна';

  @override
  String get canceledStatus => 'Скасована';

  @override
  String get pastDueStatus => 'Прострочена';

  @override
  String get trialStatus => 'Пробна';

  @override
  String trialEndsInDays(int days) {
    return 'Пробна версія: $days дн.';
  }

  @override
  String get trialEnded => 'Пробну версію завершено';

  @override
  String renewsInDays(int days) {
    return 'Поновлення через: $days дн.';
  }

  @override
  String accessEndsInDays(int days) {
    return 'Доступ завершиться через: $days дн.';
  }

  @override
  String get subscriptionEnded => 'Підписку завершено';

  @override
  String get profile => 'Профіль';

  @override
  String get errorLoadingProfile => 'Помилка завантаження профілю';

  @override
  String get user => 'Користувач';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp підключено';

  @override
  String get logExpensesViaWhatsApp => 'Додавайте витрати через WhatsApp';

  @override
  String get connectWhatsApp => 'Підключити WhatsApp';

  @override
  String get newBadge => 'НОВЕ';

  @override
  String get logExpensesInstantly => 'Записуйте витрати миттєво в чаті';

  @override
  String get fast => 'Швидко';

  @override
  String get photo => 'Фото';

  @override
  String get autoSync => 'Автосинхронізація';

  @override
  String get naturalLanguage => 'Розмовний ввід';

  @override
  String get describeExpenseAutomatically => 'Опишіть витрату. Ми її розпізнаємо.';

  @override
  String get snapReceipt => 'Фото чека';

  @override
  String get snapReceiptDescription => 'Сфотографуйте чек. ШІ розпізнає та додасть витрату.';

  @override
  String get previous => 'Назад';

  @override
  String get next => 'Далі';

  @override
  String get overview => 'Огляд';

  @override
  String get activity => 'Активність';

  @override
  String get accountInformation => 'Дані акаунту';

  @override
  String get userId => 'ID користувача';

  @override
  String get recentActivity => 'Остання активність';

  @override
  String get noActivityYet => 'Активності ще немає';

  @override
  String get signOut => 'Вийти';

  @override
  String get insights => 'Аналітика';

  @override
  String get runningTab => 'Поточний';

  @override
  String get day30Tab => '30 днів';

  @override
  String get longTermTab => 'Довгостроковий';

  @override
  String get scenarioTab => 'Сценарій';

  @override
  String get runningAndDailyBalances => 'Поточний та денний баланси';

  @override
  String get budgetVsSpentDescription => 'Бюджет проти витрат по днях із сукупним поточним балансом.';

  @override
  String get runningBalanceLegend => 'Поточний баланс';

  @override
  String get budgetLegend => 'Бюджет';

  @override
  String get spentLegend => 'Витрачено';

  @override
  String get runningBalanceGuide => 'Гід по поточному балансу';

  @override
  String get runningBalanceIntro => 'Цей графік — ваш особистий фінансовий помічник. Розберемось, що він показує та як ним користуватися.';

  @override
  String get day30LookAhead => 'Прогноз на 30 днів';

  @override
  String get projectedFromTrailing30Days => 'Прогноз на основі середніх показників за останні 30 днів.';

  @override
  String get projectedSpendingLegend => 'Прогнозовані витрати';

  @override
  String get peek30DaysAhead => 'Погляд на 30 днів уперед';

  @override
  String get day30ForecastIntro => 'Цей прогноз аналізує ваші звички за останній місяць, щоб передбачити активність на наступний. Вважайте це прогнозом погоди для вашого гаманця.';

  @override
  String get longTermProjection => 'Довгостроковий прогноз';

  @override
  String get basedOnHistoricalAverages => 'На основі попередніх середніх показників; оновлюється автоматично.';

  @override
  String get month18ProjectionLegend => 'Прогноз на 18 місяців';

  @override
  String get your18MonthHorizon => 'Ваш горизонт на 18 місяців';

  @override
  String get longTermIntro => 'Цей прогноз поєднує ваші стабільні звички з припущеннями про помірне зростання, щоб ви побачили, до чого призведуть сьогоднішні рішення.';

  @override
  String get aiScenarioPlanning => 'Планування сценаріїв (ШІ)';

  @override
  String get askAiFinancialAdvisor => 'Запитайте ШІ-радника, чи можете ви дозволити собі майбутню витрату';

  @override
  String get canI => 'Чи можу я';

  @override
  String get before => 'до';

  @override
  String get beforePrefix => 'до';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Оберіть дату';

  @override
  String get check => 'Перевірити';

  @override
  String get enterQuestionAndPickDate => 'Будь ласка, введіть запитання та оберіть дату';

  @override
  String get analyzingScenario => 'Аналіз сценарію...';

  @override
  String get thisMightTakeAWhile => 'Це може зайняти трохи часу';

  @override
  String get whereTheMoneyWent => 'Куди пішли гроші';

  @override
  String get categoryTotalsForSelectedRange => 'Підсумки за категоріями для обраного періоду.';

  @override
  String get scenarioCategoriesGuide => 'Як розуміти категорії';

  @override
  String get categoryGuideIntro => 'Цей графік — погляд з висоти на те, куди \"полетіла\" кожна гривня. Ось як його читати без калькулятора.';

  @override
  String get readTheBarChartLikeAPro => 'Читайте діаграму як профі';

  @override
  String get categoryChartDesc => 'Розподіл за категоріями за обраний період.';

  @override
  String get whyThisViewIsHelpful => 'Чому це корисно';

  @override
  String get categoryWhyHelpfulDesc => 'Швидко визначайте найбільші категорії витрат та помічайте тенденції.';

  @override
  String get whatToDoWithTheInsight => 'Що робити з цією інформацією';

  @override
  String get categoryWhatToDoDesc => 'Використовуйте це для коригування бюджету та витрат.';

  @override
  String get scenarioAnalysis => 'Аналіз сценарію';

  @override
  String get target => 'Ціль';

  @override
  String get quickStats => 'Швидка статистика';

  @override
  String get currentBalance => 'Поточний баланс';

  @override
  String get projectedNoChange => 'Прогноз (без змін)';

  @override
  String get avgDailyNet => 'Сер. чистий потік / день';

  @override
  String get noDataAvailable => 'Немає даних';

  @override
  String get day => 'День';

  @override
  String get close => 'Закрити';

  @override
  String get done => 'Готово';

  @override
  String get whatYouAreSeeing => 'Що ви бачите';

  @override
  String get whyItMatters => 'Чому це важливо';

  @override
  String get howToRespond => 'Як реагувати';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Ваш поточний баланс показує, скільки \"простору для маневру\" у вас є після кожного дня. Денні стовпці — це ваш план проти реальних витрат.';

  @override
  String get runningBalanceWhyMattersDesc => 'Це як перевірка пульсу. Допомагає побачити, коли ви випереджаєте план (і можете інвестувати), або коли потрібна корекція курсу.';

  @override
  String get runningBalanceHowToRespondDesc => 'Використовуйте графік як тренера. Радійте успіхам, коригуйте очікування, але не будьте надто суворі до себе — головне стабільний прогрес, а не досконалість.';

  @override
  String get whatTheForecastShows => 'Що показує прогноз';

  @override
  String get day30WhatShowsDesc => 'Ми аналізуємо доходи та витрати за 30 днів, щоб спрогнозувати середній тиждень. Це згладжує разові великі витрати, щоб ви побачили свій звичний ритм.';

  @override
  String get day30WhyMattersDesc => 'Прогнозування допомагає діяти проактивно. Бачачи попереду \"великі\" дні, ви можете відкласти кошти заздалегідь, а не шукати їх в останню мить.';

  @override
  String get day30HowToPlaySmartDesc => 'Сприймайте це як дружню пораду, а не суворе правило. Коригуйте план маленькими, реальними кроками.';

  @override
  String get howTheProjectionWorks => 'Як працює прогноз';

  @override
  String get longTermHowWorksDesc => 'Ми прокручуємо вперед ваші середні доходи та витрати, додаючи скромне зростання, щоб ви побачили, чи залишатиметься ваш план \"в плюсі\" через місяці.';

  @override
  String get longTermWhyMattersDesc => 'Довгі горизонти роблять великі мрії реальнішими. Подивіться, чи вистачає коштів на ваші цілі: резервний фонд, інвестиції чи великі покупки.';

  @override
  String get longTermMovesToConsiderDesc => 'Використовуйте графік, щоб \"прорепетирувати\" майбутні рішення. Маленькі зміни сьогодні дають великі результати завтра.';

  @override
  String get forMe => 'Для мене';

  @override
  String get forUs => 'Для нас';

  @override
  String get home => 'Головна';

  @override
  String get reminder => 'Нагадування';

  @override
  String get analyzingReceipt => 'Аналізую чек...';

  @override
  String get analyzingExpense => 'Аналізую витрату...';

  @override
  String get noExpenseInformationExtracted => 'Не вдалося розпізнати дані про витрату';

  @override
  String get failedToAnalyzeNoData => 'Помилка аналізу: немає даних';

  @override
  String get failedToAnalyze => 'Помилка аналізу';

  @override
  String get updateBudget => 'Оновити бюджет';

  @override
  String get enterNewTotalDailyBudget => 'Введіть новий загальний денний бюджет.';

  @override
  String get budgetAmount => 'Сума бюджету';

  @override
  String get save => 'Зберегти';

  @override
  String get enterValidAmountGreaterThan0 => 'Введіть суму, більшу за 0';

  @override
  String get updatingBudget => 'Оновлення бюджету...';

  @override
  String get budgetUpdated => 'Бюджет оновлено';

  @override
  String get failedToUpdateBudget => 'Не вдалося оновити бюджет';

  @override
  String get loggedSuccessfully => 'Успішно додано';

  @override
  String get view => 'Переглянути';

  @override
  String get retry => 'Повторити';

  @override
  String get failedToCapturePhoto => 'Не вдалося зробити фото';

  @override
  String get noSpendingData => 'Немає даних про витрати';

  @override
  String get byCategory => 'За категоріями';

  @override
  String get noExpensesYet => 'Витрат ще немає';

  @override
  String get startLoggingExpensesToSeeCategories => 'Почніть додавати витрати, щоб побачити категорії';

  @override
  String get selectDateRange => 'Обрати період';

  @override
  String get addExpense => 'Додати витрату';

  @override
  String get describeYourExpense => 'Опишіть витрату (напр., \"50 на каву, 200 на бургер\")';

  @override
  String get enterExpenseDetails => 'Введіть деталі витрати...';

  @override
  String get freeFormText => 'Довільний текст';

  @override
  String get takePhoto => 'Зробити фото';

  @override
  String get transactions => 'Транзакції';

  @override
  String get negative => 'Негативний';

  @override
  String get positive => 'Позитивний';

  @override
  String get spendingBreakdown => 'Аналіз витрат';

  @override
  String get spent => 'Витрачено';

  @override
  String get today => 'Сьогодні';

  @override
  String get yesterday => 'Вчора';

  @override
  String get thisWeek => 'Цього тижня';

  @override
  String get lastWeek => 'Минулого тижня';

  @override
  String get thisMonth => 'Цього місяця';

  @override
  String get last30Days => 'Останні 30 днів';

  @override
  String get customRange => 'Інший період';

  @override
  String get spentToday => 'Ваші витрати сьогодні';

  @override
  String get spentYesterday => 'Ваші витрати вчора';

  @override
  String get spentThisWeek => 'Ваші витрати цього тижня';

  @override
  String get spentLastWeek => 'Ваші витрати минулого тижня';

  @override
  String get spentThisMonth => 'Ваші витрати цього місяця';

  @override
  String get spentLast30Days => 'Ваші витрати (за 30 днів)';

  @override
  String get spentCustom => 'Витрачено (інший період)';

  @override
  String get todaysBudget => 'Бюджет на сьогодні';

  @override
  String get yesterdaysBudget => 'Бюджет на вчора';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Сума денних бюджетів за тиждень';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Сума денних бюджетів за минулий тиждень';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Сума денних бюджетів за місяць';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Сума денних бюджетів за 30 днів';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Сума денних бюджетів за обраний період';

  @override
  String get netCashflowToday => 'Чистий потік (сьогодні)';

  @override
  String get netCashflowYesterday => 'Чистий потік (вчора)';

  @override
  String get netCashflowThisWeek => 'Чистий потік (цей тиждень)';

  @override
  String get netCashflowLastWeek => 'Чистий потік (минулий тиждень)';

  @override
  String get netCashflowThisMonth => 'Чистий потік (цей місяць)';

  @override
  String get netCashflowLast30Days => 'Чистий потік (за 30 днів)';

  @override
  String get netCashflowCustom => 'Чистий потік (інший період)';

  @override
  String get selectCurrency => 'Оберіть валюту';

  @override
  String get showLessCurrencies => 'Показати менше валют';

  @override
  String showAllCurrencies(int count) {
    return 'Показати всі валюти (ще $count)';
  }

  @override
  String get budget => 'Бюджет';

  @override
  String get spentLabel => 'Витрачено';

  @override
  String get net => 'Чистий';

  @override
  String get txn => 'тр.';

  @override
  String get txns => 'тр.';

  @override
  String get pleaseEnterExpenseDetails => 'Будь ласка, введіть деталі витрати';

  @override
  String get userNotLoggedIn => 'Користувач не ввійшов у систему';

  @override
  String get errorLoadingHouseholds => 'Помилка завантаження домогосподарств';

  @override
  String get welcomeToHouseholds => 'Вітаємо в Групах';

  @override
  String get householdsDescription => 'Керуйте спільними фінансами з сім\'єю, партнером чи сусідами. Слідкуйте за бюджетами, діліть витрати та приймайте рішення разом.';

  @override
  String get createHousehold => 'Створити домогосподарство';

  @override
  String get joinWithInvite => 'Приєднатись за запрошенням';

  @override
  String get pleaseUseInvitationLink => 'Будь ласка, використайте посилання‑запрошення, щоб приєднатися до домогосподарства';

  @override
  String get householdName => 'Назва домогосподарства';

  @override
  String get householdNameHint => 'Наприклад, Сім\'я Ковальчуків';

  @override
  String get pleaseEnterHouseholdName => 'Будь ласка, введіть назву домогосподарства';

  @override
  String get errorCreatingHousehold => 'Помилка створення домогосподарства';

  @override
  String get householdsFeature => 'Функція \"Групи\"';

  @override
  String get householdsFeatureDescription => 'Функція \"Групи\" вже доступна! Керуйте спільними фінансами з родиною, партнером чи сусідами.';

  @override
  String get gotIt => 'Зрозуміло!';

  @override
  String get confirmExpense => 'Підтвердити витрату';

  @override
  String get expenseDetails => 'Деталі витрати';

  @override
  String get details => 'Деталі';

  @override
  String get category => 'Категорія';

  @override
  String get currency => 'Валюта';

  @override
  String get date => 'Дата';

  @override
  String get time => 'Час';

  @override
  String get notes => 'Нотатки';

  @override
  String get receipt => 'Чек';

  @override
  String get saveExpense => 'Зберегти витрату';

  @override
  String get shareWithHousehold => 'Поділитися з домогосподарством';

  @override
  String get loadingHouseholdMembers => 'Завантаження учасників домогосподарства...';

  @override
  String get selectHouseholdToConfigureSplit => 'Оберіть домогосподарство, щоб налаштувати розділення';

  @override
  String get currencyManagedByHousehold => 'Валюта керується домогосподарством і не може бути змінена';

  @override
  String get currencyCannotBeChanged => 'Валюту не можна змінити, якщо ви ділитеся витратою з домогосподарством';

  @override
  String get failedToLoadImage => 'Не вдалося завантажити зображення';

  @override
  String get editAmount => 'Редагувати суму';

  @override
  String get amount => 'Сума';

  @override
  String get editNotes => 'Редагувати нотатки';

  @override
  String get addANote => 'Додати нотатку...';

  @override
  String get noMembersFoundInHousehold => 'У домогосподарстві не знайдено учасників';

  @override
  String get errorLoadingMembers => 'Помилка завантаження учасників';

  @override
  String get noExpenseToSave => 'Немає витрати для збереження';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'Витрату збережено та поширено$splitInfo!';
  }

  @override
  String get expenseSaved => 'Витрату збережено!';

  @override
  String failedToSave(String error) {
    return 'Помилка збереження: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Помилка синхронізації валюти: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Валюту успішно оновлено';

  @override
  String retryFailed(Object error) {
    return 'Повторна спроба не вдалася: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'Витрачено $amount $currencySymbol на $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Введіть новий загальний денний бюджет.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Будь ласка, увійдіть, щоб отримати доступ до функцій домогосподарства';

  @override
  String get quickActions => 'Швидкі дії';

  @override
  String get members => 'Учасники';

  @override
  String get invites => 'Запрошення';

  @override
  String get errorLoadingExpenses => 'Помилка завантаження витрат';

  @override
  String get budgets => 'Бюджети';

  @override
  String get loadingHousehold => 'Завантаження домогосподарства...';

  @override
  String get remaining => 'Залишок';

  @override
  String get overBudget => 'Понад бюджет';

  @override
  String get sharedBudgets => 'Спільні бюджети';

  @override
  String get netPosition => 'Чиста позиція';

  @override
  String get spentByHousehold => 'Витрати групи';

  @override
  String get memberSpending => 'Витрати за учасниками';

  @override
  String get spentByHouseholdTooltip => 'Показує загальну суму, витрачену всіма учасниками групи за обраний період. Включає всі спільні витрати, додані будь-яким учасником групи.';

  @override
  String get manageMoneyTogether => 'Керуйте грошима разом з партнером, родиною чи сусідами в одному спільному просторі.';

  @override
  String get sharedBudgetsExpenses => 'Спільні бюджети та витрати';

  @override
  String get sharedBudgetsExpensesDesc => 'Створюйте бюджети, відстежуйте витрати та дивіться, куди йдуть спільні гроші, в реальному часі.';

  @override
  String get smartExpenseSplitting => 'Розумне розділення витрат';

  @override
  String get smartExpenseSplittingDesc => 'Автоматично розраховуйте, хто кому скільки винен, з гнучкими опціями: порівну, за відсотками чи точними сумами.';

  @override
  String get stayInSync => 'Будьте на зв\'язку';

  @override
  String get stayInSyncDesc => 'Отримуйте сповіщення про додавання витрат, досягнення бюджетів чи необхідність розрахуватися.';

  @override
  String get householdSettings => 'Налаштування домогосподарства';

  @override
  String get householdNotFound => 'Групу не знайдено';

  @override
  String get coverPhoto => 'Обкладинка';

  @override
  String get changeCoverPhoto => 'Змінити обкладинку';

  @override
  String get saveChanges => 'Зберегти зміни';

  @override
  String get errorLoadingHousehold => 'Помилка завантаження домогосподарства';

  @override
  String get householdUpdatedSuccessfully => 'Групу успішно оновлено';

  @override
  String get failedToUpdateHousehold => 'Не вдалося оновити домогосподарство';

  @override
  String get inviteMember => 'Запросити учасника';

  @override
  String get removeMember => 'Видалити учасника';

  @override
  String get remove => 'Видалити';

  @override
  String get confirmRemoveMember => 'Ви впевнені, що хочете видалити';

  @override
  String get updatedMemberRole => 'Роль оновлено';

  @override
  String get unknown => 'Невідомо';

  @override
  String get makeAdmin => 'Зробити адміністратором';

  @override
  String get makeMember => 'Зробити учасником';

  @override
  String get invitations => 'Запрошення';

  @override
  String get errorLoadingInvites => 'Помилка завантаження запрошень';

  @override
  String get createInvitation => 'Створити запрошення';

  @override
  String get pendingInvitations => 'Очікують на відповідь';

  @override
  String get noPendingInvitations => 'Немає активних запрошень';

  @override
  String get invitationHistory => 'Історія запрошень';

  @override
  String get noInvitationHistory => 'Немає історії запрошень';

  @override
  String get emailOptional => 'Email (необов\'язково)';

  @override
  String get friendEmailExample => 'dryg@example.com';

  @override
  String get personalMessageOptional => 'Особисте повідомлення (необов\'язково)';

  @override
  String get joinHouseholdBudget => 'Приєднуйся до нашого спільного бюджету!';

  @override
  String get expiresIn => 'Термін дії';

  @override
  String get oneDay => '1 день';

  @override
  String get threeDays => '3 дні';

  @override
  String get sevenDays => '7 днів';

  @override
  String get fourteenDays => '14 днів';

  @override
  String get thirtyDays => '30 днів';

  @override
  String get unlimited => 'Без обмежень';

  @override
  String get create => 'Створити';

  @override
  String get invitationCreatedSuccessfully => 'Запрошення успішно створено';

  @override
  String get inviteLinkCopiedToClipboard => 'Посилання скопійовано в буфер обміну!';

  @override
  String get errorCreatingInvite => 'Помилка створення запрошення';

  @override
  String get revokeInvitation => 'Скасувати запрошення';

  @override
  String get confirmRevokeInvitation => 'Ви впевнені, що хочете скасувати це запрошення?';

  @override
  String get revoke => 'Скасувати';

  @override
  String get invitationRevoked => 'Запрошення скасовано';

  @override
  String get errorRevokingInvite => 'Помилка скасування запрошення';

  @override
  String get anyoneWithLink => 'Будь-хто за посиланням';

  @override
  String get noExpiry => 'Без терміну дії';

  @override
  String get expired => 'Термін дії минув';

  @override
  String get expires => 'Дійсне до';

  @override
  String get copyLink => 'Копіювати посилання';

  @override
  String get selectCoverImage => 'Обрати обкладинку';

  @override
  String get failedToLoadImages => 'Не вдалося завантажити зображення';

  @override
  String get chooseFromGallery => 'Обрати з галереї';

  @override
  String get failedToLoad => 'Не вдалося завантажити';

  @override
  String get imageTooLarge => 'Зображення завелике';

  @override
  String get maxIs => 'Макс. розмір:';

  @override
  String get unsupportedFileFormat => 'Непідтримуваний формат. Використовуйте JPG, PNG або WebP.';

  @override
  String get cropCoverImage => 'Обрізати обкладинку';

  @override
  String get editBudget => 'Редагувати бюджет';

  @override
  String get budgetDetails => 'Деталі бюджету';

  @override
  String get budgetName => 'Назва бюджету';

  @override
  String get period => 'Період';

  @override
  String get alertThresholds => 'Рівні сповіщень';

  @override
  String get warningThreshold => 'Поріг попередження (%)';

  @override
  String get alertThreshold => 'Поріг тривоги (%)';

  @override
  String get warningThresholdHelper => 'Сповістити, коли використання бюджету досягне цього відсотка';

  @override
  String get alertThresholdHelper => 'Критичне сповіщення при цьому відсотку';

  @override
  String get budgetStatus => 'Статус бюджету';

  @override
  String get active => 'Активний';

  @override
  String get inactive => 'Неактивний';

  @override
  String get deletingBudget => 'Видалення бюджету...';

  @override
  String get savingChanges => 'Збереження змін...';

  @override
  String get budgetNameCannotBeEmpty => 'Назва бюджету не може бути порожньою';

  @override
  String get pleaseEnterValidAmount => 'Будь ласка, введіть дійсну суму';

  @override
  String get warningThresholdRange => 'Поріг попередження має бути від 0 до 100';

  @override
  String get alertThresholdRange => 'Поріг тривоги має бути від 0 до 100';

  @override
  String get warningThresholdLessThanAlert => 'Поріг попередження має бути меншим або дорівнювати порогу тривоги';

  @override
  String get deleteBudget => 'Видалити бюджет';

  @override
  String get confirmDeleteBudget => 'Ви впевнені, що хочете видалити';

  @override
  String get thisActionCannotBeUndone => 'Цю дію неможливо скасувати';

  @override
  String get budgetUpdatedSuccessfully => 'Бюджет успішно оновлено';

  @override
  String get budgetDeletedSuccessfully => 'Бюджет успішно видалено';

  @override
  String get categoryTransfers => 'Перекази';

  @override
  String get categoryShopping => 'Покупки';

  @override
  String get categoryUtilities => 'Комунальні';

  @override
  String get categoryEntertainment => 'Розваги';

  @override
  String get categoryEntertainmentSubscriptions => 'Підписки на розваги';

  @override
  String get categoryRestaurants => 'Ресторани';

  @override
  String get categoryFood => 'Їжа';

  @override
  String get categoryGroceries => 'Продукти';

  @override
  String get categoryTransport => 'Транспорт';

  @override
  String get categoryTransportation => 'Транспорт';

  @override
  String get categoryTravel => 'Подорожі';

  @override
  String get categoryFlights => 'Авіаквитки';

  @override
  String get categoryVacation => 'Відпустка';

  @override
  String get categoryHealth => 'Здоров\'я';

  @override
  String get categoryMedical => 'Медицина';

  @override
  String get categoryText => 'Текст';

  @override
  String get categoryEducation => 'Освіта';

  @override
  String get categoryTuition => 'Навчання';

  @override
  String get categorySubscriptions => 'Підписки';

  @override
  String get categoryServices => 'Послуги';

  @override
  String get categoryHousing => 'Житло';

  @override
  String get categoryRent => 'Оренда';

  @override
  String get categoryMortgage => 'Іпотека';

  @override
  String get categoryBills => 'Рахунки';

  @override
  String get categoryInsurance => 'Страхування';

  @override
  String get categorySavings => 'Заощадження';

  @override
  String get categoryInvestment => 'Інвестиції';

  @override
  String get categoryInvestments => 'Інвестиції';

  @override
  String get categoryIncome => 'Дохід';

  @override
  String get categorySalary => 'Зарплата';

  @override
  String get categoryBonus => 'Бонус';

  @override
  String get categoryPets => 'Дом. тварини';

  @override
  String get categoryKids => 'Діти';

  @override
  String get categoryFamily => 'Сім\'я';

  @override
  String get categoryGifts => 'Подарунки';

  @override
  String get categoryCharity => 'Благодійність';

  @override
  String get categoryFees => 'Комісії';

  @override
  String get categoryLoan => 'Позика';

  @override
  String get categoryLoans => 'Позики';

  @override
  String get categoryDebt => 'Борг';

  @override
  String get categoryPersonalCare => 'Догляд за собою';

  @override
  String get categoryBeauty => 'Краса';

  @override
  String get categoryMisc => 'Різне';

  @override
  String get categoryUncategorized => 'Без категорії';

  @override
  String get deleteBudgetCannotBeUndone => 'Цю дію неможливо скасувати';

  @override
  String get delete => 'Видалити';

  @override
  String get failedToDeleteBudget => 'Не вдалося видалити бюджет';

  @override
  String get owner => 'Власник';

  @override
  String get admin => 'Адмін';

  @override
  String get member => 'Учасник';

  @override
  String get pending => 'Очікує';

  @override
  String get accepted => 'Прийнято';

  @override
  String get revoked => 'Скасовано';

  @override
  String get tapToChangeCover => 'Торкніться, щоб змінити обкладинку';

  @override
  String get personalMessageHint => 'Напишіть щось запрошеним (напр., \"Приєднуйся до нашого бюджету!\")';

  @override
  String get invitationExpiresIn => 'Термін дії запрошення';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'днів',
      many: 'днів',
      few: 'дні',
      one: 'день',
    );
    return '$days $_temp0';
  }

  @override
  String get createHouseholdDescription => 'Створіть спільний простір для відстеження бюджетів та витрат з родиною чи сусідами.';

  @override
  String get uploadingImage => 'Завантаження зображення...';

  @override
  String get creating => 'Створення...';

  @override
  String get generatingInvite => 'Генерація запрошення...';

  @override
  String get pleaseSelectValidCurrency => 'Будь ласка, оберіть дійсну валюту домогосподарства';

  @override
  String nameMaxLength(int max) {
    return 'Назва має містити менше $max символів';
  }

  @override
  String get createHouseholdPage => 'Сторінка створення домогосподарства';

  @override
  String get invitationPersonalMessageInput => 'Поле вводу повідомлення для запрошення';

  @override
  String get householdNameInput => 'Поле вводу назви домогосподарства';

  @override
  String get invitationExpirationSelector => 'Вибір терміну дії запрошення';

  @override
  String get unlimitedExpiration => 'Безстрокове';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'днів',
      many: 'днів',
      few: 'дні',
      one: 'день',
    );
    return '$days $_temp0';
  }

  @override
  String get householdInformation => 'Інформація про домогосподарство';

  @override
  String get creatingHousehold => 'Створення домогосподарства';

  @override
  String get createHouseholdButton => 'Кнопка \'Створити домогосподарство\'';

  @override
  String get searchExpenses => 'Пошук витрат...';

  @override
  String get clearAll => 'Очистити все';

  @override
  String get allCategories => 'Всі категорії';

  @override
  String get allMembers => 'Всі учасники';

  @override
  String get balanceSummary => 'Баланс';

  @override
  String get youAreOwed => 'Вам винні';

  @override
  String get youOwe => 'Ви винні';

  @override
  String get youOweOthers => 'Ви винні іншим';

  @override
  String get othersOweYou => 'Інші винні вам';

  @override
  String get viewDetails => 'Детальніше';

  @override
  String get settleUp => 'Розрахуватись';

  @override
  String get markExpensesAsSettled => 'Позначте витрати як \"Розраховані\", щоб оновити баланс';

  @override
  String get whoAreYouSettlingWith => 'З ким ви розраховуєтесь?';

  @override
  String get selectMember => 'Оберіть учасника';

  @override
  String get amountToSettle => 'Сума до розрахунку';

  @override
  String get howDidYouSettle => 'Як ви розрахувалися?';

  @override
  String get cash => 'Готівка';

  @override
  String get paidInCash => 'Оплачено готівкою';

  @override
  String get bankTransfer => 'Переказ';

  @override
  String get transferredViaBank => 'Переказано через банк';

  @override
  String get mobilePayment => 'Мобільний платіж';

  @override
  String get venmoPaypalEtc => 'Venmo, PayPal тощо.';

  @override
  String get search => 'Пошук';

  @override
  String get noData => 'Немає даних';

  @override
  String get filterTransactions => 'Фільтр транзакцій';

  @override
  String get noTransactionsFound => 'Транзакцій не знайдено';

  @override
  String get failedToLoadHouseholdTransactions => 'Не вдалося завантажити транзакції домогосподарства';

  @override
  String get reset => 'Скинути';

  @override
  String get apply => 'Застосувати';

  @override
  String get expenses => 'Витрати';

  @override
  String get dateRange => 'Період';

  @override
  String get noMatchingExpenses => 'Відповідних витрат не знайдено';

  @override
  String get startLoggingExpenses => 'Почніть додавати витрати, щоб побачити їх тут';

  @override
  String get tryAdjustingFilters => 'Спробуйте змінити фільтри';

  @override
  String get split => 'Розділити';

  @override
  String get note => 'Нотатка';

  @override
  String get currencyCannotBeChangedWhenSharing => 'Валюту не можна змінити, якщо ви ділитеся витратою з домогосподарством';

  @override
  String get createBudget => 'Створити бюджет';

  @override
  String get pleaseEnterABudgetName => 'Будь ласка, введіть назву бюджету';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Будь ласка, введіть суму, більшу за 0';

  @override
  String get warningThresholdMustBeBetween0And100 => 'Поріг попередження має бути від 0 до 100%';

  @override
  String get alertThresholdMustBeBetween0And100 => 'Поріг тривоги має бути від 0 до 100%';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'Поріг попередження має бути меншим або дорівнювати порогу тривоги';

  @override
  String get budgetCreatedSuccessfully => 'Бюджет успішно створено!';

  @override
  String get failedToCreateBudget => 'Не вдалося створити бюджет';

  @override
  String get groceriesRentEntertainment => 'Напр., Продукти, Оренда, Розваги';

  @override
  String get budgetType => 'Тип бюджету';

  @override
  String get sharedWithAllHouseholdMembers => 'Спільний для всіх учасників домогосподарства';

  @override
  String get personalBudgetForYourExpensesOnly => 'Особистий бюджет (лише для ваших витрат)';

  @override
  String get countSplitPortionOnly => 'Враховувати лише вашу частку';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Враховувати в цьому бюджеті лише вашу частину розділених витрат';

  @override
  String get joinHousehold => 'Приєднатися до домогосподарства';

  @override
  String get joinAHousehold => 'Приєднатися до домогосподарства';

  @override
  String get enterYourInvitationLinkToJoin => 'Введіть посилання-запрошення, щоб приєднатись\nдо спільного фінансового простору';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Вставте посилання-запрошення, яке ви отримали від учасника домогосподарства';

  @override
  String get pasteInvitationLink => 'Вставити посилання';

  @override
  String get pleaseEnterAnInvitationLink => 'Будь ласка, введіть посилання-запрошення';

  @override
  String get pleaseEnterAValidInvitationLink => 'Будь ласка, введіть дійсне посилання-запрошення';

  @override
  String get paste => 'Вставити';

  @override
  String get validating => 'Перевірка...';

  @override
  String get continueAction => 'Продовжити';

  @override
  String get welcomeAboard => 'Ласкаво просимо!';

  @override
  String get youreNowPartOfTheHousehold => 'Ви тепер частина домогосподарства.\nПочніть спільно керувати фінансами!';

  @override
  String get thisWillOnlyTakeAMoment => 'Це займе лише хвилинку';

  @override
  String get unableToJoin => 'Не вдалося приєднатись';

  @override
  String get tryAgain => 'Спробувати знову';

  @override
  String get goToHousehold => 'Перейти до домогосподарства';

  @override
  String get expiresSoon => 'Термін дії спливає';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Запрошення дійсне до';
  }

  @override
  String get whatYoullGet => 'Що ви отримаєте';

  @override
  String get viewSharedBudgetsAndExpenses => 'Перегляд спільних бюджетів та витрат';

  @override
  String get trackHouseholdFinancialHealth => 'Відстеження фінансового стану домогосподарства';

  @override
  String get collaborateOnFinancialDecisions => 'Спільне прийняття фінансових рішень';

  @override
  String get household => 'Група';

  @override
  String get viewAll => 'Усі';

  @override
  String get manage => 'Керувати';

  @override
  String get noBudgetsYet => 'Бюджетів ще немає';

  @override
  String get createSharedBudgetDescription => 'Створіть спільний бюджет, щоб разом стежити за витратами';

  @override
  String get errorLoadingBudgets => 'Помилка завантаження бюджетів';

  @override
  String get recentSplits => 'Останні розділення';

  @override
  String get invite => 'Запросити';

  @override
  String get last6Months => 'Останні 6 місяців';

  @override
  String get thisYear => 'Цей рік';

  @override
  String get allTime => 'За весь час';

  @override
  String nameMinLength(int min) {
    return 'Назва має містити щонайменше $min символів';
  }

  @override
  String get splitExpense => 'Розділити витрату';

  @override
  String get percent => 'Відсоток';

  @override
  String get splitShare => 'Частка';

  @override
  String get owes => 'Борг';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'Сума розділених частин має дорівнювати $amount $currency';
  }

  @override
  String get percentagesMustTotal100 => 'Сума відсотків має бути 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'Кожен має мати принаймні 1 частку';

  @override
  String get whatsappVerified => 'WhatsApp підтверджено';

  @override
  String get whatsappVerification => 'Підтвердження WhatsApp';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Ваш номер WhatsApp успішно прив\'язано до акаунту';

  @override
  String get verifyingYourWhatsAppNumber => 'Підтвердження вашого номера WhatsApp...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Введіть 6-значний код з WhatsApp';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Будь ласка, введіть 6-значний код';

  @override
  String get failedToVerifyCode => 'Не вдалося підтвердити код';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Помилка підтвердження коду. Спробуйте ще.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Код введено автоматично з посилання';

  @override
  String get verify => 'Підтвердити';

  @override
  String get verifying => 'Підтвердження...';

  @override
  String get avatarStudio => 'Студія Аватарів';

  @override
  String get preview => 'Попередній перегляд';

  @override
  String get colors => 'Кольори';

  @override
  String get randomize => 'Випадково';

  @override
  String get saveAvatar => 'Зберегти аватар';

  @override
  String get saving => 'Збереження...';

  @override
  String get skipForNow => 'Пропустити';

  @override
  String get selectColor => 'Обрати колір';

  @override
  String get failedToSaveAvatar => 'Не вдалося зберегти аватар';

  @override
  String get hair => 'Волосся';

  @override
  String get eyes => 'Очі';

  @override
  String get mouth => 'Рот';

  @override
  String get background => 'Тло';

  @override
  String get face => 'Обличчя';

  @override
  String get ears => 'Вуха';

  @override
  String get shirts => 'Одяг';

  @override
  String get brow => 'Брови';

  @override
  String get nose => 'Ніс';

  @override
  String get blush => 'Рум\'янець';

  @override
  String get accessories => 'Аксесуари';

  @override
  String get stars => 'Зірки';

  @override
  String get currencyIsManagedByHousehold => 'Валюта керується домогосподарством і не може бути змінена';

  @override
  String get buyALaptop => 'купити ноутбук за \$1,200';

  @override
  String get selectTargetDate => 'Оберіть кінцеву дату';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'Чи можу я $action до $date';
  }

  @override
  String get scenarioDateFormat => 'dd.MM.yyyy';

  @override
  String analysisFailed(String error) {
    return 'Помилка аналізу: $error';
  }

  @override
  String get leftHandChamps => 'Ті, що зліва — ваші \"важковаговики\". Ідеальні кандидати для перегляду.';

  @override
  String get smallButFrequent => 'Маленькі, але часті категорії вказують на звички, які можуть непомітно накопичуватись.';

  @override
  String get colorMatches => 'Колір збігається з тим, що на Головній, щоб вам було звичніше.';

  @override
  String get planningNewGoal => 'Плануєте нову ціль? Знайдіть категорії, які можна \"підрізати\", не чіпаючи найприємнішого.';

  @override
  String get eyeingTreatYourself => 'Плануєте \"місяць подарунків собі\"? Подивіться, які сфери можуть безпечно \"прогнутися\".';

  @override
  String get doubleCheckTagging => 'Перевірте, чи правильно ви позначили нові витрати — жодних привидів.';

  @override
  String get slideHighBar => 'Знизьте високу планку: встановіть мініліміт або перейдіть на дешевші аналоги.';

  @override
  String get nonNegotiable => 'Якщо стовпець \"недоторканний\" (привіт, оренда), плануйте *навколо* нього, а не боріться з ним.';

  @override
  String get revisitAfterScenario => 'Перегляньте ще раз після запуску сценарію, щоб побачити, чи спрацювали ваші коригування.';

  @override
  String get purpleLineCushion => 'Фіолетова лінія: \"подушка\", що лишається після кожного дня. Якщо лінія росте — ви набираєте обертів.';

  @override
  String get blueBarsBudget => 'Сині стовпці: бюджет, який ви встановили на цей день.';

  @override
  String get redBarsSpent => 'Червоні стовпці: те, що фактично пішло з вашого рахунку.';

  @override
  String get lineTrendingUpward => 'Лінія йде вгору = є зайві кошти, які можна спрямувати на заощадження.';

  @override
  String get flatDippingLine => 'Рівна лінія або падіння = час зупинитись і переглянути великі покупки.';

  @override
  String get sharpDrops => 'Різкі падіння часто збігаються з незапланованими покупками — натисніть на них, щоб переглянути.';

  @override
  String get lineRisingDays => 'Лінія росте кілька днів? Подумайте про те, щоб перекинути трохи на заощадження або погашення боргу.';

  @override
  String get lineDippingWeekend => 'Лінія падає після активних вихідних? Збалансуйте наступні дні, скоротивши дрібні необов\'язкові витрати.';

  @override
  String get feelStuckRed => 'Застрягли \"в мінусі\"? Перегляньте свій бюджет на Головній — малі зміни дають великий ефект.';

  @override
  String get thirtyDayForecastDesc => 'Цей прогноз аналізує ваші звички за останній місяць, щоб передбачити активність на наступний. Вважайте це прогнозом погоди для вашого гаманця.';

  @override
  String get greenLineExpected => 'Зелена лінія = очікувані денні витрати, якщо наступний місяць буде схожий на минулий.';

  @override
  String get spikesHighlight => 'Піки показують тижні, коли ваші звички зазвичай стають дорожчими (привіт, п\'ятнична доставка їжі).';

  @override
  String get forecastUpdates => 'Коли ви додаєте нові транзакції, прогноз плавно оновлюється — не потрібно нічого перезавантажувати.';

  @override
  String get spotExpensivePatterns => 'Помічайте дорогі патерни заздалегідь і створюйте мінібуфер, перш ніж вони настануть.';

  @override
  String get catchQuieterWeeks => 'Знаходьте \"тихі\" тижні, коли можна перекинути зайві кошти на заощадження чи погашення боргу.';

  @override
  String get timeRecurringPayments => 'Використовуйте цю інформацію, щоб спланувати час для регулярних платежів, підписок чи поповнень.';

  @override
  String get bigSpikeComing => 'Наближається великий пік? Забронкуйте дешевші варіанти заздалегідь або перенесіть гнучкі витрати на спокійніші дні.';

  @override
  String get forecastDipping => 'Прогноз падає? Нагородіть себе, запланувавши додатковий переказ на заощадження.';

  @override
  String get forecastLooksOff => 'Якщо прогноз виглядає дивно, перегляньте категорії на Головній, щоб виправити можливі помилки.';

  @override
  String get greenLineTrends => 'Зелена лінія показує ваш типовий темп заощаджень. Рух вгору означає, що ваші цілі фінансуються.';

  @override
  String get lineDipsSignals => 'Якщо лінія падає, це сигналізує про майбутні місяці, коли витрати, як правило, перевищують доходи.';

  @override
  String get largeGoalsDebts => 'Великі цілі або борги враховуються, коли ви позначаєте їх на Головній.';

  @override
  String get upwardSlope => 'Крива йде вгору? Чудово! Подумайте про збільшення пенсійних чи туристичних заощаджень.';

  @override
  String get flatSlipping => 'Рівна чи падає? Час налаштувати бюджети або збільшити доходи, поки це не перетворилося на сніговий ком.';

  @override
  String get watchSeasonalTrends => 'Слідкуйте за сезонними тенденціями — свята, навчальні семестри чи щорічні поновлення часто з\'являються тут першими.';

  @override
  String get schedulePaymentIncreases => 'Плануйте плавне збільшення платежів за кредитами, коли крива зростає.';

  @override
  String get planAheadDips => 'Плануйте заздалегідь \"просідання\", відкладаючи кошти у цільові фонди або скорочуючи необов\'язкові витрати.';

  @override
  String get checkProjectionMonthly => 'Перевіряйте прогноз щомісяця, щоб ваша \"довга гра\" залишалася приємною та гнучкою.';

  @override
  String get categoryHealthcare => 'Здоров\'я / Медицина';

  @override
  String get categoryOther => 'Інше';

  @override
  String get deleteExpense => 'Видалити витрату';

  @override
  String get confirmDeleteExpense => 'Ви впевнені, що хочете видалити цю витрату? Цю дію неможливо скасувати.';

  @override
  String get expenseDeletedSuccessfully => 'Витрату успішно видалено';

  @override
  String get failedToDeleteExpense => 'Не вдалося видалити витрату';

  @override
  String get expenseNotFoundOrDeleted => 'Витрату не знайдено або її було видалено';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Лише адміністратори та власники можуть редагувати налаштування домогосподарства';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Лише адміністратори та власники можуть створювати запрошення';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Поділитися запрошенням у домогосподарство $householdName';
  }

  @override
  String get shareInvitation => 'Поділитися запрошенням';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Група $householdName успішно створена';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'Група \"$householdName\" успішно створена!';
  }

  @override
  String get invitationLink => 'Запрошувальне посилання';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Запрошувальне посилання: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Копіювати запрошувальне посилання';

  @override
  String get copyInvitationLinkToClipboard => 'Копіювати запрошувальне посилання в буфер обміну';

  @override
  String get shareInvitationLink => 'Поділитися запрошувальним посиланням';

  @override
  String get share => 'Поділитися';

  @override
  String get closeShareSheet => 'Закрити меню \'Поділитися\'';

  @override
  String get invitationLinkCopiedToClipboard => 'Запрошувальне посилання скопійовано в буфер обміну!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Долучайтеся до мого домогосподарства \"$householdName\" у Moneko!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Долучайтеся до мого домогосподарства у Moneko';

  @override
  String get zeroAmount => '0,00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Налаштування сповіщень';

  @override
  String get budgetBoop => 'Легке нагадування';

  @override
  String get getGentleReminder => 'Отримуйте м\'яке нагадування при досягненні цього порогу';

  @override
  String get purrSuasiveNudge => 'Муркітливе нагадування';

  @override
  String get getStrongerNudge => 'Отримуйте сильніше підштовхування при досягненні цього порогу';

  @override
  String get createBudgetButton => 'Створити бюджет';

  @override
  String get daily => 'Щоденно';

  @override
  String get weekly => 'Щотижня';

  @override
  String get monthly => 'Щомісячно';

  @override
  String get yearly => 'Щорічно';

  @override
  String get householdBudgetType => 'Бюджет домогосподарства';

  @override
  String get personalBudgetType => 'Особистий бюджет';

  @override
  String joinHouseholdName(String householdName) {
    return 'Приєднатися до \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Попередній перегляд домогосподарства: $householdName, запрошено $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Запрошено $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'Термін дії спливає $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Запрошення дійсне до';

  @override
  String get personalMessageFromInviter => 'Особисте повідомлення від відправника';

  @override
  String get messageFromInviter => 'Повідомлення від відправника';

  @override
  String get joiningHousehold => 'Приєднання до домогосподарства...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Помилка: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'Сталася неочікувана помилка';

  @override
  String get invalidInvitationLinkFormat => 'Недійсний формат посилання-запрошення';

  @override
  String get invalidOrExpiredInvitation => 'Недійсне або прострочене запрошення';

  @override
  String get tomorrow => 'Завтра';

  @override
  String inDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'через $days днів',
      few: 'через $days дні',
      one: 'через 1 день',
    );
    return '$_temp0';
  }

  @override
  String get january => 'Січ';

  @override
  String get february => 'Лют';

  @override
  String get march => 'Бер';

  @override
  String get april => 'Квіт';

  @override
  String get may => 'Трав';

  @override
  String get june => 'Черв';

  @override
  String get july => 'Лип';

  @override
  String get august => 'Серп';

  @override
  String get september => 'Вер';

  @override
  String get october => 'Жовт';

  @override
  String get november => 'Лист';

  @override
  String get december => 'Груд';

  @override
  String remindUser(String name) {
    return 'Нагадати $name';
  }

  @override
  String get sendFriendlySpendingReminder => 'Надіслати дружнє нагадування про витрати';

  @override
  String get addMessageOptional => 'Додайте повідомлення (необов’язково)';

  @override
  String get messageHintExample => 'Наприклад: «Гаманець теж хоче відпочити!»';

  @override
  String get sendReminder => 'Надіслати нагадування';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Будь ласка, зачекайте 24 години, перш ніж надсилати $name ще одне нагадування';
  }

  @override
  String reminderSentToName(String name) {
    return 'Нагадування надіслано $name 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'Не вдалося надіслати нагадування. Спробуйте ще раз.';
}
