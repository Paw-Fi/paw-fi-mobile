import 'dart:async';
import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/utils/household_creation_utils.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/onboarding_account_sync_policy.dart';
import 'package:moneko/features/onboarding/domain/onboarding_budget_sync_service.dart';
import 'package:moneko/features/onboarding/domain/budget_recommender.dart';
import 'package:moneko/features/onboarding/domain/preauth_budget_profile.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/subscription/presentation/iap_restore_polling.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/animated_pulsing_icon.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/shimmering_text.dart';
import 'package:moneko/shared/widgets/trial_welcome_dialog.dart';
import 'dart:io';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

const _kCreatedHouseholdPrefix = 'onboarding_created_household:';
const _kCreatedInvitePrefix = 'onboarding_created_invite:';
const _kBudgetSyncFailurePrefix = 'onboarding_budget_sync_failures:';
const _kCurrencySyncTimeout = Duration(seconds: 8);
const _kPaywallReturnTrialGrantedPrefix = 'paywall_return_trial:';
const _kSubscriptionRefreshTimeout = Duration(seconds: 10);
const _kAppStoreRestoreTimeout = Duration(seconds: 16);
const _kTrialGrantTimeout = Duration(seconds: 20);
const _kPostGrantRefreshTimeout = Duration(seconds: 8);
const _kTrialGrantProgressUpdateInterval = Duration(milliseconds: 750);
const _kTrialGrantProgressStart = 0.1;
const _kTrialGrantProgressCap = 0.6;

double onboardingSubscriptionPreparationVisualProgress(Duration elapsed) {
  final progress = _kTrialGrantProgressStart +
      elapsed.inMilliseconds /
          _kTrialGrantTimeout.inMilliseconds *
          (_kTrialGrantProgressCap - _kTrialGrantProgressStart);
  return progress
      .clamp(_kTrialGrantProgressStart, _kTrialGrantProgressCap)
      .toDouble();
}

class OnboardingSubscriptionCompletionCopy {
  const OnboardingSubscriptionCompletionCopy({
    required this.progressLabel,
    required this.title,
    required this.body,
  });

  final String progressLabel;
  final String title;
  final String body;
}

OnboardingSubscriptionCompletionCopy onboardingCompletionCopyForSubscription({
  required AppLocalizations l10n,
  required SubscriptionDetails? details,
}) {
  final subscription = details?.subscription;
  if ((subscription?.isSubscribed ?? false) &&
      (subscription?.provider == 'app_store' ||
          subscription?.appStoreInAppOwnershipType != null)) {
    if (subscription?.isAppStoreFamilyShared ?? false) {
      return OnboardingSubscriptionCompletionCopy(
        progressLabel: l10n.onboardingPreparingProgressFamilySharingRestored,
        title: l10n.onboardingPreparingTitleFamilySharingRestored,
        body: l10n.onboardingPreparingBodyFamilySharingRestored,
      );
    }

    return OnboardingSubscriptionCompletionCopy(
      progressLabel: l10n.onboardingPreparingProgressAppStoreRestored,
      title: l10n.onboardingPreparingTitleAppStoreRestored,
      body: l10n.onboardingPreparingBodyAppStoreRestored,
    );
  }

  return OnboardingSubscriptionCompletionCopy(
    progressLabel: l10n.onboardingPreparingProgressReady,
    title: l10n.onboardingPreparingTitleDone,
    body: l10n.onboardingPreparingBodyDone,
  );
}

class _ExistingAccountState {
  const _ExistingAccountState({
    required this.hasExpenses,
    required this.hasBudgetAmounts,
    required this.hasBudgetEnvelopes,
    required this.hasHouseholdMembership,
    required this.hasSubscriptionData,
  });

  const _ExistingAccountState.safeFallback()
      : hasExpenses = true,
        hasBudgetAmounts = true,
        hasBudgetEnvelopes = true,
        hasHouseholdMembership = true,
        hasSubscriptionData = false;

  final bool hasExpenses;
  final bool hasBudgetAmounts;
  final bool hasBudgetEnvelopes;
  final bool hasHouseholdMembership;
  final bool hasSubscriptionData;

  bool get hasMeaningfulData => hasMeaningfulOnboardingData(
        hasExpenses: hasExpenses,
        hasBudgetAmounts: hasBudgetAmounts,
        hasBudgetEnvelopes: hasBudgetEnvelopes,
        hasHouseholdMembership: hasHouseholdMembership,
      );

  bool get hasBudgetData => hasBudgetAmounts || hasBudgetEnvelopes;

  bool get isExternalSubscriptionNewUser =>
      hasSubscriptionData && !hasMeaningfulData && !hasBudgetData;
}

class OnboardingAccountPreparingPage extends HookConsumerWidget {
  const OnboardingAccountPreparingPage({
    super.key,
    this.autoStart = true,
  });

  final bool autoStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final progress = useState(0.0);
    final progressLabel = useState(l10n.onboardingPreparingProgressInitial);
    final setupError = useState<String?>(null);
    final isDone = useState(false);
    final completionCopy =
        useState<OnboardingSubscriptionCompletionCopy?>(null);
    final didStart = useState(false);
    final isPrimaryActionEnabled = isDone.value || setupError.value != null;
    final isGrantingOnboardingTrial = useRef(false);

    useEffect(() {
      return null;
    }, const []);

    Future<void> applyCurrencyDefaults({
      required String fallbackUserId,
      required OnboardingPreauthDraft draft,
    }) async {
      try {
        final selectedCurrency = draft.selectedCurrency.trim().toUpperCase();
        if (selectedCurrency.isEmpty) {
          debugPrint(
            '[OnboardingPrep] No preauth currency selected, skipping currency sync',
          );
          return;
        }

        final currencyPreferenceService =
            ref.read(currencyPreferenceServiceProvider);
        final storedSelectedCurrencies =
            await currencyPreferenceService.getSelectedCurrencies();
        final seenCurrencies = <String>{};
        final normalizedSelectedCurrencies = <String>[];
        for (final value in [selectedCurrency, ...?storedSelectedCurrencies]) {
          final code = value.trim().toUpperCase();
          if (code.isEmpty || seenCurrencies.contains(code)) continue;
          seenCurrencies.add(code);
          normalizedSelectedCurrencies.add(code);
        }

        ref
            .read(homeFilterProvider.notifier)
            .setSelectedCurrency(selectedCurrency);
        ref
            .read(homeFilterProvider.notifier)
            .setSelectedCurrencies(normalizedSelectedCurrencies);
        ref
            .read(analyticsProvider.notifier)
            .updatePreferredCurrency(selectedCurrency);
        await currencyPreferenceService.setSelectedCurrency(selectedCurrency);
        await currencyPreferenceService
            .setSelectedCurrencies(normalizedSelectedCurrencies);

        final userId = supabase.auth.currentSession?.user.id ?? fallbackUserId;
        if (userId.isEmpty) {
          debugPrint(
            '[OnboardingPrep] Missing user id, skipping backend currency sync',
          );
          return;
        }

        final response = await supabase.functions.invoke(
          'update-preferred-currency',
          body: {
            'currency': selectedCurrency,
            'userId': userId,
          },
        ).timeout(_kCurrencySyncTimeout);

        if (response.status >= 400) {
          throw Exception(
            'Preferred currency sync returned ${response.status}',
          );
        }

        final payloadData = response.data;
        if (payloadData is! Map) {
          throw Exception('Preferred currency sync returned invalid payload');
        }

        final payload = Map<String, dynamic>.from(payloadData);
        if (payload['ok'] != true) {
          throw Exception(
            'Preferred currency sync response was not ok: ${payload['error'] ?? 'unknown_error'}',
          );
        }
      } on TimeoutException {
        debugPrint(
          '[OnboardingPrep] Preferred currency sync timed out after $_kCurrencySyncTimeout',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[OnboardingPrep] Preferred currency sync failed: $error\n$stackTrace',
        );
      }
    }

    Future<_ExistingAccountState> loadExistingAccountState(
        String userId) async {
      try {
        final checks = await Future.wait<dynamic>([
          supabase
              .from('expenses')
              .select('id')
              .eq('user_id', userId)
              .isFilter('deleted_at', null)
              .limit(1)
              .maybeSingle(),
          supabase
              .from('budgets')
              .select('id')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle(),
          supabase
              .from('budget_envelopes')
              .select('id')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle(),
          supabase
              .from('household_members')
              .select('household_id')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle(),
          supabase
              .from('subscriptions')
              .select('id')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle(),
        ]);

        return _ExistingAccountState(
          hasExpenses: checks[0] != null,
          hasBudgetAmounts: checks[1] != null,
          hasBudgetEnvelopes: checks[2] != null,
          hasHouseholdMembership: checks[3] != null,
          hasSubscriptionData: checks[4] != null,
        );
      } catch (_) {
        return const _ExistingAccountState.safeFallback();
      }
    }

    Future<bool> hasExistingBudgetPockets({
      required String userId,
      required String periodMonth,
      required String currency,
      required String? householdId,
    }) async {
      final budgetQuery = supabase
          .from('budgets')
          .select('id')
          .eq('period_month', periodMonth)
          .eq('currency', currency);

      final budgetRow = householdId == null
          ? await budgetQuery
              .eq('user_id', userId)
              .isFilter('household_id', null)
              .limit(1)
              .maybeSingle()
          : await budgetQuery
              .eq('household_id', householdId)
              .limit(1)
              .maybeSingle();

      final budgetId = budgetRow?['id'] as String?;
      if (budgetId == null || budgetId.isEmpty) {
        return false;
      }

      final envelopeRow = await supabase
          .from('budget_envelopes')
          .select('id')
          .eq('budget_id', budgetId)
          .limit(1)
          .maybeSingle();

      return envelopeRow != null;
    }

    Future<bool> hasCompleteBudgetSetup({
      required String userId,
      required String periodMonth,
      required String currency,
      required String? householdId,
      required int? expectedPocketCount,
    }) async {
      final budgetQuery = supabase
          .from('budgets')
          .select('id')
          .eq('period_month', periodMonth)
          .eq('currency', currency);

      final budgetRow = householdId == null
          ? await budgetQuery
              .eq('user_id', userId)
              .isFilter('household_id', null)
              .limit(1)
              .maybeSingle()
          : await budgetQuery
              .eq('household_id', householdId)
              .limit(1)
              .maybeSingle();

      final budgetId = budgetRow?['id'] as String?;
      if (budgetId == null || budgetId.isEmpty) {
        return false;
      }

      final envelopeRows = await supabase
          .from('budget_envelopes')
          .select('id')
          .eq('budget_id', budgetId);
      final envelopeIds = (envelopeRows as List?)
              ?.cast<Map<String, dynamic>>()
              .map((row) => row['id'] as String?)
              .whereType<String>()
              .toList() ??
          const <String>[];
      if (envelopeIds.isEmpty) {
        return false;
      }

      final minimumExpectedEnvelopes =
          expectedPocketCount != null && expectedPocketCount > 0
              ? expectedPocketCount
              : 1;
      if (envelopeIds.length < minimumExpectedEnvelopes) {
        return false;
      }

      final allocationRows = await supabase
          .from('envelope_allocations')
          .select('envelope_id')
          .eq('period_month', periodMonth)
          .inFilter('envelope_id', envelopeIds);

      final allocatedEnvelopeIds = (allocationRows as List?)
              ?.cast<Map<String, dynamic>>()
              .map((row) => row['envelope_id'] as String?)
              .whereType<String>()
              .toSet() ??
          const <String>{};
      return allocatedEnvelopeIds.length >= minimumExpectedEnvelopes;
    }

    Future<bool> hasRequiredStarterBudgets({
      required String userId,
      required OnboardingPreauthDraft preparedDraft,
      required String? createdHouseholdId,
      required bool shouldApplyStarterSync,
      required int? expectedPocketCount,
    }) async {
      if (!shouldApplyStarterSync || preparedDraft.monthlyBudget <= 0) {
        return true;
      }

      final financialMonthStartDay = ref.read(financialMonthStartDayProvider);
      final monthStart = financialCycleStartForDate(
        DateTime.now(),
        startDay: financialMonthStartDay,
      );
      final periodMonth = formatFinancialPeriodDate(
        DateTime(monthStart.year, monthStart.month, 1),
      );
      final selectedCurrency = preparedDraft.selectedCurrency.toUpperCase();

      final hasPersonalBudgetPockets = await hasCompleteBudgetSetup(
        userId: userId,
        periodMonth: periodMonth,
        currency: selectedCurrency,
        householdId: null,
        expectedPocketCount: expectedPocketCount,
      );
      if (!hasPersonalBudgetPockets) {
        return false;
      }

      if (createdHouseholdId == null || createdHouseholdId.isEmpty) {
        return true;
      }

      return hasCompleteBudgetSetup(
        userId: userId,
        periodMonth: periodMonth,
        currency: selectedCurrency,
        householdId: createdHouseholdId,
        expectedPocketCount: expectedPocketCount,
      );
    }

    String paywallReturnTrialGrantedKey(String userId) =>
        '$_kPaywallReturnTrialGrantedPrefix$userId:granted';

    Future<bool?> hasSubscriptionRow(String userId) async {
      try {
        final row = await supabase
            .from('subscriptions')
            .select('id')
            .eq('user_id', userId)
            .limit(1)
            .maybeSingle();
        return row != null;
      } catch (error, stackTrace) {
        debugPrint(
          '[OnboardingPrep] hasSubscriptionRow failed: $error\n$stackTrace',
        );
        return null;
      }
    }

    Future<bool> restoreAppStoreSubscriptionIfAvailable() async {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;

      try {
        await ref
            .read(subscriptionProductsProvider.future)
            .timeout(_kSubscriptionRefreshTimeout);

        final iapState = await ref
            .read(iapControllerProvider.future)
            .timeout(_kSubscriptionRefreshTimeout);
        if (!iapState.storeAvailable) {
          debugPrint(
            '[OnboardingPrep] App Store restore skipped because StoreKit is unavailable',
          );
          return false;
        }

        return await restoreAndWaitForIapSubscription(
          restorePurchases: () => ref
              .read(iapControllerProvider.notifier)
              .restorePurchases()
              .timeout(_kAppStoreRestoreTimeout),
          refreshSubscription: () async {
            await ref
                .read(subscriptionManagementProvider.notifier)
                .refresh()
                .timeout(_kSubscriptionRefreshTimeout);
            await ref
                .read(subscriptionNotifierProvider.notifier)
                .refresh()
                .timeout(_kSubscriptionRefreshTimeout);
          },
          hasActiveSubscription: () {
            final subscriptionDetails =
                ref.read(subscriptionManagementProvider).valueOrNull;
            return subscriptionDetails?.hasActiveSubscription ?? false;
          },
          restoreError: () =>
              ref.read(iapControllerProvider).valueOrNull?.lastError ?? '',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[OnboardingPrep] App Store restore check skipped: $error\n$stackTrace',
        );
        return false;
      }
    }

    Future<bool> ensureOnboardingSubscription({
      required String userId,
      required _ExistingAccountState existingState,
      required void Function({
        double? progressValue,
        String? label,
        bool? done,
      }) setProgressState,
    }) async {
      if (isGrantingOnboardingTrial.value) return false;

      final prefs = ref.read(sharedPreferencesProvider);
      final alreadyGrantedLocally =
          prefs.getBool(paywallReturnTrialGrantedKey(userId)) ?? false;

      await restoreAppStoreSubscriptionIfAvailable();

      await ref
          .read(subscriptionManagementProvider.notifier)
          .refresh()
          .timeout(_kSubscriptionRefreshTimeout, onTimeout: () {
        debugPrint(
          '[OnboardingPrep] subscriptionManagement refresh timed out after $_kSubscriptionRefreshTimeout',
        );
      });
      await ref
          .read(subscriptionNotifierProvider.notifier)
          .refresh()
          .timeout(_kSubscriptionRefreshTimeout, onTimeout: () {
        debugPrint(
          '[OnboardingPrep] subscriptionNotifier refresh timed out after $_kSubscriptionRefreshTimeout',
        );
      });

      final subscriptionDetails =
          ref.read(subscriptionManagementProvider).valueOrNull;
      final hasActiveSubscription =
          subscriptionDetails?.hasActiveSubscription ?? false;
      if (hasActiveSubscription) {
        debugPrint(
          '[OnboardingPrep] Active subscription detected; skipping onboarding trial bootstrap',
        );
        return true;
      }

      final hasSubscriptionNow = await hasSubscriptionRow(userId);
      if (hasSubscriptionNow == null) {
        debugPrint(
          '[OnboardingPrep] Subscription row check unavailable; skipping onboarding trial bootstrap',
        );
        return false;
      }
      if (hasSubscriptionNow || existingState.hasSubscriptionData) {
        debugPrint(
          '[OnboardingPrep] Existing non-active subscription found; leaving account unchanged for resubscribe flow',
        );
        return true;
      }

      if (alreadyGrantedLocally) {
        debugPrint(
          '[OnboardingPrep] Local grant marker exists but no server subscription row was found; retrying activation',
        );
        await prefs.remove(paywallReturnTrialGrantedKey(userId));
      }

      isGrantingOnboardingTrial.value = true;
      try {
        setProgressState(
          progressValue: _kTrialGrantProgressStart,
          label: l10n
              .onboardingPreparingProgressInitial, // Use general word instead of activating free trial text
        );
        debugPrint(
          '[OnboardingPrep] No subscription detected; activating onboarding free trial',
        );
        await ref
            .read(subscriptionManagementProvider.notifier)
            .grantPaywallReturnTrial()
            .timeout(_kTrialGrantTimeout);

        try {
          await ref
              .read(subscriptionManagementProvider.notifier)
              .refresh()
              .timeout(_kPostGrantRefreshTimeout);
          await ref
              .read(subscriptionNotifierProvider.notifier)
              .refresh()
              .timeout(_kPostGrantRefreshTimeout);
        } catch (refreshError, refreshStackTrace) {
          debugPrint(
            '[OnboardingPrep] Post-grant refresh failed: $refreshError\n$refreshStackTrace',
          );
        }

        final hasGrantedSubscription = await hasSubscriptionRow(userId);
        if (hasGrantedSubscription != true) {
          throw Exception(
              'Free trial activation did not create a subscription row');
        }

        await prefs.setBool(paywallReturnTrialGrantedKey(userId), true);
        await prefs.setBool(trialWelcomePendingKey(userId), true);
        return true;
      } on TimeoutException catch (error, stackTrace) {
        debugPrint(
          '[OnboardingPrep] Free trial activation timed out: $error\n$stackTrace',
        );
      } catch (error, stackTrace) {
        final message = error.toString().toLowerCase();
        if (message.contains('already granted') ||
            message.contains('already has active subscription access')) {
          final hasGrantedSubscription = await hasSubscriptionRow(userId);
          if (hasGrantedSubscription == true) {
            await prefs.setBool(paywallReturnTrialGrantedKey(userId), true);
            await prefs.setBool(trialWelcomePendingKey(userId), true);
            return true;
          }
        }
        debugPrint(
          '[OnboardingPrep] Free trial activation failed: $error\n$stackTrace',
        );
        return false;
      } finally {
        isGrantingOnboardingTrial.value = false;
      }
      return false;
    }

    Future<void> runSync() async {
      if (didStart.value || isDone.value) return;
      didStart.value = true;
      setupError.value = null;
      completionCopy.value = null;

      void setProgressState(
          {double? progressValue, String? label, bool? done}) {
        if (!context.mounted) return;
        if (progressValue != null) {
          progress.value =
              progressValue > progress.value ? progressValue : progress.value;
        }
        if (label != null) {
          progressLabel.value = label;
        }
        if (done != null) {
          isDone.value = done;
        }
      }

      final user = ref.read(authProvider);
      if (user.uid.isEmpty) {
        if (context.mounted) {
          context.go('/login');
        }
        return;
      }

      final store = ref.read(onboardingPreauthDraftStoreProvider);
      final draft = store.load();
      final prefs = ref.read(sharedPreferencesProvider);
      final now = DateTime.now();
      final budgetSyncScope =
          '${now.year}-${now.month.toString().padLeft(2, '0')}:${draft.selectedCurrency.trim().toUpperCase()}:${draft.wantsSharedSpace}:${draft.wantsStarterPockets}';
      final budgetSyncFailureKey =
          '$_kBudgetSyncFailurePrefix${user.uid}:$budgetSyncScope';
      final wasAlreadySynced = store.isSyncedForUser(user.uid);
      setProgressState(progressValue: _kTrialGrantProgressStart);
      final subscriptionPreparationStartedAt = DateTime.now();
      final subscriptionPreparationTimer = Timer.periodic(
        _kTrialGrantProgressUpdateInterval,
        (_) => setProgressState(
          progressValue: onboardingSubscriptionPreparationVisualProgress(
            DateTime.now().difference(subscriptionPreparationStartedAt),
          ),
        ),
      );
      late final _ExistingAccountState existingState;
      late final bool hasRequiredSubscription;
      try {
        existingState = await loadExistingAccountState(user.uid);
        hasRequiredSubscription = await ensureOnboardingSubscription(
          userId: user.uid,
          existingState: existingState,
          setProgressState: setProgressState,
        );
      } finally {
        subscriptionPreparationTimer.cancel();
      }
      if (!hasRequiredSubscription) {
        setProgressState(
          progressValue: 0.1,
          label: l10n.onboardingPreparingProgressErrorRetry,
          done: false,
        );
        setupError.value = 'subscription_setup_failed';
        didStart.value = false;
        return;
      }
      final hasExistingData = existingState.hasMeaningfulData;
      final shouldRunOnboardingPrep = !wasAlreadySynced || !hasExistingData;
      final shouldApplyStarterSync =
          draft.wantsStarterPockets && shouldRunOnboardingPrep;

      setProgressState(
        label: l10n.onboardingPreparingProgressSavingPreferences,
        progressValue: 0.2,
      );

      if (!shouldRunOnboardingPrep) {
        if (context.mounted) {
          context.go('/dashboard');
        }
        return;
      }

      setProgressState(
        label: l10n.onboardingPreparingProgressApplyingDefaults,
        progressValue: 0.55,
      );

      await applyCurrencyDefaults(
        fallbackUserId: user.uid,
        draft: draft,
      );
      if (!context.mounted) return;

      // If user selected a shared space in pre-auth onboarding,
      // create the shared space and optional invite now that auth exists.
      String? createdHouseholdId =
          prefs.getString('$_kCreatedHouseholdPrefix${user.uid}');
      if (createdHouseholdId != null && createdHouseholdId.isNotEmpty) {
        try {
          await ref.read(userHouseholdsProvider(user.uid).notifier).load();
          final households =
              ref.read(userHouseholdsProvider(user.uid)).valueOrNull ??
                  const [];
          final exists =
              households.any((household) => household.id == createdHouseholdId);
          if (!exists) {
            createdHouseholdId = null;
            await prefs.remove('$_kCreatedHouseholdPrefix${user.uid}');
            await prefs.remove('$_kCreatedInvitePrefix${user.uid}');
          }
        } catch (_) {
          createdHouseholdId = null;
        }
      }
      try {
        if (draft.wantsSharedSpace &&
            draft.spaceName.trim().isNotEmpty &&
            (createdHouseholdId == null || createdHouseholdId.isEmpty)) {
          String? coverImageUrl = draft.spaceImageUrl.trim().isNotEmpty
              ? draft.spaceImageUrl
              : null;

          final localImagePath = draft.spaceImagePath.trim();
          if (localImagePath.isNotEmpty) {
            final imageFile = File(localImagePath);
            if (await imageFile.exists()) {
              coverImageUrl = await HouseholdCreationUtils.uploadImageWithRetry(
                  imageFile, user.uid);
            }
          }

          final repository = ref.read(householdRepositoryProvider);
          final createdHousehold = await repository.createHousehold(
            name: draft.spaceName.trim(),
            currency: draft.selectedCurrency.toUpperCase(),
            coverImageUrl: coverImageUrl,
            isPortfolio: false,
          );

          // Refresh households first so Home header/pill can resolve
          // and display the newly created shared space immediately.
          ref.invalidate(userHouseholdsProvider(user.uid));
          await ref.read(userHouseholdsProvider(user.uid).notifier).load();

          await ref
              .read(selectedHouseholdProvider.notifier)
              .selectHousehold(createdHousehold.id);
          createdHouseholdId = createdHousehold.id;
          await prefs.setString(
            '$_kCreatedHouseholdPrefix${user.uid}',
            createdHousehold.id,
          );
          ref.read(viewModeProvider.notifier).setMode(ViewMode.household);

          final inviteEmail = draft.inviteEmail.trim();
          final inviteMessage = draft.inviteMessage.trim();
          final inviteCreated =
              prefs.getBool('$_kCreatedInvitePrefix${user.uid}') ?? false;
          if ((inviteEmail.isNotEmpty || inviteMessage.isNotEmpty) &&
              !inviteCreated) {
            UserProfile? profile;
            if (user.uid.isNotEmpty) {
              try {
                profile = await ref.read(userProfileProvider(user.uid).future);
              } catch (_) {}
            }
            final inviterName = (profile?.fullName?.trim().isNotEmpty == true
                    ? profile!.fullName
                    : user.displayName?.trim().isNotEmpty == true
                        ? user.displayName
                        : user.email)
                ?.trim();
            await repository.createInvite(
              householdId: createdHousehold.id,
              invitedEmail: inviteEmail.isNotEmpty ? inviteEmail : null,
              personalMessage: inviteMessage.isNotEmpty ? inviteMessage : null,
              inviterName: inviterName?.isNotEmpty == true ? inviterName : null,
              householdName: createdHousehold.name,
              expiresInDays: draft.inviteExpiresInDays,
            );
            await prefs.setBool('$_kCreatedInvitePrefix${user.uid}', true);
          }
        } else if (createdHouseholdId != null &&
            createdHouseholdId.isNotEmpty) {
          await ref
              .read(selectedHouseholdProvider.notifier)
              .selectHousehold(createdHouseholdId);
          ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
        }
      } catch (error) {
        if (ErrorHandler.isPlusFeatureLimitError(error) && context.mounted) {
          await PlusLockedSheet.show(
            context,
            highlightedFeature: PlusFeature.spaceCreation,
          );
        }
      }
      if (!context.mounted) return;

      setProgressState(
        label: context.l10n.onboardingPreparingProgressFinalizing,
        progressValue: 0.85,
      );

      final preparedDraft = derivePreauthBudgetProfile(draft);
      int? expectedPocketCount;

      try {
        final recommendation =
            BudgetRecommender.recommend(context, preparedDraft);
        expectedPocketCount = recommendation.pockets.length;
        final builtinRecommendationCategories = recommendation.pockets
            .expand((pocket) => pocket.suggestedCategories)
            .where((category) =>
                resolveBuiltinCategoryKey(context, category) != null)
            .map((category) => category.trim().toLowerCase())
            .toSet();
        if (recommendation.hasBlockingError) {
          setProgressState(
            progressValue: 0.85,
            label: context.l10n.onboardingPreparingProgressEssentialsFallback,
            done: false,
          );
        }
        if (preparedDraft.monthlyBudget > 0) {
          final financialMonthStartDay =
              ref.read(financialMonthStartDayProvider);
          final monthStart = financialCycleStartForDate(
            DateTime.now(),
            startDay: financialMonthStartDay,
          );
          final periodMonth = formatFinancialPeriodDate(
            DateTime(monthStart.year, monthStart.month, 1),
          );

          final personalParams = PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: monthStart,
            financialMonthStartDay: financialMonthStartDay,
          );
          final selectedCurrency = preparedDraft.selectedCurrency.toUpperCase();
          final hasPersonalBudgetPockets = await hasExistingBudgetPockets(
            userId: user.uid,
            periodMonth: periodMonth,
            currency: selectedCurrency,
            householdId: null,
          );
          if (shouldApplyStarterSync &&
              shouldCreateStarterBudget(
                forceSync: !wasAlreadySynced,
                hasExistingBudgetPockets: hasPersonalBudgetPockets,
              )) {
            await OnboardingBudgetSyncService.createStarterBudget(
              ref: ref,
              scopeParams: personalParams,
              userId: user.uid,
              selectedCurrency: selectedCurrency,
              totalBudget: preparedDraft.monthlyBudget,
              pockets: recommendation.pockets,
              builtinCategoryNames: builtinRecommendationCategories,
            );
          }

          if (createdHouseholdId != null && createdHouseholdId.isNotEmpty) {
            final hasHouseholdBudgetPockets = await hasExistingBudgetPockets(
              userId: user.uid,
              periodMonth: periodMonth,
              currency: selectedCurrency,
              householdId: createdHouseholdId,
            );
            if (shouldApplyStarterSync &&
                shouldCreateStarterBudget(
                  forceSync: !wasAlreadySynced,
                  hasExistingBudgetPockets: hasHouseholdBudgetPockets,
                )) {
              final householdParams = PocketsScopeParams(
                scope: PocketsScopeType.household,
                householdId: createdHouseholdId,
                periodMonth: monthStart,
                financialMonthStartDay: financialMonthStartDay,
              );
              await OnboardingBudgetSyncService.createStarterBudget(
                ref: ref,
                scopeParams: householdParams,
                userId: user.uid,
                selectedCurrency: selectedCurrency,
                totalBudget: preparedDraft.monthlyBudget,
                pockets: recommendation.pockets,
                builtinCategoryNames: builtinRecommendationCategories,
              );
            }
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Onboarding starter budget sync failed: $error\n$stackTrace',
        );

        bool hasRequiredBudgets = false;
        try {
          hasRequiredBudgets = await hasRequiredStarterBudgets(
            userId: user.uid,
            preparedDraft: preparedDraft,
            createdHouseholdId: createdHouseholdId,
            shouldApplyStarterSync: shouldApplyStarterSync,
            expectedPocketCount: expectedPocketCount,
          );
        } catch (verificationError, verificationStack) {
          debugPrint(
            'Onboarding starter budget verification failed: $verificationError\n$verificationStack',
          );
        }

        if (hasRequiredBudgets) {
          debugPrint(
            '[OnboardingPrep] Starter budget verification passed after sync error, continuing setup.',
          );
        } else {
          final previousFailures = prefs.getInt(budgetSyncFailureKey) ?? 0;
          final nextFailures = previousFailures + 1;
          try {
            await prefs.setInt(budgetSyncFailureKey, nextFailures);
          } catch (_) {}

          final shouldAllowDashboardFallback = nextFailures >= 2;
          var canUseDashboardFallback = shouldAllowDashboardFallback;
          if (shouldAllowDashboardFallback) {
            try {
              await store.markSyncedForUser(user.uid, preparedDraft);
            } catch (syncMarkError, syncMarkStack) {
              debugPrint(
                'Onboarding fallback sync marker failed: $syncMarkError\n$syncMarkStack',
              );
              canUseDashboardFallback = false;
            }
          }
          setProgressState(
            progressValue: 0.85,
            label: canUseDashboardFallback
                ? l10n.onboardingPreparingProgressErrorDashboard
                : l10n.onboardingPreparingProgressErrorRetry,
            done: false,
          );
          setupError.value = canUseDashboardFallback
              ? 'budget_validation_failed'
              : 'budget_setup_failed';
          didStart.value = false;
          return;
        }

        try {
          await prefs.remove(budgetSyncFailureKey);
        } catch (_) {}
      }

      try {
        await store.markSyncedForUser(user.uid, preparedDraft);
        await prefs.remove(budgetSyncFailureKey);
        await prefs.setString(
          'onboarding_profile:${user.uid}',
          jsonEncode(
            {
              'monthlyBudget': preparedDraft.monthlyBudget,
              'wantsSharedSpace': draft.wantsSharedSpace,
              'spaceName': draft.spaceName,
              'spaceImageUrl': draft.spaceImageUrl,
              'inviteEmail': draft.inviteEmail,
              'inviteMessage': draft.inviteMessage,
              'inviteExpiresInDays': draft.inviteExpiresInDays,
              'wantsStarterPockets': draft.wantsStarterPockets,
            },
          ),
        );
      } catch (_) {}
      if (!context.mounted) return;

      final doneCopy = onboardingCompletionCopyForSubscription(
        l10n: context.l10n,
        details: ref.read(subscriptionManagementProvider).valueOrNull,
      );
      completionCopy.value = doneCopy;

      setProgressState(
        progressValue: 1.0,
        label: doneCopy.progressLabel,
        done: true,
      );
    }

    useEffect(() {
      if (!autoStart) {
        return null;
      }
      unawaited(runSync());
      return null;
    }, [autoStart]);

    Future<void> onPrimaryActionTap() async {
      if (isDone.value || setupError.value == 'budget_validation_failed') {
        if (context.mounted) {
          context.go('/dashboard');
        }
        return;
      }

      if (setupError.value != null) {
        await runSync();
      }
    }

    final isLoading = setupError.value == null && !isDone.value;
    final title = setupError.value != null
        ? context.l10n.onboardingPreparingTitleError
        : isDone.value
            ? completionCopy.value?.title ??
                context.l10n.onboardingPreparingTitleDone
            : context.l10n.onboardingPreparingTitleLoading;
    final body = setupError.value != null
        ? (setupError.value == 'budget_validation_failed'
            ? context.l10n.onboardingPreparingBodyErrorDashboard
            : context.l10n.onboardingPreparingBodyErrorRetry)
        : isDone.value
            ? completionCopy.value?.body ??
                context.l10n.onboardingPreparingBodyDone
            : context.l10n.onboardingPreparingBodyLoading;

    return StatusBarOverlayRegion(
      child: AdaptiveScaffold(
        appBar: null,
        body: SafeArea(
          child: Material(
            color: colorScheme.appBackground,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PreparingIllustration(
                          progress: progress.value,
                          hasError: setupError.value != null,
                          colorScheme: colorScheme,
                        ),
                        if (isLoading) ...[
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: ShimmeringText(
                              text: progressLabel.value,
                              key: ValueKey(progressLabel.value),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.mutedForeground,
                              ),
                              shimmering: true,
                            ),
                          ),
                        ],
                        if (!isLoading) ...[
                          const SizedBox(height: 26),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              title,
                              key: ValueKey(title),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.foreground,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              body,
                              key: ValueKey(body),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.mutedForeground,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 36),
                        if (isPrimaryActionEnabled)
                          SizedBox(
                            height: 52,
                            child: PrimaryAdaptiveButton(
                              onPressed: () => unawaited(onPrimaryActionTap()),
                              child: Text(context.l10n.continueAction),
                            ),
                          ),
                        if (kDebugMode && isPrimaryActionEnabled)
                          Semantics(
                            button: true,
                            label: context.l10n.retry,
                            child: TextButton.icon(
                              onPressed: () {
                                progress.value = _kTrialGrantProgressStart;
                                progressLabel.value = context
                                    .l10n.onboardingPreparingProgressInitial;
                                setupError.value = null;
                                completionCopy.value = null;
                                isDone.value = false;
                              },
                              icon: const Icon(Icons.bug_report_outlined),
                              label: Text(context.l10n.retry),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparingIllustration extends StatelessWidget {
  const _PreparingIllustration({
    required this.progress,
    required this.hasError,
    required this.colorScheme,
  });

  final double progress;
  final bool hasError;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isComplete = !hasError && progress >= 1.0;
    final statusIcon = hasError
        ? Icons.error_outline_rounded
        : isComplete
            ? Icons.check_circle_rounded
            : null;

    return SizedBox(
      height: 200,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _PreparingProgressRing(
              progress: progress,
              color: hasError
                  ? colorScheme.destructive
                  : isComplete
                      ? colorScheme.success
                      : colorScheme.primary,
              size: 200,
            ),
            if (statusIcon == null)
              AnimatedPulsingIcon(
                color: colorScheme.primary,
                containerSize: 96,
                iconSize: 32,
              )
            else
              Icon(
                statusIcon,
                size: 56,
                color: hasError ? colorScheme.destructive : colorScheme.success,
              ),
          ],
        ),
      ),
    );
  }
}

class _PreparingProgressRing extends StatelessWidget {
  const _PreparingProgressRing({
    required this.progress,
    required this.color,
    required this.size,
  });

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _PreparingProgressRingPainter(
          progress: value,
          color: color,
        ),
      ),
    );
  }
}

class _PreparingProgressRingPainter extends CustomPainter {
  const _PreparingProgressRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    const pi = 3.141592653589793;
    canvas.drawArc(bounds, 0, 2 * pi, false, trackPaint);

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * pi * progress;
    const startAngle = -pi / 2;
    if (sweep > 0) {
      canvas.drawArc(bounds, startAngle, sweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(_PreparingProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
