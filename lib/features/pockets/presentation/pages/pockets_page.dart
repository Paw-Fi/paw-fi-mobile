import 'dart:async';
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
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/pages/household_onboarding_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_grid_section.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/core/theme/app_theme.dart';

Household? _resolveHouseholdSelection(
  SelectedHouseholdState selectedState,
  List<Household> households,
) {
  if (households.isEmpty) return null;

  final selected = selectedState.household;
  if (selected != null &&
      households.any((h) => h.id == selected.id)) {
    return households.firstWhere(
      (h) => h.id == selected.id,
      orElse: () => households.first,
    );
  }

  final selectedId = selectedState.householdId;
  if (selectedId != null) {
    return households.firstWhere(
      (h) => h.id == selectedId,
      orElse: () => households.first,
    );
  }

  return households.first;
}

class PocketsPage extends HookConsumerWidget {
  const PocketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final households = householdsAsync.valueOrNull ?? const <Household>[];
    final resolvedHousehold = viewMode.mode == ViewMode.household
        ? _resolveHouseholdSelection(selectedHouseholdState, households)
        : null;
    final resolvedHouseholdId = resolvedHousehold?.id;
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

    // Keep selectedHouseholdProvider in sync when we fall back to a household
    useEffect(() {
      if (viewMode.mode != ViewMode.household) return null;
      if (resolvedHouseholdId == null) return null;

      final currentId = selectedHouseholdState.householdId;
      final currentObjId = selectedHouseholdState.household?.id;
      if (currentId == resolvedHouseholdId && currentObjId == resolvedHouseholdId) {
        return null;
      }

      Future.microtask(() {
        ref
            .read(selectedHouseholdProvider.notifier)
            .selectHousehold(resolvedHouseholdId, user.uid);
      });

      return null;
    }, [
      viewMode.mode,
      resolvedHouseholdId,
      selectedHouseholdState.householdId,
      selectedHouseholdState.household?.id,
      user.uid,
    ]);

    if (viewMode.mode == ViewMode.household) {
      if (householdsAsync.isLoading) {
        return AdaptiveScaffold(
          body: Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
              ? const Padding(
                  padding: EdgeInsets.all(0),
                  child: HomeAiExpandableFab(),
                )
              : null,
        );
      }

      if (householdsAsync.hasError) {
        return AdaptiveScaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.errorLoadingHouseholds,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.destructive,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PlainAdaptiveButton(
                    onPressed: () => ref
                        .read(userHouseholdsProvider(user.uid).notifier)
                        .load(),
                    child: Text(
                      context.l10n.tryAgain,
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
              ? const Padding(
                  padding: EdgeInsets.all(0),
                  child: HomeAiExpandableFab(),
                )
              : null,
        );
      }

      if (households.isEmpty) {
        return AdaptiveScaffold(
          body: const HouseholdOnboardingPage(),
          floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
              ? const Padding(
                  padding: EdgeInsets.all(0),
                  child: HomeAiExpandableFab(),
                )
              : null,
        );
      }

      if (resolvedHouseholdId == null) {
        return AdaptiveScaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.selectHouseholdToManageSharedBudgets,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
              ? const Padding(
                  padding: EdgeInsets.all(0),
                  child: HomeAiExpandableFab(),
                )
              : null,
        );
      }
    }

    // Determine parameters for the currently viewed month (for the bottom bar)
    final currentScopeParams = viewMode.mode == ViewMode.personal
        ? PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: currentMonthState.value,
          )
        : PocketsScopeParams(
            scope: PocketsScopeType.household,
            householdId: resolvedHouseholdId,
            periodMonth: currentMonthState.value,
          );

    final currentPocketsState = ref.watch(pocketsProvider(currentScopeParams));
    final currentPocketsNotifier =
        ref.read(pocketsProvider(currentScopeParams).notifier);
    final hasChanges = currentPocketsState.hasChanges;
    final isPocketsLoading = currentPocketsState.isLoading;

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
                      householdId: resolvedHouseholdId,
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
                        color: colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.15),
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
      floatingActionButton:
          shouldShowHomeFab(viewMode, householdsAsync) && !isPocketsLoading
              ? const Padding(
                  padding: EdgeInsets.all(0),
                  child: HomeAiExpandableFab(),
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
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            context.l10n.startWithLastMonthsBudget,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.youHadBudgetLastMonth(formattedAmount),
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
              child: Text(
                context.l10n.copyBudgetWithAmount(formattedAmount),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
