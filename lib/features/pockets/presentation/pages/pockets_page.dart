import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_grid_section.dart';
import 'package:moneko/features/utils/main_page_top_padding.dart';
import 'package:moneko/shared/widgets/plain-adaptive-button.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

class PocketsPage extends HookConsumerWidget {
  const PocketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    // Always start at the current month
    final now = DateTime.now();
    final initialMonth = DateTime(now.year, now.month, 1);

    // Use a large initial page index to allow swiping into the past
    const initialPage = 1000;
    final pageController = usePageController(initialPage: initialPage);
    final currentMonthState = useState(initialMonth);

    // Reset to initial page when the global filter changes
    useEffect(() {
      if (pageController.hasClients) {
        pageController.jumpToPage(initialPage);
      }
      currentMonthState.value = initialMonth;
      return null;
    }, [initialMonth]);

    // Determine parameters for the currently viewed month (for the bottom bar)
    final currentScopeParams = viewMode.mode == ViewMode.personal
        ? PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: currentMonthState.value,
          )
        : PocketsScopeParams(
            scope: PocketsScopeType.household,
            householdId: selectedHouseholdState.householdId,
            periodMonth: currentMonthState.value,
          );

    final currentPocketsState = ref.watch(pocketsProvider(currentScopeParams));
    final currentPocketsNotifier =
        ref.read(pocketsProvider(currentScopeParams).notifier);
    final hasChanges = currentPocketsState.hasChanges;

    return AdaptiveScaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: pageController,
            allowImplicitScrolling: true,
            itemCount: initialPage + 1, // Prevent swiping to future months
            onPageChanged: (index) {
              final offset = index - initialPage;
              currentMonthState.value =
                  DateTime(initialMonth.year, initialMonth.month + offset, 1);
            },
            itemBuilder: (context, index) {
              final offset = index - initialPage;
              final month =
                  DateTime(initialMonth.year, initialMonth.month + offset, 1);

              final scopeParams = viewMode.mode == ViewMode.personal
                  ? PocketsScopeParams(
                      scope: PocketsScopeType.personal, periodMonth: month)
                  : PocketsScopeParams(
                      scope: PocketsScopeType.household,
                      householdId: selectedHouseholdState.householdId,
                      periodMonth: month,
                    );

              return _PocketsMonthView(
                scopeParams: scopeParams,
                colorScheme: colorScheme,
                isPersonalMode: viewMode.mode == ViewMode.personal,
                onDateSelected: (date) {
                  final diffYears = date.year - initialMonth.year;
                  final diffMonths = date.month - initialMonth.month;
                  final totalMonthDiff = diffYears * 12 + diffMonths;
                  final int targetPage = initialPage + totalMonthDiff;

                  pageController.animateToPage(
                    targetPage,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              );
            },
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            left: 24,
            right: 24,
            bottom:
                hasChanges ? (PlatformInfo.isIOS26OrHigher() ? 100 : 32) : -100,
            child: IgnorePointer(
              ignoring: !hasChanges,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: hasChanges ? 1.0 : 0.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.only(
                          top: 8, left: 16, right: 16, bottom: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: PlainAdaptiveButton(
                              onPressed: currentPocketsNotifier.revertChanges,
                              child: Text(
                                context.l10n.reset,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PrimaryAdaptiveButton(
                              onPressed: currentPocketsNotifier.saveChanges,
                              child: Text(context.l10n.save),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
          ? Padding(
              padding: PlatformInfo.isIOS26OrHigher()
                  ? const EdgeInsets.only(bottom: 80, right: 6)
                  : const EdgeInsets.all(0),
              child: const HomeAiExpandableFab(),
            )
          : null,
    );
  }
}

class _PocketsMonthView extends HookConsumerWidget {
  const _PocketsMonthView({
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
    this.onDateSelected,
  });

  final PocketsScopeParams scopeParams;
  final ColorScheme colorScheme;
  final bool isPersonalMode;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pocketsState = ref.watch(pocketsProvider(scopeParams));
    final pocketsNotifier = ref.read(pocketsProvider(scopeParams).notifier);

    Future<void> refresh() async {
      // Invalidate and reload pockets data only - analytics is managed by app_initialization_provider.
      // Invalidation recreates the notifier; we then explicitly call load() to force an immediate refresh.
      ref.invalidate(pocketsProvider(scopeParams));
      await ref.read(pocketsProvider(scopeParams).notifier).load();
    }

    final showCopyBudget =
        pocketsState.totalBudget == 0 && pocketsState.previousBudget > 0;

    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showCopyBudget)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _CopyBudgetBanner(
                  previousBudget: pocketsState.previousBudget,
                  onCopy: () => pocketsNotifier
                      .reusePreviousBudget(pocketsState.previousBudget),
                  colorScheme: colorScheme,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PocketsGridSection(
                scopeParams: scopeParams,
                colorScheme: colorScheme,
                isPersonalMode: isPersonalMode,
                uncategorizedExpenses: pocketsState.uncategorizedExpenses,
                onDateSelected: onDateSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyBudgetBanner extends StatelessWidget {
  const _CopyBudgetBanner({
    required this.previousBudget,
    required this.onCopy,
    required this.colorScheme,
  });

  final double previousBudget;
  final VoidCallback onCopy;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final formattedAmount = currencyFormatter.format(previousBudget);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Start with last month\'s budget?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You had a budget of $formattedAmount last month.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryAdaptiveButton(
              onPressed: onCopy,
              child: Text('Copy Budget ($formattedAmount)'),
            ),
          ),
        ],
      ),
    );
  }
}
