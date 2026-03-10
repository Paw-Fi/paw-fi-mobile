import 'dart:async';
import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/auth/auth.dart';
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
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'dart:io';

const _kCreatedHouseholdPrefix = 'onboarding_created_household:';
const _kCreatedInvitePrefix = 'onboarding_created_invite:';

class OnboardingAccountPreparingPage extends HookConsumerWidget {
  const OnboardingAccountPreparingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = useState(0.0);
    final progressLabel = useState('Preparing your account...');
    final setupError = useState<String?>(null);
    final isDone = useState(false);
    final didStart = useState(false);

    Future<bool> accountHasExistingData(String userId) async {
      try {
        final checks = await Future.wait<dynamic>([
          supabase
              .from('expenses')
              .select('id')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle(),
          supabase
              .from('budgets')
              .select('id')
              .eq('user_id', userId)
              .gt('total_budget_cents', 0)
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
        ]);

        return hasMeaningfulOnboardingData(
          hasExpenses: checks[0] != null,
          hasBudgetAmounts: checks[1] != null,
          hasBudgetEnvelopes: checks[2] != null,
          hasHouseholdMembership: checks[3] != null,
        );
      } catch (_) {
        return true;
      }
    }

    Future<bool> hasExistingBudgetPockets({
      required String periodMonth,
      required String currency,
      required String? householdId,
    }) async {
      final currentUser = ref.read(authProvider);
      final budgetQuery = supabase
          .from('budgets')
          .select('id')
          .eq('period_month', periodMonth)
          .eq('currency', currency);

      final budgetRow = householdId == null
          ? await budgetQuery
              .eq('user_id', currentUser.uid)
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

    Future<void> runSync() async {
      if (didStart.value || isDone.value) return;
      didStart.value = true;
      setupError.value = null;

      void setProgressState(
          {double? progressValue, String? label, bool? done}) {
        if (!context.mounted) return;
        if (progressValue != null) {
          progress.value = progressValue;
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
      final wasAlreadySynced = store.isSyncedForUser(user.uid);
      final hasExistingData = await accountHasExistingData(user.uid);
      final shouldRunOnboardingPrep = !wasAlreadySynced || !hasExistingData;
      final shouldApplyStarterSync =
          draft.wantsStarterPockets && shouldRunOnboardingPrep;

      setProgressState(
        label: 'Saving your preferences...',
        progressValue: 0.2,
      );

      if (!shouldRunOnboardingPrep) {
        setProgressState(
          progressValue: 1.0,
          label: 'We found your existing data, so we kept your current setup.',
          done: true,
        );
        return;
      }

      setProgressState(
        label: 'Applying currency and defaults...',
        progressValue: 0.55,
      );

      try {
        final selectedCurrency = draft.selectedCurrency.toUpperCase();
        ref
            .read(homeFilterProvider.notifier)
            .setSelectedCurrency(selectedCurrency);
        ref
            .read(analyticsProvider.notifier)
            .updatePreferredCurrency(selectedCurrency);
        await ref
            .read(currencyPreferenceServiceProvider)
            .setSelectedCurrency(selectedCurrency);

        final userId = supabase.auth.currentSession?.user.id;
        if (userId != null && userId.isNotEmpty) {
          await supabase.functions.invoke(
            'update-preferred-currency',
            body: {
              'currency': selectedCurrency,
              'userId': userId,
            },
          );
        }
      } catch (_) {}
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
            final inviterName = (user.displayName?.trim().isNotEmpty == true
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
      } catch (_) {}
      if (!context.mounted) return;

      setProgressState(
        label: 'Finalizing your setup...',
        progressValue: 0.85,
      );

      final preparedDraft = derivePreauthBudgetProfile(draft);

      try {
        final recommendation =
            BudgetRecommender.recommend(context, preparedDraft);
        final builtinRecommendationCategories = recommendation.pockets
            .expand((pocket) => pocket.suggestedCategories)
            .where((category) =>
                resolveBuiltinCategoryKey(context, category) != null)
            .map((category) => category.trim().toLowerCase())
            .toSet();
        if (recommendation.hasBlockingError) {
          setProgressState(
            progressValue: 0.85,
            label:
                'Building your essentials-first plan from your fixed costs...',
            done: false,
          );
        }
        if (preparedDraft.monthlyBudget > 0) {
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final periodMonth =
              '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}-01';

          final personalParams = PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: monthStart,
          );
          final selectedCurrency = preparedDraft.selectedCurrency.toUpperCase();
          final hasPersonalBudgetPockets = await hasExistingBudgetPockets(
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
        setProgressState(
          progressValue: 0.85,
          label:
              'Almost done - we hit a small hiccup creating your starter pockets. Tap try again.',
          done: false,
        );
        setupError.value = 'budget_setup_failed';
        didStart.value = false;
        return;
      }

      try {
        await store.markSyncedForUser(user.uid, preparedDraft);
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

      setProgressState(
        progressValue: 1.0,
        label: 'Your account is ready.',
        done: true,
      );
    }

    useEffect(() {
      unawaited(runSync());
      return null;
    }, const []);

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Icon(
                  setupError.value != null
                      ? Icons.auto_awesome_rounded
                      : isDone.value
                          ? Icons.check_circle_rounded
                          : Icons.auto_awesome_rounded,
                  size: 58,
                  color: setupError.value != null
                      ? colorScheme.primary
                      : isDone.value
                          ? colorScheme.success
                          : colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  setupError.value != null
                      ? 'Almost there!'
                      : isDone.value
                          ? 'Setup complete'
                          : 'Preparing your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  setupError.value != null
                      ? (setupError.value == 'budget_validation_failed'
                          ? 'Great start - your essentials plan is ready to refine. Open the dashboard and we will guide your next step.'
                          : 'You are very close - tap try again and we will finish setting everything up.')
                      : isDone.value
                          ? 'We synced your choices and personalized your setup.'
                          : 'Hang tight - we are syncing your choices and personalizing your setup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.value,
                    minHeight: 10,
                    backgroundColor:
                        colorScheme.mutedForeground.withValues(alpha: 0.2),
                    color: isDone.value
                        ? colorScheme.success
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  progressLabel.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: PrimaryAdaptiveButton(
                    onPressed: isDone.value
                        ? () => context.go('/onboarding?stage=post')
                        : setupError.value == 'budget_validation_failed'
                            ? () => context.go('/dashboard')
                            : setupError.value != null
                                ? () => unawaited(runSync())
                                : null,
                    child: Text(
                      setupError.value == 'budget_validation_failed'
                          ? 'Open dashboard'
                          : setupError.value != null
                              ? 'Try again'
                              : 'Continue',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
