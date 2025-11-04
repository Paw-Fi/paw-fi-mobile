// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'Nog geen uitgaven';

  @override
  String get loginWelcomeBack => 'Welkom terug';

  @override
  String get orContinueWithEmail => 'Of ga verder met e-mail';

  @override
  String get emailAddress => 'E-mailadres';

  @override
  String get password => 'Wachtwoord';

  @override
  String get forgotPassword => 'Wachtwoord vergeten?';

  @override
  String get signIn => 'Inloggen';

  @override
  String get newToMoneko => 'Nieuw bij Moneko?';

  @override
  String get createAccount => 'Account aanmaken';

  @override
  String get resetYourPassword => 'Stel je wachtwoord opnieuw in';

  @override
  String get email => 'E-mail';

  @override
  String get exampleEmail => 'jij@voorbeeld.nl';

  @override
  String get cancel => 'Annuleren';

  @override
  String get sendResetLink => 'Resetlink verzenden';

  @override
  String get passwordResetEmailSent => 'E-mail voor wachtwoordherstel verzonden. Check je inbox.';

  @override
  String get enterValidEmail => 'Voer een geldig e-mailadres in';

  @override
  String passwordMinLength(int min) {
    return 'Wachtwoord moet minimaal $min tekens lang zijn';
  }

  @override
  String fullNameMinLength(int min) {
    return 'Volledige naam moet minimaal $min tekens lang zijn';
  }

  @override
  String get createYourAccount => 'Maak je account aan';

  @override
  String get fullName => 'Volledige naam';

  @override
  String get createPassword => 'Maak een wachtwoord aan';

  @override
  String get passwordComplexityRequirement => 'Wachtwoord moet minimaal één hoofdletter, één kleine letter en één cijfer bevatten';

  @override
  String get passwordRequirementShort => 'Wachtwoord: 8+ tekens, met hoofdletter, kleine letter en cijfer';

  @override
  String get termsAgreement => 'Door een account aan te maken, ga je akkoord met onze Servicevoorwaarden en ons Privacybeleid';

  @override
  String get alreadyHaveAccount => 'Heb je al een account?';

  @override
  String get signInLower => 'Inloggen';

  @override
  String get verificationCodeSent => 'Verificatiecode succesvol verzonden';

  @override
  String get verifyYourEmail => 'Verifieer je e-mailadres';

  @override
  String verificationEmailSentTo(String email) {
    return 'We hebben een 6-cijferige verificatiecode gestuurd naar $email';
  }

  @override
  String get enterCompleteCode => 'Voer de volledige 6-cijferige code in';

  @override
  String get invalidVerificationCode => 'Ongeldige verificatiecode';

  @override
  String get verificationCodeExpired => 'Verificatiecode is verlopen. Vraag een nieuwe code aan.';

  @override
  String get verifyEmail => 'E-mail verifiëren';

  @override
  String get didntReceiveTheCode => 'Code niet ontvangen? Check je spamfolder of';

  @override
  String resendInSeconds(int seconds) {
    return 'opnieuw verzenden over $seconds sec.';
  }

  @override
  String get resendVerificationEmail => 'verificatiemail opnieuw verzenden';

  @override
  String get continueWithGoogle => 'Doorgaan met Google';

  @override
  String get signingInWithGoogle => 'Inloggen met Google...';

  @override
  String get error => 'Fout';

  @override
  String get anErrorOccurred => 'Er is een fout opgetreden';

  @override
  String get unknownError => 'Onbekende fout';

  @override
  String get goToHome => 'Ga naar Start';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ Betaling gelukt! Abonnement controleren...';

  @override
  String get paymentFailed => 'Betaling mislukt';

  @override
  String get paymentCanceled => 'ℹ️ Betaling geannuleerd';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp succesvol geverifieerd!';

  @override
  String get settings => 'Instellingen';

  @override
  String get enableNotificationsInSettings => 'Schakel meldingen voor Moneko in via de instellingen van je apparaat';

  @override
  String get appearance => 'Weergave';

  @override
  String get darkMode => 'Donkere modus';

  @override
  String get notifications => 'Meldingen';

  @override
  String get pushNotifications => 'Pushmeldingen';

  @override
  String get receiveAlertsAndUpdates => 'Ontvang waarschuwingen en updates';

  @override
  String get language => 'Taal';

  @override
  String get systemDefault => 'Systeemstandaard';

  @override
  String get membership => 'Abonnement';

  @override
  String get loading => 'Laden...';

  @override
  String get failedToLoadMembership => 'Kon abonnement niet laden';

  @override
  String get couldNotOpenMembershipPage => 'Kon abonnementspagina niet openen';

  @override
  String get freePlan => 'Gratis';

  @override
  String get freePlanStatus => 'Gratis abonnement';

  @override
  String get lifetimePlan => 'Lifetime';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus (per maand)';

  @override
  String get plusYearlyPlan => 'Plus (per jaar)';

  @override
  String get activeStatus => 'Actief';

  @override
  String get activeLifetimeStatus => 'Actief • Lifetime';

  @override
  String get canceledStatus => 'Geannuleerd';

  @override
  String get pastDueStatus => 'Achterstallig';

  @override
  String get trialStatus => 'Proefperiode';

  @override
  String trialEndsInDays(int days) {
    return 'Proefperiode eindigt over $days dagen';
  }

  @override
  String get trialEnded => 'Proefperiode beëindigd';

  @override
  String renewsInDays(int days) {
    return 'Wordt verlengd over $days dagen';
  }

  @override
  String accessEndsInDays(int days) {
    return 'Toegang eindigt over $days dagen';
  }

  @override
  String get subscriptionEnded => 'Abonnement beëindigd';

  @override
  String get profile => 'Profiel';

  @override
  String get errorLoadingProfile => 'Fout bij laden van profiel';

  @override
  String get user => 'Gebruiker';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp gekoppeld';

  @override
  String get logExpensesViaWhatsApp => 'Uitgaven registreren via WhatsApp';

  @override
  String get connectWhatsApp => 'Koppel WhatsApp';

  @override
  String get newBadge => 'NIEUW';

  @override
  String get logExpensesInstantly => 'Registreer uitgaven direct via chat';

  @override
  String get fast => 'Snel';

  @override
  String get photo => 'Foto';

  @override
  String get autoSync => 'Auto-sync';

  @override
  String get naturalLanguage => 'Natuurlijke taal';

  @override
  String get describeExpenseAutomatically => 'Omschrijf je uitgave. Wij registreren het automatisch.';

  @override
  String get snapReceipt => 'Scan je bon';

  @override
  String get snapReceiptDescription => 'Maak een foto van je bon. AI extraheert en registreert de gegevens.';

  @override
  String get previous => 'Vorige';

  @override
  String get next => 'Volgende';

  @override
  String get overview => 'Overzicht';

  @override
  String get activity => 'Activiteit';

  @override
  String get accountInformation => 'Accountinformatie';

  @override
  String get userId => 'Gebruikers-ID';

  @override
  String get recentActivity => 'Recente activiteit';

  @override
  String get noActivityYet => 'Nog geen activiteit';

  @override
  String get signOut => 'Uitloggen';

  @override
  String get insights => 'Inzichten';

  @override
  String get runningTab => 'Lopend';

  @override
  String get day30Tab => '30 dagen';

  @override
  String get longTermTab => 'Lange termijn';

  @override
  String get scenarioTab => 'Scenario';

  @override
  String get runningAndDailyBalances => 'Lopend & Dagelijks Saldo';

  @override
  String get budgetVsSpentDescription => 'Budget vs. uitgaven per dag met cumulatief lopend saldo.';

  @override
  String get runningBalanceLegend => 'Lopend saldo';

  @override
  String get budgetLegend => 'Budget';

  @override
  String get spentLegend => 'Uitgegeven';

  @override
  String get runningBalanceGuide => 'Uitleg lopend saldo';

  @override
  String get runningBalanceIntro => 'Zie deze grafiek als je persoonlijke geldcoach. Laten we bekijken wat het toont en hoe je het gebruikt.';

  @override
  String get day30LookAhead => '30-daagse prognose';

  @override
  String get projectedFromTrailing30Days => 'Geprojecteerd op basis van gemiddelden van de afgelopen 30 dagen.';

  @override
  String get projectedSpendingLegend => 'Verwachte uitgaven';

  @override
  String get peek30DaysAhead => 'Kijk 30 dagen vooruit';

  @override
  String get day30ForecastIntro => 'Deze prognose gebruikt de activiteit van de afgelopen maand om in te schatten hoe de volgende maand eruitziet. Zie het als een weerbericht voor je portemonnee.';

  @override
  String get longTermProjection => 'Langetermijnprognose';

  @override
  String get basedOnHistoricalAverages => 'Gebaseerd op historische gemiddelden; wordt automatisch bijgewerkt met jouw gegevens.';

  @override
  String get month18ProjectionLegend => '18-maandenprognose';

  @override
  String get your18MonthHorizon => 'Jouw 18-maandenhorizon';

  @override
  String get longTermIntro => 'Deze prognose combineert je vaste gewoonten met voorzichtige groei-aannames, zodat je kunt zien waar je keuzes van vandaag toe leiden.';

  @override
  String get aiScenarioPlanning => 'AI Scenarioplanning';

  @override
  String get askAiFinancialAdvisor => 'Vraag je AI-financieel adviseur of je een toekomstige uitgave kunt veroorloven';

  @override
  String get canI => 'Kan ik';

  @override
  String get before => 'vóór';

  @override
  String get beforePrefix => 'vóór';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Kies datum';

  @override
  String get check => 'Controleren';

  @override
  String get enterQuestionAndPickDate => 'Stel een vraag en kies een datum';

  @override
  String get analyzingScenario => 'Scenario analyseren...';

  @override
  String get thisMightTakeAWhile => 'Dit kan even duren';

  @override
  String get whereTheMoneyWent => 'Waar het geld naartoe ging';

  @override
  String get categoryTotalsForSelectedRange => 'Categorie-totalen voor de geselecteerde periode.';

  @override
  String get scenarioCategoriesGuide => 'Begrijp de categorieën';

  @override
  String get categoryGuideIntro => 'Zie deze grafiek als een helikopterview van waar elke euro naartoe ging. Zo lees je het, zonder rekenmachine.';

  @override
  String get readTheBarChartLikeAPro => 'Lees het staafdiagram als een pro';

  @override
  String get categoryChartDesc => 'Uitsplitsing per categorie voor de geselecteerde periode.';

  @override
  String get whyThisViewIsHelpful => 'Waarom dit handig is';

  @override
  String get categoryWhyHelpfulDesc => 'Identificeer snel je grootste uitgavencategorieën en ontdek trends.';

  @override
  String get whatToDoWithTheInsight => 'Wat je met dit inzicht kunt doen';

  @override
  String get categoryWhatToDoDesc => 'Gebruik deze informatie om je budget en uitgavenpatroon aan te passen.';

  @override
  String get scenarioAnalysis => 'Scenarioanalyse';

  @override
  String get target => 'Doel';

  @override
  String get quickStats => 'Snelle statistieken';

  @override
  String get currentBalance => 'Huidig saldo';

  @override
  String get projectedNoChange => 'Prognose (onveranderd)';

  @override
  String get avgDailyNet => 'Gem. dagelijks netto';

  @override
  String get noDataAvailable => 'Geen gegevens beschikbaar';

  @override
  String get day => 'Dag';

  @override
  String get close => 'Sluiten';

  @override
  String get done => 'Klaar';

  @override
  String get whatYouAreSeeing => 'Wat je ziet';

  @override
  String get whyItMatters => 'Waarom het belangrijk is';

  @override
  String get howToRespond => 'Hoe je kunt reageren';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Je lopend saldo laat zien hoeveel ademruimte je hebt na elke dag. De dagelijkse staven tonen wat je had gepland versus wat je werkelijk hebt uitgegeven.';

  @override
  String get runningBalanceWhyMattersDesc => 'Zie dit als een snelle check. Het helpt je te zien wanneer je voorloopt op schema (en kunt blijven investeren), of wanneer een bijsturing nodig is.';

  @override
  String get runningBalanceHowToRespondDesc => 'Gebruik de grafiek als coach. Vier je successen, stel je verwachtingen bij als dat nodig is, en wees niet te streng voor jezelf. Het gaat om vooruitgang, niet om perfectie.';

  @override
  String get whatTheForecastShows => 'Wat de prognose toont';

  @override
  String get day30WhatShowsDesc => 'We combineren de uitgaven en inkomsten van de afgelopen 30 dagen om een gemiddelde week te schetsen. Uitschieters worden gladgestreken zodat je je normale ritme ziet.';

  @override
  String get day30WhyMattersDesc => 'Vooruitkijkende budgetten helpen je proactief te blijven. Als je dure dagen ziet aankomen, kun je alvast geld opzijzetten in plaats van later in de knel te komen.';

  @override
  String get day30HowToPlaySmartDesc => 'Zie het als een vriendelijk duwtje, niet als een strikte regel. Pas je plan aan met kleine, haalbare stappen.';

  @override
  String get howTheProjectionWorks => 'Hoe de prognose werkt';

  @override
  String get longTermHowWorksDesc => 'We trekken je gemiddelde inkomsten en uitgaven door, met een bescheiden groei, zodat je kunt zien of je met je plan de komende maanden comfortabel doorkomt.';

  @override
  String get longTermWhyMattersDesc => 'Een lange horizon maakt grote dromen haalbaar. Zie of je noodfonds, investeringen of grote aankopen op koers blijven.';

  @override
  String get longTermMovesToConsiderDesc => 'Gebruik de grafiek om toekomstige beslissingen te \'oefenen\'. Kleine aanpassingen vandaag leiden tot grote winsten later.';

  @override
  String get forMe => 'Voor mij';

  @override
  String get forUs => 'Voor ons';

  @override
  String get home => 'Home';

  @override
  String get reminder => 'Herinnering';

  @override
  String get analyzingReceipt => 'Bon analyseren...';

  @override
  String get analyzingExpense => 'Uitgave analyseren...';

  @override
  String get noExpenseInformationExtracted => 'Geen uitgave-informatie gevonden';

  @override
  String get failedToAnalyzeNoData => 'Analyse mislukt: geen gegevens ontvangen';

  @override
  String get failedToAnalyze => 'Analyse mislukt';

  @override
  String get updateBudget => 'Budget bijwerken';

  @override
  String get enterNewTotalDailyBudget => 'Voer het nieuwe totale dagbudget in.';

  @override
  String get budgetAmount => 'Budgetbedrag';

  @override
  String get save => 'Opslaan';

  @override
  String get enterValidAmountGreaterThan0 => 'Voer een geldig bedrag in (hoger dan 0)';

  @override
  String get updatingBudget => 'Budget bijwerken...';

  @override
  String get budgetUpdated => 'Budget bijgewerkt';

  @override
  String get failedToUpdateBudget => 'Budget bijwerken mislukt';

  @override
  String get loggedSuccessfully => 'Succesvol geregistreerd';

  @override
  String get view => 'Bekijken';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String get failedToCapturePhoto => 'Foto maken mislukt';

  @override
  String get noSpendingData => 'Geen uitgavengegevens';

  @override
  String get byCategory => 'Per categorie';

  @override
  String get noExpensesYet => 'Nog geen uitgaven';

  @override
  String get startLoggingExpensesToSeeCategories => 'Begin met het registreren van uitgaven om categorieën te zien';

  @override
  String get selectDateRange => 'Selecteer datumbereik';

  @override
  String get addExpense => 'Uitgave toevoegen';

  @override
  String get describeYourExpense => 'Omschrijf je uitgave (bijv: \"5 voor burger, 3 voor koffie\")';

  @override
  String get enterExpenseDetails => 'Voer uitgavedetails in...';

  @override
  String get freeFormText => 'Vrije tekst';

  @override
  String get takePhoto => 'Maak foto';

  @override
  String get transactions => 'Transacties';

  @override
  String get negative => 'Negatief';

  @override
  String get positive => 'Positief';

  @override
  String get spendingBreakdown => 'Uitsplitsing uitgaven';

  @override
  String get spent => 'Uitgegeven';

  @override
  String get today => 'Vandaag';

  @override
  String get yesterday => 'Gisteren';

  @override
  String get thisWeek => 'Deze week';

  @override
  String get lastWeek => 'Vorige week';

  @override
  String get thisMonth => 'Deze maand';

  @override
  String get last30Days => 'Afgelopen 30 dagen';

  @override
  String get customRange => 'Aangepast bereik';

  @override
  String get spentToday => 'Je uitgaven vandaag';

  @override
  String get spentYesterday => 'Je uitgaven gisteren';

  @override
  String get spentThisWeek => 'Je uitgaven deze week';

  @override
  String get spentLastWeek => 'Je uitgaven vorige week';

  @override
  String get spentThisMonth => 'Je uitgaven deze maand';

  @override
  String get spentLast30Days => 'Je uitgaven (afgelopen 30 dagen)';

  @override
  String get spentCustom => 'Uitgegeven (aangepast)';

  @override
  String get todaysBudget => 'Budget van vandaag';

  @override
  String get yesterdaysBudget => 'Budget van gisteren';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Totaal dagbudgetten deze week';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Totaal dagbudgetten vorige week';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Totaal dagbudgetten deze maand';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Totaal dagbudgetten afgelopen 30 dagen';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Totaal dagbudgetten geselecteerde periode';

  @override
  String get netCashflowToday => 'Netto cashflow vandaag';

  @override
  String get netCashflowYesterday => 'Netto cashflow gisteren';

  @override
  String get netCashflowThisWeek => 'Netto cashflow deze week';

  @override
  String get netCashflowLastWeek => 'Netto cashflow vorige week';

  @override
  String get netCashflowThisMonth => 'Netto cashflow deze maand';

  @override
  String get netCashflowLast30Days => 'Netto cashflow (afgelopen 30 dagen)';

  @override
  String get netCashflowCustom => 'Netto cashflow (aangepast)';

  @override
  String get selectCurrency => 'Kies valuta';

  @override
  String get showLessCurrencies => 'Minder valuta\'s tonen';

  @override
  String showAllCurrencies(int count) {
    return 'Alle valuta\'s tonen ($count meer)';
  }

  @override
  String get budget => 'Budget';

  @override
  String get spentLabel => 'Uitgegeven';

  @override
  String get net => 'Netto';

  @override
  String get txn => 'trans.';

  @override
  String get txns => 'trans.';

  @override
  String get pleaseEnterExpenseDetails => 'Voer uitgavedetails in';

  @override
  String get userNotLoggedIn => 'Gebruiker niet ingelogd';

  @override
  String get errorLoadingHouseholds => 'Fout bij laden van huishoudens';

  @override
  String get welcomeToHouseholds => 'Welkom bij Huishoudens';

  @override
  String get householdsDescription => 'Beheer gedeelde financiën met je familie, partner of huisgenoten. Volg budgetten, splits uitgaven en werk samen aan geldbeslissingen.';

  @override
  String get createHousehold => 'Huishouden aanmaken';

  @override
  String get joinWithInvite => 'Deelnemen met uitnodiging';

  @override
  String get pleaseUseInvitationLink => 'Gebruik een uitnodigingslink om deel te nemen aan een huishouden';

  @override
  String get householdName => 'Naam huishouden';

  @override
  String get householdNameHint => 'bijv. De Jongs';

  @override
  String get pleaseEnterHouseholdName => 'Voer een naam in voor het huishouden';

  @override
  String get errorCreatingHousehold => 'Fout bij aanmaken van huishouden';

  @override
  String get householdsFeature => 'Huishoudens-functie';

  @override
  String get householdsFeatureDescription => 'De Huishoudens-functie is nu beschikbaar! Beheer gedeelde financiën met familie, partners of huisgenoten.';

  @override
  String get gotIt => 'Oké!';

  @override
  String get confirmExpense => 'Bevestig uitgave';

  @override
  String get expenseDetails => 'Uitgavedetails';

  @override
  String get details => 'Details';

  @override
  String get category => 'Categorie';

  @override
  String get currency => 'Valuta';

  @override
  String get date => 'Datum';

  @override
  String get time => 'Tijd';

  @override
  String get notes => 'Notities';

  @override
  String get receipt => 'Bon';

  @override
  String get saveExpense => 'Uitgave opslaan';

  @override
  String get shareWithHousehold => 'Delen met huishouden';

  @override
  String get loadingHouseholdMembers => 'Leden van huishouden laden...';

  @override
  String get selectHouseholdToConfigureSplit => 'Kies een huishouden om de splitsing in te stellen';

  @override
  String get currencyManagedByHousehold => 'Valuta wordt beheerd door het huishouden en kan niet worden gewijzigd';

  @override
  String get currencyCannotBeChanged => 'Valuta kan niet worden gewijzigd bij delen met een huishouden';

  @override
  String get failedToLoadImage => 'Afbeelding laden mislukt';

  @override
  String get editAmount => 'Bedrag bewerken';

  @override
  String get amount => 'Bedrag';

  @override
  String get editNotes => 'Notities bewerken';

  @override
  String get addANote => 'Voeg een notitie toe...';

  @override
  String get noMembersFoundInHousehold => 'Geen leden gevonden in huishouden';

  @override
  String get errorLoadingMembers => 'Fout bij laden van leden';

  @override
  String get noExpenseToSave => 'Geen uitgave om op te slaan';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'Uitgave opgeslagen en gedeeld$splitInfo!';
  }

  @override
  String get expenseSaved => 'Uitgave opgeslagen!';

  @override
  String failedToSave(String error) {
    return 'Opslaan mislukt: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Synchroniseren valutavoorkeur mislukt: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Valuta succesvol bijgewerkt';

  @override
  String retryFailed(Object error) {
    return 'Opnieuw proberen mislukt: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'Ik heb $currencySymbol$amount uitgegeven aan $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Voer het nieuwe totale dagbudget in.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Log in om toegang te krijgen tot huishouden-functies';

  @override
  String get quickActions => 'Snelle acties';

  @override
  String get members => 'Leden';

  @override
  String get invites => 'Uitnodigingen';

  @override
  String get errorLoadingExpenses => 'Fout bij laden van uitgaven';

  @override
  String get budgets => 'Budgetten';

  @override
  String get loadingHousehold => 'Huishouden laden...';

  @override
  String get remaining => 'Resterend';

  @override
  String get overBudget => 'Boven budget';

  @override
  String get sharedBudgets => 'Gedeelde budgetten';

  @override
  String get netPosition => 'Nettopositie';

  @override
  String get spentByHousehold => 'Uitgaven van Huishouden';

  @override
  String get memberSpending => 'Uitgaven per Lid';

  @override
  String get spentByHouseholdTooltip => 'Dit toont het totaalbedrag dat alle huishoudleden hebben uitgegeven in de geselecteerde periode. Het omvat alle gedeelde uitgaven die door een lid van het huishouden zijn geregistreerd.';

  @override
  String get manageMoneyTogether => 'Beheer geld samen met je partner, familie of huisgenoten in één gedeelde ruimte.';

  @override
  String get sharedBudgetsExpenses => 'Gedeelde budgetten & Uitgaven';

  @override
  String get sharedBudgetsExpensesDesc => 'Stel budgetten in, volg uitgaven en zie in real-time waar het geld van het huishouden naartoe gaat.';

  @override
  String get smartExpenseSplitting => 'Slim uitgaven splitsen';

  @override
  String get smartExpenseSplittingDesc => 'Bereken automatisch wie wat verschuldigd is met flexibele splitsopties: gelijk, percentage of aangepaste bedragen.';

  @override
  String get stayInSync => 'Blijf gesynchroniseerd';

  @override
  String get stayInSyncDesc => 'Ontvang meldingen wanneer uitgaven worden toegevoegd, budgetten zijn bereikt of splitsingen moeten worden verrekend.';

  @override
  String get householdSettings => 'Instellingen huishouden';

  @override
  String get householdNotFound => 'Huishouden niet gevonden';

  @override
  String get coverPhoto => 'Omslagfoto';

  @override
  String get changeCoverPhoto => 'Omslagfoto wijzigen';

  @override
  String get saveChanges => 'Wijzigingen opslaan';

  @override
  String get errorLoadingHousehold => 'Fout bij laden van huishouden';

  @override
  String get householdUpdatedSuccessfully => 'Huishouden succesvol bijgewerkt';

  @override
  String get failedToUpdateHousehold => 'Huishouden bijwerken mislukt';

  @override
  String get inviteMember => 'Lid uitnodigen';

  @override
  String get removeMember => 'Lid verwijderen';

  @override
  String get remove => 'Verwijderen';

  @override
  String get confirmRemoveMember => 'Weet je zeker dat je';

  @override
  String get updatedMemberRole => 'Rol van lid bijgewerkt';

  @override
  String get unknown => 'Onbekend';

  @override
  String get makeAdmin => 'Beheerder maken';

  @override
  String get makeMember => 'Lid maken';

  @override
  String get invitations => 'Uitnodigingen';

  @override
  String get errorLoadingInvites => 'Fout bij laden van uitnodigingen';

  @override
  String get createInvitation => 'Uitnodiging maken';

  @override
  String get pendingInvitations => 'Openstaande uitnodigingen';

  @override
  String get noPendingInvitations => 'Geen openstaande uitnodigingen';

  @override
  String get invitationHistory => 'Geschiedenis uitnodigingen';

  @override
  String get noInvitationHistory => 'Geen uitnodigingsgeschiedenis';

  @override
  String get emailOptional => 'E-mail (optioneel)';

  @override
  String get friendEmailExample => 'vriend@voorbeeld.nl';

  @override
  String get personalMessageOptional => 'Persoonlijk bericht (optioneel)';

  @override
  String get joinHouseholdBudget => 'Sluit je aan bij ons huishoudbudget!';

  @override
  String get expiresIn => 'Verloopt over';

  @override
  String get oneDay => '1 dag';

  @override
  String get threeDays => '3 dagen';

  @override
  String get sevenDays => '7 dagen';

  @override
  String get fourteenDays => '14 dagen';

  @override
  String get thirtyDays => '30 dagen';

  @override
  String get unlimited => 'Onbeperkt';

  @override
  String get create => 'Aanmaken';

  @override
  String get invitationCreatedSuccessfully => 'Uitnodiging succesvol aangemaakt';

  @override
  String get inviteLinkCopiedToClipboard => 'Uitnodigingslink gekopieerd naar klembord!';

  @override
  String get errorCreatingInvite => 'Fout bij maken van uitnodiging';

  @override
  String get revokeInvitation => 'Uitnodiging intrekken';

  @override
  String get confirmRevokeInvitation => 'Weet je zeker dat je deze uitnodiging wilt intrekken?';

  @override
  String get revoke => 'Intrekken';

  @override
  String get invitationRevoked => 'Uitnodiging ingetrokken';

  @override
  String get errorRevokingInvite => 'Fout bij intrekken van uitnodiging';

  @override
  String get anyoneWithLink => 'Iedereen met de link';

  @override
  String get noExpiry => 'Verloopt niet';

  @override
  String get expired => 'Verlopen';

  @override
  String get expires => 'Verloopt';

  @override
  String get copyLink => 'Link kopiëren';

  @override
  String get selectCoverImage => 'Kies omslagfoto';

  @override
  String get failedToLoadImages => 'Afbeeldingen laden mislukt';

  @override
  String get chooseFromGallery => 'Kies uit galerij';

  @override
  String get failedToLoad => 'Laden mislukt';

  @override
  String get imageTooLarge => 'Afbeelding te groot';

  @override
  String get maxIs => 'Max. is';

  @override
  String get unsupportedFileFormat => 'Niet-ondersteund bestandsformaat. Gebruik JPG, PNG of WebP.';

  @override
  String get cropCoverImage => 'Omslagfoto bijsnijden';

  @override
  String get editBudget => 'Budget bewerken';

  @override
  String get budgetDetails => 'Budgetdetails';

  @override
  String get budgetName => 'Naam budget';

  @override
  String get period => 'Periode';

  @override
  String get alertThresholds => 'Waarschuwingsdrempels';

  @override
  String get warningThreshold => 'Waarschuwingsdrempel (%)';

  @override
  String get alertThreshold => 'Alarmdrempel (%)';

  @override
  String get warningThresholdHelper => 'Melding wanneer budgetgebruik dit percentage bereikt';

  @override
  String get alertThresholdHelper => 'Kritieke melding bij dit percentage';

  @override
  String get budgetStatus => 'Budgetstatus';

  @override
  String get active => 'Actief';

  @override
  String get inactive => 'Inactief';

  @override
  String get deletingBudget => 'Budget verwijderen...';

  @override
  String get savingChanges => 'Wijzigingen opslaan...';

  @override
  String get budgetNameCannotBeEmpty => 'Budgetnaam mag niet leeg zijn';

  @override
  String get pleaseEnterValidAmount => 'Voer een geldig bedrag in';

  @override
  String get warningThresholdRange => 'Waarschuwingsdrempel moet tussen 0 en 100 zijn';

  @override
  String get alertThresholdRange => 'Alarmdrempel moet tussen 0 en 100 zijn';

  @override
  String get warningThresholdLessThanAlert => 'Waarschuwingsdrempel moet lager zijn dan of gelijk zijn aan de alarmdrempel';

  @override
  String get deleteBudget => 'Budget verwijderen';

  @override
  String get confirmDeleteBudget => 'Weet je zeker dat je';

  @override
  String get thisActionCannotBeUndone => 'Deze actie kan niet ongedaan worden gemaakt';

  @override
  String get budgetUpdatedSuccessfully => 'Budget succesvol bijgewerkt';

  @override
  String get budgetDeletedSuccessfully => 'Budget succesvol verwijderd';

  @override
  String get categoryTransfers => 'Overboekingen';

  @override
  String get categoryShopping => 'Winkelen';

  @override
  String get categoryUtilities => 'Nutsvoorzieningen';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryEntertainmentSubscriptions => 'Entertainment-abonnementen';

  @override
  String get categoryRestaurants => 'Restaurants';

  @override
  String get categoryFood => 'Eten & Drinken';

  @override
  String get categoryGroceries => 'Boodschappen';

  @override
  String get categoryTransport => 'Vervoer';

  @override
  String get categoryTransportation => 'Vervoer';

  @override
  String get categoryTravel => 'Reizen';

  @override
  String get categoryFlights => 'Vluchten';

  @override
  String get categoryVacation => 'Vakantie';

  @override
  String get categoryHealth => 'Gezondheid';

  @override
  String get categoryMedical => 'Medisch';

  @override
  String get categoryText => 'Tekst';

  @override
  String get categoryEducation => 'Onderwijs';

  @override
  String get categoryTuition => 'Studiegeld';

  @override
  String get categorySubscriptions => 'Abonnementen';

  @override
  String get categoryServices => 'Diensten';

  @override
  String get categoryHousing => 'Wonen';

  @override
  String get categoryRent => 'Huur';

  @override
  String get categoryMortgage => 'Hypotheek';

  @override
  String get categoryBills => 'Rekeningen';

  @override
  String get categoryInsurance => 'Verzekeringen';

  @override
  String get categorySavings => 'Sparen';

  @override
  String get categoryInvestment => 'Investering';

  @override
  String get categoryInvestments => 'Investeringen';

  @override
  String get categoryIncome => 'Inkomsten';

  @override
  String get categorySalary => 'Salaris';

  @override
  String get categoryBonus => 'Bonus';

  @override
  String get categoryPets => 'Huisdieren';

  @override
  String get categoryKids => 'Kinderen';

  @override
  String get categoryFamily => 'Familie';

  @override
  String get categoryGifts => 'Cadeaus';

  @override
  String get categoryCharity => 'Goede doelen';

  @override
  String get categoryFees => 'Kosten';

  @override
  String get categoryLoan => 'Lening';

  @override
  String get categoryLoans => 'Leningen';

  @override
  String get categoryDebt => 'Schuld';

  @override
  String get categoryPersonalCare => 'Persoonlijke verzorging';

  @override
  String get categoryBeauty => 'Uiterlijk';

  @override
  String get categoryMisc => 'Overig';

  @override
  String get categoryUncategorized => 'Geen categorie';

  @override
  String get deleteBudgetCannotBeUndone => 'Deze actie kan niet ongedaan worden gemaakt';

  @override
  String get delete => 'Verwijderen';

  @override
  String get failedToDeleteBudget => 'Budget verwijderen mislukt';

  @override
  String get owner => 'Eigenaar';

  @override
  String get admin => 'Beheerder';

  @override
  String get member => 'Lid';

  @override
  String get pending => 'Openstaand';

  @override
  String get accepted => 'Geaccepteerd';

  @override
  String get revoked => 'Ingetrokken';

  @override
  String get tapToChangeCover => 'Tik om omslag te wijzigen';

  @override
  String get personalMessageHint => 'Zeg iets tegen je genodigden (bijv. \"Sluit je aan bij ons huishoudbudget!\")';

  @override
  String get invitationExpiresIn => 'Uitnodiging verloopt over';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'dagen',
      one: 'dag',
    );
    return '$days $_temp0';
  }

  @override
  String get createHouseholdDescription => 'Maak een gedeelde ruimte om budgetten en uitgaven bij te houden met familie of huisgenoten.';

  @override
  String get uploadingImage => 'Afbeelding uploaden...';

  @override
  String get creating => 'Aanmaken...';

  @override
  String get generatingInvite => 'Uitnodiging genereren...';

  @override
  String get pleaseSelectValidCurrency => 'Kies een geldige valuta voor het huishouden';

  @override
  String nameMaxLength(int max) {
    return 'Naam mag maximaal $max tekens bevatten';
  }

  @override
  String get createHouseholdPage => 'Pagina huishouden aanmaken';

  @override
  String get invitationPersonalMessageInput => 'Invoerveld persoonlijk bericht uitnodiging';

  @override
  String get householdNameInput => 'Invoerveld naam huishouden';

  @override
  String get invitationExpirationSelector => 'Keuzelijst verloopdatum uitnodiging';

  @override
  String get unlimitedExpiration => 'Onbeperkt geldig';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'dagen',
      one: 'dag',
    );
    return '$days $_temp0 geldig';
  }

  @override
  String get householdInformation => 'Informatie huishouden';

  @override
  String get creatingHousehold => 'Huishouden aanmaken';

  @override
  String get createHouseholdButton => 'Knop huishouden aanmaken';

  @override
  String get searchExpenses => 'Uitgaven zoeken...';

  @override
  String get clearAll => 'Alles wissen';

  @override
  String get allCategories => 'Alle categorieën';

  @override
  String get allMembers => 'Alle leden';

  @override
  String get balanceSummary => 'Saldo-overzicht';

  @override
  String get youAreOwed => 'Jij krijgt nog';

  @override
  String get youOwe => 'Jij moet nog';

  @override
  String get youOweOthers => 'Jij moet anderen nog';

  @override
  String get othersOweYou => 'Anderen moeten jou nog';

  @override
  String get viewDetails => 'Bekijk details';

  @override
  String get settleUp => 'Verrekenen';

  @override
  String get markExpensesAsSettled => 'Markeer uitgaven als \'verrekend\' om de saldo\'s bij te werken';

  @override
  String get whoAreYouSettlingWith => 'Met wie wil je verrekenen?';

  @override
  String get selectMember => 'Kies lid';

  @override
  String get amountToSettle => 'Te verrekenen bedrag';

  @override
  String get howDidYouSettle => 'Hoe heb je verrekend?';

  @override
  String get cash => 'Contant';

  @override
  String get paidInCash => 'Contant betaald';

  @override
  String get bankTransfer => 'Bankoverschrijving';

  @override
  String get transferredViaBank => 'Overgemaakt via bank';

  @override
  String get mobilePayment => 'Mobiele betaling';

  @override
  String get venmoPaypalEtc => 'Tikkie, PayPal, etc.';

  @override
  String get search => 'Zoeken';

  @override
  String get noData => 'Geen gegevens';

  @override
  String get filterTransactions => 'Filter transacties';

  @override
  String get noTransactionsFound => 'Geen transacties gevonden';

  @override
  String get failedToLoadHouseholdTransactions => 'Laden van huishoudtransacties mislukt';

  @override
  String get reset => 'Resetten';

  @override
  String get apply => 'Toepassen';

  @override
  String get expenses => 'Uitgaven';

  @override
  String get dateRange => 'Datumbereik';

  @override
  String get noMatchingExpenses => 'Geen passende uitgaven';

  @override
  String get startLoggingExpenses => 'Begin met registreren om hier je uitgaven te zien';

  @override
  String get tryAdjustingFilters => 'Probeer je filters aan te passen';

  @override
  String get split => 'Splitsen';

  @override
  String get note => 'Notitie';

  @override
  String get currencyCannotBeChangedWhenSharing => 'Valuta kan niet worden gewijzigd bij het delen met een huishouden';

  @override
  String get createBudget => 'Budget aanmaken';

  @override
  String get pleaseEnterABudgetName => 'Voer een budgetnaam in';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Voer een geldig bedrag in (hoger dan 0)';

  @override
  String get warningThresholdMustBeBetween0And100 => 'Waarschuwingsdrempel moet tussen 0 en 100% zijn';

  @override
  String get alertThresholdMustBeBetween0And100 => 'Alarmdrempel moet tussen 0 en 100% zijn';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'Waarschuwingsdrempel moet lager zijn dan of gelijk zijn aan de alarmdrempel';

  @override
  String get budgetCreatedSuccessfully => 'Budget succesvol aangemaakt!';

  @override
  String get failedToCreateBudget => 'Aanmaken budget mislukt';

  @override
  String get groceriesRentEntertainment => 'bijv. Boodschappen, Huur, Entertainment';

  @override
  String get budgetType => 'Soort budget';

  @override
  String get sharedWithAllHouseholdMembers => 'Gedeeld met alle leden van het huishouden';

  @override
  String get personalBudgetForYourExpensesOnly => 'Persoonlijk budget (alleen voor jouw uitgaven)';

  @override
  String get countSplitPortionOnly => 'Alleen gesplitst deel tellen';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Tel alleen jouw deel van gesplitste uitgaven mee voor dit budget';

  @override
  String get joinHousehold => 'Deelnemen aan huishouden';

  @override
  String get joinAHousehold => 'Deelnemen aan een huishouden';

  @override
  String get enterYourInvitationLinkToJoin => 'Voer je uitnodigingslink in om deel te nemen\naan een gedeelde financiële ruimte';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Plak de uitnodigingslink die je van een huishoudenlid ontving';

  @override
  String get pasteInvitationLink => 'Plak uitnodigingslink';

  @override
  String get pleaseEnterAnInvitationLink => 'Voer een uitnodigingslink in';

  @override
  String get pleaseEnterAValidInvitationLink => 'Voer een geldige uitnodigingslink in';

  @override
  String get paste => 'Plakken';

  @override
  String get validating => 'Valideren...';

  @override
  String get continueAction => 'Doorgaan';

  @override
  String get welcomeAboard => 'Welkom aan boord!';

  @override
  String get youreNowPartOfTheHousehold => 'Je maakt nu deel uit van het huishouden.\nBegin met het samen beheren van je financiën!';

  @override
  String get thisWillOnlyTakeAMoment => 'Dit duurt maar een momentje';

  @override
  String get unableToJoin => 'Deelnemen mislukt';

  @override
  String get tryAgain => 'Probeer opnieuw';

  @override
  String get goToHousehold => 'Ga naar huishouden';

  @override
  String get expiresSoon => 'Verloopt binnenkort';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Uitnodiging geldig t/m $formattedDate';
  }

  @override
  String get whatYoullGet => 'Dit krijg je';

  @override
  String get viewSharedBudgetsAndExpenses => 'Gedeelde budgetten en uitgaven bekijken';

  @override
  String get trackHouseholdFinancialHealth => 'Financiële gezondheid van het huishouden volgen';

  @override
  String get collaborateOnFinancialDecisions => 'Samenwerken aan financiële beslissingen';

  @override
  String get household => 'Huishouden';

  @override
  String get viewAll => 'Alles bekijken';

  @override
  String get manage => 'Beheren';

  @override
  String get noBudgetsYet => 'Nog geen budgetten';

  @override
  String get createSharedBudgetDescription => 'Maak een gedeeld budget om samen uitgaven te volgen';

  @override
  String get errorLoadingBudgets => 'Fout bij laden van budgetten';

  @override
  String get recentSplits => 'Recente splitsingen';

  @override
  String get invite => 'Uitnodigen';

  @override
  String get last6Months => 'Afgelopen 6 maanden';

  @override
  String get thisYear => 'Dit jaar';

  @override
  String get allTime => 'Altijd';

  @override
  String nameMinLength(int min) {
    return 'Naam moet minimaal $min tekens bevatten';
  }

  @override
  String get splitExpense => 'Uitgave splitsen';

  @override
  String get percent => 'Procent';

  @override
  String get splitShare => 'Deel';

  @override
  String get owes => 'Schuldig';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'Gesplitste bedragen moeten opgeteld $currency$amount zijn';
  }

  @override
  String get percentagesMustTotal100 => 'Percentages moeten opgeteld 100% zijn';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'Elke persoon moet minimaal 1 deel hebben';

  @override
  String get whatsappVerified => 'WhatsApp geverifieerd';

  @override
  String get whatsappVerification => 'WhatsApp-verificatie';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Je WhatsApp-nummer is succesvol gekoppeld aan je account';

  @override
  String get verifyingYourWhatsAppNumber => 'Je WhatsApp-nummer verifiëren...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Voer de 6-cijferige code uit WhatsApp in';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Voer de 6-cijferige verificatiecode in';

  @override
  String get failedToVerifyCode => 'Code verifiëren mislukt';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Code verifiëren mislukt. Probeer het opnieuw.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Code automatisch ingevuld via verificatielink';

  @override
  String get verify => 'Verifiëren';

  @override
  String get verifying => 'Verifiëren...';

  @override
  String get avatarStudio => 'Avatarstudio';

  @override
  String get preview => 'Voorbeeld';

  @override
  String get colors => 'Kleuren';

  @override
  String get randomize => 'Willekeurig';

  @override
  String get saveAvatar => 'Avatar opslaan';

  @override
  String get saving => 'Opslaan...';

  @override
  String get skipForNow => 'Nu overslaan';

  @override
  String get selectColor => 'Kies kleur';

  @override
  String get failedToSaveAvatar => 'Avatar opslaan mislukt';

  @override
  String get hair => 'Haar';

  @override
  String get eyes => 'Ogen';

  @override
  String get mouth => 'Mond';

  @override
  String get background => 'Achtergrond';

  @override
  String get face => 'Gezicht';

  @override
  String get ears => 'Oren';

  @override
  String get shirts => 'Shirts';

  @override
  String get brow => 'Wenkbrauw';

  @override
  String get nose => 'Neus';

  @override
  String get blush => 'Blos';

  @override
  String get accessories => 'Accessoires';

  @override
  String get stars => 'Sterren';

  @override
  String get currencyIsManagedByHousehold => 'Valuta wordt beheerd door het huishouden en kan niet worden gewijzigd';

  @override
  String get buyALaptop => 'een laptop van € 1.200 kopen';

  @override
  String get selectTargetDate => 'Kies streefdatum';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'Kan ik $action vóór $date?';
  }

  @override
  String get scenarioDateFormat => 'dd-MM-yyyy';

  @override
  String analysisFailed(String error) {
    return 'Analyse mislukt: $error';
  }

  @override
  String get leftHandChamps => 'De uitschieters links zijn je zwaargewichten: perfecte kandidaten voor een snelle check.';

  @override
  String get smallButFrequent => 'Kleine maar frequente categorieën wijzen op gewoonten die er na verloop van tijd insluipen.';

  @override
  String get colorMatches => 'De kleur komt overeen met wat je op het Home-tabblad ziet, wel zo makkelijk.';

  @override
  String get planningNewGoal => 'Een nieuw doel plannen? Ontdek categorieën om op te bezuinigen zonder aan de leuke dingen te komen.';

  @override
  String get eyeingTreatYourself => 'Zin in een verwenmaand? Kijk welke posten wat flexibeler zijn.';

  @override
  String get doubleCheckTagging => 'Gebruik dit om te controleren of nieuwe uitgaven goed zijn gecategoriseerd; geen verrassingen.';

  @override
  String get slideHighBar => 'Druk een hoge staaf omlaag door een minilimiet in te stellen of over te stappen op goedkopere alternatieven.';

  @override
  String get nonNegotiable => 'Als een staaf niet onderhandelbaar is (hallo, huur!), plan er dan omheen in plaats van ertegen te vechten.';

  @override
  String get revisitAfterScenario => 'Bekijk dit opnieuw na een scenario om te zien of je aanpassingen effect hebben.';

  @override
  String get purpleLineCushion => 'Paarse lijn: de buffer die elke dag overblijft. Een stijgende lijn betekent dat je momentum opbouwt.';

  @override
  String get blueBarsBudget => 'Blauwe staven: het budget dat je voor die dag hebt ingesteld.';

  @override
  String get redBarsSpent => 'Rode staven: wat er daadwerkelijk van je rekening afging.';

  @override
  String get lineTrendingUpward => 'Lijn stijgt = extra geld dat je kunt doorsluizen naar spaardoelen.';

  @override
  String get flatDippingLine => 'Vlakke of dalende lijn = tijd om te pauzeren en grote uitgaven te bekijken.';

  @override
  String get sharpDrops => 'Scherpe dalingen duiden vaak op ongeplande aankopen. Tik erop om de details te zien.';

  @override
  String get lineRisingDays => 'Stijgt de lijn al een paar dagen? Overweeg om wat extra\'s te sparen of af te lossen.';

  @override
  String get lineDippingWeekend => 'Daalt de lijn na een druk weekend? Breng de komende dagen in balans door te korten op kleine, niet-noodzakelijke uitgaven.';

  @override
  String get feelStuckRed => 'Zit je vast in het rood? Check je budget op het Home-tabblad. Kleine aanpassingen tellen snel op.';

  @override
  String get thirtyDayForecastDesc => 'Deze prognose gebruikt de activiteit van de afgelopen maand om in te schatten hoe de volgende maand eruitziet. Zie het als een weerbericht voor je portemonnee.';

  @override
  String get greenLineExpected => 'Groene lijn = verwachte dagelijkse uitgaven als de komende maand zich gedraagt als de vorige.';

  @override
  String get spikesHighlight => 'Pieken markeren weken waarin je gewoonten meestal duurder uitvallen (hallo, afhaalmaaltijd op vrijdag).';

  @override
  String get forecastUpdates => 'Wanneer je nieuwe transacties invoert, wordt de prognose vanzelf bijgewerkt. Je hoeft niet te verversen.';

  @override
  String get spotExpensivePatterns => 'Ontdek dure patronen vroegtijdig en leg een minibuffer aan voordat het zover is.';

  @override
  String get catchQuieterWeeks => 'Profiteer van rustigere weken om extra geld te sparen of af te lossen.';

  @override
  String get timeRecurringPayments => 'Gebruik dit inzicht om terugkerende betalingen, abonnementen of opwaarderingen te timen.';

  @override
  String get bigSpikeComing => 'Grote piek op komst? Boek alvast goedkopere opties of verschuif flexibele uitgaven naar rustigere dagen.';

  @override
  String get forecastDipping => 'Prognose aan de lage kant? Beloon jezelf en plan een extra spaaropdracht in.';

  @override
  String get forecastLooksOff => 'Lijkt de prognose niet te kloppen? Controleer je categorieën op het Home-tabblad om foute labels te corrigeren.';

  @override
  String get greenLineTrends => 'De groene lijn volgt je typische spaartempo. Een stijgende lijn betekent dat je doelen worden gefinancierd.';

  @override
  String get lineDipsSignals => 'Als de lijn daalt, signaleert dat toekomstige maanden waarin de uitgaven de inkomsten dreigen te overstijgen.';

  @override
  String get largeGoalsDebts => 'Grote doelen of schulden worden meegenomen als je ze tagt op het Home-tabblad.';

  @override
  String get upwardSlope => 'Een stijgende lijn? Vier het en overweeg je pensioen- of reisspaarpot een boost te geven.';

  @override
  String get flatSlipping => 'Vlak of dalend? Tijd om budgetten aan te passen of inkomsten te verhogen voordat het een probleem wordt.';

  @override
  String get watchSeasonalTrends => 'Let op seizoentrends: vakanties, schoolperiodes of jaarlijkse verlengingen zie je hier vaak als eerste.';

  @override
  String get schedulePaymentIncreases => 'Plan voorzichtige verhogingen van aflossingen als de curve stijgt.';

  @override
  String get planAheadDips => 'Plan vooruit voor dalingen door geld te reserveren (sinking funds) of te korten op optionele uitgaven.';

  @override
  String get checkProjectionMonthly => 'Controleer de prognose maandelijks om je langetermijnplan leuk en flexibel te houden.';

  @override
  String get categoryHealthcare => 'Gezondheidszorg';

  @override
  String get categoryOther => 'Overig';

  @override
  String get deleteExpense => 'Verwijder uitgave';

  @override
  String get confirmDeleteExpense => 'Weet je zeker dat je deze uitgave wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get expenseDeletedSuccessfully => 'Uitgave succesvol verwijderd';

  @override
  String get failedToDeleteExpense => 'Verwijderen van uitgave mislukt';

  @override
  String get expenseNotFoundOrDeleted => 'Uitgave niet gevonden of al verwijderd';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Alleen beheerders en eigenaren kunnen huishoudinstellingen bewerken';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Alleen beheerders en eigenaren kunnen uitnodigingen maken';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Uitnodiging voor huishouden $householdName delen';
  }

  @override
  String get shareInvitation => 'Uitnodiging delen';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Huishouden $householdName succesvol aangemaakt';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'Huishouden \"$householdName\" succesvol aangemaakt!';
  }

  @override
  String get invitationLink => 'Uitnodigingslink';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Uitnodigingslink: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Uitnodigingslink kopiëren';

  @override
  String get copyInvitationLinkToClipboard => 'Uitnodigingslink naar klembord kopiëren';

  @override
  String get shareInvitationLink => 'Uitnodigingslink delen';

  @override
  String get share => 'Delen';

  @override
  String get closeShareSheet => 'Deelvenster sluiten';

  @override
  String get invitationLinkCopiedToClipboard => 'Uitnodigingslink gekopieerd naar klembord!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Word lid van mijn huishouden \"$householdName\" op Moneko!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Word lid van mijn huishouden op Moneko';

  @override
  String get zeroAmount => '0,00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Notificatie-instellingen';

  @override
  String get budgetBoop => 'Budget-tikje';

  @override
  String get getGentleReminder => 'Krijg een zachte herinnering wanneer je deze drempel bereikt';

  @override
  String get purrSuasiveNudge => 'Een snorrend duwtje';

  @override
  String get getStrongerNudge => 'Krijg een sterkere duw wanneer je deze drempel bereikt';

  @override
  String get createBudgetButton => 'Budget maken';

  @override
  String get daily => 'Dagelijks';

  @override
  String get weekly => 'Wekelijks';

  @override
  String get monthly => 'Maandelijks';

  @override
  String get yearly => 'Jaarlijks';

  @override
  String get householdBudgetType => 'Huishoudbudget';

  @override
  String get personalBudgetType => 'Persoonlijk budget';

  @override
  String joinHouseholdName(String householdName) {
    return 'Deelnemen aan \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Voorbeeld huishouden: $householdName, uitgenodigd door $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Uitgenodigd door $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'Uitnodiging verloopt binnenkort op $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Uitnodiging geldig t/m';

  @override
  String get personalMessageFromInviter => 'Persoonlijk bericht van de uitnodiger';

  @override
  String get messageFromInviter => 'Bericht van de uitnodiger';

  @override
  String get joiningHousehold => 'Bezig met deelnemen...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Fout: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'Er is een onverwachte fout opgetreden';

  @override
  String get invalidInvitationLinkFormat => 'Ongeldig uitnodigingslinkformaat';

  @override
  String get invalidOrExpiredInvitation => 'Ongeldige of verlopen uitnodiging';

  @override
  String get tomorrow => 'Morgen';

  @override
  String inDays(int days) {
    return 'over $days dagen';
  }

  @override
  String get january => 'Jan';

  @override
  String get february => 'Feb';

  @override
  String get march => 'Mrt';

  @override
  String get april => 'Apr';

  @override
  String get may => 'Mei';

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
  String get december => 'Dec';

  @override
  String remindUser(String name) {
    return '$name herinneren';
  }

  @override
  String get sendFriendlySpendingReminder => 'Een vriendelijke bestedingsherinnering sturen';

  @override
  String get addMessageOptional => 'Bericht toevoegen (optioneel)';

  @override
  String get messageHintExample => 'Bijv.: \"Je portemonnee heeft rust nodig!\"';

  @override
  String get sendReminder => 'Herinnering sturen';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Wacht 24 uur voordat je nog een herinnering naar $name stuurt';
  }

  @override
  String reminderSentToName(String name) {
    return 'Herinnering verzonden naar $name 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'Herinnering verzenden mislukt. Probeer het opnieuw.';
}
