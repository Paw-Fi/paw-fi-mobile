// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'Noch keine Ausgaben';

  @override
  String get loginWelcomeBack => 'Willkommen zurück';

  @override
  String get orContinueWithEmail => 'Oder mit E-Mail fortfahren';

  @override
  String get emailAddress => 'E-Mail-Adresse';

  @override
  String get password => 'Passwort';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get signIn => 'Anmelden';

  @override
  String get newToMoneko => 'Neu bei Moneko?';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get resetYourPassword => 'Passwort zurücksetzen';

  @override
  String get email => 'E-Mail';

  @override
  String get exampleEmail => 'du@beispiel.com';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get sendResetLink => 'Link zum Zurücksetzen senden';

  @override
  String get passwordResetEmailSent => 'E-Mail zum Zurücksetzen gesendet. Prüfe deinen Posteingang.';

  @override
  String get enterValidEmail => 'Bitte gib eine gültige E-Mail-Adresse ein';

  @override
  String passwordMinLength(int min) {
    return 'Passwort muss mindestens $min Zeichen lang sein';
  }

  @override
  String fullNameMinLength(int min) {
    return 'Vollständiger Name muss mindestens $min Zeichen lang sein';
  }

  @override
  String get createYourAccount => 'Erstelle dein Konto';

  @override
  String get fullName => 'Vollständiger Name';

  @override
  String get createPassword => 'Passwort erstellen';

  @override
  String get passwordComplexityRequirement => 'Passwort muss mindestens einen Großbuchstaben, einen Kleinbuchstaben und eine Zahl enthalten';

  @override
  String get passwordRequirementShort => 'Passwort: 8+ Zeichen, inkl. Groß-, Kleinbuchstabe und Zahl';

  @override
  String get termsAgreement => 'Mit der Erstellung eines Kontos stimmst du unseren Nutzungsbedingungen und Datenschutzrichtlinien zu.';

  @override
  String get alreadyHaveAccount => 'Hast du bereits ein Konto?';

  @override
  String get signInLower => 'Anmelden';

  @override
  String get verificationCodeSent => 'Bestätigungscode erfolgreich gesendet';

  @override
  String get verifyYourEmail => 'Bestätige deine E-Mail';

  @override
  String verificationEmailSentTo(String email) {
    return 'Wir haben einen 6-stelligen Bestätigungscode an $email gesendet';
  }

  @override
  String get enterCompleteCode => 'Bitte gib den vollständigen 6-stelligen Code ein';

  @override
  String get invalidVerificationCode => 'Ungültiger Bestätigungscode';

  @override
  String get verificationCodeExpired => 'Bestätigungscode abgelaufen. Bitte fordere einen neuen an.';

  @override
  String get verifyEmail => 'E-Mail bestätigen';

  @override
  String get didntReceiveTheCode => 'Keinen Code erhalten? Prüfe deinen Spam-Ordner oder';

  @override
  String resendInSeconds(int seconds) {
    return 'Erneut senden in $seconds Sek.';
  }

  @override
  String get resendVerificationEmail => 'Bestätigungs-E-Mail erneut senden';

  @override
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get signingInWithGoogle => 'Anmeldung mit Google läuft...';

  @override
  String get error => 'Fehler';

  @override
  String get anErrorOccurred => 'Ein Fehler ist aufgetreten';

  @override
  String get unknownError => 'Unbekannter Fehler';

  @override
  String get goToHome => 'Zur Startseite';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ Zahlung erfolgreich! Abonnement wird geprüft...';

  @override
  String get paymentFailed => 'Zahlung fehlgeschlagen';

  @override
  String get paymentCanceled => 'ℹ️ Zahlung abgebrochen';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp erfolgreich verifiziert!';

  @override
  String get settings => 'Einstellungen';

  @override
  String get enableNotificationsInSettings => 'Aktiviere Benachrichtigungen für Moneko in deinen Geräteeinstellungen.';

  @override
  String get appearance => 'Darstellung';

  @override
  String get darkMode => 'Dunkelmodus';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get pushNotifications => 'Push-Benachrichtigungen';

  @override
  String get receiveAlertsAndUpdates => 'Warnungen und Updates erhalten';

  @override
  String get language => 'Sprache';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get membership => 'Mitgliedschaft';

  @override
  String get loading => 'Laden...';

  @override
  String get failedToLoadMembership => 'Mitgliedschaft konnte nicht geladen werden';

  @override
  String get couldNotOpenMembershipPage => 'Seite zur Mitgliedschaft konnte nicht geöffnet werden';

  @override
  String get freePlan => 'Kostenlos';

  @override
  String get freePlanStatus => 'Kostenloser Plan';

  @override
  String get lifetimePlan => 'Lebenslang';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus Monatlich';

  @override
  String get plusYearlyPlan => 'Plus Jährlich';

  @override
  String get activeStatus => 'Aktiv';

  @override
  String get activeLifetimeStatus => 'Aktiv • Lebenslang';

  @override
  String get canceledStatus => 'Gekündigt';

  @override
  String get pastDueStatus => 'Überfällig';

  @override
  String get trialStatus => 'Testphase';

  @override
  String trialEndsInDays(int days) {
    return 'Testphase endet in $days Tagen';
  }

  @override
  String get trialEnded => 'Testphase beendet';

  @override
  String renewsInDays(int days) {
    return 'Verlängert sich in $days Tagen';
  }

  @override
  String accessEndsInDays(int days) {
    return 'Zugriff endet in $days Tagen';
  }

  @override
  String get subscriptionEnded => 'Abonnement beendet';

  @override
  String get profile => 'Profil';

  @override
  String get errorLoadingProfile => 'Fehler beim Laden des Profils';

  @override
  String get user => 'Benutzer';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp verbunden';

  @override
  String get logExpensesViaWhatsApp => 'Ausgaben per WhatsApp erfassen';

  @override
  String get connectWhatsApp => 'WhatsApp verbinden';

  @override
  String get newBadge => 'NEU';

  @override
  String get logExpensesInstantly => 'Ausgaben sofort per Chat erfassen';

  @override
  String get fast => 'Schnell';

  @override
  String get photo => 'Foto';

  @override
  String get autoSync => 'Auto-Sync';

  @override
  String get naturalLanguage => 'Natürliche Sprache';

  @override
  String get describeExpenseAutomatically => 'Beschreibe deine Ausgabe. Wir erfassen sie automatisch.';

  @override
  String get snapReceipt => 'Beleg scannen';

  @override
  String get snapReceiptDescription => 'Scanne deinen Beleg. Die KI liest ihn aus und erfasst die Daten.';

  @override
  String get previous => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String get overview => 'Übersicht';

  @override
  String get activity => 'Aktivitäten';

  @override
  String get accountInformation => 'Kontoinformationen';

  @override
  String get userId => 'Benutzer-ID';

  @override
  String get recentActivity => 'Letzte Aktivitäten';

  @override
  String get noActivityYet => 'Noch keine Aktivitäten';

  @override
  String get signOut => 'Abmelden';

  @override
  String get insights => 'Einblicke';

  @override
  String get runningTab => 'Verlauf';

  @override
  String get day30Tab => '30 Tage';

  @override
  String get longTermTab => 'Langfristig';

  @override
  String get scenarioTab => 'Szenario';

  @override
  String get runningAndDailyBalances => 'Laufender Saldo & Tagessalden';

  @override
  String get budgetVsSpentDescription => 'Budget vs. Ausgaben pro Tag mit kumulativem laufenden Saldo.';

  @override
  String get runningBalanceLegend => 'Laufender Saldo';

  @override
  String get budgetLegend => 'Budget';

  @override
  String get spentLegend => 'Ausgegeben';

  @override
  String get runningBalanceGuide => 'Anleitung: Laufender Saldo';

  @override
  String get runningBalanceIntro => 'Stell dir dieses Diagramm wie deinen persönlichen Finanzcoach vor. Lass uns ansehen, was es zeigt und wie du es nutzt.';

  @override
  String get day30LookAhead => '30-Tage-Vorschau';

  @override
  String get projectedFromTrailing30Days => 'Prognose basierend auf dem Durchschnitt der letzten 30 Tage.';

  @override
  String get projectedSpendingLegend => 'Prognostizierte Ausgaben';

  @override
  String get peek30DaysAhead => 'Ein Blick 30 Tage voraus';

  @override
  String get day30ForecastIntro => 'Diese Prognose nutzt die Aktivitäten des letzten Monats, um den nächsten Monat einzuschätzen. Sieh es als Wetterbericht für deinen Geldbeutel.';

  @override
  String get longTermProjection => 'Langfristige Prognose';

  @override
  String get basedOnHistoricalAverages => 'Basierend auf historischen Durchschnittswerten; wird automatisch mit deinen Daten aktualisiert.';

  @override
  String get month18ProjectionLegend => '18-Monats-Prognose';

  @override
  String get your18MonthHorizon => 'Dein 18-Monats-Horizont';

  @override
  String get longTermIntro => 'Diese Prognose kombiniert deine Gewohnheiten mit leichten Wachstumsannahmen, damit du siehst, wohin deine heutigen Entscheidungen führen.';

  @override
  String get aiScenarioPlanning => 'KI-Szenarioplanung';

  @override
  String get askAiFinancialAdvisor => 'Frag deinen KI-Finanzberater, ob du dir eine zukünftige Ausgabe leisten kannst.';

  @override
  String get canI => 'Kann ich';

  @override
  String get before => 'vor';

  @override
  String get beforePrefix => 'vor';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Datum wählen';

  @override
  String get check => 'Prüfen';

  @override
  String get enterQuestionAndPickDate => 'Bitte gib eine Frage ein und wähle ein Datum';

  @override
  String get analyzingScenario => 'Szenario wird analysiert...';

  @override
  String get thisMightTakeAWhile => 'Das kann einen Moment dauern';

  @override
  String get whereTheMoneyWent => 'Wohin das Geld ging';

  @override
  String get categoryTotalsForSelectedRange => 'Kategoriesummen für den gewählten Zeitraum.';

  @override
  String get scenarioCategoriesGuide => 'Kategorien verstehen';

  @override
  String get categoryGuideIntro => 'Sieh dieses Diagramm als Vogelperspektive dafür, wohin jeder Euro geflogen ist. So liest du es ohne Taschenrechner.';

  @override
  String get readTheBarChartLikeAPro => 'Das Balkendiagramm wie ein Profi lesen';

  @override
  String get categoryChartDesc => 'Kategorie-Aufschlüsselung für den gewählten Zeitraum.';

  @override
  String get whyThisViewIsHelpful => 'Warum diese Ansicht hilfreich ist';

  @override
  String get categoryWhyHelpfulDesc => 'Erkenne schnell deine größten Ausgabekategorien und entdecke Trends im Zeitverlauf.';

  @override
  String get whatToDoWithTheInsight => 'Was du mit dieser Erkenntnis tun kannst';

  @override
  String get categoryWhatToDoDesc => 'Nutze diese Informationen, um dein Budget und deine Ausgabegewohnheiten anzupassen.';

  @override
  String get scenarioAnalysis => 'Szenarioanalyse';

  @override
  String get target => 'Ziel';

  @override
  String get quickStats => 'Schnell-Statistik';

  @override
  String get currentBalance => 'Aktueller Saldo';

  @override
  String get projectedNoChange => 'Prognose (ohne Änderung)';

  @override
  String get avgDailyNet => 'Ø Tägl. Netto';

  @override
  String get noDataAvailable => 'Keine Daten verfügbar';

  @override
  String get day => 'Tag';

  @override
  String get close => 'Schließen';

  @override
  String get done => 'Fertig';

  @override
  String get whatYouAreSeeing => 'Was du siehst';

  @override
  String get whyItMatters => 'Warum es wichtig ist';

  @override
  String get howToRespond => 'Wie du reagieren kannst';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Dein laufender Saldo zeigt, wie viel Spielraum du nach den täglichen Ausgaben hast. Die Balken zeigen, was du geplant und was du tatsächlich ausgegeben hast.';

  @override
  String get runningBalanceWhyMattersDesc => 'Sieh es als freundlichen Check. Es hilft dir zu erkennen, wenn du besser als geplant dastehst (und weiter investieren kannst) oder wann eine Kurskorrektur nötig ist.';

  @override
  String get runningBalanceHowToRespondDesc => 'Nutze das Diagramm wie einen Coach. Feiere Erfolge, passe Erwartungen an, wenn nötig, und sei nachsichtig mit dir – es geht um stetigen Fortschritt, nicht um Perfektion.';

  @override
  String get whatTheForecastShows => 'Was die Prognose zeigt';

  @override
  String get day30WhatShowsDesc => 'Wir nutzen die Ausgaben und Einnahmen der letzten 30 Tage, um eine durchschnittliche Woche zu skizzieren. Das gleicht einmalige Ausreißer aus, damit du deinen üblichen Rhythmus siehst.';

  @override
  String get day30WhyMattersDesc => 'Vorausschauende Budgets helfen dir, proaktiv zu bleiben. Wenn du teure Tage frühzeitig siehst, kannst du Geld zur Seite legen, anstatt später in Not zu geraten.';

  @override
  String get day30HowToPlaySmartDesc => 'Sieh es als freundlichen Anstoß, nicht als strenges Regelbuch. Passe deinen Plan mit kleinen Schritten an, die sich machbar anfühlen.';

  @override
  String get howTheProjectionWorks => 'Wie die Prognose funktioniert';

  @override
  String get longTermHowWorksDesc => 'Wir schreiben deine durchschnittlichen Einnahmen und Ausgaben fort und rechnen ein moderates Wachstum ein, damit du siehst, ob dein Plan dich auch in Monaten noch im grünen Bereich hält.';

  @override
  String get longTermWhyMattersDesc => 'Langfristige Horizonte machen große Träume greifbar. Sieh, ob dein Notgroschen, deine Investitionen oder große Anschaffungen auf Kurs bleiben.';

  @override
  String get longTermMovesToConsiderDesc => 'Nutze das Diagramm, um zukünftige Entscheidungen durchzuspielen. Kleine Anpassungen heute haben später eine große Wirkung.';

  @override
  String get forMe => 'Für mich';

  @override
  String get forUs => 'Für uns';

  @override
  String get home => 'Start';

  @override
  String get reminder => 'Erinnerung';

  @override
  String get analyzingReceipt => 'Beleg wird analysiert...';

  @override
  String get analyzingExpense => 'Ausgabe wird analysiert...';

  @override
  String get noExpenseInformationExtracted => 'Keine Ausgabeninformationen erkannt';

  @override
  String get failedToAnalyzeNoData => 'Analyse fehlgeschlagen: Keine Daten empfangen';

  @override
  String get failedToAnalyze => 'Analyse fehlgeschlagen';

  @override
  String get updateBudget => 'Budget aktualisieren';

  @override
  String get enterNewTotalDailyBudget => 'Gib das neue tägliche Gesamtbudget ein.';

  @override
  String get budgetAmount => 'Budgetbetrag';

  @override
  String get save => 'Speichern';

  @override
  String get enterValidAmountGreaterThan0 => 'Bitte gib einen gültigen Betrag größer als 0 ein';

  @override
  String get updatingBudget => 'Budget wird aktualisiert...';

  @override
  String get budgetUpdated => 'Budget aktualisiert';

  @override
  String get failedToUpdateBudget => 'Budget konnte nicht aktualisiert werden';

  @override
  String get loggedSuccessfully => 'Erfolgreich erfasst';

  @override
  String get view => 'Ansehen';

  @override
  String get retry => 'Wiederholen';

  @override
  String get failedToCapturePhoto => 'Fotoaufnahme fehlgeschlagen';

  @override
  String get noSpendingData => 'Keine Ausgabendaten';

  @override
  String get byCategory => 'Nach Kategorie';

  @override
  String get noExpensesYet => 'Noch keine Ausgaben';

  @override
  String get startLoggingExpensesToSeeCategories => 'Erfasse Ausgaben, um Kategorien zu sehen';

  @override
  String get selectDateRange => 'Zeitraum auswählen';

  @override
  String get addExpense => 'Ausgabe hinzufügen';

  @override
  String get describeYourExpense => 'Beschreibe deine Ausgabe (z. B. „5 für Burger, 3 für Kaffee“)';

  @override
  String get enterExpenseDetails => 'Ausgabendetails eingeben...';

  @override
  String get freeFormText => 'Freitext';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get transactions => 'Transaktionen';

  @override
  String get negative => 'Negativ';

  @override
  String get positive => 'Positiv';

  @override
  String get spendingBreakdown => 'Ausgaben-Aufschlüsselung';

  @override
  String get spent => 'Ausgegeben';

  @override
  String get today => 'Heute';

  @override
  String get yesterday => 'Gestern';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get lastWeek => 'Letzte Woche';

  @override
  String get thisMonth => 'Dieser Monat';

  @override
  String get last30Days => 'Letzte 30 Tage';

  @override
  String get customRange => 'Benutzerdefiniert';

  @override
  String get spentToday => 'Deine Ausgaben heute';

  @override
  String get spentYesterday => 'Deine Ausgaben gestern';

  @override
  String get spentThisWeek => 'Deine Ausgaben diese Woche';

  @override
  String get spentLastWeek => 'Deine Ausgaben letzte Woche';

  @override
  String get spentThisMonth => 'Deine Ausgaben diesen Monat';

  @override
  String get spentLast30Days => 'Deine Ausgaben (letzte 30 Tage)';

  @override
  String get spentCustom => 'Ausgegeben (benutzerdef.)';

  @override
  String get todaysBudget => 'Heutiges Budget';

  @override
  String get yesterdaysBudget => 'Gestriges Budget';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Summe der Tagesbudgets diese Woche';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Summe der Tagesbudgets letzte Woche';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Summe der Tagesbudgets diesen Monat';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Summe der Tagesbudgets der letzten 30 Tage';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Summe der Tagesbudgets im gewählten Zeitraum';

  @override
  String get netCashflowToday => 'Netto-Cashflow heute';

  @override
  String get netCashflowYesterday => 'Netto-Cashflow gestern';

  @override
  String get netCashflowThisWeek => 'Netto-Cashflow diese Woche';

  @override
  String get netCashflowLastWeek => 'Netto-Cashflow letzte Woche';

  @override
  String get netCashflowThisMonth => 'Netto-Cashflow diesen Monat';

  @override
  String get netCashflowLast30Days => 'Netto-Cashflow (letzte 30 Tage)';

  @override
  String get netCashflowCustom => 'Netto-Cashflow (benutzerdef.)';

  @override
  String get selectCurrency => 'Währung auswählen';

  @override
  String get showLessCurrencies => 'Weniger Währungen anzeigen';

  @override
  String showAllCurrencies(int count) {
    return '$count weitere Währungen anzeigen';
  }

  @override
  String get budget => 'Budget';

  @override
  String get spentLabel => 'Ausgegeben';

  @override
  String get net => 'Netto';

  @override
  String get txn => 'Trans.';

  @override
  String get txns => 'Trans.';

  @override
  String get pleaseEnterExpenseDetails => 'Bitte Ausgabendetails eingeben';

  @override
  String get userNotLoggedIn => 'Benutzer nicht angemeldet';

  @override
  String get errorLoadingHouseholds => 'Fehler beim Laden der Haushalte';

  @override
  String get welcomeToHouseholds => 'Willkommen bei Haushalte';

  @override
  String get householdsDescription => 'Verwaltet geteilte Finanzen mit Familie, Partner oder Mitbewohnern. Behaltet Budgets im Blick, teilt Ausgaben und arbeitet zusammen.';

  @override
  String get createHousehold => 'Haushalt erstellen';

  @override
  String get joinWithInvite => 'Mit Einladung beitreten';

  @override
  String get pleaseUseInvitationLink => 'Bitte nutze einen Einladungslink, um einem Haushalt beizutreten';

  @override
  String get householdName => 'Name des Haushalts';

  @override
  String get householdNameHint => 'z. B. Die Müllers';

  @override
  String get pleaseEnterHouseholdName => 'Bitte gib einen Haushaltsnamen ein';

  @override
  String get errorCreatingHousehold => 'Fehler beim Erstellen des Haushalts';

  @override
  String get householdsFeature => 'Haushalte-Feature';

  @override
  String get householdsFeatureDescription => 'Das Haushalte-Feature ist jetzt verfügbar! Verwalte Finanzen mit Familie, Partnern oder Mitbewohnern.';

  @override
  String get gotIt => 'Verstanden!';

  @override
  String get confirmExpense => 'Ausgabe bestätigen';

  @override
  String get expenseDetails => 'Ausgabendetails';

  @override
  String get details => 'Details';

  @override
  String get category => 'Kategorie';

  @override
  String get currency => 'Währung';

  @override
  String get date => 'Datum';

  @override
  String get time => 'Zeit';

  @override
  String get notes => 'Notizen';

  @override
  String get receipt => 'Beleg';

  @override
  String get saveExpense => 'Ausgabe speichern';

  @override
  String get shareWithHousehold => 'Mit Haushalt teilen';

  @override
  String get loadingHouseholdMembers => 'Haushaltsmitglieder werden geladen...';

  @override
  String get selectHouseholdToConfigureSplit => 'Wähle einen Haushalt, um die Aufteilung zu konfigurieren';

  @override
  String get currencyManagedByHousehold => 'Die Währung wird vom Haushalt verwaltet und kann nicht geändert werden';

  @override
  String get currencyCannotBeChanged => 'Währung kann nicht geändert werden, wenn mit einem Haushalt geteilt wird';

  @override
  String get failedToLoadImage => 'Bild konnte nicht geladen werden';

  @override
  String get editAmount => 'Betrag bearbeiten';

  @override
  String get amount => 'Betrag';

  @override
  String get editNotes => 'Notizen bearbeiten';

  @override
  String get addANote => 'Notiz hinzufügen...';

  @override
  String get noMembersFoundInHousehold => 'Keine Mitglieder im Haushalt gefunden';

  @override
  String get errorLoadingMembers => 'Fehler beim Laden der Mitglieder';

  @override
  String get noExpenseToSave => 'Keine Ausgabe zum Speichern';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'Ausgabe gespeichert und geteilt$splitInfo!';
  }

  @override
  String get expenseSaved => 'Ausgabe gespeichert!';

  @override
  String failedToSave(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Währungseinstellung konnte nicht synchronisiert werden: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Währung erfolgreich aktualisiert';

  @override
  String retryFailed(Object error) {
    return 'Erneuter Versuch fehlgeschlagen: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'Ich habe $currencySymbol$amount für $category ausgegeben.';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Gib das neue tägliche Gesamtbudget ein.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Bitte melde dich an, um die Haushaltsfunktionen zu nutzen';

  @override
  String get quickActions => 'Schnellaktionen';

  @override
  String get members => 'Mitglieder';

  @override
  String get invites => 'Einladungen';

  @override
  String get errorLoadingExpenses => 'Fehler beim Laden der Ausgaben';

  @override
  String get budgets => 'Budgets';

  @override
  String get loadingHousehold => 'Haushalt wird geladen...';

  @override
  String get remaining => 'Übrig';

  @override
  String get overBudget => 'Budget überschritten';

  @override
  String get sharedBudgets => 'Geteilte Budgets';

  @override
  String get netPosition => 'Nettoposition';

  @override
  String get spentByHousehold => 'Ausgaben des Haushalts';

  @override
  String get memberSpending => 'Mitgliederausgaben';

  @override
  String get spentByHouseholdTooltip => 'Dies zeigt den Gesamtbetrag, den alle Haushaltsmitglieder im ausgewählten Zeitraum ausgegeben haben. Es umfasst alle gemeinsamen Ausgaben, die von einem Mitglied des Haushalts erfasst wurden.';

  @override
  String get manageMoneyTogether => 'Verwaltet Geld gemeinsam mit Partner, Familie oder Mitbewohnern an einem Ort.';

  @override
  String get sharedBudgetsExpenses => 'Geteilte Budgets & Ausgaben';

  @override
  String get sharedBudgetsExpensesDesc => 'Setzt Budgets, verfolgt Ausgaben und seht in Echtzeit, wohin euer Geld fließt.';

  @override
  String get smartExpenseSplitting => 'Smarte Ausgabenteilung';

  @override
  String get smartExpenseSplittingDesc => 'Automatische Berechnung, wer was schuldet – flexibel teilbar: gleich, prozentual oder individuell.';

  @override
  String get stayInSync => 'Bleibt synchron';

  @override
  String get stayInSyncDesc => 'Erhaltet Benachrichtigungen bei neuen Ausgaben, erreichten Budgets oder fälligen Abrechnungen.';

  @override
  String get householdSettings => 'Haushaltseinstellungen';

  @override
  String get householdNotFound => 'Haushalt nicht gefunden';

  @override
  String get coverPhoto => 'Titelbild';

  @override
  String get changeCoverPhoto => 'Titelbild ändern';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get errorLoadingHousehold => 'Fehler beim Laden des Haushalts';

  @override
  String get householdUpdatedSuccessfully => 'Haushalt erfolgreich aktualisiert';

  @override
  String get failedToUpdateHousehold => 'Haushalt konnte nicht aktualisiert werden';

  @override
  String get inviteMember => 'Mitglied einladen';

  @override
  String get removeMember => 'Mitglied entfernen';

  @override
  String get remove => 'Entfernen';

  @override
  String get confirmRemoveMember => 'Möchtest du wirklich';

  @override
  String get updatedMemberRole => 'Mitgliedsrolle aktualisiert';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get makeAdmin => 'Zum Admin machen';

  @override
  String get makeMember => 'Zum Mitglied machen';

  @override
  String get invitations => 'Einladungen';

  @override
  String get errorLoadingInvites => 'Fehler beim Laden der Einladungen';

  @override
  String get createInvitation => 'Einladung erstellen';

  @override
  String get pendingInvitations => 'Ausstehende Einladungen';

  @override
  String get noPendingInvitations => 'Keine ausstehenden Einladungen';

  @override
  String get invitationHistory => 'Einladungsverlauf';

  @override
  String get noInvitationHistory => 'Kein Einladungsverlauf';

  @override
  String get emailOptional => 'E-Mail (optional)';

  @override
  String get friendEmailExample => 'freund@beispiel.com';

  @override
  String get personalMessageOptional => 'Persönliche Nachricht (optional)';

  @override
  String get joinHouseholdBudget => 'Tritt unserem Haushaltsbudget bei!';

  @override
  String get expiresIn => 'Läuft ab in';

  @override
  String get oneDay => '1 Tag';

  @override
  String get threeDays => '3 Tage';

  @override
  String get sevenDays => '7 Tage';

  @override
  String get fourteenDays => '14 Tage';

  @override
  String get thirtyDays => '30 Tage';

  @override
  String get unlimited => 'Unbegrenzt';

  @override
  String get create => 'Erstellen';

  @override
  String get invitationCreatedSuccessfully => 'Einladung erfolgreich erstellt';

  @override
  String get inviteLinkCopiedToClipboard => 'Einladungslink in Zwischenablage kopiert!';

  @override
  String get errorCreatingInvite => 'Fehler beim Erstellen der Einladung';

  @override
  String get revokeInvitation => 'Einladung widerrufen';

  @override
  String get confirmRevokeInvitation => 'Möchtest du diese Einladung wirklich widerrufen?';

  @override
  String get revoke => 'Widerrufen';

  @override
  String get invitationRevoked => 'Einladung widerrufen';

  @override
  String get errorRevokingInvite => 'Fehler beim Widerrufen der Einladung';

  @override
  String get anyoneWithLink => 'Jeder mit dem Link';

  @override
  String get noExpiry => 'Läuft nicht ab';

  @override
  String get expired => 'Abgelaufen';

  @override
  String get expires => 'Läuft ab';

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get selectCoverImage => 'Titelbild auswählen';

  @override
  String get failedToLoadImages => 'Bilder konnten nicht geladen werden';

  @override
  String get chooseFromGallery => 'Aus Galerie wählen';

  @override
  String get failedToLoad => 'Laden fehlgeschlagen';

  @override
  String get imageTooLarge => 'Bild zu groß';

  @override
  String get maxIs => 'Max. ist';

  @override
  String get unsupportedFileFormat => 'Nicht unterstütztes Dateiformat. Bitte JPG, PNG oder WebP verwenden.';

  @override
  String get cropCoverImage => 'Titelbild zuschneiden';

  @override
  String get editBudget => 'Budget bearbeiten';

  @override
  String get budgetDetails => 'Budgetdetails';

  @override
  String get budgetName => 'Budgetname';

  @override
  String get period => 'Zeitraum';

  @override
  String get alertThresholds => 'Warnschwellen';

  @override
  String get warningThreshold => 'Warnschwelle (%)';

  @override
  String get alertThreshold => 'Alarmschwelle (%)';

  @override
  String get warningThresholdHelper => 'Warnung, wenn Budgetnutzung diesen Prozentsatz erreicht';

  @override
  String get alertThresholdHelper => 'Kritische Warnung bei diesem Prozentsatz';

  @override
  String get budgetStatus => 'Budgetstatus';

  @override
  String get active => 'Aktiv';

  @override
  String get inactive => 'Inaktiv';

  @override
  String get deletingBudget => 'Budget wird gelöscht...';

  @override
  String get savingChanges => 'Änderungen werden gespeichert...';

  @override
  String get budgetNameCannotBeEmpty => 'Budgetname darf nicht leer sein';

  @override
  String get pleaseEnterValidAmount => 'Bitte gib einen gültigen Betrag ein';

  @override
  String get warningThresholdRange => 'Warnschwelle muss zwischen 0 und 100 liegen';

  @override
  String get alertThresholdRange => 'Alarmschwelle muss zwischen 0 und 100 liegen';

  @override
  String get warningThresholdLessThanAlert => 'Warnschwelle muss kleiner oder gleich der Alarmschwelle sein';

  @override
  String get deleteBudget => 'Budget löschen';

  @override
  String get confirmDeleteBudget => 'Möchtest du wirklich löschen';

  @override
  String get thisActionCannotBeUndone => 'Diese Aktion kann nicht rückgängig gemacht werden';

  @override
  String get budgetUpdatedSuccessfully => 'Budget erfolgreich aktualisiert';

  @override
  String get budgetDeletedSuccessfully => 'Budget erfolgreich gelöscht';

  @override
  String get categoryTransfers => 'Überträge';

  @override
  String get categoryShopping => 'Einkaufen';

  @override
  String get categoryUtilities => 'Nebenkosten';

  @override
  String get categoryEntertainment => 'Unterhaltung';

  @override
  String get categoryEntertainmentSubscriptions => 'Abos (Unterhaltung)';

  @override
  String get categoryRestaurants => 'Restaurants';

  @override
  String get categoryFood => 'Essen & Trinken';

  @override
  String get categoryGroceries => 'Lebensmittel';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Reisen';

  @override
  String get categoryFlights => 'Flüge';

  @override
  String get categoryVacation => 'Urlaub';

  @override
  String get categoryHealth => 'Gesundheit';

  @override
  String get categoryMedical => 'Medizinisches';

  @override
  String get categoryText => 'Text';

  @override
  String get categoryEducation => 'Bildung';

  @override
  String get categoryTuition => 'Studiengebühren';

  @override
  String get categorySubscriptions => 'Abos';

  @override
  String get categoryServices => 'Dienstleistungen';

  @override
  String get categoryHousing => 'Wohnen';

  @override
  String get categoryRent => 'Miete';

  @override
  String get categoryMortgage => 'Hypothek';

  @override
  String get categoryBills => 'Rechnungen';

  @override
  String get categoryInsurance => 'Versicherung';

  @override
  String get categorySavings => 'Sparen';

  @override
  String get categoryInvestment => 'Investment';

  @override
  String get categoryInvestments => 'Investments';

  @override
  String get categoryIncome => 'Einkommen';

  @override
  String get categorySalary => 'Gehalt';

  @override
  String get categoryBonus => 'Bonus';

  @override
  String get categoryPets => 'Haustiere';

  @override
  String get categoryKids => 'Kinder';

  @override
  String get categoryFamily => 'Familie';

  @override
  String get categoryGifts => 'Geschenke';

  @override
  String get categoryCharity => 'Spenden';

  @override
  String get categoryFees => 'Gebühren';

  @override
  String get categoryLoan => 'Kredit';

  @override
  String get categoryLoans => 'Kredite';

  @override
  String get categoryDebt => 'Schulden';

  @override
  String get categoryPersonalCare => 'Körperpflege';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryMisc => 'Sonstiges';

  @override
  String get categoryUncategorized => 'Ohne Kategorie';

  @override
  String get deleteBudgetCannotBeUndone => 'Diese Aktion kann nicht rückgängig gemacht werden';

  @override
  String get delete => 'Löschen';

  @override
  String get failedToDeleteBudget => 'Budget konnte nicht gelöscht werden';

  @override
  String get owner => 'Eigentümer';

  @override
  String get admin => 'Admin';

  @override
  String get member => 'Mitglied';

  @override
  String get pending => 'Ausstehend';

  @override
  String get accepted => 'Angenommen';

  @override
  String get revoked => 'Widerrufen';

  @override
  String get tapToChangeCover => 'Tippen, um Titelbild zu ändern';

  @override
  String get personalMessageHint => 'Sag den Eingeladenen etwas (z. B. „Tritt unserem Haushaltsbudget bei!“) ';

  @override
  String get invitationExpiresIn => 'Einladung läuft ab in';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'e',
      one: '',
    );
    return '$days Tag$_temp0';
  }

  @override
  String get createHouseholdDescription => 'Erstelle einen geteilten Bereich, um Budgets und Ausgaben mit Familie oder Mitbewohnern zu verfolgen.';

  @override
  String get uploadingImage => 'Bild wird hochgeladen...';

  @override
  String get creating => 'Wird erstellt...';

  @override
  String get generatingInvite => 'Einladung wird erstellt...';

  @override
  String get pleaseSelectValidCurrency => 'Bitte wähle eine gültige Haushaltswährung';

  @override
  String nameMaxLength(int max) {
    return 'Name darf max. $max Zeichen lang sein';
  }

  @override
  String get createHouseholdPage => 'Seite „Haushalt erstellen“';

  @override
  String get invitationPersonalMessageInput => 'Eingabe für persönliche Einladungsnachricht';

  @override
  String get householdNameInput => 'Eingabe für Haushaltsnamen';

  @override
  String get invitationExpirationSelector => 'Auswahl für Ablauf der Einladung';

  @override
  String get unlimitedExpiration => 'Unbegrenzte Gültigkeit';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'en',
      one: '',
    );
    return 'Ablauf in $days Tag$_temp0';
  }

  @override
  String get householdInformation => 'Haushaltsinformationen';

  @override
  String get creatingHousehold => 'Haushalt wird erstellt';

  @override
  String get createHouseholdButton => 'Button „Haushalt erstellen“';

  @override
  String get searchExpenses => 'Ausgaben suchen...';

  @override
  String get clearAll => 'Alle löschen';

  @override
  String get allCategories => 'Alle Kategorien';

  @override
  String get allMembers => 'Alle Mitglieder';

  @override
  String get balanceSummary => 'Saldenübersicht';

  @override
  String get youAreOwed => 'Man schuldet dir';

  @override
  String get youOwe => 'Du schuldest';

  @override
  String get youOweOthers => 'Du schuldest anderen';

  @override
  String get othersOweYou => 'Andere schulden dir';

  @override
  String get viewDetails => 'Details ansehen';

  @override
  String get settleUp => 'Abrechnen';

  @override
  String get markExpensesAsSettled => 'Markiere Ausgaben als beglichen, um Salden zu aktualisieren';

  @override
  String get whoAreYouSettlingWith => 'Mit wem rechnest du ab?';

  @override
  String get selectMember => 'Mitglied auswählen';

  @override
  String get amountToSettle => 'Abzurechnender Betrag';

  @override
  String get howDidYouSettle => 'Wie hast du bezahlt?';

  @override
  String get cash => 'Bar';

  @override
  String get paidInCash => 'Bar bezahlt';

  @override
  String get bankTransfer => 'Überweisung';

  @override
  String get transferredViaBank => 'Per Bank überwiesen';

  @override
  String get mobilePayment => 'Mobile Zahlung';

  @override
  String get venmoPaypalEtc => 'PayPal, etc.';

  @override
  String get search => 'Suchen';

  @override
  String get noData => 'Keine Daten';

  @override
  String get filterTransactions => 'Transaktionen filtern';

  @override
  String get noTransactionsFound => 'Keine Transaktionen gefunden';

  @override
  String get failedToLoadHouseholdTransactions => 'Haushaltstransaktionen konnten nicht geladen werden';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get apply => 'Anwenden';

  @override
  String get expenses => 'Ausgaben';

  @override
  String get dateRange => 'Zeitraum';

  @override
  String get noMatchingExpenses => 'Keine passenden Ausgaben';

  @override
  String get startLoggingExpenses => 'Erfasse Ausgaben, um sie hier zu sehen';

  @override
  String get tryAdjustingFilters => 'Versuche, deine Filter anzupassen';

  @override
  String get split => 'Teilen';

  @override
  String get note => 'Notiz';

  @override
  String get currencyCannotBeChangedWhenSharing => 'Währung kann nicht geändert werden, wenn mit einem Haushalt geteilt wird';

  @override
  String get createBudget => 'Budget erstellen';

  @override
  String get pleaseEnterABudgetName => 'Bitte gib einen Budgetnamen ein';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Bitte gib einen gültigen Betrag größer als 0 ein';

  @override
  String get warningThresholdMustBeBetween0And100 => 'Warnschwelle muss zwischen 0 und 100 % liegen';

  @override
  String get alertThresholdMustBeBetween0And100 => 'Alarmschwelle muss zwischen 0 und 100 % liegen';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'Warnschwelle muss kleiner oder gleich der Alarmschwelle sein';

  @override
  String get budgetCreatedSuccessfully => 'Budget erfolgreich erstellt!';

  @override
  String get failedToCreateBudget => 'Budget konnte nicht erstellt werden';

  @override
  String get groceriesRentEntertainment => 'z. B. Lebensmittel, Miete, Unterhaltung';

  @override
  String get budgetType => 'Budget-Typ';

  @override
  String get sharedWithAllHouseholdMembers => 'Geteilt mit allen Haushaltsmitgliedern';

  @override
  String get personalBudgetForYourExpensesOnly => 'Persönliches Budget nur für deine Ausgaben';

  @override
  String get countSplitPortionOnly => 'Nur geteilten Anteil zählen';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Nur deinen Anteil an geteilten Ausgaben für dieses Budget zählen';

  @override
  String get joinHousehold => 'Haushalt beitreten';

  @override
  String get joinAHousehold => 'Einem Haushalt beitreten';

  @override
  String get enterYourInvitationLinkToJoin => 'Gib deinen Einladungslink ein, um einem\ngeteilten Finanzraum beizutreten';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Füge den Einladungslink ein, den du von einem Haushaltsmitglied erhalten hast';

  @override
  String get pasteInvitationLink => 'Einladungslink einfügen';

  @override
  String get pleaseEnterAnInvitationLink => 'Bitte gib einen Einladungslink ein';

  @override
  String get pleaseEnterAValidInvitationLink => 'Bitte gib einen gültigen Einladungslink ein';

  @override
  String get paste => 'Einfügen';

  @override
  String get validating => 'Wird überprüft...';

  @override
  String get continueAction => 'Weiter';

  @override
  String get welcomeAboard => 'Willkommen an Bord!';

  @override
  String get youreNowPartOfTheHousehold => 'Du bist jetzt Teil des Haushalts.\nVerwaltet jetzt gemeinsam eure Finanzen!';

  @override
  String get thisWillOnlyTakeAMoment => 'Dies dauert nur einen Moment';

  @override
  String get unableToJoin => 'Beitreten nicht möglich';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get goToHousehold => 'Zum Haushalt';

  @override
  String get expiresSoon => 'Läuft bald ab';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Einladung gültig bis $formattedDate';
  }

  @override
  String get whatYoullGet => 'Was du bekommst';

  @override
  String get viewSharedBudgetsAndExpenses => 'Geteilte Budgets und Ausgaben anzeigen';

  @override
  String get trackHouseholdFinancialHealth => 'Finanzlage des Haushalts überwachen';

  @override
  String get collaborateOnFinancialDecisions => 'Finanzentscheidungen gemeinsam treffen';

  @override
  String get household => 'Haushalt';

  @override
  String get viewAll => 'Alle ansehen';

  @override
  String get manage => 'Verwalten';

  @override
  String get noBudgetsYet => 'Noch keine Budgets';

  @override
  String get createSharedBudgetDescription => 'Erstellt ein geteiltes Budget, um Ausgaben gemeinsam zu verfolgen';

  @override
  String get errorLoadingBudgets => 'Fehler beim Laden der Budgets';

  @override
  String get recentSplits => 'Letzte Aufteilungen';

  @override
  String get invite => 'Einladen';

  @override
  String get last6Months => 'Letzte 6 Monate';

  @override
  String get thisYear => 'Dieses Jahr';

  @override
  String get allTime => 'Gesamte Zeit';

  @override
  String nameMinLength(int min) {
    return 'Name muss mind. $min Zeichen lang sein';
  }

  @override
  String get splitExpense => 'Ausgabe teilen';

  @override
  String get percent => 'Prozent';

  @override
  String get splitShare => 'Anteil';

  @override
  String get owes => 'Schuldet';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'Aufgeteilte Beträge müssen $currency$amount ergeben';
  }

  @override
  String get percentagesMustTotal100 => 'Prozentsätze müssen 100 % ergeben';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'Jede Person muss mindestens 1 Anteil haben';

  @override
  String get whatsappVerified => 'WhatsApp verifiziert';

  @override
  String get whatsappVerification => 'WhatsApp-Verifizierung';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Deine WhatsApp-Nummer ist erfolgreich mit deinem Konto verknüpft';

  @override
  String get verifyingYourWhatsAppNumber => 'Deine WhatsApp-Nummer wird verifiziert...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Gib den 6-stelligen Code von WhatsApp ein';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Bitte gib den 6-stelligen Bestätigungscode ein';

  @override
  String get failedToVerifyCode => 'Code konnte nicht verifiziert werden';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Code-Verifizierung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Code automatisch vom Verifizierungslink eingefügt';

  @override
  String get verify => 'Verifizieren';

  @override
  String get verifying => 'Wird verifiziert...';

  @override
  String get avatarStudio => 'Avatar-Studio';

  @override
  String get preview => 'Vorschau';

  @override
  String get colors => 'Farben';

  @override
  String get randomize => 'Zufällig';

  @override
  String get saveAvatar => 'Avatar speichern';

  @override
  String get saving => 'Wird gespeichert...';

  @override
  String get skipForNow => 'Jetzt überspringen';

  @override
  String get selectColor => 'Farbe auswählen';

  @override
  String get failedToSaveAvatar => 'Avatar konnte nicht gespeichert werden';

  @override
  String get hair => 'Haare';

  @override
  String get eyes => 'Augen';

  @override
  String get mouth => 'Mund';

  @override
  String get background => 'Hintergrund';

  @override
  String get face => 'Gesicht';

  @override
  String get ears => 'Ohren';

  @override
  String get shirts => 'Shirts';

  @override
  String get brow => 'Augenbrauen';

  @override
  String get nose => 'Nase';

  @override
  String get blush => 'Rouge';

  @override
  String get accessories => 'Accessoires';

  @override
  String get stars => 'Sterne';

  @override
  String get currencyIsManagedByHousehold => 'Die Währung wird vom Haushalt verwaltet und kann nicht geändert werden';

  @override
  String get buyALaptop => 'einen Laptop für 1.200 \$ kaufen';

  @override
  String get selectTargetDate => 'Zieldatum auswählen';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'Kann ich $action vor dem $date?';
  }

  @override
  String get scenarioDateFormat => 'dd.MM.yyyy';

  @override
  String analysisFailed(String error) {
    return 'Analyse fehlgeschlagen: $error';
  }

  @override
  String get leftHandChamps => 'Die Posten links sind deine Spitzenreiter – perfekte Kandidaten für eine schnelle Überprüfung.';

  @override
  String get smallButFrequent => 'Kleine, aber häufige Kategorien deuten auf Gewohnheiten hin, die sich über die Zeit summieren.';

  @override
  String get colorMatches => 'Die Farben passen zur Startseite, damit du dich sofort zurechtfindest.';

  @override
  String get planningNewGoal => 'Planst du ein neues Ziel? Finde Kategorien, die du kürzen kannst, ohne den Spaß zu verlieren.';

  @override
  String get eyeingTreatYourself => 'Planst du einen Gönn-dir-Monat? Sieh nach, welche Bereiche flexibel sind.';

  @override
  String get doubleCheckTagging => 'Prüfe, ob neue Ausgaben richtig zugeordnet wurden – keine Ausreißer erlaubt.';

  @override
  String get slideHighBar => 'Setze bei einem hohen Balken ein kleines Limit oder wechsle zu günstigeren Alternativen.';

  @override
  String get nonNegotiable => 'Wenn ein Balken nicht verhandelbar ist (Hallo, Miete), plane um ihn herum, anstatt dagegen anzukämpfen.';

  @override
  String get revisitAfterScenario => 'Schau nach einem Szenario nochmal hier vorbei, um zu sehen, ob deine Anpassungen greifen.';

  @override
  String get purpleLineCushion => 'Lila Linie: der Puffer, der am Ende des Tages bleibt. Steigende Linien bedeuten, du baust Puffer auf.';

  @override
  String get blueBarsBudget => 'Blaue Balken: dein Budget für diesen Tag.';

  @override
  String get redBarsSpent => 'Rote Balken: was tatsächlich von deinem Konto abging.';

  @override
  String get lineTrendingUpward => 'Linie steigt an = zusätzliches Geld, das du für Sparziele nutzen kannst.';

  @override
  String get flatDippingLine => 'Linie flach oder fallend = Zeit, um innezuhalten und große Posten zu prüfen.';

  @override
  String get sharpDrops => 'Starke Abfälle deuten oft auf ungeplante Käufe hin – tippe sie an, um Details zu sehen.';

  @override
  String get lineRisingDays => 'Linie steigt mehrere Tage an? Überlege, etwas mehr zu sparen oder Schulden zu tilgen.';

  @override
  String get lineDippingWeekend => 'Linie fällt nach einem Wochenende? Gleiche die nächsten Tage aus, indem du kleine, freiwillige Ausgaben kürzt.';

  @override
  String get feelStuckRed => 'Hängst du im roten Bereich fest? Überprüfe dein Budget auf der Startseite – kleine Anpassungen summieren sich.';

  @override
  String get thirtyDayForecastDesc => 'Diese Prognose nutzt die Aktivitäten des letzten Monats, um den nächsten Monat einzuschätzen. Sieh es als Wetterbericht für deinen Geldbeutel.';

  @override
  String get greenLineExpected => 'Grüne Linie = erwartete tägliche Ausgaben, wenn der nächste Monat sich wie der letzte verhält.';

  @override
  String get spikesHighlight => 'Spitzen zeigen Wochen, in denen deine Gewohnheiten teurer werden (Hallo, Lieferdienst am Freitag).';

  @override
  String get forecastUpdates => 'Wenn du neue Transaktionen erfasst, passt sich die Prognose sanft an – keine Aktualisierung nötig.';

  @override
  String get spotExpensivePatterns => 'Erkenne teure Muster frühzeitig und lege einen Mini-Puffer an, bevor sie eintreffen.';

  @override
  String get catchQuieterWeeks => 'Nutze ruhigere Wochen, um zusätzliches Geld zu sparen oder Schulden zu tilgen.';

  @override
  String get timeRecurringPayments => 'Nutze die Einsicht, um wiederkehrende Zahlungen, Abos oder Aufladungen zu planen.';

  @override
  String get bigSpikeComing => 'Eine große Spitze kündigt sich an? Buche günstigere Optionen oder verschiebe flexible Ausgaben auf ruhigere Tage.';

  @override
  String get forecastDipping => 'Prognose fällt? Belohne dich, indem du eine zusätzliche Sparüberweisung einplanst.';

  @override
  String get forecastLooksOff => 'Wenn die Prognose seltsam aussieht, prüfe deine Kategorien auf der Startseite, um Fehler zu korrigieren.';

  @override
  String get greenLineTrends => 'Die grüne Linie folgt deiner typischen Sparrate – ein Aufwärtstrend bedeutet, deine Ziele sind finanziert.';

  @override
  String get lineDipsSignals => 'Wenn die Linie fällt, signalisiert das zukünftige Monate, in denen Ausgaben die Einnahmen übersteigen könnten.';

  @override
  String get largeGoalsDebts => 'Große Ziele oder Schulden werden berücksichtigt, wenn du sie auf der Startseite erfasst.';

  @override
  String get upwardSlope => 'Ein Anstieg? Super! Erwäge, mehr für die Rente oder Reisen zurückzulegen.';

  @override
  String get flatSlipping => 'Flach oder fallend? Zeit, Budgets anzupassen oder Einnahmen zu steigern, bevor es zum Problem wird.';

  @override
  String get watchSeasonalTrends => 'Achte auf saisonale Trends – Feiertage, Semester oder jährliche Beiträge zeigen sich hier oft zuerst.';

  @override
  String get schedulePaymentIncreases => 'Plane leichte Erhöhungen von Kreditzahlungen, wenn die Kurve steigt.';

  @override
  String get planAheadDips => 'Plane für Rückgänge, indem du Rücklagen bildest oder optionale Ausgaben kürzt.';

  @override
  String get checkProjectionMonthly => 'Prüfe die Prognose monatlich, um deine langfristige Planung flexibel und motivierend zu halten.';

  @override
  String get categoryHealthcare => 'Gesundheit';

  @override
  String get categoryOther => 'Sonstiges';

  @override
  String get deleteExpense => 'Ausgabe löschen';

  @override
  String get confirmDeleteExpense => 'Möchtest du diese Ausgabe wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get expenseDeletedSuccessfully => 'Ausgabe erfolgreich gelöscht';

  @override
  String get failedToDeleteExpense => 'Ausgabe konnte nicht gelöscht werden';

  @override
  String get expenseNotFoundOrDeleted => 'Ausgabe nicht gefunden oder bereits gelöscht';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Nur Admins und Besitzer können Haushaltseinstellungen bearbeiten';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Nur Admins und Besitzer können Einladungen erstellen';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Einladung für Haushalt $householdName teilen';
  }

  @override
  String get shareInvitation => 'Einladung teilen';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Haushalt $householdName erfolgreich erstellt';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'Haushalt \"$householdName\" erfolgreich erstellt!';
  }

  @override
  String get invitationLink => 'Einladungslink';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Einladungslink: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Einladungslink kopieren';

  @override
  String get copyInvitationLinkToClipboard => 'Einladungslink in die Zwischenablage kopieren';

  @override
  String get shareInvitationLink => 'Einladungslink teilen';

  @override
  String get share => 'Teilen';

  @override
  String get closeShareSheet => 'Teilen-Fenster schließen';

  @override
  String get invitationLinkCopiedToClipboard => 'Einladungslink in die Zwischenablage kopiert!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Trete meinem Haushalt \"$householdName\" auf Moneko bei!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Trete meinem Haushalt auf Moneko bei';

  @override
  String get zeroAmount => '0,00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Benachrichtigungseinstellungen';

  @override
  String get budgetBoop => 'Budget-Stupser';

  @override
  String get getGentleReminder => 'Erhalte eine sanfte Erinnerung, wenn du diesen Schwellenwert erreichst';

  @override
  String get purrSuasiveNudge => 'Schnurr-Schubser';

  @override
  String get getStrongerNudge => 'Erhalte einen stärkeren Anstoß, wenn du diesen Schwellenwert erreichst';

  @override
  String get createBudgetButton => 'Budget erstellen';

  @override
  String get daily => 'Täglich';

  @override
  String get weekly => 'Wöchentlich';

  @override
  String get monthly => 'Monatlich';

  @override
  String get yearly => 'Jährlich';

  @override
  String get householdBudgetType => 'Haushaltsbudget';

  @override
  String get personalBudgetType => 'Persönliches Budget';

  @override
  String joinHouseholdName(String householdName) {
    return '\"$householdName\" beitreten';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Haushaltsvorschau: $householdName, eingeladen von $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Eingeladen von $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'Einladung läuft bald ab am $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Einladung gültig bis';

  @override
  String get personalMessageFromInviter => 'Persönliche Nachricht vom Absender';

  @override
  String get messageFromInviter => 'Nachricht vom Absender';

  @override
  String get joiningHousehold => 'Haushalt beitreten...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Fehler: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'Ein unerwarteter Fehler ist aufgetreten';

  @override
  String get invalidInvitationLinkFormat => 'Ungültiges Einladungslink-Format';

  @override
  String get invalidOrExpiredInvitation => 'Ungültige oder abgelaufene Einladung';

  @override
  String get tomorrow => 'Morgen';

  @override
  String inDays(int days) {
    return 'in $days Tagen';
  }

  @override
  String get january => 'Jan';

  @override
  String get february => 'Feb';

  @override
  String get march => 'Mär';

  @override
  String get april => 'Apr';

  @override
  String get may => 'Mai';

  @override
  String get june => 'Jun';

  @override
  String get july => 'Jul';

  @override
  String get august => 'Aug';

  @override
  String get september => 'Sep';

  @override
  String get october => 'Okt';

  @override
  String get november => 'Nov';

  @override
  String get december => 'Dez';

  @override
  String remindUser(String name) {
    return '$name erinnern';
  }

  @override
  String get sendFriendlySpendingReminder => 'Eine freundliche Ausgaben-Erinnerung senden';

  @override
  String get addMessageOptional => 'Nachricht hinzufügen (optional)';

  @override
  String get messageHintExample => 'z. B. „Dein Geldbeutel braucht eine Pause!“';

  @override
  String get sendReminder => 'Erinnerung senden';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Bitte warte 24 Stunden, bevor du $name erneut erinnerst';
  }

  @override
  String reminderSentToName(String name) {
    return 'Erinnerung an $name gesendet! 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'Erinnerung konnte nicht gesendet werden. Bitte versuche es erneut.';

  @override
  String get income => 'Einkommen';

  @override
  String get addIncome => 'Einkommen hinzufügen';

  @override
  String get incomeAdded => 'Einkommen erfolgreich hinzugefügt';

  @override
  String get noIncome => 'Noch kein Einkommen';

  @override
  String get noIncomeDescription => 'Erfasse deine Einkünfte, um die finanzielle Gesundheit deines Haushalts zu verfolgen';

  @override
  String get totalIncome => 'Gesamteinkommen';

  @override
  String get monthToDate => 'Monat bis heute';

  @override
  String get yearToDate => 'YTD';

  @override
  String get failedToLoadIncome => 'Einkommen konnte nicht geladen werden';

  @override
  String get incomeAcknowledged => 'Einkommen bestätigt';

  @override
  String get acknowledge => 'Bestätigen';

  @override
  String get acknowledged => 'bestätigt';

  @override
  String get source => 'Quelle';

  @override
  String get sourceHint => 'z.B. Arbeitgeber, Kunde';

  @override
  String get me => 'Ich';

  @override
  String get partner => 'Partner';

  @override
  String get privacyScope => 'Datenschutz';

  @override
  String get privacyFull => 'Alle Details';

  @override
  String get privacyBalancesOnly => 'Nur Salden';

  @override
  String get privacyPrivate => 'Privat';

  @override
  String get privacyFullExplanation => 'Partner kann alle Details einschließlich Betrag, Quelle und Beschreibung sehen.';

  @override
  String get privacyBalancesOnlyExplanation => 'Partner kann dieses Einkommen in Summen sehen, aber nicht die Details (Quelle, Beschreibung ausgeblendet).';

  @override
  String get privacyPrivateExplanation => 'Nur du kannst dieses Einkommen sehen. Es trägt zu Haushaltssummen bei, aber Partner kann keine Details sehen.';

  @override
  String get incomeSalary => 'Gehalt';

  @override
  String get incomeFreelance => 'Freelance';

  @override
  String get incomeInvestment => 'Investition';

  @override
  String get incomeRefund => 'Rückerstattung';

  @override
  String get incomeGift => 'Geschenk';

  @override
  String get incomeBonus => 'Bonus';

  @override
  String get incomeRental => 'Mieteinnahmen';

  @override
  String get incomeOther => 'Sonstiges';

  @override
  String get goals => 'Ziele';

  @override
  String get createGoal => 'Ziel erstellen';

  @override
  String get goalCreated => 'Ziel erfolgreich erstellt';

  @override
  String get goalTitle => 'Zieltitel';

  @override
  String get enterGoalTitle => 'Zieltitel eingeben';

  @override
  String get pleaseEnterTitle => 'Bitte geben Sie einen Titel ein';

  @override
  String get pleaseEnterAmount => 'Bitte geben Sie einen Betrag ein';

  @override
  String get invalidAmount => 'Bitte einen gültigen Betrag über 0 eingeben';

  @override
  String get targetAmount => 'Zielbetrag';

  @override
  String get currentAmount => 'Aktueller Betrag';

  @override
  String get targetDate => 'Zieldatum';

  @override
  String get description => 'Beschreibung';

  @override
  String get descriptionHint => 'Optionale Notiz';

  @override
  String get savings => 'Ersparnisse';

  @override
  String get paydown => 'Tilgung';

  @override
  String get all => 'Alle';

  @override
  String get completed => 'Abgeschlossen';

  @override
  String get offTrack => 'Vom Kurs ab';

  @override
  String get onTrack => 'Auf Kurs';

  @override
  String get complete => 'abschließen';

  @override
  String get overallProgress => 'Gesamtfortschritt';

  @override
  String get totalGoals => 'Gesamte Ziele';

  @override
  String get noGoals => 'Noch keine Ziele. Erstelle dein erstes Ziel, um loszulegen!';

  @override
  String get noSavingsGoals => 'Noch keine Sparziele. Erstelle eines, um mit dem Sparen zu beginnen!';

  @override
  String get noPaydownGoals => 'Noch keine Tilgungsziele. Erstelle eines, um mit der Schuldenreduzierung zu beginnen!';

  @override
  String get goalAcknowledged => 'Ziel bestätigt';

  @override
  String get balancesOnly => 'Nur Salden';

  @override
  String get contribution => 'Beitrag';

  @override
  String get withdrawal => 'Abhebung';

  @override
  String get interest => 'Zinsen';

  @override
  String get adjustment => 'Anpassung';

  @override
  String get addContribution => 'Beitrag hinzufügen';

  @override
  String get contributionAmount => 'Beitragsbetrag';

  @override
  String get contributionType => 'Typ';

  @override
  String get contributionAdded => 'Beitrag erfolgreich hinzugefügt';
}
