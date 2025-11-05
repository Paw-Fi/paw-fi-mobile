// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => '暂无支出';

  @override
  String get loginWelcomeBack => '欢迎回来';

  @override
  String get orContinueWithEmail => '或使用邮箱继续';

  @override
  String get emailAddress => '邮箱地址';

  @override
  String get password => '密码';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get signIn => '登录';

  @override
  String get newToMoneko => 'Moneko 新用户？';

  @override
  String get createAccount => '创建账户';

  @override
  String get resetYourPassword => '重置密码';

  @override
  String get email => '邮箱';

  @override
  String get exampleEmail => 'you@example.com';

  @override
  String get cancel => '取消';

  @override
  String get sendResetLink => '发送重置链接';

  @override
  String get passwordResetEmailSent => '密码重置邮件已发送。请检查您的收件箱。';

  @override
  String get enterValidEmail => '请输入有效的邮箱地址';

  @override
  String passwordMinLength(int min) {
    return '密码必须至少为 $min 个字符';
  }

  @override
  String fullNameMinLength(int min) {
    return '姓名必须至少为 $min 个字符';
  }

  @override
  String get createYourAccount => '创建您的账户';

  @override
  String get fullName => '姓名';

  @override
  String get createPassword => '创建密码';

  @override
  String get passwordComplexityRequirement => '密码必须包含至少一个大写字母、一个小写字母和一个数字';

  @override
  String get passwordRequirementShort => '密码至少 8 位，且包含大小写字母和数字';

  @override
  String get termsAgreement => '创建账户即表示您同意我们的服务条款和隐私政策';

  @override
  String get alreadyHaveAccount => '已有账户？';

  @override
  String get signInLower => '登录';

  @override
  String get verificationCodeSent => '验证码已成功发送';

  @override
  String get verifyYourEmail => '验证您的邮箱';

  @override
  String verificationEmailSentTo(String email) {
    return '我们已发送一个 6 位验证码至 $email';
  }

  @override
  String get enterCompleteCode => '请输入完整的 6 位验证码';

  @override
  String get invalidVerificationCode => '验证码无效';

  @override
  String get verificationCodeExpired => '验证码已过期。请重新获取。';

  @override
  String get verifyEmail => '验证邮箱';

  @override
  String get didntReceiveTheCode => '没有收到验证码？请检查您的垃圾邮件夹或';

  @override
  String resendInSeconds(int seconds) {
    return '$seconds 秒后重新发送';
  }

  @override
  String get resendVerificationEmail => '重新发送验证邮件';

  @override
  String get continueWithGoogle => 'Google 账号登录';

  @override
  String get signingInWithGoogle => '正在使用 Google 账号登录...';

  @override
  String get error => '错误';

  @override
  String get anErrorOccurred => '发生错误';

  @override
  String get unknownError => '未知错误';

  @override
  String get goToHome => '返回首页';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ 付款成功！正在检查订阅状态...';

  @override
  String get paymentFailed => '付款失败';

  @override
  String get paymentCanceled => 'ℹ️ 付款已取消';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp 验证成功！';

  @override
  String get settings => '设置';

  @override
  String get enableNotificationsInSettings => '请在您设备的系统设置中为 Moneko 开启通知';

  @override
  String get appearance => '外观';

  @override
  String get darkMode => '深色模式';

  @override
  String get notifications => '通知';

  @override
  String get pushNotifications => '推送通知';

  @override
  String get receiveAlertsAndUpdates => '接收提醒和更新';

  @override
  String get language => '语言';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get membership => '会员';

  @override
  String get loading => '加载中...';

  @override
  String get failedToLoadMembership => '会员信息加载失败';

  @override
  String get couldNotOpenMembershipPage => '无法打开会员页面';

  @override
  String get freePlan => '免费版';

  @override
  String get freePlanStatus => '免费版';

  @override
  String get lifetimePlan => '终身版';

  @override
  String get plusPlan => 'Plus 版';

  @override
  String get plusMonthlyPlan => 'Plus 月度版';

  @override
  String get plusYearlyPlan => 'Plus 年度版';

  @override
  String get activeStatus => '生效中';

  @override
  String get activeLifetimeStatus => '生效中 • 终身';

  @override
  String get canceledStatus => '已取消';

  @override
  String get pastDueStatus => '已逾期';

  @override
  String get trialStatus => '试用中';

  @override
  String trialEndsInDays(int days) {
    return '试用期剩余 $days 天';
  }

  @override
  String get trialEnded => '试用已结束';

  @override
  String renewsInDays(int days) {
    return '$days 天后自动续费';
  }

  @override
  String accessEndsInDays(int days) {
    return '访问权限剩余 $days 天';
  }

  @override
  String get subscriptionEnded => '订阅已结束';

  @override
  String get profile => '个人资料';

  @override
  String get errorLoadingProfile => '个人资料加载失败';

  @override
  String get user => '用户';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => '已连接 WhatsApp';

  @override
  String get logExpensesViaWhatsApp => '通过 WhatsApp 消息记账';

  @override
  String get connectWhatsApp => '连接 WhatsApp';

  @override
  String get newBadge => '新';

  @override
  String get logExpensesInstantly => '通过聊天即时记账';

  @override
  String get fast => '快速';

  @override
  String get photo => '照片';

  @override
  String get autoSync => '自动同步';

  @override
  String get naturalLanguage => '自然语言';

  @override
  String get describeExpenseAutomatically => '描述您的支出，我们将自动为您记录。';

  @override
  String get snapReceipt => '拍下收据';

  @override
  String get snapReceiptDescription => '拍下收据，AI 将自动提取并记录。';

  @override
  String get previous => '上一步';

  @override
  String get next => '下一步';

  @override
  String get overview => '概览';

  @override
  String get activity => '活动';

  @override
  String get accountInformation => '账户信息';

  @override
  String get userId => '用户 ID';

  @override
  String get recentActivity => '最近活动';

  @override
  String get noActivityYet => '暂无活动';

  @override
  String get signOut => '退出登录';

  @override
  String get insights => '财务分析';

  @override
  String get runningTab => '实时';

  @override
  String get day30Tab => '30 天';

  @override
  String get longTermTab => '长期';

  @override
  String get scenarioTab => '模拟';

  @override
  String get runningAndDailyBalances => '实时与每日余额';

  @override
  String get budgetVsSpentDescription => '每日预算 vs 支出，以及累计实时余额。';

  @override
  String get runningBalanceLegend => '实时余额';

  @override
  String get budgetLegend => '预算';

  @override
  String get spentLegend => '支出';

  @override
  String get runningBalanceGuide => '实时余额指南';

  @override
  String get runningBalanceIntro => '您可以把这张图表当作您的私人理财教练。下面，我们就来看看如何读懂和使用它。';

  @override
  String get day30LookAhead => '未来 30 天预测';

  @override
  String get projectedFromTrailing30Days => '根据过去 30 天的平均数据预测。';

  @override
  String get projectedSpendingLegend => '预测支出';

  @override
  String get peek30DaysAhead => '预见未来 30 天';

  @override
  String get day30ForecastIntro => '此预测使用上个月的活动来推测下个月的大致情况。把它想象成您钱包的天气预报。';

  @override
  String get longTermProjection => '长期预测';

  @override
  String get basedOnHistoricalAverages => '基于历史平均数据；随您的数据自动更新。';

  @override
  String get month18ProjectionLegend => '18 个月预测';

  @override
  String get your18MonthHorizon => '您的 18 个月展望';

  @override
  String get longTermIntro => '此预测结合了您的消费习惯与适度的增长预期，帮您预见今天的选择将如何塑造未来。';

  @override
  String get aiScenarioPlanning => 'AI 情景规划';

  @override
  String get askAiFinancialAdvisor => '询问您的 AI 财务顾问，您是否能负担某项未来支出';

  @override
  String get canI => '我能否';

  @override
  String get before => '在...之前';

  @override
  String get beforePrefix => '在';

  @override
  String get beforeSuffix => '之前';

  @override
  String get pickDate => '选择日期';

  @override
  String get check => '查看';

  @override
  String get enterQuestionAndPickDate => '请输入问题并选择日期';

  @override
  String get analyzingScenario => '正在分析情景...';

  @override
  String get thisMightTakeAWhile => '这可能需要一些时间';

  @override
  String get whereTheMoneyWent => '钱花哪儿了';

  @override
  String get categoryTotalsForSelectedRange => '所选范围的分类总计。';

  @override
  String get scenarioCategoriesGuide => '理解分类';

  @override
  String get categoryGuideIntro => '把这张图表想象成每笔钱去向的鸟瞰图。无需计算器，教您如何读懂它。';

  @override
  String get readTheBarChartLikeAPro => '像专家一样阅读条形图';

  @override
  String get categoryChartDesc => '所选时期的分类明细。';

  @override
  String get whyThisViewIsHelpful => '此视图为何有用';

  @override
  String get categoryWhyHelpfulDesc => '快速识别您的最大支出类别，并发现随时间变化的趋势。';

  @override
  String get whatToDoWithTheInsight => '如何运用此洞察';

  @override
  String get categoryWhatToDoDesc => '利用这些信息来调整您的预算和消费习惯。';

  @override
  String get scenarioAnalysis => '情景分析';

  @override
  String get target => '目标';

  @override
  String get quickStats => '快速统计';

  @override
  String get currentBalance => '当前余额';

  @override
  String get projectedNoChange => '预测（无变化）';

  @override
  String get avgDailyNet => '日均净额';

  @override
  String get noDataAvailable => '暂无数据';

  @override
  String get day => '日';

  @override
  String get close => '关闭';

  @override
  String get done => '完成';

  @override
  String get whatYouAreSeeing => '您看到的是什么';

  @override
  String get whyItMatters => '为何重要';

  @override
  String get howToRespond => '如何应对';

  @override
  String get runningBalanceWhatYouSeeDesc => '您的实时余额追踪您每日支出后还剩多少“喘息空间”。每日条形图显示了您的计划支出与实际支出。';

  @override
  String get runningBalanceWhyMattersDesc => '把它当作一次友好的“脉搏检查”。它帮您注意到何时超前计划（以便继续投资），或何时需要“修正路线”以保持正轨。';

  @override
  String get runningBalanceHowToRespondDesc => '像教练一样使用图表。庆祝收益，必要时重设期望，并给自己一点宽容——关键在于稳步前进，而非完美无缺。';

  @override
  String get whatTheForecastShows => '预测显示了什么';

  @override
  String get day30WhatShowsDesc => '我们结合过去 30 天的收支来描绘未来一周的平均情况。它平滑了单次“大额消费”，让您看到通常的节奏。';

  @override
  String get day30WhyMattersDesc => '前瞻性预算助您保持主动。预见未来几天有大笔支出，能让您提前预留现金，而不是事后手忙脚乱。';

  @override
  String get day30HowToPlaySmartDesc => '把它当作一个友好的提醒，而不是一本严格的规则手册。用一些您认为可行的小调整来修正您的计划。';

  @override
  String get howTheProjectionWorks => '预测如何运作';

  @override
  String get longTermHowWorksDesc => '我们推算您未来的平均收支，并加入适度的增长假设，以便您查看您的计划是否能在未来数月保持充裕的现金。';

  @override
  String get longTermWhyMattersDesc => '长远规划让梦想成真。看看您的应急基金、投资或大额采购是否仍在正轨上。';

  @override
  String get longTermMovesToConsiderDesc => '使用图表来“排练”未来的决策。今天的小调整将复合成未来的大胜利。';

  @override
  String get forMe => '个人';

  @override
  String get forUs => '家庭';

  @override
  String get home => '首页';

  @override
  String get reminder => '提醒';

  @override
  String get analyzingReceipt => '正在分析收据...';

  @override
  String get analyzingExpense => '正在分析支出...';

  @override
  String get noExpenseInformationExtracted => '未能提取到支出信息';

  @override
  String get failedToAnalyzeNoData => '分析失败：未返回数据';

  @override
  String get failedToAnalyze => '分析失败';

  @override
  String get updateBudget => '更新预算';

  @override
  String get enterNewTotalDailyBudget => '请输入新的每日总预算。';

  @override
  String get budgetAmount => '预算金额';

  @override
  String get save => '保存';

  @override
  String get enterValidAmountGreaterThan0 => '请输入大于 0 的有效金额';

  @override
  String get updatingBudget => '正在更新预算...';

  @override
  String get budgetUpdated => '预算已更新';

  @override
  String get failedToUpdateBudget => '预算更新失败';

  @override
  String get loggedSuccessfully => '记录成功';

  @override
  String get view => '查看';

  @override
  String get retry => '重试';

  @override
  String get failedToCapturePhoto => '照片拍摄失败';

  @override
  String get noSpendingData => '暂无支出数据';

  @override
  String get byCategory => '按分类';

  @override
  String get noExpensesYet => '暂无支出';

  @override
  String get startLoggingExpensesToSeeCategories => '开始记账以查看分类';

  @override
  String get selectDateRange => '选择日期范围';

  @override
  String get addExpense => '记一笔';

  @override
  String get describeYourExpense => '描述您的支出（例如：“汉堡 5 元，咖啡 3 元”）';

  @override
  String get enterExpenseDetails => '输入支出详情...';

  @override
  String get freeFormText => '自由文本';

  @override
  String get takePhoto => '拍照';

  @override
  String get transactions => '交易记录';

  @override
  String get negative => '负';

  @override
  String get positive => '正';

  @override
  String get spendingBreakdown => '支出明细';

  @override
  String get spent => '支出';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get thisWeek => '本周';

  @override
  String get lastWeek => '上周';

  @override
  String get thisMonth => '本月';

  @override
  String get last30Days => '过去 30 天';

  @override
  String get customRange => '自定义范围';

  @override
  String get spentToday => '您的今日支出';

  @override
  String get spentYesterday => '您的昨日支出';

  @override
  String get spentThisWeek => '您的本周支出';

  @override
  String get spentLastWeek => '您的上周支出';

  @override
  String get spentThisMonth => '您的本月支出';

  @override
  String get spentLast30Days => '您的支出（过去 30 天）';

  @override
  String get spentCustom => '支出（自定义）';

  @override
  String get todaysBudget => '今日预算';

  @override
  String get yesterdaysBudget => '昨日预算';

  @override
  String get sumOfDailyBudgetsThisWeek => '本周每日预算总和';

  @override
  String get sumOfDailyBudgetsLastWeek => '上周每日预算总和';

  @override
  String get sumOfDailyBudgetsThisMonth => '本月每日预算总和';

  @override
  String get sumOfDailyBudgetsLast30Days => '过去 30 天每日预算总和';

  @override
  String get sumOfDailyBudgetsForSelectedRange => '所选范围每日预算总和';

  @override
  String get netCashflowToday => '今日净现金流';

  @override
  String get netCashflowYesterday => '昨日净现金流';

  @override
  String get netCashflowThisWeek => '本周净现金流';

  @override
  String get netCashflowLastWeek => '上周净现金流';

  @override
  String get netCashflowThisMonth => '本月净现金流';

  @override
  String get netCashflowLast30Days => '净现金流（过去 30 天）';

  @override
  String get netCashflowCustom => '净现金流（自定义）';

  @override
  String get selectCurrency => '选择货币';

  @override
  String get showLessCurrencies => '收起';

  @override
  String showAllCurrencies(int count) {
    return '展开全部 $count 种货币';
  }

  @override
  String get budget => '预算';

  @override
  String get spentLabel => '支出';

  @override
  String get net => '净额';

  @override
  String get txn => '笔';

  @override
  String get txns => '笔';

  @override
  String get pleaseEnterExpenseDetails => '请输入支出详情';

  @override
  String get userNotLoggedIn => '用户未登录';

  @override
  String get errorLoadingHouseholds => '家庭加载失败';

  @override
  String get welcomeToHouseholds => '欢迎使用「家庭」功能';

  @override
  String get householdsDescription => '与您的家人、伴侣或室友共同管理财务。一起跟踪预算、分摊支出，并共同规划财务。';

  @override
  String get createHousehold => '创建家庭';

  @override
  String get joinWithInvite => '使用邀请加入';

  @override
  String get pleaseUseInvitationLink => '请使用邀请链接加入家庭';

  @override
  String get householdName => '家庭名称';

  @override
  String get householdNameHint => '例如：幸福一家人';

  @override
  String get pleaseEnterHouseholdName => '请输入家庭名称';

  @override
  String get errorCreatingHousehold => '创建家庭失败';

  @override
  String get householdsFeature => '“家庭”功能';

  @override
  String get householdsFeatureDescription => '“家庭”功能现已推出！与家人、伴侣或室友共同管理财务。';

  @override
  String get gotIt => '知道了';

  @override
  String get confirmExpense => '确认支出';

  @override
  String get expenseDetails => '支出详情';

  @override
  String get details => '详情';

  @override
  String get category => '类别';

  @override
  String get currency => '货币';

  @override
  String get date => '日期';

  @override
  String get time => '时间';

  @override
  String get notes => '备注';

  @override
  String get receipt => '收据';

  @override
  String get saveExpense => '保存支出';

  @override
  String get shareWithHousehold => '与家庭分享';

  @override
  String get loadingHouseholdMembers => '正在加载家庭成员...';

  @override
  String get selectHouseholdToConfigureSplit => '选择一个家庭以配置分摊';

  @override
  String get currencyManagedByHousehold => '家庭货币统一设置，无法在此更改';

  @override
  String get currencyCannotBeChanged => '分享至家庭时无法更改货币';

  @override
  String get failedToLoadImage => '图片加载失败';

  @override
  String get editAmount => '编辑金额';

  @override
  String get amount => '金额';

  @override
  String get editNotes => '编辑备注';

  @override
  String get addANote => '添加备注...';

  @override
  String get noMembersFoundInHousehold => '未找到家庭成员';

  @override
  String get errorLoadingMembers => '成员加载失败';

  @override
  String get noExpenseToSave => '没有要保存的支出';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return '支出已保存并分享$splitInfo！';
  }

  @override
  String get expenseSaved => '支出已保存！';

  @override
  String failedToSave(String error) {
    return '保存失败：$error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return '货币偏好同步失败：$error';
  }

  @override
  String get currencyUpdatedSuccessfully => '货币更新成功';

  @override
  String retryFailed(Object error) {
    return '重试失败：$error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return '我在 $category 上花了 $currencySymbol$amount';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => '请输入新的每日总预算。';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => '请登录以使用家庭功能';

  @override
  String get quickActions => '快捷操作';

  @override
  String get members => '成员';

  @override
  String get invites => '邀请';

  @override
  String get errorLoadingExpenses => '支出加载失败';

  @override
  String get budgets => '预算';

  @override
  String get loadingHousehold => '正在加载家庭信息...';

  @override
  String get remaining => '剩余';

  @override
  String get overBudget => '超出預算';

  @override
  String get sharedBudgets => '共享预算';

  @override
  String get netPosition => '净差额';

  @override
  String get spentByHousehold => '家庭支出';

  @override
  String get memberSpending => '成员支出';

  @override
  String get spentByHouseholdTooltip => '显示所选期间内所有家庭成员的总支出金额。包括家庭任何成员记录的所有共享支出。';

  @override
  String get manageMoneyTogether => '在同一共享空间中，与您的伴侣、家人或室友共同管理财务。';

  @override
  String get sharedBudgetsExpenses => '共享预算与支出';

  @override
  String get sharedBudgetsExpensesDesc => '设置预算、跟踪支出，实时查看您家庭的资金流向。';

  @override
  String get smartExpenseSplitting => '智能分摊支出';

  @override
  String get smartExpenseSplittingDesc => '通过灵活的分摊选项（均摊、按百分比或自定义金额）自动计算谁欠谁。';

  @override
  String get stayInSync => '保持同步';

  @override
  String get stayInSyncDesc => '当添加支出、达到预算或需要结算分摊时收到通知。';

  @override
  String get householdSettings => '家庭设置';

  @override
  String get householdNotFound => '未找到家庭';

  @override
  String get coverPhoto => '封面照片';

  @override
  String get changeCoverPhoto => '更换封面';

  @override
  String get saveChanges => '保存更改';

  @override
  String get errorLoadingHousehold => '家庭信息加载失败';

  @override
  String get householdUpdatedSuccessfully => '家庭信息更新成功';

  @override
  String get failedToUpdateHousehold => '家庭信息更新失败';

  @override
  String get inviteMember => '邀请成员';

  @override
  String get removeMember => '移除成员';

  @override
  String get remove => '移除';

  @override
  String get confirmRemoveMember => '您确定要移除';

  @override
  String get updatedMemberRole => '已更新成员角色';

  @override
  String get unknown => '未知';

  @override
  String get makeAdmin => '设为管理员';

  @override
  String get makeMember => '设为成员';

  @override
  String get invitations => '邀请';

  @override
  String get errorLoadingInvites => '邀请加载失败';

  @override
  String get createInvitation => '创建邀请';

  @override
  String get pendingInvitations => '待处理的邀请';

  @override
  String get noPendingInvitations => '暂无待处理的邀请';

  @override
  String get invitationHistory => '邀请历史';

  @override
  String get noInvitationHistory => '暂无邀请历史';

  @override
  String get emailOptional => '邮箱（可选）';

  @override
  String get friendEmailExample => 'friend@example.com';

  @override
  String get personalMessageOptional => '个性化消息（可选）';

  @override
  String get joinHouseholdBudget => '加入我们的家庭预算吧！';

  @override
  String get expiresIn => '有效期至';

  @override
  String get oneDay => '1 天';

  @override
  String get threeDays => '3 天';

  @override
  String get sevenDays => '7 天';

  @override
  String get fourteenDays => '14 天';

  @override
  String get thirtyDays => '30 天';

  @override
  String get unlimited => '无限制';

  @override
  String get create => '创建';

  @override
  String get invitationCreatedSuccessfully => '邀请创建成功';

  @override
  String get inviteLinkCopiedToClipboard => '邀请链接已复制到剪贴板！';

  @override
  String get errorCreatingInvite => '创建邀请失败';

  @override
  String get revokeInvitation => '撤销邀请';

  @override
  String get confirmRevokeInvitation => '您确定要撤销此邀请吗？';

  @override
  String get revoke => '撤销';

  @override
  String get invitationRevoked => '邀请已撤销';

  @override
  String get errorRevokingInvite => '撤销邀请失败';

  @override
  String get anyoneWithLink => '任何持有链接的人';

  @override
  String get noExpiry => '永不过期';

  @override
  String get expired => '已过期';

  @override
  String get expires => '过期时间';

  @override
  String get copyLink => '复制链接';

  @override
  String get selectCoverImage => '选择封面图片';

  @override
  String get failedToLoadImages => '图片加载失败';

  @override
  String get chooseFromGallery => '从相册选择';

  @override
  String get failedToLoad => '加载失败';

  @override
  String get imageTooLarge => '图片过大';

  @override
  String get maxIs => '最大为';

  @override
  String get unsupportedFileFormat => '不支持的文件格式。请使用 JPG、PNG 或 WebP。';

  @override
  String get cropCoverImage => '裁剪封面图片';

  @override
  String get editBudget => '编辑预算';

  @override
  String get budgetDetails => '预算详情';

  @override
  String get budgetName => '预算名称';

  @override
  String get period => '周期';

  @override
  String get alertThresholds => '提醒阈值';

  @override
  String get warningThreshold => '警告阈值 (%)';

  @override
  String get alertThreshold => '警报阈值 (%)';

  @override
  String get warningThresholdHelper => '当预算使用达到此百分比时提醒';

  @override
  String get alertThresholdHelper => '达到此百分比时发送严重警报';

  @override
  String get budgetStatus => '预算状态';

  @override
  String get active => '活跃';

  @override
  String get inactive => '停用';

  @override
  String get deletingBudget => '正在删除预算...';

  @override
  String get savingChanges => '正在保存更改...';

  @override
  String get budgetNameCannotBeEmpty => '预算名称不能为空';

  @override
  String get pleaseEnterValidAmount => '请输入有效金额';

  @override
  String get warningThresholdRange => '警告阈值必须在 0 到 100 之间';

  @override
  String get alertThresholdRange => '警报阈值必须在 0 到 100 之间';

  @override
  String get warningThresholdLessThanAlert => '警告阈值必须小于或等于警报阈值';

  @override
  String get deleteBudget => '删除预算';

  @override
  String get confirmDeleteBudget => '您确定要删除';

  @override
  String get thisActionCannotBeUndone => '此操作无法撤销';

  @override
  String get budgetUpdatedSuccessfully => '预算更新成功';

  @override
  String get budgetDeletedSuccessfully => '预算删除成功';

  @override
  String get categoryTransfers => '转账';

  @override
  String get categoryShopping => '购物';

  @override
  String get categoryUtilities => '水电煤';

  @override
  String get categoryEntertainment => '娱乐';

  @override
  String get categoryEntertainmentSubscriptions => '娱乐订阅';

  @override
  String get categoryRestaurants => '餐饮';

  @override
  String get categoryFood => '食物';

  @override
  String get categoryGroceries => '买菜';

  @override
  String get categoryTransport => '交通';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categoryTravel => '旅行';

  @override
  String get categoryFlights => '机票';

  @override
  String get categoryVacation => '度假';

  @override
  String get categoryHealth => '健康';

  @override
  String get categoryMedical => '医疗';

  @override
  String get categoryText => '文本';

  @override
  String get categoryEducation => '教育';

  @override
  String get categoryTuition => '学费';

  @override
  String get categorySubscriptions => '订阅';

  @override
  String get categoryServices => '服务';

  @override
  String get categoryHousing => '住房';

  @override
  String get categoryRent => '房租';

  @override
  String get categoryMortgage => '房贷';

  @override
  String get categoryBills => '账单';

  @override
  String get categoryInsurance => '保险';

  @override
  String get categorySavings => '储蓄';

  @override
  String get categoryInvestment => '投资';

  @override
  String get categoryInvestments => '投资';

  @override
  String get categoryIncome => '收入';

  @override
  String get categorySalary => '工资';

  @override
  String get categoryBonus => '奖金';

  @override
  String get categoryPets => '宠物';

  @override
  String get categoryKids => '孩子';

  @override
  String get categoryFamily => '家庭';

  @override
  String get categoryGifts => '礼物';

  @override
  String get categoryCharity => '慈善';

  @override
  String get categoryFees => '费用';

  @override
  String get categoryLoan => '贷款';

  @override
  String get categoryLoans => '贷款';

  @override
  String get categoryDebt => '债务';

  @override
  String get categoryPersonalCare => '个人护理';

  @override
  String get categoryBeauty => '美容';

  @override
  String get categoryMisc => '其他';

  @override
  String get categoryUncategorized => '未分类';

  @override
  String get deleteBudgetCannotBeUndone => '此操作无法撤销';

  @override
  String get delete => '删除';

  @override
  String get failedToDeleteBudget => '预算删除失败';

  @override
  String get owner => '所有者';

  @override
  String get admin => '管理员';

  @override
  String get member => '成员';

  @override
  String get pending => '待处理';

  @override
  String get accepted => '已接受';

  @override
  String get revoked => '已撤销';

  @override
  String get tapToChangeCover => '点击更换封面';

  @override
  String get personalMessageHint => '给被邀请人留句话（例如：“加入我们的家庭预算吧！”）';

  @override
  String get invitationExpiresIn => '邀请有效期';

  @override
  String daysCount(int days) {
    return '$days 天';
  }

  @override
  String get createHouseholdDescription => '创建一个共享空间，与家人或室友一起跟踪预算和支出。';

  @override
  String get uploadingImage => '正在上传图片...';

  @override
  String get creating => '正在创建...';

  @override
  String get generatingInvite => '正在生成邀请...';

  @override
  String get pleaseSelectValidCurrency => '请选择有效的家庭货币';

  @override
  String nameMaxLength(int max) {
    return '名称必须少于 $max 个字符';
  }

  @override
  String get createHouseholdPage => '创建家庭页面';

  @override
  String get invitationPersonalMessageInput => '邀请消息输入框';

  @override
  String get householdNameInput => '家庭名称输入框';

  @override
  String get invitationExpirationSelector => '邀请有效期选择器';

  @override
  String get unlimitedExpiration => '无限期';

  @override
  String daysExpiration(int days) {
    return '$days 天有效期';
  }

  @override
  String get householdInformation => '家庭信息';

  @override
  String get creatingHousehold => '正在创建家庭';

  @override
  String get createHouseholdButton => '创建家庭按钮';

  @override
  String get searchExpenses => '搜索支出...';

  @override
  String get clearAll => '全部清除';

  @override
  String get allCategories => '全部';

  @override
  String get allMembers => '所有成员';

  @override
  String get balanceSummary => '结算总览';

  @override
  String get youAreOwed => '他人欠您';

  @override
  String get youOwe => '您欠他人';

  @override
  String get youOweOthers => '您欠他人';

  @override
  String get othersOweYou => '他人欠您';

  @override
  String get viewDetails => '查看详情';

  @override
  String get settleUp => '结算';

  @override
  String get markExpensesAsSettled => '将支出标记为已结算以更新余额';

  @override
  String get whoAreYouSettlingWith => '您在和谁结算？';

  @override
  String get selectMember => '选择成员';

  @override
  String get amountToSettle => '结算金额';

  @override
  String get howDidYouSettle => '您是如何结算的？';

  @override
  String get cash => '现金';

  @override
  String get paidInCash => '以现金支付';

  @override
  String get bankTransfer => '银行转账';

  @override
  String get transferredViaBank => '通过银行转账';

  @override
  String get mobilePayment => '移动支付';

  @override
  String get venmoPaypalEtc => '微信、支付宝等';

  @override
  String get search => '搜索';

  @override
  String get noData => '暂无数据';

  @override
  String get filterTransactions => '筛选交易';

  @override
  String get noTransactionsFound => '未找到交易记录';

  @override
  String get failedToLoadHouseholdTransactions => '家庭交易记录加载失败';

  @override
  String get reset => '重置';

  @override
  String get apply => '应用';

  @override
  String get expenses => '支出';

  @override
  String get dateRange => '日期范围';

  @override
  String get noMatchingExpenses => '无匹配支出';

  @override
  String get startLoggingExpenses => '开始记账，支出将显示在此处';

  @override
  String get tryAdjustingFilters => '尝试调整您的筛选条件';

  @override
  String get split => '分摊';

  @override
  String get note => '备注';

  @override
  String get currencyCannotBeChangedWhenSharing => '分享至家庭时无法更改货币';

  @override
  String get createBudget => '创建预算';

  @override
  String get pleaseEnterABudgetName => '请输入预算名称';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => '请输入一个大于 0 的有效金额';

  @override
  String get warningThresholdMustBeBetween0And100 => '警告阈值必须在 0 到 100% 之间';

  @override
  String get alertThresholdMustBeBetween0And100 => '警报阈值必须在 0 到 100% 之间';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => '警告阈值必须小于或等于警报阈值';

  @override
  String get budgetCreatedSuccessfully => '预算创建成功！';

  @override
  String get failedToCreateBudget => '预算创建失败';

  @override
  String get groceriesRentEntertainment => '例如：买菜、房租、娱乐';

  @override
  String get budgetType => '预算类型';

  @override
  String get sharedWithAllHouseholdMembers => '与所有家庭成员共享';

  @override
  String get personalBudgetForYourExpensesOnly => '仅用于您个人支出的预算';

  @override
  String get countSplitPortionOnly => '仅计算分摊部分';

  @override
  String get onlyCountYourPortionOfSplitExpenses => '仅将您在分摊支出中承担的部分计入此预算';

  @override
  String get joinHousehold => '加入家庭';

  @override
  String get joinAHousehold => '加入一个家庭';

  @override
  String get enterYourInvitationLinkToJoin => '输入您的邀请链接以加入\n共享的财务空间';

  @override
  String get pasteTheInvitationLinkYouReceived => '粘贴您从家庭成员收到的邀请链接';

  @override
  String get pasteInvitationLink => '粘贴邀请链接';

  @override
  String get pleaseEnterAnInvitationLink => '请输入邀请链接';

  @override
  String get pleaseEnterAValidInvitationLink => '请输入有效的邀请链接';

  @override
  String get paste => '粘贴';

  @override
  String get validating => '验证中...';

  @override
  String get continueAction => '继续';

  @override
  String get welcomeAboard => '欢迎加入！';

  @override
  String get youreNowPartOfTheHousehold => '您现在是家庭的一员了。\n开始共同管理您的财务吧！';

  @override
  String get thisWillOnlyTakeAMoment => '只需片刻';

  @override
  String get unableToJoin => '无法加入';

  @override
  String get tryAgain => '重试';

  @override
  String get goToHousehold => '前往家庭';

  @override
  String get expiresSoon => '即将过期';

  @override
  String invitationValidUntil(String formattedDate) {
    return '邀请有效期至 $formattedDate';
  }

  @override
  String get whatYoullGet => '您将获得';

  @override
  String get viewSharedBudgetsAndExpenses => '查看共享预算和支出';

  @override
  String get trackHouseholdFinancialHealth => '跟踪家庭财务健康状况';

  @override
  String get collaborateOnFinancialDecisions => '共同制定财务决策';

  @override
  String get household => '家庭';

  @override
  String get viewAll => '查看全部';

  @override
  String get manage => '管理';

  @override
  String get noBudgetsYet => '暂无预算';

  @override
  String get createSharedBudgetDescription => '创建一个共享预算以共同跟踪支出';

  @override
  String get errorLoadingBudgets => '预算加载失败';

  @override
  String get recentSplits => '最近的分摊';

  @override
  String get invite => '邀请';

  @override
  String get last6Months => '过去 6 个月';

  @override
  String get thisYear => '今年';

  @override
  String get allTime => '全部时间';

  @override
  String nameMinLength(int min) {
    return '名称必须至少为 $min 个字符';
  }

  @override
  String get splitExpense => '分摊支出';

  @override
  String get percent => '百分比';

  @override
  String get splitShare => '份额';

  @override
  String get owes => '欠款';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return '分摊金额总和必须等于 $currency$amount';
  }

  @override
  String get percentagesMustTotal100 => '百分比总和必须为 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => '每人必须至少占 1 份';

  @override
  String get whatsappVerified => 'WhatsApp 验证成功';

  @override
  String get whatsappVerification => 'WhatsApp 验证';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => '您的 WhatsApp 号码已成功绑定到您的账户';

  @override
  String get verifyingYourWhatsAppNumber => '正在验证您的 WhatsApp 号码...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => '请输入来自 WhatsApp 的 6 位验证码';

  @override
  String get pleaseEnterThe6DigitVerificationCode => '请输入 6 位验证码';

  @override
  String get failedToVerifyCode => '验证码验证失败';

  @override
  String get failedToVerifyCodePleaseTryAgain => '验证失败。请重试。';

  @override
  String get codeAutoFilledFromVerificationLink => '已从验证链接自动填充验证码';

  @override
  String get verify => '验证';

  @override
  String get verifying => '验证中...';

  @override
  String get avatarStudio => '头像编辑器';

  @override
  String get preview => '预览';

  @override
  String get colors => '颜色';

  @override
  String get randomize => '随机';

  @override
  String get saveAvatar => '保存头像';

  @override
  String get saving => '保存中...';

  @override
  String get skipForNow => '暂时跳过';

  @override
  String get selectColor => '选择颜色';

  @override
  String get failedToSaveAvatar => '头像保存失败';

  @override
  String get hair => '头发';

  @override
  String get eyes => '眼睛';

  @override
  String get mouth => '嘴巴';

  @override
  String get background => '背景';

  @override
  String get face => '脸型';

  @override
  String get ears => '耳朵';

  @override
  String get shirts => '衣服';

  @override
  String get brow => '眉毛';

  @override
  String get nose => '鼻子';

  @override
  String get blush => '腮红';

  @override
  String get accessories => '配饰';

  @override
  String get stars => '星星';

  @override
  String get currencyIsManagedByHousehold => '家庭货币统一设置，无法在此更改';

  @override
  String get buyALaptop => '购买一台 8000 元的笔记本电脑';

  @override
  String get selectTargetDate => '选择目标日期';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return '我可以在 $date 前 $action 吗';
  }

  @override
  String get scenarioDateFormat => 'yyyy/MM/dd';

  @override
  String analysisFailed(String error) {
    return '分析失败：$error';
  }

  @override
  String get leftHandChamps => '左边的“大头”是您的主要支出项——非常适合快速审查。';

  @override
  String get smallButFrequent => '小额但频繁的类别暗示着可能随时间“悄悄”养成的习惯。';

  @override
  String get colorMatches => '颜色与您在“首页”看到的相匹配，让您的大脑保持舒适。';

  @override
  String get planningNewGoal => '正在规划新目标？找出可以削减的类别，而不影响“乐趣”支出。';

  @override
  String get eyeingTreatYourself => '想“犒劳”一下自己一个月？看看哪些领域可以安全地“伸缩”。';

  @override
  String get doubleCheckTagging => '用它来复查新支出是否被正确标记——不允许“幽灵支出”。';

  @override
  String get slideHighBar => '通过设置小额限制或切换到低成本替代品，将高额支出“拉低”一格。';

  @override
  String get nonNegotiable => '如果某项支出是不可协商的（比如房租），那就围绕它制定计划，而不是对抗它。';

  @override
  String get revisitAfterScenario => '运行情景分析后重新审视，看看您的调整是否有效。';

  @override
  String get purpleLineCushion => '紫线：每天剩下的“缓冲垫”。上升的线条意味着您正在积累势头。';

  @override
  String get blueBarsBudget => '蓝条：您当天设定的预算。';

  @override
  String get redBarsSpent => '红条：实际从您账户中支出的。';

  @override
  String get lineTrendingUpward => '线条上升 = 您可以将额外的现金转用于储蓄目标。';

  @override
  String get flatDippingLine => '线条平坦或下降 = 是时候暂停并审查大额项目了。';

  @override
  String get sharpDrops => '急剧下降通常对应计划外采购——点击它们以查看详情。';

  @override
  String get lineRisingDays => '线条连续几天上升？考虑将一点额外的钱转入储蓄或偿还债务。';

  @override
  String get lineDippingWeekend => '忙碌的周末后线条下降？通过削减小的非必要开支来重新平衡未来几天的收支。';

  @override
  String get feelStuckRed => '感觉“陷入赤字”？返回“首页”重新审视您的预算——小的调整会迅速累积。';

  @override
  String get thirtyDayForecastDesc => '此预测使用上个月的活动来推测下个月的大致情况。把它想象成您钱包的天气预报。';

  @override
  String get greenLineExpected => '绿线 = 如果下个月的情况与上个月相似，预计的每日支出。';

  @override
  String get spikesHighlight => '尖峰突显了您的习惯通常“更昂贵”的几周（比如周五的外卖）。';

  @override
  String get forecastUpdates => '当您记录新交易时，预测会自动更新——无需刷新。';

  @override
  String get spotExpensivePatterns => '及早发现“昂贵”的模式，并在它们到来之前储备一个小型缓冲。';

  @override
  String get catchQuieterWeeks => '抓住“平静”的几周，您可以将额外的现金转入储蓄或偿还债务。';

  @override
  String get timeRecurringPayments => '利用此洞察来安排定期付款、订阅或充值的时间。';

  @override
  String get bigSpikeComing => '即将迎来大笔支出？提前预订更便宜的选项，或将灵活支出调整到“平静”的日子。';

  @override
  String get forecastDipping => '预测下降？安排一次额外的储蓄转账来奖励自己。';

  @override
  String get forecastLooksOff => '如果预测看起来不对劲，请在“首页”查看分类，整理任何错误的标签。';

  @override
  String get greenLineTrends => '绿线随您的典型储蓄率变化——向上的势头意味着您的目标资金充足。';

  @override
  String get lineDipsSignals => '如果线条下降，它预示着未来几个月支出可能超过收入。';

  @override
  String get largeGoalsDebts => '当您在“首页”标记它们时，大额目标或债务会包含在内。';

  @override
  String get upwardSlope => '向上的斜率？庆祝一下，并考虑增加退休或旅行储蓄。';

  @override
  String get flatSlipping => '平坦或下滑？是时候在“滚雪球”之前调整预算或增加收入来源了。';

  @override
  String get watchSeasonalTrends => '注意季节性趋势——假期、学期或年度续费通常会首先在这里显现。';

  @override
  String get schedulePaymentIncreases => '当曲线“上升”时，安排温和地增加贷款还款额。';

  @override
  String get planAheadDips => '通过指定“偿债基金”或削减可选支出来为“下降”提前计划。';

  @override
  String get checkProjectionMonthly => '每月检查一次预测，让您的长期规划保持乐趣和灵活性。';

  @override
  String get categoryHealthcare => '医疗健康';

  @override
  String get categoryOther => '其他';

  @override
  String get deleteExpense => '删除支出';

  @override
  String get confirmDeleteExpense => '您确定要删除这笔支出吗？此操作无法撤销。';

  @override
  String get expenseDeletedSuccessfully => '支出删除成功';

  @override
  String get failedToDeleteExpense => '支出删除失败';

  @override
  String get expenseNotFoundOrDeleted => '支出未找到或已被删除';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => '只有管理员和所有者可以编辑家庭设置';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => '只有管理员和所有者可以创建邀请';

  @override
  String shareInvitationForHousehold(String householdName) {
    return '分享家庭 $householdName 的邀请';
  }

  @override
  String get shareInvitation => '分享邀请';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return '家庭 $householdName 创建成功';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return '家庭 \"$householdName\" 创建成功！';
  }

  @override
  String get invitationLink => '邀请链接';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return '邀请链接：$inviteUrl';
  }

  @override
  String get copyInvitationLink => '复制邀请链接';

  @override
  String get copyInvitationLinkToClipboard => '复制邀请链接到剪贴板';

  @override
  String get shareInvitationLink => '分享邀请链接';

  @override
  String get share => '分享';

  @override
  String get closeShareSheet => '关闭分享面板';

  @override
  String get invitationLinkCopiedToClipboard => '邀请链接已复制到剪贴板！';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return '来 Moneko 加入我的家庭 \"$householdName\" 吧！\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => '来 Moneko 加入我的家庭吧';

  @override
  String get zeroAmount => '0.00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => '通知设置';

  @override
  String get budgetBoop => '预算戳一下';

  @override
  String get getGentleReminder => '达到此阈值时收到温和提醒';

  @override
  String get purrSuasiveNudge => '咕噜式提醒';

  @override
  String get getStrongerNudge => '达到此阈值时收到更强推动';

  @override
  String get createBudgetButton => '创建预算';

  @override
  String get daily => '每日';

  @override
  String get weekly => '每周';

  @override
  String get monthly => '每月';

  @override
  String get yearly => '每年';

  @override
  String get householdBudgetType => '家庭预算';

  @override
  String get personalBudgetType => '个人预算';

  @override
  String joinHouseholdName(String householdName) {
    return '加入 \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return '家庭预览：$householdName，邀请者：$inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return '邀请者：$inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return '邀请即将于 $formattedDate 过期';
  }

  @override
  String get invitationValidUntilLabel => '邀请有效期至';

  @override
  String get personalMessageFromInviter => '邀请者的个人消息';

  @override
  String get messageFromInviter => '来自邀请者的消息';

  @override
  String get joiningHousehold => '正在加入家庭...';

  @override
  String errorWithMessage(String errorMessage) {
    return '错误：$errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => '发生了意外错误';

  @override
  String get invalidInvitationLinkFormat => '无效的邀请链接格式';

  @override
  String get invalidOrExpiredInvitation => '无效或已过期的邀请';

  @override
  String get tomorrow => '明天';

  @override
  String inDays(int days) {
    return '$days 天后';
  }

  @override
  String get january => '1月';

  @override
  String get february => '2月';

  @override
  String get march => '3月';

  @override
  String get april => '4月';

  @override
  String get may => '5月';

  @override
  String get june => '6月';

  @override
  String get july => '7月';

  @override
  String get august => '8月';

  @override
  String get september => '9月';

  @override
  String get october => '10月';

  @override
  String get november => '11月';

  @override
  String get december => '12月';

  @override
  String remindUser(String name) {
    return '提醒 $name';
  }

  @override
  String get sendFriendlySpendingReminder => '发送一条友好的消费提醒';

  @override
  String get addMessageOptional => '添加留言（可选）';

  @override
  String get messageHintExample => '例如：“你的钱包也需要休息！”';

  @override
  String get sendReminder => '发送提醒';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return '请等待 24 小时后再向 $name 发送提醒';
  }

  @override
  String reminderSentToName(String name) {
    return '已向 $name 发送提醒 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => '提醒发送失败，请重试。';

  @override
  String get income => '收入';

  @override
  String get addIncome => '添加收入';

  @override
  String get incomeAdded => '收入添加成功';

  @override
  String get noIncome => '暂无收入';

  @override
  String get noIncomeDescription => '记录您的收入以跟踪家庭的财务健康状况';

  @override
  String get totalIncome => '总收入';

  @override
  String get monthToDate => '本月至今';

  @override
  String get yearToDate => '本年至今';

  @override
  String get failedToLoadIncome => '加载收入失败';

  @override
  String get incomeAcknowledged => '收入已确认';

  @override
  String get acknowledge => '确认';

  @override
  String get acknowledged => '已确认';

  @override
  String get source => '来源';

  @override
  String get sourceHint => '例如：雇主、客户';

  @override
  String get me => '我';

  @override
  String get partner => '伴侣';

  @override
  String get privacyScope => '隐私';

  @override
  String get privacyFull => '完整详情';

  @override
  String get privacyBalancesOnly => '仅余额';

  @override
  String get privacyPrivate => '私密';

  @override
  String get privacyFullExplanation => '伴侣可以看到所有详细信息，包括金额、来源和描述。';

  @override
  String get privacyBalancesOnlyExplanation => '伴侣可以在总额中看到此收入，但无法看到详细信息（来源、描述隐藏）。';

  @override
  String get privacyPrivateExplanation => '只有您可以看到此收入。它有助于家庭总额，但伴侣无法看到详细信息。';

  @override
  String get incomeSalary => '工资';

  @override
  String get incomeFreelance => '自由职业';

  @override
  String get incomeInvestment => '投资';

  @override
  String get incomeRefund => '退款';

  @override
  String get incomeGift => '礼金';

  @override
  String get incomeBonus => '奖金';

  @override
  String get incomeRental => '租金';

  @override
  String get incomeOther => '其他';

  @override
  String get goals => '目标';

  @override
  String get createGoal => '创建目标';

  @override
  String get goalCreated => '目标创建成功';

  @override
  String get goalTitle => '目标标题';

  @override
  String get enterGoalTitle => '输入目标标题';

  @override
  String get pleaseEnterTitle => '请输入标题';

  @override
  String get pleaseEnterAmount => '请输入金额';

  @override
  String get invalidAmount => '请输入大于0的有效金额';

  @override
  String get targetAmount => '目标金额';

  @override
  String get currentAmount => '当前金额';

  @override
  String get targetDate => '目标日期';

  @override
  String get description => '描述';

  @override
  String get descriptionHint => '备注（可选）';

  @override
  String get savings => '储蓄';

  @override
  String get paydown => '还款';

  @override
  String get all => '全部';

  @override
  String get completed => '已完成';

  @override
  String get offTrack => '进度落后';

  @override
  String get onTrack => '进度正常';

  @override
  String get complete => '完成';

  @override
  String get overallProgress => '整体进度';

  @override
  String get totalGoals => '总目标数';

  @override
  String get noGoals => '还没有目标。创建您的第一个目标开始吧！';

  @override
  String get noSavingsGoals => '还没有储蓄目标。创建一个开始储蓄吧！';

  @override
  String get noPaydownGoals => '还没有还款目标。创建一个开始减少债务吧！';

  @override
  String get goalAcknowledged => '目标已确认';

  @override
  String get balancesOnly => '仅余额';

  @override
  String get contribution => '存入';

  @override
  String get withdrawal => '提款';

  @override
  String get interest => '利息';

  @override
  String get adjustment => '调整';

  @override
  String get addContribution => '添加存入';

  @override
  String get contributionAmount => '存入金额';

  @override
  String get contributionType => '类型';

  @override
  String get contributionAdded => '已成功添加存入';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw(): super('zh_TW');

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => '尚無支出';

  @override
  String get loginWelcomeBack => '歡迎回來';

  @override
  String get orContinueWithEmail => '或使用 Email 繼續';

  @override
  String get emailAddress => '電子信箱';

  @override
  String get password => '密碼';

  @override
  String get forgotPassword => '忘記密碼？';

  @override
  String get signIn => '登入';

  @override
  String get newToMoneko => '還不是 Moneko 會員？';

  @override
  String get createAccount => '註冊帳號';

  @override
  String get resetYourPassword => '重設您的密碼';

  @override
  String get email => 'Email';

  @override
  String get exampleEmail => 'you@example.com';

  @override
  String get cancel => '取消';

  @override
  String get sendResetLink => '傳送重設連結';

  @override
  String get passwordResetEmailSent => '密碼重設 Email 已寄出，請檢查您的收件匣。';

  @override
  String get enterValidEmail => '請輸入有效的 Email 地址';

  @override
  String passwordMinLength(int min) {
    return '密碼長度至少需 $min 個字元';
  }

  @override
  String fullNameMinLength(int min) {
    return '全名長度至少需 $min 個字元';
  }

  @override
  String get createYourAccount => '建立您的帳號';

  @override
  String get fullName => '全名';

  @override
  String get createPassword => '建立密碼';

  @override
  String get passwordComplexityRequirement => '密碼必須包含至少一個大寫字母、一個小寫字母和一個數字';

  @override
  String get passwordRequirementShort => '密碼需 8+ 字元，並包含大小寫字母與數字';

  @override
  String get termsAgreement => '註冊帳號即表示您同意我們的服務條款與隱私權政策';

  @override
  String get alreadyHaveAccount => '已經有帳號了？';

  @override
  String get signInLower => '登入';

  @override
  String get verificationCodeSent => '驗證碼已成功寄出';

  @override
  String get verifyYourEmail => '驗證您的 Email';

  @override
  String verificationEmailSentTo(String email) {
    return '我們已將 6 位數驗證碼寄至 $email';
  }

  @override
  String get enterCompleteCode => '請輸入完整的 6 位數驗證碼';

  @override
  String get invalidVerificationCode => '驗證碼無效';

  @override
  String get verificationCodeExpired => '驗證碼已過期，請重新索取。';

  @override
  String get verifyEmail => '驗證 Email';

  @override
  String get didntReceiveTheCode => '沒收到驗證碼？請檢查您的垃圾郵件匣，或';

  @override
  String resendInSeconds(int seconds) {
    return '$seconds 秒後重新傳送';
  }

  @override
  String get resendVerificationEmail => '重新傳送驗證 Email';

  @override
  String get continueWithGoogle => '使用 Google 帳號繼續';

  @override
  String get signingInWithGoogle => '正在使用 Google 登入...';

  @override
  String get error => '錯誤';

  @override
  String get anErrorOccurred => '發生錯誤';

  @override
  String get unknownError => '未知的錯誤';

  @override
  String get goToHome => '前往首頁';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ 付款成功！正在檢查訂閱狀態...';

  @override
  String get paymentFailed => '付款失敗';

  @override
  String get paymentCanceled => 'ℹ️ 付款已取消';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp 驗證成功！';

  @override
  String get settings => '設定';

  @override
  String get enableNotificationsInSettings => '請至您裝置的「設定」開啟 Moneko 的通知功能';

  @override
  String get appearance => '外觀';

  @override
  String get darkMode => '深色模式';

  @override
  String get notifications => '通知';

  @override
  String get pushNotifications => '推播通知';

  @override
  String get receiveAlertsAndUpdates => '接收提醒與更新';

  @override
  String get language => '語言';

  @override
  String get systemDefault => '系統預設';

  @override
  String get membership => '會員方案';

  @override
  String get loading => '載入中...';

  @override
  String get failedToLoadMembership => '無法載入會員方案';

  @override
  String get couldNotOpenMembershipPage => '無法開啟會員方案頁面';

  @override
  String get freePlan => '免費';

  @override
  String get freePlanStatus => '免費方案';

  @override
  String get lifetimePlan => '終身';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus 月繳方案';

  @override
  String get plusYearlyPlan => 'Plus 年繳方案';

  @override
  String get activeStatus => '有效';

  @override
  String get activeLifetimeStatus => '有效 • 終身';

  @override
  String get canceledStatus => '已取消';

  @override
  String get pastDueStatus => '已逾期';

  @override
  String get trialStatus => '試用中';

  @override
  String trialEndsInDays(int days) {
    return '試用將於 $days 天後結束';
  }

  @override
  String get trialEnded => '試用已結束';

  @override
  String renewsInDays(int days) {
    return '$days 天後續訂';
  }

  @override
  String accessEndsInDays(int days) {
    return '會員資格將於 $days 天後結束';
  }

  @override
  String get subscriptionEnded => '訂閱已結束';

  @override
  String get profile => '個人資料';

  @override
  String get errorLoadingProfile => '載入個人資料時發生錯誤';

  @override
  String get user => '使用者';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => '已連結 WhatsApp';

  @override
  String get logExpensesViaWhatsApp => '透過 WhatsApp 訊息記錄支出';

  @override
  String get connectWhatsApp => '連結 WhatsApp';

  @override
  String get newBadge => '新功能';

  @override
  String get logExpensesInstantly => '透過聊天立即記錄支出';

  @override
  String get fast => '快速';

  @override
  String get photo => '照片';

  @override
  String get autoSync => '自動同步';

  @override
  String get naturalLanguage => '自然語言';

  @override
  String get describeExpenseAutomatically => '描述您的支出，我們將自動為您記錄。';

  @override
  String get snapReceipt => '拍下收據';

  @override
  String get snapReceiptDescription => '拍下您的收據，AI 將自動擷取並記錄。';

  @override
  String get previous => '上一步';

  @override
  String get next => '下一步';

  @override
  String get overview => '總覽';

  @override
  String get activity => '活動';

  @override
  String get accountInformation => '帳號資訊';

  @override
  String get userId => '使用者 ID';

  @override
  String get recentActivity => '近期活動';

  @override
  String get noActivityYet => '目前沒有活動';

  @override
  String get signOut => '登出';

  @override
  String get insights => '洞察報告';

  @override
  String get runningTab => '即時餘額';

  @override
  String get day30Tab => '30 天';

  @override
  String get longTermTab => '長期';

  @override
  String get scenarioTab => '情境';

  @override
  String get runningAndDailyBalances => '即時與每日餘額';

  @override
  String get budgetVsSpentDescription => '每日預算與支出對比，以及累計即時餘額。';

  @override
  String get runningBalanceLegend => '即時餘額';

  @override
  String get budgetLegend => '預算';

  @override
  String get spentLegend => '支出';

  @override
  String get runningBalanceGuide => '即時餘額指南';

  @override
  String get runningBalanceIntro => '把這張圖表想像成您的個人理財教練。讓我們來看看它顯示了什麼，以及如何使用它。';

  @override
  String get day30LookAhead => '未來 30 天預測';

  @override
  String get projectedFromTrailing30Days => '根據過去 30 天的平均值預測。';

  @override
  String get projectedSpendingLegend => '預測支出';

  @override
  String get peek30DaysAhead => '預覽未來 30 天';

  @override
  String get day30ForecastIntro => '此預測使用上個月的活動來推測下個月的狀況。把它想像成您錢包的氣象報告。';

  @override
  String get longTermProjection => '長期預測';

  @override
  String get basedOnHistoricalAverages => '基於歷史平均值；隨您的資料自動更新。';

  @override
  String get month18ProjectionLegend => '18 個月預測';

  @override
  String get your18MonthHorizon => '您的 18 個月展望';

  @override
  String get longTermIntro => '此預測融合了您的穩定習慣與溫和的成長假設，讓您看見今日的選擇將帶來什麼樣的未來。';

  @override
  String get aiScenarioPlanning => 'AI 情境規劃';

  @override
  String get askAiFinancialAdvisor => '詢問您的 AI 理財顧問，您是否負擔得起未來的某項支出';

  @override
  String get canI => '我能否';

  @override
  String get before => '在...之前';

  @override
  String get beforePrefix => '在';

  @override
  String get beforeSuffix => '之前';

  @override
  String get pickDate => '選擇日期';

  @override
  String get check => '開始分析';

  @override
  String get enterQuestionAndPickDate => '請輸入問題並選擇日期';

  @override
  String get analyzingScenario => '正在分析情境...';

  @override
  String get thisMightTakeAWhile => '這可能需要一點時間';

  @override
  String get whereTheMoneyWent => '錢都花到哪裡去了';

  @override
  String get categoryTotalsForSelectedRange => '所選範圍內的類別總計。';

  @override
  String get scenarioCategoriesGuide => '看懂類別';

  @override
  String get categoryGuideIntro => '把這張圖表想像成一張鳥瞰圖，看看每塊錢都飛到哪裡去了。這裡教您不用計算機也能看懂它。';

  @override
  String get readTheBarChartLikeAPro => '像專家一樣閱讀長條圖';

  @override
  String get categoryChartDesc => '所選期間的類別明細。';

  @override
  String get whyThisViewIsHelpful => '為什麼這個視圖有幫助';

  @override
  String get categoryWhyHelpfulDesc => '快速找出您最大的支出類別，並觀察長期趨勢。';

  @override
  String get whatToDoWithTheInsight => '如何運用這份洞察';

  @override
  String get categoryWhatToDoDesc => '利用這些資訊來調整您的預算和消費習慣。';

  @override
  String get scenarioAnalysis => '情境分析';

  @override
  String get target => '目標';

  @override
  String get quickStats => '快速統計';

  @override
  String get currentBalance => '目前餘額';

  @override
  String get projectedNoChange => '預測 (無變動)';

  @override
  String get avgDailyNet => '每日平均淨額';

  @override
  String get noDataAvailable => '沒有可用的資料';

  @override
  String get day => '日';

  @override
  String get close => '關閉';

  @override
  String get done => '完成';

  @override
  String get whatYouAreSeeing => '您所看到的';

  @override
  String get whyItMatters => '為何重要';

  @override
  String get howToRespond => '如何應對';

  @override
  String get runningBalanceWhatYouSeeDesc => '您的「即時餘額」追蹤您在每日支出後還有多少緩衝空間。每日長條圖顯示您的計劃 (預算) 與實際支出。';

  @override
  String get runningBalanceWhyMattersDesc => '把它當作一個友善的健康檢查。它幫助您注意到自己何時超前進度，以便繼續投資，或在何時需要修正路線以保持在軌道上。';

  @override
  String get runningBalanceHowToRespondDesc => '像教練一樣使用這張圖表。慶祝成果，必要時重新設定期望，並給自己一點彈性——重點是穩步前進，而非完美。';

  @override
  String get whatTheForecastShows => '預測顯示了什麼';

  @override
  String get day30WhatShowsDesc => '我們融合過去 30 天的收支，描繪出未來一週的平均狀況。它會平滑掉一次性的大額花費，讓您看到通常的節奏。';

  @override
  String get day30WhyMattersDesc => '前瞻性的預算能幫助您保持主動。看到未來有大筆支出的日子，能讓您提早預留現金，而不是到時手忙腳亂。';

  @override
  String get day30HowToPlaySmartDesc => '把它當作一個友善的提醒，而不是嚴格的規則手冊。用一些您覺得可行的小動作來調整您的計劃。';

  @override
  String get howTheProjectionWorks => '預測如何運作';

  @override
  String get longTermHowWorksDesc => '我們推估您未來的平均收支，並加入適度的成長，讓您看到您的計劃是否能在未來幾個月保持現金充裕。';

  @override
  String get longTermWhyMattersDesc => '長遠的眼光使偉大的夢想成真。看看您的緊急預備金、投資或大型採購是否仍在軌道上。';

  @override
  String get longTermMovesToConsiderDesc => '使用圖表來演練未來的決策。今天的小調整將在未來累積成大勝利。';

  @override
  String get forMe => '個人';

  @override
  String get forUs => '共享';

  @override
  String get home => '首頁';

  @override
  String get reminder => '提醒';

  @override
  String get analyzingReceipt => '正在分析收據...';

  @override
  String get analyzingExpense => '正在分析支出...';

  @override
  String get noExpenseInformationExtracted => '未擷取到支出資訊';

  @override
  String get failedToAnalyzeNoData => '分析失敗：未傳回資料';

  @override
  String get failedToAnalyze => '分析失敗';

  @override
  String get updateBudget => '更新預算';

  @override
  String get enterNewTotalDailyBudget => '輸入新的每日總預算。';

  @override
  String get budgetAmount => '預算金額';

  @override
  String get save => '儲存';

  @override
  String get enterValidAmountGreaterThan0 => '請輸入大於 0 的有效金額';

  @override
  String get updatingBudget => '正在更新預算...';

  @override
  String get budgetUpdated => '預算已更新';

  @override
  String get failedToUpdateBudget => '更新預算失敗';

  @override
  String get loggedSuccessfully => '記錄成功';

  @override
  String get view => '查看';

  @override
  String get retry => '重試';

  @override
  String get failedToCapturePhoto => '拍攝照片失敗';

  @override
  String get noSpendingData => '沒有支出資料';

  @override
  String get byCategory => '按類別';

  @override
  String get noExpensesYet => '尚無支出';

  @override
  String get startLoggingExpensesToSeeCategories => '開始記錄支出以查看類別';

  @override
  String get selectDateRange => '選取日期範圍';

  @override
  String get addExpense => '新增支出';

  @override
  String get describeYourExpense => '描述您的支出 (例如：「漢堡 \$80，咖啡 \$55」)';

  @override
  String get enterExpenseDetails => '輸入支出詳情...';

  @override
  String get freeFormText => '自由輸入';

  @override
  String get takePhoto => '拍照';

  @override
  String get transactions => '交易';

  @override
  String get negative => '負';

  @override
  String get positive => '正';

  @override
  String get spendingBreakdown => '支出明細';

  @override
  String get spent => '已支出';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get thisWeek => '本週';

  @override
  String get lastWeek => '上週';

  @override
  String get thisMonth => '本月';

  @override
  String get last30Days => '過去 30 天';

  @override
  String get customRange => '自訂範圍';

  @override
  String get spentToday => '您今天的支出';

  @override
  String get spentYesterday => '您昨天的支出';

  @override
  String get spentThisWeek => '您本週的支出';

  @override
  String get spentLastWeek => '您上週的支出';

  @override
  String get spentThisMonth => '您本月的支出';

  @override
  String get spentLast30Days => '您的支出 (過去 30 天)';

  @override
  String get spentCustom => '支出 (自訂)';

  @override
  String get todaysBudget => '今日預算';

  @override
  String get yesterdaysBudget => '昨日預算';

  @override
  String get sumOfDailyBudgetsThisWeek => '本週每日預算總和';

  @override
  String get sumOfDailyBudgetsLastWeek => '上週每日預算總和';

  @override
  String get sumOfDailyBudgetsThisMonth => '本月每日預算總和';

  @override
  String get sumOfDailyBudgetsLast30Days => '過去 30 天每日預算總和';

  @override
  String get sumOfDailyBudgetsForSelectedRange => '所選範圍每日預算總和';

  @override
  String get netCashflowToday => '今日淨現金流';

  @override
  String get netCashflowYesterday => '昨日淨現金流';

  @override
  String get netCashflowThisWeek => '本週淨現金流';

  @override
  String get netCashflowLastWeek => '上週淨現金流';

  @override
  String get netCashflowThisMonth => '本月淨現金流';

  @override
  String get netCashflowLast30Days => '淨現金流 (過去 30 天)';

  @override
  String get netCashflowCustom => '淨現金流 (自訂)';

  @override
  String get selectCurrency => '選擇幣別';

  @override
  String get showLessCurrencies => '顯示較少幣別';

  @override
  String showAllCurrencies(int count) {
    return '顯示所有幣別 (還有 $count 種)';
  }

  @override
  String get budget => '預算';

  @override
  String get spentLabel => '已支出';

  @override
  String get net => '淨額';

  @override
  String get txn => '筆';

  @override
  String get txns => '筆';

  @override
  String get pleaseEnterExpenseDetails => '請輸入支出詳情';

  @override
  String get userNotLoggedIn => '使用者未登入';

  @override
  String get errorLoadingHouseholds => '載入家庭時發生錯誤';

  @override
  String get welcomeToHouseholds => '歡迎使用「家庭」';

  @override
  String get householdsDescription => '與您的家人、伴侶或室友管理共享財務。追蹤預算、分攤支出，並共同協作理財決策。';

  @override
  String get createHousehold => '建立家庭';

  @override
  String get joinWithInvite => '使用邀請加入';

  @override
  String get pleaseUseInvitationLink => '請使用邀請連結加入家庭';

  @override
  String get householdName => '家庭名稱';

  @override
  String get householdNameHint => '例如：我們這一家';

  @override
  String get pleaseEnterHouseholdName => '請輸入家庭名稱';

  @override
  String get errorCreatingHousehold => '建立家庭時發生錯誤';

  @override
  String get householdsFeature => '「家庭」功能';

  @override
  String get householdsFeatureDescription => '「家庭」功能現已推出！與家人、伴侶或室友共同管理共享財務。';

  @override
  String get gotIt => '了解！';

  @override
  String get confirmExpense => '確認支出';

  @override
  String get expenseDetails => '支出詳情';

  @override
  String get details => '詳情';

  @override
  String get category => '類別';

  @override
  String get currency => '幣別';

  @override
  String get date => '日期';

  @override
  String get time => '時間';

  @override
  String get notes => '備註';

  @override
  String get receipt => '收據';

  @override
  String get saveExpense => '儲存支出';

  @override
  String get shareWithHousehold => '與家庭分享';

  @override
  String get loadingHouseholdMembers => '正在載入家庭成員...';

  @override
  String get selectHouseholdToConfigureSplit => '選擇一個家庭以設定分帳';

  @override
  String get currencyManagedByHousehold => '幣別由家庭管理，無法變更';

  @override
  String get currencyCannotBeChanged => '與家庭共享時無法變更幣別';

  @override
  String get failedToLoadImage => '載入圖片失敗';

  @override
  String get editAmount => '編輯金額';

  @override
  String get amount => '金額';

  @override
  String get editNotes => '編輯備註';

  @override
  String get addANote => '新增備註...';

  @override
  String get noMembersFoundInHousehold => '家庭中找不到成員';

  @override
  String get errorLoadingMembers => '載入成員時發生錯誤';

  @override
  String get noExpenseToSave => '沒有要儲存的支出';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return '支出已儲存並共享$splitInfo！';
  }

  @override
  String get expenseSaved => '支出已儲存！';

  @override
  String failedToSave(String error) {
    return '儲存失敗：$error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return '同步幣別偏好失敗：$error';
  }

  @override
  String get currencyUpdatedSuccessfully => '幣別更新成功';

  @override
  String retryFailed(Object error) {
    return '重試失敗：$error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return '我在 $category 上花了 $currencySymbol$amount';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => '輸入新的每日總預算。';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => '請登入以使用家庭功能';

  @override
  String get quickActions => '快速操作';

  @override
  String get members => '成員';

  @override
  String get invites => '邀請';

  @override
  String get errorLoadingExpenses => '載入支出時發生錯誤';

  @override
  String get budgets => '預算';

  @override
  String get loadingHousehold => '正在載入家庭...';

  @override
  String get remaining => '剩餘';

  @override
  String get overBudget => '超出预算';

  @override
  String get sharedBudgets => '共享預算';

  @override
  String get netPosition => '淨額';

  @override
  String get spentByHousehold => '家庭支出';

  @override
  String get memberSpending => '成員支出';

  @override
  String get spentByHouseholdTooltip => '顯示所選期間內所有家庭成員的總支出金額。包括家庭任何成員記錄的所有共享支出。';

  @override
  String get manageMoneyTogether => '在一個共享空間中，與您的伴侶、家人或室友共同管理財務。';

  @override
  String get sharedBudgetsExpenses => '共享預算與支出';

  @override
  String get sharedBudgetsExpensesDesc => '設定預算、追蹤支出，並即時查看您家庭的資金流向。';

  @override
  String get smartExpenseSplitting => '智慧分帳';

  @override
  String get smartExpenseSplittingDesc => '透過彈性的分帳選項 (均分、百分比或自訂金額) 自動計算誰該付多少錢。';

  @override
  String get stayInSync => '保持同步';

  @override
  String get stayInSyncDesc => '當新增支出、達到預算或需要結算分帳時收到通知。';

  @override
  String get householdSettings => '家庭設定';

  @override
  String get householdNotFound => '找不到家庭';

  @override
  String get coverPhoto => '封面照片';

  @override
  String get changeCoverPhoto => '更換封面照片';

  @override
  String get saveChanges => '儲存變更';

  @override
  String get errorLoadingHousehold => '載入家庭時發生錯誤';

  @override
  String get householdUpdatedSuccessfully => '家庭已成功更新';

  @override
  String get failedToUpdateHousehold => '更新家庭失敗';

  @override
  String get inviteMember => '邀請成員';

  @override
  String get removeMember => '移除成員';

  @override
  String get remove => '移除';

  @override
  String get confirmRemoveMember => '您確定要移除';

  @override
  String get updatedMemberRole => '已更新成員角色';

  @override
  String get unknown => '未知';

  @override
  String get makeAdmin => '設為管理員';

  @override
  String get makeMember => '設為成員';

  @override
  String get invitations => '邀請';

  @override
  String get errorLoadingInvites => '載入邀請時發生錯誤';

  @override
  String get createInvitation => '建立邀請';

  @override
  String get pendingInvitations => '待處理的邀請';

  @override
  String get noPendingInvitations => '沒有待處理的邀請';

  @override
  String get invitationHistory => '邀請紀錄';

  @override
  String get noInvitationHistory => '沒有邀請紀錄';

  @override
  String get emailOptional => 'Email (選填)';

  @override
  String get friendEmailExample => 'friend@example.com';

  @override
  String get personalMessageOptional => '個人訊息 (選填)';

  @override
  String get joinHouseholdBudget => '加入我們的家庭預算！';

  @override
  String get expiresIn => '有效期限';

  @override
  String get oneDay => '1 天';

  @override
  String get threeDays => '3 天';

  @override
  String get sevenDays => '7 天';

  @override
  String get fourteenDays => '14 天';

  @override
  String get thirtyDays => '30 天';

  @override
  String get unlimited => '無限制';

  @override
  String get create => '建立';

  @override
  String get invitationCreatedSuccessfully => '邀請建立成功';

  @override
  String get inviteLinkCopiedToClipboard => '邀請連結已複製到剪貼簿！';

  @override
  String get errorCreatingInvite => '建立邀請時發生錯誤';

  @override
  String get revokeInvitation => '撤銷邀請';

  @override
  String get confirmRevokeInvitation => '您確定要撤銷此邀請嗎？';

  @override
  String get revoke => '撤銷';

  @override
  String get invitationRevoked => '邀請已撤銷';

  @override
  String get errorRevokingInvite => '撤銷邀請時發生錯誤';

  @override
  String get anyoneWithLink => '任何持有連結者';

  @override
  String get noExpiry => '無到期日';

  @override
  String get expired => '已過期';

  @override
  String get expires => '到期';

  @override
  String get copyLink => '複製連結';

  @override
  String get selectCoverImage => '選取封面圖片';

  @override
  String get failedToLoadImages => '載入圖片失敗';

  @override
  String get chooseFromGallery => '從相簿選擇';

  @override
  String get failedToLoad => '載入失敗';

  @override
  String get imageTooLarge => '圖片過大';

  @override
  String get maxIs => '上限為';

  @override
  String get unsupportedFileFormat => '不支援的檔案格式。請使用 JPG、PNG 或 WebP。';

  @override
  String get cropCoverImage => '裁切封面圖片';

  @override
  String get editBudget => '編輯預算';

  @override
  String get budgetDetails => '預算詳情';

  @override
  String get budgetName => '預算名稱';

  @override
  String get period => '週期';

  @override
  String get alertThresholds => '提醒閾值';

  @override
  String get warningThreshold => '警告閾值 (%)';

  @override
  String get alertThreshold => '警示閾值 (%)';

  @override
  String get warningThresholdHelper => '當預算使用率達到此百分比時提醒';

  @override
  String get alertThresholdHelper => '達到此百分比時發出嚴重警示';

  @override
  String get budgetStatus => '預算狀態';

  @override
  String get active => '活躍';

  @override
  String get inactive => '停用';

  @override
  String get deletingBudget => '正在刪除預算...';

  @override
  String get savingChanges => '正在儲存變更...';

  @override
  String get budgetNameCannotBeEmpty => '預算名稱不可為空';

  @override
  String get pleaseEnterValidAmount => '請輸入有效金額';

  @override
  String get warningThresholdRange => '警告閾值必須介於 0 和 100 之間';

  @override
  String get alertThresholdRange => '警示閾值必須介於 0 和 100 之間';

  @override
  String get warningThresholdLessThanAlert => '警告閾值必須小於或等於警示閾值';

  @override
  String get deleteBudget => '刪除預算';

  @override
  String get confirmDeleteBudget => '您確定要刪除';

  @override
  String get thisActionCannotBeUndone => '此動作無法復原';

  @override
  String get budgetUpdatedSuccessfully => '預算更新成功';

  @override
  String get budgetDeletedSuccessfully => '預算刪除成功';

  @override
  String get categoryTransfers => '轉帳';

  @override
  String get categoryShopping => '購物';

  @override
  String get categoryUtilities => '水電雜費';

  @override
  String get categoryEntertainment => '娛樂';

  @override
  String get categoryEntertainmentSubscriptions => '娛樂訂閱';

  @override
  String get categoryRestaurants => '餐廳';

  @override
  String get categoryFood => '食物';

  @override
  String get categoryGroceries => '食材雜貨';

  @override
  String get categoryTransport => '交通';

  @override
  String get categoryTransportation => '交通運輸';

  @override
  String get categoryTravel => '旅遊';

  @override
  String get categoryFlights => '機票';

  @override
  String get categoryVacation => '度假';

  @override
  String get categoryHealth => '健康';

  @override
  String get categoryMedical => '醫療';

  @override
  String get categoryText => '文字';

  @override
  String get categoryEducation => '教育';

  @override
  String get categoryTuition => '學費';

  @override
  String get categorySubscriptions => '訂閱';

  @override
  String get categoryServices => '服務';

  @override
  String get categoryHousing => '居住';

  @override
  String get categoryRent => '租金';

  @override
  String get categoryMortgage => '房貸';

  @override
  String get categoryBills => '帳單';

  @override
  String get categoryInsurance => '保險';

  @override
  String get categorySavings => '儲蓄';

  @override
  String get categoryInvestment => '投資';

  @override
  String get categoryInvestments => '投資';

  @override
  String get categoryIncome => '收入';

  @override
  String get categorySalary => '薪水';

  @override
  String get categoryBonus => '獎金';

  @override
  String get categoryPets => '寵物';

  @override
  String get categoryKids => '孩子';

  @override
  String get categoryFamily => '家庭';

  @override
  String get categoryGifts => '禮物';

  @override
  String get categoryCharity => '慈善';

  @override
  String get categoryFees => '手續費';

  @override
  String get categoryLoan => '貸款';

  @override
  String get categoryLoans => '貸款';

  @override
  String get categoryDebt => '債務';

  @override
  String get categoryPersonalCare => '個人照護';

  @override
  String get categoryBeauty => '美容';

  @override
  String get categoryMisc => '雜項';

  @override
  String get categoryUncategorized => '未分類';

  @override
  String get deleteBudgetCannotBeUndone => '此動作無法復原';

  @override
  String get delete => '刪除';

  @override
  String get failedToDeleteBudget => '刪除預算失敗';

  @override
  String get owner => '所有者';

  @override
  String get admin => '管理員';

  @override
  String get member => '成員';

  @override
  String get pending => '待處理';

  @override
  String get accepted => '已接受';

  @override
  String get revoked => '已撤銷';

  @override
  String get tapToChangeCover => '點擊以更換封面';

  @override
  String get personalMessageHint => '想對受邀者說的話 (例如：「加入我們的家庭預算吧！」)';

  @override
  String get invitationExpiresIn => '邀請有效期限';

  @override
  String daysCount(int days) {
    return '$days 天';
  }

  @override
  String get createHouseholdDescription => '建立一個共享空間，與家人或室友一起追蹤預算和支出。';

  @override
  String get uploadingImage => '正在上傳圖片...';

  @override
  String get creating => '正在建立...';

  @override
  String get generatingInvite => '正在產生邀請...';

  @override
  String get pleaseSelectValidCurrency => '請選擇有效的家庭幣別';

  @override
  String nameMaxLength(int max) {
    return '名稱不得超過 $max 個字元';
  }

  @override
  String get createHouseholdPage => '建立家庭頁面';

  @override
  String get invitationPersonalMessageInput => '邀請個人訊息輸入';

  @override
  String get householdNameInput => '家庭名稱輸入';

  @override
  String get invitationExpirationSelector => '邀請有效期限選擇器';

  @override
  String get unlimitedExpiration => '永久有效';

  @override
  String daysExpiration(int days) {
    return '$days 天有效';
  }

  @override
  String get householdInformation => '家庭資訊';

  @override
  String get creatingHousehold => '正在建立家庭';

  @override
  String get createHouseholdButton => '建立家庭按鈕';

  @override
  String get searchExpenses => '搜尋支出...';

  @override
  String get clearAll => '全部清除';

  @override
  String get allCategories => '所有類別';

  @override
  String get allMembers => '所有成員';

  @override
  String get balanceSummary => '餘額總覽';

  @override
  String get youAreOwed => '他人欠您';

  @override
  String get youOwe => '您欠他人';

  @override
  String get youOweOthers => '您欠他人';

  @override
  String get othersOweYou => '他人欠您';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get settleUp => '結算';

  @override
  String get markExpensesAsSettled => '將支出標記為已結算以更新餘額';

  @override
  String get whoAreYouSettlingWith => '您要與誰結算？';

  @override
  String get selectMember => '選擇成員';

  @override
  String get amountToSettle => '結算金額';

  @override
  String get howDidYouSettle => '您如何結算？';

  @override
  String get cash => '現金';

  @override
  String get paidInCash => '以現金支付';

  @override
  String get bankTransfer => '銀行轉帳';

  @override
  String get transferredViaBank => '透過銀行轉帳';

  @override
  String get mobilePayment => '行動支付';

  @override
  String get venmoPaypalEtc => 'LINE Pay, 街口支付等';

  @override
  String get search => '搜尋';

  @override
  String get noData => '沒有資料';

  @override
  String get filterTransactions => '篩選交易';

  @override
  String get noTransactionsFound => '找不到交易';

  @override
  String get failedToLoadHouseholdTransactions => '載入家庭交易失敗';

  @override
  String get reset => '重設';

  @override
  String get apply => '套用';

  @override
  String get expenses => '支出';

  @override
  String get dateRange => '日期範圍';

  @override
  String get noMatchingExpenses => '沒有符合的支出';

  @override
  String get startLoggingExpenses => '開始記錄支出，就能在這裡看到它們';

  @override
  String get tryAdjustingFilters => '試著調整您的篩選條件';

  @override
  String get split => '分帳';

  @override
  String get note => '備註';

  @override
  String get currencyCannotBeChangedWhenSharing => '與家庭共享時無法變更幣別';

  @override
  String get createBudget => '建立預算';

  @override
  String get pleaseEnterABudgetName => '請輸入預算名稱';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => '請輸入大於 0 的有效金額';

  @override
  String get warningThresholdMustBeBetween0And100 => '警告閾值必須介於 0% 和 100% 之間';

  @override
  String get alertThresholdMustBeBetween0And100 => '警示閾值必須介於 0% 和 100% 之間';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => '警告閾值必須小於或等於警示閾值';

  @override
  String get budgetCreatedSuccessfully => '預算建立成功！';

  @override
  String get failedToCreateBudget => '建立預算失敗';

  @override
  String get groceriesRentEntertainment => '例如：食材、租金、娛樂';

  @override
  String get budgetType => '預算類型';

  @override
  String get sharedWithAllHouseholdMembers => '與所有家庭成員共享';

  @override
  String get personalBudgetForYourExpensesOnly => '僅供您個人支出的預算';

  @override
  String get countSplitPortionOnly => '僅計算分帳部分';

  @override
  String get onlyCountYourPortionOfSplitExpenses => '僅將您在分帳支出中的部分計入此預算';

  @override
  String get joinHousehold => '加入家庭';

  @override
  String get joinAHousehold => '加入一個家庭';

  @override
  String get enterYourInvitationLinkToJoin => '輸入您的邀請連結以加入\n一個共享的財務空間';

  @override
  String get pasteTheInvitationLinkYouReceived => '貼上您從家庭成員那裡收到的邀請連結';

  @override
  String get pasteInvitationLink => '貼上邀請連結';

  @override
  String get pleaseEnterAnInvitationLink => '請輸入邀請連結';

  @override
  String get pleaseEnterAValidInvitationLink => '請輸入有效的邀請連結';

  @override
  String get paste => '貼上';

  @override
  String get validating => '驗證中...';

  @override
  String get continueAction => '繼續';

  @override
  String get welcomeAboard => '歡迎加入！';

  @override
  String get youreNowPartOfTheHousehold => '您現在是這個家庭的一員了。\n開始協作管理您的財務吧！';

  @override
  String get thisWillOnlyTakeAMoment => '請稍候片刻';

  @override
  String get unableToJoin => '無法加入';

  @override
  String get tryAgain => '再試一次';

  @override
  String get goToHousehold => '前往家庭';

  @override
  String get expiresSoon => '即將過期';

  @override
  String invitationValidUntil(String formattedDate) {
    return '邀請有效期至';
  }

  @override
  String get whatYoullGet => '你將獲得';

  @override
  String get viewSharedBudgetsAndExpenses => '查看共享預算和支出';

  @override
  String get trackHouseholdFinancialHealth => '追蹤家庭財務狀況';

  @override
  String get collaborateOnFinancialDecisions => '協作制定財務決策';

  @override
  String get household => '家庭';

  @override
  String get viewAll => '查看全部';

  @override
  String get manage => '管理';

  @override
  String get noBudgetsYet => '尚無預算';

  @override
  String get createSharedBudgetDescription => '建立共享預算以共同追蹤支出';

  @override
  String get errorLoadingBudgets => '載入預算時發生錯誤';

  @override
  String get recentSplits => '近期分帳';

  @override
  String get invite => '邀請';

  @override
  String get last6Months => '過去 6 個月';

  @override
  String get thisYear => '今年';

  @override
  String get allTime => '所有時間';

  @override
  String nameMinLength(int min) {
    return '名稱至少需 $min 個字元';
  }

  @override
  String get splitExpense => '分攤支出';

  @override
  String get percent => '百分比';

  @override
  String get splitShare => '份';

  @override
  String get owes => '應付';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return '分攤金額總和必須等於 $currency$amount';
  }

  @override
  String get percentagesMustTotal100 => '百分比總和必須為 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => '每人至少需佔 1 份';

  @override
  String get whatsappVerified => 'WhatsApp 驗證成功';

  @override
  String get whatsappVerification => 'WhatsApp 驗證';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => '您的 WhatsApp 號碼已成功連結到您的帳號';

  @override
  String get verifyingYourWhatsAppNumber => '正在驗證您的 WhatsApp 號碼...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => '輸入來自 WhatsApp 的 6 位數驗證碼';

  @override
  String get pleaseEnterThe6DigitVerificationCode => '請輸入 6 位數驗證碼';

  @override
  String get failedToVerifyCode => '驗證失敗';

  @override
  String get failedToVerifyCodePleaseTryAgain => '驗證失敗，請再試一次。';

  @override
  String get codeAutoFilledFromVerificationLink => '已從驗證連結自動填入驗證碼';

  @override
  String get verify => '驗證';

  @override
  String get verifying => '驗證中...';

  @override
  String get avatarStudio => '頭像工作室';

  @override
  String get preview => '預覽';

  @override
  String get colors => '顏色';

  @override
  String get randomize => '隨機';

  @override
  String get saveAvatar => '儲存頭像';

  @override
  String get saving => '儲存中...';

  @override
  String get skipForNow => '暫時略過';

  @override
  String get selectColor => '選擇顏色';

  @override
  String get failedToSaveAvatar => '儲存頭像失敗';

  @override
  String get hair => '頭髮';

  @override
  String get eyes => '眼睛';

  @override
  String get mouth => '嘴巴';

  @override
  String get background => '背景';

  @override
  String get face => '臉型';

  @override
  String get ears => '耳朵';

  @override
  String get shirts => '衣服';

  @override
  String get brow => '眉毛';

  @override
  String get nose => '鼻子';

  @override
  String get blush => '腮紅';

  @override
  String get accessories => '配件';

  @override
  String get stars => '星星';

  @override
  String get currencyIsManagedByHousehold => '幣別由家庭管理，無法變更';

  @override
  String get buyALaptop => '買一台 \$30,000 的筆電';

  @override
  String get selectTargetDate => '選擇目標日期';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return '我可以在 $date 之前 $action 嗎？';
  }

  @override
  String get scenarioDateFormat => 'yyyy/MM/dd';

  @override
  String analysisFailed(String error) {
    return '分析失敗：$error';
  }

  @override
  String get leftHandChamps => '圖表左側是您的主要支出項目——非常適合快速檢視。';

  @override
  String get smallButFrequent => '金額小但頻繁的類別，暗示著可能隨時間累積的習慣。';

  @override
  String get colorMatches => '顏色與您在「首頁」標籤上看到的相符，讓您的大腦保持舒適。';

  @override
  String get planningNewGoal => '正在規劃新目標？找出可以削減的類別，而無需犧牲您的樂趣。';

  @override
  String get eyeingTreatYourself => '想犒賞自己一個月嗎？看看哪些領域可以安全地彈性調整。';

  @override
  String get doubleCheckTagging => '用它來再次確認新的支出是否被正確標記——不容許任何遺漏。';

  @override
  String get slideHighBar => '設定一個小額限制或改用較低成本的替代品，來降低那個高高的長條。';

  @override
  String get nonNegotiable => '如果某個項目是固定支出 (例如：租金)，那就圍繞它來規劃，而不是對抗它。';

  @override
  String get revisitAfterScenario => '執行情境分析後，重新檢視，看看您的調整是否有效。';

  @override
  String get purpleLineCushion => '紫線：每天結束後剩下的緩衝金。上升的線條代表您正在累積動能。';

  @override
  String get blueBarsBudget => '藍色長條：您當天設定的預算。';

  @override
  String get redBarsSpent => '紅色長條：實際從您帳戶中支出的金額。';

  @override
  String get lineTrendingUpward => '線條上升 = 您可以將額外的現金轉用於儲蓄目標。';

  @override
  String get flatDippingLine => '線條平緩或下降 = 該暫停並檢視大額項目了。';

  @override
  String get sharpDrops => '急遽下降通常代表有計劃外的採購——點擊它們以查看詳情。';

  @override
  String get lineRisingDays => '線條連續上升好幾天？考慮將多餘的錢轉入儲蓄或償還債務。';

  @override
  String get lineDippingWeekend => '忙碌的週末後線條下降了？透過削減未來幾天的小額非必要開支來重新平衡。';

  @override
  String get feelStuckRed => '覺得自己一直處於赤字？回到「首頁」標籤重新檢視您的預算——小小的調整也能累積大大的效果。';

  @override
  String get thirtyDayForecastDesc => '此預測使用上個月的活動來推測下個月的狀況。把它想像成您錢包的氣象報告。';

  @override
  String get greenLineExpected => '綠線 = 如果下個月的行為與上個月相同，預期的每日支出。';

  @override
  String get spikesHighlight => '高峰突顯出您的消費習慣通常在哪幾週花費更高 (例如：週五的外賣)。';

  @override
  String get forecastUpdates => '當您記錄新的交易時，預測會自動更新——無需重新整理。';

  @override
  String get spotExpensivePatterns => '及早發現高消費模式，並在它們到來前提早存一筆緩衝金。';

  @override
  String get catchQuieterWeeks => '抓住支出較少的幾週，將多餘的現金轉入儲蓄或償還債務。';

  @override
  String get timeRecurringPayments => '利用這份洞察來安排您的定期付款、訂閱或儲值時間。';

  @override
  String get bigSpikeComing => '即將有大筆支出？提早預訂較便宜的選項，或將彈性支出改到較平靜的日子。';

  @override
  String get forecastDipping => '預測顯示支出下降？安排一筆額外的儲蓄轉帳來獎勵自己。';

  @override
  String get forecastLooksOff => '如果預測看起來不對勁，請檢視「首頁」標籤中的類別，整理任何錯誤的標記。';

  @override
  String get greenLineTrends => '綠線會隨著您典型的儲蓄率趨勢變動——向上的動能代表您的目標資金充足。';

  @override
  String get lineDipsSignals => '如果線條下降，這預示著未來幾個月的支出可能超過收入。';

  @override
  String get largeGoalsDebts => '當您在「首頁」標籤中標記它們時，大型目標或債務會被包含在內。';

  @override
  String get upwardSlope => '呈現上升趨勢？值得慶祝，並考慮提高您的退休金或旅遊儲蓄。';

  @override
  String get flatSlipping => '持平或下滑？在雪球滾大之前，是時候調整預算或增加收入來源了。';

  @override
  String get watchSeasonalTrends => '注意季節性趨勢——假期、學期或年度續約通常會最先在這裡顯現。';

  @override
  String get schedulePaymentIncreases => '當曲線上升時，安排溫和地增加貸款還款金額。';

  @override
  String get planAheadDips => '透過提撥儲備基金或削減非必要開支，為未來的下降提前規劃。';

  @override
  String get checkProjectionMonthly => '每月檢查預測，讓您的長期規劃保持樂趣和彈性。';

  @override
  String get categoryHealthcare => '醫療保健';

  @override
  String get categoryOther => '其他';

  @override
  String get deleteExpense => '刪除支出';

  @override
  String get confirmDeleteExpense => '您確定要刪除這筆支出嗎？此動作無法復原。';

  @override
  String get expenseDeletedSuccessfully => '支出已成功刪除';

  @override
  String get failedToDeleteExpense => '刪除支出失敗';

  @override
  String get expenseNotFoundOrDeleted => '找不到支出或支出已被刪除';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => '只有管理員和擁有者可以編輯家庭設定';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => '只有管理員和擁有者可以建立邀請';

  @override
  String shareInvitationForHousehold(String householdName) {
    return '分享家庭 $householdName 的邀請';
  }

  @override
  String get shareInvitation => '分享邀請';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return '家庭 $householdName 建立成功';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return '家庭 \"$householdName\" 建立成功！';
  }

  @override
  String get invitationLink => '邀請連結';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return '邀請連結：$inviteUrl';
  }

  @override
  String get copyInvitationLink => '複製邀請連結';

  @override
  String get copyInvitationLinkToClipboard => '複製邀請連結到剪貼簿';

  @override
  String get shareInvitationLink => '分享邀請連結';

  @override
  String get share => '分享';

  @override
  String get closeShareSheet => '關閉分享面板';

  @override
  String get invitationLinkCopiedToClipboard => '邀請連結已複製到剪貼簿！';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return '來 Moneko 加入我的家庭 \"$householdName\" 吧！\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => '來 Moneko 加入我的家庭吧';

  @override
  String get zeroAmount => '0.00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => '通知設定';

  @override
  String get budgetBoop => '預算戳一下';

  @override
  String get getGentleReminder => '達到此閾值時收到溫和提醒';

  @override
  String get purrSuasiveNudge => '咕嚕式提醒';

  @override
  String get getStrongerNudge => '達到此閾值時收到更強推動';

  @override
  String get createBudgetButton => '建立預算';

  @override
  String get daily => '每日';

  @override
  String get weekly => '每週';

  @override
  String get monthly => '每月';

  @override
  String get yearly => '每年';

  @override
  String get householdBudgetType => '家庭預算';

  @override
  String get personalBudgetType => '個人預算';

  @override
  String joinHouseholdName(String householdName) {
    return '加入「$householdName」';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return '家庭預覽：$householdName，邀請者：$inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return '邀請者：$inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return '邀請將於 $formattedDate 到期';
  }

  @override
  String get invitationValidUntilLabel => '邀請有效期限';

  @override
  String get personalMessageFromInviter => '邀請者的個人訊息';

  @override
  String get messageFromInviter => '來自邀請者的訊息';

  @override
  String get joiningHousehold => '正在加入家庭...';

  @override
  String errorWithMessage(String errorMessage) {
    return '錯誤：$errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => '發生意外錯誤';

  @override
  String get invalidInvitationLinkFormat => '無效的邀請連結格式';

  @override
  String get invalidOrExpiredInvitation => '邀請無效或已過期';

  @override
  String get tomorrow => '明天';

  @override
  String inDays(int days) {
    return '$days 天後';
  }

  @override
  String get january => '1月';

  @override
  String get february => '2月';

  @override
  String get march => '3月';

  @override
  String get april => '4月';

  @override
  String get may => '5月';

  @override
  String get june => '6月';

  @override
  String get july => '7月';

  @override
  String get august => '8月';

  @override
  String get september => '9月';

  @override
  String get october => '10月';

  @override
  String get november => '11月';

  @override
  String get december => '12月';

  @override
  String remindUser(String name) {
    return '提醒 $name';
  }

  @override
  String get sendFriendlySpendingReminder => '傳送一則親切的消費提醒';

  @override
  String get addMessageOptional => '新增訊息（選填）';

  @override
  String get messageHintExample => '例如：「你的錢包也需要休息！」';

  @override
  String get sendReminder => '傳送提醒';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return '請等候 24 小時後再向 $name 傳送另一則提醒';
  }

  @override
  String reminderSentToName(String name) {
    return '已傳送提醒給 $name 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => '無法傳送提醒，請再試一次。';

  @override
  String get income => '收入';

  @override
  String get addIncome => '新增收入';

  @override
  String get incomeAdded => '收入新增成功';

  @override
  String get noIncome => '暫無收入';

  @override
  String get noIncomeDescription => '記錄您的收入以追蹤家庭的財務健康狀況';

  @override
  String get totalIncome => '總收入';

  @override
  String get monthToDate => '本月至今';

  @override
  String get yearToDate => '本年至今';

  @override
  String get failedToLoadIncome => '載入收入失敗';

  @override
  String get incomeAcknowledged => '收入已確認';

  @override
  String get acknowledge => '確認';

  @override
  String get acknowledged => '已確認';

  @override
  String get source => '來源';

  @override
  String get sourceHint => '例如：雇主、客戶';

  @override
  String get me => '我';

  @override
  String get partner => '伴侶';

  @override
  String get privacyScope => '隱私';

  @override
  String get privacyFull => '完整詳情';

  @override
  String get privacyBalancesOnly => '僅餘額';

  @override
  String get privacyPrivate => '私密';

  @override
  String get privacyFullExplanation => '伴侶可以看到所有詳細資訊，包括金額、來源和描述。';

  @override
  String get privacyBalancesOnlyExplanation => '伴侶可以在總額中看到此收入，但無法看到詳細資訊（來源、描述隱藏）。';

  @override
  String get privacyPrivateExplanation => '只有您可以看到此收入。它有助於家庭總額，但伴侶無法看到詳細資訊。';

  @override
  String get incomeSalary => '薪資';

  @override
  String get incomeFreelance => '自由業';

  @override
  String get incomeInvestment => '投資';

  @override
  String get incomeRefund => '退款';

  @override
  String get incomeGift => '禮物';

  @override
  String get incomeBonus => '獎金';

  @override
  String get incomeRental => '租金收入';

  @override
  String get incomeOther => '其他';

  @override
  String get goals => '目標';

  @override
  String get createGoal => '建立目標';

  @override
  String get goalCreated => '目標建立成功';

  @override
  String get goalTitle => '目標標題';

  @override
  String get enterGoalTitle => '輸入目標標題';

  @override
  String get pleaseEnterTitle => '請輸入標題';

  @override
  String get pleaseEnterAmount => '請輸入金額';

  @override
  String get invalidAmount => '請輸入大於0的有效金額';

  @override
  String get targetAmount => '目標金額';

  @override
  String get currentAmount => '當前金額';

  @override
  String get targetDate => '目標日期';

  @override
  String get description => '描述';

  @override
  String get descriptionHint => '備註（可選）';

  @override
  String get savings => '儲蓄';

  @override
  String get paydown => '還款';

  @override
  String get all => '全部';

  @override
  String get completed => '已完成';

  @override
  String get offTrack => '進度落後';

  @override
  String get onTrack => '進度正常';

  @override
  String get complete => '完成';

  @override
  String get overallProgress => '整體進度';

  @override
  String get totalGoals => '總目標數';

  @override
  String get noGoals => '還沒有目標，先建立第一個目標吧！';

  @override
  String get noSavingsGoals => '還沒有儲蓄目標。建立一個就能開始儲蓄！';

  @override
  String get noPaydownGoals => '還沒有還款目標。建立一個就能開始減少債務！';

  @override
  String get goalAcknowledged => '目標已確認';

  @override
  String get balancesOnly => '僅餘額';

  @override
  String get contribution => '貢獻';

  @override
  String get withdrawal => '提領';

  @override
  String get interest => '利息';

  @override
  String get adjustment => '調整';

  @override
  String get addContribution => '新增貢獻';

  @override
  String get contributionAmount => '貢獻金額';

  @override
  String get contributionType => '類型';

  @override
  String get contributionAdded => '貢獻新增成功';
}
