// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'ยังไม่มีรายจ่าย';

  @override
  String get loginWelcomeBack => 'ยินดีต้อนรับกลับมา';

  @override
  String get orContinueWithEmail => 'หรือดำเนินการต่อด้วยอีเมล';

  @override
  String get emailAddress => 'อีเมล';

  @override
  String get password => 'รหัสผ่าน';

  @override
  String get forgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get signIn => 'เข้าสู่ระบบ';

  @override
  String get newToMoneko => 'เพิ่งเคยใช้ Moneko ใช่ไหม?';

  @override
  String get createAccount => 'สร้างบัญชี';

  @override
  String get resetYourPassword => 'ตั้งรหัสผ่านใหม่';

  @override
  String get email => 'อีเมล';

  @override
  String get exampleEmail => 'you@example.com';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get sendResetLink => 'ส่งลิงก์ตั้งรหัสผ่านใหม่';

  @override
  String get passwordResetEmailSent => 'ส่งอีเมลตั้งรหัสผ่านใหม่แล้ว โปรดตรวจสอบกล่องจดหมายของคุณ';

  @override
  String get enterValidEmail => 'โปรดระบุอีเมลที่ถูกต้อง';

  @override
  String passwordMinLength(int min) {
    return 'รหัสผ่านต้องมีอย่างน้อย $min ตัวอักษร';
  }

  @override
  String fullNameMinLength(int min) {
    return 'ชื่อ-นามสกุลต้องมีอย่างน้อย $min ตัวอักษร';
  }

  @override
  String get createYourAccount => 'สร้างบัญชีของคุณ';

  @override
  String get fullName => 'ชื่อ-นามสกุล';

  @override
  String get createPassword => 'ตั้งรหัสผ่าน';

  @override
  String get passwordComplexityRequirement => 'รหัสผ่านต้องมีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก และตัวเลขอย่างน้อย 1 ตัว';

  @override
  String get passwordRequirementShort => 'รหัสผ่านต้องยาว 8 ตัวอักษรขึ้นไป และมีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก และตัวเลข';

  @override
  String get termsAgreement => 'การสร้างบัญชีถือว่าคุณยอมรับข้อตกลงการใช้งานและนโยบายความเป็นส่วนตัวของเรา';

  @override
  String get alreadyHaveAccount => 'มีบัญชีอยู่แล้วใช่ไหม?';

  @override
  String get signInLower => 'เข้าสู่ระบบ';

  @override
  String get continueWithWallet => 'เข้าสู่ระบบด้วย Web3 Wallet';

  @override
  String get signingInWithWallet => 'กำลังเชื่อมต่อ Wallet...';

  @override
  String get verificationCodeSent => 'ส่งรหัสยืนยันแล้ว';

  @override
  String get verifyYourEmail => 'ยืนยันอีเมลของคุณ';

  @override
  String verificationEmailSentTo(String email) {
    return 'เราได้ส่งรหัสยืนยัน 6 หลักไปที่ $email แล้ว';
  }

  @override
  String get enterCompleteCode => 'โปรดกรอกรหัสยืนยัน 6 หลักให้ครบ';

  @override
  String get invalidVerificationCode => 'รหัสยืนยันไม่ถูกต้อง';

  @override
  String get verificationCodeExpired => 'รหัสยืนยันหมดอายุแล้ว โปรดขอรหัสใหม่';

  @override
  String get verifyEmail => 'ยืนยันอีเมล';

  @override
  String get didntReceiveTheCode => 'ไม่ได้รับรหัสใช่ไหม? ลองตรวจสอบในจดหมายขยะ (Junk) หรือ';

  @override
  String resendInSeconds(int seconds) {
    return 'ส่งรหัสใหม่ใน $seconds วินาที';
  }

  @override
  String get resendVerificationEmail => 'ส่งอีเมลยืนยันอีกครั้ง';

  @override
  String get continueWithGoogle => 'เข้าสู่ระบบด้วย Google';

  @override
  String get signingInWithGoogle => 'กำลังเข้าสู่ระบบด้วย Google...';

  @override
  String error(String error) {
    return 'เกิดข้อผิดพลาด';
  }

  @override
  String get errorTitle => 'เกิดข้อผิดพลาด';

  @override
  String get createSplit => 'หารบิล';

  @override
  String get equalShare => 'หารเท่ากัน';

  @override
  String get noCashflowYet => 'ยังไม่มีกระแสเงินสด';

  @override
  String get anErrorOccurred => 'เกิดข้อผิดพลาดบางอย่าง';

  @override
  String get monekoEncounteredAnError => 'Moneko พบข้อผิดพลาด';

  @override
  String get unknownError => 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ';

  @override
  String get goToHome => 'กลับหน้าแรก';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ ชำระเงินสำเร็จ! กำลังตรวจสอบสถานะสมาชิก...';

  @override
  String get paymentFailed => 'ชำระเงินไม่สำเร็จ';

  @override
  String get paymentCanceled => 'ℹ️ ยกเลิกการชำระเงินแล้ว';

  @override
  String get whatsappVerifiedSuccessfully => '✅ ยืนยันเบอร์ WhatsApp สำเร็จแล้ว!';

  @override
  String get settings => 'การตั้งค่า';

  @override
  String get enableNotificationsInSettings => 'โปรดเปิดการแจ้งเตือนของ Moneko ในการตั้งค่าของอุปกรณ์';

  @override
  String get appearance => 'การแสดงผล';

  @override
  String get darkMode => 'โหมดมืด';

  @override
  String get notifications => 'การแจ้งเตือน';

  @override
  String get pushNotifications => 'แจ้งเตือนผ่านแอป (Push Notifications)';

  @override
  String get receiveAlertsAndUpdates => 'รับการแจ้งเตือนและอัปเดตต่างๆ';

  @override
  String get language => 'ภาษา';

  @override
  String get systemDefault => 'ตามระบบ';

  @override
  String get membership => 'แพ็กเกจสมาชิก';

  @override
  String get loading => 'กำลังโหลด...';

  @override
  String get failedToLoadMembership => 'โหลดข้อมูลสมาชิกไม่สำเร็จ';

  @override
  String get couldNotOpenMembershipPage => 'เปิดหน้าแพ็กเกจสมาชิกไม่ได้';

  @override
  String get freePlan => 'ฟรี';

  @override
  String get freePlanStatus => 'แพ็กเกจฟรี';

  @override
  String get lifetimePlan => 'ตลอดชีพ';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus รายเดือน';

  @override
  String get plusYearlyPlan => 'Plus รายปี';

  @override
  String get activeStatus => 'ใช้งานอยู่';

  @override
  String get activeLifetimeStatus => 'ใช้งานอยู่ • ตลอดชีพ';

  @override
  String get canceledStatus => 'ยกเลิกแล้ว';

  @override
  String get pastDueStatus => 'ค้างชำระ';

  @override
  String get trialStatus => 'ทดลองใช้ฟรี';

  @override
  String trialEndsInDays(int days) {
    return 'ทดลองใช้ฟรีอีก $days วัน';
  }

  @override
  String get trialEnded => 'หมดช่วงทดลองใช้ฟรี';

  @override
  String renewsInDays(int days) {
    return 'ต่ออายุในอีก $days วัน';
  }

  @override
  String accessEndsInDays(int days) {
    return 'หมดอายุการใช้งานในอีก $days วัน';
  }

  @override
  String get subscriptionEnded => 'แพ็กเกจสมาชิกหมดอายุแล้ว';

  @override
  String get profile => 'โปรไฟล์';

  @override
  String get errorLoadingProfile => 'โหลดโปรไฟล์ไม่สำเร็จ';

  @override
  String get user => 'ผู้ใช้';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'เชื่อมต่อ WhatsApp แล้ว';

  @override
  String get logExpensesViaWhatsApp => 'จดรายจ่ายผ่านข้อความ WhatsApp';

  @override
  String get connectWhatsApp => 'เชื่อมต่อ WhatsApp';

  @override
  String get newBadge => 'ใหม่';

  @override
  String get logExpensesInstantly => 'จดรายจ่ายทันทีผ่านแชท';

  @override
  String get fast => 'รวดเร็ว';

  @override
  String get photo => 'รูปภาพ';

  @override
  String get autoSync => 'ซิงค์อัตโนมัติ';

  @override
  String get naturalLanguage => 'ภาษาพูด';

  @override
  String get describeExpenseAutomatically => 'แค่พิมพ์บอกรายจ่ายแบบปกติ เราจะจดให้อัตโนมัติ';

  @override
  String get snapReceipt => 'ถ่ายสลิป/ใบเสร็จ';

  @override
  String get snapReceiptDescription => 'ถ่ายรูปใบเสร็จ แล้ว AI จะแกะข้อมูลและบันทึกให้เอง';

  @override
  String get previous => 'ก่อนหน้า';

  @override
  String get next => 'ถัดไป';

  @override
  String get overview => 'ภาพรวม';

  @override
  String get activity => 'ความเคลื่อนไหว';

  @override
  String get accountInformation => 'ข้อมูลบัญชี';

  @override
  String get userId => 'User ID';

  @override
  String get recentActivity => 'ความเคลื่อนไหวล่าสุด';

  @override
  String get noActivityYet => 'ยังไม่มีความเคลื่อนไหว';

  @override
  String get signOut => 'ออกจากระบบ';

  @override
  String get insights => 'ข้อมูลเชิงลึก';

  @override
  String get runningTab => 'ยอดคงเหลือ';

  @override
  String get day30Tab => '30 วัน';

  @override
  String get longTermTab => 'ระยะยาว';

  @override
  String get scenarioTab => 'จำลองสถานการณ์';

  @override
  String get runningAndDailyBalances => 'ยอดคงเหลือสะสมและรายวัน';

  @override
  String get budgetVsSpentDescription => 'เทียบงบที่ตั้งไว้กับรายจ่ายแต่ละวัน พร้อมยอดคงเหลือสะสม';

  @override
  String get runningBalanceLegend => 'ยอดคงเหลือสะสม';

  @override
  String get budgetLegend => 'งบประมาณ';

  @override
  String get spentLegend => 'ใช้จ่ายไป';

  @override
  String get runningBalanceGuide => 'ทำความเข้าใจยอดคงเหลือสะสม';

  @override
  String get runningBalanceIntro => 'กราฟนี้เปรียบเสมือนโค้ชการเงินส่วนตัว มาดูกันว่าบอกอะไรเราได้บ้าง';

  @override
  String get day30LookAhead => 'แนวโน้ม 30 วันข้างหน้า';

  @override
  String get projectedFromTrailing30Days => 'คาดการณ์จากพฤติกรรมย้อนหลัง 30 วัน';

  @override
  String get projectedSpendingLegend => 'คาดการณ์รายจ่าย';

  @override
  String get peek30DaysAhead => 'แอบดูแนวโน้ม 30 วันข้างหน้า';

  @override
  String get day30ForecastIntro => 'คาดการณ์จากพฤติกรรมเดือนที่แล้ว เพื่อเดาว่าเดือนหน้าจะใช้เงินประมาณเท่าไหร่ คล้ายพยากรณ์อากาศสำหรับกระเป๋าตังค์ของคุณ';

  @override
  String get longTermProjection => 'คาดการณ์ระยะยาว';

  @override
  String get basedOnHistoricalAverages => 'อิงตามค่าเฉลี่ยที่ผ่านมา (อัปเดตอัตโนมัติตามข้อมูลของคุณ)';

  @override
  String get month18ProjectionLegend => 'แนวโน้ม 18 เดือน';

  @override
  String get your18MonthHorizon => 'ภาพรวม 18 เดือนของคุณ';

  @override
  String get longTermIntro => 'คาดการณ์จากพฤติกรรมปกติรวมกับแผนการเติบโต เพื่อให้เห็นว่าการตัดสินใจวันนี้จะส่งผลต่ออนาคตยังไง';

  @override
  String get aiScenarioPlanning => 'จำลองสถานการณ์ด้วย AI';

  @override
  String get askAiFinancialAdvisor => 'ถามที่ปรึกษาการเงิน AI ดูสิว่าคุณจะรับมือกับค่าใช้จ่ายในอนาคตไหวไหม';

  @override
  String get canI => 'ฉันสามารถ';

  @override
  String get before => 'ก่อนวันที่';

  @override
  String get beforePrefix => 'ก่อน';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'เลือกวันที่';

  @override
  String get check => 'ตรวจสอบ';

  @override
  String get enterQuestionAndPickDate => 'โปรดพิมพ์คำถามและเลือกวันที่';

  @override
  String get analyzingScenario => 'กำลังวิเคราะห์สถานการณ์...';

  @override
  String get thisMightTakeAWhile => 'อาจใช้เวลาสักครู่';

  @override
  String get whereTheMoneyWent => 'เงินหายไปไหนหมด';

  @override
  String get categoryTotalsForSelectedRange => 'ยอดรวมแต่ละหมวดหมู่ในช่วงเวลาที่เลือก';

  @override
  String get scenarioCategoriesGuide => 'ทำความเข้าใจหมวดหมู่';

  @override
  String get categoryGuideIntro => 'มองกราฟนี้เป็นภาพมุมสูงที่บอกว่าเงินแต่ละบาทปลิวไปไหนบ้าง มาดูวิธีอ่านกราฟง่ายๆ กันเลย';

  @override
  String get readTheBarChartLikeAPro => 'อ่านกราฟแท่งแบบมือโปร';

  @override
  String get categoryChartDesc => 'สัดส่วนค่าใช้จ่ายตามหมวดหมู่ในช่วงเวลาที่เลือก';

  @override
  String get whyThisViewIsHelpful => 'กราฟนี้ช่วยอะไรได้บ้าง?';

  @override
  String get categoryWhyHelpfulDesc => 'ช่วยให้เห็นหมวดที่กินเงินมากที่สุดได้อย่างรวดเร็ว และตามเทรนด์การใช้จ่ายได้ทัน';

  @override
  String get whatToDoWithTheInsight => 'เอาข้อมูลไปทำอะไรต่อได้บ้าง';

  @override
  String get categoryWhatToDoDesc => 'ใช้ปรับงบประมาณและพฤติกรรมการใช้เงินของคุณให้ดีขึ้น';

  @override
  String get scenarioAnalysis => 'วิเคราะห์สถานการณ์';

  @override
  String get target => 'เป้าหมาย';

  @override
  String get quickStats => 'สถิติคร่าวๆ';

  @override
  String get currentBalance => 'ยอดเงินปัจจุบัน';

  @override
  String get projectedNoChange => 'แนวโน้ม (ถ้าไม่ปรับแผน)';

  @override
  String get avgDailyNet => 'ยอดสุทธิเฉลี่ยต่อวัน';

  @override
  String get noDataAvailable => 'ไม่มีข้อมูล';

  @override
  String get day => 'วัน';

  @override
  String get close => 'ปิด';

  @override
  String get whatYouAreSeeing => 'กราฟนี้บอกอะไร';

  @override
  String get whyItMatters => 'ทำไมถึงสำคัญ';

  @override
  String get howToRespond => 'ควรรับมือยังไง';

  @override
  String get runningBalanceWhatYouSeeDesc => 'ยอดสะสมจะบอกว่าคุณมีเงินเหลือแค่ไหนหลังใช้จ่ายไปในแต่ละวัน ส่วนกราฟแท่งจะเทียบงบที่ตั้งไว้กับยอดที่จ่ายจริง';

  @override
  String get runningBalanceWhyMattersDesc => 'ถือเป็นการเช็คสุขภาพการเงิน ถ้าใช้จ่ายน้อยกว่างบ ก็มีเงินไปเก็บเพิ่ม ถ้าทะลุงบ ก็จะได้รีบปรับพฤติกรรมทัน';

  @override
  String get runningBalanceHowToRespondDesc => 'ใช้กราฟนี้เป็นเหมือนโค้ชส่วนตัว ภูมิใจเมื่อทำตามเป้าได้ ปรับแผนเมื่อจำเป็น และไม่ต้องตึงเกินไป—เราเน้นความสม่ำเสมอ ไม่ใช่ความเพอร์เฟกต์';

  @override
  String get whatTheForecastShows => 'การคาดการณ์บอกอะไร';

  @override
  String get day30WhatShowsDesc => 'เรานำรายรับรายจ่ายจาก 30 วันที่ผ่านมา มาเกลี่ยหาค่าเฉลี่ย เพื่อให้คุณเห็นจังหวะการใช้เงินที่แท้จริงแบบไม่รวมรายจ่ายก้อนโตแบบปุบปับ';

  @override
  String get day30WhyMattersDesc => 'การเห็นงบล่วงหน้าช่วยให้คุณเตรียมพร้อมรู้ว่าช่วงไหนจะใช้เงินเยอะ จะได้กันเงินไว้ก่อน ดีกว่ามานั่งปวดหัวทีหลัง';

  @override
  String get day30HowToPlaySmartDesc => 'มองว่านี่เป็นแค่การสะกิดเตือน ไม่ใช่กฎตายตัว ลองค่อยๆ ปรับการใช้จ่ายทีละนิดให้ทำได้จริง';

  @override
  String get howTheProjectionWorks => 'ระบบคาดการณ์ทำงานยังไง';

  @override
  String get longTermHowWorksDesc => 'เราใช้ค่าเฉลี่ยรายรับรายจ่ายของคุณมาประเมินล่วงหน้า เพื่อดูว่าแผนการเงินของคุณยังมั่นคงไปอีกหลายเดือนข้างหน้าหรือไม่';

  @override
  String get longTermWhyMattersDesc => 'การมองภาพระยะยาวจะช่วยให้เป้าหมายใหญ่ๆ เป็นจริงได้ ช่วยเช็คว่าเงินสำรองฉุกเฉิน การลงทุน หรือแผนซื้อของชิ้นใหญ่ ยังเดินหน้าตามเป้าอยู่ไหม';

  @override
  String get longTermMovesToConsiderDesc => 'ใช้กราฟนี้จำลองการตัดสินใจล่วงหน้า การปรับแผนเล็กๆ ในวันนี้ อาจเห็นผลลัพธ์ที่ยิ่งใหญ่ในอนาคต';

  @override
  String get forMe => 'ส่วนตัว';

  @override
  String get forUs => 'ส่วนรวม';

  @override
  String get home => 'หน้าแรก';

  @override
  String get reminder => 'การแจ้งเตือน';

  @override
  String get analyzingReceipt => 'กำลังวิเคราะห์ใบเสร็จ...';

  @override
  String get analyzingExpense => 'กำลังวิเคราะห์ค่าใช้จ่าย...';

  @override
  String get noExpenseInformationExtracted => 'แกะข้อมูลค่าใช้จ่ายไม่สำเร็จ';

  @override
  String get failedToAnalyzeNoData => 'วิเคราะห์ไม่สำเร็จ: ไม่มีข้อมูลตอบกลับ';

  @override
  String get failedToAnalyze => 'วิเคราะห์ไม่สำเร็จ';

  @override
  String get updateBudget => 'อัปเดตงบ';

  @override
  String get enterNewTotalDailyBudget => 'กรอกงบรวมรายวันใหม่';

  @override
  String get budgetAmount => 'ยอดงบประมาณ';

  @override
  String get save => 'บันทึก';

  @override
  String get enterValidAmountGreaterThan0 => 'โปรดระบุจำนวนเงินที่ถูกต้อง (มากกว่า 0)';

  @override
  String get updatingBudget => 'กำลังอัปเดตงบ...';

  @override
  String get budgetUpdated => 'อัปเดตงบเรียบร้อย';

  @override
  String get failedToUpdateBudget => 'อัปเดตงบไม่สำเร็จ';

  @override
  String get loggedSuccessfully => 'จดบันทึกสำเร็จ';

  @override
  String get expenseUpdatedSuccessfully => 'อัปเดตรายจ่ายสำเร็จ';

  @override
  String get view => 'ดู';

  @override
  String get retry => 'ลองใหม่';

  @override
  String get failedToCapturePhoto => 'ถ่ายรูปไม่สำเร็จ';

  @override
  String get noSpendingData => 'ยังไม่มีข้อมูลรายจ่าย';

  @override
  String get byCategory => 'ตามหมวดหมู่';

  @override
  String get noExpensesYet => 'ยังไม่มีรายจ่าย';

  @override
  String get startLoggingExpensesToSeeCategories => 'จดรายจ่ายเพื่อดูสัดส่วนตามหมวดหมู่ที่นี่';

  @override
  String get selectDateRange => 'เลือกช่วงเวลา';

  @override
  String get addExpense => 'เพิ่มรายจ่าย';

  @override
  String get describeYourExpense => 'พิมพ์บอกรายจ่ายหรือรายรับของคุณ (ทีละรายการ)';

  @override
  String get enterExpenseDetails => 'เช่น \"เบอร์เกอร์ 150 กาแฟ 60\" หรือ \"แม่ให้เงิน 3000\"';

  @override
  String get addEntry => 'เพิ่มรายการ';

  @override
  String get freeFormText => 'พิมพ์ข้อความ';

  @override
  String get takePhoto => 'ถ่ายรูป';

  @override
  String get transactions => 'รายการธุรกรรม';

  @override
  String get negative => 'รายจ่าย';

  @override
  String get positive => 'รายรับ';

  @override
  String get savingsRate => 'อัตราการออม';

  @override
  String get budgetRunway => 'งบที่เหลือใช้';

  @override
  String get avgDaily => 'เฉลี่ยรายวัน';

  @override
  String get left => 'คงเหลือ';

  @override
  String get spendingBreakdown => 'สัดส่วนรายจ่าย';

  @override
  String get spent => 'ใช้ไปแล้ว';

  @override
  String get today => 'วันนี้';

  @override
  String get yesterday => 'เมื่อวาน';

  @override
  String get thisWeek => 'สัปดาห์นี้';

  @override
  String get lastWeek => 'สัปดาห์ที่แล้ว';

  @override
  String get thisMonth => 'เดือนนี้';

  @override
  String get last7Days => '7 วันที่ผ่านมา';

  @override
  String get last30Days => '30 วันที่ผ่านมา';

  @override
  String get customRange => 'กำหนดช่วงเวลาเอง';

  @override
  String get spentToday => 'จ่ายไปวันนี้';

  @override
  String get spentYesterday => 'จ่ายไปเมื่อวาน';

  @override
  String get spentThisWeek => 'จ่ายไปสัปดาห์นี้';

  @override
  String get spentLastWeek => 'จ่ายไปสัปดาห์ที่แล้ว';

  @override
  String get spentThisMonth => 'จ่ายไปเดือนนี้';

  @override
  String get spentLast30Days => 'จ่ายไป (30 วันที่ผ่านมา)';

  @override
  String get spentCustom => 'จ่ายไป (กำหนดเอง)';

  @override
  String get todaysBudget => 'งบวันนี้';

  @override
  String get yesterdaysBudget => 'งบเมื่อวาน';

  @override
  String get sumOfDailyBudgetsThisWeek => 'รวมงบสัปดาห์นี้';

  @override
  String get sumOfDailyBudgetsLastWeek => 'รวมงบสัปดาห์ที่แล้ว';

  @override
  String get sumOfDailyBudgetsThisMonth => 'รวมงบเดือนนี้';

  @override
  String get sumOfDailyBudgetsLast30Days => 'รวมงบ 30 วันที่ผ่านมา';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'รวมงบในช่วงเวลาที่เลือก';

  @override
  String get netCashflowToday => 'ยอดเงินสุทธิวันนี้';

  @override
  String get netCashflowYesterday => 'ยอดเงินสุทธิเมื่อวาน';

  @override
  String get netCashflowThisWeek => 'ยอดเงินสุทธิสัปดาห์นี้';

  @override
  String get netCashflowLastWeek => 'ยอดเงินสุทธิสัปดาห์ที่แล้ว';

  @override
  String get netCashflowThisMonth => 'ยอดเงินสุทธิเดือนนี้';

  @override
  String get netCashflowLast30Days => 'ยอดเงินสุทธิ (30 วันที่ผ่านมา)';

  @override
  String get netCashflowCustom => 'ยอดเงินสุทธิ (กำหนดเอง)';

  @override
  String get selectCurrency => 'เลือกสกุลเงิน';

  @override
  String get showLessCurrencies => 'ซ่อนสกุลเงิน';

  @override
  String showAllCurrencies(int count) {
    return 'แสดงสกุลเงินทั้งหมด (อีก $count รายการ)';
  }

  @override
  String get budget => 'งบประมาณ';

  @override
  String get spentLabel => 'จ่ายไป';

  @override
  String get net => 'สุทธิ';

  @override
  String get txn => 'รายการ';

  @override
  String get txns => 'รายการ';

  @override
  String get pleaseEnterExpenseDetails => 'โปรดระบุรายละเอียดรายจ่าย';

  @override
  String get userNotLoggedIn => 'ผู้ใช้ยังไม่ได้เข้าสู่ระบบ';

  @override
  String get errorLoadingHouseholds => 'โหลดข้อมูลสเปซไม่สำเร็จ';

  @override
  String get welcomeToHouseholds => 'ยินดีต้อนรับสู่สเปซ';

  @override
  String get householdsDescription => 'สร้างสเปซที่แชร์ร่วมกันเพื่อติดตามรายจ่ายและจัดการงบกับครอบครัว แฟน หรือแก๊งเพื่อน';

  @override
  String get createHousehold => 'สร้างสเปซ';

  @override
  String get joinWithInvite => 'เข้าร่วมผ่านคำเชิญ';

  @override
  String get pleaseUseInvitationLink => 'โปรดใช้ลิงก์คำเชิญเพื่อเข้าร่วมสเปซ';

  @override
  String get householdName => 'ชื่อสเปซ';

  @override
  String get householdNameHint => 'ตั้งชื่อสเปซ';

  @override
  String get pleaseEnterHouseholdName => 'โปรดระบุชื่อสเปซ';

  @override
  String get errorCreatingHousehold => 'สร้างสเปซไม่สำเร็จ';

  @override
  String get householdsFeature => 'ฟีเจอร์ของสเปซ';

  @override
  String get householdsFeatureDescription => 'แชร์รายจ่าย ติดตามงบ และจัดการเงินร่วมกับสมาชิกในสเปซของคุณ';

  @override
  String get gotIt => 'เข้าใจแล้ว!';

  @override
  String get confirmExpense => 'ยืนยันรายจ่าย';

  @override
  String get expenseDetails => 'รายละเอียดรายจ่าย';

  @override
  String get details => 'รายละเอียด';

  @override
  String get category => 'หมวดหมู่';

  @override
  String get currency => 'สกุลเงิน';

  @override
  String get date => 'วันที่';

  @override
  String get time => 'เวลา';

  @override
  String get notes => 'บันทึกย่อ';

  @override
  String get receipt => 'ใบเสร็จ';

  @override
  String get saveExpense => 'บันทึกรายจ่าย';

  @override
  String get shareWithHousehold => 'แชร์กับสเปซ';

  @override
  String get loadingHouseholdMembers => 'กำลังโหลดสมาชิก...';

  @override
  String get selectHouseholdToConfigureSplit => 'เลือกสเปซเพื่อตั้งค่าการหารบิล';

  @override
  String get currencyManagedByHousehold => 'สกุลเงินถูกจัดการโดยสเปซ ไม่สามารถเปลี่ยนได้';

  @override
  String get currencyCannotBeChanged => 'ไม่สามารถเปลี่ยนสกุลเงินได้เมื่อแชร์กับสเปซ';

  @override
  String get cannotEditOthersExpenses => 'แก้ได้เฉพาะรายจ่ายของคุณเท่านั้น';

  @override
  String get failedToLoadImage => 'โหลดรูปภาพไม่สำเร็จ';

  @override
  String get editAmount => 'แก้ไขยอดเงิน';

  @override
  String get amount => 'จำนวนเงิน';

  @override
  String get editNotes => 'แก้ไขบันทึกย่อ';

  @override
  String get addANote => 'เพิ่มบันทึก...';

  @override
  String get noMembersFoundInHousehold => 'ไม่พบสมาชิกในสเปซนี้';

  @override
  String get errorLoadingMembers => 'โหลดสมาชิกไม่สำเร็จ';

  @override
  String get noExpenseToSave => 'ไม่มีรายจ่ายให้บันทึก';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'บันทึกและแชร์รายจ่ายแล้ว $splitInfo!';
  }

  @override
  String get expenseSaved => 'บันทึกรายจ่ายแล้ว!';

  @override
  String failedToSave(String error) {
    return 'บันทึกไม่สำเร็จ: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'ซิงค์การตั้งค่าสกุลเงินไม่สำเร็จ: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'อัปเดตสกุลเงินสำเร็จ';

  @override
  String retryFailed(Object error) {
    return 'ลองใหม่ไม่สำเร็จ: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'ฉันจ่าย $currencySymbol$amount สำหรับ $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'กรอกยอดงบรวมรายวันใหม่';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'โปรดเข้าสู่ระบบเพื่อใช้งานฟีเจอร์สเปซ';

  @override
  String get quickActions => 'เมนูด่วน';

  @override
  String get members => 'สมาชิก';

  @override
  String get invites => 'คำเชิญ';

  @override
  String get errorLoadingExpenses => 'โหลดรายจ่ายไม่สำเร็จ';

  @override
  String get budgets => 'งบประมาณ';

  @override
  String get loadingHousehold => 'กำลังโหลดสเปซ...';

  @override
  String get remaining => 'คงเหลือ';

  @override
  String get overBudget => 'เกินงบ';

  @override
  String get sharedBudgets => 'งบกองกลาง';

  @override
  String get netPosition => 'ยอดสุทธิ';

  @override
  String get spentByHousehold => 'ยอดจ่ายของสเปซ';

  @override
  String get memberSpending => 'ยอดจ่ายของสมาชิก';

  @override
  String get spentByHouseholdTooltip => 'แสดงยอดเงินรวมที่สมาชิกทุกคนในสเปซจ่ายไปในช่วงเวลาที่เลือก รวมถึงรายจ่ายที่แชร์โดยสมาชิกคนใดคนหนึ่งด้วย';

  @override
  String get manageMoneyTogether => 'จัดการเงินร่วมกับแฟน ครอบครัว หรือเพื่อนร่วมห้องในสเปซเดียวกัน';

  @override
  String get sharedBudgetsExpenses => 'งบและรายจ่ายกองกลาง';

  @override
  String get sharedBudgetsExpensesDesc => 'ตั้งงบ ติดตามการใช้จ่าย และดูว่าเงินกองกลางปลิวไปไหนบ้างแบบเรียลไทม์';

  @override
  String get smartExpenseSplitting => 'หารบิลอัจฉริยะ';

  @override
  String get smartExpenseSplittingDesc => 'คำนวณอัตโนมัติว่าใครต้องจ่ายเท่าไหร่ จะหารเท่าๆ กัน คิดเป็นเปอร์เซ็นต์ หรือระบุยอดเองก็ทำได้';

  @override
  String get stayInSync => 'ซิงค์กันอยู่เสมอ';

  @override
  String get stayInSyncDesc => 'รับการแจ้งเตือนเมื่อมีการเพิ่มรายจ่าย เมื่องบใกล้หมด หรือเมื่อถึงเวลาต้องเคลียร์บิล';

  @override
  String get householdSettings => 'การตั้งค่าสเปซ';

  @override
  String get householdNotFound => 'ไม่พบสเปซ';

  @override
  String get coverPhoto => 'รูปหน้าปก';

  @override
  String get changeCoverPhoto => 'เปลี่ยนรูปหน้าปก';

  @override
  String get saveChanges => 'บันทึกการเปลี่ยนแปลง';

  @override
  String get errorLoadingHousehold => 'โหลดสเปซไม่สำเร็จ';

  @override
  String get householdUpdatedSuccessfully => 'อัปเดตสเปซสำเร็จ';

  @override
  String get failedToUpdateHousehold => 'อัปเดตสเปซไม่สำเร็จ';

  @override
  String get inviteMember => 'เชิญสมาชิก';

  @override
  String get removeMember => 'ลบสมาชิก';

  @override
  String get remove => 'ลบออก';

  @override
  String get confirmRemoveMember => 'คุณแน่ใจหรือไม่ว่าต้องการลบ';

  @override
  String get updatedMemberRole => 'อัปเดตตำแหน่งสมาชิกแล้ว';

  @override
  String get unknown => 'ไม่ทราบ';

  @override
  String get makeAdmin => 'ตั้งเป็นแอดมิน';

  @override
  String get makeMember => 'ตั้งเป็นสมาชิก';

  @override
  String get invitations => 'คำเชิญ';

  @override
  String get errorLoadingInvites => 'โหลดคำเชิญไม่สำเร็จ';

  @override
  String get createInvitation => 'สร้างคำเชิญ';

  @override
  String get pendingInvitations => 'คำเชิญที่รอดำเนินการ';

  @override
  String get noPendingInvitations => 'ไม่มีคำเชิญค้างอยู่';

  @override
  String get invitationHistory => 'ประวัติคำเชิญ';

  @override
  String get noInvitationHistory => 'ไม่มีประวัติคำเชิญ';

  @override
  String get emailOptional => 'อีเมล (ไม่บังคับ)';

  @override
  String get friendEmailExample => 'friend@example.com';

  @override
  String get personalMessageOptional => 'ข้อความส่วนตัว (ไม่บังคับ)';

  @override
  String get joinHouseholdBudget => 'มาร่วมจัดการงบการเงินสเปซเราสิ!';

  @override
  String get expiresIn => 'หมดอายุใน';

  @override
  String get oneDay => '1 วัน';

  @override
  String get threeDays => '3 วัน';

  @override
  String get sevenDays => '7 วัน';

  @override
  String get fourteenDays => '14 วัน';

  @override
  String get thirtyDays => '30 วัน';

  @override
  String get unlimited => 'ไม่มีวันหมดอายุ';

  @override
  String get create => 'สร้าง';

  @override
  String get invitationCreatedSuccessfully => 'สร้างคำเชิญสำเร็จ';

  @override
  String get inviteLinkCopiedToClipboard => 'คัดลอกลิงก์คำเชิญแล้ว!';

  @override
  String get errorCreatingInvite => 'สร้างคำเชิญไม่สำเร็จ';

  @override
  String get revokeInvitation => 'ยกเลิกคำเชิญ';

  @override
  String get confirmRevokeInvitation => 'คุณแน่ใจหรือไม่ว่าต้องการยกเลิกคำเชิญนี้?';

  @override
  String get revoke => 'ยกเลิก';

  @override
  String get invitationRevoked => 'ยกเลิกคำเชิญแล้ว';

  @override
  String get errorRevokingInvite => 'ยกเลิกคำเชิญไม่สำเร็จ';

  @override
  String get anyoneWithLink => 'ใครก็ตามที่มีลิงก์';

  @override
  String get noExpiry => 'ไม่มีวันหมดอายุ';

  @override
  String get expired => 'หมดอายุแล้ว';

  @override
  String get expires => 'หมดอายุ';

  @override
  String get copyLink => 'คัดลอกลิงก์';

  @override
  String get selectCoverImage => 'เลือกรูปหน้าปก';

  @override
  String get failedToLoadImages => 'โหลดรูปภาพไม่สำเร็จ';

  @override
  String get chooseFromGallery => 'เลือกจากคลังภาพ';

  @override
  String get failedToLoad => 'โหลดไม่สำเร็จ';

  @override
  String get imageTooLarge => 'รูปภาพใหญ่เกินไป';

  @override
  String get maxIs => 'ขนาดสูงสุดคือ';

  @override
  String get unsupportedFileFormat => 'ไม่รองรับไฟล์นี้ โปรดใช้ JPG, PNG หรือ WebP';

  @override
  String get cropCoverImage => 'ครอปรูปหน้าปก';

  @override
  String get editBudget => 'แก้ไขงบ';

  @override
  String get budgetDetails => 'รายละเอียดงบ';

  @override
  String get budgetName => 'ชื่องบ';

  @override
  String get period => 'รอบเวลา';

  @override
  String get alertThresholds => 'การตั้งค่าแจ้งเตือน';

  @override
  String get warningThreshold => 'ระดับเตือนเบาๆ (%)';

  @override
  String get alertThreshold => 'ระดับเตือนวิกฤต (%)';

  @override
  String get warningThresholdHelper => 'แจ้งเตือนเมื่องบถูกใช้ถึงเปอร์เซ็นต์นี้';

  @override
  String get alertThresholdHelper => 'แจ้งเตือนแบบจริงจังเมื่อถึงเปอร์เซ็นต์นี้';

  @override
  String get budgetStatus => 'สถานะงบ';

  @override
  String get active => 'เปิดใช้งาน';

  @override
  String get inactive => 'ปิดใช้งาน';

  @override
  String get deletingBudget => 'กำลังลบงบ...';

  @override
  String get savingChanges => 'กำลังบันทึก...';

  @override
  String get budgetNameCannotBeEmpty => 'โปรดตั้งชื่องบ';

  @override
  String get pleaseEnterValidAmount => 'โปรดระบุจำนวนเงินให้ถูกต้อง';

  @override
  String get warningThresholdRange => 'ระดับเตือนเบาๆ ต้องอยู่ระหว่าง 0 ถึง 100';

  @override
  String get alertThresholdRange => 'ระดับเตือนวิกฤตต้องอยู่ระหว่าง 0 ถึง 100';

  @override
  String get warningThresholdLessThanAlert => 'ระดับเตือนเบาๆ ต้องน้อยกว่าหรือเท่ากับระดับเตือนวิกฤต';

  @override
  String get deleteBudget => 'ลบงบ';

  @override
  String get confirmDeleteBudget => 'คุณแน่ใจหรือไม่ว่าต้องการลบ';

  @override
  String get thisActionCannotBeUndone => 'การดำเนินการนี้ไม่สามารถย้อนกลับได้';

  @override
  String get budgetUpdatedSuccessfully => 'อัปเดตงบสำเร็จ';

  @override
  String get budgetDeletedSuccessfully => 'ลบงบสำเร็จ';

  @override
  String get categoryTransfers => 'โอนเงิน';

  @override
  String get categoryShopping => 'ช้อปปิ้ง';

  @override
  String get categoryUtilities => 'สาธารณูปโภค';

  @override
  String get categoryEntertainment => 'ความบันเทิง';

  @override
  String get categoryEntertainmentSubscriptions => 'สมาชิกรายเดือน/บันเทิง';

  @override
  String get categoryRestaurants => 'ร้านอาหาร';

  @override
  String get categoryFood => 'อาหาร';

  @override
  String get categoryGroceries => 'ของใช้ในบ้าน';

  @override
  String get categoryTransport => 'การเดินทาง';

  @override
  String get categoryTransportation => 'การเดินทาง';

  @override
  String get categoryTravel => 'ท่องเที่ยว';

  @override
  String get categoryFlights => 'เที่ยวบิน';

  @override
  String get categoryVacation => 'ทริปพักผ่อน';

  @override
  String get categoryHealth => 'สุขภาพ';

  @override
  String get categoryMedical => 'การรักษาพยาบาล';

  @override
  String get categoryText => 'ข้อความ';

  @override
  String get categoryEducation => 'การศึกษา';

  @override
  String get categoryTuition => 'ค่าเทอม';

  @override
  String get categorySubscriptions => 'ค่าสมาชิก/รายเดือน';

  @override
  String get categoryServices => 'บริการต่างๆ';

  @override
  String get categoryHousing => 'ที่อยู่อาศัย';

  @override
  String get categoryRent => 'ค่าเช่า';

  @override
  String get categoryMortgage => 'ผ่อนบ้าน';

  @override
  String get categoryBills => 'บิลต่างๆ';

  @override
  String get categoryInsurance => 'ประกันภัย';

  @override
  String get categorySavings => 'เงินออม';

  @override
  String get categoryInvestment => 'การลงทุน';

  @override
  String get categoryInvestments => 'การลงทุน';

  @override
  String get categoryIncome => 'รายรับ';

  @override
  String get categorySalary => 'เงินเดือน';

  @override
  String get categoryBonus => 'โบนัส';

  @override
  String get categoryPets => 'สัตว์เลี้ยง';

  @override
  String get categoryKids => 'ลูก/เด็ก';

  @override
  String get categoryFamily => 'ครอบครัว';

  @override
  String get categoryGifts => 'ของขวัญ';

  @override
  String get categoryCharity => 'บริจาค';

  @override
  String get categoryFees => 'ค่าธรรมเนียม';

  @override
  String get categoryLoan => 'จ่ายเงินกู้';

  @override
  String get categoryLoans => 'สินเชื่อ/เงินกู้';

  @override
  String get categoryDebt => 'จ่ายหนี้';

  @override
  String get categoryPersonalCare => 'ของใช้ส่วนตัว';

  @override
  String get categoryBeauty => 'ความงาม';

  @override
  String get categoryMisc => 'จิปาถะ';

  @override
  String get categoryUncategorized => 'ไม่ได้จัดหมวดหมู่';

  @override
  String get categoryTips => 'ทิป';

  @override
  String get categoryRentalIncome => 'ค่าเช่ารับ';

  @override
  String get categoryInterestIncome => 'ดอกเบี้ยรับ';

  @override
  String get categoryCashback => 'เงินคืน (Cashback)';

  @override
  String get categoryPension => 'เงินบำนาญ';

  @override
  String get categoryFoodAndDrinks => 'อาหารและเครื่องดื่ม';

  @override
  String get categoryTakeoutDelivery => 'เดลิเวอรี่และสั่งกลับบ้าน';

  @override
  String get categoryCoffeeTea => 'คาเฟ่ ชา กาแฟ';

  @override
  String get categorySnacks => 'ขนมและของว่าง';

  @override
  String get categoryHouseholdSupplies => 'ของใช้ในบ้าน';

  @override
  String get categoryCleaningSupplies => 'อุปกรณ์ทำความสะอาด';

  @override
  String get categoryHomeRepairs => 'ซ่อมแซมบ้าน';

  @override
  String get categoryHomeServices => 'บริการดูแลบ้าน';

  @override
  String get categoryFurniture => 'เฟอร์นิเจอร์';

  @override
  String get categoryAppliances => 'เครื่องใช้ไฟฟ้า';

  @override
  String get categoryHomeDecor => 'ของแต่งบ้าน';

  @override
  String get categoryElectricity => 'ค่าไฟ';

  @override
  String get categoryWater => 'ค่าน้ำ';

  @override
  String get categoryHeatingGas => 'ค่าแก๊ส/ทำความร้อน';

  @override
  String get categoryInternet => 'ค่าเน็ต';

  @override
  String get categoryPhoneBill => 'ค่าโทรศัพท์';

  @override
  String get categoryTrashRecycling => 'ค่าเก็บขยะ';

  @override
  String get categoryHomeSecurity => 'ระบบรักษาความปลอดภัย';

  @override
  String get categoryLaundryDryCleaning => 'ซักรีด/ซักแห้ง';

  @override
  String get categoryMovingCosts => 'ค่าขนย้าย';

  @override
  String get categoryStorage => 'ค่าเช่าที่เก็บของ';

  @override
  String get categoryClothingShoes => 'เสื้อผ้าและรองเท้า';

  @override
  String get categoryPublicTransport => 'ขนส่งสาธารณะ';

  @override
  String get categoryTaxiRideApps => 'แท็กซี่/เรียกรถ';

  @override
  String get categoryFuelGas => 'ค่าน้ำมัน';

  @override
  String get categoryParking => 'ค่าที่จอดรถ';

  @override
  String get categoryTolls => 'ค่าทางด่วน';

  @override
  String get categoryCarRepairs => 'ซ่อมบำรุงรถ';

  @override
  String get categoryCarInsurance => 'ประกันรถยนต์';

  @override
  String get categoryCarParts => 'อะไหล่รถ';

  @override
  String get categoryCarRental => 'เช่ารถ';

  @override
  String get categoryBikeScooter => 'จักรยาน/สกู๊ตเตอร์';

  @override
  String get categoryHotels => 'โรงแรม/ที่พัก';

  @override
  String get categoryTravelInsurance => 'ประกันเดินทาง';

  @override
  String get categoryTravelActivities => 'กิจกรรมท่องเที่ยว';

  @override
  String get categoryLuggageGear => 'อุปกรณ์เดินทาง';

  @override
  String get categoryPassportVisaFees => 'ค่าทำพาสปอร์ต/วีซ่า';

  @override
  String get categoryMedicalCare => 'การรักษาพยาบาล';

  @override
  String get categoryPharmacy => 'ยา/ร้านขายยา';

  @override
  String get categoryDentalCare => 'ทำฟัน';

  @override
  String get categoryEyeCare => 'ดูแลสายตา/แว่นตา';

  @override
  String get categoryMentalHealth => 'ดูแลสุขภาพจิต';

  @override
  String get categoryTherapy => 'จิตบำบัด';

  @override
  String get categoryFitnessGym => 'ฟิตเนส/ยิม';

  @override
  String get categorySportsExercise => 'กีฬา/ออกกำลังกาย';

  @override
  String get categorySupplements => 'อาหารเสริม';

  @override
  String get categoryBeautyCosmetics => 'ความงาม/เครื่องสำอาง';

  @override
  String get categorySpaMassage => 'สปาและนวด';

  @override
  String get categoryChildcare => 'พี่เลี้ยงเด็ก/เนอสเซอรี่';

  @override
  String get categorySchoolSupplies => 'อุปกรณ์การเรียน';

  @override
  String get categoryKidsActivities => 'กิจกรรมลูก';

  @override
  String get categoryKidsClothing => 'เสื้อผ้าเด็ก';

  @override
  String get categoryToysGames => 'ของเล่นและเกม';

  @override
  String get categoryBabySupplies => 'ของใช้เด็กอ่อน';

  @override
  String get categoryPetFood => 'อาหารสัตว์เลี้ยง';

  @override
  String get categoryPetTreats => 'ขนมสัตว์เลี้ยง';

  @override
  String get categoryVetVisits => 'หาหมอสัตว์';

  @override
  String get categoryPetMedicine => 'ยาสัตว์เลี้ยง';

  @override
  String get categoryPetGrooming => 'อาบน้ำตัดขนสัตว์';

  @override
  String get categoryPetSupplies => 'ของใช้สัตว์เลี้ยง';

  @override
  String get categoryPetInsurance => 'ประกันสัตว์เลี้ยง';

  @override
  String get categoryPetBoardingSitting => 'ฝากเลี้ยงสัตว์';

  @override
  String get categoryWorkSupplies => 'อุปกรณ์ทำงาน';

  @override
  String get categoryHomeOffice => 'โฮมออฟฟิศ';

  @override
  String get categorySoftwareTools => 'ซอฟต์แวร์และแอป';

  @override
  String get categoryCloudStorage => 'Cloud Storage';

  @override
  String get categoryCoursesClasses => 'คอร์สเรียน';

  @override
  String get categoryBooksStudyMaterials => 'หนังสือและสื่อการเรียน';

  @override
  String get categoryExamsCertificates => 'ค่าสอบ/ใบเซอร์';

  @override
  String get categoryCoworkingSpace => 'Co-working Space';

  @override
  String get categoryProfessionalServices => 'บริการเฉพาะทาง';

  @override
  String get categoryBusinessExpenses => 'ค่าใช้จ่ายธุรกิจ';

  @override
  String get categoryAdsMarketing => 'ค่าโฆษณา/การตลาด';

  @override
  String get categoryLicensingFees => 'ค่าลิขสิทธิ์และธรรมเนียม';

  @override
  String get categoryMoviesShows => 'ดูหนัง/ซีรีส์';

  @override
  String get categoryMusicStreaming => 'ฟังเพลง/สตรีมมิ่ง';

  @override
  String get categoryGamesApps => 'เกมและแอป';

  @override
  String get categoryHobbies => 'งานอดิเรก';

  @override
  String get categoryCraftsArt => 'งานคราฟต์/ศิลปะ';

  @override
  String get categorySportsClubs => 'สโมสรกีฬา';

  @override
  String get categoryConcertsEvents => 'คอนเสิร์ตและอีเวนต์';

  @override
  String get categoryBarsDrinks => 'บาร์/ปาร์ตี้';

  @override
  String get categoryDating => 'ออกเดท';

  @override
  String get categoryPartiesHosting => 'จัดปาร์ตี้';

  @override
  String get categoryCollectibles => 'ของสะสม';

  @override
  String get categoryFreelanceIncome => 'รายได้ฟรีแลนซ์';

  @override
  String get categoryRefunds => 'เงินคืน';

  @override
  String get categoryLoanPayments => 'จ่ายสินเชื่อ';

  @override
  String get categoryDebtPayments => 'จ่ายหนี้';

  @override
  String get categoryBankFees => 'ค่าธรรมเนียมธนาคาร';

  @override
  String get categoryTaxes => 'จ่ายภาษี';

  @override
  String get categoryFines => 'ค่าปรับ';

  @override
  String get categoryGovernmentServices => 'บริการภาครัฐ';

  @override
  String get categoryPostDelivery => 'ไปรษณีย์และขนส่ง';

  @override
  String get categoryReligiousSpiritual => 'ทำบุญ/ศาสนา';

  @override
  String get categoryCommunityEvents => 'กิจกรรมเพื่อสังคม';

  @override
  String get categoryEnvironmentalGreen => 'รักษ์โลก';

  @override
  String get categoryMiscellaneous => 'จิปาถะ';

  @override
  String get categoryGroupLifeHome => 'บ้านและชีวิตประจำวัน';

  @override
  String get categoryGroupTravelTransport => 'การเดินทางและพาหนะ';

  @override
  String get categoryGroupHealthWellness => 'สุขภาพร่างกายและจิตใจ';

  @override
  String get categoryGroupKids => 'ลูกและครอบครัว';

  @override
  String get categoryGroupPets => 'สัตว์เลี้ยง';

  @override
  String get categoryGroupWorkLearning => 'ทำงานและการเรียนรู้';

  @override
  String get categoryGroupFunSocial => 'บันเทิงและสังสรรค์';

  @override
  String get categoryGroupMoneyInOut => 'การเงินและหนี้สิน';

  @override
  String get categoryGroupCommunityServices => 'สังคมและบริการสาธารณะ';

  @override
  String get categoryGroupMisc => 'หมวดหมู่อื่นๆ';

  @override
  String get deleteBudgetCannotBeUndone => 'การลบจะไม่สามารถย้อนกลับได้';

  @override
  String get delete => 'ลบ';

  @override
  String get failedToDeleteBudget => 'ลบงบไม่สำเร็จ';

  @override
  String get owner => 'เจ้าของ';

  @override
  String get admin => 'แอดมิน';

  @override
  String get member => 'สมาชิก';

  @override
  String get pending => 'รอตอบรับ';

  @override
  String get accepted => 'เข้าร่วมแล้ว';

  @override
  String get revoked => 'ยกเลิกแล้ว';

  @override
  String get tapToChangeCover => 'แตะเพื่อเปลี่ยนหน้าปก';

  @override
  String get personalMessageHint => 'พูดอะไรสักหน่อยกับคนที่คุณเชิญ (เช่น \"มาจัดการงบด้วยกันเถอะ!\")';

  @override
  String get invitationExpiresIn => 'คำเชิญหมดอายุใน';

  @override
  String daysCount(int days) {
    return '$days วัน';
  }

  @override
  String get createHouseholdDescription => 'สร้างสเปซเพื่อติดตามงบและค่าใช้จ่ายร่วมกับครอบครัวหรือเพื่อน';

  @override
  String get uploadingImage => 'กำลังอัปโหลดรูปภาพ...';

  @override
  String get creating => 'กำลังสร้าง...';

  @override
  String get generatingInvite => 'กำลังสร้างลิงก์เชิญ...';

  @override
  String get pleaseSelectValidCurrency => 'โปรดเลือกสกุลเงินสำหรับสเปซ';

  @override
  String nameMaxLength(int max) {
    return 'ชื่อต้องยาวไม่เกิน $max ตัวอักษร';
  }

  @override
  String get createHouseholdPage => 'สร้างสเปซ';

  @override
  String get invitationPersonalMessageInput => 'ข้อความส่วนตัว (ไม่บังคับ)';

  @override
  String get householdNameInput => 'ชื่อสเปซ';

  @override
  String get invitationExpirationSelector => 'เวลาหมดอายุของคำเชิญ';

  @override
  String get unlimitedExpiration => 'ไม่มีวันหมดอายุ';

  @override
  String daysExpiration(int days) {
    return 'หมดอายุใน $days วัน';
  }

  @override
  String get householdInformation => 'ข้อมูลสเปซ';

  @override
  String get creatingHousehold => 'กำลังสร้างสเปซ...';

  @override
  String get createHouseholdButton => 'สร้างสเปซ';

  @override
  String get searchExpenses => 'ค้นหารายจ่าย...';

  @override
  String get clearAll => 'ล้างตัวกรอง';

  @override
  String get allCategories => 'ทุกหมวดหมู่';

  @override
  String get allMembers => 'สมาชิกทุกคน';

  @override
  String get balanceSummary => 'สรุปยอดคงค้าง';

  @override
  String get youAreOwed => 'คุณจะได้คืน';

  @override
  String get youOwe => 'คุณต้องจ่าย';

  @override
  String get youOweOthers => 'คุณต้องจ่ายคนอื่น';

  @override
  String get othersOweYou => 'คนอื่นต้องจ่ายคุณ';

  @override
  String get viewDetails => 'ดูรายละเอียด';

  @override
  String get settleUp => 'เคลียร์บิล';

  @override
  String get markExpensesAsSettled => 'กดเคลียร์บิลเพื่ออัปเดตยอดค้างชำระ';

  @override
  String get whoAreYouSettlingWith => 'คุณจะเคลียร์บิลกับใคร?';

  @override
  String get selectMember => 'เลือกสมาชิก';

  @override
  String get amountToSettle => 'ยอดที่ต้องเคลียร์';

  @override
  String get howDidYouSettle => 'คุณจ่ายด้วยวิธีไหน?';

  @override
  String get cash => 'เงินสด';

  @override
  String get paidInCash => 'จ่ายเป็นเงินสด';

  @override
  String get bankTransfer => 'โอนเงิน';

  @override
  String get transferredViaBank => 'โอนผ่านแอปธนาคาร';

  @override
  String get mobilePayment => 'แอปจ่ายเงิน/สแกนจ่าย';

  @override
  String get venmoPaypalEtc => 'พร้อมเพย์, TrueMoney, ฯลฯ';

  @override
  String get search => 'ค้นหา';

  @override
  String get noData => 'ไม่มีข้อมูล';

  @override
  String get filterTransactions => 'กรองรายการ';

  @override
  String get noTransactionsFound => 'ไม่พบรายการ';

  @override
  String get failedToLoadHouseholdTransactions => 'โหลดรายการของสเปซไม่สำเร็จ';

  @override
  String get reset => 'รีเซ็ต';

  @override
  String get apply => 'นำไปใช้';

  @override
  String get expenses => 'รายจ่าย';

  @override
  String get dateRange => 'ช่วงวันที่';

  @override
  String get noMatchingExpenses => 'ไม่พบรายจ่ายที่ตรงกับตัวกรอง';

  @override
  String get startLoggingExpenses => 'จดรายจ่ายแรกของคุณเพื่อให้แสดงข้อมูลที่นี่';

  @override
  String get tryAdjustingFilters => 'ลองปรับตัวกรองใหม่ดูสิ';

  @override
  String get split => 'หารบิล';

  @override
  String get note => 'โน้ต';

  @override
  String get currencyCannotBeChangedWhenSharing => 'เปลี่ยนสกุลเงินไม่ได้เมื่อแชร์กับสเปซ';

  @override
  String get createBudget => 'ตั้งงบ';

  @override
  String get pleaseEnterABudgetName => 'โปรดตั้งชื่องบ';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'โปรดระบุยอดเงินให้ถูกต้อง (มากกว่า 0)';

  @override
  String get warningThresholdMustBeBetween0And100 => 'ระดับแจ้งเตือนต้องอยู่ระหว่าง 0 ถึง 100%';

  @override
  String get alertThresholdMustBeBetween0And100 => 'ระดับเตือนวิกฤตต้องอยู่ระหว่าง 0 ถึง 100%';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'ระดับเตือนเบาๆ ต้องน้อยกว่าหรือเท่ากับระดับเตือนวิกฤต';

  @override
  String get budgetCreatedSuccessfully => 'สร้างงบสำเร็จแล้ว!';

  @override
  String get failedToCreateBudget => 'สร้างงบไม่สำเร็จ';

  @override
  String get groceriesRentEntertainment => 'เช่น ของใช้ ค่าเช่า หรือช้อปปิ้ง';

  @override
  String get budgetType => 'ประเภทงบ';

  @override
  String get sharedWithAllHouseholdMembers => 'แชร์กับสมาชิกทุกคนในสเปซ';

  @override
  String get personalBudgetForYourExpensesOnly => 'งบส่วนตัว (เห็นเฉพาะคุณ)';

  @override
  String get countSplitPortionOnly => 'คิดเฉพาะส่วนที่ฉันต้องจ่าย';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'นับยอดเข้าในงบนี้เฉพาะส่วนแบ่งที่คุณต้องจ่ายเท่านั้น';

  @override
  String get joinHousehold => 'เข้าร่วมสเปซ';

  @override
  String get joinAHousehold => 'เข้าร่วมสเปซ';

  @override
  String get enterYourInvitationLinkToJoin => 'ใส่ลิงก์คำเชิญเพื่อเข้าสเปซ\nและจัดการเงินร่วมกัน';

  @override
  String get pasteTheInvitationLinkYouReceived => 'วางลิงก์คำเชิญที่คุณได้รับมา';

  @override
  String get pasteInvitationLink => 'วางลิงก์คำเชิญ';

  @override
  String get pleaseEnterAnInvitationLink => 'โปรดวางลิงก์คำเชิญ';

  @override
  String get pleaseEnterAValidInvitationLink => 'ลิงก์คำเชิญไม่ถูกต้อง';

  @override
  String get paste => 'วาง';

  @override
  String get validating => 'กำลังตรวจสอบ...';

  @override
  String get continueAction => 'ต่อไป';

  @override
  String get welcomeAboard => 'ยินดีต้อนรับ!';

  @override
  String get youreNowPartOfTheHousehold => 'คุณได้เข้าร่วมสเปซนี้แล้ว\nมาเริ่มจัดการเงินด้วยกันเลย!';

  @override
  String get thisWillOnlyTakeAMoment => 'รอสักครู่นะ...';

  @override
  String get unableToJoin => 'เข้าร่วมไม่สำเร็จ';

  @override
  String get tryAgain => 'ลองอีกครั้ง';

  @override
  String get goToHousehold => 'ไปที่สเปซ';

  @override
  String get expiresSoon => 'ใกล้หมดอายุ';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'คำเชิญใช้ได้จนถึง $formattedDate';
  }

  @override
  String get whatYoullGet => 'สิ่งที่คุณทำได้';

  @override
  String get viewSharedBudgetsAndExpenses => 'ดูงบและรายจ่ายกองกลาง';

  @override
  String get trackHouseholdFinancialHealth => 'ติดตามสุขภาพการเงินของสเปซ';

  @override
  String get collaborateOnFinancialDecisions => 'ตัดสินใจเรื่องการเงินร่วมกัน';

  @override
  String get household => 'สเปซ';

  @override
  String get viewAll => 'ดูทั้งหมด';

  @override
  String get manage => 'จัดการ';

  @override
  String get noBudgetsYet => 'ยังไม่ได้ตั้งงบ';

  @override
  String get createSharedBudgetDescription => 'สร้างงบกองกลางเพื่อติดตามรายจ่ายร่วมกัน';

  @override
  String get errorLoadingBudgets => 'โหลดงบไม่สำเร็จ';

  @override
  String get recentSplits => 'รายการหารบิลล่าสุด';

  @override
  String get invite => 'เชิญ';

  @override
  String get last6Months => '6 เดือนที่ผ่านมา';

  @override
  String get thisYear => 'ปีนี้';

  @override
  String get allTime => 'ทั้งหมด';

  @override
  String nameMinLength(int min) {
    return 'ชื่อต้องมีอย่างน้อย $min ตัวอักษร';
  }

  @override
  String get splitExpense => 'หารบิล';

  @override
  String get percent => 'เปอร์เซ็นต์';

  @override
  String get splitShare => 'ส่วนแบ่ง';

  @override
  String get owes => 'ต้องจ่าย';

  @override
  String splitAmountsMustEqual(String currency, String amount, Object currencySymbol) {
    return 'ยอดที่หารต้องรวมกันได้ $currency$amount';
  }

  @override
  String get percentagesMustTotal100 => 'เปอร์เซ็นต์รวมกันต้องได้ 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'แต่ละคนต้องมีส่วนแบ่งอย่างน้อย 1 ส่วน';

  @override
  String get whatsappVerified => 'ยืนยัน WhatsApp แล้ว';

  @override
  String get whatsappVerification => 'ยืนยันเบอร์ WhatsApp';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'เชื่อมต่อเบอร์ WhatsApp ของคุณสำเร็จแล้ว';

  @override
  String get verifyingYourWhatsAppNumber => 'กำลังยืนยันเบอร์ WhatsApp ของคุณ...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'กรอกรหัส 6 หลักจาก WhatsApp';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'โปรดกรอกรหัสยืนยัน 6 หลัก';

  @override
  String get failedToVerifyCode => 'ยืนยันรหัสไม่สำเร็จ';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'ยืนยันรหัสไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get codeAutoFilledFromVerificationLink => 'กรอกรหัสอัตโนมัติจากลิงก์ยืนยันแล้ว';

  @override
  String get verify => 'ยืนยัน';

  @override
  String get verifying => 'กำลังยืนยัน...';

  @override
  String get avatarStudio => 'สร้างอวตาร';

  @override
  String get preview => 'พรีวิว';

  @override
  String get colors => 'สี';

  @override
  String get randomize => 'สุ่ม';

  @override
  String get saveAvatar => 'บันทึกอวตาร';

  @override
  String get saving => 'กำลังบันทึก...';

  @override
  String get skipForNow => 'ข้ามไปก่อน';

  @override
  String get selectColor => 'เลือกสี';

  @override
  String get failedToSaveAvatar => 'บันทึกอวตารไม่สำเร็จ';

  @override
  String get hair => 'ทรงผม';

  @override
  String get eyes => 'ดวงตา';

  @override
  String get mouth => 'ปาก';

  @override
  String get background => 'พื้นหลัง';

  @override
  String get face => 'ใบหน้า';

  @override
  String get ears => 'หู';

  @override
  String get shirts => 'เสื้อ';

  @override
  String get brow => 'คิ้ว';

  @override
  String get nose => 'จมูก';

  @override
  String get blush => 'แก้ม';

  @override
  String get accessories => 'เครื่องประดับ';

  @override
  String get stars => 'ดาว';

  @override
  String get recurring => 'รายการประจำ';

  @override
  String get manageYourRecurringTransactions => 'จัดการบิลและรายการที่เกิดซ้ำทุกเดือน';

  @override
  String get errorLoadingData => 'โหลดข้อมูลไม่สำเร็จ';

  @override
  String get deleteRecurringTransaction => 'ลบรายการประจำ';

  @override
  String get areYouSureYouWantToDeleteThisRecurringTransaction => 'คุณแน่ใจหรือไม่ว่าต้องการลบรายการประจำนี้?';

  @override
  String get recurringTransactionDeleted => 'ลบรายการประจำแล้ว';

  @override
  String get transactionDeleted => 'ลบรายการแล้ว';

  @override
  String get recentTransactions => 'รายการล่าสุด';

  @override
  String get failedToDeleteRecurringTransaction => 'ลบรายการประจำไม่สำเร็จ';

  @override
  String get deleteEntireSeries => 'ลบรายการประจำนี้ทั้งหมด';

  @override
  String get skipNextOccurrence => 'ข้ามรอบนี้';

  @override
  String get deleteRecurringChoiceDescription => 'คุณต้องการข้ามแค่รอบนี้ หรือลบรายการประจำนี้ทิ้งทั้งหมด?';

  @override
  String get occurrenceSkipped => 'ข้ามรอบนี้แล้ว';

  @override
  String get currencyIsManagedByHousehold => 'สกุลเงินถูกจัดการโดยสเปซ เปลี่ยนไม่ได้นะ';

  @override
  String get buyALaptop => 'ซื้อแล็ปท็อปราคา 35,000 บาท';

  @override
  String get selectTargetDate => 'เลือกวันที่';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'ฉันสามารถ $action ก่อน $date ได้ไหม?';
  }

  @override
  String get scenarioDateFormat => 'dd/MM/yyyy';

  @override
  String analysisFailed(String error) {
    return 'วิเคราะห์ไม่สำเร็จ: $error';
  }

  @override
  String get leftHandChamps => 'หมวดซ้ายสุดคือตัวดูดเงินหลัก ลองเช็คดูหน่อยไหม';

  @override
  String get smallButFrequent => 'ยอดน้อยแต่จ่ายบ่อย ระวังเงินปลิวแบบไม่รู้ตัวนะ';

  @override
  String get colorMatches => 'สีตรงกับในหน้าแรกเลย จะได้จำง่ายๆ';

  @override
  String get planningNewGoal => 'กำลังตั้งเป้าใหม่? ลองหาหมวดที่พอลดได้โดยไม่ลำบากเกินไปดูสิ';

  @override
  String get eyeingTreatYourself => 'เล็งของชิ้นใหญ่ไว้? ลองดูว่าตรงไหนลดได้บ้างเพื่อให้ได้ของไวขึ้น';

  @override
  String get doubleCheckTagging => 'เช็คให้ชัวร์ว่าจัดหมวดหมู่ถูก อย่าให้มีรายการลึกลับโผล่มา';

  @override
  String get slideHighBar => 'ลองลดกราฟแท่งสูงๆ ลงนิด ด้วยการตั้งลิมิตหรือหาของที่ถูกกว่ามาแทน';

  @override
  String get nonNegotiable => 'ถ้ายอดไหนลดไม่ได้ (เช่น ค่าเช่า) ก็ปรับตัวอื่นเพื่อชดเชยแทน';

  @override
  String get revisitAfterScenario => 'กลับมาเช็คอีกทีหลังจำลองสถานการณ์ เพื่อดูว่าแผนใหม่รอดไหม';

  @override
  String get purpleLineCushion => 'เส้นสีม่วง: เงินเหลือๆ ในแต่ละวัน ถ้าเส้นชี้ขึ้นแปลว่ามาถูกทางแล้ว';

  @override
  String get blueBarsBudget => 'แท่งสีฟ้า: งบที่ตั้งไว้สำหรับวันนั้น';

  @override
  String get redBarsSpent => 'แท่งสีแดง: ยอดที่จ่ายไปจริงๆ';

  @override
  String get lineTrendingUpward => 'เส้นชี้ขึ้น = มีเงินเหลือไปโปะเป้าหมายเก็บเงินได้';

  @override
  String get flatDippingLine => 'เส้นราบหรือดิ่งลง = ได้เวลาเบรกและทบทวนการใช้เงินก้อนใหญ่';

  @override
  String get sharpDrops => 'กราฟดิ่งฮวบมักมาจากรายจ่ายที่ไม่ได้แพลนไว้ ลองแตะดูรายละเอียดสิ';

  @override
  String get lineRisingDays => 'กราฟขึ้นติดกันหลายวัน? ลองแบ่งเงินที่เหลือไปออมหรือโปะหนี้ดูสิ';

  @override
  String get lineDippingWeekend => 'กราฟร่วงหลังปาร์ตี้วันหยุด? ลองลดของจุกจิกในวันถัดๆ ไปเพื่อดึงยอดกลับมา';

  @override
  String get feelStuckRed => 'ทะลุงบตลอด? ลองกลับไปปรับงบในหน้าแรกดูนิดนึงก็เห็นผลแล้ว';

  @override
  String get thirtyDayForecastDesc => 'คาดการณ์จากพฤติกรรมเดือนที่แล้ว เพื่อเดาว่าเดือนหน้าจะใช้เงินประมาณเท่าไหร่ เหมือนพยากรณ์อากาศให้กระเป๋าตังค์';

  @override
  String get greenLineExpected => 'เส้นสีเขียว = รายจ่ายคาดการณ์ ถ้าคุณใช้ชีวิตเหมือนเดือนก่อนเป๊ะ';

  @override
  String get spikesHighlight => 'กราฟพุ่งปรี๊ดบอกให้รู้ว่าสัปดาห์ไหนจะจ่ายหนัก (เช่น ปาร์ตี้วันศุกร์)';

  @override
  String get forecastUpdates => 'ทุกครั้งที่จดรายจ่าย กราฟจะอัปเดตอัตโนมัติ ไม่ต้องกดรีเฟรช';

  @override
  String get spotExpensivePatterns => 'จับทางรายจ่ายก้อนใหญ่ให้ทัน แล้วกันเงินเตรียมไว้ก่อน';

  @override
  String get catchQuieterWeeks => 'เล็งสัปดาห์ที่ใช้เงินน้อยๆ เพื่อเอาเงินไปโปะหนี้หรือเก็บเพิ่ม';

  @override
  String get timeRecurringPayments => 'ใช้กราฟช่วยดูจังหวะจ่ายบิลหรือตัดค่าสมาชิกให้เนียนที่สุด';

  @override
  String get bigSpikeComing => 'เห็นยอดพุ่งมาแต่ไกล? ลองโยกรายจ่ายอื่นไปไว้วันที่เบากว่าแทน';

  @override
  String get forecastDipping => 'กราฟลงสวยๆ? ให้รางวัลตัวเองด้วยการเก็บเงินเพิ่มอีกนิดสิ';

  @override
  String get forecastLooksOff => 'ถ้ากราฟดูเพี้ยนๆ ลองเช็คหมวดหมู่ในหน้าแรกว่าลงผิดหรือเปล่า';

  @override
  String get greenLineTrends => 'เส้นสีเขียวบอกอัตราออมเงิน ถ้าชี้ขึ้นแปลว่าใกล้ถึงเป้าหมายแล้ว';

  @override
  String get lineDipsSignals => 'ถ้าเส้นทิ่มลง แปลว่าอีกไม่กี่เดือนรายจ่ายอาจแซงรายรับ';

  @override
  String get largeGoalsDebts => 'เป้าหมายใหญ่หรือหนี้ก้อนโตจะรวมอยู่ด้วย (ถ้าติดแท็กไว้)';

  @override
  String get upwardSlope => 'กราฟพุ่งขึ้นเหรอ? ฉลองได้เลย! ลองหักเงินไปลงทุนหรือจัดทริปเที่ยวดูไหม';

  @override
  String get flatSlipping => 'เส้นดิ่งลง? ถึงเวลาปรับงบหรือหาทางเพิ่มรายรับแล้วล่ะ';

  @override
  String get watchSeasonalTrends => 'ระวังรายจ่ายตามเทศกาล เปิดเทอม หรือบิลรายปี มันมักจะโผล่มาในนี้ก่อนเพื่อน';

  @override
  String get schedulePaymentIncreases => 'วางแผนโปะหนี้เพิ่มเบาๆ ช่วงที่กราฟกำลังชี้ขึ้น';

  @override
  String get planAheadDips => 'เตรียมรับมือช่วงกราฟตก ด้วยการกันเงินสำรองหรือลดของฟุ่มเฟือย';

  @override
  String get checkProjectionMonthly => 'เข้ามาเช็คกราฟเดือนละครั้ง เพื่อปรับแผนระยะยาวให้เป๊ะและยืดหยุ่น';

  @override
  String get categoryHealthcare => 'สุขภาพและการแพทย์';

  @override
  String get categoryOther => 'อื่นๆ';

  @override
  String get deleteExpense => 'ลบรายจ่าย';

  @override
  String get confirmDeleteExpense => 'คุณแน่ใจหรือไม่ว่าต้องการลบรายจ่ายนี้? ลบแล้วกู้คืนไม่ได้นะ';

  @override
  String get expenseDeletedSuccessfully => 'ลบรายจ่ายสำเร็จ';

  @override
  String get failedToDeleteExpense => 'ลบรายจ่ายไม่สำเร็จ';

  @override
  String get expenseNotFoundOrDeleted => 'ไม่พบรายจ่าย หรือรายจ่ายถูกลบไปแล้ว';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'เฉพาะแอดมินและเจ้าของเท่านั้นที่แก้การตั้งค่าสเปซได้';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'เฉพาะแอดมินและเจ้าของเท่านั้นที่สร้างคำเชิญได้';

  @override
  String shareInvitationForHousehold(String groupName) {
    return 'แชร์คำเชิญเข้าสเปซ $groupName';
  }

  @override
  String get shareInvitation => 'แชร์คำเชิญ';

  @override
  String householdCreatedSuccessfully(String groupName) {
    return 'สร้างสเปซ $groupName สำเร็จแล้ว';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String groupName) {
    return 'สร้างสเปซ \"$groupName\" สำเร็จแล้ว!';
  }

  @override
  String get invitationLink => 'ลิงก์คำเชิญ';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'ลิงก์คำเชิญ: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'คัดลอกลิงก์คำเชิญ';

  @override
  String get copyInvitationLinkToClipboard => 'คัดลอกลิงก์แล้ว';

  @override
  String get shareInvitationLink => 'แชร์ลิงก์คำเชิญ';

  @override
  String get share => 'แชร์';

  @override
  String get closeShareSheet => 'ปิดหน้าต่างแชร์';

  @override
  String get invitationLinkCopiedToClipboard => 'คัดลอกลิงก์คำเชิญแล้ว!';

  @override
  String joinMyHouseholdMessage(String groupName, String inviteUrl) {
    return 'มาเข้าสเปซ \"$groupName\" แล้วจัดการงบด้วยกันใน Moneko เถอะ!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'เข้าสเปซของฉันบน Moneko';

  @override
  String get zeroAmount => '0.00';

  @override
  String get dollarPrefix => '฿ ';

  @override
  String get notificationSettings => 'ตั้งค่าการแจ้งเตือน';

  @override
  String get budgetBoop => 'เตือนเบาๆ';

  @override
  String get getGentleReminder => 'รับการแจ้งเตือนเบาๆ เมื่อใช้งบถึงจุดนี้';

  @override
  String get purrSuasiveNudge => 'เตือนแบบจริงจัง';

  @override
  String get getStrongerNudge => 'รับการเตือนแบบจริงจังเมื่อใช้งบถึงจุดนี้';

  @override
  String get createBudgetButton => 'สร้างงบ';

  @override
  String get daily => 'รายวัน';

  @override
  String get weekly => 'รายสัปดาห์';

  @override
  String get monthly => 'รายเดือน';

  @override
  String get yearly => 'รายปี';

  @override
  String get biweekly => 'ทุก 2 สัปดาห์';

  @override
  String get oneTime => 'ครั้งเดียว';

  @override
  String percentageOfSpending(String percentage) {
    return '$percentage% ของรายจ่าย';
  }

  @override
  String get totalAmount => 'ยอดรวม';

  @override
  String get payer => 'คนจ่าย';

  @override
  String get whoPaid => 'ใครเป็นคนออก?';

  @override
  String get dollarSign => '฿';

  @override
  String get custom => 'กำหนดเอง';

  @override
  String everyXDays(int count) {
    return 'ทุกๆ $count วัน';
  }

  @override
  String everyXWeeks(int count) {
    return 'ทุกๆ $count สัปดาห์';
  }

  @override
  String get every2Weeks => 'ทุกๆ 2 สัปดาห์';

  @override
  String everyXMonths(int count) {
    return 'ทุกๆ $count เดือน';
  }

  @override
  String everyXYears(int count) {
    return 'ทุกๆ $count ปี';
  }

  @override
  String get householdBudgetType => 'งบสเปซ';

  @override
  String get personalBudgetType => 'งบส่วนตัว';

  @override
  String joinHouseholdName(String householdName) {
    return 'เข้าร่วม \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return '$householdName • เชิญโดย $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'เชิญโดย $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'คำเชิญจะหมดอายุในอีก $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'คำเชิญใช้ได้จนถึง';

  @override
  String get personalMessageFromInviter => 'ข้อความส่วนตัวจากผู้เชิญ';

  @override
  String get messageFromInviter => 'ข้อความจากผู้เชิญ';

  @override
  String get joiningHousehold => 'กำลังเข้าร่วมสเปซ...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'ข้อผิดพลาด: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'เกิดข้อผิดพลาดที่ไม่คาดคิด';

  @override
  String get invalidInvitationLinkFormat => 'รูปแบบลิงก์คำเชิญไม่ถูกต้อง';

  @override
  String get invalidOrExpiredInvitation => 'คำเชิญไม่ถูกต้องหรือหมดอายุแล้ว';

  @override
  String get tomorrow => 'พรุ่งนี้';

  @override
  String inDays(int days) {
    return 'ในอีก $days วัน';
  }

  @override
  String get january => 'ม.ค.';

  @override
  String get february => 'ก.พ.';

  @override
  String get march => 'มี.ค.';

  @override
  String get april => 'เม.ย.';

  @override
  String get may => 'พ.ค.';

  @override
  String get june => 'มิ.ย.';

  @override
  String get july => 'ก.ค.';

  @override
  String get august => 'ส.ค.';

  @override
  String get september => 'ก.ย.';

  @override
  String get october => 'ต.ค.';

  @override
  String get november => 'พ.ย.';

  @override
  String get december => 'ธ.ค.';

  @override
  String remindUser(String name) {
    return 'เตือน $name';
  }

  @override
  String get sendFriendlySpendingReminder => 'ส่งข้อความสะกิดเตือนการใช้เงิน';

  @override
  String get addMessageOptional => 'เพิ่มข้อความ (ไม่บังคับ)';

  @override
  String get messageHintExample => 'เช่น \"กระเป๋าตังค์ร้องไห้แล้ว พักก่อน!\"';

  @override
  String get sendReminder => 'ส่งการเตือน';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'รอ 24 ชั่วโมงก่อนส่งข้อความเตือนให้ $name อีกครั้งนะ';
  }

  @override
  String reminderSentToName(String name) {
    return 'ส่งข้อความเตือนให้ $name แล้ว! 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'ส่งข้อความเตือนไม่สำเร็จ ลองใหม่อีกครั้ง';

  @override
  String get income => 'รายรับ';

  @override
  String get addIncome => 'เพิ่มรายรับ';

  @override
  String get incomeAdded => 'เพิ่มรายรับสำเร็จ';

  @override
  String get incomeSaved => 'บันทึกรายรับแล้ว';

  @override
  String get incomeSavedAndShared => 'บันทึกและแชร์รายรับแล้ว';

  @override
  String get noIncome => 'ยังไม่มีรายรับ';

  @override
  String get noIncomeDescription => 'บันทึกรายรับของคุณเพื่อเช็คสุขภาพการเงินของสเปซ';

  @override
  String get totalIncome => 'รวมรายรับ';

  @override
  String get monthToDate => 'ยอดเดือนนี้';

  @override
  String get yearToDate => 'ยอดปีนี้';

  @override
  String get failedToLoadIncome => 'โหลดข้อมูลรายรับไม่สำเร็จ';

  @override
  String get incomeAcknowledged => 'รับทราบแล้ว';

  @override
  String get acknowledge => 'รับทราบ';

  @override
  String get acknowledged => 'รับทราบแล้ว';

  @override
  String get source => 'แหล่งที่มา';

  @override
  String get sourceHint => 'เช่น ชื่อบริษัท, ลูกค้า';

  @override
  String get me => 'ฉัน';

  @override
  String get partner => 'แฟน/พาร์ทเนอร์';

  @override
  String get privacyScope => 'ความเป็นส่วนตัว';

  @override
  String get privacyFull => 'รายละเอียดทั้งหมด';

  @override
  String get privacyBalancesOnly => 'ดูแค่ยอดรวม';

  @override
  String get privacyPrivate => 'ส่วนตัว';

  @override
  String get privacyFullExplanation => 'พาร์ทเนอร์จะเห็นยอดทั้งหมด แหล่งที่มา และโน้ตที่คุณพิมพ์ไว้';

  @override
  String get privacyBalancesOnlyExplanation => 'พาร์ทเนอร์จะเห็นแค่ยอดรวมเท่านั้น ไม่เห็นว่ามาจากไหนหรือโน้ตอะไร';

  @override
  String get privacyPrivateExplanation => 'คุณเห็นคนเดียว ยอดจะถูกบวกในกองกลาง แต่พาร์ทเนอร์จะไม่เห็นเลย';

  @override
  String get incomeSalary => 'เงินเดือน';

  @override
  String get incomeFreelance => 'ฟรีแลนซ์';

  @override
  String get incomeInvestment => 'การลงทุน';

  @override
  String get incomeRefund => 'เงินคืน';

  @override
  String get incomeGift => 'ของขวัญ';

  @override
  String get incomeBonus => 'โบนัส';

  @override
  String get incomeRental => 'ค่าเช่า';

  @override
  String get incomeOther => 'อื่นๆ';

  @override
  String get days => 'วัน';

  @override
  String get hours => 'ชั่วโมง';

  @override
  String get goals => 'เป้าหมาย';

  @override
  String get createGoal => 'สร้างเป้าหมาย';

  @override
  String get goalCreated => 'สร้างเป้าหมายสำเร็จ';

  @override
  String get goalTitle => 'ชื่อเป้าหมาย';

  @override
  String get enterGoalTitle => 'ระบุชื่อเป้าหมาย';

  @override
  String get pleaseEnterTitle => 'โปรดระบุชื่อ';

  @override
  String get pleaseEnterAmount => 'โปรดยอดเงิน';

  @override
  String get invalidAmount => 'โปรดระบุยอดเงินให้ถูกต้อง (มากกว่า 0)';

  @override
  String get targetAmount => 'ยอดเป้าหมาย';

  @override
  String get currentAmount => 'ยอดปัจจุบัน';

  @override
  String get targetDate => 'เป้าหมายวันที่';

  @override
  String get description => 'รายละเอียด';

  @override
  String get descriptionHint => 'โน้ตเพิ่มเติม (ไม่บังคับ)';

  @override
  String get savings => 'เก็บเงิน';

  @override
  String get paydown => 'โปะหนี้';

  @override
  String get all => 'ทั้งหมด';

  @override
  String get completed => 'สำเร็จแล้ว';

  @override
  String get offTrack => 'ช้ากว่าเป้า';

  @override
  String get onTrack => 'ตามเป้า';

  @override
  String get complete => 'เสร็จสิ้น';

  @override
  String get overallProgress => 'ความคืบหน้าโดยรวม';

  @override
  String get totalGoals => 'เป้าหมายทั้งหมด';

  @override
  String get noGoals => 'ยังไม่มีเป้าหมาย ลองสร้างเป้าหมายแรกดูสิ!';

  @override
  String get noSavingsGoals => 'ยังไม่มีเป้าหมายเก็บเงิน ลองสร้างสักอันดูสิ!';

  @override
  String get noPaydownGoals => 'ยังไม่มีเป้าหมายโปะหนี้ ลองสร้างสักอันดูสิ!';

  @override
  String get goalAcknowledged => 'รับทราบเป้าหมายแล้ว';

  @override
  String get balancesOnly => 'ดูแค่ยอดรวม';

  @override
  String get contribution => 'ยอดสมทบ';

  @override
  String get withdrawal => 'ถอนเงิน';

  @override
  String get interest => 'ดอกเบี้ย';

  @override
  String get adjustment => 'ปรับยอด';

  @override
  String get addContribution => 'เพิ่มยอดสมทบ';

  @override
  String get contributionAmount => 'ยอดสมทบ';

  @override
  String get contributionType => 'ประเภท';

  @override
  String get contributionAdded => 'เพิ่มยอดสมทบสำเร็จ';

  @override
  String get pleaseSelectCategory => 'โปรดเลือกหมวดหมู่';

  @override
  String get userNotAuthenticated => 'ผู้ใช้ยังไม่ได้ยืนยันตัวตน';

  @override
  String get recurringExpenseUpdatedSuccessfully => 'อัปเดตรายจ่ายประจำสำเร็จ';

  @override
  String get recurringExpenseAddedSuccessfully => 'เพิ่มรายจ่ายประจำสำเร็จ';

  @override
  String get recurringIncomeUpdatedSuccessfully => 'อัปเดตรายรับประจำสำเร็จ';

  @override
  String get recurringIncomeAddedSuccessfully => 'เพิ่มรายรับประจำสำเร็จ';

  @override
  String get failedToUpdateRecurringExpense => 'อัปเดตรายจ่ายประจำไม่สำเร็จ';

  @override
  String get failedToAddRecurringExpense => 'เพิ่มรายจ่ายประจำไม่สำเร็จ';

  @override
  String get failedToUpdateRecurringIncome => 'อัปเดตรายรับประจำไม่สำเร็จ';

  @override
  String get failedToAddRecurringIncome => 'เพิ่มรายรับประจำไม่สำเร็จ';

  @override
  String get editRecurringExpense => 'แก้ไขรายจ่ายประจำ';

  @override
  String get editRecurringIncome => 'แก้ไขรายรับประจำ';

  @override
  String get addRecurringExpense => 'เพิ่มรายจ่ายประจำ';

  @override
  String get addRecurringIncome => 'เพิ่มรายรับประจำ';

  @override
  String get selectCategory => 'เลือกหมวดหมู่';

  @override
  String get frequency => 'ความถี่';

  @override
  String get startDate => 'วันเริ่ม';

  @override
  String get setEndDate => 'กำหนดวันจบ';

  @override
  String get endDate => 'วันจบ';

  @override
  String get selectEndDate => 'เลือกวันจบ';

  @override
  String get descriptionOptional => 'รายละเอียด (ไม่บังคับ)';

  @override
  String get sourceOptional => 'ที่มา (ไม่บังคับ)';

  @override
  String get companyNameClientNameExample => 'เช่น ชื่อบริษัท, ลูกค้า';

  @override
  String get setReminder => 'ตั้งเตือน';

  @override
  String get updateRecurringTransaction => 'อัปเดตรายการประจำ';

  @override
  String get addRecurringTransaction => 'เพิ่มรายการประจำ';

  @override
  String youWillBeNotifiedBeforeEachOccurrence(int value, String unit) {
    return 'จะมีการแจ้งเตือนล่วงหน้า $value $unit';
  }

  @override
  String get addReminder => 'เพิ่มการตั้งเตือน';

  @override
  String get ended => 'จบแล้ว';

  @override
  String get noRecurringExpenses => 'ไม่มีรายจ่ายประจำ';

  @override
  String get noRecurringIncome => 'ไม่มีรายรับประจำ';

  @override
  String get setupAutomaticExpenseTracking => 'ตั้งระบบจดอัตโนมัติสำหรับค่ารายเดือน บิลต่างๆ หรือรายจ่ายประจำ';

  @override
  String get setupAutomaticIncomeTracking => 'ตั้งระบบจดอัตโนมัติสำหรับเงินเดือน ฟรีแลนซ์ และรายได้ประจำ';

  @override
  String get confirmIncome => 'ยืนยันรายรับ';

  @override
  String get saveIncome => 'บันทึกรายรับ';

  @override
  String get addReceiptPhoto => 'เพิ่มรูปใบเสร็จ';

  @override
  String get tapToTakePhoto => 'แตะเพื่อถ่ายรูปใบเสร็จของคุณ';

  @override
  String get atLeastOneMember => 'ต้องรวมสมาชิกอย่างน้อย 1 คน';

  @override
  String get memberMustHaveShare => 'สมาชิกอย่างน้อย 1 คนต้องมีส่วนแบ่งมากกว่า 0';

  @override
  String get monthOverMonthSpending => 'เทียบรายจ่ายกับเดือนก่อน';

  @override
  String get last3Months => '3 เดือนที่ผ่านมา';

  @override
  String get breakdown => 'สัดส่วน';

  @override
  String get noOutstandingItems => 'ไม่มียอดค้าง';

  @override
  String get theyOweYou => 'เขาต้องจ่ายคุณ';

  @override
  String get expressNetting => 'เคลียร์ยอดรวบตึง';

  @override
  String get detailedSettlement => 'เคลียร์ทีละรายการ';

  @override
  String get expressNettingHint => 'กดยืนยันเพื่อเคลียร์ยอดค้างทั้งหมดที่มีกับคนนี้แบบรวดเดียว';

  @override
  String get settle => 'เคลียร์บิล';

  @override
  String get confirmSettlement => 'ยืนยันเคลียร์บิล';

  @override
  String get confirmSettlementMessage => 'การกดเคลียร์ถือเป็นการล้างยอดค้างทั้งหมดกับคนนี้';

  @override
  String get pleaseSelectMember => 'โปรดเลือกสมาชิก';

  @override
  String get settlementCompleted => 'เคลียร์บิลสำเร็จแล้ว';

  @override
  String get nothingToSettle => 'ไม่มีอะไรต้องเคลียร์';

  @override
  String get expense => 'รายจ่าย';

  @override
  String get settlement => 'ประวัติเคลียร์บิล';

  @override
  String get suggestedNetTransfers => 'แนะนำวิธีโอนรวบตึง';

  @override
  String get detailedPairwiseDues => 'รายละเอียดค้างจ่ายแต่ละคน';

  @override
  String get outstanding => 'ยอดค้าง';

  @override
  String get youAreOwedBy => 'จะได้เงินจาก';

  @override
  String get noOutstandingAmounts => 'ไม่มียอดค้าง';

  @override
  String get groupFairnessTitle => 'สมดุลการจ่าย';

  @override
  String get groupFairness => 'สมดุลของสเปซ';

  @override
  String get groupFairnessExplanation => 'แสดงสัดส่วนการออกเงินว่าแฟร์แค่ไหน ถ้า 100% คือทุกคนออกพอๆ กัน';

  @override
  String get noMemberDataYet => 'ยังไม่มีข้อมูลสมาชิก';

  @override
  String evenShare(String amount) {
    return 'หารเท่ากัน: $amount';
  }

  @override
  String get viewHousehold => 'ดูสเปซ';

  @override
  String get invalidInvitationMissingInfo => 'คำเชิญไม่ถูกต้อง: ไม่มีข้อมูลสเปซ';

  @override
  String joinedHouseholdWithName(String name) {
    return 'เข้าสเปซ $name แล้ว!';
  }

  @override
  String get joinedHousehold => 'เข้าสเปซแล้ว!';

  @override
  String get errorLoadingSplits => 'โหลดรายการหารบิลไม่สำเร็จ';

  @override
  String get markAsSettled => 'กดว่าจ่ายแล้ว';

  @override
  String get splitDetails => 'รายละเอียดการหารบิล';

  @override
  String get equalSplit => 'หารเท่ากัน';

  @override
  String get noSharedBudgetsYet => 'ยังไม่มีงบกองกลาง';

  @override
  String get whoCanSeeThisExpense => 'ใครเห็นรายจ่ายนี้ได้บ้าง?';

  @override
  String get onlyVisibleToYou => 'เฉพาะคุณ';

  @override
  String get chooseSpecificMembers => 'เลือกเฉพาะบางคน';

  @override
  String get selectMembers => 'เลือกสมาชิก';

  @override
  String get noMembersFound => 'ไม่พบสมาชิก';

  @override
  String membersSelectedCount(int count) {
    return 'เลือกไว้ $count คน';
  }

  @override
  String get noSplitsYet => 'ยังไม่มีรายการหารบิล';

  @override
  String get startSplittingExpensesWithYourHousehold => 'เริ่มหารบิลกับคนในสเปซของคุณ';

  @override
  String minutesAgoShort(int count) {
    return '$count นาทีที่แล้ว';
  }

  @override
  String hoursAgoShort(int count) {
    return '$count ชม. ที่แล้ว';
  }

  @override
  String daysAgoShort(int count) {
    return '$count วันที่แล้ว';
  }

  @override
  String weeksAgoShort(int count) {
    return '$count สัปดาห์ที่แล้ว';
  }

  @override
  String get errorLoadingActivity => 'โหลดความเคลื่อนไหวไม่สำเร็จ';

  @override
  String get noRecentActivity => 'ไม่มีความเคลื่อนไหวล่าสุด';

  @override
  String get viewAllExpenses => 'ดูรายจ่ายทั้งหมด';

  @override
  String get noPendingSplits => 'ไม่มีบิลรอหาร';

  @override
  String get pendingSettlement => 'รอเคลียร์บิล';

  @override
  String get youreIn => 'เข้ามาแล้ว! 🎉';

  @override
  String get invitationError => 'ลิงก์คำเชิญมีปัญหา';

  @override
  String get processingInvitation => 'กำลังตรวจสอบคำเชิญ...';

  @override
  String get noHouseholdsAvailableCreateOrJoin => 'ยังไม่มีสเปซ ลองสร้างหรือเข้าร่วมดูก่อนนะ';

  @override
  String get selectHousehold => 'เลือกสเปซ';

  @override
  String get yourPockets => 'พ็อกเก็ตของคุณ';

  @override
  String get editPocket => 'แก้ไขพ็อกเก็ต';

  @override
  String get addPocket => 'เพิ่มพ็อกเก็ต';

  @override
  String get pockets => 'พ็อกเก็ต (ซองเงิน)';

  @override
  String get pocketNameLabel => 'ชื่อพ็อกเก็ต';

  @override
  String get pocketNamePlaceholder => 'ชื่อพ็อกเก็ต';

  @override
  String get thisPocketFallback => 'พ็อกเก็ตนี้';

  @override
  String get pleaseEnterPocketName => 'โปรดตั้งชื่อพ็อกเก็ต';

  @override
  String get pleaseEnterPocketPercentage => 'โปรดระบุเปอร์เซ็นต์';

  @override
  String get pleaseEnterValidPocketPercentage => 'โปรดระบุเปอร์เซ็นต์ (0-100)';

  @override
  String get pleaseSelectHouseholdFirst => 'โปรดเลือกสเปซก่อน';

  @override
  String get pleaseSetMonthlyBudgetFirst => 'โปรดตั้งงบรายเดือนก่อน';

  @override
  String get pocketAllocationLabel => 'แบ่งงบมา';

  @override
  String get pocketCategoriesLabel => 'หมวดหมู่';

  @override
  String get tapToSelectCategories => 'แตะเพื่อเลือกหมวดหมู่';

  @override
  String get pocketColorLabel => 'สี';

  @override
  String get pocketIconLabel => 'ไอคอน';

  @override
  String get budgetExceededByLabel => 'เกินงบมาแล้ว';

  @override
  String get pocketDeleteTitle => 'ลบพ็อกเก็ต?';

  @override
  String get pocketDeleteMessage => 'ลบพ็อกเก็ตนี้รวมถึงหมวดหมู่ที่ผูกไว้ แต่รายจ่ายจะยังอยู่ครบนะ';

  @override
  String get pocketDeleted => 'ลบพ็อกเก็ตแล้ว';

  @override
  String get failedToDeletePocket => 'ลบพ็อกเก็ตไม่สำเร็จ';

  @override
  String get budgetImpactTitle => 'ผลกระทบต่องบ';

  @override
  String get budgetBalanced => 'ลงตัว';

  @override
  String get remainingLabel => 'คงเหลือ';

  @override
  String get pocketSegmentLabel => 'พ็อกเก็ต';

  @override
  String get thisPocketSegmentLabel => 'พ็อกเก็ตนี้';

  @override
  String get pocketNotFoundAppBar => 'ไม่พบพ็อกเก็ต';

  @override
  String get pocketNotFoundTitle => 'ไม่พบพ็อกเก็ต';

  @override
  String get pocketNotFoundMessage => 'พ็อกเก็ตนี้อาจถูกลบไปแล้ว';

  @override
  String get goBack => 'กลับ';

  @override
  String get monthlyBudgetLabel => 'งบรายเดือน';

  @override
  String get keyInsightsTitle => 'ข้อมูลสำคัญ';

  @override
  String get spentThisMonthLabel => 'จ่ายไปเดือนนี้';

  @override
  String get avgDailySpendLabel => 'เฉลี่ยต่อวัน';

  @override
  String get pocketAllowanceLabel => 'งบที่ใช้ได้';

  @override
  String get dailyTrendTitle => 'เทรนด์รายวัน';

  @override
  String get past30DaysLabel => '30 วันที่ผ่านมา';

  @override
  String get noTransactionsYet => 'ยังไม่มีรายการ';

  @override
  String get unallocatedSpendLabel => 'รายจ่ายที่ไม่ได้เข้าพ็อกเก็ต';

  @override
  String get unallocatedBannerDescription => 'มีบางรายการที่ยังไม่ได้จับใส่พ็อกเก็ตไหนเลย';

  @override
  String get uncategorizedSpendingTitle => 'รายจ่ายนอกพ็อกเก็ต';

  @override
  String get uncategorizedSpendingDescription => 'หมวดหมู่พวกนี้ยังไม่ผูกกับพ็อกเก็ตไหนเลย ลองจับคู่ดูจะได้ตามงบได้ง่ายๆ';

  @override
  String get noDetailedExpensesFound => 'ไม่มีรายละเอียดรายจ่ายในหมวดนี้';

  @override
  String get setMonthlyBudgetTitle => 'ตั้งงบรายเดือน';

  @override
  String get newPocketTitle => 'พ็อกเก็ตใหม่';

  @override
  String get ofSpendingLabel => 'ของรายจ่าย';

  @override
  String get viewOptionsTitle => 'มุมมอง';

  @override
  String get envelopeModeTitle => 'โหมดแบ่งซองเงิน';

  @override
  String get envelopeModeDescription => 'แบ่งงบรายเดือนออกเป็นซองๆ (พ็อกเก็ต)';

  @override
  String get howItWorksTitle => 'มันทำงานยังไง?';

  @override
  String get allocateYourIncomeTitle => 'แบ่งเงินของคุณ';

  @override
  String get allocateYourIncomeDescription => 'แบ่งงบรายเดือนเป็นซองๆ (พ็อกเก็ต)';

  @override
  String get trackSpendingTitle => 'ตามติดรายจ่าย';

  @override
  String get trackSpendingDescription => 'เช็คได้เลยว่าพ็อกเก็ตไหนเหลือเงินเท่าไหร่';

  @override
  String get avoidOverspendingTitle => 'กันงบบานปลาย';

  @override
  String get avoidOverspendingDescription => 'เตือนทันทีเมื่อเงินในพ็อกเก็ตใกล้หมดหรือทะลุงบ';

  @override
  String get youveGotPaychecksIncomingAndBillsToPay => 'คุณมีรายรับและบิลที่รอจ่ายอยู่';

  @override
  String get notifyMeDaysBefore => 'เตือนล่วงหน้า 3 วัน';

  @override
  String get upcomingPaychecks => 'รายรับที่กำลังจะเข้า';

  @override
  String get paycheckFromWork => 'เงินเดือนเข้า';

  @override
  String get freelanceProject => 'ค่าจ้างฟรีแลนซ์';

  @override
  String get upcomingBills => 'บิลที่ใกล้ดิว';

  @override
  String get rentPayment => 'ค่าเช่า';

  @override
  String get electricityBill => 'ค่าไฟ';

  @override
  String get comingInNextPhase => 'เจอกันเวอร์ชันหน้า';

  @override
  String get thisFeatureIsUnderDevelopment => 'ฟีเจอร์นี้กำลังพัฒนานะ';

  @override
  String get impersonateUser => 'จำลองผู้ใช้ (Impersonate)';

  @override
  String get pleaseEnterAnEmailAddress => 'โปรดระบุอีเมล';

  @override
  String get failedToImpersonateUserPleaseCheckTheEmailAndTryAgain => 'จำลองผู้ใช้ไม่สำเร็จ โปรดตรวจสอบอีเมลแล้วลองใหม่';

  @override
  String get enterTheEmailAddressOfTheUserYouWantToImpersonate => 'กรอกอีเมลของผู้ใช้ที่คุณต้องการจำลองการใช้งาน:';

  @override
  String get userEmail => 'อีเมลผู้ใช้';

  @override
  String get youWillSeeDataFromThisUsersPerspectiveWithoutLoggingInAsThem => 'คุณจะเห็นข้อมูลจากมุมมองของผู้ใช้นี้โดยไม่ต้องเข้าสู่ระบบด้วยรหัสผ่านของพวกเขา';

  @override
  String get start => 'เริ่มเลย';

  @override
  String get ethereumEvm => 'Ethereum (EVM)';

  @override
  String get useMetaMaskRainbowBraveEtc => 'ใช้ MetaMask, Rainbow, Brave ฯลฯ';

  @override
  String get solana => 'Solana';

  @override
  String get usePhantomSolflareBackpackEtc => 'ใช้ Phantom, Solflare, Backpack ฯลฯ';

  @override
  String get select => 'เลือก';

  @override
  String get color => 'สี';

  @override
  String get done => 'เสร็จสิ้น';

  @override
  String get moneko => 'Moneko';

  @override
  String get allowance => 'งบใช้ได้';

  @override
  String get updateNow => 'อัปเดตเลย';

  @override
  String get pocketNotFound => 'ไม่พบพ็อกเก็ต';

  @override
  String get pocketNotFoundDescription => 'พ็อกเก็ตที่คุณค้นหาไม่มีอยู่หรือถูกลบไปแล้ว';

  @override
  String get monthlyBudget => 'งบรายเดือน';

  @override
  String get keyInsights => 'ข้อมูลสำคัญ';

  @override
  String get dailyTrend => 'เทรนด์รายวัน';

  @override
  String get past30Days => '30 วันที่ผ่านมา';

  @override
  String get assignToPocket => 'ใส่พ็อกเก็ต';

  @override
  String get groceries => 'ของใช้ในบ้าน';

  @override
  String get foodAndDrinks => 'อาหารและเครื่องดื่ม';

  @override
  String get restaurants => 'ร้านอาหาร';

  @override
  String get takeoutAndDelivery => 'สั่งอาหารและเดลิเวอรี่';

  @override
  String get cofeeAndTea => 'ชาและกาแฟ';

  @override
  String get snacks => 'ขนมและของว่าง';

  @override
  String get householdSupplies => 'ของใช้ในกลุ่ม';

  @override
  String get cleaningSupplies => 'อุปกรณ์ทำความสะอาด';

  @override
  String get homeRepairs => 'ซ่อมแซมบ้าน';

  @override
  String get homeServices => 'บริการดูแลบ้าน';

  @override
  String get furniture => 'เฟอร์นิเจอร์';

  @override
  String get appliances => 'เครื่องใช้ไฟฟ้า';

  @override
  String get homeDecor => 'ตกแต่งบ้าน';

  @override
  String get rent => 'ค่าเช่า';

  @override
  String get mortgage => 'สินเชื่อบ้าน';

  @override
  String get electricity => 'ค่าไฟ';

  @override
  String get water => 'ค่าน้ำ';

  @override
  String get heatingAndGas => 'ค่าแก๊สและทำความร้อน';

  @override
  String get internet => 'ค่าอินเทอร์เน็ต';

  @override
  String get phoneBill => 'ค่าโทรศัพท์';

  @override
  String get trashAndRecycling => 'ค่าขยะและรีไซเคิล';

  @override
  String get homeSecurity => 'ระบบรักษาความปลอดภัย';

  @override
  String get laundyDryCleaning => 'ซักรีด/ซักแห้ง';

  @override
  String get movingCosts => 'ค่าขนย้าย';

  @override
  String get storage => 'ค่าเช่าที่เก็บของ';

  @override
  String get clothingAndShoes => 'เสื้อผ้าและรองเท้า';

  @override
  String get publicTransport => 'ขนส่งสาธารณะ';

  @override
  String get taxiAndRideApps => 'แท็กซี่และเรียกรถ';

  @override
  String get fuelOrGas => 'ค่าน้ำมัน';

  @override
  String get parking => 'ค่าที่จอดรถ';

  @override
  String get tolls => 'ค่าทางด่วน';

  @override
  String get carRepairs => 'ซ่อมรถ';

  @override
  String get carInsurance => 'ประกันรถยนต์';

  @override
  String get carParts => 'อะไหล่รถ';

  @override
  String get carRental => 'เช่ารถ';

  @override
  String get bikeOrScooter => 'จักรยาน/สกู๊ตเตอร์';

  @override
  String get travel => 'ท่องเที่ยว';

  @override
  String get flights => 'เที่ยวบิน';

  @override
  String get hotels => 'โรงแรม';

  @override
  String get travelInsurance => 'ประกันการเดินทาง';

  @override
  String get travelActivities => 'กิจกรรมท่องเที่ยว';

  @override
  String get luggageAndTravelGear => 'กระเป๋าและอุปกรณ์เดินทาง';

  @override
  String get passportVisaFees => 'ค่าพาสปอร์ตและวีซ่า';

  @override
  String get medicalCare => 'การรักษาพยาบาล';

  @override
  String get pharmacy => 'ร้านขายยา';

  @override
  String get dentalCare => 'ทำฟัน';

  @override
  String get eyeCare => 'ดูแลสายตา';

  @override
  String get mentalHealth => 'สุขภาพจิต';

  @override
  String get therapy => 'บำบัด';

  @override
  String get fitnessGym => 'ฟิตเนส/ยิม';

  @override
  String get sportsExercise => 'กีฬาและออกกำลังกาย';

  @override
  String get supplements => 'อาหารเสริม';

  @override
  String get personalCare => 'ของใช้ส่วนตัว';

  @override
  String get beautyCosmetics => 'ความงามและเครื่องสำอาง';

  @override
  String get spaMassage => 'สปาและนวด';

  @override
  String get childcare => 'ดูแลเด็ก';

  @override
  String get schoolSupplies => 'อุปกรณ์การเรียน';

  @override
  String get kidsActivities => 'กิจกรรมเด็ก';

  @override
  String get kidsClothing => 'เสื้อผ้าเด็ก';

  @override
  String get toysGames => 'ของเล่นและเกม';

  @override
  String get babySupplies => 'ของใช้ทารก';

  @override
  String get petFood => 'อาหารสัตว์';

  @override
  String get petTreats => 'ขนมสัตว์เลี้ยง';

  @override
  String get vetVisits => 'หาหมอสัตว์';

  @override
  String get petMedicine => 'ยาสัตว์';

  @override
  String get petGrooming => 'อาบน้ำตัดขนสัตว์';

  @override
  String get petSupplies => 'ของใช้สัตว์เลี้ยง';

  @override
  String get petInsurance => 'ประกันสัตว์เลี้ยง';

  @override
  String get petBoardingSitting => 'ฝากเลี้ยงสัตว์';

  @override
  String get workSupplies => 'อุปกรณ์ทำงาน';

  @override
  String get homeOffice => 'โฮมออฟฟิศ';

  @override
  String get softwareTools => 'ซอฟต์แวร์/เครื่องมือ';

  @override
  String get cloudStorage => 'พื้นที่เก็บข้อมูลคลาวด์';

  @override
  String get coursesClasses => 'คอร์สเรียน';

  @override
  String get booksStudyMaterials => 'หนังสือ/สื่อการเรียน';

  @override
  String get examsCertificates => 'ค่าสอบและใบรับรอง';

  @override
  String get coworkingSpace => 'พื้นที่ทำงาน Co-working';

  @override
  String get professionalServices => 'บริการระดับมืออาชีพ';

  @override
  String get businessExpenses => 'ค่าใช้จ่ายทางธุรกิจ';

  @override
  String get adsMarketing => 'โฆษณาและการตลาด';

  @override
  String get licensingFees => 'ค่าใบอนุญาตและธรรมเนียม';

  @override
  String get moviesShows => 'ดูหนัง/ซีรีส์';

  @override
  String get musicStreaming => 'สตรีมมิ่งเพลง';

  @override
  String get gamesApps => 'เกมและแอป';

  @override
  String get hobbies => 'งานอดิเรก';

  @override
  String get craftsArt => 'งานคราฟต์และศิลปะ';

  @override
  String get sportsClubs => 'สโมสรกีฬา';

  @override
  String get concertsEvents => 'คอนเสิร์ตและอีเวนต์';

  @override
  String get barsDrinks => 'บาร์และเครื่องดื่ม';

  @override
  String get dating => 'เดท';

  @override
  String get partiesHosting => 'ปาร์ตี้/จัดงาน';

  @override
  String get gifts => 'ของขวัญ';

  @override
  String get charity => 'บริจาค';

  @override
  String get collectibles => 'ของสะสม';

  @override
  String get salary => 'เงินเดือน';

  @override
  String get bonus => 'โบนัส';

  @override
  String get tips => 'ทิป';

  @override
  String get freelanceIncome => 'รายได้ฟรีแลนซ์';

  @override
  String get rentalIncome => 'รายได้ค่าเช่า';

  @override
  String get interestIncome => 'ดอกเบี้ยรับ';

  @override
  String get cashback => 'เงินคืน';

  @override
  String get pension => 'เงินบำนาญ';

  @override
  String get refunds => 'เงินคืน';

  @override
  String get transfers => 'โอนเงิน';

  @override
  String get investments => 'การลงทุน';

  @override
  String get loanPayments => 'จ่ายเงินกู้';

  @override
  String get debtPayments => 'จ่ายหนี้';

  @override
  String get bankFees => 'ค่าธรรมเนียมธนาคาร';

  @override
  String get taxes => 'ภาษี';

  @override
  String get fines => 'ค่าปรับ';

  @override
  String get governmentServices => 'บริการภาครัฐ';

  @override
  String get postDelivery => 'ไปรษณีย์/ส่งของ';

  @override
  String get religiousSpiritual => 'ศาสนาและจิตวิญญาณ';

  @override
  String get communityEvents => 'กิจกรรมชุมชน';

  @override
  String get environmentalGreen => 'สิ่งแวดล้อม/รักษ์โลก';

  @override
  String get miscellaneous => 'จิปาถะ';

  @override
  String get other => 'อื่นๆ';

  @override
  String get uncategorized => 'ไม่ได้จัดหมวดหมู่';

  @override
  String get ok => 'ตกลง';

  @override
  String get attention => 'โปรดทราบ';

  @override
  String get configureWidget => 'ตั้งค่าวิดเจ็ต';

  @override
  String get viewMode => 'รูปแบบ';

  @override
  String get compactView => 'กะทัดรัด';

  @override
  String get expandedView => 'ขยาย';

  @override
  String get viewModeMini => 'จิ๋ว';

  @override
  String get viewModeWide => 'กว้าง';

  @override
  String get viewModeFull => 'เต็มจอ';

  @override
  String get viewModeCompact => 'กะทัดรัด';

  @override
  String get selectCategoriesMultiple => 'เลือกหมวดหมู่ (เลือกได้หลายอัน)';

  @override
  String get settlingWith => 'เคลียร์บิลกับ';

  @override
  String get offsetByWhatTheyOweYou => 'หักลบกับที่เขาต้องจ่ายคุณ';

  @override
  String get owesYou => 'ต้องจ่ายคุณ';

  @override
  String get viewHistory => 'ดูประวัติ';

  @override
  String get editWidgets => 'แก้ไขวิดเจ็ต';

  @override
  String get settlementsWillAppearHere => 'ประวัติการเคลียร์บิลจะมาอยู่ตรงนี้';

  @override
  String get totalSettled => 'ยอดที่เคลียร์แล้ว';

  @override
  String get settlements => 'เคลียร์บิล';

  @override
  String get items => 'รายการ';

  @override
  String get settledSuccessfully => 'เคลียร์บิลสำเร็จ';

  @override
  String get from => 'จาก';

  @override
  String get to => 'ถึง';

  @override
  String get notYetSplitBanner => 'รายจ่ายนี้ยังไม่ได้หาร ตั้งค่าการหารบิลด้านล่างเลย';

  @override
  String get chooseSourceForAnalysis => 'เลือกช่องทางรับข้อมูล';

  @override
  String get files => 'ไฟล์';

  @override
  String get gallery => 'คลังภาพ';

  @override
  String get textAudio => 'ข้อความ/เสียง';

  @override
  String get homeFabTourTitle => 'จดรายรับหรือรายจ่าย';

  @override
  String get homeFabTourDescription => 'แตะตรงนี้เพื่อจดรายรับ-รายจ่ายผ่าน AI ได้ตลอดเวลา';

  @override
  String get holdLongerToRecord => 'กดค้างไว้เพื่ออัดเสียง';

  @override
  String get recordingFailed => 'อัดเสียงไม่สำเร็จ';

  @override
  String get recordingFileMissing => 'ไม่พบไฟล์เสียง';

  @override
  String get recordingIsEmpty => 'ไม่มีเสียงในไฟล์';

  @override
  String get updateRequiredTitle => 'ต้องอัปเดตแอป';

  @override
  String get updateRequiredMessage => 'Moneko มีเวอร์ชันใหม่แล้ว โปรดอัปเดตเพื่อใช้งานแอปต่อ';

  @override
  String get configureWidgetTitle => 'ตั้งค่าวิดเจ็ต';

  @override
  String get widgetHouseholdLabel => 'สเปซ';

  @override
  String get personalScope => 'ส่วนตัว';

  @override
  String get currencyLabel => 'สกุลเงิน';

  @override
  String get noAnalysisAvailable => 'วิเคราะห์ข้อมูลไม่ได้';

  @override
  String get scenarioSaved => 'เซฟสถานการณ์แล้ว';

  @override
  String get unableToDeleteScenario => 'ลบไม่ได้';

  @override
  String get scenarioDeleted => 'ลบแล้ว';

  @override
  String get deleteScenarioConfirmation => 'แน่ใจนะว่าจะลบ? ลบแล้วกู้คืนไม่ได้นะ';

  @override
  String get startWithLastMonthsBudget => 'เริ่มจากงบเดือนก่อนเลยไหม?';

  @override
  String youHadBudgetLastMonth(Object amount) {
    return 'เดือนที่แล้วคุณตั้งไว้ $amount';
  }

  @override
  String copyBudgetWithAmount(Object amount) {
    return 'ก๊อปปี้งบ ($amount)';
  }

  @override
  String get notificationsRefreshedSuccessfully => 'รีเฟรชการแจ้งเตือนสำเร็จ';

  @override
  String get timezone => 'โซนเวลา (Timezone)';

  @override
  String get defaultsToYourDeviceTime => 'อิงตามเวลาเครื่องของคุณ';

  @override
  String get usedForDatesAndReminders => 'ไว้ใช้อ้างอิงวันที่และเวลาเตือน';

  @override
  String get chooseTimezone => 'เลือกโซนเวลา';

  @override
  String get deviceLabel => 'เครื่อง';

  @override
  String get updatingAvatar => 'กำลังอัปเดตอวตาร...';

  @override
  String failedToProcessImage(Object error) {
    return 'จัดการรูปภาพไม่สำเร็จ: $error';
  }

  @override
  String get pleaseEnterAValidName => 'โปรดใส่ชื่อที่ถูกต้อง';

  @override
  String get profileUpdated => 'อัปเดตโปรไฟล์แล้ว';

  @override
  String failedToUpdate(Object error) {
    return 'อัปเดตไม่สำเร็จ: $error';
  }

  @override
  String get signingOut => 'กำลังออกจากระบบ...';

  @override
  String get resetPasswordDiscordMessage => 'ถ้าจะเปลี่ยนรหัสผ่าน ทักทีมซัพพอร์ตใน Discord ได้เลย';

  @override
  String get openDiscord => 'เปิด Discord';

  @override
  String get authSessionCouldNotBeEstablished => 'ยืนยันตัวตนไม่สำเร็จ';

  @override
  String get unexpectedAuthError => 'เกิดข้อผิดพลาดตอนยืนยันตัวตน';

  @override
  String get completingAuthentication => 'กำลังยืนยันตัวตน...';

  @override
  String get walletSignInStatement => 'ฉันยอมรับข้อตกลงที่ https://moneko.io/terms';

  @override
  String get pocketsBudgetTourTitle => 'ตั้งงบรายเดือนของคุณ';

  @override
  String get pocketsBudgetTourDescription => 'แตะตรงนี้เพื่อแก้งบ หรือลากแถบเพื่อปรับยอด';

  @override
  String switchingToIndex(Object index) {
    return 'กำลังเปลี่ยนไปที่ $index';
  }

  @override
  String get errorInitializingRepository => 'โหลดข้อมูลเริ่มต้นไม่สำเร็จ';

  @override
  String get errorLoadingDashboard => 'โหลดหน้าแดชบอร์ดไม่สำเร็จ';

  @override
  String get selectHouseholdToManageSharedBudgets => 'เลือกสเปซเพื่อจัดการงบกองกลาง';

  @override
  String get usd => 'USD';

  @override
  String iEarnedAmountOnCategory(Object amount, Object category) {
    return 'ฉันมีรายได้ $amount จาก $category';
  }

  @override
  String get failedToUpdateExpense => 'อัปเดตรายจ่ายไม่สำเร็จ';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get thisFieldIsRequired => 'ห้ามเว้นว่าง';

  @override
  String get pleaseEnterAValidValue => 'โปรดใส่ข้อมูลให้ถูกต้อง';

  @override
  String get technicalInfo => 'ข้อมูลทางเทคนิค';

  @override
  String get retryInitialization => 'ลองโหลดใหม่';

  @override
  String get skip => 'ข้าม';

  @override
  String get nudge => 'สะกิด';

  @override
  String get you => 'คุณ';

  @override
  String get change_currency_title => 'เปลี่ยนสกุลเงิน';

  @override
  String get change_currency_desc => 'แตะตรงนี้เพื่อเปลี่ยนสกุลเงิน';

  @override
  String get homeModeTourTitle => 'สลับดูข้อมูลส่วนตัวกับสเปซ';

  @override
  String get homeModeTourDescription => 'แตะตรงนี้เพื่อสลับดูข้อมูลส่วนตัวหรือกองกลาง';

  @override
  String get topCategory => 'หมวดที่จ่ายเยอะสุด';

  @override
  String get selectAll => 'เลือกทั้งหมด';

  @override
  String get deselectAll => 'ไม่เลือกทั้งหมด';

  @override
  String get unknownMember => 'ไม่ระบุสมาชิก';

  @override
  String get totalSpent => 'ยอดจ่ายรวม';

  @override
  String sharedWithMembers(Object count) {
    return 'แชร์กับสมาชิก $count คน';
  }

  @override
  String get noTransactionsForPeriod => 'ไม่มีรายการในช่วงเวลานี้';

  @override
  String get noSavedScenariosYet => 'ยังไม่มีสถานการณ์จำลองที่เซฟไว้';

  @override
  String get allCaughtUpNoPendingInvites => 'เคลียร์หมดแล้ว! ไม่มีคำเชิญค้างอยู่';

  @override
  String get pastInvitationsWillAppearHere => 'คำเชิญเก่าๆ จะอยู่ตรงนี้';

  @override
  String get inviteNewMember => 'เชิญสมาชิกใหม่';

  @override
  String get sendLinkToJoinHousehold => 'ส่งลิงก์ชวนคนเข้าสเปซ';

  @override
  String inHours(Object count, Object plural) {
    return 'ในอีก $count ชั่วโมง';
  }

  @override
  String daysAgo(Object count, Object plural) {
    return '$count วันที่แล้ว';
  }

  @override
  String get avatarUpdated => 'อัปเดตอวตารแล้ว';

  @override
  String get setCurrency => 'ตั้งสกุลเงิน';

  @override
  String get setBudget => 'ตั้งงบ';

  @override
  String get turnOnNotifications => 'เปิดการแจ้งเตือน';

  @override
  String get inviteWithLinks => 'เชิญผ่านลิงก์';

  @override
  String get skipNow => 'ข้ามไปก่อน';

  @override
  String get selectCurrencyForDailySpending => 'เลือกสกุลเงินที่ใช้บ่อยที่สุด';

  @override
  String get createSpendingLimitForCategory => 'ตั้งลิมิตรายจ่ายแล้วรอดูเงินเก็บงอกเงย!';

  @override
  String get getNotifiedBeforeSpendingLimit => 'รับแจ้งเตือนก่อนเงินทะลุลิมิต';

  @override
  String get newMessage => 'ข้อความใหม่';

  @override
  String get closeToSpendingLimit => 'ใกล้ทะลุลิมิตแล้วนะ ระวังหน่อย!';

  @override
  String get inviteOthersToShareBudget => 'ชวนคนมาแชร์งบและจัดการเงินด้วยกันสิ';

  @override
  String get clearAppIconBadgeTitle => 'ลบเลขแจ้งเตือนบนไอคอน';

  @override
  String get clearAppIconBadgeSubtitle => 'เคลียร์เลขสีแดงบนไอคอนแอปถ้าระบบค้าง';

  @override
  String get appIconBadgeCleared => 'เคลียร์เลขบนไอคอนแล้ว';

  @override
  String get appIconBadgeNotSupported => 'เครื่องนี้ไม่รองรับเลขแจ้งเตือนบนไอคอน';

  @override
  String get appIconBadgeClearFailed => 'เคลียร์เลขบนไอคอนไม่สำเร็จ';

  @override
  String get timezoneUpdated => 'อัปเดตโซนเวลาแล้ว';

  @override
  String timezoneUpdateFailed(Object error) {
    return 'อัปเดตโซนเวลาไม่สำเร็จ: $error';
  }

  @override
  String get fixNotificationIssuesTitle => 'แก้ปัญหาไม่แจ้งเตือน';

  @override
  String get fixNotificationIssuesSubtitle => 'รีเฟรชเครื่องนี้ใหม่ถ้าแจ้งเตือนไม่เด้ง';

  @override
  String get changeAvatar => 'เปลี่ยนอวตาร';

  @override
  String get exportAsExcel => 'โหลดเป็นไฟล์ Excel';

  @override
  String get moreOptions => 'ตัวเลือกเพิ่มเติม';

  @override
  String get exportTransactions => 'โหลดไฟล์รายการ';

  @override
  String get recurringTourFabTitle => 'เพิ่มบิลประจำ';

  @override
  String get recurringTourFabDescription => 'สร้างรายรับรายจ่ายที่เกิดทุกเดือน เช่น ค่าสมาชิก บิล หรือเงินเดือน';

  @override
  String get recurringTourTabsTitle => 'ดูบิลประจำแต่ละประเภท';

  @override
  String get recurringTourTabsDescription => 'สลับแท็บเพื่อดูรายรับหรือรายจ่ายที่เกิดซ้ำ';

  @override
  String get insightsTourExampleRentGroceries => 'จ่ายค่าเช่าและซื้อของเข้าห้อง';

  @override
  String get insightsTourExampleEmergencyFund => 'เก็บเงิน 15,000 เป็นกองทุนฉุกเฉิน';

  @override
  String get insightsTourIntro => 'ถาม AI ดูสิว่าอนาคตจะเปย์ไหวไหม';

  @override
  String get insightsTourDataLine => 'คำนวณจากค่าเฉลี่ยที่ผ่านมา (อัปเดตให้อัตโนมัติ)';

  @override
  String get syncBankSectionTitle => 'ผูกบัญชีธนาคาร';

  @override
  String get syncBankAccountsTitle => 'ผูกบัญชีธนาคาร';

  @override
  String get syncBankAccountsSubtitle => 'ผูกธนาคารอย่างปลอดภัยเพื่อดึงยอดและรายการแบบอัตโนมัติ';

  @override
  String get syncBankAccountsTooltip => 'ดูวิธีผูกบัญชีผ่าน Plaid';

  @override
  String get syncBankAccountsComingSoon => 'ฟีเจอร์ผูกธนาคารกำลังจะมาเร็วๆ นี้';

  @override
  String get integrations => 'ผูกแอปอื่น';

  @override
  String get account => 'บัญชี';

  @override
  String get preferences => 'ตั้งค่าทั่วไป';

  @override
  String get tapToSet => 'แตะเพื่อตั้งค่า';

  @override
  String get comingSoon => 'เร็วๆ นี้';

  @override
  String get space => 'สเปซ';

  @override
  String get privateSpace => 'สเปซส่วนตัว';

  @override
  String get sharedSpace => 'สเปซกองกลาง';

  @override
  String get sharedSpacesDescription => 'สเปซกองกลางช่วยให้คุณจัดการงบและแชร์ค่าใช้จ่ายร่วมกับคนอื่นได้';

  @override
  String get privateSpacesDescription => 'สเปซส่วนตัวมีแต่คุณที่เห็น ปลอดภัยสุดๆ เอาไว้จัดการเงินเงียบๆ คนเดียว';

  @override
  String get howDoSpacesWork => 'สเปซคืออะไร?';

  @override
  String get createSpace => 'สร้างสเปซ';

  @override
  String get inviteMembers => 'เชิญสมาชิก';

  @override
  String get onlyYou => 'เฉพาะคุณ';

  @override
  String get ownerPrivate => 'เจ้าของ (ส่วนตัว)';

  @override
  String get inviteLink => 'ลิงก์คำเชิญ';

  @override
  String get generatedInNextStep => 'จะได้ลิงก์ในขั้นตอนถัดไป';

  @override
  String get createPrivateSpace => 'สร้างสเปซส่วนตัว';

  @override
  String get pleaseEnterValidSpaceName => 'โปรดใส่ชื่อสเปซ';

  @override
  String get chooseYourSpace => 'เลือกสเปซ';

  @override
  String get spacesHelpOrganize => 'สเปซช่วยแยกกระเป๋าเงินของคุณให้เป็นสัดส่วน ลองดูสิ:';

  @override
  String get yourPersonalVault => 'เซฟส่วนตัว';

  @override
  String get privateSpaceDescription => 'พื้นที่ส่วนตัวสุดๆ ไว้จดรายจ่ายและเป้าหมายเก็บเงินที่คุณเห็นคนเดียว';

  @override
  String get betterTogether => 'จัดการด้วยกันมันกว่า';

  @override
  String get sharedSpaceDescription2 => 'ชวนแฟนหรือครอบครัวมาตั้งงบกองกลาง หารบิลรัวๆ แล้วพุ่งชนเป้าหมายไปด้วยกัน';

  @override
  String get pleaseEnterValidEmailAddress => 'โปรดใส่อีเมลให้ถูกต้อง';

  @override
  String get linkCopiedToClipboard => 'คัดลอกลิงก์แล้ว';

  @override
  String get invitationReady => 'ลิงก์เชิญพร้อมแล้ว';

  @override
  String get whoDoYouWantToInvite => 'อยากชวนใครเข้าสเปซ?';

  @override
  String get emailInviteDescription => 'ใส่อีเมลเพื่อนส่งคำเชิญตรงๆ หรือสร้างลิงก์ไปส่งเองก็ได้';

  @override
  String get emailAddressOptional => 'อีเมล (ไม่บังคับ)';

  @override
  String get emailPlaceholder => 'name@example.com';

  @override
  String get linkExpiration => 'วันหมดอายุลิงก์';

  @override
  String get createInviteLink => 'สร้างลิงก์คำเชิญ';

  @override
  String get inviteSent => 'ส่งคำเชิญแล้ว!';

  @override
  String get linkReady => 'ลิงก์พร้อมใช้งาน!';

  @override
  String get invitationEmailSent => 'ส่งอีเมลชวนแล้วนะ หรือจะเอาลิงก์ด้านล่างไปส่งเองก็ได้';

  @override
  String get shareLinkDescription => 'ส่งลิงก์นี้ให้คนที่คุณอยากชวนเข้าสเปซเลย';

  @override
  String get invalidInvitationMissingHousehold => 'ลิงก์เชิญพัง: หาข้อมูลสเปซไม่เจอ';

  @override
  String get failedToDeleteHousehold => 'ลบสเปซไม่สำเร็จ';

  @override
  String get failedToLoadHouseholdCoverImages => 'โหลดรูปหน้าปกสเปซไม่สำเร็จ';

  @override
  String get householdNamePlaceholder => 'เช่น บ้านของเรา';

  @override
  String get created => 'สร้างเมื่อ';

  @override
  String get householdCoverImage => 'รูปหน้าปกสเปซ';

  @override
  String get editHouseholdCoverImage => 'เปลี่ยนรูปหน้าปกสเปซ';

  @override
  String get tryJoiningHouseholdAgain => 'ลองเข้าสเปซใหม่อีกครั้ง';

  @override
  String get joinHouseholdPage => 'เข้าร่วมสเปซ';

  @override
  String get joinHouseholdWithInvitationLink => 'เข้าสเปซด้วยลิงก์คำเชิญ';

  @override
  String get pasteInvitationLinkFromHouseholdMember => 'แปะลิงก์ที่เพื่อนส่งมาเลย';

  @override
  String get benefitsOfJoiningHousehold => 'ข้อดี: ดูงบกองกลาง เช็คสถานะการเงิน และตัดสินใจเรื่องเงินไปพร้อมกันได้';

  @override
  String get joiningHouseholdPleaseWait => 'กำลังเข้าสเปซ รอแป๊บนึงนะ...';

  @override
  String get successfullyJoinedHousehold => 'เข้าสเปซสำเร็จแล้ว';

  @override
  String get goToHouseholdOverview => 'ไปที่หน้าสเปซเลย';

  @override
  String get loadingGroupMembers => 'กำลังโหลดสมาชิก...';

  @override
  String get splitGroupNotFound => 'ไม่พบกลุ่มหารบิล';

  @override
  String get coverImageSemanticLabel => 'รูปหน้าปก';

  @override
  String get managePrivateSpace => 'จัดการสเปซส่วนตัว';

  @override
  String get manageSharedSpace => 'จัดการสเปซกองกลาง';

  @override
  String get onboardingFinishNextUp => 'ขั้นตอนต่อไป';

  @override
  String get onboardingFinishHighlightCaptureTitle => 'จดรายจ่ายอัจฉริยะ';

  @override
  String get onboardingFinishHighlightCaptureBody => 'พิมพ์คุย ถ่ายใบเสร็จ หรืออัดเสียง ก็จดได้หมด';

  @override
  String get onboardingFinishHighlightPocketsTitle => 'แบ่งเงินใส่พ็อกเก็ต';

  @override
  String get onboardingFinishHighlightPocketsBody => 'แบ่งงบรายเดือนเป็นซองๆ แล้วคอยเช็คว่าเหลือใช้เท่าไหร่';

  @override
  String get onboardingFinishHighlightHouseholdTitle => 'แชร์กับครอบครัว';

  @override
  String get onboardingFinishHighlightHouseholdBody => 'จัดการเงินคนเดียวชิลๆ หรือแชร์งบกับคนในบ้านก็ได้';

  @override
  String get onboardingFinishHighlightInsightsTitle => 'รู้ลึกเรื่องการใช้เงิน';

  @override
  String get onboardingFinishHighlightInsightsBody => 'ลองถาม AI สิว่า \"เดือนหน้าจะซื้อไอแพดไหวไหม?\"';

  @override
  String get claimFreeTrial => 'ทดลองใช้ฟรีเลย';

  @override
  String get youreAllSet => 'พร้อมใช้งานแล้ว!';

  @override
  String get claimYourFreeTrialToUnlockAllFeatures => 'รับสิทธิ์ทดลองใช้ฟรีเพื่อปลดล็อกฟีเจอร์ทุกอัน';

  @override
  String get startYourJourneyWithMoneko => 'เริ่มต้นใช้งาน Moneko';

  @override
  String get oneMonthFreePremiumAccess => 'ใช้พรีเมียมฟรีเต็มๆ 1 เดือน';

  @override
  String get premiumFeatures => 'ฟีเจอร์พรีเมียม';

  @override
  String get syncAcrossDevices => 'ใช้งานได้หลายเครื่อง ข้อมูลตรงกัน';

  @override
  String get sharedSpacesAndBudgets => 'แชร์สเปซและงบกับคนอื่นได้';

  @override
  String joinDiscordForMonthVoucher(int months) {
    return 'เข้า Discord รับโค้ดพรีเมียมฟรี $months เดือน';
  }

  @override
  String joinOurDiscordForVoucher(int months) {
    return 'เข้าร่วม Discord ของเราเพื่อรับสิทธิ์ใช้งานพรีเมียมฟรี $months เดือน!';
  }

  @override
  String get yourSubscriptionHasExpired => 'สมาชิกพรีเมียมของคุณหมดอายุแล้ว';

  @override
  String get resubscribeToContinueEnjoying => 'ต่ออายุเพื่อใช้งานฟีเจอร์พรีเมียมและข้อมูลเชิงลึกได้อย่างต่อเนื่อง';

  @override
  String get continuePremiumAccess => 'ใช้งานพรีเมียมต่อ';

  @override
  String get allPremiumFeatures => 'ฟีเจอร์พรีเมียมทั้งหมด';

  @override
  String get resubscribe => 'สมัครสมาชิกใหม่';

  @override
  String get dangerZone => 'โซนอันตราย';

  @override
  String get deleteHousehold => 'ลบสเปซ';

  @override
  String get saved => 'บันทึกเรียบร้อย';

  @override
  String get allGroupMembers => 'สมาชิกทุกคนในกลุ่ม';

  @override
  String get justMyself => 'เฉพาะฉันเท่านั้น';

  @override
  String get privateSpaceDescriptionFooter => 'มีเพียงคุณเท่านั้นที่มองเห็นสเปซนี้';

  @override
  String get sharedSpaceDescriptionFooter => 'สมาชิกทุกคนสามารถดูยอดเงินและรายการธุรกรรมได้';

  @override
  String get spaceVisibility => 'การมองเห็นสเปซ';

  @override
  String get whoCanSeeAndAddExpense => 'ใครดูและเพิ่มรายจ่ายได้บ้าง?';

  @override
  String get everyoneInSpaceCanViewAndAddTransactions => 'ทุกคนในสเปซสามารถดูและเพิ่มรายการได้ คุณสามารถชวนสมาชิกเพิ่มได้ในขั้นตอนถัดไป';

  @override
  String get onlyYouCanSeeAndAddTransactionsInThisSpace => 'มีเพียงคุณเท่านั้นที่สามารถดูและเพิ่มรายการในสเปซนี้ได้';

  @override
  String get nameThisSpace => 'ตั้งชื่อสเปซ';

  @override
  String get spaceDeletedSuccessfully => 'ลบสเปซเรียบร้อยแล้ว';

  @override
  String get failedToDelete => 'ลบไม่สำเร็จ';

  @override
  String get continueButton => 'ดำเนินการต่อ';

  @override
  String get createFromTemplate => 'สร้างจากเทมเพลต';

  @override
  String get createFromTemplateDesc => 'เลือกเทมเพลตเพื่อตั้งงบประมาณอย่างรวดเร็ว';

  @override
  String get templateRentHeavyTitle => 'เน้นค่าเช่าและของใช้จำเป็น';

  @override
  String get templateRentHeavyDesc => 'เน้นการจัดการที่พักอาศัยและของใช้พื้นฐาน';

  @override
  String get templateBalancedTitle => 'สายสมดุลเบื้องต้น';

  @override
  String get templateBalancedDesc => 'แบ่งตามสูตร 50/30/20 (จำเป็น/ความสุข/เงินออม)';

  @override
  String get template_couple_dink_title => 'คู่รักวัยทำงาน (DINKs)';

  @override
  String get template_couple_dink_desc => 'คู่รักที่ทำงานทั้งคู่และยังไม่มีลูก เน้นการแบ่งเงินแบบ 50/30/20';

  @override
  String get template_couple_fire_title => 'สายเก็บเงินโหด (FIRE)';

  @override
  String get template_couple_fire_desc => 'เน้นอัตราการออมที่สูงเป็นพิเศษ เพื่อเกษียณเร็วหรือเป้าหมายใหญ่';

  @override
  String get template_couple_debt_title => 'สายปลดหนี้';

  @override
  String get template_couple_debt_desc => 'เน้นการโปะหนี้ให้หมดก่อนเริ่มใช้จ่ายฟุ่มเฟือย';

  @override
  String get template_couple_foodies_title => 'สายกินตัวจริง';

  @override
  String get template_couple_foodies_desc => 'สำหรับคู่รักที่รักการทานข้าวนอกบ้านและซื้อวัตถุดิบพรีเมียม';

  @override
  String get template_couple_home_title => 'คนเพิ่งมีบ้าน';

  @override
  String get template_couple_home_desc => 'เน้นงบไปที่ค่าผ่อนบ้าน การรีโนเวท และของตกแต่ง';

  @override
  String get template_couple_travel_title => 'สายเที่ยวและผจญภัย';

  @override
  String get template_couple_travel_desc => 'สำหรับทริปใหญ่ หรือคนที่รักการเดินทางเป็นชีวิตจิตใจ';

  @override
  String get template_family_bal_title => 'ครอบครัวมาตรฐาน';

  @override
  String get template_family_bal_desc => 'งบประมาณพื้นฐานสำหรับครอบครัวที่มีลูก';

  @override
  String get template_family_single_title => 'ครอบครัวรายได้ทางเดียว';

  @override
  String get template_family_single_desc => 'เน้นการคุมงบอย่างรัดกุมสำหรับครอบครัวที่ทำงานคนเดียว';

  @override
  String get template_family_pets_title => 'ทาสสัตว์เลี้ยง';

  @override
  String get template_family_pets_desc => 'สำหรับบ้านที่เลี้ยงสัตว์และมีค่าใช้จ่ายจุกจิกตามมา';

  @override
  String get template_family_health_title => 'สายรักษาสุขภาพ';

  @override
  String get template_family_health_desc => 'เน้นงบไปที่ค่ารักษาพยาบาล การดูแลสุขภาพ และบำบัด';

  @override
  String get template_family_active_title => 'สายกิจกรรม';

  @override
  String get template_family_active_desc => 'เน้นค่าเรียนพิเศษ กีฬา ดนตรี และชมรมต่างๆ';

  @override
  String get template_family_host_title => 'สายปาร์ตี้/จัดงาน';

  @override
  String get template_family_host_desc => 'สำหรับคนที่ชอบจัดงานสังสรรค์ มีแขกมาบ้าน หรือออกงานสังคมบ่อย';

  @override
  String get template_mates_split_title => 'แชร์ค่าใช้จ่ายในบ้าน';

  @override
  String get template_mates_split_desc => 'แชร์เฉพาะบิลส่วนกลาง ส่วนของใช้ส่วนตัวแยกกระเป๋ากัน';

  @override
  String get template_mates_party_title => 'เพื่อนสายตี้';

  @override
  String get template_mates_party_desc => 'งบส่วนกลางสำหรับงานปาร์ตี้ เครื่องดื่ม และการสังสรรค์';

  @override
  String get template_mates_nomads_title => 'ชาว Digital Nomads';

  @override
  String get template_mates_nomads_desc => 'กลุ่มคนทำงานทางไกลที่แชร์ที่พักหรือ Co-working space ร่วมกัน';

  @override
  String get template_mates_student_title => 'เด็กหอ';

  @override
  String get template_mates_student_desc => 'เน้นความประหยัดขั้นสุด สำหรับค่าอาหารและอุปกรณ์การเรียน';

  @override
  String get template_mates_communal_title => 'อยู่แบบคอมมูน';

  @override
  String get template_mates_communal_desc => 'สไตล์สโลว์ไลฟ์ แชร์ค่าอาหารและของใช้ในบ้านร่วมกันทุกอย่าง';

  @override
  String get template_mates_min_title => 'มินิมอลสายแชร์';

  @override
  String get template_mates_min_desc => 'แชร์แค่ค่าเช่าและค่าน้ำไฟ ที่เหลือจัดการเองส่วนตัว';

  @override
  String get template_pers_freelancer_title => 'ฟรีแลนซ์';

  @override
  String get template_pers_freelancer_desc => 'จัดการรายได้ที่ไม่แน่นอน พร้อมสำรองเงินไว้จ่ายภาษี';

  @override
  String get template_pers_student_title => 'นักศึกษามหาวิทยาลัย';

  @override
  String get template_pers_student_desc => 'บริหารค่าเรียนที่ค่อนข้างสูง พร้อมการใช้ชีวิตแบบประหยัด';

  @override
  String get template_pers_luxury_title => 'รายได้สูง ไลฟ์สไตล์หรู';

  @override
  String get template_pers_luxury_desc => 'เน้นการใช้จ่ายเพื่อความสุข การกินเที่ยว และการดูแลตัวเองระดับพรีเมียม';

  @override
  String get template_pers_car_title => 'สายเดินทาง/คนรักรถ';

  @override
  String get template_pers_car_desc => 'เน้นงบค่าน้ำมัน การซ่อมบำรุง และค่าแต่งรถ';

  @override
  String get template_pers_bio_title => 'สายฟิตเนส/ไบโอแฮคเกอร์';

  @override
  String get template_pers_bio_desc => 'เน้นงบอาหารเสริม ยิม และอาหารออร์แกนิก';

  @override
  String get template_pers_gamer_title => 'สายเทคและเกมเมอร์';

  @override
  String get template_pers_gamer_desc => 'เน้นอุปกรณ์ไอที เกม และบริการดิจิทัลต่างๆ';

  @override
  String get categoryHealthInsurance => 'ประกันสุขภาพ';

  @override
  String get categoryHomeInsurance => 'ประกันที่พักอาศัย';

  @override
  String get categoryLifeInsurance => 'ประกันชีวิต';

  @override
  String get categoryRentersInsurance => 'ประกันผู้เช่า';

  @override
  String get exportExcel => 'ส่งออก Excel';

  @override
  String get exportReceiptsZip => 'ส่งออกไฟล์ ZIP ใบเสร็จ';

  @override
  String get noReceiptsFound => 'ไม่พบใบเสร็จ';

  @override
  String get multipleCurrencies => 'หลายสกุลเงิน';

  @override
  String get importData => 'นำเข้าข้อมูล';

  @override
  String get importStepSelect => 'เลือกไฟล์';

  @override
  String get importStepMap => 'จับคู่ข้อมูล';

  @override
  String get importStepPreview => 'ตรวจสอบ';

  @override
  String get importSelectFileHint => 'เลือกไฟล์ CSV หรือ TXT เพื่อนำเข้า';

  @override
  String get noFileSelected => 'ยังไม่ได้เลือกไฟล์';

  @override
  String get csvTxtSupported => 'รองรับไฟล์ CSV, PDF, XLSX และ XLS';

  @override
  String get importNoTable => 'ยังไม่มีข้อมูลที่จะแสดง';

  @override
  String get selectColumn => 'เลือกคอลัมน์';

  @override
  String get importMapHint => 'จับคู่คอลัมน์ของคุณให้ตรงกับระบบของ Moneko';

  @override
  String get back => 'ย้อนกลับ';

  @override
  String get type => 'ประเภท';

  @override
  String get importPreviewHint => 'ตรวจสอบความถูกต้องก่อนนำเข้าข้อมูลจริง';

  @override
  String get skipDuplicates => 'ข้ามรายการซ้ำ';

  @override
  String get importRowError => 'ต้องแก้ไข';

  @override
  String get importRowDuplicate => 'รายการซ้ำ';

  @override
  String get importRowReady => 'พร้อม';

  @override
  String get importRow => 'แถวข้อมูล';

  @override
  String get importErrorInvalidDate => 'รูปแบบวันที่ไม่ถูกต้อง';

  @override
  String get importErrorInvalidAmount => 'จำนวนเงินไม่ถูกต้อง';

  @override
  String get importErrorUnknown => 'ข้อมูลไม่ครบถ้วน';

  @override
  String get importEditRowTitle => 'แก้ไขข้อมูล';

  @override
  String get importEditDateHint => 'เลือกวันที่';

  @override
  String get importEditAmountHint => 'เช่น 24.99';

  @override
  String get importEditCategoryHint => 'เช่น ของใช้ในบ้าน';

  @override
  String get importEditDescriptionHint => 'บันทึกย่อ (ระบุหรือไม่ก็ได้)';

  @override
  String get importEditSave => 'บันทึก';

  @override
  String get importEditInvalidTitle => 'โปรดแก้ไขข้อมูลเหล่านี้';

  @override
  String get importing => 'กำลังนำเข้า…';

  @override
  String get importConfirm => 'ยืนยันการนำเข้า';

  @override
  String get imported => 'นำเข้าสำเร็จแล้ว';

  @override
  String get failed => 'ไม่สำเร็จ';

  @override
  String get rows => 'แถว';

  @override
  String get valid => 'ถูกต้อง';

  @override
  String get errors => 'ข้อผิดพลาด';

  @override
  String get duplicates => 'รายการซ้ำ';

  @override
  String get importSelectFileTitle => 'เลือกไฟล์';

  @override
  String get file => 'ไฟล์';

  @override
  String get importMapTitle => 'จับคู่คอลัมน์';

  @override
  String get summary => 'สรุปผล';

  @override
  String get options => 'ตัวเลือก';

  @override
  String get required => 'จำเป็น';

  @override
  String get optional => 'ระบุหรือไม่ก็ได้';

  @override
  String get accountOverview => 'ภาพรวมบัญชี';

  @override
  String get displayCurrency => 'สกุลเงินที่แสดง';

  @override
  String get displayCurrencyTooltip => 'ยอดเงินทั้งหมดในหน้านี้ถูกแปลงเป็นสกุลเงินหลักของคุณโดยประมาณ';

  @override
  String get activeAccounts => 'บัญชีที่ใช้งานอยู่';

  @override
  String get financialOverview => 'ภาพรวมการเงิน';

  @override
  String get incomeThisMonth => 'รายรับเดือนนี้';

  @override
  String get expensesThisMonth => 'รายจ่ายเดือนนี้';

  @override
  String get netFlow => 'กระแสเงินสุทธิ';

  @override
  String get netFlowBreakdown => 'รายละเอียดกระแสเงิน';

  @override
  String get totalExpense => 'รายจ่ายรวม';

  @override
  String get netResult => 'ยอดสุทธิ';

  @override
  String get dailyAverage => 'เฉลี่ยรายวัน';

  @override
  String get averageDailySpend => 'ค่าใช้จ่ายเฉลี่ยต่อวัน';

  @override
  String get daysTracked => 'วันที่บันทึก';

  @override
  String get statistics => 'สถิติ';

  @override
  String get trend => 'แนวโน้ม';

  @override
  String get chart => 'กราฟ';

  @override
  String get spendingTrend => 'แนวโน้มการใช้จ่าย';

  @override
  String get topInsight => 'ข้อมูลสำคัญ';

  @override
  String get percentOfSpend => '% ของรายจ่าย';

  @override
  String get insight => 'ข้อมูลเชิงลึก';

  @override
  String get accountsAnalysis => 'วิเคราะห์บัญชี';

  @override
  String get spendByAccount => 'รายจ่ายตามบัญชี';

  @override
  String get accountSpend => 'ยอดจ่ายผ่านบัญชี';

  @override
  String get noAccountActivity => 'ยังไม่มีความเคลื่อนไหวในบัญชี';

  @override
  String get viewAllTransactions => 'ดูรายการทั้งหมด';

  @override
  String get topCategories => 'หมวดหมู่ยอดนิยม';

  @override
  String get transactionsUpper => 'รายการธุรกรรม';

  @override
  String get charts => 'กราฟ';

  @override
  String get accountsList => 'รายชื่อบัญชี';

  @override
  String get transactionsInCategory => 'รายการในหมวดหมู่';

  @override
  String get totalAccounts => 'บัญชีทั้งหมด';

  @override
  String get currencies => 'สกุลเงิน';

  @override
  String get totalTransactions => 'รายการทั้งหมด';

  @override
  String get personal => 'ส่วนตัว';

  @override
  String get ofWord => 'จาก';

  @override
  String get accountSpent => 'จ่ายไป';

  @override
  String get accountIncome => 'ได้รับ';

  @override
  String get accountSpendLabel => 'ยอดจ่าย';

  @override
  String get noExpensesRecorded => 'ยังไม่มีการบันทึกรายจ่ายในเดือนนี้';

  @override
  String get transactionsCount => 'รายการ';

  @override
  String get noTransactionsRecorded => 'ไม่มีรายการในเดือนนี้';

  @override
  String get noExpensesDisplay => 'ไม่มีรายจ่ายที่จะแสดง';

  @override
  String get importInto => 'นำเข้าสู่';

  @override
  String get importColumnFormat => 'รูปแบบคอลัมน์';

  @override
  String get importSplitDebitCredit => 'แยกคอลัมน์ รายรับ/รายจ่าย (Debit/Credit)';

  @override
  String get importSplitDebitCreditHint => 'เปิดใช้งานหากยอดเงินเข้าและออกอยู่คนละคอลัมน์กัน';

  @override
  String get importFieldDebit => 'คอลัมน์รายจ่าย (Debit)';

  @override
  String get importFieldCredit => 'คอลัมน์รายรับ (Credit)';

  @override
  String get importFieldBalance => 'คอลัมน์ยอดคงเหลือ';

  @override
  String get importFieldReference => 'รหัสอ้างอิง';

  @override
  String get noSplitTransactionsFound => 'ไม่พบรายการที่แชร์จ่าย';

  @override
  String get netSplitPosition => 'ยอดสรุปการแชร์จ่าย';

  @override
  String get howThisIsCalculated => 'วิธีการคำนวณ';

  @override
  String ofTotalAmount(Object totalAmount) {
    return 'จากยอดทั้งหมด $totalAmount';
  }

  @override
  String get expenseTitle => 'รายจ่าย';

  @override
  String get amountPlaceholder => 'จำนวนเงิน';

  @override
  String get noteOptional => 'บันทึกย่อ (ระบุหรือไม่ก็ได้)';

  @override
  String get memberName => 'สมาชิก';

  @override
  String get youLabel => 'คุณ';

  @override
  String get unknownLabel => '?';

  @override
  String get selectEllipsis => 'เลือก...';

  @override
  String get howItSCalculated => 'วิธีการคำนวณ';

  @override
  String get appExperience => 'ประสบการณ์การใช้งาน';

  @override
  String get restartOnboarding => 'เริ่มขั้นตอนแนะนำใหม่อีกครั้ง';

  @override
  String get tryAiLoggingTitle => 'พบกับ Moneko ผู้ช่วย AI คนใหม่ของคุณ!';

  @override
  String get tryNow => 'ลองเลย';

  @override
  String get tryAiLoggingSubtitle => 'ถ่ายรูป พิมพ์ หรือพูด—การจดรายจ่ายจะง่ายและสนุกกว่าที่เคย!';

  @override
  String get tryAiLoggingFilesHint => 'มีใบเสร็จไหม? ส่งมาให้เราได้เลย!';

  @override
  String get aiFirstLogCongratsTitle => 'ว้าว! คุณเก่งมาก!';

  @override
  String aiFirstLogCongratsBody(num count, Object target) {
    return 'ยอดเยี่ยม! Moneko เพิ่ม $count รายการลงใน $target ให้คุณแล้ว ทำต่อไปนะ!';
  }

  @override
  String get aiLogSummaryTitle => 'สิ่งที่ Moneko ตรวจพบ!';

  @override
  String aiLogSummaryMore(num count) {
    return 'และอีก $count รายการ';
  }

  @override
  String get aiLogSummaryFallback => 'รายการธุรกรรม';

  @override
  String get aiLogMetaBreakdown => 'รายการย่อย';

  @override
  String get aiPromptExamplesTitle => 'ลองพูดแบบนี้ดูสิ';

  @override
  String get aiPromptExamplesDescription => 'Moneko สามารถแยกวันที่ หมวดหมู่ ร้านค้า หรือแม้แต่แยกรายการย่อยให้คุณได้!';

  @override
  String get aiPromptExample1 => 'กินข้าวเที่ยง 150 บาท วันนี้ที่ MK';

  @override
  String get aiPromptExample2 => 'ซื้อของใช้ในบ้าน 420 บาท เมื่อวาน';

  @override
  String get aiPromptExample3 => 'จ่าย Grab 120 บาท แบ่งเป็นค่ารถกับทิป';

  @override
  String get aiCapabilitiesHint => 'เราจะระบุวันที่ หมวดหมู่ และสกุลเงินให้คุณโดยอัตโนมัติ พร้อมแยกรายการย่อยถ้ามี';

  @override
  String get pocketsIntroTitle => 'จัดระเบียบเงินของคุณ!';

  @override
  String get pocketsIntroSubtitle => 'แบ่งเงินออกเป็นซอง (พ็อกเก็ต) เช่น ของใช้ในบ้าน, กินเที่ยว เพื่อให้รู้ว่าเงินถูกใช้ไปกับอะไรบ้าง!';

  @override
  String get pocketsIntroSetBudgetFirst => 'ตั้งงบประมาณก่อน';

  @override
  String get pocketsIntroSetBudgetHint => 'คุณต้องตั้งงบประมาณรายเดือนก่อน จึงจะสามารถแบ่งเงินใส่พ็อกเก็ตได้';

  @override
  String get pocketsIntroCreatePocket => 'สร้างพ็อกเก็ตแรก';

  @override
  String get pocketsIntroUseTemplate => 'ใช้เทมเพลต';

  @override
  String get pocketsIntroBenefitTrack => 'ติดตามตามหมวดหมู่';

  @override
  String get pocketsIntroBenefitLimit => 'ควบคุมไม่ให้ใช้เกินงบ';

  @override
  String get pocketsIntroBenefitVisual => 'เห็นภาพรวมชัดเจน';

  @override
  String get pocketsIntroOrCustom => 'หรือจะสร้างพ็อกเก็ตเองตามใจชอบ';

  @override
  String get orbitBubbleExpense1 => 'กาแฟ 80 บาท';

  @override
  String get orbitBubbleExpense2 => 'ของเข้าบ้าน 450';

  @override
  String get orbitBubbleExpense3 => 'ชาไข่มุก 45';

  @override
  String get orbitBubbleInsight1 => 'ทริปญี่ปุ่นเดือนหน้าไหวไหม?';

  @override
  String get orbitBubbleInsight2 => 'เดือนนี้ยังอยู่ในงบไหม?';

  @override
  String get orbitBubbleInsight3 => 'ใช้ค่ากินไปเท่าไหร่แล้ว?';

  @override
  String get lastMonth => 'เดือนที่แล้ว';

  @override
  String get onboardingFinishHighlightSharedExpenses => 'แชร์รายจ่ายง่ายๆ ด้วย Moneko';

  @override
  String get onboardingFinishHighlightFreeTrial => 'ทดลองใช้ Moneko ฟรี 30 วัน';

  @override
  String get onboardingFinishHighlightLogExpenses => 'จดรายจ่ายด้วยเสียง ข้อความ รูป หรือแชท';

  @override
  String get onboardingFinishHighlightWhatsApp => 'เพิ่มรายจ่ายได้โดยตรงจาก WhatsApp';

  @override
  String get onboardingFinishHighlightSharedBudgets => 'แชร์งบประมาณกับแฟนหรือครอบครัว';

  @override
  String get onboardingFinishHighlightOnePlan => 'แผนเดียวใช้ได้ครอบคลุมทั้งบ้าน';

  @override
  String get onboardingFinishHighlightEnvelopeBudgeting => 'แบ่งเงินใส่ซอง (Envelope Budgeting) แบบง่ายๆ';

  @override
  String get settingsDeleteAccountTitle => 'ยืนยันการลบบัญชี?';

  @override
  String get settingsDeleteAccountDescription => 'การดำเนินการนี้จะลบบัญชีและข้อมูลทั้งหมดของคุณอย่างถาวรและไม่สามารถกู้คืนได้ โปรดพิมพ์คำว่า DELETE เพื่อยืนยัน';

  @override
  String get settingsDeleteAccountButton => 'ลบบัญชี';

  @override
  String get settingsDeleteAccountConfirmValidation => 'พิมพ์ DELETE เพื่อยืนยัน';

  @override
  String get settingsDeleteAccountInProgress => 'กำลังลบบัญชี...';

  @override
  String get settingsDeleteAccountSuccess => 'ลบบัญชีเรียบร้อยแล้ว';

  @override
  String get settingsDeleteAccountTileBusy => 'กำลังลบ...';

  @override
  String get connectTelegram => 'เชื่อมต่อ Telegram';

  @override
  String get telegramVerification => 'การยืนยันตัวตน Telegram';

  @override
  String get telegramVerified => 'ยืนยัน Telegram เรียบร้อย';

  @override
  String get yourTelegramIsSuccessfullyLinked => 'เชื่อมต่อบัญชี Telegram ของคุณสำเร็จแล้ว';

  @override
  String get verifyingYourTelegram => 'กำลังตรวจสอบบัญชี Telegram...';

  @override
  String get enterThe6DigitCodeFromTelegram => 'กรอกรหัส 6 หลักที่ได้รับจาก Telegram';

  @override
  String get telegramVerifiedSuccessfully => 'ยืนยัน Telegram สำเร็จ';

  @override
  String get fasterLoggingTipTitle => 'เคล็ดลับการจดให้ไวขึ้น';

  @override
  String get fasterLoggingTipDescription => 'คุณสามารถตั้งค่าปุ่มกดค้าง (Quick Action) เพื่อจดรายจ่ายได้รวดเร็วยิ่งขึ้น';

  @override
  String get pressAndHoldQuickAction => 'ตั้งค่าคำสั่งด่วนเมื่อกดค้าง';

  @override
  String get takePhotoWithCamera => 'ถ่ายภาพด้วยกล้อง';

  @override
  String get choosePhotoFromLibrary => 'เลือกรูปจากคลังภาพ';

  @override
  String get recordWithAudio => 'บันทึกด้วยเสียง';

  @override
  String get showTextInputDrawer => 'เปิดช่องพิมพ์ข้อความ';

  @override
  String get notSet => 'ยังไม่ได้ตั้งค่า';

  @override
  String quickActionUpdated(Object action) {
    return 'อัปเดตคำสั่งด่วนแล้ว: $action';
  }

  @override
  String get microphonePermissionRequiredForQuickAudioLogging => 'โปรดอนุญาตให้เข้าถึงไมโครโฟนเพื่อใช้งานการบันทึกเสียง';

  @override
  String unableToStartRecording(Object error) {
    return 'ไม่สามารถเริ่มบันทึกเสียงได้: $error';
  }

  @override
  String get recordingTooShort => 'การบันทึกเสียงสั้นเกินไป';

  @override
  String unableToProcessRecording(Object error) {
    return 'ประมวลผลเสียงไม่สำเร็จ: $error';
  }

  @override
  String get releaseToCancel => 'ปล่อยเพื่อยกเลิก';

  @override
  String get slideRightToCancel => 'ปัดขวาเพื่อยกเลิก';

  @override
  String get telegramConnected => 'เชื่อมต่อ Telegram แล้ว';

  @override
  String get siriShortcuts => 'คำสั่งลัด Siri';

  @override
  String get siriShortcutsDescription => 'จดรายจ่ายได้โดยไม่ต้องเปิดแอป แค่พูดว่า: “Log expense with Moneko”';

  @override
  String get siriShortcutsOpenShortcuts => 'เปิดแอปคำสั่งลัด (Shortcuts)';

  @override
  String get siriShortcutsReady => 'พร้อมใช้งาน';

  @override
  String get siriShortcutsNeedsRefresh => 'ต้องรีเฟรช';

  @override
  String get siriShortcutsSetupRequired => 'ยังไม่ได้ตั้งค่า';

  @override
  String get siriShortcutsChecking => 'กำลังตรวจสอบ...';

  @override
  String get siriShortcutsSyncFailed => 'ซิงค์การตั้งค่า Siri ไม่สำเร็จ';

  @override
  String get siriShortcutsOpenFailed => 'ไม่สามารถเปิดแอปคำสั่งลัดได้';

  @override
  String get whatsAppAccessLimitedTitle => 'การเข้าถึง WhatsApp อาจถูกจำกัด';

  @override
  String whatsAppAccessLimitedDescription(Object countryName) {
    return 'การใช้งาน WhatsApp ถูกจำกัดในบางประเทศ รวมถึงใน $countryName ซึ่งอยู่นอกเหนือการควบคุมของเรา เราขอแนะนำให้ใช้ Telegram แทนเพื่อการใช้งานที่ราบรื่น หากนี่เป็นข้อผิดพลาด คุณสามารถดำเนินการต่อได้ด้านล่าง';
  }

  @override
  String get continueAnyway => 'ดำเนินการต่อ';

  @override
  String get premium => 'พรีเมียม';

  @override
  String get free => 'ฟรี';

  @override
  String get support => 'ช่วยเหลือและสนับสนุน';

  @override
  String get reportABug => 'รายงานปัญหา/บั๊ก';

  @override
  String get submitNewFeatureRequest => 'เสนอแนะฟีเจอร์ใหม่';

  @override
  String version(Object version) {
    return 'เวอร์ชัน $version';
  }

  @override
  String get couldNotLaunchTelegram => 'ไม่สามารถเปิดแอป Telegram ได้';

  @override
  String get couldNotLaunchWhatsApp => 'ไม่สามารถเปิดแอป WhatsApp ได้';

  @override
  String get attachAScreenshot => 'แนบภาพหน้าจอ';

  @override
  String get chooseFromLibrary => 'เลือกจากคลังภาพ';

  @override
  String get pleaseDescribeTheIssueBeforeSubmitting => 'โปรดอธิบายปัญหาของคุณก่อนส่ง';

  @override
  String get pleaseIncludeAtLeast10Characters => 'โปรดระบุรายละเอียดอย่างน้อย 10 ตัวอักษร เพื่อให้เราตรวจสอบได้แม่นยำขึ้น';

  @override
  String get ticketSubmittedWeWillFollowUpSoon => 'ส่งข้อมูลเรียบร้อยแล้ว เราจะรีบดำเนินการให้เร็วที่สุด';

  @override
  String get somethingWentWrongWhileSubmittingTicket => 'เกิดข้อผิดพลาดในการส่งข้อมูล โปรดลองอีกครั้ง';

  @override
  String get submit => 'ส่ง';

  @override
  String get attachScreenshots => 'แนบภาพหน้าจอ';

  @override
  String get addAnotherAttachment => 'เพิ่มไฟล์แนบ';

  @override
  String addUpToImagesUnder5MBEach(Object max) {
    return 'แนบรูปได้สูงสุด $max รูป (ขนาดไม่เกิน 5 MB ต่อรูป)';
  }

  @override
  String ofAttached(Object count, Object max) {
    return 'แนบแล้ว $count จาก $max รูป';
  }

  @override
  String get deviceInformation => 'ข้อมูลอุปกรณ์';

  @override
  String get includeAnonymizedDiagnostics => 'รวมข้อมูลการวิเคราะห์ (แบบไม่ระบุตัวตน) เพื่อช่วยในการแก้ปัญหา';

  @override
  String get tellUsWhatWentWrong => 'เกิดปัญหาอะไรขึ้น? บอกเราหน่อยเพื่อให้เราช่วยแก้ไข (แนบรูปภาพจะดีมาก)';

  @override
  String get shareIdeasFeatureRequests => 'แชร์ไอเดีย ขอฟีเจอร์ใหม่ หรือบอกความรู้สึกของคุณที่มีต่อ Moneko';

  @override
  String get whatHappenedIncludeSteps => 'เกิดอะไรขึ้น? รบกวนแจ้งขั้นตอนก่อนเกิดปัญหา (ถ้าจำได้)';

  @override
  String get shareYourThoughtsFeatureIdeas => 'แชร์ความคิดเห็น ไอเดีย หรือฟีเจอร์ที่คุณอยากเห็น';

  @override
  String get thanksBugReportQueue => 'ขอบคุณ! เราได้รับรายงานบั๊กของคุณแล้ว และจะแจ้งความคืบหน้าทางอีเมล';

  @override
  String get thanksFeedbackTicketLogged => 'ขอบคุณสำหรับข้อเสนอแนะ! เราบันทึกข้อมูลแล้ว และจะติดต่อกลับหากต้องการข้อมูลเพิ่ม';

  @override
  String get eachScreenshotMustBeSmallerThan5MB => 'ภาพหน้าจอแต่ละรูปต้องมีขนาดไม่เกิน 5 MB';

  @override
  String get currentTimezone => 'เขตเวลาปัจจุบัน';

  @override
  String get deviceTimezone => 'เขตเวลาของอุปกรณ์';

  @override
  String get yourCountry => 'ประเทศของคุณ';

  @override
  String get reportABugTitle => 'รายงานบั๊ก';

  @override
  String get submitNewFeatureRequestTitle => 'ขอฟีเจอร์ใหม่';

  @override
  String get tellUsWhatWentWrongDescription => 'แจ้งปัญหาที่พบเพื่อให้เราเร่งแก้ไข (แนบรูปภาพประกอบจะช่วยได้มาก)';

  @override
  String get shareIdeasFeatureRequestsDescription => 'แชร์ไอเดีย หรือฟีเจอร์ใหม่ๆ ที่คุณอยากให้มีในแอป';

  @override
  String get whatHappenedIncludeStepsPlaceholder => 'อธิบายสิ่งที่เกิดขึ้น หรือขั้นตอนก่อนเกิดปัญหา';

  @override
  String get shareYourThoughtsFeatureIdeasPlaceholder => 'แชร์ความต้องการหรือไอเดียเจ๋งๆ ของคุณที่นี่';

  @override
  String get missingCategoryHint => 'หาหมวดหมู่ไม่เจอใช่ไหม? เพิ่มเองได้เลยที่ ';

  @override
  String get categories => 'หมวดหมู่';

  @override
  String get noResultsFound => 'ไม่พบผลลัพธ์';

  @override
  String get edit => 'แก้ไข';

  @override
  String get previewMockReceiptNoted => 'โหมดพรีวิว: บันทึกใบเสร็จจำลองแล้ว (ข้อมูลจะไม่ถูกบันทึกจริง)';

  @override
  String get previewMockUpdatesApplied => 'โหมดพรีวิว: อัปเดตข้อมูลจำลองแล้ว (ข้อมูลจะไม่ถูกบันทึกจริง)';

  @override
  String get previewMockExpenseCreated => 'โหมดพรีวิว: สร้างรายจ่ายจำลองแล้ว (ข้อมูลจะไม่ถูกบันทึกจริง)';

  @override
  String get noTransactionToSave => 'ไม่มีรายการให้บันทึก';

  @override
  String get updateCategoryPreferenceTitle => 'อัปเดตการตั้งค่าหมวดหมู่หรือไม่?';

  @override
  String updateCategoryPreferenceDescription(Object fromLabel, Object toLabel) {
    return 'ในอนาคต ต้องการให้รายการนี้บันทึกลงใน \"$toLabel\" แทนที่ \"$fromLabel\" โดยอัตโนมัติไหม?';
  }

  @override
  String get yes => 'ใช่';

  @override
  String get no => 'ไม่';

  @override
  String get preferenceUpdatedSuccessfully => 'อัปเดตการตั้งค่าเรียบร้อยแล้ว';

  @override
  String get preferenceUpdateFailed => 'อัปเดตการตั้งค่าไม่สำเร็จ';

  @override
  String get previewDeletionSkipped => 'โหมดพรีวิว: ข้ามการลบ (ข้อมูลนี้เป็นเพียงชุดข้อมูลทดสอบ)';

  @override
  String get previewRecurringUpdatedForDemo => 'โหมดพรีวิว: อัปเดตรายการประจำจำลองแล้ว';

  @override
  String get previewRecurringScheduledForDemo => 'โหมดพรีวิว: ตั้งค่ารายการประจำจำลองแล้ว';

  @override
  String get failedToSaveRecurringTransaction => 'ไม่สามารถบันทึกรายการประจำได้';

  @override
  String get onboardingPreviewTitle => 'สัมผัสประสบการณ์ Moneko';

  @override
  String get onboardingPreviewSubtitle => 'ลองเล่นแอปด้วยข้อมูลจำลอง เพื่อทดสอบฟีเจอร์ต่างๆ โดยไม่ต้องใช้เงินจริง';

  @override
  String get onboardingPreviewFeatureAiLogging => 'ลองจดรายจ่ายด้วย AI ในพื้นที่ปลอดภัย';

  @override
  String get onboardingPreviewFeatureExplore => 'สำรวจฟีเจอร์พ็อกเก็ต ข้อมูลเชิงลึก และบิลประจำ';

  @override
  String get onboardingPreviewFeatureSaveProgress => 'สร้างบัญชีภายหลังเพื่อบันทึกข้อมูลจริง';

  @override
  String get onboardingPreviewTakeTour => 'เริ่มทดลองใช้งาน';

  @override
  String get onboardingPreviewCreateAccountInstead => 'สร้างบัญชีเลยตอนนี้';

  @override
  String get onboardingPreviewBubbleAiLogging => 'จดรายจ่ายด้วย AI';

  @override
  String get onboardingPreviewBubbleSmartPockets => 'พ็อกเก็ตอัจฉริยะ';

  @override
  String get onboardingPreviewBubbleSharedSpaces => 'สเปซส่วนรวม';

  @override
  String get onboardingPreviewBubbleInsightfulCharts => 'กราฟวิเคราะห์ข้อมูล';

  @override
  String get onboardingPreviewBubbleWhatsappSync => 'ซิงค์ผ่าน WhatsApp';

  @override
  String get onboardingPreviewBubbleRecurringBills => 'จัดการบิลประจำ';

  @override
  String get settingsCustomCategoriesAction => 'ปรับแต่ง';

  @override
  String customCategoryDeleteConfirmation(Object name) {
    return 'ยืนยันการลบหมวดหมู่ \"$name\"?';
  }

  @override
  String customCategoriesLoadFailed(Object error) {
    return 'โหลดหมวดหมู่ไม่สำเร็จ: $error';
  }

  @override
  String get unhide => 'เลิกซ่อน';

  @override
  String get hide => 'ซ่อน';

  @override
  String get editCategory => 'แก้ไขหมวดหมู่';

  @override
  String get addCustomCategory => 'เพิ่มหมวดหมู่';

  @override
  String get customCategoryNameRequired => 'กรุณาใส่ชื่อหมวดหมู่';

  @override
  String get customCategoryNameTooLong => 'ชื่อหมวดหมู่ต้องยาวไม่เกิน 96 ตัวอักษร';

  @override
  String get customCategoryNameBackticksNotAllowed => 'ชื่อหมวดหมู่ห้ามมีเครื่องหมาย Backtick (`)';

  @override
  String get customCategoryNameControlCharsNotAllowed => 'ชื่อหมวดหมู่ห้ามมีอักขระควบคุม (Control Characters)';

  @override
  String get customCategoryNameReservedOther => 'คำว่า \"other\" ถูกสงวนไว้ ไม่สามารถนำมาใช้เป็นชื่อหมวดหมู่ได้';

  @override
  String get customCategoryNameLabel => 'ชื่อหมวดหมู่';

  @override
  String get customCategoryUpdated => 'อัปเดตหมวดหมู่เรียบร้อย';

  @override
  String get customCategoryUpdateFailed => 'อัปเดตไม่สำเร็จ โปรดตรวจสอบชื่อและข้อจำกัด 96 ตัวอักษร';

  @override
  String get customCategoryAddCta => 'เพิ่มหมวดหมู่';

  @override
  String get manualInputQuickActionLabel => 'กรอกข้อมูลเอง';

  @override
  String get onboardingQuestionHelpMost => 'คุณอยากให้เราช่วยเรื่องอะไรมากที่สุด?';

  @override
  String get onboardingQuestionWhoBudgetWith => 'ปกติคุณบริหารจัดการเงินร่วมกับใคร?';

  @override
  String get onboardingQuestionSplitBills => 'คุณมีการแชร์ค่าใช้จ่ายกับคนอื่นบ้างไหม?';

  @override
  String get onboardingQuestionMonthlyAmount => 'ในแต่ละเดือน คุณตั้งเป้าบริหารเงินประมาณเท่าไหร่?';

  @override
  String get onboardingQuestionHousing => 'ค่าที่พัก: คุณจ่ายค่าเช่าหรือผ่อนบ้านเดือนละเท่าไหร่?';

  @override
  String get onboardingQuestionUtilities => 'ค่าน้ำ ค่าไฟ อินเทอร์เน็ต ประมาณเดือนละเท่าไหร่?';

  @override
  String get onboardingQuestionDebtMinimums => 'ยอดจ่ายหนี้ขั้นต่ำในแต่ละเดือนคือเท่าไหร่?';

  @override
  String get onboardingQuestionSetAside => 'คุณต้องการเก็บเงินออมเดือนละเท่าไหร่?';

  @override
  String get onboardingQuestionEatOut => 'ปกติคุณทานข้าวนอกบ้านหรือสั่งเดลิเวอรี่บ่อยแค่ไหน?';

  @override
  String get onboardingQuestionSubscriptions => 'ค่าสมาชิกและบริการรายเดือนต่างๆ';

  @override
  String get onboardingQuestionPets => 'คุณมีสัตว์เลี้ยงไหม?';

  @override
  String get onboardingQuestionPetSpend => 'ค่าใช้จ่ายสำหรับสัตว์เลี้ยงประมาณเดือนละเท่าไหร่?';

  @override
  String get onboardingQuestionTransport => 'คุณเดินทางด้วยวิธีไหนเป็นหลัก?';

  @override
  String get onboardingQuestionDependents => 'คุณต้องดูแลค่าใช้จ่ายให้คนในครอบครัวหรือลูกไหม?';

  @override
  String get onboardingQuestionPlanAhead => 'มีเป้าหมายใหญ่ๆ ที่ต้องการวางแผนล่วงหน้าไหม?';

  @override
  String get onboardingQuestionBreathingRoom => 'ต้องการเหลือเงินสำรองไว้ใช้สบายๆ แค่ไหน?';

  @override
  String get onboardingPreviewTotal => 'งบประมาณรวมทั้งหมด';

  @override
  String get onboardingPreviewFixed => 'รายจ่ายคงที่คุณกรอกไว้';

  @override
  String get onboardingPreviewLeft => 'เหลือใช้รายวัน + เงินออม';

  @override
  String get onboardingPreviewFixedTooHigh => 'รายจ่ายคงที่สูงกว่างบรวม ลองเพิ่มงบรวมหรือลดรายจ่ายบางอย่างลงนะ';

  @override
  String get onboardingPreviewTightRemainder => 'งบที่เหลือดูจะตึงไปสำหรับการใช้ชีวิตประจำวัน ลองปรับเป้าหมายเงินออมหรือเพิ่มงบรวมดูนะ';

  @override
  String get importAutoMappedBanner => 'ระบบจับคู่คอลัมน์ให้คุณเรียบร้อยแล้ว';

  @override
  String get importReviewMapping => 'ตรวจสอบการจับคู่';

  @override
  String get importIssueInvalidDate => 'วันที่ไม่ถูกต้อง';

  @override
  String get importIssueInvalidAmount => 'จำนวนเงินไม่ถูกต้อง';

  @override
  String get importIssueMissingCurrency => 'ไม่ระบุสกุลเงิน';

  @override
  String get importIssueUnknownType => 'ไม่ระบุประเภท';

  @override
  String get importIssueLowConfidence => 'ความแม่นยำต่ำ';

  @override
  String get importDuplicateInFile => 'ซ้ำ (ภายในไฟล์)';

  @override
  String get importDuplicateInDb => 'ซ้ำ (มีอยู่ในระบบแล้ว)';

  @override
  String get importEditCurrencyHint => 'เช่น USD, THB';

  @override
  String get importEditTypeLabel => 'ประเภทรายการ';

  @override
  String importPartialSuccess(Object failed, Object succeeded) {
    return 'นำเข้าสำเร็จ $succeeded รายการ, ล้มเหลว $failed รายการ';
  }

  @override
  String importAllFailed(Object failed) {
    return 'การนำเข้าล้มเหลว: พบข้อผิดพลาด $failed รายการ';
  }

  @override
  String get monthlyBudgetHint => '15000';

  @override
  String get monthlyHousingAmount => 'ค่าที่พักรายเดือน';

  @override
  String get monthlyHousingAmountHint => '5000';

  @override
  String get monthlyUtilitiesAmount => 'ค่าสาธารณูปโภครายเดือน';

  @override
  String get monthlyUtilitiesAmountHint => '1000';

  @override
  String get debtMinimumPayments => 'ยอดจ่ายหนี้ขั้นต่ำ';

  @override
  String get debtMinimumPaymentsHint => '0';

  @override
  String get inputSource => 'แหล่งข้อมูล';

  @override
  String get analysisResult => 'ผลการวิเคราะห์';

  @override
  String get looksGood => 'ดูดีเลย!';

  @override
  String get importExpenses => 'นำเข้ารายจ่าย';

  @override
  String get selectApp => 'เลือกแอป';

  @override
  String get notUsingAnApp => 'ไม่ได้ใช้แอปอื่น';

  @override
  String get failedToReadFile => 'อ่านไฟล์ไม่สำเร็จ';

  @override
  String get fileTooLarge => 'ไฟล์มีขนาดใหญ่เกินไป (สูงสุด 15MB)';

  @override
  String get onboardingPreAuthBudgetTitle => 'ตั้งงบประมาณรายเดือนไว้ที่เท่าไหร่ดี?';

  @override
  String get onboardingPreAuthBudgetSubtitle => 'เราจะใช้ข้อมูลนี้สร้างร่างพ็อกเก็ตแรกให้คุณ';

  @override
  String get onboardingPreAuthHousingTitle => 'ค่าที่พักของคุณ';

  @override
  String get onboardingPreAuthHousingSubtitle => 'เราใช้ข้อมูลนี้เพื่อให้แน่ใจว่างบของคุณไม่ตึงจนเกินไป';

  @override
  String get onboardingPreAuthNotSureEstimate => 'ไม่แน่ใจ (ให้เราช่วยประเมิน)';

  @override
  String get onboardingPreAuthUtilitiesTitle => 'ค่าสาธารณูปโภคโดยประมาณ';

  @override
  String get onboardingPreAuthUtilitiesKnown => 'ฉันทราบยอดค่าน้ำค่านไฟรายเดือน';

  @override
  String get onboardingPreAuthUtilitiesUnknown => 'ไม่แน่ใจ (ใช้การประเมินจากระบบ)';

  @override
  String get onboardingPreAuthDebtTitle => 'ยอดจ่ายหนี้ขั้นต่ำ';

  @override
  String get onboardingPreAuthDebtSubtitle => 'รวมยอดจ่ายหนี้ขั้นต่ำต่อเดือน (ใส่ 0 หากไม่มีหนี้)';

  @override
  String get onboardingPreAuthCurrencyTitle => 'สกุลเงินที่คุณใช้เป็นประจำ?';

  @override
  String get onboardingPreAuthCurrencySelect => 'เลือกสกุลเงิน';

  @override
  String get onboardingPreAuthCurrencyChangeLater => 'คุณสามารถเปลี่ยนสกุลเงินได้ในภายหลัง';

  @override
  String get onboardingPreAuthCalculatingTitle => 'กำลังจัดสรรงบประมาณที่เหมาะกับคุณ...';

  @override
  String get onboardingPreAuthStarterTitle => 'แผนงบประมาณของคุณพร้อมแล้ว!';

  @override
  String get onboardingPreAuthStarterSubtitle => 'นี่คือร่างแผนแรกที่คุณปรับเปลี่ยนได้ตลอดเวลาในแอป';

  @override
  String get onboardingPreAuthStarterSliderHint => 'เลื่อนแถบหรือแตะจำนวนเงินเพื่อปรับยอด';

  @override
  String get onboardingPreAuthAlmostReadyTitle => 'เกือบเสร็จแล้ว';

  @override
  String get onboardingPreAuthAlmostReadySubtitle => 'บันทึกข้อมูลของคุณไว้เพื่อกลับมาดูได้ทุกเมื่อ';

  @override
  String get onboardingPreAuthSaveBudgetTitle => 'บันทึกงบประมาณของคุณ';

  @override
  String get onboardingPreAuthSaveBudgetSubtitle => 'เข้าสู่ระบบเพื่อจัดเก็บข้อมูลและซิงค์ใช้งานได้ทุกอุปกรณ์';

  @override
  String get onboardingPreAuthSaveBudgetConfirm => 'บันทึกงบของฉัน';

  @override
  String get onboardingPreAuthSaveBudgetPreview => 'ลองใช้งานโหมดพรีวิว';

  @override
  String get onboardingPreAuthAdjustBudgetTitle => 'ปรับแต่งงบประมาณ';

  @override
  String get onboardingPreAuthAdjustBudgetSubtitle => 'คุณสามารถแก้ไขทุกอย่างได้ในภายหลัง';

  @override
  String get onboardingPreAuthAdjustBudgetValidation => 'โปรดระบุจำนวนที่ถูกต้อง';

  @override
  String get onboardingQuestionHousingTitle => 'ที่พักปัจจุบันของคุณเป็นแบบไหน?';

  @override
  String get onboardingQuestionHousingMortgage => 'ผ่อนบ้าน/คอนโด';

  @override
  String get onboardingQuestionHousingRenting => 'เช่าบ้าน/หอพัก';

  @override
  String get onboardingQuestionHousingFamily => 'พักอาศัยกับครอบครัว';

  @override
  String get onboardingQuestionHousingOwn => 'บ้านส่วนตัว (ผ่อนหมดแล้ว)';

  @override
  String get onboardingQuestionSplitTitle => 'ปกติคุณหารค่าใช้จ่ายกับใครบ้างไหม?';

  @override
  String get onboardingQuestionSplitOften => 'เป็นประจำ';

  @override
  String get onboardingQuestionSplitSometimes => 'บางครั้ง';

  @override
  String get onboardingQuestionSplitRarely => 'นานๆ ครั้ง';

  @override
  String get onboardingQuestionSplitNever => 'ไม่เคยเลย';

  @override
  String get onboardingQuestionSubscriptionsTitle => 'คุณมีค่าบริการรายเดือน/สมาชิกไหม?';

  @override
  String get onboardingQuestionSubscriptionsMany => 'มีหลายอย่าง';

  @override
  String get onboardingQuestionSubscriptionsFew => 'มีนิดหน่อย';

  @override
  String get onboardingQuestionSubscriptionsNone => 'ไม่มีเลย';

  @override
  String get onboardingQuestionEatingOutTitle => 'คุณทานข้าวนอกบ้านบ่อยแค่ไหน?';

  @override
  String get onboardingQuestionStyleTitle => 'สไตล์การใช้เงินของคุณเป็นแบบไหน?';

  @override
  String get onboardingQuestionStyleStudent => 'งบนักเรียนนักศึกษา';

  @override
  String get onboardingQuestionStyleFreelancer => 'รายได้ไม่แน่นอนสไตล์ฟรีแลนซ์';

  @override
  String get onboardingQuestionStyleCommuter => 'เน้นการเดินทางทุกวัน';

  @override
  String get onboardingQuestionStyleFoodies => 'สายกินสายเที่ยว';

  @override
  String get onboardingQuestionGoalTitle => 'เป้าหมายการเงินหลักของคุณตอนนี้?';

  @override
  String get onboardingQuestionGoalBalanced => 'รักษาความสมดุล';

  @override
  String get onboardingQuestionGoalSave => 'เน้นการออมให้มากขึ้น';

  @override
  String get onboardingQuestionGoalDebt => 'เน้นการปลดหนี้';

  @override
  String get onboardingQuestionGoalTravel => 'เก็บเงินเที่ยว/ซื้อประสบการณ์';

  @override
  String get onboardingQuestionSavingsTitle => 'เป้าหมายเงินออมของคุณ?';

  @override
  String get onboardingQuestionSavingsFixed => 'ออมยอดเดิมเท่ากันทุกเดือน';

  @override
  String get onboardingQuestionSavingsPercent => 'ออมตามเปอร์เซ็นต์ของรายได้';

  @override
  String get onboardingQuestionSavingsNotSure => 'ยังไม่แน่ใจ';

  @override
  String get onboardingPostAuthLogExpenseTitle => 'สัมผัสความล้ำของ\nMoneko AI';

  @override
  String get onboardingPostAuthLogExpenseSubtitle => 'ลองบันทึกรายจ่ายแรกของคุณสิ! พิมพ์เป็นภาษาพูดหรือถ่ายรูปใบเสร็จ แล้ว AI จะจัดการให้เอง';

  @override
  String get onboardingPostAuthSourceAudioText => 'พูด หรือ พิมพ์';

  @override
  String get onboardingPostAuthSourceTakePhoto => 'ถ่ายรูป';

  @override
  String get onboardingPostAuthExpenseCaptured => 'บันทึกรายจ่ายเรียบร้อย!';

  @override
  String get onboardingPostAuthExpenseExtractedSingle => 'Moneko AI ดึงข้อมูลการจ่ายเงินของคุณสำเร็จแล้ว';

  @override
  String onboardingPostAuthExpenseExtractedMultiple(Object count) {
    return 'Moneko AI ตรวจพบ $count รายการจากข้อมูลของคุณ';
  }

  @override
  String onboardingPostAuthAiExtractionCount(Object count) {
    return 'ดึงข้อมูลโดย AI ($count รายการ)';
  }

  @override
  String get onboardingPostAuthExpenseLoggedInline => 'บันทึกเรียบร้อย!';

  @override
  String get onboardingPostAuthViewExtractionDetails => 'ดูรายละเอียดที่ AI ดึงมาได้';

  @override
  String get onboardingPostAuthImportTitle => 'นำเข้ารายจ่ายของคุณ\nจากแอปอื่น';

  @override
  String get onboardingPostAuthImportQuestion => 'ปัจจุบันคุณใช้แอปไหนบันทึกรายจ่าย?';

  @override
  String onboardingPostAuthImportingFrom(Object app) {
    return 'กำลังนำเข้าข้อมูลจาก $app';
  }

  @override
  String get onboardingPostAuthNotificationsTitle => 'รับการแจ้งเตือนก่อนที่จะ\nใช้เงินเกินงบ';

  @override
  String get onboardingPostAuthNotificationExampleTitle => 'แจ้งเตือนจาก Moneko';

  @override
  String get onboardingPostAuthNotificationExampleSubtitle => 'คุณใกล้จะใช้เงินถึงวงเงินที่ตั้งไว้แล้วนะ';

  @override
  String onboardingPostAuthImportSuccess(Object app, Object count) {
    return 'นำเข้า $count รายการจาก $app สำเร็จแล้ว';
  }

  @override
  String get onboardingPostAuthSkipLater => 'ไว้ทำทีหลัง';

  @override
  String get failedToSyncCurrency => 'ซิงค์การตั้งค่าสกุลเงินไม่สำเร็จ';

  @override
  String get currencyUpdatedSuccess => 'อัปเดตสกุลเงินสำเร็จ';

  @override
  String get missingUserSession => 'ไม่พบเซสชันการใช้งาน';

  @override
  String get invalidResponse => 'การตอบสนองของระบบไม่ถูกต้อง';

  @override
  String get unableToUpdateCurrency => 'ไม่สามารถอัปเดตสกุลเงินได้';

  @override
  String get lifetime => 'ตลอดชีพ';

  @override
  String get perMonth => '/เดือน';

  @override
  String get perYear => '/ปี';

  @override
  String get onboardingCarouselLogTitle => 'จดรายจ่ายได้จากทุกที่';

  @override
  String get onboardingCarouselLogDesc => 'จะจดผ่าน WhatsApp, Telegram, เสียง หรือรูปถ่าย ก็ทำได้ทันที';

  @override
  String get onboardingCarouselSnapTitle => 'ถ่ายรูปใบเสร็จ';

  @override
  String get onboardingCarouselSnapDesc => 'แค่แชะ! Moneko จะแกะรายการย่อยออกมาให้คุณอัตโนมัติ';

  @override
  String get onboardingCarouselShareTitle => 'แชร์ค่าใช้จ่ายเป็นเรื่องง่าย';

  @override
  String get onboardingCarouselShareDesc => 'ติดตามรายจ่ายที่แชร์กัน เห็นยอดตรงกัน และเคลียร์บิลได้รวดเร็ว';

  @override
  String get onboardingCarouselEnvelopeTitle => 'จัดงบแบบแบ่งซอง';

  @override
  String get onboardingCarouselEnvelopeDesc => 'ตั้งวงเงินในแต่ละหมวดหมู่ เพื่อการใช้จ่ายที่ไม่หลุดแผน';

  @override
  String get paywallErrorPurchaseCancelled => 'ยกเลิกการซื้อเรียบร้อยแล้ว';

  @override
  String get paywallErrorManagedInStore => 'กรุณาจัดการสมาชิกผ่าน App Store / Play Store';

  @override
  String get paywallErrorSharedSubscription => 'Apple ID นี้ใช้สมาชิกแบบแชร์ครอบครัว โปรดออกจากกลุ่มเพื่อจัดการส่วนตัว';

  @override
  String get paywallErrorTimedOut => 'การซื้อหมดเวลา โปรดลองอีกครั้ง';

  @override
  String get paywallErrorStoreUnavailable => 'สโตร์ไม่พร้อมใช้งาน โปรดลองอีกครั้งภายหลัง';

  @override
  String get paywallErrorVerificationFailed => 'ยืนยันการซื้อไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get paywallErrorGeneric => 'การซื้อล้มเหลว โปรดลองอีกครั้ง';

  @override
  String get paywallErrorNotActivated => 'ซื้อสำเร็จแล้วแต่ระบบยังไม่เปิดใช้งาน โปรดรีสตาร์ทแอป';

  @override
  String get paywallErrorVerificationFailedRestart => 'ซื้อสำเร็จแต่ยืนยันสถานะไม่ได้ โปรดรีสตาร์ทแอป';

  @override
  String get paywallPlanMonthlyTagline => 'ยืดหยุ่น ยกเลิกได้ตลอดเวลา';

  @override
  String get paywallPlanYearlyTagline => 'คุ้มค่าที่สุดสำหรับการใช้งานระยะยาว';

  @override
  String get paywallPlanLifetimeTagline => 'จ่ายครั้งเดียว ใช้งานได้ตลอดชีพ';

  @override
  String get paywallErrorLoadOptions => 'โหลดตัวเลือกสมาชิกไม่สำเร็จ';

  @override
  String get paywallErrorOpenSettings => 'ไม่สามารถเปิดหน้าตั้งค่าสมาชิกได้';

  @override
  String get paywallErrorStartCheckout => 'เข้าสู่หน้าชำระเงินไม่สำเร็จ';

  @override
  String get paywallErrorNoSession => 'ไม่พบเซสชันผู้ใช้งาน';

  @override
  String get paywallErrorNoCheckoutUrl => 'ไม่พบ URL สำหรับชำระเงิน';

  @override
  String get paywallInfoAlreadyOnPlan => 'คุณกำลังใช้งานแผนนี้อยู่แล้ว';

  @override
  String get paywallErrorStoreUnavailableShort => 'สโตร์ไม่พร้อมใช้งาน';

  @override
  String get paywallErrorMissingProductMapping => 'ไม่พบข้อมูลผลิตภัณฑ์สำหรับ iOS';

  @override
  String get paywallProcessingPurchase => 'กำลังประมวลผลการซื้อ...';

  @override
  String get paywallRedirectingCheckout => 'กำลังพาคุณไปยังหน้าชำระเงิน...';

  @override
  String get paywallRestoringPurchases => 'กำลังกู้คืนรายการที่เคยซื้อ...';

  @override
  String get paywallRestoreSuccess => 'กู้คืนสถานะสมาชิกสำเร็จแล้ว';

  @override
  String paywallRestoreFailed(Object error) {
    return 'กู้คืนไม่สำเร็จ: $error';
  }

  @override
  String get paywallManageSubscriptionPlayStore => 'จัดการการสมัครสมาชิกใน Play Store';

  @override
  String get paywallErrorManagedInPlayStore => 'คุณสมัครสมาชิกผ่าน Play Store โปรดจัดการที่นั่น';

  @override
  String get paywallOpenPlayStore => 'เปิด Play Store';

  @override
  String get paywallTitleSimple => 'การจัดการเงิน\nควรเป็นเรื่องง่าย';

  @override
  String get paywallTitleSubscribe => 'สมัครสมาชิกเลย';

  @override
  String get paywallSubtitleResubscribe => 'เลือกแผนเพื่อกลับมาใช้ฟีเจอร์พรีเมียมแบบจัดเต็ม';

  @override
  String get paywallPreviewApp => 'ลองใช้งานโหมดพรีวิว';

  @override
  String paywallTrialTerms(Object period, Object price) {
    return 'ฉันรับทราบว่าสิทธิ์ทดลองใช้ 7 วันจะต่ออายุอัตโนมัติที่ $price$period เว้นแต่จะยกเลิก';
  }

  @override
  String paywallSubTerms(Object period, Object price) {
    return 'สมาชิกจะต่ออายุอัตโนมัติที่ $price$period เว้นแต่จะยกเลิกล่วงหน้าอย่างน้อย 24 ชั่วโมงก่อนหมดรอบ';
  }

  @override
  String get paywallProcessing => 'กำลังดำเนินการ...';

  @override
  String get paywallStartTrial => 'เริ่มทดลองใช้ฟรี';

  @override
  String get paywallGetLifetime => 'ซื้อแบบตลอดชีพ';

  @override
  String get paywallSubscribe => 'สมัครสมาชิก';

  @override
  String get paywallRestorePurchase => 'กู้คืนการซื้อ';

  @override
  String get paywallTermsPrivacy => 'ข้อกำหนดและนโยบายความเป็นส่วนตัว';

  @override
  String get paywallYearlyTrial => 'ทดลองใช้ฟรี 30 วัน';

  @override
  String get paywallMonthlyTrial => 'ทดลองใช้ฟรี 7 วัน';

  @override
  String get paywallLifetimeSupport => 'จ่ายครั้งเดียว ใช้ได้ตลอดไป';

  @override
  String get paywallFamilySharing => 'รองรับ Family Sharing';

  @override
  String get paywallRatingSuffix => 'คะแนนรีวิว';

  @override
  String get paywallBenefit1 => 'จดรายจ่ายผ่านเสียง ข้อความ รูปภาพ หรือแชท';

  @override
  String get paywallBenefit2 => 'เพิ่มรายจ่ายได้รวดเร็วผ่าน WhatsApp และ Telegram';

  @override
  String get paywallBenefit3 => 'แชร์งบกับคนในบ้าน ข้อมูลอัปเดตเรียลไทม์';

  @override
  String get paywallBenefit4 => 'ระบบจัดการงบแบบแบ่งซอง ช่วยคุมรายจ่ายไม่ให้เกินตัว';

  @override
  String get paywallLovedBy => 'ถูกใจผู้ใช้กว่า 6,000+ คน';

  @override
  String get paywallBadgeSave50 => 'ประหยัด 50%';

  @override
  String get paywallBadgeLimited => 'จำกัดเวลา';

  @override
  String get pocketsCopyDialogTitle => 'คัดลอกพ็อกเก็ตจากเดือนที่แล้ว?';

  @override
  String get pocketsCopyDialogDesc => 'เราจะสร้างพ็อกเก็ตโดยใช้ชื่อ ไอคอน และงบประมาณเดิมจากเดือนที่แล้ว คุณสามารถแก้ไขได้ตลอดเวลา';

  @override
  String get pocketsCopyConfirm => 'คัดลอกพ็อกเก็ต';

  @override
  String get pocketsNewMonthBannerTitle => 'เดือนใหม่ เริ่มจัดการงบกัน!';

  @override
  String get pocketsNewMonthBannerSubtitle => 'ยังไม่ได้ตั้งพ็อกเก็ตสำหรับเดือนนี้เลย จะคัดลอกข้อมูลจากเดือนที่แล้วไหม?';

  @override
  String get pocketsCopyLastMonthAction => 'คัดลอกพ็อกเก็ตเดิม';

  @override
  String get pocketsCopyingAction => 'กำลังคัดลอกข้อมูล...';

  @override
  String pocketsUseLastMonthBudgetAction(Object amount) {
    return 'ใช้งบรวมเท่ากับเดือนที่แล้ว ($amount)';
  }

  @override
  String get pocketsSelectStrategy => 'เลือกรูปแบบการจัดการ';

  @override
  String get pocketsCustomizePockets => 'ปรับแต่งพ็อกเก็ต';

  @override
  String get bills => 'บิลและค่าใช้จ่าย';

  @override
  String get diningOut => 'กินข้าวนอกบ้าน';

  @override
  String get fun => 'ความบันเทิงและสันทนาการ';

  @override
  String get onboardingPreAuthSavingsTitle => 'เป้าหมายการออม';

  @override
  String get onboardingIntroSlide1Title => 'เรื่องเงินบางที\n**ก็ดูวุ่นวาย**';

  @override
  String get onboardingIntroSlide1Body => 'ทั้งบิล ทั้งค่าเช่า และค่ากิน\nรู้ตัวอีกที\nเงินก็หมดไปโดยไม่ทันตั้งตัว';

  @override
  String get onboardingIntroSlide2Title => 'ถึงจะพยายามจดแล้ว\nแต่เชื่อเถอะว่า\n**มีบางยอดที่คุณเผลอลืม**\nไปอย่างง่ายดาย';

  @override
  String get onboardingIntroSlide3Title => 'ไม่ใช่ว่าคุณ\nจัดการเงินไม่เก่งหรอก\nแค่**การตามจดทุกอย่าง**\nมันเหนื่อยเกินความจำเป็น';

  @override
  String get onboardingIntroSlide3Body => 'การต้องตามจดทุกสิ่งทุกอย่าง\nเป็นเรื่องที่น่าเบื่อและเหนื่อยเกินไป';

  @override
  String get onboardingIntroSlide4Title => 'การบันทึกรายจ่าย\nควรเป็นเรื่อง**ง่าย**';

  @override
  String get getStarted => 'เริ่มต้นใช้งาน';

  @override
  String get enterAMonthlyAmountToGenerateYourStartingPocketPlan => 'ระบุยอดเงินรายเดือนเพื่อสร้างแผนพ็อกเก็ตแรกของคุณ';

  @override
  String get addYourMonthlyAmountBeforeWeCanBuildYourPocketPlan => 'กรุณาระบุยอดเงินรายเดือนก่อนเพื่อสร้างแผนพ็อกเก็ต';

  @override
  String get increaseYourMonthlyTotalOrLowerOneOfTheFixedAmounts => 'ลองเพิ่มยอดงบรวม หรือปรับลดค่าใช้จ่ายคงที่บางอย่างลงนะ';

  @override
  String get yourFixedCostsAreHigherThanYourTotalIncreaseYourTotalOrLowerAFixedAmountToContinue => 'รายจ่ายคงที่สูงกว่างบรวม ลองปรับยอดรวมหรือรายจ่ายคงที่เพื่อไปต่อ';

  @override
  String get thisIsTightForDayToDaySpendingConsiderReducingSavingsDebtExtrasOrIncreasingYourTotal => 'งบที่เหลือดูจะตึงไปสำหรับการใช้ชีวิต ลองลดเป้าหมายเงินออมหรือเพิ่มงบรวมดูนะ';

  @override
  String get utilitiesIsEstimatedFromYourProfileYouCanFineTuneItAnytime => 'ค่าสาธารณูปโภคนี้เราประเมินจากโปรไฟล์ของคุณ คุณสามารถปรับแต่งได้ตลอดเวลา';

  @override
  String get housingIsEstimatedFromYourHousingSituationUpdateThisAmountOnceYouKnowIt => 'ค่าที่พักเราประเมินจากสถานะการอยู่อาศัยของคุณ อัปเดตยอดจริงได้เมื่อคุณทราบตัวเลขที่แน่นอน';

  @override
  String get categorySavingsFuture => 'เงินออม / อนาคต';

  @override
  String get categoryKidsDependents => 'ลูก / ผู้ที่อยู่ในอุปการะ';

  @override
  String get categorySharedBills => 'บิลส่วนกลาง';

  @override
  String get categoryEverydaySpending => 'ค่าใช้จ่ายประจำวัน';

  @override
  String get categoryTrueExpenses => 'รายจ่ายจำเป็น';

  @override
  String get categoryBuffer => 'เงินสำรองเผื่อฉุกเฉิน';

  @override
  String get categoryTravelEventFund => 'กองทุนท่องเที่ยว / กิจกรรม';

  @override
  String get categoryStreamingServices => 'สตรีมมิ่ง';

  @override
  String get categorySoftwareApps => 'แอปพลิเคชันและซอฟต์แวร์';

  @override
  String get categoryGymFitness => 'ยิมและฟิตเนส';

  @override
  String get categoryMemberships => 'ค่าสมาชิกต่างๆ';

  @override
  String get categoryVeterinary => 'ค่ารักษาสัตว์เลี้ยง';

  @override
  String get categoryAccommodation => 'ที่พักและโรงแรม';

  @override
  String get categoryEventsEntertainment => 'กิจกรรมและความบันเทิง';

  @override
  String get categoryClothing => 'เสื้อผ้าและเครื่องแต่งกาย';

  @override
  String get categoryElectronics => 'อุปกรณ์อิเล็กทรอนิกส์';

  @override
  String get categoryConvenienceStore => 'ร้านสะดวกซื้อ';

  @override
  String get deleteIncome => 'ลบรายรับ';

  @override
  String get paywallCompetitorPromoText => 'กำลังใช้งานแอปอื่นอยู่ใช่ไหม? ติดต่อเราที่ hello@moneko.io เพื่อรับส่วนลด 50% สำหรับแพ็กเกจตลอดชีพ!';

  @override
  String get connectSocialBannerTitle => 'เชื่อมต่อ Telegram หรือ WhatsApp';

  @override
  String get connectSocialBannerDescription => 'บันทึกข้อมูลได้ง่ายขึ้น เพียงโต้ตอบกับ AI ของเราผ่านแอปส่งข้อความที่คุณชอบ';

  @override
  String get connectSocialBannerButton => 'เชื่อมต่อ';

  @override
  String get connectSocialBottomSheetTitle => 'เลือกแอปส่งข้อความ';

  @override
  String get connectSocialBottomSheetDescription => 'เลือกแอปเพื่อเชื่อมต่อกับ AI ของเรา';

  @override
  String get telegramAppName => 'Telegram';

  @override
  String get whatsappAppName => 'WhatsApp';
}
