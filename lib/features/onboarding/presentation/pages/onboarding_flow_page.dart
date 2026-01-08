import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/pages/household_create_page.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import '../../../../core/l10n/l10n.dart';
import 'package:moneko/core/resources/lib/supabase.dart';


const _kOnboardingCompletedPrefix = 'onboarding_completed:'; // per-user
const _kNotificationsPromptedPrefix = 'notifications_prompted:'; // per-user

class OnboardingFlowPage extends HookConsumerWidget {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();
    final currentPage = useState(0);
    final colorScheme = Theme.of(context).colorScheme;
    // Step 4: editable group name captured here so footer CTA can pass it
    final groupName = useState<String>('');

    void next() {
      if (!context.mounted) return;
      if (currentPage.value < 3) {
        final targetPage = currentPage.value + 1;
        void go() {
          pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
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
      } else {
        _completeOnboarding(context, ref);
      }
    }

    void skip() => _completeOnboarding(context, ref);

    Future<void> primary() async {
      if (currentPage.value == 0) {
        // Step 1 (Currency): persist current selection (or USD) and advance immediately
        final user = ref.read(authProvider);
        final filter = ref.read(homeFilterProvider);
        final selectedCurrency =
            (filter.selectedCurrency ?? 'USD').toUpperCase();

        // Update UI state first
        ref.read(homeFilterProvider.notifier).setSelectedCurrency(selectedCurrency);
        ref.read(analyticsProvider.notifier).updatePreferredCurrency(selectedCurrency);

        // Navigate to next step immediately (do not block on IO)
        next();

        // Fire-and-forget local preference write and backend sync
        Future(() async {
          try {
            await ref
                .read(currencyPreferenceServiceProvider)
                .setSelectedCurrency(selectedCurrency);
          } catch (_) {}
          if (user.uid.isNotEmpty) {
            try {
              await supabase.functions.invoke(
                'update-preferred-currency',
                body: {
                  'userId': user.uid,
                  'currency': selectedCurrency,
                },
              );
            } catch (_) {}
          }
        });
        return;
      }

      if (currentPage.value == 1) {
        // Step 2: persist budget then continue
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final scopeParams =
            PocketsScopeParams(scope: PocketsScopeType.personal, periodMonth: monthStart);
        await ref.read(pocketsProvider(scopeParams).notifier).saveChanges();
        next();
        return;
      }

      if (currentPage.value == 2) {
        // Step 3: prompt notifications then advance to Step 4
        final uid = ref.read(authProvider).uid;
        final prefs = ref.read(sharedPreferencesProvider);
        final promptedKey = '$_kNotificationsPromptedPrefix$uid';
        final prompted = prefs.getBool(promptedKey) ?? false;
        if (!prompted) {
          await prefs.setBool(promptedKey, true);
        }
        try {
          await ref.read(deviceRegistrationServiceProvider).initialize();
        } catch (_) {}
        next();
        return;
      }

      if (currentPage.value == 3) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HouseholdCreatePage(
              key: UniqueKey(),
              // prefill name from onboarding
              initialName: groupName.value,
              fromOnboarding: true,
            ),
            fullscreenDialog: true,
          ),
        );
        return;
      }

      // Default: advance to next step
      next();
    }

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
                  onPageChanged: (i) => currentPage.value = i,
                  children: [
                    const _CurrencyStep(),
                    const _BudgetStep(),
                    const _NotificationsStep(),
                    _HouseholdStep(
                      name: groupName.value,
                      onNameChanged: (v) => groupName.value = v,
                    ),
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
                      children: List.generate(4, (i) {
                        final bool active = currentPage.value == i;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 18 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? colorScheme.primary
                                : colorScheme.mutedForeground.withValues(alpha: 0.3),
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
                          primary();
                        },
                        child: Text(
                          currentPage.value == 0
                              ? context.l10n.setCurrency
                              : currentPage.value == 1
                                  ? context.l10n.setBudget
                                  : currentPage.value == 2
                                      ? context.l10n.turnOnNotifications
                                      : context.l10n.inviteWithLinks,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlainAdaptiveButton(
                      onPressed: skip,
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

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final uid = ref.read(authProvider).uid;
    await prefs.setBool('$_kOnboardingCompletedPrefix$uid', true);
    if (context.mounted) context.go('/dashboard');
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
                        final selectedHousehold = ref.read(selectedHouseholdProvider);
                        final householdId = currentView.mode == ViewMode.household
                            ? selectedHousehold.householdId
                            : null;
                        ref
                            .read(recurringTransactionsProvider(householdId).notifier)
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
                          if (flagPath != null)
                            const SizedBox(width: 8),
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
    final scopeParams =
        PocketsScopeParams(scope: PocketsScopeType.personal, periodMonth: monthStart);
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);

    final currency = (ref.watch(homeFilterProvider).selectedCurrency ?? 'USD')
        .toUpperCase();

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
            totalAllocated: state.saved.fold(0.0, (s, p) => s + p.percentage) / 100.0 * (total > 0 ? total : 0),
            totalSpent: state.totalSpent,
            periodMonth: state.periodMonth,
            previousBudget: prev,
            onReusePrevious: prev > 0 ? () => notifier.reusePreviousBudget(prev) : null,
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
              border: Border.all(color: colorScheme.border.withValues(alpha: 0.06), width: 1),
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
                  child: Icon(Icons.notifications_active_rounded, size: 16, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.newMessage, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.foreground)),
                      const SizedBox(height: 2),
                      Text(context.l10n.closeToSpendingLimit, style: TextStyle(color: colorScheme.mutedForeground)),
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
              border: Border.all(color: colorScheme.border.withValues(alpha: 0.06), width: 1),
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
                  context.l10n.createHousehold,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: colorScheme.foreground, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: context.l10n.householdNameHint,
                    hintStyle: TextStyle(color: colorScheme.mutedForeground.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: colorScheme.cardSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colorScheme.border.withValues(alpha: 0.12), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colorScheme.border.withValues(alpha: 0.12), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
