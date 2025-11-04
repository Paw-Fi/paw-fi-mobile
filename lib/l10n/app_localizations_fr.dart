// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'Aucune dépense';

  @override
  String get loginWelcomeBack => 'Ravi de vous revoir';

  @override
  String get orContinueWithEmail => 'Ou continuer par e-mail';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get signIn => 'Connexion';

  @override
  String get newToMoneko => 'Nouveau sur Moneko ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get resetYourPassword => 'Réinitialiser votre mot de passe';

  @override
  String get email => 'E-mail';

  @override
  String get exampleEmail => 'vous@exemple.com';

  @override
  String get cancel => 'Annuler';

  @override
  String get sendResetLink => 'Envoyer le lien de réinitialisation';

  @override
  String get passwordResetEmailSent => 'E-mail de réinitialisation envoyé. Vérifiez votre boîte de réception.';

  @override
  String get enterValidEmail => 'Veuillez saisir une adresse e-mail valide.';

  @override
  String passwordMinLength(int min) {
    return 'Le mot de passe doit contenir au moins $min caractères.';
  }

  @override
  String fullNameMinLength(int min) {
    return 'Le nom complet doit contenir au moins $min caractères.';
  }

  @override
  String get createYourAccount => 'Créez votre compte';

  @override
  String get fullName => 'Nom complet';

  @override
  String get createPassword => 'Créer un mot de passe';

  @override
  String get passwordComplexityRequirement => 'Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre.';

  @override
  String get passwordRequirementShort => 'Mot de passe : 8+ caractères, avec majuscule, minuscule et chiffre.';

  @override
  String get termsAgreement => 'En créant un compte, vous acceptez nos Conditions d\'utilisation et notre Politique de confidentialité.';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get signInLower => 'Se connecter';

  @override
  String get verificationCodeSent => 'Code de vérification envoyé avec succès';

  @override
  String get verifyYourEmail => 'Vérifiez votre e-mail';

  @override
  String verificationEmailSentTo(String email) {
    return 'Nous avons envoyé un code de vérification à 6 chiffres à $email';
  }

  @override
  String get enterCompleteCode => 'Veuillez saisir le code complet à 6 chiffres.';

  @override
  String get invalidVerificationCode => 'Code de vérification invalide.';

  @override
  String get verificationCodeExpired => 'Le code de vérification a expiré. Veuillez en demander un nouveau.';

  @override
  String get verifyEmail => 'Vérifier l\'e-mail';

  @override
  String get didntReceiveTheCode => 'Vous n\'avez pas reçu le code ? Vérifiez vos spams ou';

  @override
  String resendInSeconds(int seconds) {
    return 'renvoyer dans $seconds s';
  }

  @override
  String get resendVerificationEmail => 'renvoyer l\'e-mail de vérification';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get signingInWithGoogle => 'Connexion avec Google...';

  @override
  String get error => 'Erreur';

  @override
  String get anErrorOccurred => 'Une erreur est survenue';

  @override
  String get unknownError => 'Erreur inconnue';

  @override
  String get goToHome => 'Aller à l\'accueil';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ Paiement réussi ! Vérification de l\'abonnement...';

  @override
  String get paymentFailed => 'Échec du paiement';

  @override
  String get paymentCanceled => 'ℹ️ Paiement annulé';

  @override
  String get whatsappVerifiedSuccessfully => '✅ WhatsApp vérifié avec succès !';

  @override
  String get settings => 'Paramètres';

  @override
  String get enableNotificationsInSettings => 'Activez les notifications pour Moneko dans les réglages de votre appareil.';

  @override
  String get appearance => 'Apparence';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Notifications push';

  @override
  String get receiveAlertsAndUpdates => 'Recevoir des alertes et des mises à jour';

  @override
  String get language => 'Langue';

  @override
  String get systemDefault => 'Système';

  @override
  String get membership => 'Abonnement';

  @override
  String get loading => 'Chargement...';

  @override
  String get failedToLoadMembership => 'Échec du chargement de l\'abonnement.';

  @override
  String get couldNotOpenMembershipPage => 'Impossible d\'ouvrir la page de l\'abonnement.';

  @override
  String get freePlan => 'Gratuit';

  @override
  String get freePlanStatus => 'Formule gratuite';

  @override
  String get lifetimePlan => 'À vie';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus (Mensuel)';

  @override
  String get plusYearlyPlan => 'Plus (Annuel)';

  @override
  String get activeStatus => 'Actif';

  @override
  String get activeLifetimeStatus => 'Actif • À vie';

  @override
  String get canceledStatus => 'Annulé';

  @override
  String get pastDueStatus => 'En retard';

  @override
  String get trialStatus => 'Essai';

  @override
  String trialEndsInDays(int days) {
    return 'Fin de l\'essai dans $days jours';
  }

  @override
  String get trialEnded => 'Essai terminé';

  @override
  String renewsInDays(int days) {
    return 'Renouvellement dans $days jours';
  }

  @override
  String accessEndsInDays(int days) {
    return 'Fin de l\'accès dans $days jours';
  }

  @override
  String get subscriptionEnded => 'Abonnement terminé';

  @override
  String get profile => 'Profil';

  @override
  String get errorLoadingProfile => 'Erreur lors du chargement du profil.';

  @override
  String get user => 'Utilisateur';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp connecté';

  @override
  String get logExpensesViaWhatsApp => 'Ajouter des dépenses par messages WhatsApp';

  @override
  String get connectWhatsApp => 'Connecter WhatsApp';

  @override
  String get newBadge => 'NOUVEAU';

  @override
  String get logExpensesInstantly => 'Ajoutez vos dépenses instantanément par chat.';

  @override
  String get fast => 'Rapide';

  @override
  String get photo => 'Photo';

  @override
  String get autoSync => 'Synchro auto';

  @override
  String get naturalLanguage => 'Langage naturel';

  @override
  String get describeExpenseAutomatically => 'Décrivez votre dépense. Nous l\'enregistrons automatiquement.';

  @override
  String get snapReceipt => 'Scanner un reçu';

  @override
  String get snapReceiptDescription => 'Scannez votre reçu. L\'IA extrait et enregistre les données.';

  @override
  String get previous => 'Précédent';

  @override
  String get next => 'Suivant';

  @override
  String get overview => 'Aperçu';

  @override
  String get activity => 'Activité';

  @override
  String get accountInformation => 'Informations du compte';

  @override
  String get userId => 'ID utilisateur';

  @override
  String get recentActivity => 'Activité récente';

  @override
  String get noActivityYet => 'Aucune activité pour le moment.';

  @override
  String get signOut => 'Déconnexion';

  @override
  String get insights => 'Analyses';

  @override
  String get runningTab => 'En continu';

  @override
  String get day30Tab => '30 jours';

  @override
  String get longTermTab => 'Long terme';

  @override
  String get scenarioTab => 'Scénario';

  @override
  String get runningAndDailyBalances => 'Soldes courants et quotidiens';

  @override
  String get budgetVsSpentDescription => 'Budget vs Dépenses par jour avec solde courant cumulé.';

  @override
  String get runningBalanceLegend => 'Solde courant';

  @override
  String get budgetLegend => 'Budget';

  @override
  String get spentLegend => 'Dépensé';

  @override
  String get runningBalanceGuide => 'Guide du solde courant';

  @override
  String get runningBalanceIntro => 'Voyez ce graphique comme votre coach financier personnel. Découvrons ce qu\'il montre et comment l\'utiliser.';

  @override
  String get day30LookAhead => 'Prévision à 30 jours';

  @override
  String get projectedFromTrailing30Days => 'Projeté à partir des moyennes des 30 derniers jours.';

  @override
  String get projectedSpendingLegend => 'Dépenses projetées';

  @override
  String get peek30DaysAhead => 'Un aperçu des 30 prochains jours';

  @override
  String get day30ForecastIntro => 'Cette prévision utilise l\'activité du mois dernier pour anticiper le mois à venir. Considérez-la comme la météo de votre portefeuille.';

  @override
  String get longTermProjection => 'Projection à long terme';

  @override
  String get basedOnHistoricalAverages => 'Basé sur les moyennes historiques ; se met à jour automatiquement avec vos données.';

  @override
  String get month18ProjectionLegend => 'Projection à 18 mois';

  @override
  String get your18MonthHorizon => 'Votre horizon à 18 mois';

  @override
  String get longTermIntro => 'Cette projection combine vos habitudes et des hypothèses de croissance modérées pour voir où vos choix d\'aujourd\'hui vous mènent.';

  @override
  String get aiScenarioPlanning => 'Planification de scénario (IA)';

  @override
  String get askAiFinancialAdvisor => 'Demandez à votre conseiller financier IA si vous pouvez vous permettre une dépense future.';

  @override
  String get canI => 'Puis-je';

  @override
  String get before => 'avant le';

  @override
  String get beforePrefix => 'avant le';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Choisir une date';

  @override
  String get check => 'Vérifier';

  @override
  String get enterQuestionAndPickDate => 'Veuillez poser une question et choisir une date.';

  @override
  String get analyzingScenario => 'Analyse du scénario...';

  @override
  String get thisMightTakeAWhile => 'Cela peut prendre un moment.';

  @override
  String get whereTheMoneyWent => 'Où est passé l\'argent';

  @override
  String get categoryTotalsForSelectedRange => 'Totaux par catégorie pour la période sélectionnée.';

  @override
  String get scenarioCategoriesGuide => 'Comprendre les catégories';

  @override
  String get categoryGuideIntro => 'Voyez ce graphique comme une vue d\'ensemble de la destination de chaque euro. Voici comment le lire sans calculatrice.';

  @override
  String get readTheBarChartLikeAPro => 'Lire le graphique en barres comme un pro';

  @override
  String get categoryChartDesc => 'Répartition par catégorie pour la période sélectionnée.';

  @override
  String get whyThisViewIsHelpful => 'Pourquoi cette vue est utile';

  @override
  String get categoryWhyHelpfulDesc => 'Identifiez rapidement vos plus grandes catégories de dépenses et repérez les tendances.';

  @override
  String get whatToDoWithTheInsight => 'Quoi faire de cette information';

  @override
  String get categoryWhatToDoDesc => 'Utilisez ces informations pour ajuster votre budget et vos habitudes de consommation.';

  @override
  String get scenarioAnalysis => 'Analyse du scénario';

  @override
  String get target => 'Cible';

  @override
  String get quickStats => 'Stats rapides';

  @override
  String get currentBalance => 'Solde actuel';

  @override
  String get projectedNoChange => 'Projeté (Sans changement)';

  @override
  String get avgDailyNet => 'Solde net quotidien moyen';

  @override
  String get noDataAvailable => 'Aucune donnée disponible';

  @override
  String get day => 'Jour';

  @override
  String get close => 'Fermer';

  @override
  String get done => 'Terminé';

  @override
  String get whatYouAreSeeing => 'Ce que vous voyez';

  @override
  String get whyItMatters => 'Pourquoi c\'est important';

  @override
  String get howToRespond => 'Comment réagir';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Votre solde courant suit votre marge de manœuvre après chaque journée de dépenses. Les barres montrent ce que vous aviez prévu vs ce que vous avez réellement dépensé.';

  @override
  String get runningBalanceWhyMattersDesc => 'Voyez-le comme un bilan de santé amical. Il vous aide à voir quand vous êtes en avance sur vos plans (pour continuer à investir) ou quand une correction s\'impose.';

  @override
  String get runningBalanceHowToRespondDesc => 'Utilisez le graphique comme un coach. Célébrez les gains, réajustez les attentes si nécessaire et soyez indulgent. L\'objectif est le progrès constant, pas la perfection.';

  @override
  String get whatTheForecastShows => 'Ce que montre la prévision';

  @override
  String get day30WhatShowsDesc => 'Nous combinons les 30 derniers jours de dépenses et de revenus pour esquisser une semaine moyenne à venir. Cela lisse les grosses dépenses ponctuelles pour voir le rythme habituel.';

  @override
  String get day30WhyMattersDesc => 'Des budgets prévisionnels vous aident à rester proactif. Anticiper les jours de grosses dépenses vous permet de mettre de l\'argent de côté au lieu de stresser plus tard.';

  @override
  String get day30HowToPlaySmartDesc => 'Prenez-le comme un conseil amical, pas une règle stricte. Ajustez votre plan avec de petits changements qui vous semblent réalisables.';

  @override
  String get howTheProjectionWorks => 'Comment fonctionne la projection';

  @override
  String get longTermHowWorksDesc => 'Nous projetons vos revenus et dépenses moyens, en y ajoutant une croissance modeste, pour voir si votre plan maintient un niveau de trésorerie confortable.';

  @override
  String get longTermWhyMattersDesc => 'Les horizons lointains concrétisent les grands rêves. Voyez si votre fonds d\'urgence, vos investissements ou vos gros achats restent sur la bonne voie.';

  @override
  String get longTermMovesToConsiderDesc => 'Utilisez le graphique pour simuler vos décisions futures. De petits ajustements aujourd\'hui génèrent de grands gains plus tard.';

  @override
  String get forMe => 'Pour moi';

  @override
  String get forUs => 'Pour nous';

  @override
  String get home => 'Accueil';

  @override
  String get reminder => 'Rappel';

  @override
  String get analyzingReceipt => 'Analyse du reçu...';

  @override
  String get analyzingExpense => 'Analyse de la dépense...';

  @override
  String get noExpenseInformationExtracted => 'Aucune information de dépense extraite.';

  @override
  String get failedToAnalyzeNoData => 'Échec de l\'analyse : Aucune donnée retournée.';

  @override
  String get failedToAnalyze => 'Échec de l\'analyse';

  @override
  String get updateBudget => 'Mettre à jour le budget';

  @override
  String get enterNewTotalDailyBudget => 'Saisissez le nouveau budget quotidien total.';

  @override
  String get budgetAmount => 'Montant du budget';

  @override
  String get save => 'Enregistrer';

  @override
  String get enterValidAmountGreaterThan0 => 'Saisissez un montant valide supérieur à 0.';

  @override
  String get updatingBudget => 'Mise à jour du budget...';

  @override
  String get budgetUpdated => 'Budget mis à jour';

  @override
  String get failedToUpdateBudget => 'Échec de la mise à jour du budget';

  @override
  String get loggedSuccessfully => 'Enregistré avec succès';

  @override
  String get view => 'Voir';

  @override
  String get retry => 'Réessayer';

  @override
  String get failedToCapturePhoto => 'Échec de la capture photo.';

  @override
  String get noSpendingData => 'Aucune donnée de dépense.';

  @override
  String get byCategory => 'Par catégorie';

  @override
  String get noExpensesYet => 'Aucune dépense pour l\'instant';

  @override
  String get startLoggingExpensesToSeeCategories => 'Commencez à ajouter des dépenses pour voir les catégories.';

  @override
  String get selectDateRange => 'Choisir la période';

  @override
  String get addExpense => 'Ajouter une dépense';

  @override
  String get describeYourExpense => 'Décrivez votre dépense (ex : \"5 pour un burger, 3 pour un café\")';

  @override
  String get enterExpenseDetails => 'Saisir les détails de la dépense...';

  @override
  String get freeFormText => 'Texte libre';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get transactions => 'Transactions';

  @override
  String get negative => 'Négatif';

  @override
  String get positive => 'Positif';

  @override
  String get spendingBreakdown => 'Répartition des dépenses';

  @override
  String get spent => 'Dépensé';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get lastWeek => 'La semaine dernière';

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get last30Days => 'Les 30 derniers jours';

  @override
  String get customRange => 'Période personnalisée';

  @override
  String get spentToday => 'Vos dépenses aujourd\'hui';

  @override
  String get spentYesterday => 'Vos dépenses hier';

  @override
  String get spentThisWeek => 'Vos dépenses cette semaine';

  @override
  String get spentLastWeek => 'Vos dépenses la semaine dernière';

  @override
  String get spentThisMonth => 'Vos dépenses ce mois-ci';

  @override
  String get spentLast30Days => 'Vos dépenses (30 derniers jours)';

  @override
  String get spentCustom => 'Dépensé (personnalisé)';

  @override
  String get todaysBudget => 'Budget du jour';

  @override
  String get yesterdaysBudget => 'Budget d\'hier';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Somme des budgets quotidiens (semaine)';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Somme des budgets quotidiens (sem. dernière)';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Somme des budgets quotidiens (mois)';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Somme des budgets quotidiens (30 jours)';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Somme des budgets quotidiens (période)';

  @override
  String get netCashflowToday => 'Flux de trésorerie net (aujourd\'hui)';

  @override
  String get netCashflowYesterday => 'Flux de trésorerie net (hier)';

  @override
  String get netCashflowThisWeek => 'Flux de trésorerie net (semaine)';

  @override
  String get netCashflowLastWeek => 'Flux de trésorerie net (sem. dernière)';

  @override
  String get netCashflowThisMonth => 'Flux de trésorerie net (mois)';

  @override
  String get netCashflowLast30Days => 'Flux de trésorerie net (30 jours)';

  @override
  String get netCashflowCustom => 'Flux de trésorerie net (personnalisé)';

  @override
  String get selectCurrency => 'Choisir la devise';

  @override
  String get showLessCurrencies => 'Afficher moins de devises';

  @override
  String showAllCurrencies(int count) {
    return 'Afficher toutes les devises ($count de plus)';
  }

  @override
  String get budget => 'Budget';

  @override
  String get spentLabel => 'Dépensé';

  @override
  String get net => 'Net';

  @override
  String get txn => 'trans.';

  @override
  String get txns => 'trans.';

  @override
  String get pleaseEnterExpenseDetails => 'Veuillez saisir les détails de la dépense.';

  @override
  String get userNotLoggedIn => 'Utilisateur non connecté.';

  @override
  String get errorLoadingHouseholds => 'Erreur de chargement des foyers';

  @override
  String get welcomeToHouseholds => 'Bienvenue dans les Foyers';

  @override
  String get householdsDescription => 'Gérez vos finances partagées avec votre famille, partenaire ou colocataires. Suivez les budgets, partagez les dépenses et collaborez.';

  @override
  String get createHousehold => 'Créer un foyer';

  @override
  String get joinWithInvite => 'Rejoindre avec une invitation';

  @override
  String get pleaseUseInvitationLink => 'Veuillez utiliser un lien d\'invitation pour rejoindre un foyer.';

  @override
  String get householdName => 'Nom du foyer';

  @override
  String get householdNameHint => 'ex : Famille Durand';

  @override
  String get pleaseEnterHouseholdName => 'Veuillez saisir un nom de foyer.';

  @override
  String get errorCreatingHousehold => 'Erreur lors de la création du foyer.';

  @override
  String get householdsFeature => 'Fonctionnalité Foyers';

  @override
  String get householdsFeatureDescription => 'La fonctionnalité Foyers est disponible ! Gérez vos finances partagées avec votre famille, partenaires ou colocataires.';

  @override
  String get gotIt => 'Compris !';

  @override
  String get confirmExpense => 'Confirmer la dépense';

  @override
  String get expenseDetails => 'Détails de la dépense';

  @override
  String get details => 'Détails';

  @override
  String get category => 'Catégorie';

  @override
  String get currency => 'Devise';

  @override
  String get date => 'Date';

  @override
  String get time => 'Heure';

  @override
  String get notes => 'Notes';

  @override
  String get receipt => 'Reçu';

  @override
  String get saveExpense => 'Enregistrer la dépense';

  @override
  String get shareWithHousehold => 'Partager avec le foyer';

  @override
  String get loadingHouseholdMembers => 'Chargement des membres du foyer...';

  @override
  String get selectHouseholdToConfigureSplit => 'Sélectionnez un foyer pour configurer le partage.';

  @override
  String get currencyManagedByHousehold => 'La devise est gérée par le foyer et ne peut pas être modifiée.';

  @override
  String get currencyCannotBeChanged => 'La devise ne peut pas être modifiée lors du partage avec un foyer.';

  @override
  String get failedToLoadImage => 'Échec du chargement de l\'image.';

  @override
  String get editAmount => 'Modifier le montant';

  @override
  String get amount => 'Montant';

  @override
  String get editNotes => 'Modifier les notes';

  @override
  String get addANote => 'Ajouter une note...';

  @override
  String get noMembersFoundInHousehold => 'Aucun membre trouvé dans ce foyer.';

  @override
  String get errorLoadingMembers => 'Erreur de chargement des membres.';

  @override
  String get noExpenseToSave => 'Aucune dépense à enregistrer.';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return 'Dépense enregistrée et partagée$splitInfo';
  }

  @override
  String get expenseSaved => 'Dépense enregistrée';

  @override
  String failedToSave(String error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Échec de la synchro. des préférences de devise : $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Devise mise à jour';

  @override
  String retryFailed(Object error) {
    return 'Échec de la nouvelle tentative : $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'J\'ai dépensé $amount $currencySymbol en $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Saisissez le nouveau budget quotidien total.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Veuillez vous connecter pour accéder aux foyers.';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get members => 'Membres';

  @override
  String get invites => 'Invitations';

  @override
  String get errorLoadingExpenses => 'Erreur de chargement des dépenses';

  @override
  String get budgets => 'Budgets';

  @override
  String get loadingHousehold => 'Chargement du foyer...';

  @override
  String get remaining => 'Restant';

  @override
  String get overBudget => 'Budget dépassé';

  @override
  String get sharedBudgets => 'Budgets partagés';

  @override
  String get netPosition => 'Solde de règlement';

  @override
  String get spentByHousehold => 'Dépenses du Foyer';

  @override
  String get memberSpending => 'Dépenses par Membre';

  @override
  String get spentByHouseholdTooltip => 'Cela montre le montant total dépensé par tous les membres du foyer pendant la période sélectionnée. Il inclut toutes les dépenses partagées enregistrées par n\'importe quel membre du foyer.';

  @override
  String get manageMoneyTogether => 'Gérez l\'argent ensemble avec votre partenaire, famille ou colocataires dans un espace partagé.';

  @override
  String get sharedBudgetsExpenses => 'Budgets et dépenses partagés';

  @override
  String get sharedBudgetsExpensesDesc => 'Définissez des budgets, suivez les dépenses et voyez où va l\'argent de votre foyer en temps réel.';

  @override
  String get smartExpenseSplitting => 'Partage intelligent des dépenses';

  @override
  String get smartExpenseSplittingDesc => 'Calculez automatiquement qui doit quoi avec des options flexibles : égal, pourcentage ou montants personnalisés.';

  @override
  String get stayInSync => 'Restez synchronisés';

  @override
  String get stayInSyncDesc => 'Soyez notifié lorsque des dépenses sont ajoutées, des budgets atteints ou des partages à régler.';

  @override
  String get householdSettings => 'Paramètres du foyer';

  @override
  String get householdNotFound => 'Foyer introuvable.';

  @override
  String get coverPhoto => 'Photo de couverture';

  @override
  String get changeCoverPhoto => 'Changer la photo de couverture';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get errorLoadingHousehold => 'Erreur de chargement du foyer.';

  @override
  String get householdUpdatedSuccessfully => 'Foyer mis à jour';

  @override
  String get failedToUpdateHousehold => 'Échec de la mise à jour du foyer';

  @override
  String get inviteMember => 'Inviter un membre';

  @override
  String get removeMember => 'Supprimer le membre';

  @override
  String get remove => 'Supprimer';

  @override
  String get confirmRemoveMember => 'Êtes-vous sûr de vouloir supprimer';

  @override
  String get updatedMemberRole => 'Rôle du membre mis à jour';

  @override
  String get unknown => 'Inconnu';

  @override
  String get makeAdmin => 'Nommer admin';

  @override
  String get makeMember => 'Nommer membre';

  @override
  String get invitations => 'Invitations';

  @override
  String get errorLoadingInvites => 'Erreur de chargement des invitations.';

  @override
  String get createInvitation => 'Créer une invitation';

  @override
  String get pendingInvitations => 'Invitations en attente';

  @override
  String get noPendingInvitations => 'Aucune invitation en attente.';

  @override
  String get invitationHistory => 'Historique des invitations';

  @override
  String get noInvitationHistory => 'Aucun historique d\'invitation.';

  @override
  String get emailOptional => 'E-mail (optionnel)';

  @override
  String get friendEmailExample => 'ami@exemple.com';

  @override
  String get personalMessageOptional => 'Message personnel (optionnel)';

  @override
  String get joinHouseholdBudget => 'Rejoignez notre budget de foyer !';

  @override
  String get expiresIn => 'Expire dans';

  @override
  String get oneDay => '1 jour';

  @override
  String get threeDays => '3 jours';

  @override
  String get sevenDays => '7 jours';

  @override
  String get fourteenDays => '14 jours';

  @override
  String get thirtyDays => '30 jours';

  @override
  String get unlimited => 'Illimité';

  @override
  String get create => 'Créer';

  @override
  String get invitationCreatedSuccessfully => 'Invitation créée avec succès';

  @override
  String get inviteLinkCopiedToClipboard => 'Lien d\'invitation copié';

  @override
  String get errorCreatingInvite => 'Erreur lors de la création de l\'invitation.';

  @override
  String get revokeInvitation => 'Révoquer l\'invitation';

  @override
  String get confirmRevokeInvitation => 'Êtes-vous sûr de vouloir révoquer cette invitation ?';

  @override
  String get revoke => 'Révoquer';

  @override
  String get invitationRevoked => 'Invitation révoquée';

  @override
  String get errorRevokingInvite => 'Erreur lors de la révocation de l\'invitation.';

  @override
  String get anyoneWithLink => 'Toute personne ayant le lien';

  @override
  String get noExpiry => 'N\'expire pas';

  @override
  String get expired => 'Expirée';

  @override
  String get expires => 'Expire';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get selectCoverImage => 'Choisir une image de couverture';

  @override
  String get failedToLoadImages => 'Échec du chargement des images.';

  @override
  String get chooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get failedToLoad => 'Échec du chargement.';

  @override
  String get imageTooLarge => 'Image trop volumineuse.';

  @override
  String get maxIs => 'Max :';

  @override
  String get unsupportedFileFormat => 'Format non supporté. Veuillez utiliser JPG, PNG ou WebP.';

  @override
  String get cropCoverImage => 'Recadrer l\'image de couverture';

  @override
  String get editBudget => 'Modifier le budget';

  @override
  String get budgetDetails => 'Détails du budget';

  @override
  String get budgetName => 'Nom du budget';

  @override
  String get period => 'Période';

  @override
  String get alertThresholds => 'Seuils d\'alerte';

  @override
  String get warningThreshold => 'Seuil d\'avertissement (%)';

  @override
  String get alertThreshold => 'Seuil d\'alerte (%)';

  @override
  String get warningThresholdHelper => 'Alerte quand l\'utilisation du budget atteint ce pourcentage.';

  @override
  String get alertThresholdHelper => 'Alerte critique à ce pourcentage.';

  @override
  String get budgetStatus => 'Statut du budget';

  @override
  String get active => 'Actif';

  @override
  String get inactive => 'Inactif';

  @override
  String get deletingBudget => 'Suppression du budget...';

  @override
  String get savingChanges => 'Enregistrement...';

  @override
  String get budgetNameCannotBeEmpty => 'Le nom du budget ne peut pas être vide.';

  @override
  String get pleaseEnterValidAmount => 'Veuillez saisir un montant valide.';

  @override
  String get warningThresholdRange => 'Le seuil d\'avertissement doit être entre 0 et 100.';

  @override
  String get alertThresholdRange => 'Le seuil d\'alerte doit être entre 0 et 100.';

  @override
  String get warningThresholdLessThanAlert => 'Le seuil d\'avertissement doit être inférieur ou égal au seuil d\'alerte.';

  @override
  String get deleteBudget => 'Supprimer le budget';

  @override
  String get confirmDeleteBudget => 'Êtes-vous sûr de vouloir supprimer';

  @override
  String get thisActionCannotBeUndone => 'Cette action est irréversible.';

  @override
  String get budgetUpdatedSuccessfully => 'Budget mis à jour';

  @override
  String get budgetDeletedSuccessfully => 'Budget supprimé';

  @override
  String get categoryTransfers => 'Virements';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryUtilities => 'Factures';

  @override
  String get categoryEntertainment => 'Loisirs';

  @override
  String get categoryEntertainmentSubscriptions => 'Abonnements (Loisirs)';

  @override
  String get categoryRestaurants => 'Restaurants';

  @override
  String get categoryFood => 'Alimentation';

  @override
  String get categoryGroceries => 'Courses';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Voyage';

  @override
  String get categoryFlights => 'Billets d\'avion';

  @override
  String get categoryVacation => 'Vacances';

  @override
  String get categoryHealth => 'Santé';

  @override
  String get categoryMedical => 'Médical';

  @override
  String get categoryText => 'Texte';

  @override
  String get categoryEducation => 'Éducation';

  @override
  String get categoryTuition => 'Frais de scolarité';

  @override
  String get categorySubscriptions => 'Abonnements';

  @override
  String get categoryServices => 'Services';

  @override
  String get categoryHousing => 'Logement';

  @override
  String get categoryRent => 'Loyer';

  @override
  String get categoryMortgage => 'Prêt immobilier';

  @override
  String get categoryBills => 'Factures';

  @override
  String get categoryInsurance => 'Assurance';

  @override
  String get categorySavings => 'Épargne';

  @override
  String get categoryInvestment => 'Investissement';

  @override
  String get categoryInvestments => 'Investissements';

  @override
  String get categoryIncome => 'Revenu';

  @override
  String get categorySalary => 'Salaire';

  @override
  String get categoryBonus => 'Bonus';

  @override
  String get categoryPets => 'Animaux';

  @override
  String get categoryKids => 'Enfants';

  @override
  String get categoryFamily => 'Famille';

  @override
  String get categoryGifts => 'Cadeaux';

  @override
  String get categoryCharity => 'Dons';

  @override
  String get categoryFees => 'Frais';

  @override
  String get categoryLoan => 'Prêt';

  @override
  String get categoryLoans => 'Prêts';

  @override
  String get categoryDebt => 'Dette';

  @override
  String get categoryPersonalCare => 'Soins personnels';

  @override
  String get categoryBeauty => 'Beauté';

  @override
  String get categoryMisc => 'Divers';

  @override
  String get categoryUncategorized => 'Non catégorisé';

  @override
  String get deleteBudgetCannotBeUndone => 'Cette action est irréversible.';

  @override
  String get delete => 'Supprimer';

  @override
  String get failedToDeleteBudget => 'Échec de la suppression du budget';

  @override
  String get owner => 'Propriétaire';

  @override
  String get admin => 'Admin';

  @override
  String get member => 'Membre';

  @override
  String get pending => 'En attente';

  @override
  String get accepted => 'Acceptée';

  @override
  String get revoked => 'Révoquée';

  @override
  String get tapToChangeCover => 'Appuyez pour changer la couverture';

  @override
  String get personalMessageHint => 'Dites quelque chose à vos invités (ex : \"Rejoignez notre budget de foyer !\")';

  @override
  String get invitationExpiresIn => 'L\'invitation expire dans';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$days jour$_temp0';
  }

  @override
  String get createHouseholdDescription => 'Créez un espace partagé pour suivre budgets et dépenses avec la famille ou des colocataires.';

  @override
  String get uploadingImage => 'Chargement de l\'image...';

  @override
  String get creating => 'Création...';

  @override
  String get generatingInvite => 'Génération de l\'invitation...';

  @override
  String get pleaseSelectValidCurrency => 'Veuillez choisir une devise valide pour le foyer.';

  @override
  String nameMaxLength(int max) {
    return 'Le nom doit contenir moins de $max caractères.';
  }

  @override
  String get createHouseholdPage => 'Page de création de foyer';

  @override
  String get invitationPersonalMessageInput => 'Champ : message personnel d\'invitation';

  @override
  String get householdNameInput => 'Champ : nom du foyer';

  @override
  String get invitationExpirationSelector => 'Sélecteur d\'expiration de l\'invitation';

  @override
  String get unlimitedExpiration => 'Expiration : illimitée';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Expiration : $days jour$_temp0';
  }

  @override
  String get householdInformation => 'Informations du foyer';

  @override
  String get creatingHousehold => 'Création du foyer...';

  @override
  String get createHouseholdButton => 'Bouton : Créer un foyer';

  @override
  String get searchExpenses => 'Rechercher des dépenses...';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get allCategories => 'Toutes les catégories';

  @override
  String get allMembers => 'Tous les membres';

  @override
  String get balanceSummary => 'Résumé des soldes';

  @override
  String get youAreOwed => 'On vous doit';

  @override
  String get youOwe => 'Vous devez';

  @override
  String get youOweOthers => 'Vous devez aux autres';

  @override
  String get othersOweYou => 'D\'autres vous doivent';

  @override
  String get viewDetails => 'Voir les détails';

  @override
  String get settleUp => 'Régler les comptes';

  @override
  String get markExpensesAsSettled => 'Marquer les dépenses comme réglées pour mettre à jour les soldes.';

  @override
  String get whoAreYouSettlingWith => 'Avec qui réglez-vous ?';

  @override
  String get selectMember => 'Choisir un membre';

  @override
  String get amountToSettle => 'Montant à régler';

  @override
  String get howDidYouSettle => 'Comment avez-vous réglé ?';

  @override
  String get cash => 'Espèces';

  @override
  String get paidInCash => 'Payé en espèces';

  @override
  String get bankTransfer => 'Virement bancaire';

  @override
  String get transferredViaBank => 'Transféré par virement';

  @override
  String get mobilePayment => 'Paiement mobile';

  @override
  String get venmoPaypalEtc => 'Lydia, PayPal, etc.';

  @override
  String get search => 'Rechercher';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get filterTransactions => 'Filtrer les transactions';

  @override
  String get noTransactionsFound => 'Aucune transaction trouvée.';

  @override
  String get failedToLoadHouseholdTransactions => 'Échec du chargement des transactions du foyer.';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get apply => 'Appliquer';

  @override
  String get expenses => 'Dépenses';

  @override
  String get dateRange => 'Période';

  @override
  String get noMatchingExpenses => 'Aucune dépense correspondante';

  @override
  String get startLoggingExpenses => 'Commencez à ajouter des dépenses pour les voir ici.';

  @override
  String get tryAdjustingFilters => 'Essayez d\'ajuster vos filtres.';

  @override
  String get split => 'Partager';

  @override
  String get note => 'Note';

  @override
  String get currencyCannotBeChangedWhenSharing => 'La devise ne peut pas être modifiée lors du partage avec un foyer.';

  @override
  String get createBudget => 'Créer un budget';

  @override
  String get pleaseEnterABudgetName => 'Veuillez saisir un nom de budget.';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Veuillez saisir un montant valide supérieur à 0.';

  @override
  String get warningThresholdMustBeBetween0And100 => 'Le seuil d\'avertissement doit être entre 0 et 100 %.';

  @override
  String get alertThresholdMustBeBetween0And100 => 'Le seuil d\'alerte doit être entre 0 et 100 %.';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'Le seuil d\'avertissement doit être inférieur ou égal au seuil d\'alerte.';

  @override
  String get budgetCreatedSuccessfully => 'Budget créé avec succès';

  @override
  String get failedToCreateBudget => 'Échec de la création du budget';

  @override
  String get groceriesRentEntertainment => 'ex : Courses, Loyer, Loisirs';

  @override
  String get budgetType => 'Type de budget';

  @override
  String get sharedWithAllHouseholdMembers => 'Partagé avec tous les membres du foyer';

  @override
  String get personalBudgetForYourExpensesOnly => 'Budget personnel pour vos dépenses uniquement';

  @override
  String get countSplitPortionOnly => 'Compter uniquement la part partagée';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Compter uniquement votre part des dépenses partagées dans ce budget.';

  @override
  String get joinHousehold => 'Rejoindre le foyer';

  @override
  String get joinAHousehold => 'Rejoindre un foyer';

  @override
  String get enterYourInvitationLinkToJoin => 'Entrez votre lien d\'invitation pour rejoindre\nun espace financier partagé';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Collez le lien d\'invitation que vous avez reçu d\'un membre du foyer';

  @override
  String get pasteInvitationLink => 'Coller le lien d\'invitation';

  @override
  String get pleaseEnterAnInvitationLink => 'Veuillez entrer un lien d\'invitation';

  @override
  String get pleaseEnterAValidInvitationLink => 'Veuillez entrer un lien d\'invitation valide';

  @override
  String get paste => 'Coller';

  @override
  String get validating => 'Validation...';

  @override
  String get continueAction => 'Continuer';

  @override
  String get welcomeAboard => 'Bienvenue à bord !';

  @override
  String get youreNowPartOfTheHousehold => 'Vous faites maintenant partie du foyer.\nCommencez à collaborer sur vos finances !';

  @override
  String get thisWillOnlyTakeAMoment => 'Juste un instant...';

  @override
  String get unableToJoin => 'Impossible de rejoindre';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get goToHousehold => 'Aller au Foyer';

  @override
  String get expiresSoon => 'Expire bientôt';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Invitation valide jusqu\'au $formattedDate';
  }

  @override
  String get whatYoullGet => 'Ce que vous obtiendrez';

  @override
  String get viewSharedBudgetsAndExpenses => 'Voir les budgets et dépenses partagés';

  @override
  String get trackHouseholdFinancialHealth => 'Suivre la santé financière du foyer';

  @override
  String get collaborateOnFinancialDecisions => 'Collaborer sur les décisions financières';

  @override
  String get household => 'Foyer';

  @override
  String get viewAll => 'Voir tout';

  @override
  String get manage => 'Gérer';

  @override
  String get noBudgetsYet => 'Aucun budget pour l\'instant.';

  @override
  String get createSharedBudgetDescription => 'Créez un budget partagé pour suivre les dépenses ensemble.';

  @override
  String get errorLoadingBudgets => 'Erreur de chargement des budgets.';

  @override
  String get recentSplits => 'Partages récents';

  @override
  String get invite => 'Inviter';

  @override
  String get last6Months => 'Les 6 derniers mois';

  @override
  String get thisYear => 'Cette année';

  @override
  String get allTime => 'Depuis toujours';

  @override
  String nameMinLength(int min) {
    return 'Le nom doit contenir au moins $min caractères.';
  }

  @override
  String get splitExpense => 'Partager la dépense';

  @override
  String get percent => 'Pourcentage';

  @override
  String get splitShare => 'Part';

  @override
  String get owes => 'Doit';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'Le total doit être égal à $amount $currency';
  }

  @override
  String get percentagesMustTotal100 => 'Le total des pourcentages doit être de 100 %.';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'Chaque personne doit avoir au moins 1 part.';

  @override
  String get whatsappVerified => 'WhatsApp vérifié';

  @override
  String get whatsappVerification => 'Vérification WhatsApp';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Votre numéro WhatsApp est connecté à votre compte.';

  @override
  String get verifyingYourWhatsAppNumber => 'Vérification de votre numéro WhatsApp...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Saisissez le code à 6 chiffres reçu sur WhatsApp.';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Veuillez saisir le code de vérification à 6 chiffres.';

  @override
  String get failedToVerifyCode => 'Échec de la vérification du code.';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Échec de la vérification. Veuillez réessayer.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Code auto-rempli depuis le lien de vérification.';

  @override
  String get verify => 'Vérifier';

  @override
  String get verifying => 'Vérification...';

  @override
  String get avatarStudio => 'Studio d\'avatar';

  @override
  String get preview => 'Aperçu';

  @override
  String get colors => 'Couleurs';

  @override
  String get randomize => 'Aléatoire';

  @override
  String get saveAvatar => 'Enregistrer l\'avatar';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get skipForNow => 'Ignorer pour l\'instant';

  @override
  String get selectColor => 'Choisir la couleur';

  @override
  String get failedToSaveAvatar => 'Échec de l\'enregistrement de l\'avatar.';

  @override
  String get hair => 'Cheveux';

  @override
  String get eyes => 'Yeux';

  @override
  String get mouth => 'Bouche';

  @override
  String get background => 'Arrière-plan';

  @override
  String get face => 'Visage';

  @override
  String get ears => 'Oreilles';

  @override
  String get shirts => 'Hauts';

  @override
  String get brow => 'Sourcils';

  @override
  String get nose => 'Nez';

  @override
  String get blush => 'Fard';

  @override
  String get accessories => 'Accessoires';

  @override
  String get stars => 'Étoiles';

  @override
  String get currencyIsManagedByHousehold => 'La devise est gérée par le foyer et ne peut pas être modifiée.';

  @override
  String get buyALaptop => 'acheter un ordinateur à 1 000 €';

  @override
  String get selectTargetDate => 'Choisir la date cible';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return 'Puis-je $action avant le $date';
  }

  @override
  String get scenarioDateFormat => 'dd/MM/yyyy';

  @override
  String analysisFailed(String error) {
    return 'Échec de l\'analyse : $error';
  }

  @override
  String get leftHandChamps => 'Les champions de gauche sont vos poids lourds — parfaits pour un examen rapide.';

  @override
  String get smallButFrequent => 'Les catégories petites mais fréquentes révèlent des habitudes qui peuvent s\'installer discrètement.';

  @override
  String get colorMatches => 'La couleur correspond à ce que vous voyez sur l\'Accueil pour que votre cerveau reste à l\'aise.';

  @override
  String get planningNewGoal => 'Vous planifiez un nouvel objectif ? Repérez les catégories à réduire sans toucher au plaisir.';

  @override
  String get eyeingTreatYourself => 'Envie d\'un mois \"plaisir\" ? Voyez quels postes de dépenses peuvent être flexibles.';

  @override
  String get doubleCheckTagging => 'Utilisez-le pour vérifier que les nouvelles dépenses ont été correctement étiquetées.';

  @override
  String get slideHighBar => 'Réduisez une barre élevée en fixant une mini-limite ou en optant pour des alternatives moins coûteuses.';

  @override
  String get nonNegotiable => 'Si une barre n\'est pas négociable (bonjour le loyer), planifiez autour d\'elle au lieu de la combattre.';

  @override
  String get revisitAfterScenario => 'Revenez après un scénario pour voir si vos ajustements tiennent la route.';

  @override
  String get purpleLineCushion => 'Ligne violette : la marge restante après chaque jour. Une ligne montante signifie que vous prenez de l\'élan.';

  @override
  String get blueBarsBudget => 'Barres bleues : le budget que vous avez fixé pour ce jour-là.';

  @override
  String get redBarsSpent => 'Barres rouges : ce qui est réellement sorti de votre compte.';

  @override
  String get lineTrendingUpward => 'Ligne ascendante = argent supplémentaire que vous pouvez rediriger vers vos objectifs d\'épargne.';

  @override
  String get flatDippingLine => 'Ligne plate ou descendante = il est temps de pauser et de revoir les gros postes de dépenses.';

  @override
  String get sharpDrops => 'Les chutes brutales correspondent souvent à des achats imprévus — appuyez dessus pour inspecter.';

  @override
  String get lineRisingDays => 'La ligne monte depuis plusieurs jours ? Pensez à épargner un peu plus ou à rembourser une dette.';

  @override
  String get lineDippingWeekend => 'La ligne plonge après un week-end chargé ? Rééquilibrez les jours à venir en réduisant les petites dépenses non essentielles.';

  @override
  String get feelStuckRed => 'Coincé dans le rouge ? Revoyez votre budget dans l\'Accueil — les petits ajustements font la différence.';

  @override
  String get thirtyDayForecastDesc => 'Cette prévision utilise l\'activité du mois dernier pour anticiper le mois à venir. Considérez-la comme la météo de votre portefeuille.';

  @override
  String get greenLineExpected => 'Ligne verte = dépense quotidienne attendue si le mois à venir se comporte comme le précédent.';

  @override
  String get spikesHighlight => 'Les pics soulignent les semaines où vos habitudes sont plus coûteuses (bonjour les restos du vendredi).';

  @override
  String get forecastUpdates => 'Lorsque vous ajoutez de nouvelles transactions, la prévision se met à jour en douceur.';

  @override
  String get spotExpensivePatterns => 'Repérez tôt les schémas coûteux et préparez un mini-tampon avant qu\'ils n\'arrivent.';

  @override
  String get catchQuieterWeeks => 'Profitez des semaines plus calmes pour transférer de l\'argent vers l\'épargne ou le remboursement de dettes.';

  @override
  String get timeRecurringPayments => 'Utilisez ces infos pour planifier vos paiements récurrents, abonnements ou recharges.';

  @override
  String get bigSpikeComing => 'Un gros pic arrive ? Réservez des options moins chères ou décalez les dépenses flexibles à des jours plus calmes.';

  @override
  String get forecastDipping => 'La prévision baisse ? Récompensez-vous en programmant un virement d\'épargne supplémentaire.';

  @override
  String get forecastLooksOff => 'Si la prévision semble erronée, vérifiez vos catégories dans l\'Accueil pour corriger les étiquettes.';

  @override
  String get greenLineTrends => 'La ligne verte suit votre taux d\'épargne habituel — une tendance à la hausse signifie que vos objectifs sont financés.';

  @override
  String get lineDipsSignals => 'Si la ligne baisse, cela signale des mois futurs où les dépenses dépassent les revenus.';

  @override
  String get largeGoalsDebts => 'Les grands objectifs ou les dettes sont inclus lorsque vous les marquez dans l\'Accueil.';

  @override
  String get upwardSlope => 'Une pente ascendante ? Célébrez et envisagez d\'augmenter votre épargne retraite ou voyage.';

  @override
  String get flatSlipping => 'Stable ou en baisse ? Il est temps d\'ajuster les budgets ou d\'augmenter les revenus avant que cela ne s\'aggrave.';

  @override
  String get watchSeasonalTrends => 'Surveillez les tendances saisonnières — vacances, rentrée scolaire ou renouvellements annuels apparaissent souvent ici en premier.';

  @override
  String get schedulePaymentIncreases => 'Programmez de légères augmentations de remboursement de prêts lorsque la courbe monte.';

  @override
  String get planAheadDips => 'Anticipez les baisses en constituant des fonds d\'amortissement ou en réduisant les dépenses optionnelles.';

  @override
  String get checkProjectionMonthly => 'Vérifiez la projection chaque mois pour garder votre vision à long terme flexible et motivante.';

  @override
  String get categoryHealthcare => 'Santé';

  @override
  String get categoryOther => 'Autre';

  @override
  String get deleteExpense => 'Supprimer la dépense';

  @override
  String get confirmDeleteExpense => 'Êtes-vous sûr de vouloir supprimer cette dépense ? Cette action est irréversible.';

  @override
  String get expenseDeletedSuccessfully => 'Dépense supprimée avec succès';

  @override
  String get failedToDeleteExpense => 'Échec de la suppression de la dépense';

  @override
  String get expenseNotFoundOrDeleted => 'Dépense introuvable ou déjà supprimée';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Seuls les administrateurs et propriétaires peuvent modifier les paramètres du foyer';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Seuls les administrateurs et propriétaires peuvent créer des invitations';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Partager l\'invitation pour le foyer $householdName';
  }

  @override
  String get shareInvitation => 'Partager l\'invitation';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Foyer $householdName créé avec succès';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return 'Foyer \"$householdName\" créé avec succès !';
  }

  @override
  String get invitationLink => 'Lien d\'invitation';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Lien d\'invitation : $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Copier le lien d\'invitation';

  @override
  String get copyInvitationLinkToClipboard => 'Copier le lien d\'invitation dans le presse-papiers';

  @override
  String get shareInvitationLink => 'Partager le lien d\'invitation';

  @override
  String get share => 'Partager';

  @override
  String get closeShareSheet => 'Fermer le panneau de partage';

  @override
  String get invitationLinkCopiedToClipboard => 'Lien d\'invitation copié dans le presse-papiers !';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return 'Rejoins mon foyer \"$householdName\" sur Moneko !\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Rejoins mon foyer sur Moneko';

  @override
  String get zeroAmount => '0,00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Paramètres de notification';

  @override
  String get budgetBoop => 'Miau-rappel';

  @override
  String get getGentleReminder => 'Reçois un rappel doux lorsque tu atteins ce seuil';

  @override
  String get purrSuasiveNudge => 'Poussée ronronnante';

  @override
  String get getStrongerNudge => 'Reçois une incitation plus forte lorsque tu atteins ce seuil';

  @override
  String get createBudgetButton => 'Créer un budget';

  @override
  String get daily => 'Quotidien';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get monthly => 'Mensuel';

  @override
  String get yearly => 'Annuel';

  @override
  String get householdBudgetType => 'Budget du foyer';

  @override
  String get personalBudgetType => 'Budget personnel';

  @override
  String joinHouseholdName(String householdName) {
    return 'Rejoindre \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Aperçu du foyer : $householdName, invité par $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Invité par $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'L\'invitation expire bientôt le $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Invitation valide jusqu\'au';

  @override
  String get personalMessageFromInviter => 'Message personnel de la personne qui vous invite';

  @override
  String get messageFromInviter => 'Message de la personne qui vous invite';

  @override
  String get joiningHousehold => 'Rejoindre le foyer...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Erreur : $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'Une erreur inattendue s\'est produite';

  @override
  String get invalidInvitationLinkFormat => 'Format de lien d\'invitation invalide';

  @override
  String get invalidOrExpiredInvitation => 'Invitation invalide ou expirée';

  @override
  String get tomorrow => 'Demain';

  @override
  String inDays(int days) {
    return 'dans $days jours';
  }

  @override
  String get january => 'Jan';

  @override
  String get february => 'Fév';

  @override
  String get march => 'Mar';

  @override
  String get april => 'Avr';

  @override
  String get may => 'Mai';

  @override
  String get june => 'Jui';

  @override
  String get july => 'Juil';

  @override
  String get august => 'Aoû';

  @override
  String get september => 'Sep';

  @override
  String get october => 'Oct';

  @override
  String get november => 'Nov';

  @override
  String get december => 'Déc';

  @override
  String remindUser(String name) {
    return 'Rappeler $name';
  }

  @override
  String get sendFriendlySpendingReminder => 'Envoyer un rappel amical de dépenses';

  @override
  String get addMessageOptional => 'Ajouter un message (facultatif)';

  @override
  String get messageHintExample => 'p. ex. « Votre portefeuille a besoin de souffler ! »';

  @override
  String get sendReminder => 'Envoyer le rappel';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Veuillez attendre 24 heures avant d’envoyer un nouveau rappel à $name';
  }

  @override
  String reminderSentToName(String name) {
    return 'Rappel envoyé à $name 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'Échec de l’envoi du rappel. Veuillez réessayer.';
}
