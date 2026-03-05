import 'dart:async';
import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/utils/household_creation_utils.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/budget_recommender.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'dart:io';

class OnboardingAccountPreparingPage extends HookConsumerWidget {
  const OnboardingAccountPreparingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = useState(0.0);
    final progressLabel = useState('Preparing your account...');
    final isDone = useState(false);
    final didStart = useState(false);

    Future<void> runSync() async {
      if (didStart.value || isDone.value) return;
      didStart.value = true;

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

      setProgressState(
        label: 'Saving your preferences...',
        progressValue: 0.2,
      );

      await store.markSyncedForUser(user.uid, draft);
      if (!context.mounted) return;

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
      String? createdHouseholdId;
      try {
        if (draft.wantsSharedSpace && draft.spaceName.trim().isNotEmpty) {
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
          ref.read(viewModeProvider.notifier).setMode(ViewMode.household);

          final inviteEmail = draft.inviteEmail.trim();
          final inviteMessage = draft.inviteMessage.trim();
          if (inviteEmail.isNotEmpty || inviteMessage.isNotEmpty) {
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
          }
        }
      } catch (_) {}
      if (!context.mounted) return;

      setProgressState(
        label: 'Finalizing your setup...',
        progressValue: 0.85,
      );

      try {
        final recommendation = BudgetRecommender.recommend(draft);
        if (!recommendation.hasBlockingError && draft.monthlyBudget > 0) {
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final periodMonth =
              '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}-01';

          Future<bool> hasExistingBudget(String? householdId) async {
            final query = supabase
                .from('budgets')
                .select('id')
                .eq('period_month', periodMonth);

            if (householdId == null) {
              final row = await query
                  .eq('user_id', user.uid)
                  .isFilter('household_id', null)
                  .limit(1)
                  .maybeSingle();
              return row != null;
            }

            final row = await query
                .eq('household_id', householdId)
                .limit(1)
                .maybeSingle();
            return row != null;
          }

          final personalParams = PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: monthStart,
          );
          final hasPersonalBudget = await hasExistingBudget(null);
          if (!hasPersonalBudget) {
            await ref
                .read(pocketsProvider(personalParams).notifier)
                .createBudgetFromTemplate(
                  totalBudget: draft.monthlyBudget,
                  pockets: recommendation.pockets,
                );
          }

          if (createdHouseholdId != null && createdHouseholdId.isNotEmpty) {
            final hasHouseholdBudget =
                await hasExistingBudget(createdHouseholdId);
            if (!hasHouseholdBudget) {
              final householdParams = PocketsScopeParams(
                scope: PocketsScopeType.household,
                householdId: createdHouseholdId,
                periodMonth: monthStart,
              );
              await ref
                  .read(pocketsProvider(householdParams).notifier)
                  .createBudgetFromTemplate(
                    totalBudget: draft.monthlyBudget,
                    pockets: recommendation.pockets,
                  );
            }
          }
        }
      } catch (_) {}

      try {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setString(
          'onboarding_profile:${user.uid}',
          jsonEncode(
            {
              'monthlyBudget': draft.monthlyBudget,
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
                  isDone.value
                      ? Icons.check_circle_rounded
                      : Icons.auto_awesome_rounded,
                  size: 58,
                  color:
                      isDone.value ? colorScheme.success : colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  isDone.value ? 'Setup complete' : 'Preparing your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isDone.value
                      ? 'We synced your choices and personalized your setup.'
                      : 'Please wait a moment while we sync your onboarding answers.',
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
                        : null,
                    child: const Text('Continue'),
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
