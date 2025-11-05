// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'Ancora nessuna spesa';

  @override
  String get loginWelcomeBack => 'Bentornato';

  @override
  String get orContinueWithEmail => 'Oppure continua con l\'email';

  @override
  String get emailAddress => 'Indirizzo email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Password dimenticata?';

  @override
  String get signIn => 'Accedi';

  @override
  String get newToMoneko => 'Nuovo su Moneko?';

  @override
  String get createAccount => 'Crea account';

  @override
  String get resetYourPassword => 'Reimposta la tua password';

  @override
  String get email => 'Email';

  @override
  String get exampleEmail => 'tu@esempio.com';

  @override
  String get cancel => 'Annulla';

  @override
  String get sendResetLink => 'Invia link di reimpostazione';

  @override
  String get passwordResetEmailSent => 'Email di reimpostazione password inviata. Controlla la tua casella di posta.';

  @override
  String get enterValidEmail => 'Inserisci un indirizzo email valido';

  @override
  String passwordMinLength(int min) {
    return 'La password deve contenere almeno $min caratteri';
  }

  @override
  String fullNameMinLength(int min) {
    return 'Il nome completo deve contenere almeno $min caratteri';
  }

  @override
  String get createYourAccount => 'Crea il tuo account';

  @override
  String get fullName => 'Nome completo';

  @override
  String get createPassword => 'Crea una password';

  @override
  String get passwordComplexityRequirement => 'La password deve contenere almeno una lettera maiuscola, una minuscola e un numero';

  @override
  String get passwordRequirementShort => 'Password: 8+ caratteri con maiuscola, minuscola e numero';

  @override
  String get termsAgreement => 'Creando un account, accetti i nostri Termini di Servizio e l\'Informativa sulla Privacy';

  @override
  String get alreadyHaveAccount => 'Hai già un account?';

  @override
  String get signInLower => 'Accedi';

  @override
  String get verificationCodeSent => 'Codice di verifica inviato con successo';

  @override
  String get verifyYourEmail => 'Verifica la tua email';

  @override
  String verificationEmailSentTo(String email) {
    return 'Abbiamo inviato un codice di verifica a 6 cifre a $email';
  }

  @override
  String get enterCompleteCode => 'Inserisci il codice completo a 6 cifre';

  @override
  String get invalidVerificationCode => 'Codice di verifica non valido';

  @override
  String get verificationCodeExpired => 'Codice di verifica scaduto. Richiedine uno nuovo.';

  @override
  String get verifyEmail => 'Verifica email';

  @override
  String get didntReceiveTheCode => 'Non hai ricevuto il codice? Controlla la cartella spam o';

  @override
  String resendInSeconds(int seconds) {
    return 'rinvia tra ${seconds}s';
  }

  @override
  String get resendVerificationEmail => 'rinvia l\'email di verifica';

  @override
  String get continueWithGoogle => 'Continua con Google';

  @override
  String get signingInWithGoogle => 'Accesso con Google in corso...';

  @override
  String get error => 'Errore';

  @override
  String get anErrorOccurred => 'Si è verificato un errore';

  @override
  String get unknownError => 'Errore sconosciuto';

  @override
  String get goToHome => 'Vai alla Home';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ Pagamento riuscito! Verifica abbonamento in corso...';

  @override
  String get paymentFailed => 'Pagamento non riuscito';

  @override
  String get paymentCanceled => 'ℹ️ Pagamento annullato';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp verificato con successo!';

  @override
  String get settings => 'Impostazioni';

  @override
  String get enableNotificationsInSettings => 'Abilita le notifiche per Moneko nelle impostazioni del tuo dispositivo';

  @override
  String get appearance => 'Aspetto';

  @override
  String get darkMode => 'Modalità scura';

  @override
  String get notifications => 'Notifiche';

  @override
  String get pushNotifications => 'Notifiche push';

  @override
  String get receiveAlertsAndUpdates => 'Ricevi avvisi e aggiornamenti';

  @override
  String get language => 'Lingua';

  @override
  String get systemDefault => 'Predefinito di sistema';

  @override
  String get membership => 'Abbonamento';

  @override
  String get loading => 'Caricamento in corso...';

  @override
  String get failedToLoadMembership => 'Impossibile caricare l\'abbonamento';

  @override
  String get couldNotOpenMembershipPage => 'Impossibile aprire la pagina dell\'abbonamento';

  @override
  String get freePlan => 'Gratuito';

  @override
  String get freePlanStatus => 'Piano gratuito';

  @override
  String get lifetimePlan => 'A vita';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus Mensile';

  @override
  String get plusYearlyPlan => 'Plus Annuale';

  @override
  String get activeStatus => 'Attivo';

  @override
  String get activeLifetimeStatus => 'Attivo • A vita';

  @override
  String get canceledStatus => 'Annullato';

  @override
  String get pastDueStatus => 'Scaduto';

  @override
  String get trialStatus => 'In prova';

  @override
  String trialEndsInDays(int days) {
    return 'La prova termina tra $days giorni';
  }

  @override
  String get trialEnded => 'Periodo di prova terminato';

  @override
  String renewsInDays(int days) {
    return 'Si rinnova tra $days giorni';
  }

  @override
  String accessEndsInDays(int days) {
    return 'L\'accesso termina tra $days giorni';
  }

  @override
  String get subscriptionEnded => 'Abbonamento terminato';

  @override
  String get profile => 'Profilo';

  @override
  String get errorLoadingProfile => 'Errore nel caricamento del profilo';

  @override
  String get user => 'Utente';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp Connesso';

  @override
  String get logExpensesViaWhatsApp => 'Registra le spese tramite messaggi WhatsApp';

  @override
  String get connectWhatsApp => 'Connetti WhatsApp';

  @override
  String get newBadge => 'NOVITÀ';

  @override
  String get logExpensesInstantly => 'Registra le spese istantaneamente via chat';

  @override
  String get fast => 'Veloce';

  @override
  String get photo => 'Foto';

  @override
  String get autoSync => 'Sincronizzazione automatica';

  @override
  String get naturalLanguage => 'Linguaggio naturale';

  @override
  String get describeExpenseAutomatically => 'Descrivi la tua spesa. La registreremo automaticamente.';

  @override
  String get snapReceipt => 'Scatta la ricevuta';

  @override
  String get snapReceiptDescription => 'Scatta la ricevuta. L\'IA la estrarrà e registrerà.';

  @override
  String get previous => 'Precedente';

  @override
  String get next => 'Avanti';

  @override
  String get overview => 'Panoramica';

  @override
  String get activity => 'Attività';

  @override
  String get accountInformation => 'Informazioni account';

  @override
  String get userId => 'ID Utente';

  @override
  String get recentActivity => 'Attività recente';

  @override
  String get noActivityYet => 'Nessuna attività ancora';

  @override
  String get signOut => 'Esci';

  @override
  String get insights => 'Statistiche';

  @override
  String get runningTab => 'Corrente';

  @override
  String get day30Tab => '30 Giorni';

  @override
  String get longTermTab => 'Lungo Termine';

  @override
  String get scenarioTab => 'Scenario';

  @override
  String get runningAndDailyBalances => 'Saldi correnti e giornalieri';

  @override
  String get budgetVsSpentDescription => 'Budget vs Speso al giorno con saldo corrente cumulativo.';

  @override
  String get runningBalanceLegend => 'Saldo corrente';

  @override
  String get budgetLegend => 'Budget';

  @override
  String get spentLegend => 'Speso';

  @override
  String get runningBalanceGuide => 'Guida al saldo corrente';

  @override
  String get runningBalanceIntro => 'Pensa a questo grafico come al tuo coach finanziario personale. Vediamo cosa mostra e come usarlo.';

  @override
  String get day30LookAhead => 'Previsione a 30 giorni';

  @override
  String get projectedFromTrailing30Days => 'Proiezione basata sulle medie degli ultimi 30 giorni.';

  @override
  String get projectedSpendingLegend => 'Spesa prevista';

  @override
  String get peek30DaysAhead => 'Sguardo ai prossimi 30 giorni';

  @override
  String get day30ForecastIntro => 'Questa previsione usa l\'attività dell\'ultimo mese per ipotizzare come sarà il prossimo. Pensala come un bollettino meteo per il tuo portafoglio.';

  @override
  String get longTermProjection => 'Proiezione a lungo termine';

  @override
  String get basedOnHistoricalAverages => 'Basata sulle medie storiche; si aggiorna automaticamente con i tuoi dati.';

  @override
  String get month18ProjectionLegend => 'Proiezione a 18 mesi';

  @override
  String get your18MonthHorizon => 'Il tuo orizzonte a 18 mesi';

  @override
  String get longTermIntro => 'Questa proiezione unisce le tue abitudini costanti a moderate ipotesi di crescita, per mostrarti dove portano le scelte di oggi.';

  @override
  String get aiScenarioPlanning => 'Pianificazione Scenari (IA)';

  @override
  String get askAiFinancialAdvisor => 'Chiedi al tuo consulente finanziario IA se puoi permetterti una spesa futura';

  @override
  String get canI => 'Posso';

  @override
  String get before => 'prima del';

  @override
  String get beforePrefix => 'prima del';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Scegli data';

  @override
  String get check => 'Controlla';

  @override
  String get enterQuestionAndPickDate => 'Inserisci una domanda e scegli una data';

  @override
  String get analyzingScenario => 'Analisi dello scenario in corso...';

  @override
  String get thisMightTakeAWhile => 'Potrebbe volerci un po\' di tempo';

  @override
  String get whereTheMoneyWent => 'Dove sono finiti i soldi';

  @override
  String get categoryTotalsForSelectedRange => 'Totali di categoria per l\'intervallo selezionato.';

  @override
  String get scenarioCategoriesGuide => 'Comprendere le categorie';

  @override
  String get categoryGuideIntro => 'Pensa a questo grafico come a una vista a volo d\'uccello di dove è volato ogni euro. Ecco come leggerlo senza bisogno di una calcolatrice.';

  @override
  String get readTheBarChartLikeAPro => 'Leggi il grafico a barre come un professionista';

  @override
  String get categoryChartDesc => 'Suddivisione per categoria per il periodo selezionato.';

  @override
  String get whyThisViewIsHelpful => 'Perché questa vista è utile';

  @override
  String get categoryWhyHelpfulDesc => 'Identifica rapidamente le tue maggiori categorie di spesa e individua le tendenze nel tempo.';

  @override
  String get whatToDoWithTheInsight => 'Cosa fare con queste informazioni';

  @override
  String get categoryWhatToDoDesc => 'Usa queste informazioni per regolare il tuo budget e le tue abitudini di spesa.';

  @override
  String get scenarioAnalysis => 'Analisi dello scenario';

  @override
  String get target => 'Obiettivo';

  @override
  String get quickStats => 'Statistiche rapide';

  @override
  String get currentBalance => 'Saldo attuale';

  @override
  String get projectedNoChange => 'Proiezione (Nessuna modifica)';

  @override
  String get avgDailyNet => 'Netto medio giornaliero';

  @override
  String get noDataAvailable => 'Nessun dato disponibile';

  @override
  String get day => 'Giorno';

  @override
  String get close => 'Chiudi';

  @override
  String get done => 'Fatto';

  @override
  String get whatYouAreSeeing => 'Cosa stai vedendo';

  @override
  String get whyItMatters => 'Perché è importante';

  @override
  String get howToRespond => 'Come reagire';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Il tuo saldo corrente tiene traccia di quanto margine hai dopo ogni giorno di spesa. Le barre giornaliere mostrano ciò che hai pianificato rispetto a ciò che hai speso realmente.';

  @override
  String get runningBalanceWhyMattersDesc => 'Consideralo un controllo amichevole. Ti aiuta a notare quando sei in vantaggio sul piano per continuare a investire, o quando una correzione di rotta ti manterrà in carreggiata.';

  @override
  String get runningBalanceHowToRespondDesc => 'Usa il grafico come un coach. Celebra i guadagni, reimposta le aspettative quando necessario e concediti un po\' di flessibilità: si tratta di progressi costanti, non di perfezione.';

  @override
  String get whatTheForecastShows => 'Cosa mostra la previsione';

  @override
  String get day30WhatShowsDesc => 'Uniamo le spese e le entrate degli ultimi 30 giorni per tracciare una settimana media futura. Smussa le spese occasionali per mostrarti il ritmo abituale.';

  @override
  String get day30WhyMattersDesc => 'I budget previsionali ti aiutano a rimanere proattivo. Vedere in anticipo le giornate dispendiose ti permette di mettere da parte i soldi invece di affannarti dopo.';

  @override
  String get day30HowToPlaySmartDesc => 'Prendilo come un suggerimento amichevole, non come un rigido manuale di regole. Modifica il tuo piano con piccole mosse che sembrano fattibili.';

  @override
  String get howTheProjectionWorks => 'Come funziona la proiezione';

  @override
  String get longTermHowWorksDesc => 'Sviluppiamo le tue entrate e spese medie, aggiungendo una modesta crescita, così puoi vedere se il tuo piano mantiene la liquidità confortevole nei mesi a venire.';

  @override
  String get longTermWhyMattersDesc => 'Orizzonti lunghi rendono reali i grandi sogni. Vedi se il tuo fondo di emergenza, investimenti o grandi acquisti rimangono in carreggiata.';

  @override
  String get longTermMovesToConsiderDesc => 'Usa il grafico per provare decisioni future. Piccoli aggiustamenti oggi si trasformano in grandi vittorie domani.';

  @override
  String get forMe => 'Per me';

  @override
  String get forUs => 'Per noi';

  @override
  String get home => 'Home';

  @override
  String get reminder => 'Promemoria';

  @override
  String get analyzingReceipt => 'Analisi ricevuta in corso...';

  @override
  String get analyzingExpense => 'Analisi spesa in corso...';

  @override
  String get noExpenseInformationExtracted => 'Nessuna informazione sulla spesa estratta';

  @override
  String get failedToAnalyzeNoData => 'Analisi fallita: Nessun dato restituito';

  @override
  String get failedToAnalyze => 'Analisi fallita';

  @override
  String get updateBudget => 'Aggiorna budget';

  @override
  String get enterNewTotalDailyBudget => 'Inserisci il nuovo budget giornaliero totale.';

  @override
  String get budgetAmount => 'Importo budget';

  @override
  String get save => 'Salva';

  @override
  String get enterValidAmountGreaterThan0 => 'Inserisci un importo valido maggiore di 0';

  @override
  String get updatingBudget => 'Aggiornamento budget in corso...';

  @override
  String get budgetUpdated => 'Budget aggiornato';

  @override
  String get failedToUpdateBudget => 'Impossibile aggiornare il budget';

  @override
  String get loggedSuccessfully => 'Registrato con successo';

  @override
  String get view => 'Visualizza';

  @override
  String get retry => 'Riprova';

  @override
  String get failedToCapturePhoto => 'Impossibile scattare la foto';

  @override
  String get noSpendingData => 'Nessun dato di spesa';

  @override
  String get byCategory => 'Per categoria';

  @override
  String get noExpensesYet => 'Ancora nessuna spesa';

  @override
  String get startLoggingExpensesToSeeCategories => 'Inizia a registrare le spese per vedere le categorie';

  @override
  String get selectDateRange => 'Seleziona intervallo di date';

  @override
  String get addExpense => 'Aggiungi spesa';

  @override
  String get describeYourExpense => 'Descrivi la tua spesa (es: \"5 per hamburger, 3 per caffè\")';

  @override
  String get enterExpenseDetails => 'Inserisci i dettagli della spesa...';

  @override
  String get freeFormText => 'Testo libero';

  @override
  String get takePhoto => 'Scatta Foto';

  @override
  String get transactions => 'Transazioni';

  @override
  String get negative => 'Negativo';

  @override
  String get positive => 'Positivo';

  @override
  String get spendingBreakdown => 'Suddivisione spesa';

  @override
  String get spent => 'Spesi';

  @override
  String get today => 'Oggi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get thisWeek => 'Questa settimana';

  @override
  String get lastWeek => 'Settimana scorsa';

  @override
  String get thisMonth => 'Questo mese';

  @override
  String get last30Days => 'Ultimi 30 giorni';

  @override
  String get customRange => 'Intervallo personalizzato';

  @override
  String get spentToday => 'Le tue spese di oggi';

  @override
  String get spentYesterday => 'Le tue spese di ieri';

  @override
  String get spentThisWeek => 'Le tue spese di questa settimana';

  @override
  String get spentLastWeek => 'Le tue spese della settimana scorsa';

  @override
  String get spentThisMonth => 'Le tue spese di questo mese';

  @override
  String get spentLast30Days => 'Le tue spese (ultimi 30 giorni)';

  @override
  String get spentCustom => 'Spesi (personalizzato)';

  @override
  String get todaysBudget => 'Budget di oggi';

  @override
  String get yesterdaysBudget => 'Budget di ieri';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Somma dei budget giornalieri questa settimana';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Somma dei budget giornalieri settimana scorsa';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Somma dei budget giornalieri questo mese';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Somma dei budget giornalieri negli ultimi 30 giorni';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Somma dei budget giornalieri per l\'intervallo selezionato';

  @override
  String get netCashflowToday => 'Flusso di cassa netto oggi';

  @override
  String get netCashflowYesterday => 'Flusso di cassa netto ieri';

  @override
  String get netCashflowThisWeek => 'Flusso di cassa netto questa settimana';

  @override
  String get netCashflowLastWeek => 'Flusso di cassa netto settimana scorsa';

  @override
  String get netCashflowThisMonth => 'Flusso di cassa netto questo mese';

  @override
  String get netCashflowLast30Days => 'Flusso di cassa netto (ultimi 30 giorni)';

  @override
  String get netCashflowCustom => 'Flusso di cassa netto (personalizzato)';

  @override
  String get selectCurrency => 'Seleziona valuta';

  @override
  String get showLessCurrencies => 'Mostra meno valute';

  @override
  String showAllCurrencies(int count) {
    return 'Mostra tutte le valute ($count in più)';
  }

  @override
  String get budget => 'Budget';

  @override
  String get spentLabel => 'Spesi';

  @override
  String get net => 'Netto';

  @override
  String get txn => 'trans.';

  @override
  String get txns => 'trans.';

  @override
  String get pleaseEnterExpenseDetails => 'Inserisci i dettagli della spesa';

  @override
  String get userNotLoggedIn => 'Utente non autenticato';

  @override
  String get errorLoadingHouseholds => 'Errore nel caricamento dei Gruppi';

  @override
  String get welcomeToHouseholds => 'Benvenuto in Gruppi';

  @override
  String get householdsDescription => 'Gestisci le finanze condivise con la tua famiglia, partner o coinquilini. Tieni traccia dei budget, dividi le spese e collaborate sulle decisioni finanziarie.';

  @override
  String get createHousehold => 'Crea Gruppo';

  @override
  String get joinWithInvite => 'Unisciti con Invito';

  @override
  String get pleaseUseInvitationLink => 'Usa un link d\'invito per unirti a un gruppo';

  @override
  String get householdName => 'Nome del Gruppo';

  @override
  String get householdNameHint => 'es. I Rossi, Casa Via Roma';

  @override
  String get pleaseEnterHouseholdName => 'Inserisci un nome per il gruppo';

  @override
  String get errorCreatingHousehold => 'Errore nella creazione del gruppo';

  @override
  String get householdsFeature => 'Funzione Gruppi';

  @override
  String get householdsFeatureDescription => 'La funzione Gruppi è ora disponibile! Gestisci le finanze condivise con famiglia, partner o coinquilini.';

  @override
  String get gotIt => 'Ho capito!';

  @override
  String get confirmExpense => 'Conferma spesa';

  @override
  String get expenseDetails => 'Dettagli spesa';

  @override
  String get details => 'Dettagli';

  @override
  String get category => 'Categoria';

  @override
  String get currency => 'Valuta';

  @override
  String get date => 'Data';

  @override
  String get time => 'Ora';

  @override
  String get notes => 'Note';

  @override
  String get receipt => 'Ricevuta';

  @override
  String get saveExpense => 'Salva spesa';

  @override
  String get shareWithHousehold => 'Condividi con nucleo familiare';

  @override
  String get loadingHouseholdMembers => 'Caricamento membri del gruppo...';

  @override
  String get selectHouseholdToConfigureSplit => 'Seleziona un gruppo per configurare la divisione';

  @override
  String get currencyManagedByHousehold => 'La valuta è gestita dal gruppo e non può essere modificata';

  @override
  String get currencyCannotBeChanged => 'La valuta non può essere modificata quando si condivide con un gruppo';

  @override
  String get failedToLoadImage => 'Impossibile caricare l\'immagine';

  @override
  String get editAmount => 'Modifica importo';

  @override
  String get amount => 'Importo';

  @override
  String get editNotes => 'Modifica note';

  @override
  String get addANote => 'Aggiungi una nota...';

  @override
  String get noMembersFoundInHousehold => 'Nessun membro trovato nel gruppo';

  @override
  String get errorLoadingMembers => 'Errore nel caricamento dei membri';

  @override
  String get noExpenseToSave => 'Nessuna spesa da salvare';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'Spesa salvata e condivisa$splitInfo!';
  }

  @override
  String get expenseSaved => 'Spesa salvata!';

  @override
  String failedToSave(String error) {
    return 'Salvataggio non riuscito: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Sincronizzazione preferenza valuta non riuscita: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Valuta aggiornata con successo';

  @override
  String retryFailed(Object error) {
    return 'Nuovo tentativo fallito: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'Ho speso $currencySymbol$amount per $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Inserisci il nuovo budget giornaliero totale.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Accedi per usare le funzioni del gruppo';

  @override
  String get quickActions => 'Azioni rapide';

  @override
  String get members => 'Membri';

  @override
  String get invites => 'Inviti';

  @override
  String get errorLoadingExpenses => 'Errore nel caricamento delle spese';

  @override
  String get budgets => 'Budget';

  @override
  String get loadingHousehold => 'Caricamento gruppo in corso...';

  @override
  String get remaining => 'Rimanente';

  @override
  String get overBudget => 'Fuori budget';

  @override
  String get sharedBudgets => 'Budget condivisi';

  @override
  String get netPosition => 'Posizione netta';

  @override
  String get spentByHousehold => 'Spese del Gruppo';

  @override
  String get memberSpending => 'Spese per Membro';

  @override
  String get spentByHouseholdTooltip => 'Questo mostra l\'importo totale speso da tutti i membri del gruppo durante il periodo selezionato. Include tutte le spese condivise registrate da qualsiasi membro del gruppo.';

  @override
  String get manageMoneyTogether => 'Gestite i soldi insieme al vostro partner, famiglia o coinquilini in un unico spazio condiviso.';

  @override
  String get sharedBudgetsExpenses => 'Budget e Spese Condivisi';

  @override
  String get sharedBudgetsExpensesDesc => 'Impostate budget, monitorate le spese e vedete dove vanno i soldi del gruppo in tempo reale.';

  @override
  String get smartExpenseSplitting => 'Divisione Intelligente delle Spese';

  @override
  String get smartExpenseSplittingDesc => 'Calcola automaticamente chi deve cosa con opzioni di divisione flessibili: equa, percentuale o importi personalizzati.';

  @override
  String get stayInSync => 'Rimanete Sincronizzati';

  @override
  String get stayInSyncDesc => 'Ricevi notifiche quando vengono aggiunte spese, raggiunti i budget o le divisioni devono essere saldate.';

  @override
  String get householdSettings => 'Impostazioni del Gruppo';

  @override
  String get householdNotFound => 'Gruppo non trovato';

  @override
  String get coverPhoto => 'Immagine di copertina';

  @override
  String get changeCoverPhoto => 'Cambia immagine di copertina';

  @override
  String get saveChanges => 'Salva modifiche';

  @override
  String get errorLoadingHousehold => 'Errore nel caricamento del gruppo';

  @override
  String get householdUpdatedSuccessfully => 'Gruppo aggiornato con successo';

  @override
  String get failedToUpdateHousehold => 'Impossibile aggiornare il gruppo';

  @override
  String get inviteMember => 'Invita membro';

  @override
  String get removeMember => 'Rimuovi membro';

  @override
  String get remove => 'Rimuovi';

  @override
  String get confirmRemoveMember => 'Sei sicuro di voler rimuovere';

  @override
  String get updatedMemberRole => 'Ruolo aggiornato';

  @override
  String get unknown => 'Sconosciuto';

  @override
  String get makeAdmin => 'Rendi amministratore';

  @override
  String get makeMember => 'Rendi membro';

  @override
  String get invitations => 'Inviti';

  @override
  String get errorLoadingInvites => 'Errore nel caricamento degli inviti';

  @override
  String get createInvitation => 'Crea invito';

  @override
  String get pendingInvitations => 'Inviti in sospeso';

  @override
  String get noPendingInvitations => 'Nessun invito in sospeso';

  @override
  String get invitationHistory => 'Cronologia inviti';

  @override
  String get noInvitationHistory => 'Nessuna cronologia inviti';

  @override
  String get emailOptional => 'Email (opzionale)';

  @override
  String get friendEmailExample => 'amico@esempio.com';

  @override
  String get personalMessageOptional => 'Messaggio personale (opzionale)';

  @override
  String get joinHouseholdBudget => 'Unisciti al nostro budget di gruppo!';

  @override
  String get expiresIn => 'Scade tra';

  @override
  String get oneDay => '1 giorno';

  @override
  String get threeDays => '3 giorni';

  @override
  String get sevenDays => '7 giorni';

  @override
  String get fourteenDays => '14 giorni';

  @override
  String get thirtyDays => '30 giorni';

  @override
  String get unlimited => 'Illimitato';

  @override
  String get create => 'Crea';

  @override
  String get invitationCreatedSuccessfully => 'Invito creato con successo';

  @override
  String get inviteLinkCopiedToClipboard => 'Link d\'invito copiato negli appunti!';

  @override
  String get errorCreatingInvite => 'Errore nella creazione dell\'invito';

  @override
  String get revokeInvitation => 'Revoca invito';

  @override
  String get confirmRevokeInvitation => 'Sei sicuro di voler revocare questo invito?';

  @override
  String get revoke => 'Revoca';

  @override
  String get invitationRevoked => 'Invito revocato';

  @override
  String get errorRevokingInvite => 'Errore nella revoca dell\'invito';

  @override
  String get anyoneWithLink => 'Chiunque abbia il link';

  @override
  String get noExpiry => 'Nessuna scadenza';

  @override
  String get expired => 'Scaduto';

  @override
  String get expires => 'Scade';

  @override
  String get copyLink => 'Copia link';

  @override
  String get selectCoverImage => 'Seleziona immagine di copertina';

  @override
  String get failedToLoadImages => 'Impossibile caricare le immagini';

  @override
  String get chooseFromGallery => 'Scegli dalla Galleria';

  @override
  String get failedToLoad => 'Impossibile caricare';

  @override
  String get imageTooLarge => 'Immagine troppo grande';

  @override
  String get maxIs => 'Il massimo è';

  @override
  String get unsupportedFileFormat => 'Formato file non supportato. Usa JPG, PNG o WebP.';

  @override
  String get cropCoverImage => 'Ritaglia immagine di copertina';

  @override
  String get editBudget => 'Modifica budget';

  @override
  String get budgetDetails => 'Dettagli budget';

  @override
  String get budgetName => 'Nome budget';

  @override
  String get period => 'Periodo';

  @override
  String get alertThresholds => 'Soglie di avviso';

  @override
  String get warningThreshold => 'Soglia di attenzione (%)';

  @override
  String get alertThreshold => 'Soglia di allarme (%)';

  @override
  String get warningThresholdHelper => 'Avvisa quando l\'uso del budget raggiunge questa percentuale';

  @override
  String get alertThresholdHelper => 'Allarme critico a questa percentuale';

  @override
  String get budgetStatus => 'Stato budget';

  @override
  String get active => 'Attivo';

  @override
  String get inactive => 'Inattivo';

  @override
  String get deletingBudget => 'Eliminazione budget in corso...';

  @override
  String get savingChanges => 'Salvataggio modifiche in corso...';

  @override
  String get budgetNameCannotBeEmpty => 'Il nome del budget non può essere vuoto';

  @override
  String get pleaseEnterValidAmount => 'Inserisci un importo valido';

  @override
  String get warningThresholdRange => 'La soglia di attenzione deve essere tra 0 e 100';

  @override
  String get alertThresholdRange => 'La soglia di allarme deve essere tra 0 e 100';

  @override
  String get warningThresholdLessThanAlert => 'La soglia di attenzione deve essere inferiore o uguale alla soglia di allarme';

  @override
  String get deleteBudget => 'Elimina budget';

  @override
  String get confirmDeleteBudget => 'Sei sicuro di voler eliminare';

  @override
  String get thisActionCannotBeUndone => 'Questa azione non può essere annullata';

  @override
  String get budgetUpdatedSuccessfully => 'Budget aggiornato con successo';

  @override
  String get budgetDeletedSuccessfully => 'Budget eliminato con successo';

  @override
  String get categoryTransfers => 'Trasferimenti';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryUtilities => 'Utenze';

  @override
  String get categoryEntertainment => 'Intrattenimento';

  @override
  String get categoryEntertainmentSubscriptions => 'Abbonamenti Intrattenimento';

  @override
  String get categoryRestaurants => 'Ristoranti';

  @override
  String get categoryFood => 'Cibo';

  @override
  String get categoryGroceries => 'Spesa';

  @override
  String get categoryTransport => 'Trasporti';

  @override
  String get categoryTransportation => 'Trasporti';

  @override
  String get categoryTravel => 'Viaggi';

  @override
  String get categoryFlights => 'Voli';

  @override
  String get categoryVacation => 'Vacanza';

  @override
  String get categoryHealth => 'Salute';

  @override
  String get categoryMedical => 'Spese mediche';

  @override
  String get categoryText => 'Testo';

  @override
  String get categoryEducation => 'Istruzione';

  @override
  String get categoryTuition => 'Tasse scolastiche';

  @override
  String get categorySubscriptions => 'Abbonamenti';

  @override
  String get categoryServices => 'Servizi';

  @override
  String get categoryHousing => 'Casa';

  @override
  String get categoryRent => 'Affitto';

  @override
  String get categoryMortgage => 'Mutuo';

  @override
  String get categoryBills => 'Bollette';

  @override
  String get categoryInsurance => 'Assicurazione';

  @override
  String get categorySavings => 'Risparmi';

  @override
  String get categoryInvestment => 'Investimento';

  @override
  String get categoryInvestments => 'Investimenti';

  @override
  String get categoryIncome => 'Entrate';

  @override
  String get categorySalary => 'Stipendio';

  @override
  String get categoryBonus => 'Bonus';

  @override
  String get categoryPets => 'Animali domestici';

  @override
  String get categoryKids => 'Figli';

  @override
  String get categoryFamily => 'Famiglia';

  @override
  String get categoryGifts => 'Regali';

  @override
  String get categoryCharity => 'Beneficenza';

  @override
  String get categoryFees => 'Commissioni';

  @override
  String get categoryLoan => 'Prestito';

  @override
  String get categoryLoans => 'Prestiti';

  @override
  String get categoryDebt => 'Debiti';

  @override
  String get categoryPersonalCare => 'Cura personale';

  @override
  String get categoryBeauty => 'Bellezza';

  @override
  String get categoryMisc => 'Altro';

  @override
  String get categoryUncategorized => 'Non categorizzato';

  @override
  String get deleteBudgetCannotBeUndone => 'Questa azione non può essere annullata';

  @override
  String get delete => 'Elimina';

  @override
  String get failedToDeleteBudget => 'Impossibile eliminare il budget';

  @override
  String get owner => 'Proprietario';

  @override
  String get admin => 'Admin';

  @override
  String get member => 'Membro';

  @override
  String get pending => 'In sospeso';

  @override
  String get accepted => 'Accettato';

  @override
  String get revoked => 'Revocato';

  @override
  String get tapToChangeCover => 'Tocca per cambiare copertina';

  @override
  String get personalMessageHint => 'Scrivi qualcosa ai tuoi invitati (es. \"Ehi! Entra nel nostro gruppo per le spese di casa!\")';

  @override
  String get invitationExpiresIn => 'L\'invito scade tra';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'i',
      one: '',
    );
    return '$days giorno$_temp0';
  }

  @override
  String get createHouseholdDescription => 'Crea uno spazio condiviso per monitorare budget e spese con famiglia o coinquilini.';

  @override
  String get uploadingImage => 'Caricamento immagine...';

  @override
  String get creating => 'Creazione in corso...';

  @override
  String get generatingInvite => 'Generazione invito in corso...';

  @override
  String get pleaseSelectValidCurrency => 'Seleziona una valuta valida per il gruppo';

  @override
  String nameMaxLength(int max) {
    return 'Il nome deve avere meno di $max caratteri';
  }

  @override
  String get createHouseholdPage => 'Pagina di creazione gruppo';

  @override
  String get invitationPersonalMessageInput => 'Input messaggio personale invito';

  @override
  String get householdNameInput => 'Input nome gruppo';

  @override
  String get invitationExpirationSelector => 'Selettore scadenza invito';

  @override
  String get unlimitedExpiration => 'Scadenza illimitata';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'i',
      one: '',
    );
    return 'scadenza $days giorno$_temp0';
  }

  @override
  String get householdInformation => 'Informazioni sul gruppo';

  @override
  String get creatingHousehold => 'Creazione gruppo in corso';

  @override
  String get createHouseholdButton => 'Pulsante crea gruppo';

  @override
  String get searchExpenses => 'Cerca spese...';

  @override
  String get clearAll => 'Cancella tutto';

  @override
  String get allCategories => 'Tutte le categorie';

  @override
  String get allMembers => 'Tutti i membri';

  @override
  String get balanceSummary => 'Riepilogo saldi';

  @override
  String get youAreOwed => 'Ti devono';

  @override
  String get youOwe => 'Devi';

  @override
  String get youOweOthers => 'Devi agli altri';

  @override
  String get othersOweYou => 'Gli altri ti devono';

  @override
  String get viewDetails => 'Vedi dettagli';

  @override
  String get settleUp => 'Salda i conti';

  @override
  String get markExpensesAsSettled => 'Segna le spese come saldate per aggiornare i saldi';

  @override
  String get whoAreYouSettlingWith => 'Con chi stai saldando i conti?';

  @override
  String get selectMember => 'Seleziona membro';

  @override
  String get amountToSettle => 'Importo da saldare';

  @override
  String get howDidYouSettle => 'Come hai saldato?';

  @override
  String get cash => 'Contanti';

  @override
  String get paidInCash => 'Pagato in contanti';

  @override
  String get bankTransfer => 'Bonifico bancario';

  @override
  String get transferredViaBank => 'Trasferito via banca';

  @override
  String get mobilePayment => 'Pagamento mobile';

  @override
  String get venmoPaypalEtc => 'Satispay, PayPal, ecc.';

  @override
  String get search => 'Cerca';

  @override
  String get noData => 'Nessun dato';

  @override
  String get filterTransactions => 'Filtra transazioni';

  @override
  String get noTransactionsFound => 'Nessuna transazione trovata';

  @override
  String get failedToLoadHouseholdTransactions => 'Impossibile caricare le transazioni del gruppo';

  @override
  String get reset => 'Reimposta';

  @override
  String get apply => 'Applica';

  @override
  String get expenses => 'Spese';

  @override
  String get dateRange => 'Intervallo di date';

  @override
  String get noMatchingExpenses => 'Nessuna spesa corrispondente';

  @override
  String get startLoggingExpenses => 'Inizia a registrare le spese per vederle qui';

  @override
  String get tryAdjustingFilters => 'Prova a modificare i filtri';

  @override
  String get split => 'Dividi';

  @override
  String get note => 'Nota';

  @override
  String get currencyCannotBeChangedWhenSharing => 'La valuta non può essere modificata quando si condivide con una famiglia';

  @override
  String get createBudget => 'Crea budget';

  @override
  String get pleaseEnterABudgetName => 'Inserisci un nome per il budget';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Inserisci un importo valido superiore a 0';

  @override
  String get warningThresholdMustBeBetween0And100 => 'La soglia di attenzione deve essere tra 0 e 100%';

  @override
  String get alertThresholdMustBeBetween0And100 => 'La soglia di allarme deve essere tra 0 e 100%';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'La soglia di attenzione deve essere inferiore o uguale a quella di allarme';

  @override
  String get budgetCreatedSuccessfully => 'Budget creato con successo!';

  @override
  String get failedToCreateBudget => 'Impossibile creare il budget';

  @override
  String get groceriesRentEntertainment => 'es. Spesa, Affitto, Intrattenimento';

  @override
  String get budgetType => 'Tipo di budget';

  @override
  String get sharedWithAllHouseholdMembers => 'Condiviso con tutti i membri della famiglia';

  @override
  String get personalBudgetForYourExpensesOnly => 'Budget personale solo per le tue spese';

  @override
  String get countSplitPortionOnly => 'Conta solo la tua quota divisa';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Conta solo la tua parte delle spese divise in questo budget';

  @override
  String get joinHousehold => 'Unisciti alla famiglia';

  @override
  String get joinAHousehold => 'Unisciti a una famiglia';

  @override
  String get enterYourInvitationLinkToJoin => 'Inserisci il tuo link d\'invito per unirti\na uno spazio finanziario condiviso';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Incolla il link d\'invito che hai ricevuto da un membro del gruppo';

  @override
  String get pasteInvitationLink => 'Incolla link d\'invito';

  @override
  String get pleaseEnterAnInvitationLink => 'Inserisci un link d\'invito';

  @override
  String get pleaseEnterAValidInvitationLink => 'Inserisci un link d\'invito valido';

  @override
  String get paste => 'Incolla';

  @override
  String get validating => 'Convalida in corso...';

  @override
  String get continueAction => 'Continua';

  @override
  String get welcomeAboard => 'Benvenuto a bordo!';

  @override
  String get youreNowPartOfTheHousehold => 'Ora fai parte del gruppo.\nInizia a collaborare sulle vostre finanze!';

  @override
  String get thisWillOnlyTakeAMoment => 'Ci vorrà solo un momento';

  @override
  String get unableToJoin => 'Impossibile unirsi';

  @override
  String get tryAgain => 'Riprova';

  @override
  String get goToHousehold => 'Vai al Gruppo';

  @override
  String get expiresSoon => 'Scade a breve';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Invito valido fino al $formattedDate';
  }

  @override
  String get whatYoullGet => 'Cosa otterrai';

  @override
  String get viewSharedBudgetsAndExpenses => 'Visualizza budget e spese condivisi';

  @override
  String get trackHouseholdFinancialHealth => 'Monitora la salute finanziaria del gruppo';

  @override
  String get collaborateOnFinancialDecisions => 'Collabora sulle decisioni finanziarie';

  @override
  String get household => 'Nucleo familiare';

  @override
  String get viewAll => 'Vedi tutti';

  @override
  String get manage => 'Gestisci';

  @override
  String get noBudgetsYet => 'Nessun budget ancora';

  @override
  String get createSharedBudgetDescription => 'Crea un budget condiviso per monitorare le spese insieme';

  @override
  String get errorLoadingBudgets => 'Errore nel caricamento dei budget';

  @override
  String get recentSplits => 'Divisioni recenti';

  @override
  String get invite => 'Invita';

  @override
  String get last6Months => 'Ultimi 6 mesi';

  @override
  String get thisYear => 'Quest\'anno';

  @override
  String get allTime => 'Sempre';

  @override
  String nameMinLength(int min) {
    return 'Il nome deve contenere almeno $min caratteri';
  }

  @override
  String get splitExpense => 'Dividi spesa';

  @override
  String get percent => 'Percentuale';

  @override
  String get splitShare => 'Quota';

  @override
  String get owes => 'Deve';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'Il totale diviso deve essere $currency$amount';
  }

  @override
  String get percentagesMustTotal100 => 'Le percentuali devono sommarsi al 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'Ogni persona deve avere almeno 1 quota';

  @override
  String get whatsappVerified => 'WhatsApp Verificato';

  @override
  String get whatsappVerification => 'Verifica WhatsApp';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Il tuo numero WhatsApp è collegato con successo al tuo account';

  @override
  String get verifyingYourWhatsAppNumber => 'Verifica del tuo numero WhatsApp in corso...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Inserisci il codice a 6 cifre da WhatsApp';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Inserisci il codice di verifica a 6 cifre';

  @override
  String get failedToVerifyCode => 'Impossibile verificare il codice';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Impossibile verificare il codice. Riprova.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Codice compilato automaticamente dal link di verifica';

  @override
  String get verify => 'Verifica';

  @override
  String get verifying => 'Verifica in corso...';

  @override
  String get avatarStudio => 'Studio Avatar';

  @override
  String get preview => 'Anteprima';

  @override
  String get colors => 'Colori';

  @override
  String get randomize => 'Casuale';

  @override
  String get saveAvatar => 'Salva avatar';

  @override
  String get saving => 'Salvataggio...';

  @override
  String get skipForNow => 'Salta per ora';

  @override
  String get selectColor => 'Seleziona colore';

  @override
  String get failedToSaveAvatar => 'Impossibile salvare l\'avatar';

  @override
  String get hair => 'Capelli';

  @override
  String get eyes => 'Occhi';

  @override
  String get mouth => 'Bocca';

  @override
  String get background => 'Sfondo';

  @override
  String get face => 'Viso';

  @override
  String get ears => 'Orecchie';

  @override
  String get shirts => 'Magliette';

  @override
  String get brow => 'Sopracciglia';

  @override
  String get nose => 'Naso';

  @override
  String get blush => 'Fard';

  @override
  String get accessories => 'Accessori';

  @override
  String get stars => 'Stelle';

  @override
  String get currencyIsManagedByHousehold => 'La valuta è gestita dal gruppo e non può essere modificata';

  @override
  String get buyALaptop => 'comprare un portatile da 1.200 €';

  @override
  String get selectTargetDate => 'Seleziona data obiettivo';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'Posso $action prima del $date';
  }

  @override
  String get scenarioDateFormat => 'dd/MM/yyyy';

  @override
  String analysisFailed(String error) {
    return 'Analisi fallita: $error';
  }

  @override
  String get leftHandChamps => 'Le voci principali a sinistra sono i tuoi pesi massimi, candidati perfetti per una rapida revisione.';

  @override
  String get smallButFrequent => 'Le categorie piccole ma frequenti indicano abitudini che possono accumularsi nel tempo.';

  @override
  String get colorMatches => 'Il colore corrisponde a quello che vedi nella scheda Home, così il tuo cervello è a suo agio.';

  @override
  String get planningNewGoal => 'Stai pianificando un nuovo obiettivo? Individua le categorie da tagliare senza toccare quelle divertenti.';

  @override
  String get eyeingTreatYourself => 'Punti a un mese di coccole? Vedi quali aree possono flettersi in sicurezza.';

  @override
  String get doubleCheckTagging => 'Usalo per ricontrollare che le nuove spese siano state etichettate correttamente: nessun fantasma ammesso.';

  @override
  String get slideHighBar => 'Abbassa un po\' un\'asticella alta impostando un mini-limite o passando ad alternative a basso costo.';

  @override
  String get nonNegotiable => 'Se una barra non è negoziabile (ciao, affitto), pianifica intorno ad essa invece di combatterla.';

  @override
  String get revisitAfterScenario => 'Riguarda dopo aver eseguito uno scenario per vedere se le tue modifiche funzionano.';

  @override
  String get purpleLineCushion => 'Linea viola: il margine rimasto dopo ogni giorno. Le linee ascendenti significano che stai accumulando slancio.';

  @override
  String get blueBarsBudget => 'Barre blu: il budget che hai impostato per quel giorno.';

  @override
  String get redBarsSpent => 'Barre rosse: ciò che è effettivamente uscito dal tuo conto.';

  @override
  String get lineTrendingUpward => 'Linea tendente verso l\'alto = contanti extra che puoi reindirizzare verso obiettivi di risparmio.';

  @override
  String get flatDippingLine => 'Linea piatta o in calo = è ora di fermarsi e rivedere le spese importanti.';

  @override
  String get sharpDrops => 'Cali improvvisi spesso corrispondono ad acquisti non pianificati: toccali per ispezionare i dettagli.';

  @override
  String get lineRisingDays => 'La linea sale per diversi giorni? Considera di spostare un extra nei risparmi o nel pagamento dei debiti.';

  @override
  String get lineDippingWeekend => 'La linea scende dopo un weekend intenso? Riequilibra i giorni successivi tagliando piccole spese discrezionali.';

  @override
  String get feelStuckRed => 'Ti senti bloccato in rosso? Rivedi il tuo budget nella scheda Home: piccoli aggiustamenti si sommano rapidamente.';

  @override
  String get thirtyDayForecastDesc => 'Questa previsione usa l\'attività dell\'ultimo mese per ipotizzare come sarà il prossimo. Pensala come un bollettino meteo per il tuo portafoglio.';

  @override
  String get greenLineExpected => 'Linea verde = spesa giornaliera prevista se il prossimo mese si comporterà come l\'ultimo.';

  @override
  String get spikesHighlight => 'I picchi evidenziano settimane in cui le tue abitudini di solito diventano più costose (ciao, cibo d\'asporto del venerdì).';

  @override
  String get forecastUpdates => 'Quando registri nuove transazioni, la previsione si aggiorna delicatamente, non c\'è bisogno di ricaricare.';

  @override
  String get spotExpensivePatterns => 'Individua presto schemi costosi e metti da parte un mini-cuscinetto prima che arrivino.';

  @override
  String get catchQuieterWeeks => 'Cogli le settimane più tranquille in cui puoi spostare contanti extra nei risparmi o nel pagamento dei debiti.';

  @override
  String get timeRecurringPayments => 'Usa questa informazione per programmare pagamenti ricorrenti, abbonamenti o ricariche.';

  @override
  String get bigSpikeComing => 'Picco importante in arrivo? Prenota opzioni più economiche o sposta spese flessibili a giorni più calmi.';

  @override
  String get forecastDipping => 'Previsione in calo? Premiati programmando un trasferimento extra ai risparmi.';

  @override
  String get forecastLooksOff => 'Se la previsione sembra errata, rivedi le categorie nella scheda Home per sistemare eventuali etichette sbagliate.';

  @override
  String get greenLineTrends => 'La linea verde segue il tuo tipico tasso di risparmio: slancio verso l\'alto significa che i tuoi obiettivi sono finanziati.';

  @override
  String get lineDipsSignals => 'Se la linea scende, segnala mesi futuri in cui le spese tendono a superare le entrate.';

  @override
  String get largeGoalsDebts => 'Grandi obiettivi o debiti sono inclusi quando li etichetti nella scheda Home.';

  @override
  String get upwardSlope => 'Una pendenza verso l\'alto? Festeggia e considera di aumentare i risparmi per la pensione o per i viaggi.';

  @override
  String get flatSlipping => 'Piatta o in calo? È ora di regolare i budget o aumentare le entrate prima che l\'effetto valanga prenda il sopravvento.';

  @override
  String get watchSeasonalTrends => 'Osserva le tendenze stagionali: festività, trimestri scolastici o rinnovi annuali spesso si vedono qui per primi.';

  @override
  String get schedulePaymentIncreases => 'Programma leggeri aumenti di pagamento sui prestiti quando la curva sale.';

  @override
  String get planAheadDips => 'Pianifica in anticipo i cali accantonando fondi specifici o tagliando spese opzionali.';

  @override
  String get checkProjectionMonthly => 'Controlla la proiezione mensilmente per mantenere il tuo gioco a lungo termine divertente e flessibile.';

  @override
  String get categoryHealthcare => 'Salute';

  @override
  String get categoryOther => 'Altro';

  @override
  String get deleteExpense => 'Elimina Spesa';

  @override
  String get confirmDeleteExpense => 'Sei sicuro di voler eliminare questa spesa? Questa azione non può essere annullata.';

  @override
  String get expenseDeletedSuccessfully => 'Spesa eliminata con successo';

  @override
  String get failedToDeleteExpense => 'Impossibile eliminare la spesa';

  @override
  String get expenseNotFoundOrDeleted => 'Spesa non trovata o già eliminata';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Solo amministratori e proprietari possono modificare le impostazioni del nucleo familiare';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Solo amministratori e proprietari possono creare inviti';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Condividi l\'invito per il gruppo $householdName';
  }

  @override
  String get shareInvitation => 'Condividi invito';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Gruppo $householdName creato con successo';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'Gruppo \"$householdName\" creato con successo!';
  }

  @override
  String get invitationLink => 'Link di invito';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Link di invito: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Copia link di invito';

  @override
  String get copyInvitationLinkToClipboard => 'Copia link di invito negli appunti';

  @override
  String get shareInvitationLink => 'Condividi link di invito';

  @override
  String get share => 'Condividi';

  @override
  String get closeShareSheet => 'Chiudi pannello di condivisione';

  @override
  String get invitationLinkCopiedToClipboard => 'Link di invito copiato negli appunti!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Unisciti al mio gruppo \"$householdName\" su Moneko!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Unisciti al mio gruppo su Moneko';

  @override
  String get zeroAmount => '0,00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Impostazioni di notifica';

  @override
  String get budgetBoop => 'Bussatina budget';

  @override
  String get getGentleReminder => 'Ricevi un promemoria gentile quando raggiungi questa soglia';

  @override
  String get purrSuasiveNudge => 'Spintarella con fusa';

  @override
  String get getStrongerNudge => 'Ricevi una spinta più forte quando raggiungi questa soglia';

  @override
  String get createBudgetButton => 'Crea budget';

  @override
  String get daily => 'Giornaliero';

  @override
  String get weekly => 'Settimanale';

  @override
  String get monthly => 'Mensile';

  @override
  String get yearly => 'Annuale';

  @override
  String get householdBudgetType => 'Budget di gruppo';

  @override
  String get personalBudgetType => 'Budget personale';

  @override
  String joinHouseholdName(String householdName) {
    return 'Unisciti a \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Anteprima gruppo: $householdName, invitato da $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Invitato da $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'L\'invito è in scadenza il $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Invito valido fino al';

  @override
  String get personalMessageFromInviter => 'Messaggio personale dall\'invitante';

  @override
  String get messageFromInviter => 'Messaggio dall\'invitante';

  @override
  String get joiningHousehold => 'Unione al gruppo in corso...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Errore: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'Si è verificato un errore imprevisto';

  @override
  String get invalidInvitationLinkFormat => 'Formato link d\'invito non valido';

  @override
  String get invalidOrExpiredInvitation => 'Invito non valido o scaduto';

  @override
  String get tomorrow => 'Domani';

  @override
  String inDays(int days) {
    return 'tra $days giorni';
  }

  @override
  String get january => 'Gen';

  @override
  String get february => 'Feb';

  @override
  String get march => 'Mar';

  @override
  String get april => 'Apr';

  @override
  String get may => 'Mag';

  @override
  String get june => 'Giu';

  @override
  String get july => 'Lug';

  @override
  String get august => 'Ago';

  @override
  String get september => 'Set';

  @override
  String get october => 'Ott';

  @override
  String get november => 'Nov';

  @override
  String get december => 'Dic';

  @override
  String remindUser(String name) {
    return 'Ricorda a $name';
  }

  @override
  String get sendFriendlySpendingReminder => 'Invia un promemoria gentile sulle spese';

  @override
  String get addMessageOptional => 'Aggiungi un messaggio (opzionale)';

  @override
  String get messageHintExample => 'es.: «Il tuo portafoglio ha bisogno di riposo!»';

  @override
  String get sendReminder => 'Invia promemoria';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Attendi 24 ore prima di inviare un altro promemoria a $name';
  }

  @override
  String reminderSentToName(String name) {
    return 'Promemoria inviato a $name 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'Invio promemoria fallito. Riprova.';

  @override
  String get income => 'Reddito';

  @override
  String get addIncome => 'Aggiungi reddito';

  @override
  String get incomeAdded => 'Reddito aggiunto con successo';

  @override
  String get noIncome => 'Nessun reddito ancora';

  @override
  String get noIncomeDescription => 'Registra i tuoi redditi per monitorare la salute finanziaria del tuo nucleo familiare';

  @override
  String get totalIncome => 'Reddito totale';

  @override
  String get monthToDate => 'Mese a oggi';

  @override
  String get yearToDate => 'YTD';

  @override
  String get failedToLoadIncome => 'Caricamento reddito fallito';

  @override
  String get incomeAcknowledged => 'Reddito riconosciuto';

  @override
  String get acknowledge => 'Riconosci';

  @override
  String get acknowledged => 'riconosciuto';

  @override
  String get source => 'Fonte';

  @override
  String get sourceHint => 'es. Datore di lavoro, Cliente';

  @override
  String get me => 'Io';

  @override
  String get partner => 'Partner';

  @override
  String get privacyScope => 'Privacy';

  @override
  String get privacyFull => 'Dettagli completi';

  @override
  String get privacyBalancesOnly => 'Solo saldi';

  @override
  String get privacyPrivate => 'Privato';

  @override
  String get privacyFullExplanation => 'Il partner può vedere tutti i dettagli inclusi importo, fonte e descrizione.';

  @override
  String get privacyBalancesOnlyExplanation => 'Il partner può vedere questo reddito nei totali ma non i dettagli (fonte, descrizione nascosta).';

  @override
  String get privacyPrivateExplanation => 'Solo tu puoi vedere questo reddito. Contribuisce ai totali del nucleo familiare ma il partner non può vedere i dettagli.';

  @override
  String get incomeSalary => 'Stipendio';

  @override
  String get incomeFreelance => 'Freelance';

  @override
  String get incomeInvestment => 'Investimento';

  @override
  String get incomeRefund => 'Rimborso';

  @override
  String get incomeGift => 'Regalo';

  @override
  String get incomeBonus => 'Bonus';

  @override
  String get incomeRental => 'Affitto';

  @override
  String get incomeOther => 'Altro';

  @override
  String get goals => 'Obiettivi';

  @override
  String get createGoal => 'Crea obiettivo';

  @override
  String get goalCreated => 'Obiettivo creato con successo';

  @override
  String get goalTitle => 'Titolo obiettivo';

  @override
  String get enterGoalTitle => 'Inserisci titolo obiettivo';

  @override
  String get pleaseEnterTitle => 'Per favore inserisci un titolo';

  @override
  String get pleaseEnterAmount => 'Inserisci un importo';

  @override
  String get invalidAmount => 'Inserisci un importo valido maggiore di 0';

  @override
  String get targetAmount => 'Importo target';

  @override
  String get currentAmount => 'Importo attuale';

  @override
  String get targetDate => 'Data target';

  @override
  String get description => 'Descrizione';

  @override
  String get descriptionHint => 'Nota opzionale';

  @override
  String get savings => 'Risparmi';

  @override
  String get paydown => 'Estinzione';

  @override
  String get all => 'Tutti';

  @override
  String get completed => 'Completato';

  @override
  String get offTrack => 'Fuori traccia';

  @override
  String get onTrack => 'In traccia';

  @override
  String get complete => 'completa';

  @override
  String get overallProgress => 'progresso generale';

  @override
  String get totalGoals => 'Obiettivi totali';

  @override
  String get noGoals => 'Nessun obiettivo ancora. Crea il tuo primo obiettivo per iniziare!';

  @override
  String get noSavingsGoals => 'Nessun obiettivo di risparmio ancora. Creane uno per iniziare a risparmiare!';

  @override
  String get noPaydownGoals => 'Nessun obiettivo di estinzione ancora. Creane uno per iniziare a ridurre i debiti!';

  @override
  String get goalAcknowledged => 'Obiettivo riconosciuto';

  @override
  String get balancesOnly => 'Solo saldi';

  @override
  String get contribution => 'Contributo';

  @override
  String get withdrawal => 'Prelievo';

  @override
  String get interest => 'Interesse';

  @override
  String get adjustment => 'Aggiustamento';

  @override
  String get addContribution => 'Aggiungi contributo';

  @override
  String get contributionAmount => 'Importo contributo';

  @override
  String get contributionType => 'Tipo';

  @override
  String get contributionAdded => 'Contributo aggiunto con successo';
}
