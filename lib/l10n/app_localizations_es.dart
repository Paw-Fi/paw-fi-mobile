// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Moneko';

  @override
  String get noSpendingYet => 'Aún sin gastos';

  @override
  String get loginWelcomeBack => '¡Hola de nuevo!';

  @override
  String get orContinueWithEmail => 'O continúa con email';

  @override
  String get emailAddress => 'Dirección de email';

  @override
  String get password => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get newToMoneko => '¿Eres nuevo/a en Moneko?';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get resetYourPassword => 'Restablece tu contraseña';

  @override
  String get email => 'Email';

  @override
  String get exampleEmail => 'tu@ejemplo.com';

  @override
  String get cancel => 'Cancelar';

  @override
  String get sendResetLink => 'Enviar enlace';

  @override
  String get passwordResetEmailSent => 'Email de restablecimiento enviado. Revisa tu bandeja de entrada.';

  @override
  String get enterValidEmail => 'Por favor, introduce un email válido';

  @override
  String passwordMinLength(int min) {
    return 'La contraseña debe tener al menos $min caracteres';
  }

  @override
  String fullNameMinLength(int min) {
    return 'El nombre completo debe tener al menos $min caracteres';
  }

  @override
  String get createYourAccount => 'Crea tu cuenta';

  @override
  String get fullName => 'Nombre completo';

  @override
  String get createPassword => 'Crea una contraseña';

  @override
  String get passwordComplexityRequirement => 'La contraseña debe incluir al menos una mayúscula, una minúscula y un número';

  @override
  String get passwordRequirementShort => 'Contraseña: 8+ caracteres, con mayúscula, minúscula y número';

  @override
  String get termsAgreement => 'Al crear una cuenta, aceptas nuestros Términos de Servicio y Política de Privacidad';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta?';

  @override
  String get signInLower => 'Inicia sesión';

  @override
  String get verificationCodeSent => 'Código de verificación enviado';

  @override
  String get verifyYourEmail => 'Verifica tu email';

  @override
  String verificationEmailSentTo(String email) {
    return 'Hemos enviado un código de 6 dígitos a $email';
  }

  @override
  String get enterCompleteCode => 'Por favor, introduce el código completo de 6 dígitos';

  @override
  String get invalidVerificationCode => 'Código de verificación no válido';

  @override
  String get verificationCodeExpired => 'El código de verificación ha caducado. Por favor, solicita uno nuevo.';

  @override
  String get verifyEmail => 'Verificar email';

  @override
  String get didntReceiveTheCode => '¿No recibiste el código? Revisa tu carpeta de spam o';

  @override
  String resendInSeconds(int seconds) {
    return 'reenviar en ${seconds}s';
  }

  @override
  String get resendVerificationEmail => 'reenviar email de verificación';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get signingInWithGoogle => 'Iniciando sesión con Google...';

  @override
  String get error => 'Error';

  @override
  String get anErrorOccurred => 'Ocurrió un error';

  @override
  String get unknownError => 'Error desconocido';

  @override
  String get goToHome => 'Ir al inicio';

  @override
  String get paymentSuccessfulCheckingSubscription => '✅ ¡Pago completado! Comprobando suscripción...';

  @override
  String get paymentFailed => 'Error en el pago';

  @override
  String get paymentCanceled => 'ℹ️ Pago cancelado';

  @override
  String get whatsappVerifiedSuccessfully => '✅ ¡WhatsApp verificado correctamente!';

  @override
  String get settings => 'Ajustes';

  @override
  String get enableNotificationsInSettings => 'Activa las notificaciones de Moneko en los ajustes de tu dispositivo';

  @override
  String get appearance => 'Apariencia';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get pushNotifications => 'Notificaciones push';

  @override
  String get receiveAlertsAndUpdates => 'Recibir alertas y actualizaciones';

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get membership => 'Suscripción';

  @override
  String get loading => 'Cargando...';

  @override
  String get failedToLoadMembership => 'Error al cargar la suscripción';

  @override
  String get couldNotOpenMembershipPage => 'No se pudo abrir la página de suscripción';

  @override
  String get freePlan => 'Gratis';

  @override
  String get freePlanStatus => 'Plan gratuito';

  @override
  String get lifetimePlan => 'De por vida';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusMonthlyPlan => 'Plus Mensual';

  @override
  String get plusYearlyPlan => 'Plus Anual';

  @override
  String get activeStatus => 'Activa';

  @override
  String get activeLifetimeStatus => 'Activa • De por vida';

  @override
  String get canceledStatus => 'Cancelada';

  @override
  String get pastDueStatus => 'Pago pendiente';

  @override
  String get trialStatus => 'Prueba';

  @override
  String trialEndsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return 'La prueba termina en $days $_temp0';
  }

  @override
  String get trialEnded => 'Prueba finalizada';

  @override
  String renewsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return 'Se renueva en $days $_temp0';
  }

  @override
  String accessEndsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return 'El acceso finaliza en $days $_temp0';
  }

  @override
  String get subscriptionEnded => 'Suscripción finalizada';

  @override
  String get profile => 'Perfil';

  @override
  String get errorLoadingProfile => 'Error al cargar el perfil';

  @override
  String get user => 'Usuario';

  @override
  String get proBadge => 'PRO';

  @override
  String get whatsAppConnected => 'WhatsApp conectado';

  @override
  String get logExpensesViaWhatsApp => 'Registra gastos por mensajes de WhatsApp';

  @override
  String get connectWhatsApp => 'Conectar WhatsApp';

  @override
  String get newBadge => 'NUEVO';

  @override
  String get logExpensesInstantly => 'Registra gastos al instante vía chat';

  @override
  String get fast => 'Rápido';

  @override
  String get photo => 'Foto';

  @override
  String get autoSync => 'Autosincronización';

  @override
  String get naturalLanguage => 'Lenguaje natural';

  @override
  String get describeExpenseAutomatically => 'Describe tu gasto. Lo registraremos automáticamente.';

  @override
  String get snapReceipt => 'Escanear recibo';

  @override
  String get snapReceiptDescription => 'Toma una foto de tu recibo. La IA lo extraerá y registrará.';

  @override
  String get previous => 'Anterior';

  @override
  String get next => 'Siguiente';

  @override
  String get overview => 'Resumen';

  @override
  String get activity => 'Actividad';

  @override
  String get accountInformation => 'Información de la cuenta';

  @override
  String get userId => 'ID de usuario';

  @override
  String get recentActivity => 'Actividad reciente';

  @override
  String get noActivityYet => 'Aún no hay actividad';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get insights => 'Análisis';

  @override
  String get runningTab => 'Acumulado';

  @override
  String get day30Tab => '30 días';

  @override
  String get longTermTab => 'Largo plazo';

  @override
  String get scenarioTab => 'Escenario';

  @override
  String get runningAndDailyBalances => 'Saldos acumulados y diarios';

  @override
  String get budgetVsSpentDescription => 'Presupuesto vs. Gasto diario con saldo acumulado.';

  @override
  String get runningBalanceLegend => 'Saldo acumulado';

  @override
  String get budgetLegend => 'Presupuesto';

  @override
  String get spentLegend => 'Gastado';

  @override
  String get runningBalanceGuide => 'Guía del saldo acumulado';

  @override
  String get runningBalanceIntro => 'Piensa en este gráfico como tu entrenador financiero personal. Veamos qué muestra y cómo usarlo.';

  @override
  String get day30LookAhead => 'Previsión a 30 días';

  @override
  String get projectedFromTrailing30Days => 'Proyectado en base a los promedios de los últimos 30 días.';

  @override
  String get projectedSpendingLegend => 'Gasto proyectado';

  @override
  String get peek30DaysAhead => 'Un vistazo a los próximos 30 días';

  @override
  String get day30ForecastIntro => 'Esta previsión usa la actividad del último mes para estimar cómo será el próximo. Es como el pronóstico del tiempo para tu cartera.';

  @override
  String get longTermProjection => 'Proyección a largo plazo';

  @override
  String get basedOnHistoricalAverages => 'Basado en promedios históricos; se actualiza automáticamente con tus datos.';

  @override
  String get month18ProjectionLegend => 'Proyección a 18 meses';

  @override
  String get your18MonthHorizon => 'Tu horizonte a 18 meses';

  @override
  String get longTermIntro => 'Esta proyección combina tus hábitos con supuestos de crecimiento moderado para que veas a dónde te llevan tus decisiones de hoy.';

  @override
  String get aiScenarioPlanning => 'Planificación de escenarios (IA)';

  @override
  String get askAiFinancialAdvisor => 'Pregúntale a tu asesor financiero de IA si puedes permitirte un gasto futuro';

  @override
  String get canI => '¿Puedo';

  @override
  String get before => 'antes del';

  @override
  String get beforePrefix => 'antes del';

  @override
  String get beforeSuffix => '';

  @override
  String get pickDate => 'Elige la fecha';

  @override
  String get check => 'Comprobar';

  @override
  String get enterQuestionAndPickDate => 'Por favor, haz una pregunta y elige una fecha';

  @override
  String get analyzingScenario => 'Analizando escenario...';

  @override
  String get thisMightTakeAWhile => 'Esto puede tardar un momento';

  @override
  String get whereTheMoneyWent => 'En qué se fue el dinero';

  @override
  String get categoryTotalsForSelectedRange => 'Totales por categoría para el rango seleccionado.';

  @override
  String get scenarioCategoriesGuide => 'Entiende las categorías';

  @override
  String get categoryGuideIntro => 'Imagina este gráfico como una vista de pájaro de dónde fue tu dinero. Así puedes leerlo sin necesidad de calculadora.';

  @override
  String get readTheBarChartLikeAPro => 'Lee el gráfico de barras como un experto';

  @override
  String get categoryChartDesc => 'Desglose por categoría para el período seleccionado.';

  @override
  String get whyThisViewIsHelpful => 'Por qué esta vista es útil';

  @override
  String get categoryWhyHelpfulDesc => 'Identifica rápidamente tus mayores categorías de gasto y detecta tendencias.';

  @override
  String get whatToDoWithTheInsight => 'Qué hacer con esta información';

  @override
  String get categoryWhatToDoDesc => 'Usa esta información para ajustar tu presupuesto y tus hábitos de gasto.';

  @override
  String get scenarioAnalysis => 'Análisis de escenario';

  @override
  String get target => 'Objetivo';

  @override
  String get quickStats => 'Estadísticas rápidas';

  @override
  String get currentBalance => 'Saldo actual';

  @override
  String get projectedNoChange => 'Proyectado (sin cambios)';

  @override
  String get avgDailyNet => 'Neto diario prom.';

  @override
  String get noDataAvailable => 'No hay datos disponibles';

  @override
  String get day => 'Día';

  @override
  String get close => 'Cerrar';

  @override
  String get done => 'Listo';

  @override
  String get whatYouAreSeeing => 'Qué estás viendo';

  @override
  String get whyItMatters => 'Por qué es importante';

  @override
  String get howToRespond => 'Cómo actuar';

  @override
  String get runningBalanceWhatYouSeeDesc => 'Tu saldo acumulado muestra cuánto margen tienes después de cada día de gasto. Las barras diarias muestran lo que planeaste vs. lo que realmente gastaste.';

  @override
  String get runningBalanceWhyMattersDesc => 'Tómalo como un chequeo amistoso. Te ayuda a ver si vas adelantado para seguir invirtiendo, o si necesitas corregir el rumbo para mantenerte en el buen camino.';

  @override
  String get runningBalanceHowToRespondDesc => 'Usa el gráfico como un entrenador. Celebra las ganancias, reajusta las expectativas si es necesario y sé flexible: se trata de un progreso constante, no de la perfección.';

  @override
  String get whatTheForecastShows => 'Qué muestra la previsión';

  @override
  String get day30WhatShowsDesc => 'Combinamos los últimos 30 días de gastos e ingresos para dibujar una semana promedio. Suaviza los gastos puntuales para que puedas ver el ritmo habitual.';

  @override
  String get day30WhyMattersDesc => 'Los presupuestos a futuro te ayudan a ser proactivo. Ver los días de gastos fuertes con antelación te permite reservar dinero en lugar de tener apuros más tarde.';

  @override
  String get day30HowToPlaySmartDesc => 'Tómalo como un aviso amistoso, no como reglas estrictas. Ajusta tu plan con pequeños movimientos que parezcan factibles.';

  @override
  String get howTheProjectionWorks => 'Cómo funciona la proyección';

  @override
  String get longTermHowWorksDesc => 'Proyectamos tus ingresos y gastos promedio, añadiendo un crecimiento modesto para que veas si tu plan mantiene un saldo cómodo en los próximos meses.';

  @override
  String get longTermWhyMattersDesc => 'Los horizontes largos hacen realidad los grandes sueños. Comprueba si tu fondo de emergencia, inversiones o grandes compras van por buen camino.';

  @override
  String get longTermMovesToConsiderDesc => 'Usa el gráfico para ensayar decisiones futuras. Pequeños ajustes hoy se convierten en grandes victorias mañana.';

  @override
  String get forMe => 'Para mí';

  @override
  String get forUs => 'Para nosotros';

  @override
  String get home => 'Inicio';

  @override
  String get reminder => 'Recordatorio';

  @override
  String get analyzingReceipt => 'Analizando recibo...';

  @override
  String get analyzingExpense => 'Analizando gasto...';

  @override
  String get noExpenseInformationExtracted => 'No se extrajo información del gasto';

  @override
  String get failedToAnalyzeNoData => 'Error al analizar: No se obtuvieron datos';

  @override
  String get failedToAnalyze => 'Error al analizar';

  @override
  String get updateBudget => 'Actualizar presupuesto';

  @override
  String get enterNewTotalDailyBudget => 'Introduce el nuevo presupuesto diario total.';

  @override
  String get budgetAmount => 'Importe del presupuesto';

  @override
  String get save => 'Guardar';

  @override
  String get enterValidAmountGreaterThan0 => 'Introduce un importe válido mayor que 0';

  @override
  String get updatingBudget => 'Actualizando presupuesto...';

  @override
  String get budgetUpdated => 'Presupuesto actualizado';

  @override
  String get failedToUpdateBudget => 'Error al actualizar el presupuesto';

  @override
  String get loggedSuccessfully => 'Registrado correctamente';

  @override
  String get view => 'Ver';

  @override
  String get retry => 'Reintentar';

  @override
  String get failedToCapturePhoto => 'Error al tomar la foto';

  @override
  String get noSpendingData => 'No hay datos de gastos';

  @override
  String get byCategory => 'Por categoría';

  @override
  String get noExpensesYet => 'Aún no hay gastos';

  @override
  String get startLoggingExpensesToSeeCategories => 'Empieza a registrar gastos para ver las categorías';

  @override
  String get selectDateRange => 'Seleccionar rango de fechas';

  @override
  String get addExpense => 'Añadir gasto';

  @override
  String get describeYourExpense => 'Describe tu gasto (ej: \"5 en hamburguesa, 3 en café\")';

  @override
  String get enterExpenseDetails => 'Introduce los detalles del gasto...';

  @override
  String get freeFormText => 'Texto libre';

  @override
  String get takePhoto => 'Hacer foto';

  @override
  String get transactions => 'Transacciones';

  @override
  String get negative => 'Negativo';

  @override
  String get positive => 'Positivo';

  @override
  String get spendingBreakdown => 'Desglose de gastos';

  @override
  String get spent => 'Gastado';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get lastWeek => 'Semana pasada';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get last30Days => 'Últimos 30 días';

  @override
  String get customRange => 'Rango personalizado';

  @override
  String get spentToday => 'Tus gastos de hoy';

  @override
  String get spentYesterday => 'Tus gastos de ayer';

  @override
  String get spentThisWeek => 'Tus gastos de esta semana';

  @override
  String get spentLastWeek => 'Tus gastos de la semana pasada';

  @override
  String get spentThisMonth => 'Tus gastos de este mes';

  @override
  String get spentLast30Days => 'Tus gastos (últimos 30 días)';

  @override
  String get spentCustom => 'Gastado (personalizado)';

  @override
  String get todaysBudget => 'Presupuesto de hoy';

  @override
  String get yesterdaysBudget => 'Presupuesto de ayer';

  @override
  String get sumOfDailyBudgetsThisWeek => 'Suma de presupuestos diarios de esta semana';

  @override
  String get sumOfDailyBudgetsLastWeek => 'Suma de presupuestos diarios de la semana pasada';

  @override
  String get sumOfDailyBudgetsThisMonth => 'Suma de presupuestos diarios de este mes';

  @override
  String get sumOfDailyBudgetsLast30Days => 'Suma de presupuestos diarios de los últimos 30 días';

  @override
  String get sumOfDailyBudgetsForSelectedRange => 'Suma de presupuestos diarios del rango seleccionado';

  @override
  String get netCashflowToday => 'Flujo de caja neto de hoy';

  @override
  String get netCashflowYesterday => 'Flujo de caja neto de ayer';

  @override
  String get netCashflowThisWeek => 'Flujo de caja neto de esta semana';

  @override
  String get netCashflowLastWeek => 'Flujo de caja neto de la semana pasada';

  @override
  String get netCashflowThisMonth => 'Flujo de caja neto de este mes';

  @override
  String get netCashflowLast30Days => 'Flujo de caja neto (últimos 30 días)';

  @override
  String get netCashflowCustom => 'Flujo de caja neto (personalizado)';

  @override
  String get selectCurrency => 'Seleccionar moneda';

  @override
  String get showLessCurrencies => 'Mostrar menos monedas';

  @override
  String showAllCurrencies(int count) {
    return 'Mostrar todas las monedas ($count más)';
  }

  @override
  String get budget => 'Presupuesto';

  @override
  String get spentLabel => 'Gastado';

  @override
  String get net => 'Neto';

  @override
  String get txn => 'trans.';

  @override
  String get txns => 'trans.';

  @override
  String get pleaseEnterExpenseDetails => 'Por favor, introduce los detalles del gasto';

  @override
  String get userNotLoggedIn => 'Usuario no ha iniciado sesión';

  @override
  String get errorLoadingHouseholds => 'Error al cargar los hogares';

  @override
  String get welcomeToHouseholds => 'Te damos la bienvenida a Hogares';

  @override
  String get householdsDescription => 'Gestiona las finanzas compartidas con tu familia, pareja o compañeros de piso. Controla presupuestos, divide gastos y colabora en las decisiones.';

  @override
  String get createHousehold => 'Crear grupo';

  @override
  String get joinWithInvite => 'Unirse con invitación';

  @override
  String get pleaseUseInvitationLink => 'Por favor, usa un enlace de invitación para unirte a un hogar';

  @override
  String get householdName => 'Nombre del hogar';

  @override
  String get householdNameHint => 'ej: Los García, Piso compartido';

  @override
  String get pleaseEnterHouseholdName => 'Por favor, introduce un nombre para el grupo';

  @override
  String get errorCreatingHousehold => 'Error al crear el hogar';

  @override
  String get householdsFeature => 'Función de Hogares';

  @override
  String get householdsFeatureDescription => '¡La función de Hogares ya está disponible! Gestiona finanzas compartidas con familia, pareja o compañeros.';

  @override
  String get gotIt => '¡Entendido!';

  @override
  String get confirmExpense => 'Confirmar gasto';

  @override
  String get expenseDetails => 'Detalles del gasto';

  @override
  String get details => 'Detalles';

  @override
  String get category => 'Categoría';

  @override
  String get currency => 'Moneda';

  @override
  String get date => 'Fecha';

  @override
  String get time => 'Hora';

  @override
  String get notes => 'Notas';

  @override
  String get receipt => 'Recibo';

  @override
  String get saveExpense => 'Guardar gasto';

  @override
  String get shareWithHousehold => 'Compartir con el grupo';

  @override
  String get loadingHouseholdMembers => 'Cargando miembros del grupo...';

  @override
  String get selectHouseholdToConfigureSplit => 'Selecciona un grupo para configurar la división';

  @override
  String get currencyManagedByHousehold => 'La moneda la gestiona el hogar y no se puede cambiar';

  @override
  String get currencyCannotBeChanged => 'No se puede cambiar la moneda al compartir con un hogar';

  @override
  String get failedToLoadImage => 'Error al cargar la imagen';

  @override
  String get editAmount => 'Editar importe';

  @override
  String get amount => 'Importe';

  @override
  String get editNotes => 'Editar notas';

  @override
  String get addANote => 'Añade una nota...';

  @override
  String get noMembersFoundInHousehold => 'No se encontraron miembros en el hogar';

  @override
  String get errorLoadingMembers => 'Error al cargar miembros';

  @override
  String get noExpenseToSave => 'No hay gasto que guardar';

  @override
  String expenseSavedAndShared(String splitInfo) {
    return '¡Gasto guardado y compartido$splitInfo!';
  }

  @override
  String get expenseSaved => '¡Gasto guardado!';

  @override
  String failedToSave(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String failedToSyncCurrencyPreference(Object error) {
    return 'Error al sincronizar la moneda: $error';
  }

  @override
  String get currencyUpdatedSuccessfully => 'Moneda actualizada correctamente';

  @override
  String retryFailed(Object error) {
    return 'Reintento fallido: $error';
  }

  @override
  String iSpentAmountOnCategory(Object amount, Object category, Object currencySymbol) {
    return 'Gasté $currencySymbol$amount en $category';
  }

  @override
  String get enterNewTotalDailyBudgetDescription => 'Introduce el nuevo presupuesto diario total.';

  @override
  String get pleaseSignInToAccessHouseholdFeatures => 'Por favor, inicia sesión para acceder a las funciones del hogar';

  @override
  String get quickActions => 'Acciones rápidas';

  @override
  String get members => 'Miembros';

  @override
  String get invites => 'Invitaciones';

  @override
  String get errorLoadingExpenses => 'Error al cargar los gastos';

  @override
  String get budgets => 'Presupuestos';

  @override
  String get loadingHousehold => 'Cargando hogar...';

  @override
  String get remaining => 'Restante';

  @override
  String get overBudget => 'Por encima del presupuesto';

  @override
  String get sharedBudgets => 'Presupuestos compartidos';

  @override
  String get netPosition => 'Posición neta';

  @override
  String get spentByHousehold => 'Gastos del Hogar';

  @override
  String get memberSpending => 'Gastos por Miembro';

  @override
  String get spentByHouseholdTooltip => 'Muestra el importe total gastado por todos los miembros del hogar durante el período seleccionado. Incluye todos los gastos compartidos registrados por cualquier miembro del hogar.';

  @override
  String get manageMoneyTogether => 'Gestionad el dinero juntos con vuestra pareja, familia o compañeros de piso en un espacio compartido.';

  @override
  String get sharedBudgetsExpenses => 'Presupuestos y gastos compartidos';

  @override
  String get sharedBudgetsExpensesDesc => 'Cread presupuestos, seguid los gastos y ved a dónde va el dinero del hogar en tiempo real.';

  @override
  String get smartExpenseSplitting => 'División de gastos inteligente';

  @override
  String get smartExpenseSplittingDesc => 'Calcula automáticamente quién debe qué con opciones flexibles: partes iguales, porcentaje o importes personalizados.';

  @override
  String get stayInSync => 'Manteneos sincronizados';

  @override
  String get stayInSyncDesc => 'Recibid avisos cuando se añadan gastos, se alcancen presupuestos o haya que saldar deudas.';

  @override
  String get householdSettings => 'Ajustes del grupo';

  @override
  String get householdNotFound => 'Grupo no encontrado';

  @override
  String get coverPhoto => 'Foto de portada';

  @override
  String get changeCoverPhoto => 'Cambiar foto de portada';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get errorLoadingHousehold => 'Error al cargar el grupo';

  @override
  String get householdUpdatedSuccessfully => 'Grupo actualizado correctamente';

  @override
  String get failedToUpdateHousehold => 'Error al actualizar el grupo';

  @override
  String get inviteMember => 'Invitar miembro';

  @override
  String get removeMember => 'Eliminar miembro';

  @override
  String get remove => 'Eliminar';

  @override
  String get confirmRemoveMember => '¿Seguro que quieres eliminar a';

  @override
  String get updatedMemberRole => 'Rol de miembro actualizado';

  @override
  String get unknown => 'Desconocido';

  @override
  String get makeAdmin => 'Hacer admin';

  @override
  String get makeMember => 'Hacer miembro';

  @override
  String get invitations => 'Invitaciones';

  @override
  String get errorLoadingInvites => 'Error al cargar invitaciones';

  @override
  String get createInvitation => 'Crear invitación';

  @override
  String get pendingInvitations => 'Invitaciones pendientes';

  @override
  String get noPendingInvitations => 'No hay invitaciones pendientes';

  @override
  String get invitationHistory => 'Historial de invitaciones';

  @override
  String get noInvitationHistory => 'No hay historial de invitaciones';

  @override
  String get emailOptional => 'Email (opcional)';

  @override
  String get friendEmailExample => 'amigo@ejemplo.com';

  @override
  String get personalMessageOptional => 'Mensaje personal (opcional)';

  @override
  String get joinHouseholdBudget => '¡Únete a nuestro presupuesto de grupo!';

  @override
  String get expiresIn => 'Caduca en';

  @override
  String get oneDay => '1 día';

  @override
  String get threeDays => '3 días';

  @override
  String get sevenDays => '7 días';

  @override
  String get fourteenDays => '14 días';

  @override
  String get thirtyDays => '30 días';

  @override
  String get unlimited => 'Sin límite';

  @override
  String get create => 'Crear';

  @override
  String get invitationCreatedSuccessfully => 'Invitación creada correctamente';

  @override
  String get inviteLinkCopiedToClipboard => '¡Enlace de invitación copiado al portapapeles!';

  @override
  String get errorCreatingInvite => 'Error al crear la invitación';

  @override
  String get revokeInvitation => 'Revocar invitación';

  @override
  String get confirmRevokeInvitation => '¿Seguro que quieres revocar esta invitación?';

  @override
  String get revoke => 'Revocar';

  @override
  String get invitationRevoked => 'Invitación revocada';

  @override
  String get errorRevokingInvite => 'Error al revocar la invitación';

  @override
  String get anyoneWithLink => 'Cualquiera con el enlace';

  @override
  String get noExpiry => 'No caduca';

  @override
  String get expired => 'Caducada';

  @override
  String get expires => 'Caduca';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get selectCoverImage => 'Seleccionar imagen de portada';

  @override
  String get failedToLoadImages => 'Error al cargar imágenes';

  @override
  String get chooseFromGallery => 'Elegir de la galería';

  @override
  String get failedToLoad => 'Error al cargar';

  @override
  String get imageTooLarge => 'Imagen demasiado grande';

  @override
  String get maxIs => 'El máximo es';

  @override
  String get unsupportedFileFormat => 'Formato no admitido. Usa JPG, PNG o WebP.';

  @override
  String get cropCoverImage => 'Recortar imagen de portada';

  @override
  String get editBudget => 'Editar presupuesto';

  @override
  String get budgetDetails => 'Detalles del presupuesto';

  @override
  String get budgetName => 'Nombre del presupuesto';

  @override
  String get period => 'Período';

  @override
  String get alertThresholds => 'Umbrales de alerta';

  @override
  String get warningThreshold => 'Umbral de aviso (%)';

  @override
  String get alertThreshold => 'Umbral de alerta (%)';

  @override
  String get warningThresholdHelper => 'Avisar cuando el uso del presupuesto alcance este porcentaje';

  @override
  String get alertThresholdHelper => 'Alerta crítica a este porcentaje';

  @override
  String get budgetStatus => 'Estado del presupuesto';

  @override
  String get active => 'Activo';

  @override
  String get inactive => 'Inactivo';

  @override
  String get deletingBudget => 'Eliminando presupuesto...';

  @override
  String get savingChanges => 'Guardando cambios...';

  @override
  String get budgetNameCannotBeEmpty => 'El nombre del presupuesto no puede estar vacío';

  @override
  String get pleaseEnterValidAmount => 'Por favor, introduce un importe válido';

  @override
  String get warningThresholdRange => 'El umbral de aviso debe estar entre 0 y 100';

  @override
  String get alertThresholdRange => 'El umbral de alerta debe estar entre 0 y 100';

  @override
  String get warningThresholdLessThanAlert => 'El umbral de aviso debe ser menor o igual que el umbral de alerta';

  @override
  String get deleteBudget => 'Eliminar presupuesto';

  @override
  String get confirmDeleteBudget => '¿Seguro que quieres eliminar';

  @override
  String get thisActionCannotBeUndone => 'Esta acción no se puede deshacer';

  @override
  String get budgetUpdatedSuccessfully => 'Presupuesto actualizado correctamente';

  @override
  String get budgetDeletedSuccessfully => 'Presupuesto eliminado correctamente';

  @override
  String get categoryTransfers => 'Transferencias';

  @override
  String get categoryShopping => 'Compras';

  @override
  String get categoryUtilities => 'Servicios';

  @override
  String get categoryEntertainment => 'Ocio';

  @override
  String get categoryEntertainmentSubscriptions => 'Suscripciones (Ocio)';

  @override
  String get categoryRestaurants => 'Restaurantes';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryGroceries => 'Supermercado';

  @override
  String get categoryTransport => 'Transporte';

  @override
  String get categoryTransportation => 'Transporte';

  @override
  String get categoryTravel => 'Viajes';

  @override
  String get categoryFlights => 'Vuelos';

  @override
  String get categoryVacation => 'Vacaciones';

  @override
  String get categoryHealth => 'Salud';

  @override
  String get categoryMedical => 'Médico';

  @override
  String get categoryText => 'Texto';

  @override
  String get categoryEducation => 'Educación';

  @override
  String get categoryTuition => 'Matrícula';

  @override
  String get categorySubscriptions => 'Suscripciones';

  @override
  String get categoryServices => 'Servicios';

  @override
  String get categoryHousing => 'Vivienda';

  @override
  String get categoryRent => 'Alquiler';

  @override
  String get categoryMortgage => 'Hipoteca';

  @override
  String get categoryBills => 'Facturas';

  @override
  String get categoryInsurance => 'Seguros';

  @override
  String get categorySavings => 'Ahorros';

  @override
  String get categoryInvestment => 'Inversión';

  @override
  String get categoryInvestments => 'Inversiones';

  @override
  String get categoryIncome => 'Ingresos';

  @override
  String get categorySalary => 'Salario';

  @override
  String get categoryBonus => 'Bonus';

  @override
  String get categoryPets => 'Mascotas';

  @override
  String get categoryKids => 'Hijos';

  @override
  String get categoryFamily => 'Familia';

  @override
  String get categoryGifts => 'Regalos';

  @override
  String get categoryCharity => 'Donativos';

  @override
  String get categoryFees => 'Comisiones';

  @override
  String get categoryLoan => 'Préstamo';

  @override
  String get categoryLoans => 'Préstamos';

  @override
  String get categoryDebt => 'Deuda';

  @override
  String get categoryPersonalCare => 'Cuidado personal';

  @override
  String get categoryBeauty => 'Belleza';

  @override
  String get categoryMisc => 'Varios';

  @override
  String get categoryUncategorized => 'Sin categoría';

  @override
  String get deleteBudgetCannotBeUndone => 'Esta acción no se puede deshacer';

  @override
  String get delete => 'Eliminar';

  @override
  String get failedToDeleteBudget => 'Error al eliminar el presupuesto';

  @override
  String get owner => 'Propietario/a';

  @override
  String get admin => 'Admin';

  @override
  String get member => 'Miembro';

  @override
  String get pending => 'Pendiente';

  @override
  String get accepted => 'Aceptada';

  @override
  String get revoked => 'Revocada';

  @override
  String get tapToChangeCover => 'Toca para cambiar la portada';

  @override
  String get personalMessageHint => 'Escribe un mensaje a tus invitados (ej: \"¡Únete a nuestro presupuesto de grupo!\")';

  @override
  String get invitationExpiresIn => 'La invitación caduca en';

  @override
  String daysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return '$days $_temp0';
  }

  @override
  String get createHouseholdDescription => 'Crea un espacio compartido para seguir presupuestos y gastos con familia o compañeros.';

  @override
  String get uploadingImage => 'Subiendo imagen...';

  @override
  String get creating => 'Creando...';

  @override
  String get generatingInvite => 'Generando invitación...';

  @override
  String get pleaseSelectValidCurrency => 'Por favor, selecciona una moneda válida para el grupo';

  @override
  String nameMaxLength(int max) {
    return 'El nombre debe tener menos de $max caracteres';
  }

  @override
  String get createHouseholdPage => 'Página de creación de grupo';

  @override
  String get invitationPersonalMessageInput => 'Campo de mensaje personal de invitación';

  @override
  String get householdNameInput => 'Campo de nombre de grupo';

  @override
  String get invitationExpirationSelector => 'Selector de caducidad de invitación';

  @override
  String get unlimitedExpiration => 'Caducidad ilimitada';

  @override
  String daysExpiration(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return 'Caducidad: $days $_temp0';
  }

  @override
  String get householdInformation => 'Información del grupo';

  @override
  String get creatingHousehold => 'Creando grupo';

  @override
  String get createHouseholdButton => 'Botón de crear grupo';

  @override
  String get searchExpenses => 'Buscar gastos...';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get allCategories => 'Todas las categorías';

  @override
  String get allMembers => 'Todos los miembros';

  @override
  String get balanceSummary => 'Resumen de saldos';

  @override
  String get youAreOwed => 'Te deben';

  @override
  String get youOwe => 'Debes';

  @override
  String get youOweOthers => 'Debes a otros';

  @override
  String get othersOweYou => 'Otros te deben';

  @override
  String get viewDetails => 'Ver detalles';

  @override
  String get settleUp => 'Saldar deudas';

  @override
  String get markExpensesAsSettled => 'Marca los gastos como saldados para actualizar los saldos';

  @override
  String get whoAreYouSettlingWith => '¿Con quién estás saldando cuentas?';

  @override
  String get selectMember => 'Seleccionar miembro';

  @override
  String get amountToSettle => 'Importe a saldar';

  @override
  String get howDidYouSettle => '¿Cómo lo has pagado?';

  @override
  String get cash => 'Efectivo';

  @override
  String get paidInCash => 'Pagado en efectivo';

  @override
  String get bankTransfer => 'Transferencia bancaria';

  @override
  String get transferredViaBank => 'Transferido por banco';

  @override
  String get mobilePayment => 'Pago móvil';

  @override
  String get venmoPaypalEtc => 'Bizum, PayPal, etc.';

  @override
  String get search => 'Buscar';

  @override
  String get noData => 'No hay datos';

  @override
  String get filterTransactions => 'Filtrar transacciones';

  @override
  String get noTransactionsFound => 'No se encontraron transacciones';

  @override
  String get failedToLoadHouseholdTransactions => 'Error al cargar las transacciones del grupo';

  @override
  String get reset => 'Restablecer';

  @override
  String get apply => 'Aplicar';

  @override
  String get expenses => 'Gastos';

  @override
  String get dateRange => 'Rango de fechas';

  @override
  String get noMatchingExpenses => 'No hay gastos que coincidan';

  @override
  String get startLoggingExpenses => 'Empieza a registrar gastos para verlos aquí';

  @override
  String get tryAdjustingFilters => 'Intenta ajustar los filtros';

  @override
  String get split => 'Dividir';

  @override
  String get note => 'Nota';

  @override
  String get currencyCannotBeChangedWhenSharing => 'No se puede cambiar la moneda al compartir con un grupo';

  @override
  String get createBudget => 'Crear presupuesto';

  @override
  String get pleaseEnterABudgetName => 'Por favor, introduce un nombre para el presupuesto';

  @override
  String get pleaseEnterAValidAmountGreaterThan0 => 'Por favor, introduce un importe válido mayor que 0';

  @override
  String get warningThresholdMustBeBetween0And100 => 'El umbral de aviso debe estar entre 0 y 100%';

  @override
  String get alertThresholdMustBeBetween0And100 => 'El umbral de alerta debe estar entre 0 y 100%';

  @override
  String get warningThresholdMustBeLessThanOrEqualToAlert => 'El umbral de aviso debe ser menor o igual que el umbral de alerta';

  @override
  String get budgetCreatedSuccessfully => '¡Presupuesto creado correctamente!';

  @override
  String get failedToCreateBudget => 'Error al crear el presupuesto';

  @override
  String get groceriesRentEntertainment => 'ej: Supermercado, Alquiler, Ocio';

  @override
  String get budgetType => 'Tipo de presupuesto';

  @override
  String get sharedWithAllHouseholdMembers => 'Compartido con todos los miembros del grupo';

  @override
  String get personalBudgetForYourExpensesOnly => 'Presupuesto personal solo para tus gastos';

  @override
  String get countSplitPortionOnly => 'Contar solo la parte dividida';

  @override
  String get onlyCountYourPortionOfSplitExpenses => 'Contar solo tu parte de los gastos divididos para este presupuesto';

  @override
  String get joinHousehold => 'Unirse al Hogar';

  @override
  String get joinAHousehold => 'Unirse a un Hogar';

  @override
  String get enterYourInvitationLinkToJoin => 'Ingresa tu enlace de invitación para unirte\na un espacio financiero compartido';

  @override
  String get pasteTheInvitationLinkYouReceived => 'Pega el enlace de invitación que recibiste de un miembro del hogar';

  @override
  String get pasteInvitationLink => 'Pegar enlace de invitación';

  @override
  String get pleaseEnterAnInvitationLink => 'Por favor ingresa un enlace de invitación';

  @override
  String get pleaseEnterAValidInvitationLink => 'Por favor ingresa un enlace de invitación válido';

  @override
  String get paste => 'Pegar';

  @override
  String get validating => 'Validando...';

  @override
  String get continueAction => 'Continuar';

  @override
  String get welcomeAboard => '¡Bienvenido a bordo!';

  @override
  String get youreNowPartOfTheHousehold => '¡Ahora eres parte del hogar.\nComienza a colaborar en tus finanzas!';

  @override
  String get thisWillOnlyTakeAMoment => 'Esto solo tomará un momento';

  @override
  String get unableToJoin => 'No ha sido posible unirse';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get goToHousehold => 'Ir al Hogar';

  @override
  String get expiresSoon => 'Caduca pronto';

  @override
  String invitationValidUntil(String formattedDate) {
    return 'Invitación válida hasta $formattedDate';
  }

  @override
  String get whatYoullGet => 'Lo que obtendrás';

  @override
  String get viewSharedBudgetsAndExpenses => 'Ver presupuestos y gastos compartidos';

  @override
  String get trackHouseholdFinancialHealth => 'Monitorizar la salud financiera del hogar';

  @override
  String get collaborateOnFinancialDecisions => 'Colaborar en decisiones financieras';

  @override
  String get household => 'Grupo';

  @override
  String get viewAll => 'Ver todo';

  @override
  String get manage => 'Gestionar';

  @override
  String get noBudgetsYet => 'Aún no hay presupuestos';

  @override
  String get createSharedBudgetDescription => 'Crea un presupuesto compartido para seguir los gastos juntos';

  @override
  String get errorLoadingBudgets => 'Error al cargar los presupuestos';

  @override
  String get recentSplits => 'Divisiones recientes';

  @override
  String get invite => 'Invitar';

  @override
  String get last6Months => 'Últimos 6 meses';

  @override
  String get thisYear => 'Este año';

  @override
  String get allTime => 'Desde siempre';

  @override
  String nameMinLength(int min) {
    return 'El nombre debe tener al menos $min caracteres';
  }

  @override
  String get splitExpense => 'Dividir gasto';

  @override
  String get percent => 'Porcentaje';

  @override
  String get splitShare => 'Parte';

  @override
  String get owes => 'Debe';

  @override
  String splitAmountsMustEqual(String currency, String amount) {
    return 'La suma de los importes debe ser $currency$amount';
  }

  @override
  String get percentagesMustTotal100 => 'Los porcentajes deben sumar 100%';

  @override
  String get eachPersonMustHaveAtLeast1Share => 'Cada persona debe tener al menos 1 parte';

  @override
  String get whatsappVerified => 'WhatsApp verificado';

  @override
  String get whatsappVerification => 'Verificación de WhatsApp';

  @override
  String get yourWhatsAppNumberIsSuccessfullyLinked => 'Tu número de WhatsApp se ha vinculado correctamente a tu cuenta';

  @override
  String get verifyingYourWhatsAppNumber => 'Verificando tu número de WhatsApp...';

  @override
  String get enterThe6DigitCodeFromWhatsApp => 'Introduce el código de 6 dígitos de WhatsApp';

  @override
  String get pleaseEnterThe6DigitVerificationCode => 'Por favor, introduce el código de verificación de 6 dígitos';

  @override
  String get failedToVerifyCode => 'Error al verificar el código';

  @override
  String get failedToVerifyCodePleaseTryAgain => 'Error al verificar el código. Inténtalo de nuevo.';

  @override
  String get codeAutoFilledFromVerificationLink => 'Código autocompletado desde el enlace de verificación';

  @override
  String get verify => 'Verificar';

  @override
  String get verifying => 'Verificando...';

  @override
  String get avatarStudio => 'Estudio de avatares';

  @override
  String get preview => 'Vista previa';

  @override
  String get colors => 'Colores';

  @override
  String get randomize => 'Aleatorio';

  @override
  String get saveAvatar => 'Guardar avatar';

  @override
  String get saving => 'Guardando...';

  @override
  String get skipForNow => 'Omitir por ahora';

  @override
  String get selectColor => 'Seleccionar color';

  @override
  String get failedToSaveAvatar => 'Error al guardar el avatar';

  @override
  String get hair => 'Pelo';

  @override
  String get eyes => 'Ojos';

  @override
  String get mouth => 'Boca';

  @override
  String get background => 'Fondo';

  @override
  String get face => 'Cara';

  @override
  String get ears => 'Orejas';

  @override
  String get shirts => 'Camisetas';

  @override
  String get brow => 'Cejas';

  @override
  String get nose => 'Nariz';

  @override
  String get blush => 'Colorete';

  @override
  String get accessories => 'Accesorios';

  @override
  String get stars => 'Estrellas';

  @override
  String get currencyIsManagedByHousehold => 'La moneda la gestiona el grupo y no se puede cambiar';

  @override
  String get buyALaptop => 'comprar un portátil de 1.200 \$';

  @override
  String get selectTargetDate => 'Selecciona la fecha objetivo';

  @override
  String scenarioQuestionTemplate(String action, String date) {
    return '¿Puedo $action antes del $date?';
  }

  @override
  String get scenarioDateFormat => 'dd/MM/yyyy';

  @override
  String analysisFailed(String error) {
    return 'Análisis fallido: $error';
  }

  @override
  String get leftHandChamps => 'Los primeros de la izquierda son tus pesos pesados, candidatos perfectos para una revisión.';

  @override
  String get smallButFrequent => 'Las categorías pequeñas pero frecuentes indican hábitos que pueden acumularse con el tiempo.';

  @override
  String get colorMatches => 'El color coincide con el de la pestaña Inicio para que te sea familiar.';

  @override
  String get planningNewGoal => '¿Planeando un nuevo objetivo? Detecta categorías que recortar sin tocar la diversión.';

  @override
  String get eyeingTreatYourself => '¿Pensando en un mes de caprichos? Mira qué áreas pueden flexionarse sin riesgo.';

  @override
  String get doubleCheckTagging => 'Úsalo para comprobar que los gastos nuevos están bien etiquetados, sin fantasmas.';

  @override
  String get slideHighBar => 'Baja un poco una barra alta poniendo un mini-límite o cambiando a opciones más baratas.';

  @override
  String get nonNegotiable => 'Si una barra no es negociable (hola, alquiler), planifica en torno a ella en lugar de combatirla.';

  @override
  String get revisitAfterScenario => 'Vuelve a revisar tras un escenario para ver si tus ajustes funcionan.';

  @override
  String get purpleLineCushion => 'Línea morada: el colchón que queda cada día. Si sube, estás cogiendo impulso.';

  @override
  String get blueBarsBudget => 'Barras azules: el presupuesto que fijaste para ese día.';

  @override
  String get redBarsSpent => 'Barras rojas: lo que realmente salió de tu cuenta.';

  @override
  String get lineTrendingUpward => 'Línea ascendente = dinero extra que puedes redirigir a objetivos de ahorro.';

  @override
  String get flatDippingLine => 'Línea plana o descendente = hora de parar y revisar los gastos grandes.';

  @override
  String get sharpDrops => 'Las caídas bruscas suelen ser compras no planeadas; tócalas para ver los detalles.';

  @override
  String get lineRisingDays => '¿La línea sube varios días? Considera mover un extra a ahorros o pagar deuda.';

  @override
  String get lineDippingWeekend => '¿La línea baja tras un fin de semana movido? Reequilibra los próximos días recortando pequeños gastos discrecionales.';

  @override
  String get feelStuckRed => '¿Atascado en números rojos? Revisa tu presupuesto en Inicio; los pequeños ajustes suman.';

  @override
  String get thirtyDayForecastDesc => 'Esta previsión usa la actividad del último mes para estimar cómo será el próximo. Es como el pronóstico del tiempo para tu cartera.';

  @override
  String get greenLineExpected => 'Línea verde = gasto diario esperado si el próximo mes se comporta como el último.';

  @override
  String get spikesHighlight => 'Los picos señalan semanas donde tus hábitos son más caros (hola, comida a domicilio del viernes).';

  @override
  String get forecastUpdates => 'Cuando registras nuevas transacciones, la previsión se actualiza sola, sin necesidad de refrescar.';

  @override
  String get spotExpensivePatterns => 'Detecta patrones de gasto caros con tiempo y guarda un mini-colchón antes de que lleguen.';

  @override
  String get catchQuieterWeeks => 'Aprovecha las semanas más tranquilas para pasar dinero extra a ahorros o pagar deuda.';

  @override
  String get timeRecurringPayments => 'Usa esta información para programar pagos recurrentes, suscripciones o recargas.';

  @override
  String get bigSpikeComing => '¿Viene un pico grande? Reserva opciones más baratas o mueve gastos flexibles a días más tranquilos.';

  @override
  String get forecastDipping => '¿La previsión baja? Prémiate programando una transferencia extra a tus ahorros.';

  @override
  String get forecastLooksOff => 'Si la previsión parece incorrecta, revisa las categorías en Inicio para corregir etiquetas.';

  @override
  String get greenLineTrends => 'La línea verde sigue tu tasa de ahorro típica. Si sube, tus objetivos se están financiando.';

  @override
  String get lineDipsSignals => 'Si la línea baja, indica meses futuros donde los gastos suelen superar a los ingresos.';

  @override
  String get largeGoalsDebts => 'Los grandes objetivos o deudas se incluyen cuando los etiquetas en Inicio.';

  @override
  String get upwardSlope => '¿Una pendiente ascendente? Celébralo y considera aumentar tus ahorros para la jubilación o viajes.';

  @override
  String get flatSlipping => '¿Plana o descendente? Hora de ajustar presupuestos o aumentar ingresos antes de que sea una bola de nieve.';

  @override
  String get watchSeasonalTrends => 'Vigila las tendencias estacionales: vacaciones, matrículas o renovaciones anuales suelen aparecer aquí primero.';

  @override
  String get schedulePaymentIncreases => 'Programa pequeños aumentos en los pagos de préstamos cuando la curva suba.';

  @override
  String get planAheadDips => 'Anticípate a las caídas destinando fondos de emergencia o recortando gastos opcionales.';

  @override
  String get checkProjectionMonthly => 'Revisa la proyección cada mes para que tu estrategia a largo plazo sea flexible y amena.';

  @override
  String get categoryHealthcare => 'Salud';

  @override
  String get categoryOther => 'Otros';

  @override
  String get deleteExpense => 'Eliminar gasto';

  @override
  String get confirmDeleteExpense => '¿Seguro que quieres eliminar este gasto? Esta acción no se puede deshacer.';

  @override
  String get expenseDeletedSuccessfully => 'Gasto eliminado correctamente';

  @override
  String get failedToDeleteExpense => 'Error al eliminar el gasto';

  @override
  String get expenseNotFoundOrDeleted => 'Gasto no encontrado o ya eliminado';

  @override
  String get onlyAdminsAndOwnersCanEditHouseholdSettings => 'Solo administradores y propietarios pueden editar la configuración del hogar';

  @override
  String get onlyAdminsAndOwnersCanCreateInvitations => 'Solo administradores y propietarios pueden crear invitaciones';

  @override
  String shareInvitationForHousehold(String householdName) {
    return 'Compartir invitación para el hogar $householdName';
  }

  @override
  String get shareInvitation => 'Compartir invitación';

  @override
  String householdCreatedSuccessfully(String householdName) {
    return 'Hogar $householdName creado correctamente';
  }

  @override
  String householdCreatedSuccessfullyWithQuotes(String householdName) {
    return '¡Hogar \"$householdName\" creado correctamente!';
  }

  @override
  String get invitationLink => 'Enlace de invitación';

  @override
  String invitationLinkWithUrl(String inviteUrl) {
    return 'Enlace de invitación: $inviteUrl';
  }

  @override
  String get copyInvitationLink => 'Copiar enlace de invitación';

  @override
  String get copyInvitationLinkToClipboard => 'Copiar enlace de invitación al portapapeles';

  @override
  String get shareInvitationLink => 'Compartir enlace de invitación';

  @override
  String get share => 'Compartir';

  @override
  String get closeShareSheet => 'Cerrar panel de compartir';

  @override
  String get invitationLinkCopiedToClipboard => '¡Enlace de invitación copiado al portapapeles!';

  @override
  String joinMyHouseholdMessage(String householdName, String inviteUrl) {
    return '¡Únete a mi hogar \"$householdName\" en Moneko!\n\n$inviteUrl';
  }

  @override
  String get joinMyHouseholdSubject => 'Únete a mi hogar en Moneko';

  @override
  String get zeroAmount => '0,00';

  @override
  String get dollarPrefix => '\$ ';

  @override
  String get notificationSettings => 'Configuración de notificaciones';

  @override
  String get budgetBoop => 'Toque de presupuesto';

  @override
  String get getGentleReminder => 'Recibe un recordatorio amable cuando alcances este umbral';

  @override
  String get purrSuasiveNudge => 'Ron-cordatorio';

  @override
  String get getStrongerNudge => 'Recibe un empujón más fuerte cuando alcances este umbral';

  @override
  String get createBudgetButton => 'Crear presupuesto';

  @override
  String get daily => 'Diario';

  @override
  String get weekly => 'Semanal';

  @override
  String get monthly => 'Mensual';

  @override
  String get yearly => 'Anual';

  @override
  String get householdBudgetType => 'Presupuesto del hogar';

  @override
  String get personalBudgetType => 'Presupuesto personal';

  @override
  String joinHouseholdName(String householdName) {
    return 'Unirse a \"$householdName\"';
  }

  @override
  String householdPreview(String householdName, String inviterEmail) {
    return 'Vista previa del hogar: $householdName, invitado por $inviterEmail';
  }

  @override
  String invitedBy(String inviterEmail) {
    return 'Invitado por $inviterEmail';
  }

  @override
  String invitationExpiresSoon(String formattedDate) {
    return 'La invitación caduca pronto: $formattedDate';
  }

  @override
  String get invitationValidUntilLabel => 'Invitación válida hasta';

  @override
  String get personalMessageFromInviter => 'Mensaje personal de quien te invita';

  @override
  String get messageFromInviter => 'Mensaje de quien te invita';

  @override
  String get joiningHousehold => 'Uniéndose al hogar...';

  @override
  String errorWithMessage(String errorMessage) {
    return 'Error: $errorMessage';
  }

  @override
  String get anUnexpectedErrorOccurred => 'Ocurrió un error inesperado';

  @override
  String get invalidInvitationLinkFormat => 'Formato de enlace de invitación inválido';

  @override
  String get invalidOrExpiredInvitation => 'Invitación no válida o caducada';

  @override
  String get tomorrow => 'Mañana';

  @override
  String inDays(int days) {
    return 'en $days días';
  }

  @override
  String get january => 'Ene';

  @override
  String get february => 'Feb';

  @override
  String get march => 'Mar';

  @override
  String get april => 'Abr';

  @override
  String get may => 'May';

  @override
  String get june => 'Jun';

  @override
  String get july => 'Jul';

  @override
  String get august => 'Ago';

  @override
  String get september => 'Sep';

  @override
  String get october => 'Oct';

  @override
  String get november => 'Nov';

  @override
  String get december => 'Dic';

  @override
  String remindUser(String name) {
    return 'Recordar a $name';
  }

  @override
  String get sendFriendlySpendingReminder => 'Enviar un recordatorio amistoso de gastos';

  @override
  String get addMessageOptional => 'Añadir un mensaje (opcional)';

  @override
  String get messageHintExample => 'p. ej., «¡Tu cartera necesita un descanso!»';

  @override
  String get sendReminder => 'Enviar recordatorio';

  @override
  String pleaseWait24HoursBeforeSendingAnotherReminder(String name) {
    return 'Espera 24 horas antes de enviar otro recordatorio a $name';
  }

  @override
  String reminderSentToName(String name) {
    return 'Recordatorio enviado a $name 🔔';
  }

  @override
  String get failedToSendReminderTryAgain => 'No se pudo enviar el recordatorio. Vuelve a intentarlo.';
}
