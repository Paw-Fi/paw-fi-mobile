// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kanuri (`kr`).
class AppLocalizationsKr extends AppLocalizations {
  AppLocalizationsKr([String locale = 'kr']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => '아직 지출 없음';

  @override
  String get loginWelcomeBack => '다시 만나서 반가워요!';

  @override
  String get orContinueWithEmail => '또는 이메일로 계속하기';

  @override
  String get emailAddress => '이메일 주소';

  @override
  String get password => '비밀번호';

  @override
  String get forgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get signIn => '로그인';

  @override
  String get newToMoneko => 'Moneko가 처음이신가요?';

  @override
  String get createAccount => '회원가입';

  @override
  String get resetYourPassword => '비밀번호 재설정';

  @override
  String get email => '이메일';

  @override
  String get exampleEmail => 'you@example.com';

  @override
  String get cancel => '취소';

  @override
  String get sendResetLink => '재설정 링크 보내기';

  @override
  String get passwordResetEmailSent => '비밀번호 재설정 이메일을 보냈습니다. 받은 편지함을 확인해주세요.';

  @override
  String get enterValidEmail => '올바른 이메일 주소를 입력해주세요.';

  @override
  String passwordMinLength(int min) {
    return '비밀번호는 최소 $min자 이상이어야 합니다.';
  }

  @override
  String fullNameMinLength(int min) {
    return '이름은 최소 $min자 이상이어야 합니다.';
  }

  @override
  String get createYourAccount => '회원가입';

  @override
  String get fullName => '이름';

  @override
  String get createPassword => '비밀번호 설정';

  @override
  String get passwordComplexityRequirement => '비밀번호는 영문 대문자, 소문자, 숫자를 각각 하나 이상 포함해야 합니다.';

  @override
  String get passwordRequirementShort => '비밀번호: 8자 이상 (영문 대/소문자, 숫자 포함)';

  @override
  String get termsAgreement => '회원가입 시 서비스 이용약관 및 개인정보 처리방침에 동의하는 것으로 간주됩니다.';

  @override
  String get alreadyHaveAccount => '이미 계정이 있으신가요?';

  @override
  String get signInLower => '로그인';

  @override
  String get verificationCodeSent => '인증번호가 발송되었습니다.';

  @override
  String get verifyYourEmail => '이메일 인증';

  @override
  String verificationEmailSentTo(String email) {
    return '$email(으)로 6자리 인증번호를 보냈습니다.';
  }

  @override
  String get enterCompleteCode => '6자리 인증번호를 모두 입력해주세요.';

  @override
  String get invalidVerificationCode => '유효하지 않은 인증번호입니다.';

  @override
  String get verificationCodeExpired => '인증번호 유효 시간이 만료되었습니다. 새 인증번호를 요청해주세요.';

  @override
  String get verifyEmail => '이메일 인증하기';

  @override
  String get didntReceiveTheCode => '인증번호를 받지 못하셨나요? 스팸함을 확인하거나';

  @override
  String resendInSeconds(int seconds) {
    return '$seconds초 후 재전송';
  }

  @override
  String get resendVerificationEmail => '인증 이메일 재전송';

  @override
  String get continueWithGoogle => 'Google로 계속하기';

  @override
  String get signingInWithGoogle => 'Google로 로그인 중...';

  @override
  String get error => '오류';

  @override
  String get anErrorOccurred => '오류가 발생했습니다.';

  @override
  String get unknownError => '알 수 없는 오류';

  @override
  String get goToHome => '홈으로 가기';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ 결제 완료! 구독 정보를 확인 중입니다...';

  @override
  String get paymentFailed => '결제 실패';

  @override
  String get paymentCanceled => 'ℹ️ 결제가 취소되었습니다.';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp 인증 완료!';

  @override
  String get settings => '설정';

  @override
  String get enableNotificationsInSettings => '기기 설정에서 Moneko 알림을 활성화해주세요.';

  @override
  String get appearance => '화면 설정';

  @override
  String get darkMode => '다크 모드';

  @override
  String get notifications => '알림';

  @override
  String get pushNotifications => '푸시 알림';

  @override
  String get receiveAlertsAndUpdates => '알림 및 업데이트 받기';

  @override
  String get language => '언어';

  @override
  String get systemDefault => '시스템 기본 설정';

  @override
  String get membership => '멤버십';

  @override
  String get loading => '로딩 중...';

  @override
  String get failedToLoadMembership => '멤버십 정보를 불러오지 못했습니다.';

  @override
  String get couldNotOpenMembershipPage => '멤버십 페이지를 열 수 없습니다.';

  @override
  String get freePlan => '무료';

  @override
  String get freePlanStatus => '무료 플랜';

  @override
  String get lifetimePlan => '평생';

  @override
  String get plusPlan => '플러스';

  @override
  String get plusMonthlyPlan => '플러스 (월간)';

  @override
  String get plusYearlyPlan => '플러스 (연간)';

  @override
  String get activeStatus => '활성';

  @override
  String get activeLifetimeStatus => '활성 • 평생';

  @override
  String get canceledStatus => '취소됨';

  @override
  String get pastDueStatus => '연체';

  @override
  String get trialStatus => '체험판';

  @override
  String trialEndsInDays(int days) {
    return '체험판 $days일 후 종료';
  }

  @override
  String get trialEnded => '체험판 종료';

  @override
  String renewsInDays(int days) {
    return '$days일 후 갱신';
  }

  @override
  String accessEndsInDays(int days) {
    return '$days일 후 이용 종료';
  }

  @override
  String get subscriptionEnded => '구독 종료';

  @override
  String get profile => '프로필';

  @override
  String get errorLoadingProfile => '프로필 로딩 오류';

  @override
  String get user => '사용자';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp 연결됨';

  @override
  String get logExpensesViaWhatsApp => 'WhatsApp 메시지로 지출 내역 기록하기';

  @override
  String get connectWhatsApp => 'WhatsApp 연결하기';

  @override
  String get newBadge => 'NEW';

  @override
  String get logExpensesInstantly => '채팅으로 즉시 지출 내역 기록';

  @override
  String get fast => '빠른 기록';

  @override
  String get photo => '사진';

  @override
  String get autoSync => '자동 동기화';

  @override
  String get naturalLanguage => '자연어 처리';

  @override
  String get describeExpenseAutomatically => '지출 내역을 입력하세요. 자동으로 기록해 드립니다.';

  @override
  String get snapReceipt => '영수증 촬영';

  @override
  String get snapReceiptDescription => '영수증을 촬영하세요. AI가 내용을 추출하여 기록합니다.';

  @override
  String get previous => '이전';

  @override
  String get next => '다음';

  @override
  String get overview => '요약';

  @override
  String get activity => '활동 내역';

  @override
  String get accountInformation => '계정 정보';

  @override
  String get userId => '사용자 ID';

  @override
  String get recentActivity => '최근 활동';

  @override
  String get noActivityYet => '아직 활동 내역이 없습니다.';

  @override
  String get signOut => '로그아웃';

  @override
  String get insights => '인사이트';

  @override
  String get runningTab => '누적';

  @override
  String get day30Tab => '30일';

  @override
  String get longTermTab => '장기';

  @override
  String get scenarioTab => '시나리오';

  @override
  String get runningAndDailyBalances => '누적 및 일일 잔액';

  @override
  String get budgetVsSpentDescription => '일별 예산 대비 지출 내역과 누적 잔액을 보여줍니다.';

  @override
  String get runningBalanceLegend => '누적 잔액';

  @override
  String get budgetLegend => '예산';

  @override
  String get spentLegend => '지출';

  @override
  String get runningBalanceGuide => '누적 잔액 가이드';

  @override
  String get runningBalanceIntro => '이 차트를 개인 머니 코치라고 생각해보세요. 차트가 무엇을 보여주고 어떻게 활용할 수 있는지 알려드릴게요.';

  @override
  String get day30LookAhead => '30일 전망';

  @override
  String get projectedFromTrailing30Days => '지난 30일간의 평균 데이터를 기반으로 예상한 결과입니다.';

  @override
  String get projectedSpendingLegend => '예상 지출';

  @override
  String get peek30DaysAhead => '30일 앞서 내다보기';

  @override
  String get day30ForecastIntro => '이 예상 데이터는 지난 한 달간의 활동을 바탕으로 다음 달의 모습을 예측합니다. 지갑을 위한 일기 예보라고 생각하세요.';

  @override
  String get longTermProjection => '장기 전망';

  @override
  String get basedOnHistoricalAverages => '과거 평균 데이터를 기반으로 하며, 데이터가 쌓이면 자동으로 업데이트됩니다.';

  @override
  String get month18ProjectionLegend => '18개월 전망';

  @override
  String get your18MonthHorizon => '18개월 후의 재정 상태';

  @override
  String get longTermIntro => '이 전망은 사용자의 꾸준한 소비 습관과 완만한 성장 추세를 반영하여, 오늘의 선택이 미래에 어떤 결과로 이어질지 보여줍니다.';

  @override
  String get aiScenarioPlanning => 'AI 시나리오 플래닝';

  @override
  String get askAiFinancialAdvisor => '미래의 지출을 감당할 수 있는지 AI 재무 어드바이저에게 물어보세요.';

  @override
  String get canI => '혹시';

  @override
  String get before => '전에';

  @override
  String get beforePrefix => '전에';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => '날짜 선택';

  @override
  String get check => '확인하기';

  @override
  String get enterQuestionAndPickDate => '질문을 입력하고 날짜를 선택해주세요.';

  @override
  String get analyzingScenario => '시나리오 분석 중...';

  @override
  String get thisMightTakeAWhile => '시간이 조금 걸릴 수 있습니다.';

  @override
  String get whereTheMoneyWent => '돈이 어디로 갔을까요?';

  @override
  String get categoryTotalsForSelectedRange => '선택한 기간의 카테고리별 합계입니다.';

  @override
  String get scenarioCategoriesGuide => '카테고리 이해하기';

  @override
  String get categoryGuideIntro => '이 차트는 돈이 어디로 흘러갔는지 한눈에 보여줍니다. 계산기 없이도 쉽게 읽는 법을 알려드릴게요.';

  @override
  String get readTheBarChartLikeAPro => '막대 차트 전문가처럼 읽기';

  @override
  String get categoryChartDesc => '선택한 기간의 카테고리별 내역입니다.';

  @override
  String get whyThisViewIsHelpful => '이 차트가 유용한 이유';

  @override
  String get categoryWhyHelpfulDesc => '가장 큰 지출 카테고리를 빠르게 파악하고 시간 경과에 따른 변화를 발견할 수 있습니다.';

  @override
  String get whatToDoWithTheInsight => '인사이트 활용법';

  @override
  String get categoryWhatToDoDesc => '이 정보를 바탕으로 예산과 소비 습관을 조절해 보세요.';

  @override
  String get scenarioAnalysis => '시나리오 분석';

  @override
  String get target => '목표';

  @override
  String get quickStats => '간단 통계';

  @override
  String get currentBalance => '현재 잔액';

  @override
  String get projectedNoChange => '예상 잔액 (변동 없음)';

  @override
  String get avgDailyNet => '일평균 순현금흐름';

  @override
  String get noDataAvailable => '데이터 없음';

  @override
  String get day => '일';

  @override
  String get close => '닫기';

  @override
  String get done => '완료';

  @override
  String get whatYouAreSeeing => '차트 읽는 법';

  @override
  String get whyItMatters => '이게 왜 중요할까요?';

  @override
  String get howToRespond => '어떻게 활용할까요?';

  @override
  String get runningBalanceWhatYouSeeDesc => '누적 잔액은 매일 지출 후 남은 여유 자금을 보여줍니다. 일일 막대는 계획한 예산과 실제 지출액을 비교해 보여줘요.';

  @override
  String get runningBalanceWhyMattersDesc => '일종의 재정 건강 신호라고 생각하세요. 계획보다 앞서고 있는지, 아니면 계획대로 가기 위해 수정이 필요한지 파악하는 데 도움이 됩니다.';

  @override
  String get runningBalanceHowToRespondDesc => '차트를 코치처럼 활용하세요. 성과가 좋으면 축하하고, 필요하면 기대치를 재설정하세요. 완벽함보다는 꾸준한 과정이 중요합니다.';

  @override
  String get whatTheForecastShows => '예상 데이터가 보여주는 것';

  @override
  String get day30WhatShowsDesc => '지난 30일간의 지출과 수입을 조합하여 앞으로의 평균적인 한 주를 예측합니다. 일회성 지출을 제외하고 평소의 흐름을 볼 수 있어요.';

  @override
  String get day30WhyMattersDesc => '미래를 내다보는 예산은 미리 대비하는 데 도움이 됩니다. 지출이 많은 날을 미리 확인하고 현금을 준비할 수 있어요.';

  @override
  String get day30HowToPlaySmartDesc => '엄격한 규칙보다는 친근한 조언으로 받아들이세요. 실천 가능한 작은 변화부터 계획을 조절해 보세요.';

  @override
  String get howTheProjectionWorks => '예측 방법';

  @override
  String get longTermHowWorksDesc => '평균 수입과 지출에 완만한 성장률을 더해, 현재의 계획이 몇 달 뒤에도 여유 자금을 유지할 수 있는지 보여줍니다.';

  @override
  String get longTermWhyMattersDesc => '장기적인 안목은 큰 꿈을 현실로 만듭니다. 비상금, 투자, 또는 큰 지출 계획이 순조롭게 진행되고 있는지 확인하세요.';

  @override
  String get longTermMovesToConsiderDesc => '미래의 결정을 미리 연습하는 데 차트를 활용하세요. 오늘의 작은 변화가 나중에 큰 성공으로 이어집니다.';

  @override
  String get forMe => '개인';

  @override
  String get forUs => '공동';

  @override
  String get home => '홈';

  @override
  String get reminder => '알림';

  @override
  String get analyzingReceipt => '영수증 분석 중...';

  @override
  String get analyzingExpense => '지출 내역 분석 중...';

  @override
  String get noExpenseInformationExtracted => '지출 정보를 추출하지 못했습니다.';

  @override
  String get failedToAnalyzeNoData => '분석 실패: 반환된 데이터 없음';

  @override
  String get failedToAnalyze => '분석 실패';

  @override
  String get updateBudget => '예산 수정';

  @override
  String get enterNewTotalDailyBudget => '새로운 일일 총예산을 입력하세요.';

  @override
  String get budgetAmount => '예산 금액';

  @override
  String get save => '저장';

  @override
  String get enterValidAmountGreaterThan0 => '0보다 큰 유효한 금액을 입력하세요.';

  @override
  String get updatingBudget => '예산 업데이트 중...';

  @override
  String get budgetUpdated => '예산 업데이트 완료';

  @override
  String get failedToUpdateBudget => '예산 업데이트 실패';

  @override
  String get loggedSuccessfully => '기록 완료';

  @override
  String get view => '보기';

  @override
  String get retry => '재시도';

  @override
  String get failedToCapturePhoto => '사진 촬영 실패';

  @override
  String get noSpendingData => '지출 데이터 없음';

  @override
  String get byCategory => '카테고리별';

  @override
  String get noExpensesYet => '아직 지출 내역이 없습니다.';

  @override
  String get startLoggingExpensesToSeeCategories => '지출 내역을 기록하고 카테고리별 내역을 확인하세요.';

  @override
  String get selectDateRange => '기간 선택';

  @override
  String get addExpense => '지출 추가';

  @override
  String get describeYourExpense => '지출 내역을 입력하세요 (예: \"버거 5천원, 커피 3천원\")';

  @override
  String get enterExpenseDetails => '지출 상세 내역 입력...';

  @override
  String get freeFormText => '자유 입력';

  @override
  String get takePhoto => '사진 촬영';

  @override
  String get transactions => '거래 내역';

  @override
  String get negative => '마이너스';

  @override
  String get positive => '플러스';

  @override
  String get spendingBreakdown => '지출 내역';

  @override
  String get spent => '지출';

  @override
  String get today => '오늘';

  @override
  String get yesterday => '어제';

  @override
  String get thisWeek => '이번 주';

  @override
  String get lastWeek => '지난주';

  @override
  String get thisMonth => '이번 달';

  @override
  String get last30Days => '최근 30일';

  @override
  String get customRange => '기간 설정';

  @override
  String get spentToday => '오늘 내 지출';

  @override
  String get spentYesterday => '어제 내 지출';

  @override
  String get spentThisWeek => '이번 주 내 지출';

  @override
  String get spentLastWeek => '지난주 내 지출';

  @override
  String get spentThisMonth => '이번 달 내 지출';

  @override
  String get spentLast30Days => '내 지출 (최근 30일)';

  @override
  String get spentCustom => '지출 (기간 설정)';

  @override
  String get todaysBudget => '오늘 예산';

  @override
  String get yesterdaysBudget => '어제 예산';

  @override
  String get sumOfDailyBudgetsThisWeek => '이번 주 일일 예산 합계';

  @override
  String get sumOfDailyBudgetsLastWeek => '지난주 일일 예산 합계';

  @override
  String get sumOfDailyBudgetsThisMonth => '이번 달 일일 예산 합계';

  @override
  String get sumOfDailyBudgetsLast30Days => '최근 30일간 일일 예산 합계';

  @override
  String get sumOfDailyBudgetsForSelectedRange => '선택한 기간의 일일 예산 합계';

  @override
  String get netCashflowToday => '오늘 순현금흐름';

  @override
  String get netCashflowYesterday => '어제 순현금흐름';

  @override
  String get netCashflowThisWeek => '이번 주 순현금흐름';

  @override
  String get netCashflowLastWeek => '지난주 순현금흐름';

  @override
  String get netCashflowThisMonth => '이번 달 순현금흐름';

  @override
  String get netCashflowLast30Days => '순현금흐름 (최근 30일)';

  @override
  String get netCashflowCustom => '순현금흐름 (기간 설정)';

  @override
  String get selectCurrency => '통화 선택';

  @override
  String get showLessCurrencies => '통화 숨기기';

  @override
  String showAllCurrencies(int count) {
    return '모든 통화 보기 ($count개 더보기)';
  }

  @override
  String get budget => '예산';

  @override
  String get spentLabel => '지출';

  @override
  String get net => '순';

  @override
  String get txn => '건';

  @override
  String get txns => '건';

  @override
  String get pleaseEnterExpenseDetails => '지출 상세 내역을 입력해주세요.';

  @override
  String get userNotLoggedIn => '로그인되지 않은 사용자입니다.';

  @override
  String get errorLoadingHouseholds => '그룹 로딩 오류';

  @override
  String get welcomeToHouseholds => '그룹 기능 시작하기';

  @override
  String get householdsDescription => '가족, 파트너, 룸메이트와 함께 공동 재정을 관리하세요. 예산을 추적하고, 지출을 나누고, 재정 결정을 함께 내릴 수 있습니다.';

  @override
  String get createHousehold => '그룹 생성하기';

  @override
  String get joinWithInvite => '초대 링크로 참여하기';

  @override
  String get pleaseUseInvitationLink => '초대 링크를 사용해 그룹에 참여해주세요.';

  @override
  String get householdName => '그룹 이름';

  @override
  String get householdNameHint => '예: 우리 가족, 스미스네';

  @override
  String get pleaseEnterHouseholdName => '그룹 이름을 입력해주세요.';

  @override
  String get errorCreatingHousehold => '그룹 생성 오류';

  @override
  String get householdsFeature => '그룹 기능';

  @override
  String get householdsFeatureDescription => '이제 그룹 기능을 사용할 수 있습니다! 가족, 파트너, 룸메이트와 공동 재정을 관리해보세요.';

  @override
  String get gotIt => '확인';

  @override
  String get confirmExpense => '지출 확인';

  @override
  String get expenseDetails => '지출 상세 내역';

  @override
  String get details => '상세 내역';

  @override
  String get category => '카테고리';

  @override
  String get currency => '통화';

  @override
  String get date => '날짜';

  @override
  String get time => '시간';

  @override
  String get notes => '메모';

  @override
  String get receipt => '영수증';

  @override
  String get saveExpense => '지출 저장';

  @override
  String get shareWithHousehold => '그룹과 공유하기';

  @override
  String get loadingHouseholdMembers => '그룹 멤버 로딩 중...';

  @override
  String get selectHouseholdToConfigureSplit => '정산 방식을 설정할 그룹을 선택하세요.';

  @override
  String get currencyManagedByHousehold => '통화는 그룹에서 관리하며 변경할 수 없습니다.';

  @override
  String get currencyCannotBeChanged => '그룹과 공유 시 통화를 변경할 수 없습니다.';

  @override
  String get failedToLoadImage => '이미지 로딩 실패';

  @override
  String get editAmount => '금액 수정';

  @override
  String get amount => '금액';

  @override
  String get editNotes => '메모 수정';

  @override
  String get addANote => '메모 추가...';

  @override
  String get noMembersFoundInHousehold => '그룹 멤버를 찾을 수 없습니다.';

  @override
  String get errorLoadingMembers => '멤버 로딩 오류';

  @override
  String get noExpenseToSave => '저장할 지출 내역이 없습니다.';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return '지출 내역이 저장 및 공유되었습니다$splitInfo!';
  }

  @override
  String get expenseSaved => '지출 내역 저장 완료!';

  @override
  String failedToSave(String error) {
    return '저장 실패: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return '통화 설정 동기화 실패: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => '통화 업데이트 완료';

  @override
  String retryFailed(Object error) {
    return '재시도 실패: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return '$category에 $currencySymbol$amount 지출';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => '새로운 일일 총예산을 입력하세요.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => '그룹 기능을 사용하려면 로그인해주세요.';

  @override
  String get quickActions => '빠른 실행';

  @override
  String get members => '멤버';

  @override
  String get invites => '초대';

  @override
  String get errorLoadingExpenses => '지출 내역 로딩 오류';

  @override
  String get budgets => '예산';

  @override
  String get loadingHousehold => '그룹 로딩 중...';

  @override
  String get remaining => '남음';

  @override
  String get overBudget => '예산 초과';

  @override
  String get sharedBudgets => '공유 예산';

  @override
  String get netPosition => '순 현황';

  @override
  String get spentByHousehold => '그룹 지출';

  @override
  String get memberSpending => '멤버별 지출';

  @override
  String get spentByHouseholdTooltip => '선택한 기간 동안 모든 그룹 멤버가 지출한 총액을 표시합니다. 그룹의 모든 멤버가 기록한 공유 지출이 포함됩니다.';

  @override
  String get manageMoneyTogether => '파트너, 가족, 룸메이트와 함께 한 공간에서 돈을 관리하세요.';

  @override
  String get sharedBudgetsExpenses => '공유 예산 및 지출';

  @override
  String get sharedBudgetsExpensesDesc => '예산을 설정하고, 지출을 추적하며, 그룹의 돈이 어디에 쓰이는지 실시간으로 확인하세요.';

  @override
  String get smartExpenseSplitting => '스마트한 지출 나누기';

  @override
  String get smartExpenseSplittingDesc => '균등, 비율, 또는 직접 입력 등 유연한 방식으로 누가 얼마를 내야 하는지 자동으로 계산합니다.';

  @override
  String get stayInSync => '실시간 동기화';

  @override
  String get stayInSyncDesc => '지출이 추가되거나, 예산에 도달하거나, 정산이 필요할 때 알림을 받으세요.';

  @override
  String get householdSettings => '그룹 설정';

  @override
  String get householdNotFound => '그룹을 찾을 수 없습니다.';

  @override
  String get coverPhoto => '커버 사진';

  @override
  String get changeCoverPhoto => '커버 사진 변경';

  @override
  String get saveChanges => '변경사항 저장';

  @override
  String get errorLoadingHousehold => '그룹 로딩 오류';

  @override
  String get householdUpdatedSuccessfully => '그룹 정보가 업데이트되었습니다.';

  @override
  String get failedToUpdateHousehold => '그룹 정보 업데이트에 실패했습니다.';

  @override
  String get inviteMember => '멤버 초대하기';

  @override
  String get removeMember => '멤버 내보내기';

  @override
  String get remove => '내보내기';

  @override
  String get confirmRemoveMember => '정말로 내보내시겠습니까?';

  @override
  String get updatedMemberRole => '멤버 역할이 변경되었습니다.';

  @override
  String get unknown => '알 수 없음';

  @override
  String get makeAdmin => '관리자로 지정';

  @override
  String get makeMember => '멤버로 변경';

  @override
  String get invitations => '초대 내역';

  @override
  String get errorLoadingInvites => '초대 내역 로딩 오류';

  @override
  String get createInvitation => '초대장 만들기';

  @override
  String get pendingInvitations => '대기 중인 초대';

  @override
  String get noPendingInvitations => '대기 중인 초대가 없습니다.';

  @override
  String get invitationHistory => '초대 기록';

  @override
  String get noInvitationHistory => '초대 기록이 없습니다.';

  @override
  String get emailOptional => '이메일 (선택)';

  @override
  String get friendEmailExample => 'friend@example.com';

  @override
  String get personalMessageOptional => '개인 메시지 (선택)';

  @override
  String get joinHouseholdBudget => '우리 그룹 가계부에 참여하세요!';

  @override
  String get expiresIn => '만료 기한';

  @override
  String get oneDay => '1일';

  @override
  String get threeDays => '3일';

  @override
  String get sevenDays => '7일';

  @override
  String get fourteenDays => '14일';

  @override
  String get thirtyDays => '30일';

  @override
  String get unlimited => '무제한';

  @override
  String get create => '만들기';

  @override
  String get invitationCreatedSuccessfully => '초대장을 만들었습니다.';

  @override
  String get inviteLinkCopiedToClipboard => '초대 링크가 클립보드에 복사되었습니다!';

  @override
  String get errorCreatingInvite => '초대장 생성 오류';

  @override
  String get revokeInvitation => '초대 취소';

  @override
  String get confirmRevokeInvitation => '이 초대를 정말 취소하시겠습니까?';

  @override
  String get revoke => '취소하기';

  @override
  String get invitationRevoked => '초대가 취소되었습니다.';

  @override
  String get errorRevokingInvite => '초대 취소 오류';

  @override
  String get anyoneWithLink => '링크가 있는 누구나';

  @override
  String get noExpiry => '만료 기한 없음';

  @override
  String get expired => '만료됨';

  @override
  String get expires => '만료';

  @override
  String get copyLink => '링크 복사';

  @override
  String get selectCoverImage => '커버 이미지 선택';

  @override
  String get failedToLoadImages => '이미지 로딩 실패';

  @override
  String get chooseFromGallery => '갤러리에서 선택';

  @override
  String get failedToLoad => '로딩 실패';

  @override
  String get imageTooLarge => '이미지 크기가 너무 큽니다.';

  @override
  String get maxIs => '최대';

  @override
  String get unsupportedFileFormat => '지원하지 않는 파일 형식입니다. JPG, PNG, 또는 WebP 파일을 사용하세요.';

  @override
  String get cropCoverImage => '커버 이미지 자르기';

  @override
  String get editBudget => '예산 수정';

  @override
  String get budgetDetails => '예산 상세';

  @override
  String get budgetName => '예산 이름';

  @override
  String get period => '기간';

  @override
  String get alertThresholds => '알림 기준';

  @override
  String get warningThreshold => '경고 기준 (%)';

  @override
  String get alertThreshold => '위험 기준 (%)';

  @override
  String get warningThresholdHelper => '예산 사용률이 이 비율에 도달하면 경고 알림';

  @override
  String get alertThresholdHelper => '예산 사용률이 이 비율에 도달하면 위험 알림';

  @override
  String get budgetStatus => '예산 상태';

  @override
  String get active => '활성';

  @override
  String get inactive => '비활성';

  @override
  String get deletingBudget => '예산 삭제 중...';

  @override
  String get savingChanges => '변경사항 저장 중...';

  @override
  String get budgetNameCannotBeEmpty => '예산 이름을 입력해야 합니다.';

  @override
  String get pleaseEnterValidAmount => '올바른 금액을 입력해주세요.';

  @override
  String get warningThresholdRange => '경고 기준은 0에서 100 사이여야 합니다.';

  @override
  String get alertThresholdRange => '위험 기준은 0에서 100 사이여야 합니다.';

  @override
  String get warningThresholdLessThanAlert => '경고 기준은 위험 기준보다 낮거나 같아야 합니다.';

  @override
  String get deleteBudget => '예산 삭제';

  @override
  String get confirmDeleteBudget => '정말로 삭제하시겠습니까?';

  @override
  String get thisActionCannotBeUndone => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get budgetUpdatedSuccessfully => '예산이 업데이트되었습니다.';

  @override
  String get budgetDeletedSuccessfully => '예산이 삭제되었습니다.';

  @override
  String get categoryTransfers => '이체';

  @override
  String get categoryShopping => '쇼핑';

  @override
  String get categoryUtilities => '공과금';

  @override
  String get categoryEntertainment => '문화생활';

  @override
  String get categoryEntertainmentSubscriptions => '구독 (문화)';

  @override
  String get categoryRestaurants => '외식';

  @override
  String get categoryFood => '식비';

  @override
  String get categoryGroceries => '식료품';

  @override
  String get categoryTransport => '교통';

  @override
  String get categoryTransportation => '교통';

  @override
  String get categoryTravel => '여행';

  @override
  String get categoryFlights => '항공';

  @override
  String get categoryVacation => '휴가';

  @override
  String get categoryHealth => '건강';

  @override
  String get categoryMedical => '의료';

  @override
  String get categoryText => '텍스트';

  @override
  String get categoryEducation => '교육';

  @override
  String get categoryTuition => '학비';

  @override
  String get categorySubscriptions => '구독';

  @override
  String get categoryServices => '서비스';

  @override
  String get categoryHousing => '주거';

  @override
  String get categoryRent => '월세';

  @override
  String get categoryMortgage => '대출 (주택)';

  @override
  String get categoryBills => '청구서';

  @override
  String get categoryInsurance => '보험';

  @override
  String get categorySavings => '저축';

  @override
  String get categoryInvestment => '투자';

  @override
  String get categoryInvestments => '투자';

  @override
  String get categoryIncome => '수입';

  @override
  String get categorySalary => '급여';

  @override
  String get categoryBonus => '보너스';

  @override
  String get categoryPets => '반려동물';

  @override
  String get categoryKids => '육아';

  @override
  String get categoryFamily => '가족';

  @override
  String get categoryGifts => '선물';

  @override
  String get categoryCharity => '기부';

  @override
  String get categoryFees => '수수료';

  @override
  String get categoryLoan => '대출';

  @override
  String get categoryLoans => '대출';

  @override
  String get categoryDebt => '부채';

  @override
  String get categoryPersonalCare => '개인 용품';

  @override
  String get categoryBeauty => '미용';

  @override
  String get categoryMisc => '기타';

  @override
  String get categoryUncategorized => '미분류';

  @override
  String get deleteBudgetCannotBeUndone => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get delete => '삭제';

  @override
  String get failedToDeleteBudget => '예산 삭제 실패';

  @override
  String get owner => '소유자';

  @override
  String get admin => '관리자';

  @override
  String get member => '멤버';

  @override
  String get pending => '대기 중';

  @override
  String get accepted => '수락함';

  @override
  String get revoked => '취소됨';

  @override
  String get tapToChangeCover => '탭하여 커버 변경';

  @override
  String get personalMessageHint => '초대할 멤버에게 메시지를 남겨보세요 (예: \"우리 그룹 가계부에 참여하세요!\")';

  @override
  String get invitationExpiresIn => '초대 만료 기한';

  @override
  String daysCount(int days) {
    return '$days일';
  }

  @override
  String get createHouseholdDescription => '가족, 룸메이트와 함께 예산과 지출을 추적하는 공유 공간을 만드세요.';

  @override
  String get uploadingImage => '이미지 업로드 중...';

  @override
  String get creating => '생성 중...';

  @override
  String get generatingInvite => '초대 링크 생성 중...';

  @override
  String get pleaseSelectValidCurrency => '유효한 그룹 통화를 선택해주세요.';

  @override
  String nameMaxLength(int max) {
    return '이름은 $max자 미만이어야 합니다.';
  }

  @override
  String get createHouseholdPage => '그룹 생성 페이지';

  @override
  String get invitationPersonalMessageInput => '초대 개인 메시지 입력';

  @override
  String get householdNameInput => '그룹 이름 입력';

  @override
  String get invitationExpirationSelector => '초대 만료 기한 선택';

  @override
  String get unlimitedExpiration => '무제한';

  @override
  String daysExpiration(int days) {
    return '$days일 후 만료';
  }

  @override
  String get householdInformation => '그룹 정보';

  @override
  String get creatingHousehold => '그룹 생성 중';

  @override
  String get createHouseholdButton => '그룹 생성 버튼';

  @override
  String get searchExpenses => '지출 내역 검색...';

  @override
  String get clearAll => '전체 해제';

  @override
  String get allCategories => '모든 카테고리';

  @override
  String get allMembers => '모든 멤버';

  @override
  String get balanceSummary => '정산 요약';

  @override
  String get youAreOwed => '받을 돈';

  @override
  String get youOwe => '보낼 돈';

  @override
  String get youOweOthers => '내가 보낼 돈';

  @override
  String get othersOweYou => '내가 받을 돈';

  @override
  String get viewDetails => '상세 보기';

  @override
  String get settleUp => '정산하기';

  @override
  String get markExpensesAsSettled => '정산 완료로 표시하여 잔액을 업데이트하세요.';

  @override
  String get whoAreYouSettlingWith => '누구와 정산하시나요?';

  @override
  String get selectMember => '멤버 선택';

  @override
  String get amountToSettle => '정산할 금액';

  @override
  String get howDidYouSettle => '어떻게 정산했나요?';

  @override
  String get cash => '현금';

  @override
  String get paidInCash => '현금으로 정산';

  @override
  String get bankTransfer => '계좌 이체';

  @override
  String get transferredViaBank => '계좌 이체로 정산';

  @override
  String get mobilePayment => '간편 송금';

  @override
  String get venmoPaypalEtc => '토스, 카카오페이 등';

  @override
  String get search => '검색';

  @override
  String get noData => '데이터 없음';

  @override
  String get filterTransactions => '거래 내역 필터';

  @override
  String get noTransactionsFound => '거래 내역을 찾을 수 없습니다.';

  @override
  String get failedToLoadHouseholdTransactions => '그룹 거래 내역을 불러오는 데 실패했습니다.';

  @override
  String get reset => '초기화';

  @override
  String get apply => '적용';

  @override
  String get expenses => '지출 내역';

  @override
  String get dateRange => '기간';

  @override
  String get noMatchingExpenses => '일치하는 지출 내역이 없습니다.';

  @override
  String get startLoggingExpenses => '지출 내역을 기록하면 여기에 표시됩니다.';

  @override
  String get tryAdjustingFilters => '필터 조건을 변경해보세요.';

  @override
  String get split => '정산';

  @override
  String get note => '메모';

  @override
  String get currencyCannotBeChangedWhenSharing => '그룹과 공유 시 통화를 변경할 수 없습니다.';

  @override
  String get createBudget => '예산 만들기';

  @override
  String get pleaseEnterABudgetName => '예산 이름을 입력해주세요.';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => '0보다 큰 유효한 금액을 입력해주세요.';

  @override
  String get warningThresholdMustBeBetween0And100 => '경고 기준은 0%와 100% 사이여야 합니다.';

  @override
  String get alertThresholdMustBeBetween0And100 => '위험 기준은 0%와 100% 사이여야 합니다.';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => '경고 기준은 위험 기준보다 낮거나 같아야 합니다.';

  @override
  String get budgetCreatedSuccessfully => '예산이 생성되었습니다!';

  @override
  String get failedToCreateBudget => '예산 생성에 실패했습니다.';

  @override
  String get groceriesRentEntertainment => '예: 식료품, 월세, 문화생활';

  @override
  String get budgetType => '예산 유형';

  @override
  String get sharedWithAllHouseholdMembers => '모든 그룹 멤버와 공유';

  @override
  String get personalBudgetForYourExpensesOnly => '개인 지출만 반영하는 예산';

  @override
  String get countSplitPortionOnly => '분할된 금액만 계산';

  @override
  String get onlyCountYourPortionOfSplitExpenses => '분할된 지출 중 내 몫만 이 예산에 포함합니다.';

  @override
  String get joinHousehold => '가정에 참여';

  @override
  String get joinAHousehold => '가정에 참여하기';

  @override
  String get enterYourInvitationLinkToJoin => '공유 재정 공간에 참여하려면\n초대 링크를 입력하세요.';

  @override
  String get pasteTheInvitationLinkYouReceived => '그룹 멤버로부터 받은 초대 링크를 붙여넣으세요.';

  @override
  String get pasteInvitationLink => '초대 링크 붙여넣기';

  @override
  String get pleaseEnterAnInvitationLink => '초대 링크를 입력해주세요.';

  @override
  String get pleaseEnterAValidInvitationLink => '유효한 초대 링크를 입력해주세요.';

  @override
  String get paste => '붙여넣기';

  @override
  String get validating => '확인 중...';

  @override
  String get continueAction => '계속하기';

  @override
  String get welcomeAboard => '환영합니다!';

  @override
  String get youreNowPartOfTheHousehold => '이제 그룹의 멤버가 되었습니다.\n재정 관리를 함께 시작해보세요!';

  @override
  String get thisWillOnlyTakeAMoment => '잠시만 기다려주세요.';

  @override
  String get unableToJoin => '참여할 수 없음';

  @override
  String get tryAgain => '다시 시도';

  @override
  String get goToHousehold => '그룹으로 가기';

  @override
  String get expiresSoon => '곧 만료됨';

  @override
  String invitationValidUntil(String formattedDate) {
    return '초대는 $formattedDate까지 유효합니다';
  }

  @override
  String get whatYoullGet => '제공되는 기능';

  @override
  String get viewSharedBudgetsAndExpenses => '공유 예산 및 지출 내역 보기';

  @override
  String get trackHouseholdFinancialHealth => '그룹 재정 현황 추적';

  @override
  String get collaborateOnFinancialDecisions => '재정 관련 결정 함께하기';

  @override
  String get household => '그룹';

  @override
  String get viewAll => '전체 보기';

  @override
  String get manage => '관리';

  @override
  String get noBudgetsYet => '아직 예산이 없습니다.';

  @override
  String get createSharedBudgetDescription => '공유 예산을 만들어 함께 지출을 관리하세요.';

  @override
  String get errorLoadingBudgets => '예산 로딩 오류';

  @override
  String get recentSplits => '최근 정산 내역';

  @override
  String get invite => '초대';

  @override
  String get last6Months => '최근 6개월';

  @override
  String get thisYear => '올해';

  @override
  String get allTime => '전체 기간';

  @override
  String nameMinLength(int min) {
    return '이름은 최소 $min자 이상이어야 합니다.';
  }

  @override
  String get splitExpense => '지출 나누기';

  @override
  String get percent => '비율 (%)';

  @override
  String get splitShare => '몫 (비율)';

  @override
  String get owes => '낼 금액';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return '분할 금액의 총합이 $currency$amount와(과) 일치해야 합니다.';
  }

  @override
  String get percentagesMustTotal100 => '비율의 총합은 100%여야 합니다.';

  @override
  String get eachPersonMustHaveAtLeast1Share => '각 멤버는 최소 1 이상의 몫을 가져야 합니다.';

  @override
  String get whatsappVerified => 'WhatsApp 인증 완료';

  @override
  String get whatsappVerification => 'WhatsApp 인증';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'WhatsApp 번호가 계정에 성공적으로 연결되었습니다.';

  @override
  String get verifyingYourWhatsAppNumber => 'WhatsApp 번호 인증 중...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'WhatsApp에서 받은 6자리 코드를 입력하세요.';

  @override
  String get pleaseEnterThe6DigitVerificationCode => '6자리 인증번호를 입력해주세요.';

  @override
  String get failedToVerifyCode => '코드 인증 실패';

  @override
  String get failedToVerifyCodePleaseTryAgain => '코드 인증에 실패했습니다. 다시 시도해주세요.';

  @override
  String get codeAutoFilledFromVerificationLink => '인증 링크에서 코드가 자동 입력되었습니다.';

  @override
  String get verify => '인증하기';

  @override
  String get verifying => '인증 중...';

  @override
  String get avatarStudio => '아바타 스튜디오';

  @override
  String get preview => '미리보기';

  @override
  String get colors => '색상';

  @override
  String get randomize => '랜덤';

  @override
  String get saveAvatar => '아바타 저장';

  @override
  String get saving => '저장 중...';

  @override
  String get skipForNow => '지금은 건너뛰기';

  @override
  String get selectColor => '색상 선택';

  @override
  String get failedToSaveAvatar => '아바타 저장 실패';

  @override
  String get hair => '헤어';

  @override
  String get eyes => '눈';

  @override
  String get mouth => '입';

  @override
  String get background => '배경';

  @override
  String get face => '얼굴';

  @override
  String get ears => '귀';

  @override
  String get shirts => '상의';

  @override
  String get brow => '눈썹';

  @override
  String get nose => '코';

  @override
  String get blush => '볼터치';

  @override
  String get accessories => '액세서리';

  @override
  String get stars => '별';

  @override
  String get currencyIsManagedByHousehold => '통화는 그룹에서 관리하며 변경할 수 없습니다.';

  @override
  String get buyALaptop => '120만원짜리 노트북 사기';

  @override
  String get selectTargetDate => '목표 날짜 선택';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return '$date 전에 $action할 수 있을까요?';
  }

  @override
  String get scenarioDateFormat => 'yyyy/MM/dd';

  @override
  String analysisFailed(String error) {
    return '분석 실패: $error';
  }

  @override
  String get leftHandChamps => '왼쪽에 있는 항목들이 지출의 큰 부분을 차지합니다. 빠르게 검토하기 좋은 후보들이죠.';

  @override
  String get smallButFrequent => '금액은 작지만 잦은 지출은 시간이 지나면서 쌓일 수 있는 습관을 보여줍니다.';

  @override
  String get colorMatches => '홈 탭에서 본 색상과 동일하게 표시되어 혼란스럽지 않아요.';

  @override
  String get planningNewGoal => '새로운 목표를 계획 중인가요? 즐거움을 포기하지 않고도 줄일 수 있는 카테고리를 찾아보세요.';

  @override
  String get eyeingTreatYourself => '자신에게 선물을 하고 싶나요? 어떤 항목을 안전하게 조절할 수 있는지 확인해보세요.';

  @override
  String get doubleCheckTagging => '새로운 지출이 정확하게 태그되었는지 다시 한번 확인하는 데 사용하세요.';

  @override
  String get slideHighBar => '작은 한도를 설정하거나 더 저렴한 대안으로 바꿔서 높은 막대를 조금 낮춰보세요.';

  @override
  String get nonNegotiable => '월세처럼 협상 불가능한 항목이라면, 싸우려 하지 말고 그 외의 것을 계획하세요.';

  @override
  String get revisitAfterScenario => '시나리오를 실행한 후 다시 방문하여 조정한 내역이 잘 유지되는지 확인하세요.';

  @override
  String get purpleLineCushion => '보라색 선: 매일 지출 후 남은 여유 자금입니다. 선이 올라가면 추진력이 생기고 있다는 뜻이에요.';

  @override
  String get blueBarsBudget => '파란색 막대: 그날 설정한 예산입니다.';

  @override
  String get redBarsSpent => '빨간색 막대: 실제로 계좌에서 나간 돈입니다.';

  @override
  String get lineTrendingUpward => '선이 상승 중 = 저축 목표에 더 보탤 수 있는 추가 현금이 있다는 의미입니다.';

  @override
  String get flatDippingLine => '선이 평평하거나 하락 중 = 잠시 멈추고 큰 지출 항목을 검토할 시간입니다.';

  @override
  String get sharpDrops => '급격한 하락은 종종 계획에 없던 구매와 일치합니다. 탭해서 상세 내역을 확인하세요.';

  @override
  String get lineRisingDays => '선이 며칠째 상승 중인가요? 저축이나 부채 상환에 조금 더 투자하는 것을 고려해보세요.';

  @override
  String get lineDippingWeekend => '바쁜 주말 후 선이 하락했나요? 작은 재량 지출을 줄여서 다가오는 날들을 재조정하세요.';

  @override
  String get feelStuckRed => '계속 마이너스인 것 같나요? 홈 탭에서 예산을 다시 검토하세요. 작은 조정이 모여 큰 차이를 만듭니다.';

  @override
  String get thirtyDayForecastDesc => '이 예상 데이터는 지난 한 달간의 활동을 바탕으로 다음 달의 모습을 예측합니다. 지갑을 위한 일기 예보라고 생각하세요.';

  @override
  String get greenLineExpected => '초록색 선 = 다음 달이 지난달처럼 흘러갈 경우 예상되는 일일 지출입니다.';

  @override
  String get spikesHighlight => '뾰족한 부분은 평소 지출이 많아지는 주를 보여줍니다 (예: 금요일의 배달 음식).';

  @override
  String get forecastUpdates => '새로운 거래 내역을 기록하면 예상 데이터도 부드럽게 업데이트됩니다. 새로고침할 필요 없어요.';

  @override
  String get spotExpensivePatterns => '지출이 많은 패턴을 미리 파악하고, 그 전에 미리 대비하세요.';

  @override
  String get catchQuieterWeeks => '지출이 적은 주를 파악하여 여유 자금을 저축이나 부채 상환에 활용하세요.';

  @override
  String get timeRecurringPayments => '이 정보를 활용하여 정기 결제, 구독, 또는 충전 시기를 조절하세요.';

  @override
  String get bigSpikeComing => '큰 지출이 예상되나요? 더 저렴한 옵션을 미리 예약하거나, 유동적인 지출을 다른 날로 옮기세요.';

  @override
  String get forecastDipping => '예상 지출이 줄었나요? 추가 저축 이체를 예약해서 스스로에게 보상하세요.';

  @override
  String get forecastLooksOff => '예상 데이터가 실제와 맞지 않는 것 같나요? 홈 탭에서 카테고리를 검토하여 잘못 분류된 항목이 있는지 확인하세요.';

  @override
  String get greenLineTrends => '초록색 선은 일반적인 저축률 추세를 보여줍니다. 상승세는 목표가 잘 진행되고 있음을 의미해요.';

  @override
  String get lineDipsSignals => '선이 하락한다면, 지출이 수입을 초과하는 경향이 있는 달을 예고하는 신호입니다.';

  @override
  String get largeGoalsDebts => '홈 탭에서 태그한 큰 목표나 부채가 포함됩니다.';

  @override
  String get upwardSlope => '상승 곡선인가요? 축하합니다! 은퇴 자금이나 여행 저축을 늘려보는 것을 고려해보세요.';

  @override
  String get flatSlipping => '평평하거나 미끄러지고 있나요? 더 큰 문제로 번지기 전에 예산을 조정하거나 수입원을 늘릴 시간입니다.';

  @override
  String get watchSeasonalTrends => '계절적 추세를 주시하세요. 명절, 학기, 또는 연간 갱신 비용이 여기에 먼저 나타나는 경우가 많습니다.';

  @override
  String get schedulePaymentIncreases => '곡선이 상승할 때 대출 상환액을 조금씩 늘려보세요.';

  @override
  String get planAheadDips => '비상금을 마련하거나 선택적 지출을 줄여서 하락에 미리 대비하세요.';

  @override
  String get checkProjectionMonthly => '매달 예상 데이터를 확인하며 장기 계획을 즐겁고 유연하게 유지하세요.';

  @override
  String get categoryHealthcare => '건강/의료';

  @override
  String get categoryOther => '기타';

  @override
  String get deleteExpense => '지출 삭제';

  @override
  String get confirmDeleteExpense => '이 지출 내역을 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get expenseDeletedSuccessfully => '지출 내역이 삭제되었습니다.';

  @override
  String get failedToDeleteExpense => '지출 내역 삭제에 실패했습니다.';

  @override
  String get expenseNotFoundOrDeleted => '지출 내역을 찾을 수 없거나 이미 삭제되었습니다.';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => '관리자와 소유자만 가계 설정을 편집할 수 있습니다';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => '관리자와 소유자만 초대를 생성할 수 있습니다';

  @override
  String shareInvitationForHousehold(String householdName) {
    return '가계 $householdName 초대 공유';
  }

  @override
  String get shareInvitation => '초대 공유';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return '가계 $householdName이 성공적으로 생성되었습니다';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return '가계 \"$householdName\"이 성공적으로 생성되었습니다!';
  }

  @override
  String get invitationLink => '초대 링크';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return '초대 링크: $inviteUrl';
  }

  @override
  String get copyInvitationLink => '초대 링크 복사';

  @override
  String get copyInvitationLinkToClipboard => '초대 링크를 클립보드에 복사';

  @override
  String get shareInvitationLink => '초대 링크 공유';

  @override
  String get share => '공유';

  @override
  String get closeShareSheet => '공유 시트 닫기';

  @override
  String get invitationLinkCopiedToClipboard => '초대 링크가 클립보드에 복사되었습니다!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Moneko에서 제 가계 \"$householdName\"에 참여하세요!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Moneko에서 제 가계에 참여하세요';

  @override
  String get zeroAmount => '0.00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => '알림 설정';

  @override
  String get budgetBoop => '예산 콕!';

  @override
  String get getGentleReminder => '이 임계값에 도달했을 때 부드러운 알림 받기';

  @override
  String get purrSuasiveNudge => '가르랑 알림';

  @override
  String get getStrongerNudge => '이 임계값에 도달했을 때 더 강한 넛지 받기';

  @override
  String get createBudgetButton => '예산 생성';

  @override
  String get daily => '일일';

  @override
  String get weekly => '주간';

  @override
  String get monthly => '월간';

  @override
  String get yearly => '연간';

  @override
  String get householdBudgetType => '가계 예산';

  @override
  String get personalBudgetType => '개인 예산';

  @override
  String joinHouseholdName(String householdName) {
    return '\"$householdName\"에 참여';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return '가정 미리보기: $householdName, 초대한 사람: $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return '$inviterEmail님의 초대';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return '초대가 $formattedDate에 곧 만료됩니다';
  }

  @override
  String get invitationValidUntilLabel => '초대 유효 기간';

  @override
  String get personalMessageFromInviter => '초대자의 개인 메시지';

  @override
  String get messageFromInviter => '초대자 메시지';

  @override
  String get joiningHousehold => '그룹 참여 중...';

  @override
  String errorWithMessage(String errorMessage) {
    return '오류: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => '예기치 못한 오류가 발생했습니다';

  @override
  String get invalidInvitationLinkFormat => '유효하지 않은 초대 링크 형식입니다';

  @override
  String get invalidOrExpiredInvitation => '유효하지 않거나 만료된 초대입니다';

  @override
  String get tomorrow => '내일';

  @override
  String inDays(int days) {
    return '$days일 후';
  }

  @override
  String get january => '1월';

  @override
  String get february => '2월';

  @override
  String get march => '3월';

  @override
  String get april => '4월';

  @override
  String get may => '5월';

  @override
  String get june => '6월';

  @override
  String get july => '7월';

  @override
  String get august => '8월';

  @override
  String get september => '9월';

  @override
  String get october => '10월';

  @override
  String get november => '11월';

  @override
  String get december => '12월';

  @override
  String remindUser(String name) {
    return '$name에게 알림 보내기';
  }

  @override
  String get sendFriendlySpendingReminder => '친절한 지출 알림 보내기';

  @override
  String get addMessageOptional => '메시지 추가(선택 사항)';

  @override
  String get messageHintExample => '예: “지갑도 좀 쉬어야 해요!”';

  @override
  String get sendReminder => '알림 보내기';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return '$name에게 다른 알림을 보내려면 24시간 기다려 주세요';
  }

  @override
  String reminderSentToName(String name) {
    return '$name에게 알림을 보냈어요 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => '알림을 보내지 못했습니다. 다시 시도해 주세요.';
}
