import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/households/presentation/pages/create_space_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_finish_page.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/create_budget_from_template_sheet.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

const _kOnboardingCompletedPrefix = 'onboarding_completed:'; // per-user
const _kNotificationsPromptedPrefix = 'notifications_prompted:'; // per-user

class OnboardingFlowPage extends HookConsumerWidget {
  const OnboardingFlowPage({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();
    final currentPage = useState(0);
    final colorScheme = Theme.of(context).colorScheme;
    final notificationFlowStarted = useState(false);
    final notificationFlowCompleted = useState(false);
    final aiLogSuccess = useState<AiLogSuccess?>(null);
    // Step 4: editable group name captured here so footer CTA can pass it
    final groupName = useState<String>('');
    // Track whether user created a space in Step 3
    final didCreateSpace = useState(false);
    // Track whether user created a pocket in Step 4
    final pocketCreated = useState(false);
    const totalSteps = 6;

    void goToPage(int targetPage) {
      if (!context.mounted) return;
      void go() {
        unawaited(pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ));
      }

      if (pageController.hasClients) {
        go();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (!pageController.hasClients) return;
          go();
        });
      }
    }

    Future<void> showFinishPage() async {
      if (!context.mounted) return;
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const OnboardingFinishPage(),
          fullscreenDialog: true,
        ),
      );
      if (done == true && context.mounted) {
        await _completeOnboarding(context, ref);
      }
    }

    void next() {
      if (!context.mounted) return;
      if (currentPage.value < totalSteps - 1) {
        final targetPage = currentPage.value + 1;
        goToPage(targetPage);
      } else {
        unawaited(showFinishPage());
      }
    }

    void skip() => next(); // Now skip goes to next step instead of exiting

    Future<void> handleNotificationsFlow() async {
      if (!context.mounted) return;
      if (notificationFlowStarted.value || notificationFlowCompleted.value) {
        if (notificationFlowCompleted.value) {
          next();
        }
        return;
      }

      notificationFlowStarted.value = true;
      final uid = ref.read(authProvider).uid;
      final prefs = ref.read(sharedPreferencesProvider);
      final deviceRegistration = ref.read(deviceRegistrationServiceProvider);
      try {
        final promptedKey = '$_kNotificationsPromptedPrefix$uid';
        final prompted = prefs.getBool(promptedKey) ?? false;
        if (!prompted) {
          await prefs.setBool(promptedKey, true);
        }

        if (!context.mounted) return;

        try {
          await deviceRegistration.initialize();
        } catch (_) {}

        if (!context.mounted) return;

        notificationFlowCompleted.value = true;
        next();
      } finally {
        if (context.mounted) {
          notificationFlowStarted.value = false;
        }
      }
    }

    Future<void> primary() async {
      if (currentPage.value == 0) {
        // Step 1 (Currency): persist current selection (or USD) and advance immediately
        final filter = ref.read(homeFilterProvider);
        final selectedCurrency =
            (filter.selectedCurrency ?? 'USD').toUpperCase();

        // Update UI state first
        ref
            .read(homeFilterProvider.notifier)
            .setSelectedCurrency(selectedCurrency);
        ref
            .read(analyticsProvider.notifier)
            .updatePreferredCurrency(selectedCurrency);

        // Navigate to next step immediately (do not block on IO)
        next();

        // Fire-and-forget local preference write and backend sync
        unawaited(() async {
          try {
            await ref
                .read(currencyPreferenceServiceProvider)
                .setSelectedCurrency(selectedCurrency);
          } catch (_) {}
          if (supabase.auth.currentSession != null) {
            try {
              final userId = supabase.auth.currentSession?.user.id;
              if (userId == null || userId.isEmpty) {
                return;
              }
              final response = await supabase.functions.invoke(
                'update-preferred-currency',
                body: {
                  'currency': selectedCurrency,
                  'userId': userId,
                },
              );
              if (response.status >= 400) {
                debugPrint(
                    'update-preferred-currency failed: ${response.status}');
                return;
              }
              final payload = response.data;
              final ok = payload is Map && payload['ok'] == true;
              if (!ok) {
                debugPrint(
                    'update-preferred-currency returned unexpected payload: $payload');
              }
            } catch (_) {}
          }
        }());
        return;
      }

      if (currentPage.value == 1) {
        // Step 2: persist budget then continue
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final scopeParams = PocketsScopeParams(
            scope: PocketsScopeType.personal, periodMonth: monthStart);
        await ref.read(pocketsProvider(scopeParams).notifier).saveChanges();
        next();
        return;
      }

      if (currentPage.value == 2) {
        // Step 3: prompt notifications then advance to Step 4
        await handleNotificationsFlow();
        return;
      }

      if (currentPage.value == 3) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CreateSpacePage(
              key: UniqueKey(),
              initialName: groupName.value,
              fromOnboarding: true,
            ),
            fullscreenDialog: true,
          ),
        );
        // Always return to onboarding after space creation
        if (result == true) {
          didCreateSpace.value = true;
          next();
        }
        return;
      }

      if (currentPage.value == 4) {
        // Pockets intro step
        if (pocketCreated.value) {
          next();
          return;
        }
        // Resolve scope based on whether user created a space
        final selectedHousehold = ref.read(selectedHouseholdProvider);
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final scopeParams = didCreateSpace.value &&
                selectedHousehold.householdId != null
            ? PocketsScopeParams(
                scope: PocketsScopeType.household,
                householdId: selectedHousehold.householdId,
                periodMonth: monthStart,
              )
            : PocketsScopeParams(
                scope: PocketsScopeType.personal,
                periodMonth: monthStart,
              );

        // Open template sheet for pocket creation (it handles budget input too)
        if (!context.mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
          builder: (context) => CreateBudgetFromTemplateSheet(
            scopeParams: scopeParams,
          ),
        );
        // After sheet closes, check if pockets were created
        final updatedState = ref.read(pocketsProvider(scopeParams));
        if (updatedState.editing.isNotEmpty) {
          pocketCreated.value = true;
        }
        return;
      }

      // Default: advance to next step
      next();
    }

    useEffect(() {
      if (currentPage.value == 2) {
        unawaited(handleNotificationsFlow());
      }
      return null;
    }, [currentPage.value]);

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => currentPage.value = i,
                  children: [
                    // IMPORTANT: Only build the current step.
                    // PageView keeps offstage pages alive; building all steps
                    // can trigger heavy providers/services during tests and
                    // early onboarding frames.
                    currentPage.value == 0
                        ? const _CurrencyStep()
                        : const SizedBox.shrink(),
                    currentPage.value == 1
                        ? const _BudgetStep()
                        : const SizedBox.shrink(),
                    currentPage.value == 2
                        ? const _NotificationsStep()
                        : const SizedBox.shrink(),
                    currentPage.value == 3
                        ? _HouseholdStep(
                            name: groupName.value,
                            onNameChanged: (v) => groupName.value = v,
                          )
                        : const SizedBox.shrink(),
                    currentPage.value == 4
                        ? _PocketsIntroStep(
                            didCreateSpace: didCreateSpace.value,
                            pocketCreated: pocketCreated.value,
                          )
                        : const SizedBox.shrink(),
                    currentPage.value == 5
                        ? _AiLogStep(
                            onSuccess: (success) =>
                                aiLogSuccess.value = success,
                            lastSuccess: aiLogSuccess.value,
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalSteps, (i) {
                        final bool active = currentPage.value == i;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 18 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? colorScheme.primary
                                : colorScheme.mutedForeground
                                    .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: PrimaryAdaptiveButton(
                        onPressed: () {
                          // Fire-and-forget call to async handler to avoid type mismatch
                          // and ensure reliable button taps
                          unawaited(primary());
                        },
                        child: Text(
                          currentPage.value == 0
                              ? context.l10n.setCurrency
                              : currentPage.value == 1
                                  ? context.l10n.setBudget
                                  : currentPage.value == 2
                                      ? context.l10n.turnOnNotifications
                                      : currentPage.value == 3
                                          ? context.l10n.createSpace
                                          : currentPage.value == 4
                                              ? (pocketCreated.value
                                                  ? context.l10n.continueAction
                                                  : context.l10n
                                                      .pocketsIntroUseTemplate)
                                              : (aiLogSuccess.value != null
                                                  ? context.l10n.continueAction
                                                  : context.l10n.tryNow),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlainAdaptiveButton(
                      onPressed:
                          (currentPage.value == 5 && aiLogSuccess.value != null)
                              ? null
                              : skip,
                      child: Text(
                        context.l10n.skipNow,
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markOnboardingCompleted(WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final uid = ref.read(authProvider).uid;
    await prefs.setBool('$_kOnboardingCompletedPrefix$uid', true);
  }

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    await _markOnboardingCompleted(ref);
    if (!context.mounted) return;
    if (fromSettings) {
      Navigator.of(context).pop();
    } else {
      context.go('/dashboard');
    }
  }
}

class _CurrencyStep extends HookConsumerWidget {
  const _CurrencyStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected =
        ref.watch(homeFilterProvider).selectedCurrency?.toUpperCase() ?? 'USD';
    final flagPath = getCurrencyFlagPath(selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            context.l10n.selectCurrencyForDailySpending,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding1.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.currency,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      await showCurrencySelectorModal(
                        context,
                        ref,
                        showAllByDefault: true,
                      );
                      final user = ref.read(authProvider);
                      if (user.uid.isNotEmpty) {
                        ref.read(analyticsProvider.notifier).refresh(user.uid);

                        final currentView = ref.read(viewModeProvider);
                        final selectedHousehold =
                            ref.read(selectedHouseholdProvider);
                        final householdId =
                            currentView.mode == ViewMode.household
                                ? selectedHousehold.householdId
                                : null;
                        ref
                            .read(recurringTransactionsProvider(householdId)
                                .notifier)
                            .refresh(user.uid);
                        ref.invalidate(pocketsProvider);
                      }
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colorScheme.selectedStateBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colorScheme.controlBorder,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.spotlightShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (flagPath != null) ...[
                            ClipOval(
                              child: Image.asset(
                                flagPath,
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          if (flagPath != null) const SizedBox(width: 8),
                          Text(
                            selected,
                            style: TextStyle(
                              color: colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: colorScheme.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStep extends HookConsumerWidget {
  const _BudgetStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Personal current month scope
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final scopeParams = PocketsScopeParams(
        scope: PocketsScopeType.personal, periodMonth: monthStart);
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);

    final currency =
        (ref.watch(homeFilterProvider).selectedCurrency ?? 'USD').toUpperCase();

    final total = state.totalBudget;
    final prev = state.previousBudget;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.createSpendingLimitForCategory,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding2.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          PocketsHeaderCard(
            totalBudget: total,
            totalAllocated: state.saved
                .fold<double>(0.0, (s, p) => s + (p.budgetAmountCents / 100.0)),
            totalSpent: state.totalSpent,
            periodMonth: state.periodMonth,
            previousBudget: prev,
            onReusePrevious:
                prev > 0 ? () => notifier.reusePreviousBudget(prev) : null,
            colorScheme: colorScheme,
            onTotalChanged: notifier.updateTotalBudget,
            onSave: () async => notifier.saveChanges(),
            currency: currency,
            onDateSelected: (_) {},
          ),
        ],
      ),
    );
  }
}

class _NotificationsStep extends HookConsumerWidget {
  const _NotificationsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.getNotifiedBeforeSpendingLimit,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding3.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          // Sample notification card (visual only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.border.withValues(alpha: 0.06), width: 1),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_active_rounded,
                      size: 16, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.newMessage,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground)),
                      const SizedBox(height: 2),
                      Text(context.l10n.closeToSpendingLimit,
                          style: TextStyle(color: colorScheme.mutedForeground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdStep extends HookConsumerWidget {
  const _HouseholdStep({required this.name, required this.onNameChanged});

  final String name;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(text: name);
    useEffect(() {
      void listener() => onNameChanged(controller.text);
      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.inviteOthersToShareBudget,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SvgPicture.asset(
                'lib/assets/images/onboarding/onboarding4.svg',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            // Visual create-a-group card with editable name
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.06), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.createSpace,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.mutedForeground),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: context.l10n.householdNameHint,
                      hintStyle: TextStyle(
                          color:
                              colorScheme.mutedForeground.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: colorScheme.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: colorScheme.border.withValues(alpha: 0.12),
                            width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: colorScheme.border.withValues(alpha: 0.12),
                            width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PocketsIntroStep extends HookConsumerWidget {
  const _PocketsIntroStep({
    required this.didCreateSpace,
    required this.pocketCreated,
  });

  final bool didCreateSpace;
  final bool pocketCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currency =
        (ref.watch(homeFilterProvider).selectedCurrency ?? 'USD').toUpperCase();

    // Watch pockets state for success detection
    final selectedHousehold = ref.watch(selectedHouseholdProvider);
    final monthStart = DateTime(now.year, now.month, 1);
    final scopeParams = didCreateSpace &&
            selectedHousehold.householdId != null
        ? PocketsScopeParams(
            scope: PocketsScopeType.household,
            householdId: selectedHousehold.householdId,
            periodMonth: monthStart,
          )
        : PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: monthStart,
          );
    final pocketsState = ref.watch(pocketsProvider(scopeParams));

    // Staggered animation for mock cards
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    useEffect(() {
      animController.forward();
      return null;
    }, []);

    // Mock pocket data using user's currency
    final mockPockets = useMemoized(
      () => [
      PocketEnvelope(
          id: 'mock-1',
          name: 'Groceries',
          budgetAmountCents: 50000,
          spent: 325,
          currency: currency,
          icon: 'shopping_bag',
          color: '#FF2D55', // iOS System Pink (High energy, appetizing)
          budgetId: null,
          householdId: null,
          lastUpdated: now,
        ),
        PocketEnvelope(
          id: 'mock-2',
          name: 'Dining Out',
          budgetAmountCents: 30000,
          spent: 120,
          currency: currency,
          icon: 'restaurant',
          color: '#AF52DE', // iOS System Purple (Premium, social)
          budgetId: null,
          householdId: null,
          lastUpdated: now,
        ),
        PocketEnvelope(
          id: 'mock-3',
          name: 'Transport',
          budgetAmountCents: 20000,
          spent: 160,
          currency: currency,
          icon: 'directions_car',
          color: '#FF9500', // iOS System Orange (Warning/Action, fits travel)
          budgetId: null,
          householdId: null,
          lastUpdated: now,
        ),
        PocketEnvelope(
          id: 'mock-4',
          name: 'Fun',
          budgetAmountCents: 20000,
          spent: 50,
          currency: currency,
          icon: 'celebration',
          color: '#007AFF', // iOS System Blue (Trustworthy, clean)
          budgetId: null,
          householdId: null,
          lastUpdated: now,
        ),
      ],
      [currency],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              context.l10n.pocketsIntroTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 10),
            // Subtitle
            Text(
              context.l10n.pocketsIntroSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Benefit chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BenefitChip(
                    icon: Icons.category_rounded,
                    label: context.l10n.pocketsIntroBenefitTrack,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _BenefitChip(
                    icon: Icons.shield_rounded,
                    label: context.l10n.pocketsIntroBenefitLimit,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _BenefitChip(
                    icon: Icons.bar_chart_rounded,
                    label: context.l10n.pocketsIntroBenefitVisual,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mock pocket grid with staggered animation
            if (!pocketCreated)
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(mockPockets.length, (index) {
                  final interval = Interval(
                    index * 0.15,
                    (index * 0.15 + 0.5).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic,
                  );
                  return AnimatedBuilder(
                    animation: animController,
                    builder: (context, child) {
                      final value = interval.transform(animController.value);
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: IgnorePointer(
                      child: PocketCard(
                        pocket: mockPockets[index],
                        colorScheme: colorScheme,
                        totalBudget: 1200,
                        envelopeMode: true,
                      ),
                    ),
                  );
                }),
              ),

            // Success state: show real pockets
            if (pocketCreated && pocketsState.editing.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.successSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.successBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: colorScheme.success, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${pocketsState.editing.length} pocket${pocketsState.editing.length > 1 ? 's' : ''} created!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expands [ParsedExpense] items so that each breakdown line becomes its own
/// display entry. Items without a breakdown are kept as-is.
List<ParsedExpense> _expandBreakdownItems(List<ParsedExpense> items) {
  final result = <ParsedExpense>[];
  final amountRe = RegExp(r'[\d]+[.,]?\d*');

  for (final item in items) {
    final breakdown = item.breakdown;
    if (breakdown == null || breakdown.length < 2) {
      result.add(item);
      continue;
    }

    for (final line in breakdown) {
      // Try to extract amount from the breakdown string (e.g. "burger €5.00")
      final match = amountRe.allMatches(line).lastOrNull;
      final amount = match != null
          ? double.tryParse(match.group(0)!.replaceAll(',', '.'))
          : null;

      // Description is everything before the amount match, stripped of
      // currency symbols and whitespace.
      final desc = match != null
          ? line.substring(0, match.start).replaceAll(RegExp(r'[€\$£¥₹]'), '').trim()
          : line.trim();

      result.add(item.copyWith(
        description: desc.isNotEmpty ? desc : item.description,
        amount: amount ?? item.amount / breakdown.length,
        breakdown: null,
      ));
    }
  }
  return result;
}

class _AiLogStep extends HookConsumerWidget {
  const _AiLogStep({required this.onSuccess, required this.lastSuccess});

  final ValueChanged<AiLogSuccess> onSuccess;
  final AiLogSuccess? lastSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final success = lastSuccess;
    final items = success != null
        ? _expandBreakdownItems(success.items)
        : const <ParsedExpense>[];
    final hasSuccess = success != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: hasSuccess
                  ? const SizedBox.shrink()
                  : Column(
                      key: const ValueKey('ai-log-intro'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.tryAiLoggingTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          context.l10n.tryAiLoggingSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.homeCardSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.homeCardBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.homeCardShadow,
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _AiActionChip(
                                    icon: Icons.edit_rounded,
                                    label: context.l10n.freeFormText,
                                    onTap: () async {
                                      await handleAiFreeFormText(
                                        context,
                                        ref,
                                        onSuccess: onSuccess,
                                      );
                                    },
                                  ),
                                  _AiActionChip(
                                    icon: Icons.camera_alt_rounded,
                                    label: context.l10n.takePhoto,
                                    onTap: () async {
                                      await handleAiCameraCapture(
                                        context,
                                        ref,
                                        onSuccess: onSuccess,
                                      );
                                    },
                                  ),
                                  _AiActionChip(
                                    icon: Icons.mic_rounded,
                                    label: context.l10n.textAudio,
                                    onTap: () async {
                                      await handleAiFreeFormText(
                                        context,
                                        ref,
                                        onSuccess: onSuccess,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _AiActionRow(
                                icon: Icons.attach_file_rounded,
                                label: context.l10n.files,
                                subtitle: context.l10n.tryAiLoggingFilesHint,
                                onTap: () async {
                                  await handleAiFileOrGallery(
                                    context,
                                    ref,
                                    onSuccess: onSuccess,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          context.l10n.aiPromptExamplesTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.homeCardSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.homeCardBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.homeCardShadow,
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.aiPromptExamplesDescription,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.mutedForeground,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _AiPromptChip(
                                    text: context.l10n.aiPromptExample1,
                                  ),
                                  _AiPromptChip(
                                    text: context.l10n.aiPromptExample2,
                                  ),
                                  _AiPromptChip(
                                    text: context.l10n.aiPromptExample3,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (success != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: colorScheme.successSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.successBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.success.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.celebration_rounded,
                          color: colorScheme.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.aiFirstLogCongratsTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.aiFirstLogCongratsBody(
                      items.length,
                      success.targetLabel,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.aiLogSummaryTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.homeCardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.homeCardBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.homeCardShadow,
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (int i = 0; i < items.take(5).length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 56,
                        color: colorScheme.border.withValues(alpha: 0.08),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TransactionListTile(
                        category: items[i].category,
                        title: getCategoryTranslation(context, items[i].category),
                        description: items[i].description,
                        subtitle: DateFormat.yMMMd(
                          intlSafeLocaleName(Localizations.localeOf(context)),
                        ).format(items[i].date),
                        amount: items[i].amount,
                        currency: items[i].currency,
                        isIncome: items[i].isIncome,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.aiLogSummaryMore(items.length - 5),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0,vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: colorScheme.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.aiCapabilitiesHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _AiPromptChip extends StatelessWidget {
  const _AiPromptChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        '"'+text+'"',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.foreground,
        ),
      ),
    );
  }
}

class _AiActionChip extends StatelessWidget {
  const _AiActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiActionRow extends StatelessWidget {
  const _AiActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.border.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
