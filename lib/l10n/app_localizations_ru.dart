// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'Пока нет расходов';

  @override
  String get loginWelcomeBack => 'С возвращением!';

  @override
  String get orContinueWithEmail => 'Или войдите по почте';

  @override
  String get emailAddress => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get signIn => 'Войти';

  @override
  String get newToMoneko => 'Впервые в Moneko?';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get resetYourPassword => 'Сброс пароля';

  @override
  String get email => 'Email';

  @override
  String get exampleEmail => 'you@example.com';

  @override
  String get cancel => 'Отмена';

  @override
  String get sendResetLink => 'Отправить ссылку для сброса';

  @override
  String get passwordResetEmailSent => 'Письмо для сброса пароля отправлено. Проверьте почту.';

  @override
  String get enterValidEmail => 'Введите корректный адрес эл. почты';

  @override
  String passwordMinLength(int min) {
    return 'Пароль должен быть не менее $min символов';
  }

  @override
  String fullNameMinLength(int min) {
    return 'Полное имя должно быть не менее $min символов';
  }

  @override
  String get createYourAccount => 'Создайте аккаунт';

  @override
  String get fullName => 'Полное имя';

  @override
  String get createPassword => 'Придумайте пароль';

  @override
  String get passwordComplexityRequirement => 'Пароль должен содержать хотя бы одну заглавную букву, одну строчную и одну цифру';

  @override
  String get passwordRequirementShort => 'Пароль: 8+ символов, заглавные, строчные и цифры';

  @override
  String get termsAgreement => 'Создавая аккаунт, вы соглашаетесь с Условиями обслуживания и Политикой конфиденциальности';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get signInLower => 'войти';

  @override
  String get verificationCodeSent => 'Код проверки успешно отправлен';

  @override
  String get verifyYourEmail => 'Подтвердите email';

  @override
  String verificationEmailSentTo(String email) {
    return 'Мы отправили 6-значный код на $email';
  }

  @override
  String get enterCompleteCode => 'Введите 6-значный код полностью';

  @override
  String get invalidVerificationCode => 'Неверный код';

  @override
  String get verificationCodeExpired => 'Срок действия кода истёк. Запросите новый.';

  @override
  String get verifyEmail => 'Подтвердить Email';

  @override
  String get didntReceiveTheCode => 'Не пришёл код? Проверьте спам или';

  @override
  String resendInSeconds(int seconds) {
    return 'отправить снова через $seconds сек.';
  }

  @override
  String get resendVerificationEmail => 'отправить код повторно';

  @override
  String get continueWithGoogle => 'Войти через Google';

  @override
  String get signingInWithGoogle => 'Вход через Google...';

  @override
  String get error => 'Ошибка';

  @override
  String get anErrorOccurred => 'Произошла ошибка';

  @override
  String get unknownError => 'Неизвестная ошибка';

  @override
  String get goToHome => 'На главную';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ Оплата прошла! Проверяем подписку...';

  @override
  String get paymentFailed => 'Платёж не прошёл';

  @override
  String get paymentCanceled => 'ℹ️ Платёж отменён';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp успешно подтверждён!';

  @override
  String get settings => 'Настройки';

  @override
  String get enableNotificationsInSettings => 'Включите уведомления для Moneko в настройках устройства';

  @override
  String get appearance => 'Оформление';

  @override
  String get darkMode => 'Тёмная тема';

  @override
  String get notifications => 'Уведомления';

  @override
  String get pushNotifications => 'Push-уведомления';

  @override
  String get receiveAlertsAndUpdates => 'Получать оповещения и обновления';

  @override
  String get language => 'Язык';

  @override
  String get systemDefault => 'Как в системе';

  @override
  String get membership => 'Подписка';

  @override
  String get loading => 'Загрузка...';

  @override
  String get failedToLoadMembership => 'Не удалось загрузить подписку';

  @override
  String get couldNotOpenMembershipPage => 'Не удалось открыть страницу подписки';

  @override
  String get freePlan => 'Бесплатно';

  @override
  String get freePlanStatus => 'Бесплатный план';

  @override
  String get lifetimePlan => 'Навсегда';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus (ежемесячно)';

  @override
  String get plusYearlyPlan => 'Plus (ежегодно)';

  @override
  String get activeStatus => 'Активна';

  @override
  String get activeLifetimeStatus => 'Активна • Навсегда';

  @override
  String get canceledStatus => 'Отменена';

  @override
  String get pastDueStatus => 'Просрочена';

  @override
  String get trialStatus => 'Пробный период';

  @override
  String trialEndsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '1 день',
    );
    return 'Пробный период закончится через $_temp0';
  }

  @override
  String get trialEnded => 'Пробный период окончен';

  @override
  String renewsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '1 день',
    );
    return 'Продление через $_temp0';
  }

  @override
  String accessEndsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '1 день',
    );
    return 'Доступ закроется через $_temp0';
  }

  @override
  String get subscriptionEnded => 'Подписка закончилась';

  @override
  String get profile => 'Профиль';

  @override
  String get errorLoadingProfile => 'Ошибка загрузки профиля';

  @override
  String get user => 'Пользователь';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp подключён';

  @override
  String get logExpensesViaWhatsApp => 'Запись расходов через WhatsApp';

  @override
  String get connectWhatsApp => 'Подключить WhatsApp';

  @override
  String get newBadge => 'НОВОЕ';

  @override
  String get logExpensesInstantly => 'Мгновенная запись расходов в чате';

  @override
  String get fast => 'Быстро';

  @override
  String get photo => 'Фото';

  @override
  String get autoSync => 'Автосинхронизация';

  @override
  String get naturalLanguage => 'Естественный язык';

  @override
  String get describeExpenseAutomatically => 'Опишите расход. Мы запишем его автоматически.';

  @override
  String get snapReceipt => 'Сфотографируйте чек';

  @override
  String get snapReceiptDescription => 'Сфотографируйте чек. ИИ распознает и запишет.';

  @override
  String get previous => 'Назад';

  @override
  String get next => 'Далее';

  @override
  String get overview => 'Обзор';

  @override
  String get activity => 'Активность';

  @override
  String get accountInformation => 'Информация об аккаунте';

  @override
  String get userId => 'ID пользователя';

  @override
  String get recentActivity => 'Последние действия';

  @override
  String get noActivityYet => 'Здесь пока пусто';

  @override
  String get signOut => 'Выйти';

  @override
  String get insights => 'Аналитика';

  @override
  String get runningTab => 'Динамика';

  @override
  String get day30Tab => '30 дней';

  @override
  String get longTermTab => 'Перспектива';

  @override
  String get scenarioTab => 'Сценарий';

  @override
  String get runningAndDailyBalances => 'Накопительный и дневной баланс';

  @override
  String get budgetVsSpentDescription => 'Бюджет и траты по дням с накопительным балансом.';

  @override
  String get runningBalanceLegend => 'Накопительный баланс';

  @override
  String get budgetLegend => 'Бюджет';

  @override
  String get spentLegend => 'Потрачено';

  @override
  String get runningBalanceGuide => 'Гайд по накопительному балансу';

  @override
  String get runningBalanceIntro => 'Этот график — ваш личный финансовый тренер. Давайте разберёмся, что он показывает и как им пользоваться.';

  @override
  String get day30LookAhead => 'Прогноз на 30 дней';

  @override
  String get projectedFromTrailing30Days => 'На основе средних трат за последние 30 дней.';

  @override
  String get projectedSpendingLegend => 'Прогноз трат';

  @override
  String get peek30DaysAhead => 'Загляните на 30 дней вперёд';

  @override
  String get day30ForecastIntro => 'Этот прогноз использует данные за прошлый месяц, чтобы предсказать активность в следующем. Считайте это прогнозом погоды для вашего кошелька.';

  @override
  String get longTermProjection => 'Долгосрочный прогноз';

  @override
  String get basedOnHistoricalAverages => 'На основе вашей истории трат; обновляется автоматически.';

  @override
  String get month18ProjectionLegend => 'Прогноз на 18 месяцев';

  @override
  String get your18MonthHorizon => 'Ваш горизонт — 18 месяцев';

  @override
  String get longTermIntro => 'Этот прогноз сочетает ваши привычки с умеренными допущениями о росте, чтобы вы увидели, к чему ведут сегодняшние решения.';

  @override
  String get aiScenarioPlanning => 'AI-планировщик сценариев';

  @override
  String get askAiFinancialAdvisor => 'Спросите AI-советника, можете ли вы позволить себе будущую трату';

  @override
  String get canI => 'Смогу ли я';

  @override
  String get before => 'до';

  @override
  String get beforePrefix => 'до';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Выбрать дату';

  @override
  String get check => 'Проверить';

  @override
  String get enterQuestionAndPickDate => 'Введите вопрос и выберите дату';

  @override
  String get analyzingScenario => 'Анализирую сценарий...';

  @override
  String get thisMightTakeAWhile => 'Это может занять некоторое время';

  @override
  String get whereTheMoneyWent => 'Куда ушли деньги';

  @override
  String get categoryTotalsForSelectedRange => 'Итоги по категориям за выбранный период.';

  @override
  String get scenarioCategoriesGuide => 'Как читать категории';

  @override
  String get categoryGuideIntro => 'Этот график — взгляд с высоты птичьего полёта на то, куда улетел каждый рубль. Вот как понять его без калькулятора.';

  @override
  String get readTheBarChartLikeAPro => 'Читаем график как профи';

  @override
  String get categoryChartDesc => 'Разбивка по категориям за выбранный период.';

  @override
  String get whyThisViewIsHelpful => 'Чем полезен этот график';

  @override
  String get categoryWhyHelpfulDesc => 'Помогает быстро найти самые крупные категории трат и заметить тренды.';

  @override
  String get whatToDoWithTheInsight => 'Что делать с этой информацией';

  @override
  String get categoryWhatToDoDesc => 'Используйте это, чтобы скорректировать бюджет и свои привычки.';

  @override
  String get scenarioAnalysis => 'Анализ сценария';

  @override
  String get target => 'Цель';

  @override
  String get quickStats => 'Краткая сводка';

  @override
  String get currentBalance => 'Текущий баланс';

  @override
  String get projectedNoChange => 'Прогноз (без изменений)';

  @override
  String get avgDailyNet => 'Сред. чистый доход/день';

  @override
  String get noDataAvailable => 'Нет данных';

  @override
  String get day => 'День';

  @override
  String get close => 'Закрыть';

  @override
  String get done => 'Готово';

  @override
  String get whatYouAreSeeing => 'Что вы видите';

  @override
  String get whyItMatters => 'Почему это важно';

  @override
  String get howToRespond => 'Как реагировать';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Накопительный баланс показывает, сколько у вас «свободы» после трат. Дневные столбцы — это ваш план против факта.';

  @override
  String get runningBalanceWhyMattersDesc => 'Это дружеская проверка пульса. Она помогает заметить, когда вы опережаете план, или когда пора скорректировать курс.';

  @override
  String get runningBalanceHowToRespondDesc => 'Используйте график как тренера. Радуйтесь успехам, меняйте ожидания, будьте к себе снисходительны — важен прогресс, а не идеальность.';

  @override
  String get whatTheForecastShows => 'Что показывает прогноз';

  @override
  String get day30WhatShowsDesc => 'Мы берём траты и доходы за 30 дней, чтобы набросать среднюю неделю. Это сглаживает разовые траты, показывая ваш обычный ритм.';

  @override
  String get day30WhyMattersDesc => 'Прогноз помогает действовать наперёд. Видя крупные траты, вы можете отложить деньги, а не искать их в панике.';

  @override
  String get day30HowToPlaySmartDesc => 'Это дружеский совет, а не строгие правила. Корректируйте план небольшими, посильными шагами.';

  @override
  String get howTheProjectionWorks => 'Как работает прогноз';

  @override
  String get longTermHowWorksDesc => 'Мы проецируем ваши средние доходы и расходы вперёд, добавляя скромный рост, чтобы вы видели, останутся ли у вас свободные деньги.';

  @override
  String get longTermWhyMattersDesc => 'Длинный горизонт делает мечты реальными. Посмотрите, всё ли в порядке с вашей подушкой безопасности или накоплениями на крупные цели.';

  @override
  String get longTermMovesToConsiderDesc => 'Используйте график, чтобы «отрепетировать» будущие решения. Маленькие шаги сегодня ведут к большим победам завтра.';

  @override
  String get forMe => 'Для меня';

  @override
  String get forUs => 'Для нас';

  @override
  String get home => 'Главная';

  @override
  String get reminder => 'Напоминание';

  @override
  String get analyzingReceipt => 'Анализирую чек...';

  @override
  String get analyzingExpense => 'Анализирую расход...';

  @override
  String get noExpenseInformationExtracted => 'Не удалось распознать расход';

  @override
  String get failedToAnalyzeNoData => 'Ошибка анализа: нет данных';

  @override
  String get failedToAnalyze => 'Ошибка анализа';

  @override
  String get updateBudget => 'Изменить бюджет';

  @override
  String get enterNewTotalDailyBudget => 'Введите новый общий дневной бюджет.';

  @override
  String get budgetAmount => 'Сумма бюджета';

  @override
  String get save => 'Сохранить';

  @override
  String get enterValidAmountGreaterThan0 => 'Пожалуйста, введите действительную сумму больше 0';

  @override
  String get updatingBudget => 'Обновляю бюджет...';

  @override
  String get budgetUpdated => 'Бюджет обновлён';

  @override
  String get failedToUpdateBudget => 'Не удалось обновить бюджет';

  @override
  String get loggedSuccessfully => 'Успешно записано';

  @override
  String get view => 'Посмотреть';

  @override
  String get retry => 'Повторить';

  @override
  String get failedToCapturePhoto => 'Не удалось сделать фото';

  @override
  String get noSpendingData => 'Нет данных о тратах';

  @override
  String get byCategory => 'По категориям';

  @override
  String get noExpensesYet => 'Расходов пока нет';

  @override
  String get startLoggingExpensesToSeeCategories => 'Начните записывать расходы, чтобы увидеть категории';

  @override
  String get selectDateRange => 'Выберите период';

  @override
  String get addExpense => 'Добавить расход';

  @override
  String get describeYourExpense => 'Опишите расход (напр.: \"5 на бургер, 3 на кофе\")';

  @override
  String get enterExpenseDetails => 'Введите детали расхода...';

  @override
  String get freeFormText => 'Свободный текст';

  @override
  String get takePhoto => 'Сделать фото';

  @override
  String get transactions => 'Операции';

  @override
  String get negative => 'Отрицательный';

  @override
  String get positive => 'Положительный';

  @override
  String get spendingBreakdown => 'Структура трат';

  @override
  String get spent => 'Потрачено';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get thisWeek => 'На этой неделе';

  @override
  String get lastWeek => 'На прошлой неделе';

  @override
  String get thisMonth => 'В этом месяце';

  @override
  String get last30Days => 'За 30 дней';

  @override
  String get customRange => 'Другой период';

  @override
  String get spentToday => 'Ваши расходы сегодня';

  @override
  String get spentYesterday => 'Ваши расходы вчера';

  @override
  String get spentThisWeek => 'Ваши расходы на этой неделе';

  @override
  String get spentLastWeek => 'Ваши расходы на прошлой неделе';

  @override
  String get spentThisMonth => 'Ваши расходы в этом месяце';

  @override
  String get spentLast30Days => 'Ваши расходы (за 30 дней)';

  @override
  String get spentCustom => 'Потрачено (за период)';

  @override
  String get todaysBudget => 'Бюджет на сегодня';

  @override
  String get yesterdaysBudget => 'Бюджет на вчера';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Сумма дневных бюджетов за неделю';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Сумма дневных бюджетов за прошлую неделю';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Сумма дневных бюджетов за месяц';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Сумма дневных бюджетов за 30 дней';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Сумма дневных бюджетов за период';

  @override
  String get netCashflowToday => 'Чистый доход за сегодня';

  @override
  String get netCashflowYesterday => 'Чистый доход за вчера';

  @override
  String get netCashflowThisWeek => 'Чистый доход за неделю';

  @override
  String get netCashflowLastWeek => 'Чистый доход за прошлую неделю';

  @override
  String get netCashflowThisMonth => 'Чистый доход за месяц';

  @override
  String get netCashflowLast30Days => 'Чистый доход (за 30 дней)';

  @override
  String get netCashflowCustom => 'Чистый доход (за период)';

  @override
  String get selectCurrency => 'Выберите валюту';

  @override
  String get showLessCurrencies => 'Скрыть валюты';

  @override
  String showAllCurrencies(int count) {
    return 'Показать все валюты (ещё $count)';
  }

  @override
  String get budget => 'Бюджет';

  @override
  String get spentLabel => 'Траты';

  @override
  String get net => 'Итог';

  @override
  String get txn => 'оп.';

  @override
  String get txns => 'опер.';

  @override
  String get pleaseEnterExpenseDetails => 'Введите детали расхода';

  @override
  String get userNotLoggedIn => 'Пользователь не авторизован';

  @override
  String get errorLoadingHouseholds => 'Ошибка загрузки домохозяйств';

  @override
  String get welcomeToHouseholds => 'Добро пожаловать в Группы';

  @override
  String get householdsDescription => 'Управляйте общими финансами с семьёй, партнёром или соседями. Следите за бюджетами, делите расходы и принимайте решения вместе.';

  @override
  String get createHousehold => 'Создать домохозяйство';

  @override
  String get joinWithInvite => 'Войти по приглашению';

  @override
  String get pleaseUseInvitationLink => 'Используйте ссылку-приглашение, чтобы присоединиться к домохозяйству';

  @override
  String get householdName => 'Название домохозяйства';

  @override
  String get householdNameHint => 'Напр., Семья Ивановых';

  @override
  String get pleaseEnterHouseholdName => 'Введите название домохозяйства';

  @override
  String get errorCreatingHousehold => 'Ошибка при создании домохозяйства';

  @override
  String get householdsFeature => 'Функция «Группы»';

  @override
  String get householdsFeatureDescription => 'Доступна функция «Группы»! Управляйте общими финансами с семьёй, партнёром или соседями.';

  @override
  String get gotIt => 'Понятно!';

  @override
  String get confirmExpense => 'Подтвердить расход';

  @override
  String get expenseDetails => 'Детали расхода';

  @override
  String get details => 'Детали';

  @override
  String get category => 'Категория';

  @override
  String get currency => 'Валюта';

  @override
  String get date => 'Дата';

  @override
  String get time => 'Время';

  @override
  String get notes => 'Заметки';

  @override
  String get receipt => 'Чек';

  @override
  String get saveExpense => 'Сохранить расход';

  @override
  String get shareWithHousehold => 'Поделиться с домохозяйством';

  @override
  String get loadingHouseholdMembers => 'Загрузка участников домохозяйства...';

  @override
  String get selectHouseholdToConfigureSplit => 'Выберите домохозяйство, чтобы настроить разделение';

  @override
  String get currencyManagedByHousehold => 'Валюта управляется домохозяйством и не может быть изменена';

  @override
  String get currencyCannotBeChanged => 'Валюту нельзя изменить, если расход общий';

  @override
  String get cannotEditOthersExpenses => 'Вы можете редактировать только свои расходы';

  @override
  String get failedToLoadImage => 'Не удалось загрузить фото';

  @override
  String get editAmount => 'Изменить сумму';

  @override
  String get amount => 'Сумма';

  @override
  String get editNotes => 'Изменить заметку';

  @override
  String get addANote => 'Добавить заметку...';

  @override
  String get noMembersFoundInHousehold => 'В домохозяйстве нет участников';

  @override
  String get errorLoadingMembers => 'Ошибка загрузки участников';

  @override
  String get noExpenseToSave => 'Нет расхода для сохранения';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'Расход сохранён и добавлен в домохозяйство$splitInfo!';
  }

  @override
  String get expenseSaved => 'Расход сохранён!';

  @override
  String failedToSave(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Ошибка синхронизации валюты: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Валюта успешно обновлена';

  @override
  String retryFailed(Object error) {
    return 'Ошибка повтора: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'Я потратил(а) $currencySymbol$amount на $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Введите новый общий дневной бюджет.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Войдите, чтобы получить доступ к домохозяйствам';

  @override
  String get quickActions => 'Быстрые действия';

  @override
  String get members => 'Участники';

  @override
  String get invites => 'Приглашения';

  @override
  String get errorLoadingExpenses => 'Ошибка загрузки расходов';

  @override
  String get budgets => 'Бюджеты';

  @override
  String get loadingHousehold => 'Загрузка домохозяйства...';

  @override
  String get remaining => 'Остаток';

  @override
  String get overBudget => 'Сверх бюджета';

  @override
  String get sharedBudgets => 'Общие бюджеты';

  @override
  String get netPosition => 'Баланс';

  @override
  String get spentByHousehold => 'Расходы группы';

  @override
  String get memberSpending => 'Расходы по участникам';

  @override
  String get spentByHouseholdTooltip => 'Показывает общую сумму, потраченную всеми участниками группы за выбранный период. Включает все общие расходы, внесенные любым участником группы.';

  @override
  String get manageMoneyTogether => 'Управляйте деньгами вместе с партнёром, семьёй или соседями в одном общем пространстве.';

  @override
  String get sharedBudgetsExpenses => 'Общие бюджеты и расходы';

  @override
  String get sharedBudgetsExpensesDesc => 'Создавайте бюджеты, следите за тратами и смотрите, куда уходят деньги, в реальном времени.';

  @override
  String get smartExpenseSplitting => 'Умное разделение трат';

  @override
  String get smartExpenseSplittingDesc => 'Автоматически считайте, кто кому сколько должен: поровну, в процентах или по сумме.';

  @override
  String get stayInSync => 'Будьте в курсе';

  @override
  String get stayInSyncDesc => 'Получайте уведомления о новых расходах, достижении бюджета или когда пора рассчитаться.';

  @override
  String get householdSettings => 'Настройки домохозяйства';

  @override
  String get householdNotFound => 'Группа не найдена';

  @override
  String get coverPhoto => 'Обложка';

  @override
  String get changeCoverPhoto => 'Сменить обложку';

  @override
  String get saveChanges => 'Сохранить';

  @override
  String get errorLoadingHousehold => 'Ошибка загрузки домохозяйства';

  @override
  String get householdUpdatedSuccessfully => 'Группа успешно обновлена';

  @override
  String get failedToUpdateHousehold => 'Не удалось обновить домохозяйство';

  @override
  String get inviteMember => 'Пригласить участника';

  @override
  String get removeMember => 'Удалить участника';

  @override
  String get remove => 'Удалить';

  @override
  String get confirmRemoveMember => 'Вы уверены, что хотите удалить';

  @override
  String get updatedMemberRole => 'Роль обновлена';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get makeAdmin => 'Сделать администратором';

  @override
  String get makeMember => 'Сделать участником';

  @override
  String get invitations => 'Приглашения';

  @override
  String get errorLoadingInvites => 'Ошибка загрузки приглашений';

  @override
  String get createInvitation => 'Создать приглашение';

  @override
  String get pendingInvitations => 'Ожидающие приглашения';

  @override
  String get noPendingInvitations => 'Нет ожидающих приглашений';

  @override
  String get invitationHistory => 'История приглашений';

  @override
  String get noInvitationHistory => 'Истории приглашений нет';

  @override
  String get emailOptional => 'Email (необязательно)';

  @override
  String get friendEmailExample => 'anna@example.com';

  @override
  String get personalMessageOptional => 'Личное сообщение (необязательно)';

  @override
  String get joinHouseholdBudget => 'Присоединяйся к нашему бюджету!';

  @override
  String get expiresIn => 'Срок действия';

  @override
  String get oneDay => '1 день';

  @override
  String get threeDays => '3 дня';

  @override
  String get sevenDays => '7 дней';

  @override
  String get fourteenDays => '14 дней';

  @override
  String get thirtyDays => '30 дней';

  @override
  String get unlimited => 'Бессрочно';

  @override
  String get create => 'Создать';

  @override
  String get invitationCreatedSuccessfully => 'Приглашение создано';

  @override
  String get inviteLinkCopiedToClipboard => 'Ссылка-приглашение скопирована!';

  @override
  String get errorCreatingInvite => 'Ошибка при создании приглашения';

  @override
  String get revokeInvitation => 'Отозвать приглашение';

  @override
  String get confirmRevokeInvitation => 'Вы уверены, что хотите отозвать это приглашение?';

  @override
  String get revoke => 'Отозвать';

  @override
  String get invitationRevoked => 'Приглашение отозвано';

  @override
  String get errorRevokingInvite => 'Ошибка при отзыве приглашения';

  @override
  String get anyoneWithLink => 'Любой по ссылке';

  @override
  String get noExpiry => 'Бессрочное';

  @override
  String get expired => 'Истекло';

  @override
  String get expires => 'Истекает';

  @override
  String get copyLink => 'Копировать ссылку';

  @override
  String get selectCoverImage => 'Выбрать обложку';

  @override
  String get failedToLoadImages => 'Не удалось загрузить изображения';

  @override
  String get chooseFromGallery => 'Выбрать из галереи';

  @override
  String get failedToLoad => 'Ошибка загрузки';

  @override
  String get imageTooLarge => 'Изображение слишком большое';

  @override
  String get maxIs => 'Максимум';

  @override
  String get unsupportedFileFormat => 'Неверный формат. Используйте JPG, PNG или WebP.';

  @override
  String get cropCoverImage => 'Обрезать обложку';

  @override
  String get editBudget => 'Изменить бюджет';

  @override
  String get budgetDetails => 'Детали бюджета';

  @override
  String get budgetName => 'Название бюджета';

  @override
  String get period => 'Период';

  @override
  String get alertThresholds => 'Пороги оповещений';

  @override
  String get warningThreshold => 'Предупреждение (%)';

  @override
  String get alertThreshold => 'Тревога (%)';

  @override
  String get warningThresholdHelper => 'Оповещение при достижении этого % бюджета';

  @override
  String get alertThresholdHelper => 'Критическое оповещение при этом %';

  @override
  String get budgetStatus => 'Статус бюджета';

  @override
  String get active => 'Активные';

  @override
  String get inactive => 'Неактивен';

  @override
  String get deletingBudget => 'Удаление бюджета...';

  @override
  String get savingChanges => 'Сохранение...';

  @override
  String get budgetNameCannotBeEmpty => 'Название бюджета не может быть пустым';

  @override
  String get pleaseEnterValidAmount => 'Введите корректную сумму';

  @override
  String get warningThresholdRange => 'Порог предупреждения должен быть от 0 до 100';

  @override
  String get alertThresholdRange => 'Порог тревоги должен быть от 0 до 100';

  @override
  String get warningThresholdLessThanAlert => 'Порог предупреждения должен быть меньше или равен порогу тревоги';

  @override
  String get deleteBudget => 'Удалить бюджет';

  @override
  String get confirmDeleteBudget => 'Вы уверены, что хотите удалить';

  @override
  String get thisActionCannotBeUndone => 'Это действие нельзя отменить';

  @override
  String get budgetUpdatedSuccessfully => 'Бюджет успешно обновлён';

  @override
  String get budgetDeletedSuccessfully => 'Бюджет удалён';

  @override
  String get categoryTransfers => 'Переводы';

  @override
  String get categoryShopping => 'Покупки';

  @override
  String get categoryUtilities => 'Коммунальные услуги';

  @override
  String get categoryEntertainment => 'Развлечения';

  @override
  String get categoryEntertainmentSubscriptions => 'Подписки (развлечения)';

  @override
  String get categoryRestaurants => 'Рестораны';

  @override
  String get categoryFood => 'Еда';

  @override
  String get categoryGroceries => 'Продукты';

  @override
  String get categoryTransport => 'Транспорт';

  @override
  String get categoryTransportation => 'Транспорт';

  @override
  String get categoryTravel => 'Путешествия';

  @override
  String get categoryFlights => 'Авиабилеты';

  @override
  String get categoryVacation => 'Отпуск';

  @override
  String get categoryHealth => 'Здоровье';

  @override
  String get categoryMedical => 'Медицина';

  @override
  String get categoryText => 'Текст';

  @override
  String get categoryEducation => 'Образование';

  @override
  String get categoryTuition => 'Обучение';

  @override
  String get categorySubscriptions => 'Подписки';

  @override
  String get categoryServices => 'Услуги';

  @override
  String get categoryHousing => 'Жильё';

  @override
  String get categoryRent => 'Аренда';

  @override
  String get categoryMortgage => 'Ипотека';

  @override
  String get categoryBills => 'Счета';

  @override
  String get categoryInsurance => 'Страхование';

  @override
  String get categorySavings => 'Накопления';

  @override
  String get categoryInvestment => 'Инвестиции';

  @override
  String get categoryInvestments => 'Инвестиции';

  @override
  String get categoryIncome => 'Доход';

  @override
  String get categorySalary => 'Зарплата';

  @override
  String get categoryBonus => 'Бонус';

  @override
  String get categoryPets => 'Питомцы';

  @override
  String get categoryKids => 'Дети';

  @override
  String get categoryFamily => 'Семья';

  @override
  String get categoryGifts => 'Подарки';

  @override
  String get categoryCharity => 'Благотворительность';

  @override
  String get categoryFees => 'Комиссии';

  @override
  String get categoryLoan => 'Кредит';

  @override
  String get categoryLoans => 'Кредиты';

  @override
  String get categoryDebt => 'Долг';

  @override
  String get categoryPersonalCare => 'Уход за собой';

  @override
  String get categoryBeauty => 'Красота';

  @override
  String get categoryMisc => 'Разное';

  @override
  String get categoryUncategorized => 'Без категории';

  @override
  String get deleteBudgetCannotBeUndone => 'Это действие нельзя отменить';

  @override
  String get delete => 'Удалить';

  @override
  String get failedToDeleteBudget => 'Не удалось удалить бюджет';

  @override
  String get owner => 'Владелец';

  @override
  String get admin => 'Админ';

  @override
  String get member => 'Участник';

  @override
  String get pending => 'Ожидает';

  @override
  String get accepted => 'Принято';

  @override
  String get revoked => 'Отозвано';

  @override
  String get tapToChangeCover => 'Нажмите, чтобы сменить обложку';

  @override
  String get personalMessageHint => 'Напишите что-нибудь приглашённым (напр., \"Присоединяйся к нашему бюджету!\")';

  @override
  String get invitationExpiresIn => 'Срок действия приглашения';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '1 день',
    );
    return '$_temp0';
  }

  @override
  String get createHouseholdDescription => 'Создайте общее пространство для учёта бюджетов и трат с семьёй или соседями.';

  @override
  String get uploadingImage => 'Загрузка фото...';

  @override
  String get creating => 'Создание...';

  @override
  String get generatingInvite => 'Генерация приглашения...';

  @override
  String get pleaseSelectValidCurrency => 'Выберите валюту домохозяйства';

  @override
  String nameMaxLength(int max) {
    return 'Название должно быть короче $max символов';
  }

  @override
  String get createHouseholdPage => 'Страница создания домохозяйства';

  @override
  String get invitationPersonalMessageInput => 'Поле личного сообщения';

  @override
  String get householdNameInput => 'Поле названия домохозяйства';

  @override
  String get invitationExpirationSelector => 'Выбор срока действия';

  @override
  String get unlimitedExpiration => 'Бессрочно';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Срок: $days дня',
      many: 'Срок: $days дней',
      few: 'Срок: $days дня',
      one: 'Срок: 1 день',
    );
    return '$_temp0';
  }

  @override
  String get householdInformation => 'Информация о домохозяйстве';

  @override
  String get creatingHousehold => 'Создание домохозяйства';

  @override
  String get createHouseholdButton => 'Кнопка \'Создать домохозяйство\'';

  @override
  String get searchExpenses => 'Поиск расходов...';

  @override
  String get clearAll => 'Очистить всё';

  @override
  String get allCategories => 'Все категории';

  @override
  String get allMembers => 'Все участники';

  @override
  String get balanceSummary => 'Баланс';

  @override
  String get youAreOwed => 'Вам должны';

  @override
  String get youOwe => 'Вы должны';

  @override
  String get youOweOthers => 'Вы должны другим';

  @override
  String get othersOweYou => 'Другие должны вам';

  @override
  String get viewDetails => 'Подробнее';

  @override
  String get settleUp => 'Рассчитаться';

  @override
  String get markExpensesAsSettled => 'Отметьте расходы как погашенные, чтобы обновить баланс';

  @override
  String get whoAreYouSettlingWith => 'С кем вы рассчитываетесь?';

  @override
  String get selectMember => 'Выберите участника';

  @override
  String get amountToSettle => 'Сумма к погашению';

  @override
  String get howDidYouSettle => 'Как вы рассчитались?';

  @override
  String get cash => 'Наличные';

  @override
  String get paidInCash => 'Оплачено наличными';

  @override
  String get bankTransfer => 'Банковский перевод';

  @override
  String get transferredViaBank => 'Переведено через банк';

  @override
  String get mobilePayment => 'Мобильный платёж';

  @override
  String get venmoPaypalEtc => 'PayPal, СБП и т.п.';

  @override
  String get search => 'Поиск';

  @override
  String get noData => 'Нет данных';

  @override
  String get filterTransactions => 'Фильтр операций';

  @override
  String get noTransactionsFound => 'Операций не найдено';

  @override
  String get failedToLoadHouseholdTransactions => 'Не удалось загрузить операции домохозяйства';

  @override
  String get reset => 'Сбросить';

  @override
  String get apply => 'Применить';

  @override
  String get expenses => 'Расходы';

  @override
  String get dateRange => 'Период';

  @override
  String get noMatchingExpenses => 'Нет подходящих расходов';

  @override
  String get startLoggingExpenses => 'Начните записывать расходы, и они появятся здесь';

  @override
  String get tryAdjustingFilters => 'Попробуйте изменить фильтры';

  @override
  String get split => 'Разделить';

  @override
  String get note => 'Заметка';

  @override
  String get currencyCannotBeChangedWhenSharing => 'Валюту нельзя изменить, если расход общий';

  @override
  String get createBudget => 'Создать бюджет';

  @override
  String get pleaseEnterABudgetName => 'Введите название бюджета';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Введите сумму больше 0';

  @override
  String get warningThresholdMustBeBetween0And100 => 'Порог предупреждения должен быть от 0 до 100%';

  @override
  String get alertThresholdMustBeBetween0And100 => 'Порог тревоги должен быть от 0 до 100%';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'Порог предупреждения должен быть меньше или равен порогу тревоги';

  @override
  String get budgetCreatedSuccessfully => 'Бюджет успешно создан!';

  @override
  String get failedToCreateBudget => 'Не удалось создать бюджет';

  @override
  String get groceriesRentEntertainment => 'Напр., Продукты, Аренда, Развлечения';

  @override
  String get budgetType => 'Тип бюджета';

  @override
  String get sharedWithAllHouseholdMembers => 'Общий для всех в домохозяйстве';

  @override
  String get personalBudgetForYourExpensesOnly => 'Личный бюджет (только для ваших трат)';

  @override
  String get countSplitPortionOnly => 'Учитывать только вашу часть';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Учитывать в этом бюджете только вашу долю из общих трат';

  @override
  String get joinHousehold => 'Присоединиться к домохозяйству';

  @override
  String get joinAHousehold => 'Присоединиться к домохозяйству';

  @override
  String get enterYourInvitationLinkToJoin => 'Введите ссылку-приглашение, чтобы войти\nв общее финансовое пространство';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Вставьте ссылку-приглашение, полученную от участника домохозяйства';

  @override
  String get pasteInvitationLink => 'Вставить ссылку-приглашение';

  @override
  String get pleaseEnterAnInvitationLink => 'Введите ссылку-приглашение';

  @override
  String get pleaseEnterAValidInvitationLink => 'Введите корректную ссылку-приглашение';

  @override
  String get paste => 'Вставить';

  @override
  String get validating => 'Проверка...';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get welcomeAboard => 'Добро пожаловать!';

  @override
  String get youreNowPartOfTheHousehold => 'Теперь вы часть домохозяйства.\nНачните совместно управлять финансами!';

  @override
  String get thisWillOnlyTakeAMoment => 'Это займёт всего секунду';

  @override
  String get unableToJoin => 'Не удалось войти';

  @override
  String get tryAgain => 'Попробовать снова';

  @override
  String get goToHousehold => 'Перейти к домохозяйству';

  @override
  String get expiresSoon => 'Скоро истекает';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Приглашение действительно до $formattedDate';
  }

  @override
  String get whatYoullGet => 'Что вы получите';

  @override
  String get viewSharedBudgetsAndExpenses => 'Просматривайте общие бюджеты и расходы';

  @override
  String get trackHouseholdFinancialHealth => 'Отслеживайте финансовое состояние домохозяйства';

  @override
  String get collaborateOnFinancialDecisions => 'Совместно принимайте финансовые решения';

  @override
  String get household => 'Домохозяйство';

  @override
  String get viewAll => 'Смотреть все';

  @override
  String get manage => 'Управлять';

  @override
  String get noBudgetsYet => 'Бюджетов пока нет';

  @override
  String get createSharedBudgetDescription => 'Создайте общий бюджет, чтобы следить за тратами вместе';

  @override
  String get errorLoadingBudgets => 'Ошибка загрузки бюджетов';

  @override
  String get recentSplits => 'Последние разделения';

  @override
  String get invite => 'Пригласить';

  @override
  String get last6Months => 'За 6 месяцев';

  @override
  String get thisYear => 'В этом году';

  @override
  String get allTime => 'За всё время';

  @override
  String nameMinLength(int min) {
    return 'Название должно быть не менее $min символов';
  }

  @override
  String get splitExpense => 'Разделить расход';

  @override
  String get percent => 'Процент';

  @override
  String get splitShare => 'Доля';

  @override
  String get owes => 'Должен';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'Сумма должна быть равна $currency$amount';
  }

  @override
  String get percentagesMustTotal100 => 'Сумма процентов должна быть 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'У каждого должна быть хотя бы 1 доля';

  @override
  String get whatsappVerified => 'WhatsApp подтверждён';

  @override
  String get whatsappVerification => 'Проверка WhatsApp';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Ваш номер WhatsApp успешно привязан к аккаунту';

  @override
  String get verifyingYourWhatsAppNumber => 'Проверяем ваш номер WhatsApp...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Введите 6-значный код из WhatsApp';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Введите 6-значный код проверки';

  @override
  String get failedToVerifyCode => 'Ошибка проверки кода';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Ошибка проверки кода. Пожалуйста, попробуйте снова.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Код вставлен из ссылки';

  @override
  String get verify => 'Подтвердить';

  @override
  String get verifying => 'Проверка...';

  @override
  String get avatarStudio => 'Студия аватаров';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get colors => 'Цвета';

  @override
  String get randomize => 'Случайно';

  @override
  String get saveAvatar => 'Сохранить аватар';

  @override
  String get saving => 'Сохранение...';

  @override
  String get skipForNow => 'Пропустить';

  @override
  String get selectColor => 'Выберите цвет';

  @override
  String get failedToSaveAvatar => 'Не удалось сохранить аватар';

  @override
  String get hair => 'Волосы';

  @override
  String get eyes => 'Глаза';

  @override
  String get mouth => 'Рот';

  @override
  String get background => 'Фон';

  @override
  String get face => 'Лицо';

  @override
  String get ears => 'Уши';

  @override
  String get shirts => 'Одежда';

  @override
  String get brow => 'Брови';

  @override
  String get nose => 'Нос';

  @override
  String get blush => 'Румяна';

  @override
  String get accessories => 'Аксессуары';

  @override
  String get stars => 'Звёзды';

  @override
  String get currencyIsManagedByHousehold => 'Валюта управляется домохозяйством и не может быть изменена';

  @override
  String get buyALaptop => 'купить ноутбук за 100 000 ₽';

  @override
  String get selectTargetDate => 'Выберите дату';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'Смогу ли я $action до $date?';
  }

  @override
  String get scenarioDateFormat => 'dd.MM.yyyy';

  @override
  String analysisFailed(String error) {
    return 'Ошибка анализа: $error';
  }

  @override
  String get leftHandChamps => 'Лидеры слева — ваши «тяжеловесы». Отличные кандидаты на быструю проверку.';

  @override
  String get smallButFrequent => 'Маленькие, но частые категории намекают на привычки, которые могут незаметно съедать бюджет.';

  @override
  String get colorMatches => 'Цвет совпадает с тем, что на Главной. Так вашему мозгу комфортнее.';

  @override
  String get planningNewGoal => 'Планируете новую цель? Посмотрите, какие категории можно урезать, не трогая «святое».';

  @override
  String get eyeingTreatYourself => 'Хотите себя побаловать? Посмотрите, какие категории можно «подвинуть» без вреда для бюджета.';

  @override
  String get doubleCheckTagging => 'Проверьте, правильно ли отмечены новые расходы — никаких призраков.';

  @override
  String get slideHighBar => '«Уроните» высокий столбец, установив мини-лимит или найдя более дешёвую замену.';

  @override
  String get nonNegotiable => 'Если столбец — это святое (привет, аренда), планируйте бюджет вокруг него, а не боритесь с ним.';

  @override
  String get revisitAfterScenario => 'Вернитесь сюда после прогона сценария, чтобы увидеть, работают ли ваши корректировки.';

  @override
  String get purpleLineCushion => 'Фиолетовая линия: «подушка», оставшаяся после трат. Растёт — вы набираете темп.';

  @override
  String get blueBarsBudget => 'Синие столбцы: ваш бюджет на день.';

  @override
  String get redBarsSpent => 'Красные столбцы: то, что вы реально потратили.';

  @override
  String get lineTrendingUpward => 'Линия идёт вверх = есть свободные деньги, которые можно направить на цели.';

  @override
  String get flatDippingLine => 'Линия ровная или падает = время притормозить и пересмотреть крупные покупки.';

  @override
  String get sharpDrops => 'Резкие падения часто совпадают с незапланированными тратами — нажмите, чтобы узнать детали.';

  @override
  String get lineRisingDays => 'Линия растёт несколько дней? Подумайте о том, чтобы перевести часть в накопления.';

  @override
  String get lineDippingWeekend => 'Линия просела после выходных? Сбалансируйте следующие дни, урезав мелкие необязательные траты.';

  @override
  String get feelStuckRed => 'Застряли «в минусе»? Пересмотрите бюджет на Главной — даже мелкие правки имеют значение.';

  @override
  String get thirtyDayForecastDesc => 'Этот прогноз использует данные за прошлый месяц, чтобы предсказать активность в следующем. Считайте это прогнозом погоды для вашего кошелька.';

  @override
  String get greenLineExpected => 'Зелёная линия = ожидаемые траты, если следующий месяц будет похож на прошлый.';

  @override
  String get spikesHighlight => 'Пики показывают недели, когда вы обычно тратите больше (привет, пятничная доставка еды).';

  @override
  String get forecastUpdates => 'Когда вы добавляете новые операции, прогноз плавно обновляется — не нужно ничего нажимать.';

  @override
  String get spotExpensivePatterns => 'Замечайте «дорогие» паттерны заранее и готовьте мини-буфер до их наступления.';

  @override
  String get catchQuieterWeeks => 'Ловите «тихие» недели, когда можно перекинуть излишки в накопления или на погашение долга.';

  @override
  String get timeRecurringPayments => 'Используйте прогноз, чтобы правильно выбрать даты регулярных платежей и подписок.';

  @override
  String get bigSpikeComing => 'Грядёт большой пик трат? Забронируйте дешёвые варианты или перенесите траты на «тихие» дни.';

  @override
  String get forecastDipping => 'Прогноз падает? Наградите себя, запланировав дополнительный перевод в накопления.';

  @override
  String get forecastLooksOff => 'Если прогноз кажется странным, проверьте категории на Главной — вдруг что-то не так отмечено.';

  @override
  String get greenLineTrends => 'Зелёная линия показывает ваш обычный темп накоплений. Рост означает, что на ваши цели хватает.';

  @override
  String get lineDipsSignals => 'Если линия проседает, это сигнал о месяцах, когда расходы могут превысить доходы.';

  @override
  String get largeGoalsDebts => 'Крупные цели и долги учитываются, если вы отмечаете их на Главной.';

  @override
  String get upwardSlope => 'Кривая растёт? Отлично! Подумайте об увеличении отчислений на пенсию или отпуск.';

  @override
  String get flatSlipping => 'Ровная или падает? Время настроить бюджеты или увеличить доход, пока это не стало проблемой.';

  @override
  String get watchSeasonalTrends => 'Следите за сезонными трендами — праздники, начало учёбы или годовые подписки часто видны здесь.';

  @override
  String get schedulePaymentIncreases => 'Планируйте плавное увеличение платежей по кредитам, когда кривая растёт.';

  @override
  String get planAheadDips => 'Готовьтесь к просадкам заранее, создавая резервные фонды или урезая необязательные траты.';

  @override
  String get checkProjectionMonthly => 'Проверяйте прогноз ежемесячно, чтобы ваша долгосрочная игра оставалась гибкой и приносила удовольствие.';

  @override
  String get categoryHealthcare => 'Здоровье';

  @override
  String get categoryOther => 'Разное';

  @override
  String get deleteExpense => 'Удалить расход';

  @override
  String get confirmDeleteExpense => 'Удалить этот расход? Отменить действие будет нельзя.';

  @override
  String get expenseDeletedSuccessfully => 'Расход удалён';

  @override
  String get failedToDeleteExpense => 'Не удалось удалить расход';

  @override
  String get expenseNotFoundOrDeleted => 'Расход не найден или уже удалён';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Только администраторы и владельцы могут редактировать настройки домохозяйства';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Только администраторы и владельцы могут создавать приглашения';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Поделиться приглашением в домохозяйство $householdName';
  }

  @override
  String get shareInvitation => 'Поделиться приглашением';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Группа $householdName успешно создана';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'Группа \"$householdName\" успешно создана!';
  }

  @override
  String get invitationLink => 'Пригласительная ссылка';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Пригласительная ссылка: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Копировать пригласительную ссылку';

  @override
  String get copyInvitationLinkToClipboard => 'Копировать пригласительную ссылку в буфер обмена';

  @override
  String get shareInvitationLink => 'Поделиться пригласительной ссылкой';

  @override
  String get share => 'Поделиться';

  @override
  String get closeShareSheet => 'Закрыть меню \'Поделиться\'';

  @override
  String get invitationLinkCopiedToClipboard => 'Пригласительная ссылка скопирована в буфер обмена!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Присоединяйтесь к моему домохозяйству \"$householdName\" в Moneko!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Присоединяйтесь к моему домохозяйству в Moneko';

  @override
  String get zeroAmount => '0,00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Настройки уведомлений';

  @override
  String get budgetBoop => 'Легкое напоминание';

  @override
  String get getGentleReminder => 'Получайте мягкое напоминание при достижении этого порога';

  @override
  String get purrSuasiveNudge => 'Мурчащее напоминание';

  @override
  String get getStrongerNudge => 'Получайте более сильное подталкивание при достижении этого порога';

  @override
  String get createBudgetButton => 'Создать бюджет';

  @override
  String get daily => 'Ежедневно';

  @override
  String get weekly => 'Еженедельно';

  @override
  String get monthly => 'Ежемесячно';

  @override
  String get yearly => 'Ежегодно';

  @override
  String get householdBudgetType => 'Бюджет домохозяйства';

  @override
  String get personalBudgetType => 'Личный бюджет';

  @override
  String joinHouseholdName(String householdName) {
    return 'Присоединиться к \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Предпросмотр: $householdName, приглашает $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Приглашено от $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'Приглашение скоро истечет: $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Действительно до';

  @override
  String get personalMessageFromInviter => 'Личное сообщение от отправителя';

  @override
  String get messageFromInviter => 'Сообщение от отправителя';

  @override
  String get joiningHousehold => 'Присоединяемся к домохозяйству...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Ошибка: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'Произошла непредвиденная ошибка';

  @override
  String get invalidInvitationLinkFormat => 'Неверный формат ссылки-приглашения';

  @override
  String get invalidOrExpiredInvitation => 'Недействительное или просроченное приглашение';

  @override
  String get tomorrow => 'Завтра';

  @override
  String inDays(int days) {
    return 'через $days дн.';
  }

  @override
  String get january => 'Янв';

  @override
  String get february => 'Фев';

  @override
  String get march => 'Мар';

  @override
  String get april => 'Апр';

  @override
  String get may => 'Май';

  @override
  String get june => 'Июн';

  @override
  String get july => 'Июл';

  @override
  String get august => 'Авг';

  @override
  String get september => 'Сен';

  @override
  String get october => 'Окт';

  @override
  String get november => 'Ноя';

  @override
  String get december => 'Дек';

  @override
  String remindUser(String name) {
    return 'Напомнить $name';
  }

  @override
  String get sendFriendlySpendingReminder => 'Отправить дружеское напоминание о расходах';

  @override
  String get addMessageOptional => 'Добавить сообщение (необязательно)';

  @override
  String get messageHintExample => 'Например: «Кошельку нужен отдых!»';

  @override
  String get sendReminder => 'Отправить напоминание';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Пожалуйста, подождите 24 часа, прежде чем отправлять $name ещё одно напоминание';
  }

  @override
  String reminderSentToName(String name) {
    return 'Напоминание отправлено $name 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'Не удалось отправить напоминание. Попробуйте ещё раз.';

  @override
  String get income => 'Доход';

  @override
  String get addIncome => 'Добавить доход';

  @override
  String get incomeAdded => 'Доход успешно добавлен';

  @override
  String get noIncome => 'Доходов еще нет';

  @override
  String get noIncomeDescription => 'Записывайте свои доходы для отслеживания финансового здоровья вашего домохозяйства';

  @override
  String get totalIncome => 'Общий доход';

  @override
  String get monthToDate => 'С начала месяца';

  @override
  String get yearToDate => 'С начала года';

  @override
  String get failedToLoadIncome => 'Не удалось загрузить доходы';

  @override
  String get incomeAcknowledged => 'Доход подтвержден';

  @override
  String get acknowledge => 'Подтвердить';

  @override
  String get acknowledged => 'Подтверждено';

  @override
  String get source => 'Источник';

  @override
  String get sourceHint => 'например, Работодатель, Клиент';

  @override
  String get me => 'Я';

  @override
  String get partner => 'Партнер';

  @override
  String get privacyScope => 'Конфиденциальность';

  @override
  String get privacyFull => 'Все детали';

  @override
  String get privacyBalancesOnly => 'Только балансы';

  @override
  String get privacyPrivate => 'Личный';

  @override
  String get privacyFullExplanation => 'Партнёр может видеть все детали включая сумму, источник и описание.';

  @override
  String get privacyBalancesOnlyExplanation => 'Партнёр может видеть этот доход в итогах, но не детали (источник, описание скрыто).';

  @override
  String get privacyPrivateExplanation => 'Только вы можете видеть этот доход. Он вносит вклад в итоги домохозяйства, но партнёр не может видеть детали.';

  @override
  String get incomeSalary => 'Зарплата';

  @override
  String get incomeFreelance => 'Фриланс';

  @override
  String get incomeInvestment => 'Инвестиции';

  @override
  String get incomeRefund => 'Возврат';

  @override
  String get incomeGift => 'Подарок';

  @override
  String get incomeBonus => 'Бонус';

  @override
  String get incomeRental => 'Аренда';

  @override
  String get incomeOther => 'Другое';

  @override
  String get goals => 'Цели';

  @override
  String get createGoal => 'Создать цель';

  @override
  String get goalCreated => 'Цель успешно создана';

  @override
  String get goalTitle => 'Название цели';

  @override
  String get enterGoalTitle => 'Введите название цели';

  @override
  String get pleaseEnterTitle => 'Пожалуйста, введите название';

  @override
  String get pleaseEnterAmount => 'Пожалуйста, введите сумму';

  @override
  String get invalidAmount => 'Пожалуйста, введите сумму больше 0';

  @override
  String get targetAmount => 'Целевая сумма';

  @override
  String get currentAmount => 'Текущая сумма';

  @override
  String get targetDate => 'Целевая дата';

  @override
  String get description => 'Описание';

  @override
  String get descriptionHint => 'Примечание (необязательно)';

  @override
  String get savings => 'Сбережения';

  @override
  String get paydown => 'Погашение долга';

  @override
  String get all => 'Все';

  @override
  String get completed => 'Завершённые';

  @override
  String get offTrack => 'Отставание от плана';

  @override
  String get onTrack => 'По плану';

  @override
  String get complete => 'Завершить';

  @override
  String get overallProgress => 'Общий Прогресс';

  @override
  String get totalGoals => 'Всего целей';

  @override
  String get noGoals => 'Целей пока нет. Создайте свою первую цель, чтобы начать!';

  @override
  String get noSavingsGoals => 'Целей сбережений пока нет. Создайте одну, чтобы начать сберегать!';

  @override
  String get noPaydownGoals => 'Целей погашения пока нет. Создайте одну, чтобы начать уменьшать долги!';

  @override
  String get goalAcknowledged => 'Цель подтверждена';

  @override
  String get balancesOnly => 'Только остатки';

  @override
  String get contribution => 'Взнос';

  @override
  String get withdrawal => 'Снятие';

  @override
  String get interest => 'Проценты';

  @override
  String get adjustment => 'Корректировка';

  @override
  String get addContribution => 'Добавить взнос';

  @override
  String get contributionAmount => 'Сумма взноса';

  @override
  String get contributionType => 'Тип';

  @override
  String get contributionAdded => 'Взнос успешно добавлен';
}
