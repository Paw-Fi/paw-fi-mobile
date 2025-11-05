// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => '支出はまだありません';

  @override
  String get loginWelcomeBack => 'おかえりなさい';

  @override
  String get orContinueWithEmail => 'またはメールアドレスで続ける';

  @override
  String get emailAddress => 'メールアドレス';

  @override
  String get password => 'パスワード';

  @override
  String get forgotPassword => 'パスワードをお忘れの場合';

  @override
  String get signIn => 'ログイン';

  @override
  String get newToMoneko => 'Monekoは初めてですか？';

  @override
  String get createAccount => '新規登録';

  @override
  String get resetYourPassword => 'パスワードの再設定';

  @override
  String get email => 'メールアドレス';

  @override
  String get exampleEmail => 'example@example.com';

  @override
  String get cancel => 'キャンセル';

  @override
  String get sendResetLink => '再設定リンクを送信';

  @override
  String get passwordResetEmailSent => 'パスワード再設定メールを送信しました。受信トレイを確認してください。';

  @override
  String get enterValidEmail => '有効なメールアドレスを入力してください';

  @override
  String passwordMinLength(int min) {
    return 'パスワードは$min文字以上必要です';
  }

  @override
  String fullNameMinLength(int min) {
    return '氏名は$min文字以上である必要があります';
  }

  @override
  String get createYourAccount => 'アカウントを作成';

  @override
  String get fullName => '氏名';

  @override
  String get createPassword => 'パスワードを作成';

  @override
  String get passwordComplexityRequirement => 'パスワードには、大文字、小文字、数字をそれぞれ1文字以上含める必要があります';

  @override
  String get passwordRequirementShort => '8文字以上、大文字、小文字、数字を含む';

  @override
  String get termsAgreement => 'アカウントを作成することにより、利用規約とプライバシーポリシーに同意したことになります。';

  @override
  String get alreadyHaveAccount => 'すでにアカウントをお持ちですか？';

  @override
  String get signInLower => 'ログイン';

  @override
  String get verificationCodeSent => '認証コードを送信しました';

  @override
  String get verifyYourEmail => 'メールアドレスの認証';

  @override
  String verificationEmailSentTo(String email) {
    return '$email に6桁の認証コードを送信しました。';
  }

  @override
  String get enterCompleteCode => '6桁の認証コードをすべて入力してください';

  @override
  String get invalidVerificationCode => '無効な認証コードです';

  @override
  String get verificationCodeExpired => '認証コードの有効期限が切れました。新しいコードをリクエストしてください。';

  @override
  String get verifyEmail => 'メールアドレスを認証';

  @override
  String get didntReceiveTheCode => 'コードが届かない場合は、迷惑メールフォルダを確認するか、';

  @override
  String resendInSeconds(int seconds) {
    return '$seconds秒後に再送信';
  }

  @override
  String get resendVerificationEmail => '認証メールを再送信';

  @override
  String get continueWithGoogle => 'Googleで続ける';

  @override
  String get signingInWithGoogle => 'Googleでログインしています...';

  @override
  String get error => 'エラー';

  @override
  String get anErrorOccurred => 'エラーが発生しました';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get goToHome => 'ホームに戻る';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ 支払い完了！サブスクリプションを確認しています...';

  @override
  String get paymentFailed => '支払いが失敗しました';

  @override
  String get paymentCanceled => 'ℹ️ 支払いはキャンセルされました';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsAppの認証が完了しました！';

  @override
  String get settings => '設定';

  @override
  String get enableNotificationsInSettings => 'デバイスの設定でMonekoの通知を有効にしてください';

  @override
  String get appearance => '外観';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get notifications => '通知';

  @override
  String get pushNotifications => 'プッシュ通知';

  @override
  String get receiveAlertsAndUpdates => 'アラートやお知らせを受信';

  @override
  String get language => '言語';

  @override
  String get systemDefault => 'システムのデフォルト';

  @override
  String get membership => 'メンバーシップ';

  @override
  String get loading => '読み込み中...';

  @override
  String get failedToLoadMembership => 'メンバーシップの読み込みに失敗しました';

  @override
  String get couldNotOpenMembershipPage => 'メンバーシップページを開けませんでした';

  @override
  String get freePlan => 'フリープラン';

  @override
  String get freePlanStatus => 'フリープラン';

  @override
  String get lifetimePlan => '買い切りプラン';

  @override
  String get plusPlan => 'Plusプラン';

  @override
  String get plusMonthlyPlan => 'Plus（月払い）';

  @override
  String get plusYearlyPlan => 'Plus（年払い）';

  @override
  String get activeStatus => '有効';

  @override
  String get activeLifetimeStatus => '有効 • 買い切り';

  @override
  String get canceledStatus => 'キャンセル済み';

  @override
  String get pastDueStatus => '支払い期限切れ';

  @override
  String get trialStatus => 'トライアル中';

  @override
  String trialEndsInDays(int days) {
    return 'トライアル終了まであと$days日';
  }

  @override
  String get trialEnded => 'トライアルは終了しました';

  @override
  String renewsInDays(int days) {
    return 'あと$days日で更新';
  }

  @override
  String accessEndsInDays(int days) {
    return 'あと$days日でアクセス終了';
  }

  @override
  String get subscriptionEnded => 'サブスクリプションは終了しました';

  @override
  String get profile => 'プロフィール';

  @override
  String get errorLoadingProfile => 'プロフィールの読み込みエラー';

  @override
  String get user => 'ユーザー';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp連携済み';

  @override
  String get logExpensesViaWhatsApp => 'WhatsAppメッセージで支出を記録';

  @override
  String get connectWhatsApp => 'WhatsAppと連携';

  @override
  String get newBadge => 'NEW';

  @override
  String get logExpensesInstantly => 'チャットですぐに支出を記録';

  @override
  String get fast => 'スピーディー';

  @override
  String get photo => '写真';

  @override
  String get autoSync => '自動同期';

  @override
  String get naturalLanguage => '自然言語';

  @override
  String get describeExpenseAutomatically => '支出内容を入力するだけ。自動で記録します。';

  @override
  String get snapReceipt => 'レシート撮影';

  @override
  String get snapReceiptDescription => 'レシートを撮影。AIが読み取り、記録します。';

  @override
  String get previous => '前へ';

  @override
  String get next => '次へ';

  @override
  String get overview => '概要';

  @override
  String get activity => 'アクティビティ';

  @override
  String get accountInformation => 'アカウント情報';

  @override
  String get userId => 'ユーザーID';

  @override
  String get recentActivity => '最近のアクティビティ';

  @override
  String get noActivityYet => 'まだアクティビティがありません';

  @override
  String get signOut => 'ログアウト';

  @override
  String get insights => 'インサイト';

  @override
  String get runningTab => '残高推移';

  @override
  String get day30Tab => '30日間';

  @override
  String get longTermTab => '長期';

  @override
  String get scenarioTab => 'シナリオ';

  @override
  String get runningAndDailyBalances => '残高推移と日次バランス';

  @override
  String get budgetVsSpentDescription => '日々の予算と支出、および累計残高の推移。';

  @override
  String get runningBalanceLegend => '残高推移';

  @override
  String get budgetLegend => '予算';

  @override
  String get spentLegend => '支出';

  @override
  String get runningBalanceGuide => '残高推移ガイド';

  @override
  String get runningBalanceIntro => 'このチャートをあなた専用のマネーコーチだと考えてください。何を示し、どう使うかを見ていきましょう。';

  @override
  String get day30LookAhead => '30日間の予測';

  @override
  String get projectedFromTrailing30Days => '過去30日間の平均から予測。';

  @override
  String get projectedSpendingLegend => '予測支出';

  @override
  String get peek30DaysAhead => 'この先30日間を予測';

  @override
  String get day30ForecastIntro => 'この予測は、過去1ヶ月の活動から次の1ヶ月の動きを予測します。お財布の「天気予報」のようなものです。';

  @override
  String get longTermProjection => '長期予測';

  @override
  String get basedOnHistoricalAverages => '過去の平均に基づき、データと共に自動更新されます。';

  @override
  String get month18ProjectionLegend => '18ヶ月予測';

  @override
  String get your18MonthHorizon => 'あなたの18ヶ月の見通し';

  @override
  String get longTermIntro => 'この予測は、あなたの安定した習慣と緩やかな成長予測を組み合わせ、今日の選択が未来にどう繋がるかを示します。';

  @override
  String get aiScenarioPlanning => 'AIシナリオプランニング';

  @override
  String get askAiFinancialAdvisor => '将来の支出が可能か、AIファイナンシャルアドバイザーに尋ねてみましょう';

  @override
  String get canI => '「';

  @override
  String get before => '」までに';

  @override
  String get beforePrefix => '〜までに';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => '日付を選択';

  @override
  String get check => 'チェック';

  @override
  String get enterQuestionAndPickDate => '質問を入力し、日付を選択してください';

  @override
  String get analyzingScenario => 'シナリオを分析中...';

  @override
  String get thisMightTakeAWhile => '少し時間がかかる場合があります';

  @override
  String get whereTheMoneyWent => 'お金の使い道';

  @override
  String get categoryTotalsForSelectedRange => '選択した期間のカテゴリー別合計。';

  @override
  String get scenarioCategoriesGuide => 'カテゴリーを理解する';

  @override
  String get categoryGuideIntro => 'このチャートは、お金がどこへ飛んでいったかを一望する「鳥瞰図」です。電卓なしでの読み解き方をご紹介します。';

  @override
  String get readTheBarChartLikeAPro => '棒グラフをプロのように読み解く';

  @override
  String get categoryChartDesc => '選択期間のカテゴリー別内訳。';

  @override
  String get whyThisViewIsHelpful => 'このビューが役立つ理由';

  @override
  String get categoryWhyHelpfulDesc => '支出の多いカテゴリーをすばやく特定し、時間経過による傾向を発見できます。';

  @override
  String get whatToDoWithTheInsight => 'インサイトの活用法';

  @override
  String get categoryWhatToDoDesc => 'この情報を基に、予算や支出習慣を見直しましょう。';

  @override
  String get scenarioAnalysis => 'シナリオ分析';

  @override
  String get target => '目標';

  @override
  String get quickStats => 'クイック統計';

  @override
  String get currentBalance => '現在の残高';

  @override
  String get projectedNoChange => '予測（変更なし）';

  @override
  String get avgDailyNet => '平均日次純増減';

  @override
  String get noDataAvailable => 'データがありません';

  @override
  String get day => '日';

  @override
  String get close => '閉じる';

  @override
  String get done => '完了';

  @override
  String get whatYouAreSeeing => '表示されている内容';

  @override
  String get whyItMatters => '重要な理由';

  @override
  String get howToRespond => '対処法';

  @override
  String get runningBalanceWhatYouSeeDesc => '「残高推移」は、日々の支出後にどれだけ余裕があるかを示します。日々の棒グラフは、計画（予算）と実際の支出を比較したものです。';

  @override
  String get runningBalanceWhyMattersDesc => 'これは家計の「脈拍チェック」のようなもの。計画を上回っている時に気づけば投資を続けられ、軌道修正が必要な時にも役立ちます。';

  @override
  String get runningBalanceHowToRespondDesc => 'コーチのようにこのチャートを活用しましょう。成果を祝い、必要なら期待値をリセットし、完璧でなく着実な進歩を目指してください。';

  @override
  String get whatTheForecastShows => '予測が示すもの';

  @override
  String get day30WhatShowsDesc => '過去30日間の収支をブレンドし、平均的な1週間を予測します。一時的な大きな支出はならされ、いつものリズムが見えます。';

  @override
  String get day30WhyMattersDesc => '将来を見越した予算は、積極的な家計管理に役立ちます。支出が多い日を予測し、後で慌てる代わりにあらかじめ現金を確保できます。';

  @override
  String get day30HowToPlaySmartDesc => '厳格なルールブックではなく、優しい「後押し」として捉えましょう。実行可能だと感じる小さな修正で計画を調整してください。';

  @override
  String get howTheProjectionWorks => '予測の仕組み';

  @override
  String get longTermHowWorksDesc => '平均的な収支を将来に繰り越し、緩やかな成長予測を加えることで、数ヶ月先も余裕を持った計画かを確認できます。';

  @override
  String get longTermWhyMattersDesc => '長期的な視野は、大きな夢を実現します。緊急時資金、投資、大きな買い物が計画通りに進んでいるか確認しましょう。';

  @override
  String get longTermMovesToConsiderDesc => '将来の決定をリハーサルするためにチャートを使いましょう。今日の小さな調整が、将来の大きな勝利へと繋がります。';

  @override
  String get forMe => '自分用';

  @override
  String get forUs => '共有';

  @override
  String get home => 'ホーム';

  @override
  String get reminder => 'リマインダー';

  @override
  String get analyzingReceipt => 'レシートを分析中...';

  @override
  String get analyzingExpense => '支出を分析中...';

  @override
  String get noExpenseInformationExtracted => '支出情報が抽出されませんでした';

  @override
  String get failedToAnalyzeNoData => '分析失敗：データがありません';

  @override
  String get failedToAnalyze => '分析に失敗しました';

  @override
  String get updateBudget => '予算を更新';

  @override
  String get enterNewTotalDailyBudget => '新しい1日の総予算を入力してください。';

  @override
  String get budgetAmount => '予算額';

  @override
  String get save => '保存';

  @override
  String get enterValidAmountGreaterThan0 => '0より大きい有効な金額を入力してください';

  @override
  String get updatingBudget => '予算を更新中...';

  @override
  String get budgetUpdated => '予算を更新しました';

  @override
  String get failedToUpdateBudget => '予算の更新に失敗しました';

  @override
  String get loggedSuccessfully => '記録しました';

  @override
  String get view => '表示';

  @override
  String get retry => '再試行';

  @override
  String get failedToCapturePhoto => '写真の撮影に失敗しました';

  @override
  String get noSpendingData => '支出データがありません';

  @override
  String get byCategory => 'カテゴリー別';

  @override
  String get noExpensesYet => 'まだ支出がありません';

  @override
  String get startLoggingExpensesToSeeCategories => '支出を記録し始めると、カテゴリーが表示されます';

  @override
  String get selectDateRange => '期間を選択';

  @override
  String get addExpense => '支出を追加';

  @override
  String get describeYourExpense => '支出内容を説明してください（例：「バーガー 500円、コーヒー 300円」）';

  @override
  String get enterExpenseDetails => '支出の詳細を入力...';

  @override
  String get freeFormText => '自由入力';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get transactions => '取引履歴';

  @override
  String get negative => 'マイナス';

  @override
  String get positive => 'プラス';

  @override
  String get spendingBreakdown => '支出内訳';

  @override
  String get spent => '支出';

  @override
  String get today => '今日';

  @override
  String get yesterday => '昨日';

  @override
  String get thisWeek => '今週';

  @override
  String get lastWeek => '先週';

  @override
  String get thisMonth => '今月';

  @override
  String get last30Days => '過去30日間';

  @override
  String get customRange => '期間指定';

  @override
  String get spentToday => '今日の支出（個人）';

  @override
  String get spentYesterday => '昨日の支出（個人）';

  @override
  String get spentThisWeek => '今週の支出（個人）';

  @override
  String get spentLastWeek => '先週の支出（個人）';

  @override
  String get spentThisMonth => '今月の支出（個人）';

  @override
  String get spentLast30Days => '過去30日間の支出（個人）';

  @override
  String get spentCustom => '支出（指定期間）';

  @override
  String get todaysBudget => '今日の予算';

  @override
  String get yesterdaysBudget => '昨日の予算';

  @override
  String get sumOfDailyBudgetsThisWeek => '今週の1日あたり予算合計';

  @override
  String get sumOfDailyBudgetsLastWeek => '先週の1日あたり予算合計';

  @override
  String get sumOfDailyBudgetsThisMonth => '今月の1日あたり予算合計';

  @override
  String get sumOfDailyBudgetsLast30Days => '過去30日間の1日あたり予算合計';

  @override
  String get sumOfDailyBudgetsForSelectedRange => '選択期間の1日あたり予算合計';

  @override
  String get netCashflowToday => '今日のキャッシュフロー';

  @override
  String get netCashflowYesterday => '昨日のキャッシュフロー';

  @override
  String get netCashflowThisWeek => '今週のキャッシュフロー';

  @override
  String get netCashflowLastWeek => '先週のキャッシュフロー';

  @override
  String get netCashflowThisMonth => '今月のキャッシュフロー';

  @override
  String get netCashflowLast30Days => 'キャッシュフロー（過去30日間）';

  @override
  String get netCashflowCustom => 'キャッシュフロー（指定期間）';

  @override
  String get selectCurrency => '通貨を選択';

  @override
  String get showLessCurrencies => '通貨を一部表示';

  @override
  String showAllCurrencies(int count) {
    return 'すべての通貨を表示（他$count件）';
  }

  @override
  String get budget => '予算';

  @override
  String get spentLabel => '支出';

  @override
  String get net => '純増減';

  @override
  String get txn => '件';

  @override
  String get txns => '件';

  @override
  String get pleaseEnterExpenseDetails => '支出の詳細を入力してください';

  @override
  String get userNotLoggedIn => 'ユーザーがログインしていません';

  @override
  String get errorLoadingHouseholds => 'グループの読み込みエラー';

  @override
  String get welcomeToHouseholds => '「グループ」へようこそ';

  @override
  String get householdsDescription => '家族、パートナー、ルームメイトと共有の家計を管理しましょう。予算の追跡、支出の割り勘、お金に関する意思決定を共同で行えます。';

  @override
  String get createHousehold => 'グループを作成';

  @override
  String get joinWithInvite => '招待リンクで参加';

  @override
  String get pleaseUseInvitationLink => 'グループに参加するには招待リンクを使用してください';

  @override
  String get householdName => 'グループ名';

  @override
  String get householdNameHint => '例：山田家、シェアハウス';

  @override
  String get pleaseEnterHouseholdName => 'グループ名を入力してください';

  @override
  String get errorCreatingHousehold => 'グループの作成エラー';

  @override
  String get householdsFeature => 'グループ機能';

  @override
  String get householdsFeatureDescription => 'グループ機能が利用可能になりました！家族、パートナー、ルームメイトと共有の家計を管理しましょう。';

  @override
  String get gotIt => 'OK';

  @override
  String get confirmExpense => '支出の確認';

  @override
  String get expenseDetails => '支出の詳細';

  @override
  String get details => '詳細';

  @override
  String get category => 'カテゴリー';

  @override
  String get currency => '通貨';

  @override
  String get date => '日付';

  @override
  String get time => '時間';

  @override
  String get notes => 'メモ';

  @override
  String get receipt => 'レシート';

  @override
  String get saveExpense => '支出を保存';

  @override
  String get shareWithHousehold => '世帯と共有';

  @override
  String get loadingHouseholdMembers => 'グループメンバーを読み込み中...';

  @override
  String get selectHouseholdToConfigureSplit => '割り勘を設定するグループを選択';

  @override
  String get currencyManagedByHousehold => '通貨はグループによって管理されており、変更できません';

  @override
  String get currencyCannotBeChanged => 'グループと共有する場合、通貨は変更できません';

  @override
  String get failedToLoadImage => '画像の読み込みに失敗しました';

  @override
  String get editAmount => '金額を編集';

  @override
  String get amount => '金額';

  @override
  String get editNotes => 'メモを編集';

  @override
  String get addANote => 'メモを追加...';

  @override
  String get noMembersFoundInHousehold => 'グループにメンバーが見つかりません';

  @override
  String get errorLoadingMembers => 'メンバーの読み込みエラー';

  @override
  String get noExpenseToSave => '保存する支出がありません';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return '支出を保存・共有しました$splitInfo！';
  }

  @override
  String get expenseSaved => '支出を保存しました！';

  @override
  String failedToSave(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return '通貨設定の同期に失敗しました: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => '通貨を更新しました';

  @override
  String retryFailed(Object error) {
    return '再試行に失敗しました: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return '$category に $currencySymbol$amount を使いました';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => '新しい1日の総予算を入力してください。';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'グループ機能にアクセスするにはログインしてください';

  @override
  String get quickActions => 'クイック操作';

  @override
  String get members => 'メンバー';

  @override
  String get invites => '招待';

  @override
  String get errorLoadingExpenses => '支出の読み込みエラー';

  @override
  String get budgets => '予算';

  @override
  String get loadingHousehold => 'グループを読み込み中...';

  @override
  String get remaining => '残り';

  @override
  String get overBudget => '予算オーバー';

  @override
  String get sharedBudgets => '共有予算';

  @override
  String get netPosition => '収支状況';

  @override
  String get spentByHousehold => 'グループの支出';

  @override
  String get memberSpending => 'メンバー別支出';

  @override
  String get spentByHouseholdTooltip => '選択した期間にすべてのグループメンバーが支出した合計金額を示します。グループのメンバーによって記録されたすべての共有支出が含まれます。';

  @override
  String get manageMoneyTogether => 'パートナー、家族、ルームメイトと、一つの共有スペースで一緒にお金を管理しましょう。';

  @override
  String get sharedBudgetsExpenses => '予算と支出の共有';

  @override
  String get sharedBudgetsExpensesDesc => '予算を設定し、支出を追跡し、グループのお金がリアルタイムでどこに使われているかを確認できます。';

  @override
  String get smartExpenseSplitting => 'スマートな割り勘';

  @override
  String get smartExpenseSplittingDesc => '均等、割合、カスタム金額など、柔軟な割り勘オプションで「誰がいくら払うか」を自動計算します。';

  @override
  String get stayInSync => '常に同期';

  @override
  String get stayInSyncDesc => '支出が追加された時、予算に達した時、または清算が必要な時に通知を受け取れます。';

  @override
  String get householdSettings => 'グループ設定';

  @override
  String get householdNotFound => 'グループが見つかりません';

  @override
  String get coverPhoto => 'カバー写真';

  @override
  String get changeCoverPhoto => 'カバー写真を変更';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get errorLoadingHousehold => 'グループの読み込みエラー';

  @override
  String get householdUpdatedSuccessfully => 'グループを更新しました';

  @override
  String get failedToUpdateHousehold => 'グループの更新に失敗しました';

  @override
  String get inviteMember => 'メンバーを招待';

  @override
  String get removeMember => 'メンバーを削除';

  @override
  String get remove => '削除';

  @override
  String get confirmRemoveMember => '本当に削除しますか？';

  @override
  String get updatedMemberRole => 'メンバーの役割を更新しました';

  @override
  String get unknown => '不明';

  @override
  String get makeAdmin => '管理者に設定';

  @override
  String get makeMember => 'メンバーに設定';

  @override
  String get invitations => '招待';

  @override
  String get errorLoadingInvites => '招待の読み込みエラー';

  @override
  String get createInvitation => '招待を作成';

  @override
  String get pendingInvitations => '保留中の招待';

  @override
  String get noPendingInvitations => '保留中の招待はありません';

  @override
  String get invitationHistory => '招待履歴';

  @override
  String get noInvitationHistory => '招待履歴はありません';

  @override
  String get emailOptional => 'メールアドレス（任意）';

  @override
  String get friendEmailExample => 'friend@example.com';

  @override
  String get personalMessageOptional => 'パーソナルメッセージ（任意）';

  @override
  String get joinHouseholdBudget => '私たちのグループ予算に参加しませんか？';

  @override
  String get expiresIn => '有効期限';

  @override
  String get oneDay => '1日';

  @override
  String get threeDays => '3日間';

  @override
  String get sevenDays => '7日間';

  @override
  String get fourteenDays => '14日間';

  @override
  String get thirtyDays => '30日間';

  @override
  String get unlimited => '無制限';

  @override
  String get create => '作成';

  @override
  String get invitationCreatedSuccessfully => '招待を作成しました';

  @override
  String get inviteLinkCopiedToClipboard => '招待リンクをクリップボードにコピーしました！';

  @override
  String get errorCreatingInvite => '招待の作成エラー';

  @override
  String get revokeInvitation => '招待を取り消す';

  @override
  String get confirmRevokeInvitation => 'この招待を本当取り消しますか？';

  @override
  String get revoke => '取り消す';

  @override
  String get invitationRevoked => '招待を取り消しました';

  @override
  String get errorRevokingInvite => '招待の取り消しエラー';

  @override
  String get anyoneWithLink => 'リンクを知っている全員';

  @override
  String get noExpiry => '有効期限なし';

  @override
  String get expired => '期限切れ';

  @override
  String get expires => '有効期限';

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String get selectCoverImage => 'カバー画像を選択';

  @override
  String get failedToLoadImages => '画像の読み込みに失敗しました';

  @override
  String get chooseFromGallery => 'ギャラリーから選択';

  @override
  String get failedToLoad => '読み込み失敗';

  @override
  String get imageTooLarge => '画像サイズが大きすぎます';

  @override
  String get maxIs => '最大';

  @override
  String get unsupportedFileFormat => 'サポートされていないファイル形式です。JPG、PNG、またはWebPを使用してください。';

  @override
  String get cropCoverImage => 'カバー画像を切り抜く';

  @override
  String get editBudget => '予算を編集';

  @override
  String get budgetDetails => '予算の詳細';

  @override
  String get budgetName => '予算名';

  @override
  String get period => '期間';

  @override
  String get alertThresholds => 'アラートしきい値';

  @override
  String get warningThreshold => '警告しきい値（%）';

  @override
  String get alertThreshold => 'アラートしきい値（%）';

  @override
  String get warningThresholdHelper => '予算の使用率がこの割合に達すると警告します';

  @override
  String get alertThresholdHelper => 'この割合で重大なアラートを通知します';

  @override
  String get budgetStatus => '予算ステータス';

  @override
  String get active => 'アクティブ';

  @override
  String get inactive => '無効';

  @override
  String get deletingBudget => '予算を削除中...';

  @override
  String get savingChanges => '変更を保存中...';

  @override
  String get budgetNameCannotBeEmpty => '予算名を入力してください';

  @override
  String get pleaseEnterValidAmount => '有効な金額を入力してください';

  @override
  String get warningThresholdRange => '警告しきい値は0から100の間で設定してください';

  @override
  String get alertThresholdRange => 'アラートしきい値は0から100の間で設定してください';

  @override
  String get warningThresholdLessThanAlert => '警告しきい値は、アラートしきい値以下に設定してください';

  @override
  String get deleteBudget => '予算を削除';

  @override
  String get confirmDeleteBudget => '本当に削除しますか？';

  @override
  String get thisActionCannotBeUndone => 'この操作は元に戻せません';

  @override
  String get budgetUpdatedSuccessfully => '予算を更新しました';

  @override
  String get budgetDeletedSuccessfully => '予算を削除しました';

  @override
  String get categoryTransfers => '振替';

  @override
  String get categoryShopping => 'ショッピング';

  @override
  String get categoryUtilities => '公共料金';

  @override
  String get categoryEntertainment => '娯楽';

  @override
  String get categoryEntertainmentSubscriptions => 'エンタメ（サブスク）';

  @override
  String get categoryRestaurants => '外食';

  @override
  String get categoryFood => '食費';

  @override
  String get categoryGroceries => '食料品';

  @override
  String get categoryTransport => '交通費';

  @override
  String get categoryTransportation => '交通費';

  @override
  String get categoryTravel => '旅行';

  @override
  String get categoryFlights => '航空券';

  @override
  String get categoryVacation => '休暇';

  @override
  String get categoryHealth => '健康';

  @override
  String get categoryMedical => '医療費';

  @override
  String get categoryText => 'テキスト';

  @override
  String get categoryEducation => '教育';

  @override
  String get categoryTuition => '学費';

  @override
  String get categorySubscriptions => 'サブスクリプション';

  @override
  String get categoryServices => 'サービス';

  @override
  String get categoryHousing => '住居費';

  @override
  String get categoryRent => '家賃';

  @override
  String get categoryMortgage => '住宅ローン';

  @override
  String get categoryBills => '請求';

  @override
  String get categoryInsurance => '保険';

  @override
  String get categorySavings => '貯金';

  @override
  String get categoryInvestment => '投資';

  @override
  String get categoryInvestments => '投資';

  @override
  String get categoryIncome => '収入';

  @override
  String get categorySalary => '給与';

  @override
  String get categoryBonus => 'ボーナス';

  @override
  String get categoryPets => 'ペット';

  @override
  String get categoryKids => '子供';

  @override
  String get categoryFamily => '家族';

  @override
  String get categoryGifts => 'ギフト';

  @override
  String get categoryCharity => '寄付';

  @override
  String get categoryFees => '手数料';

  @override
  String get categoryLoan => 'ローン';

  @override
  String get categoryLoans => 'ローン';

  @override
  String get categoryDebt => '負債';

  @override
  String get categoryPersonalCare => '日用品';

  @override
  String get categoryBeauty => '美容';

  @override
  String get categoryMisc => '雑費';

  @override
  String get categoryUncategorized => '未分類';

  @override
  String get deleteBudgetCannotBeUndone => 'この操作は元に戻せません';

  @override
  String get delete => '削除';

  @override
  String get failedToDeleteBudget => '予算の削除に失敗しました';

  @override
  String get owner => '所有者';

  @override
  String get admin => '管理者';

  @override
  String get member => 'メンバー';

  @override
  String get pending => '保留中';

  @override
  String get accepted => '承認済み';

  @override
  String get revoked => '取り消し済み';

  @override
  String get tapToChangeCover => 'タップしてカバーを変更';

  @override
  String get personalMessageHint => '招待する人へのメッセージ（例：「私たちのグループ予算に参加しませんか？」）';

  @override
  String get invitationExpiresIn => '招待の有効期限';

  @override
  String daysCount(int days) {
    return '$days日間';
  }

  @override
  String get createHouseholdDescription => '家族やルームメイトと予算や支出を追跡するための共有スペースを作成します。';

  @override
  String get uploadingImage => '画像をアップロード中...';

  @override
  String get creating => '作成中...';

  @override
  String get generatingInvite => '招待を作成中...';

  @override
  String get pleaseSelectValidCurrency => '有効なグループの通貨を選択してください';

  @override
  String nameMaxLength(int max) {
    return '名前は$max文字未満である必要があります';
  }

  @override
  String get createHouseholdPage => 'グループ作成ページ';

  @override
  String get invitationPersonalMessageInput => '招待メッセージ入力';

  @override
  String get householdNameInput => 'グループ名入力';

  @override
  String get invitationExpirationSelector => '招待の有効期限セレクター';

  @override
  String get unlimitedExpiration => '無期限';

  @override
  String daysExpiration(int days) {
    return '$days日間の有効期限';
  }

  @override
  String get householdInformation => 'グループ情報';

  @override
  String get creatingHousehold => 'グループを作成中';

  @override
  String get createHouseholdButton => 'グループ作成ボタン';

  @override
  String get searchExpenses => '支出を検索...';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get allCategories => 'すべてのカテゴリー';

  @override
  String get allMembers => 'すべてのメンバー';

  @override
  String get balanceSummary => '残高サマリー';

  @override
  String get youAreOwed => 'あなたが受け取る額';

  @override
  String get youOwe => 'あなたが支払う額';

  @override
  String get youOweOthers => '他の人への未払い';

  @override
  String get othersOweYou => '他の人からの未受け取り';

  @override
  String get viewDetails => '詳細を表示';

  @override
  String get settleUp => '清算する';

  @override
  String get markExpensesAsSettled => '支出を「清算済み」として残高を更新します';

  @override
  String get whoAreYouSettlingWith => '誰と清算しますか？';

  @override
  String get selectMember => 'メンバーを選択';

  @override
  String get amountToSettle => '清算金額';

  @override
  String get howDidYouSettle => '清算方法は？';

  @override
  String get cash => '現金';

  @override
  String get paidInCash => '現金で支払い';

  @override
  String get bankTransfer => '銀行振込';

  @override
  String get transferredViaBank => '銀行振込で送金';

  @override
  String get mobilePayment => 'モバイル決済';

  @override
  String get venmoPaypalEtc => 'PayPay、LINE Payなど';

  @override
  String get search => '検索';

  @override
  String get noData => 'データなし';

  @override
  String get filterTransactions => '取引履歴をフィルター';

  @override
  String get noTransactionsFound => '取引履歴が見つかりません';

  @override
  String get failedToLoadHouseholdTransactions => 'グループの取引履歴の読み込みに失敗しました';

  @override
  String get reset => 'リセット';

  @override
  String get apply => '適用';

  @override
  String get expenses => '支出';

  @override
  String get dateRange => '期間';

  @override
  String get noMatchingExpenses => '一致する支出がありません';

  @override
  String get startLoggingExpenses => '支出を記録し始めると、ここに表示されます';

  @override
  String get tryAdjustingFilters => 'フィルターを調整してみてください';

  @override
  String get split => '割り勘';

  @override
  String get note => 'メモ';

  @override
  String get currencyCannotBeChangedWhenSharing => 'グループと共有する場合、通貨は変更できません';

  @override
  String get createBudget => '予算を作成';

  @override
  String get pleaseEnterABudgetName => '予算名を入力してください';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => '0より大きい有効な金額を入力してください';

  @override
  String get warningThresholdMustBeBetween0And100 => '警告しきい値は0%から100%の間で設定してください';

  @override
  String get alertThresholdMustBeBetween0And100 => 'アラートしきい値は0%から100%の間で設定してください';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => '警告しきい値は、アラートしきい値以下に設定してください';

  @override
  String get budgetCreatedSuccessfully => '予算を作成しました！';

  @override
  String get failedToCreateBudget => '予算の作成に失敗しました';

  @override
  String get groceriesRentEntertainment => '例：食料品、家賃、娯楽';

  @override
  String get budgetType => '予算タイプ';

  @override
  String get sharedWithAllHouseholdMembers => 'すべてのグループメンバーと共有';

  @override
  String get personalBudgetForYourExpensesOnly => 'あなた個人の支出のみを対象とする予算';

  @override
  String get countSplitPortionOnly => '割り勘の自分の負担分のみ集計';

  @override
  String get onlyCountYourPortionOfSplitExpenses => '割り勘した支出のうち、あなたの負担分のみをこの予算に計上します';

  @override
  String get joinHousehold => 'グループに参加';

  @override
  String get joinAHousehold => 'グループに参加する';

  @override
  String get enterYourInvitationLinkToJoin => '共有の財務スペースに参加するため\n招待リンクを入力してください';

  @override
  String get pasteTheInvitationLinkYouReceived => 'グループメンバーから受け取った招待リンクを貼り付けてください';

  @override
  String get pasteInvitationLink => '招待リンクを貼り付け';

  @override
  String get pleaseEnterAnInvitationLink => '招待リンクを入力してください';

  @override
  String get pleaseEnterAValidInvitationLink => '有効な招待リンクを入力してください';

  @override
  String get paste => '貼り付け';

  @override
  String get validating => '検証中...';

  @override
  String get continueAction => '続ける';

  @override
  String get welcomeAboard => 'ようこそ！';

  @override
  String get youreNowPartOfTheHousehold => 'あなたは今グループのメンバーです。\nさっそく家計の管理を始めましょう！';

  @override
  String get thisWillOnlyTakeAMoment => 'すぐに完了します';

  @override
  String get unableToJoin => '参加できません';

  @override
  String get tryAgain => '再試行';

  @override
  String get goToHousehold => 'グループへ';

  @override
  String get expiresSoon => '間もなく期限切れ';

  @override
  String invitationValidUntil(String formattedDate) {
    return '招待は$formattedDateまで有効です';
  }

  @override
  String get whatYoullGet => '得られるもの';

  @override
  String get viewSharedBudgetsAndExpenses => '共有の予算と支出を表示';

  @override
  String get trackHouseholdFinancialHealth => 'グループの財務健全性を追跡';

  @override
  String get collaborateOnFinancialDecisions => '財務判断を共同で行う';

  @override
  String get household => '世帯';

  @override
  String get viewAll => 'すべて表示';

  @override
  String get manage => '管理';

  @override
  String get noBudgetsYet => 'まだ予算がありません';

  @override
  String get createSharedBudgetDescription => '共有予算を作成して、支出を一緒に追跡しましょう';

  @override
  String get errorLoadingBudgets => '予算の読み込みエラー';

  @override
  String get recentSplits => '最近の割り勘';

  @override
  String get invite => '招待';

  @override
  String get last6Months => '過去6ヶ月';

  @override
  String get thisYear => '今年';

  @override
  String get allTime => '全期間';

  @override
  String nameMinLength(int min) {
    return '名前は$min文字以上である必要があります';
  }

  @override
  String get splitExpense => '支出を割り勘';

  @override
  String get percent => '割合 (%)';

  @override
  String get splitShare => '比率';

  @override
  String get owes => '負担額';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return '分割後の合計金額は $currency$amount になる必要があります';
  }

  @override
  String get percentagesMustTotal100 => '割合の合計は100%になる必要があります';

  @override
  String get eachPersonMustHaveAtLeast1Share => '各メンバーは最低1の比率を持つ必要があります';

  @override
  String get whatsappVerified => 'WhatsApp 認証済み';

  @override
  String get whatsappVerification => 'WhatsApp 認証';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'お使いのWhatsApp番号がアカウントに正常に連携されました';

  @override
  String get verifyingYourWhatsAppNumber => 'WhatsApp番号を認証しています...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'WhatsAppに届いた6桁のコードを入力してください';

  @override
  String get pleaseEnterThe6DigitVerificationCode => '6桁の認証コードを入力してください';

  @override
  String get failedToVerifyCode => 'コードの認証に失敗しました';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'コードの認証に失敗しました。もう一度お試しください。';

  @override
  String get codeAutoFilledFromVerificationLink => '認証リンクからコードが自動入力されました';

  @override
  String get verify => '認証';

  @override
  String get verifying => '認証中...';

  @override
  String get avatarStudio => 'アバタースタジオ';

  @override
  String get preview => 'プレビュー';

  @override
  String get colors => 'カラー';

  @override
  String get randomize => 'ランダム';

  @override
  String get saveAvatar => 'アバターを保存';

  @override
  String get saving => '保存中...';

  @override
  String get skipForNow => '今はスキップ';

  @override
  String get selectColor => '色を選択';

  @override
  String get failedToSaveAvatar => 'アバターの保存に失敗しました';

  @override
  String get hair => '髪';

  @override
  String get eyes => '目';

  @override
  String get mouth => '口';

  @override
  String get background => '背景';

  @override
  String get face => '顔';

  @override
  String get ears => '耳';

  @override
  String get shirts => 'トップス';

  @override
  String get brow => '眉';

  @override
  String get nose => '鼻';

  @override
  String get blush => 'チーク';

  @override
  String get accessories => 'アクセサリー';

  @override
  String get stars => '星';

  @override
  String get currencyIsManagedByHousehold => '通貨はグループによって管理されており、変更できません';

  @override
  String get buyALaptop => '15万円のPCを購入する';

  @override
  String get selectTargetDate => '目標日を選択';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return '$dateまでに$actionできますか？';
  }

  @override
  String get scenarioDateFormat => 'yyyy/MM/dd';

  @override
  String analysisFailed(String error) {
    return '分析失敗: $error';
  }

  @override
  String get leftHandChamps => '左側の上位項目はあなたの「ヘビー級」支出です。すぐに見直すべき候補です。';

  @override
  String get smallButFrequent => '「少額だが頻繁」なカテゴリーは、時間と共にあなどれなくなる習慣を示唆しています。';

  @override
  String get colorMatches => 'ホームタブと同じ色を使用しているため、直感的に理解できます。';

  @override
  String get planningNewGoal => '新しい目標を計画中ですか？「楽しみ」を削らずに節約できるカテゴリーを見つけましょう。';

  @override
  String get eyeingTreatYourself => '「ご褒美」月間を狙っていますか？安全に調整できる項目を確認しましょう。';

  @override
  String get doubleCheckTagging => '新しい支出が正しくタグ付けされたか、幽霊支出がないか、再確認に使いましょう。';

  @override
  String get slideHighBar => '高い棒グラフは、小さな上限を設けたり、より安価な代替品に切り替えたりして、少し下げてみましょう。';

  @override
  String get nonNegotiable => '（家賃など）交渉の余地がない項目は、戦うのではなく、それを前提に計画を立てましょう。';

  @override
  String get revisitAfterScenario => 'シナリオ実行後に再訪し、調整がうまく機能しているか確認しましょう。';

  @override
  String get purpleLineCushion => '紫の線：各日の終わりに残る「余裕」。上昇ラインは勢いがついている証拠です。';

  @override
  String get blueBarsBudget => '青い棒：その日に設定した予算。';

  @override
  String get redBarsSpent => '赤い棒：実際に口座から出た支出。';

  @override
  String get lineTrendingUpward => '上昇トレンドの線 = 貯蓄目標に回せる余裕資金がある。';

  @override
  String get flatDippingLine => '横ばいまたは下降中の線 = 一時停止し、高額な項目を見直す時。';

  @override
  String get sharpDrops => '急激な落ち込みは、計画外の購入と一致することが多いです。タップして詳細を確認しましょう。';

  @override
  String get lineRisingDays => '線が数日上昇していますか？少し多めに貯蓄や借入返済に回すことを検討しましょう。';

  @override
  String get lineDippingWeekend => '忙しい週末の後に線が下がっていますか？小さな裁量支出を削って、これからの日々でリバランスしましょう。';

  @override
  String get feelStuckRed => '赤字から抜け出せないと感じますか？ホームタブで予算を見直しましょう。小さな調整が大きな結果に繋がります。';

  @override
  String get thirtyDayForecastDesc => 'この予測は、過去1ヶ月の活動から次の1ヶ月の動きを予測します。お財布の「天気予報」のようなものです。';

  @override
  String get greenLineExpected => '緑の線 = 来月が先月と同じように推移した場合の予想日次支出。';

  @override
  String get spikesHighlight => 'スパイク（突出）は、習慣的に支出が増える週（例：金曜のテイクアウト）を示します。';

  @override
  String get forecastUpdates => '新しい取引を記録すると、予測は自動で更新されます。リフレッシュは不要です。';

  @override
  String get spotExpensivePatterns => '支出の多いパターンを早期に発見し、それが来る前に小さなバッファを準備しましょう。';

  @override
  String get catchQuieterWeeks => '支出が少ない週を見つけて、余裕資金を貯蓄や借入返済に回しましょう。';

  @override
  String get timeRecurringPayments => 'このインサイトを、定期的な支払いやサブスク、チャージのタイミング調整に役立てましょう。';

  @override
  String get bigSpikeComing => '大きな支出の波が来ますか？安価な選択肢を予約したり、柔軟な支出を穏やかな日にずらしたりしましょう。';

  @override
  String get forecastDipping => '予測が下降していますか？追加の貯蓄振替をスケジュールして、自分にご褒美をあげましょう。';

  @override
  String get forecastLooksOff => '予測がずれているように見える場合は、ホームタブでカテゴリーを見直し、間違ったラベルを修正しましょう。';

  @override
  String get greenLineTrends => '緑の線は、あなたの典型的な貯蓄率と共に推移します。上昇の勢いは、目標が順調に達成に向かっていることを意味します。';

  @override
  String get lineDipsSignals => '線が下降する場合、将来的に支出が収入を上回る傾向にある月があることを示しています。';

  @override
  String get largeGoalsDebts => '大きな目標や借入は、ホームタブでタグ付けすると予測に含まれます。';

  @override
  String get upwardSlope => '上り坂ですか？素晴らしい！退職金や旅行の貯蓄を増やすことを検討しましょう。';

  @override
  String get flatSlipping => '横ばいか、滑り落ちていますか？雪だるま式に増える前に、予算を調整したり、収入源を増やしたりする時です。';

  @override
  String get watchSeasonalTrends => '季節的なトレンドに注意しましょう。休日、学期、年会費の更新などが、ここに最初に現れることが多いです。 ';

  @override
  String get schedulePaymentIncreases => '曲線が上昇している時に、ローンの返済額を緩やかに増やすスケジュールを立てましょう。';

  @override
  String get planAheadDips => '目的別積立金を確保したり、任意の支出を削ったりして、下降に備えて計画を立てましょう。';

  @override
  String get checkProjectionMonthly => '毎月予測をチェックして、長期的なゲームを楽しく、柔軟に保ちましょう。';

  @override
  String get categoryHealthcare => '医療・健康';

  @override
  String get categoryOther => 'その他';

  @override
  String get deleteExpense => '支出を削除';

  @override
  String get confirmDeleteExpense => 'この支出を本当に削除しますか？この操作は元に戻せません。';

  @override
  String get expenseDeletedSuccessfully => '支出を削除しました';

  @override
  String get failedToDeleteExpense => '支出の削除に失敗しました';

  @override
  String get expenseNotFoundOrDeleted => '支出が見つからないか、すでに削除されています';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => '管理者とオーナーのみが世帯設定を編集できます';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => '管理者とオーナーのみが招待を作成できます';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'グループ「$householdName」の招待を共有';
  }

  @override
  String get shareInvitation => '招待を共有';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'グループ「$householdName」が作成されました';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'グループ「$householdName」が作成されました！';
  }

  @override
  String get invitationLink => '招待リンク';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return '招待リンク：$inviteUrl';
  }

  @override
  String get copyInvitationLink => '招待リンクをコピー';

  @override
  String get copyInvitationLinkToClipboard => '招待リンクをクリップボードにコピー';

  @override
  String get shareInvitationLink => '招待リンクを共有';

  @override
  String get share => '共有';

  @override
  String get closeShareSheet => '共有シートを閉じる';

  @override
  String get invitationLinkCopiedToClipboard => '招待リンクをクリップボードにコピーしました！';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Monekoで私のグループ「$householdName」に参加してください！\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Monekoで私のグループに参加してください';

  @override
  String get zeroAmount => '0.00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => '通知設定';

  @override
  String get budgetBoop => '予算ツンツン';

  @override
  String get getGentleReminder => 'このしきい値に達したときに優しいリマインダーを受け取る';

  @override
  String get purrSuasiveNudge => 'ゴロゴロ・アラート';

  @override
  String get getStrongerNudge => 'このしきい値に達したときにより強いナッジを受け取る';

  @override
  String get createBudgetButton => '予算を作成';

  @override
  String get daily => '毎日';

  @override
  String get weekly => '毎週';

  @override
  String get monthly => '毎月';

  @override
  String get yearly => '毎年';

  @override
  String get householdBudgetType => 'グループ予算';

  @override
  String get personalBudgetType => '個人予算';

  @override
  String joinHouseholdName(String householdName) {
    return '「$householdName」に参加する';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'グループプレビュー：$householdName、招待者：$inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return '$inviterEmailからの招待';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'この招待は$formattedDateに期限切れとなります';
  }

  @override
  String get invitationValidUntilLabel => '有効期限';

  @override
  String get personalMessageFromInviter => '招待者からの個人メッセージ';

  @override
  String get messageFromInviter => '招待者からのメッセージ';

  @override
  String get joiningHousehold => 'グループに参加中...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'エラー：$errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => '予期しないエラーが発生しました';

  @override
  String get invalidInvitationLinkFormat => '無効な招待リンク形式です';

  @override
  String get invalidOrExpiredInvitation => '無効または期限切れの招待です';

  @override
  String get tomorrow => '明日';

  @override
  String inDays(int days) {
    return '$days日後';
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
    return '$name にリマインド';
  }

  @override
  String get sendFriendlySpendingReminder => 'やさしい支出リマインドを送信';

  @override
  String get addMessageOptional => 'メッセージを追加（任意）';

  @override
  String get messageHintExample => '例：『お財布を休ませてあげよう！』';

  @override
  String get sendReminder => 'リマインドを送信';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return '$name に再度リマインドを送信するには、24時間お待ちください';
  }

  @override
  String reminderSentToName(String name) {
    return '$name にリマインドを送信しました 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'リマインドの送信に失敗しました。もう一度お試しください。';

  @override
  String get income => '収入';

  @override
  String get addIncome => '収入を追加';

  @override
  String get incomeAdded => '収入が正常に追加されました';

  @override
  String get noIncome => 'まだ収入がありません';

  @override
  String get noIncomeDescription => '世帯の財務健全性を追跡するために収入を記録してください';

  @override
  String get totalIncome => '総収入';

  @override
  String get monthToDate => '月累計';

  @override
  String get yearToDate => '年累計';

  @override
  String get failedToLoadIncome => '収入の読み込みに失敗しました';

  @override
  String get incomeAcknowledged => '収入を確認しました';

  @override
  String get acknowledge => '確認';

  @override
  String get acknowledged => '確認済み';

  @override
  String get source => '収入源';

  @override
  String get sourceHint => '例：雇用主、取引先';

  @override
  String get me => '自分';

  @override
  String get partner => 'パートナー';

  @override
  String get privacyScope => 'プライバシー';

  @override
  String get privacyFull => 'すべての詳細';

  @override
  String get privacyBalancesOnly => '残高のみ';

  @override
  String get privacyPrivate => '非公開';

  @override
  String get privacyFullExplanation => 'パートナーは金額・収入源・説明を含むすべての詳細を閲覧できます。';

  @override
  String get privacyBalancesOnlyExplanation => 'パートナーは合計のみ確認でき、詳細（収入源・説明）は表示されません。';

  @override
  String get privacyPrivateExplanation => 'あなたのみがこの収入を見ることができます。世帯の合計に貢献しますが、パートナーは詳細を見ることができません。';

  @override
  String get incomeSalary => '給与';

  @override
  String get incomeFreelance => 'フリーランス';

  @override
  String get incomeInvestment => '投資';

  @override
  String get incomeRefund => '返金';

  @override
  String get incomeGift => '贈り物';

  @override
  String get incomeBonus => 'ボーナス';

  @override
  String get incomeRental => '賃貸収入';

  @override
  String get incomeOther => 'その他';

  @override
  String get goals => '目標';

  @override
  String get createGoal => '目標を作成';

  @override
  String get goalCreated => '目標が正常に作成されました';

  @override
  String get goalTitle => '目標タイトル';

  @override
  String get enterGoalTitle => '目標タイトルを入力';

  @override
  String get pleaseEnterTitle => 'タイトルを入力してください';

  @override
  String get pleaseEnterAmount => '金額を入力してください';

  @override
  String get invalidAmount => '0より大きい有効な金額を入力してください';

  @override
  String get targetAmount => '目標金額';

  @override
  String get currentAmount => '現在の金額';

  @override
  String get targetDate => '目標日';

  @override
  String get description => '説明';

  @override
  String get descriptionHint => 'メモ（任意）';

  @override
  String get savings => '貯蓄';

  @override
  String get paydown => '返済';

  @override
  String get all => 'すべて';

  @override
  String get completed => '完了';

  @override
  String get offTrack => '計画より遅延';

  @override
  String get onTrack => '計画通り';

  @override
  String get complete => '完了にする';

  @override
  String get overallProgress => '全体の進捗';

  @override
  String get totalGoals => '総目標数';

  @override
  String get noGoals => 'まだ目標がありません。最初の目標を作成して始めましょう！';

  @override
  String get noSavingsGoals => 'まだ貯蓄目標がありません。作成して貯蓄を始めましょう！';

  @override
  String get noPaydownGoals => 'まだ返済目標がありません。作成して借金削減を始めましょう！';

  @override
  String get goalAcknowledged => '目標を確認しました';

  @override
  String get balancesOnly => '残高のみ';

  @override
  String get contribution => '貢献';

  @override
  String get withdrawal => '引き出し';

  @override
  String get interest => '利息';

  @override
  String get adjustment => '調整';

  @override
  String get addContribution => '貢献を追加';

  @override
  String get contributionAmount => '貢献額';

  @override
  String get contributionType => 'タイプ';

  @override
  String get contributionAdded => '貢献が正常に追加されました';
}
