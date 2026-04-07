import 'dart:async';
import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/pages/household_onboarding_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_grid_section.dart';
import 'package:moneko/features/pockets/presentation/widgets/create_budget_from_template_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class PocketsPage extends HookConsumerWidget {
  const PocketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTabIndex = ref.watch(mainShellTabIndexProvider);
    final isActiveTab = currentTabIndex == 2;
    final viewMode = ref.watch(viewModeProvider);
    final isPreviewMode = ref.watch(previewModeProvider).isActive;
    final user = ref.watch(authProvider);
    final filterState = ref.watch(homeFilterProvider);
    final resolvedSelectedCurrency =
        ref.watch(selectedHomeCurrencyCodeProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final households = householdsAsync.valueOrNull ?? const <Household>[];
    final isBootstrapCurrency = !filterState.hasExplicitCurrency;
    final includeUpcomingRecurring =
        ref.watch(includeUpcomingRecurringInPocketsProvider);
    final recurringPreferenceReady = useState(false);
    final prefs = ref.read(sharedPreferencesProvider);
    final pocketsSwipeHintPrefKey =
        _pocketsMonthSwipeHintDismissedKey(user.uid);
    final hasDismissedSwipeHintState =
        useState<bool>(prefs.getBool(pocketsSwipeHintPrefKey) ?? false);

    // Track save/reset operations
    final isSavingChanges = useState(false);
    final isResettingChanges = useState(false);

    // Use householdScopeProvider to properly handle personal vs portfolio vs household.
    final householdScope = ref.watch(householdScopeProvider);

    final resolvedHouseholdId =
        householdScope.activeAccountType == ActiveWalletType.household
            ? householdScope.selectedHouseholdId
            : null;

    // Prefetch policy:
    // - Keep initial paint fast (only the settled month must render)
    // - Make 1-2 swipes feel instant by preloading a small window
    // - Avoid fetching intermediate months during large programmatic jumps
    const prefetchPastMonths = 2;
    const prefetchTowardPresentMonths = 1;

    // Always start at the current month
    final now = DateTime.now();
    final initialMonth = DateTime(now.year, now.month, 1);

    // Use a large initial page index to allow swiping into the past
    const initialPage = 1000;
    final pageController = usePageController(initialPage: initialPage);
    final settledPageIndexState = useState<int>(initialPage);
    final currentPageIndexState = useState<int>(initialPage);
    final pendingJumpTargetIndexState = useState<int?>(null);
    final currentMonthState = useState(initialMonth);

    // Reset to initial page when the global filter changes
    useEffect(() {
      if (pageController.hasClients) {
        pageController.jumpToPage(initialPage);
      }
      settledPageIndexState.value = initialPage;
      currentPageIndexState.value = initialPage;
      pendingJumpTargetIndexState.value = null;
      currentMonthState.value = initialMonth;
      return null;
    }, [initialMonth]);

    // Track the currently visible page during manual swipes so we can start
    // loading as the user drags. During programmatic jumps, we suppress this
    // to avoid fetching intermediate months.
    useEffect(() {
      void handlePageControllerChanged() {
        if (pendingJumpTargetIndexState.value != null) {
          return;
        }

        final raw = pageController.page;
        if (raw == null) return;

        final index = raw.round();
        if (index == currentPageIndexState.value) return;
        currentPageIndexState.value = index;
      }

      pageController.addListener(handlePageControllerChanged);
      return () => pageController.removeListener(handlePageControllerChanged);
    }, [pageController]);

    // Only update the "selected" month when scrolling settles.
    // This prevents fetching every intermediate month when jumping across
    // many pages (e.g., month picker -> animateToPage).
    useEffect(() {
      void syncSettledIndexFromController() {
        if (!pageController.hasClients) return;
        final raw = pageController.page;
        if (raw == null) return;

        final settledIndex = raw.round();
        if (settledIndex == settledPageIndexState.value) return;
        settledPageIndexState.value = settledIndex;
        currentPageIndexState.value = settledIndex;
        pendingJumpTargetIndexState.value = null;

        final offset = settledIndex - initialPage;
        currentMonthState.value =
            DateTime(initialMonth.year, initialMonth.month + offset, 1);

        if (hasDismissedSwipeHintState.value) {
          return;
        }
        if (settledIndex == initialPage) {
          return;
        }
        hasDismissedSwipeHintState.value = true;
        unawaited(prefs.setBool(pocketsSwipeHintPrefKey, true));
      }

      VoidCallback? removeListener;
      var disposed = false;

      // Attach after first layout so controller has a position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (disposed) return;
        if (!pageController.hasClients) return;

        final notifier = pageController.position.isScrollingNotifier;

        void handleScrollingChanged() {
          // Only react when scrolling stops.
          if (!notifier.value) {
            syncSettledIndexFromController();
          }
        }

        notifier.addListener(handleScrollingChanged);
        removeListener = () => notifier.removeListener(handleScrollingChanged);

        // Initial sync.
        syncSettledIndexFromController();
      });

      return () {
        disposed = true;
        removeListener?.call();
      };
    }, [
      pageController,
      initialMonth,
      prefs,
      pocketsSwipeHintPrefKey,
    ]);

    // Prefetch a small month window (settled month + neighbors) without
    // rebuilding the UI when the background data arrives.
    useEffect(() {
      final settledIndex = settledPageIndexState.value;
      final currentPageIndex = currentPageIndexState.value;
      final pendingJumpTargetIndex = pendingJumpTargetIndexState.value;

      Future.microtask(() {
        Iterable<int> indicesForCenter(int center) sync* {
          final startIndex = (center - prefetchPastMonths) < 0
              ? 0
              : (center - prefetchPastMonths);
          final endIndex = (center + prefetchTowardPresentMonths) > initialPage
              ? initialPage
              : (center + prefetchTowardPresentMonths);

          for (var index = startIndex; index <= endIndex; index++) {
            yield index;
          }
        }

        final indices = <int>{...indicesForCenter(settledIndex)};

        if (pendingJumpTargetIndex != null) {
          indices.addAll(indicesForCenter(pendingJumpTargetIndex));
        } else {
          indices.addAll(indicesForCenter(currentPageIndex));
        }

        for (final index in indices) {
          final offset = index - initialPage;
          final month =
              DateTime(initialMonth.year, initialMonth.month + offset, 1);

          final scopeParams = switch (householdScope.activeAccountType) {
            ActiveWalletType.personal => PocketsScopeParams(
                scope: PocketsScopeType.personal,
                periodMonth: month,
                currency: resolvedSelectedCurrency,
                isBootstrapCurrency: isBootstrapCurrency,
                includeUpcomingRecurring: includeUpcomingRecurring,
              ),
            ActiveWalletType.portfolio =>
              householdScope.activeAccountHouseholdId == null
                  ? PocketsScopeParams(
                      scope: PocketsScopeType.personal,
                      periodMonth: month,
                      currency: resolvedSelectedCurrency,
                      isBootstrapCurrency: isBootstrapCurrency,
                      includeUpcomingRecurring: includeUpcomingRecurring,
                    )
                  : PocketsScopeParams(
                      scope: PocketsScopeType.portfolio,
                      householdId: householdScope.activeAccountHouseholdId,
                      periodMonth: month,
                      currency: resolvedSelectedCurrency,
                      isBootstrapCurrency: isBootstrapCurrency,
                      includeUpcomingRecurring: includeUpcomingRecurring,
                    ),
            ActiveWalletType.household => PocketsScopeParams(
                scope: PocketsScopeType.household,
                householdId: resolvedHouseholdId,
                periodMonth: month,
                currency: resolvedSelectedCurrency,
                isBootstrapCurrency: isBootstrapCurrency,
                includeUpcomingRecurring: includeUpcomingRecurring,
              ),
          };

          // Create the provider and trigger its auto-load without subscribing.
          // (No rebuilds when background months complete.)
          ref.read(pocketsProvider(scopeParams));
        }
      });

      return null;
    }, [
      settledPageIndexState.value,
      currentPageIndexState.value,
      pendingJumpTargetIndexState.value,
      householdScope.activeAccountType,
      householdScope.activeAccountHouseholdId,
      resolvedHouseholdId,
      resolvedSelectedCurrency,
      isBootstrapCurrency,
      includeUpcomingRecurring,
      initialMonth,
    ]);

    // Keep selectedHouseholdProvider in sync when we fall back to a household
    useEffect(() {
      if (householdScope.activeAccountType != ActiveWalletType.household) {
        return null;
      }
      if (resolvedHouseholdId == null) return null;

      final currentId = selectedHouseholdState.householdId;
      final currentObjId = selectedHouseholdState.household?.id;
      if (currentId == resolvedHouseholdId &&
          currentObjId == resolvedHouseholdId) {
        return null;
      }

      Future.microtask(() {
        ref
            .read(selectedHouseholdProvider.notifier)
            .selectHousehold(resolvedHouseholdId);
      });

      return null;
    }, [
      householdScope.activeAccountType,
      resolvedHouseholdId,
      selectedHouseholdState.householdId,
      selectedHouseholdState.household?.id,
      user.uid,
    ]);

    useEffect(() {
      final initialValue = ref.read(includeUpcomingRecurringInPocketsProvider);
      Future<void>(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          if (!context.mounted) {
            return;
          }
          final storedValue = prefs.getBool(
                includeUpcomingRecurringInPocketsPreferenceKey,
              ) ??
              false;
          final currentValue =
              ref.read(includeUpcomingRecurringInPocketsProvider);
          if (currentValue == initialValue && storedValue != currentValue) {
            ref.read(includeUpcomingRecurringInPocketsProvider.notifier).state =
                storedValue;
          }
        } finally {
          if (context.mounted) {
            recurringPreferenceReady.value = true;
          }
        }
      });
      return null;
    }, const []);

    if (!isActiveTab) {
      return const SizedBox.shrink();
    }

    if (!recurringPreferenceReady.value) {
      return StatusBarOverlayRegion(
          child: AdaptiveScaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      ));
    }

    if (householdScope.activeAccountType == ActiveWalletType.household) {
      if (householdsAsync.isLoading) {
        return StatusBarOverlayRegion(
            child: AdaptiveScaffold(
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
        ));
      }

      if (householdsAsync.hasError) {
        return StatusBarOverlayRegion(
            child: AdaptiveScaffold(
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
        ));
      }

      if (households.isEmpty) {
        return StatusBarOverlayRegion(
            child: AdaptiveScaffold(
          body: const HouseholdOnboardingPage(),
          floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
              ? const Padding(
                  padding: EdgeInsets.all(0),
                  child: HomeAiExpandableFab(),
                )
              : null,
        ));
      }

      if (resolvedHouseholdId == null) {
        return StatusBarOverlayRegion(
            child: AdaptiveScaffold(
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
        ));
      }
    }

    // Determine parameters for the currently viewed month (for the bottom bar).
    final currentScopeParams = switch (householdScope.activeAccountType) {
      ActiveWalletType.personal => PocketsScopeParams(
          scope: PocketsScopeType.personal,
          periodMonth: currentMonthState.value,
          currency: resolvedSelectedCurrency,
          isBootstrapCurrency: isBootstrapCurrency,
          includeUpcomingRecurring: includeUpcomingRecurring,
        ),
      ActiveWalletType.portfolio =>
        householdScope.activeAccountHouseholdId == null
            ? PocketsScopeParams(
                scope: PocketsScopeType.personal,
                periodMonth: currentMonthState.value,
                currency: resolvedSelectedCurrency,
                isBootstrapCurrency: isBootstrapCurrency,
                includeUpcomingRecurring: includeUpcomingRecurring,
              )
            : PocketsScopeParams(
                scope: PocketsScopeType.portfolio,
                householdId: householdScope.activeAccountHouseholdId,
                periodMonth: currentMonthState.value,
                currency: resolvedSelectedCurrency,
                isBootstrapCurrency: isBootstrapCurrency,
                includeUpcomingRecurring: includeUpcomingRecurring,
              ),
      ActiveWalletType.household => PocketsScopeParams(
          scope: PocketsScopeType.household,
          householdId: resolvedHouseholdId,
          periodMonth: currentMonthState.value,
          currency: resolvedSelectedCurrency,
          isBootstrapCurrency: isBootstrapCurrency,
          includeUpcomingRecurring: includeUpcomingRecurring,
        ),
    };

    final currentPocketsState = ref.watch(pocketsProvider(currentScopeParams));
    final currentPocketsNotifier =
        ref.read(pocketsProvider(currentScopeParams).notifier);
    final hasChanges = currentPocketsState.hasChanges;
    final isPocketsLoading = currentPocketsState.isLoading;

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: pageController,
            allowImplicitScrolling: true,
            itemCount: initialPage + 1, // Prevent swiping to future months
            onPageChanged: (index) {
              if (!hasDismissedSwipeHintState.value && index != initialPage) {
                hasDismissedSwipeHintState.value = true;
                unawaited(prefs.setBool(pocketsSwipeHintPrefKey, true));
              }
            },
            itemBuilder: (context, index) {
              final offset = index - initialPage;
              final month =
                  DateTime(initialMonth.year, initialMonth.month + offset, 1);

              final settledIndex = settledPageIndexState.value;
              final currentPageIndex = currentPageIndexState.value;
              final pendingJumpTargetIndex = pendingJumpTargetIndexState.value;

              bool isInWindow(int index, int centerIndex) {
                return index >= (centerIndex - prefetchPastMonths) &&
                    index <= (centerIndex + prefetchTowardPresentMonths);
              }

              final shouldBuildFullView = isInWindow(index, settledIndex) ||
                  (pendingJumpTargetIndex != null
                      ? isInWindow(index, pendingJumpTargetIndex)
                      : isInWindow(index, currentPageIndex));

              final scopeParams = switch (householdScope.activeAccountType) {
                ActiveWalletType.personal => PocketsScopeParams(
                    scope: PocketsScopeType.personal,
                    periodMonth: month,
                    currency: resolvedSelectedCurrency,
                    isBootstrapCurrency: isBootstrapCurrency,
                    includeUpcomingRecurring: includeUpcomingRecurring,
                  ),
                ActiveWalletType.portfolio =>
                  householdScope.activeAccountHouseholdId == null
                      ? PocketsScopeParams(
                          scope: PocketsScopeType.personal,
                          periodMonth: month,
                          currency: resolvedSelectedCurrency,
                          isBootstrapCurrency: isBootstrapCurrency,
                          includeUpcomingRecurring: includeUpcomingRecurring,
                        )
                      : PocketsScopeParams(
                          scope: PocketsScopeType.portfolio,
                          householdId: householdScope.activeAccountHouseholdId,
                          periodMonth: month,
                          currency: resolvedSelectedCurrency,
                          isBootstrapCurrency: isBootstrapCurrency,
                          includeUpcomingRecurring: includeUpcomingRecurring,
                        ),
                ActiveWalletType.household => PocketsScopeParams(
                    scope: PocketsScopeType.household,
                    householdId: resolvedHouseholdId,
                    periodMonth: month,
                    currency: resolvedSelectedCurrency,
                    isBootstrapCurrency: isBootstrapCurrency,
                    includeUpcomingRecurring: includeUpcomingRecurring,
                  ),
              };

              if (!shouldBuildFullView) {
                return _PocketsMonthPlaceholder(
                  colorScheme: colorScheme,
                );
              }

              return _PocketsMonthView(
                scopeParams: scopeParams,
                colorScheme: colorScheme,
                isPersonalMode: householdScope.activeAccountType !=
                    ActiveWalletType.household,
                isActiveMonth: scopeParams == currentScopeParams,
                showSwipeHint: !hasDismissedSwipeHintState.value,
                onDateSelected: (date) {
                  final diffYears = date.year - initialMonth.year;
                  final diffMonths = date.month - initialMonth.month;
                  final totalMonthDiff = diffYears * 12 + diffMonths;
                  final int targetPage = initialPage + totalMonthDiff;

                  // Allow prefetching the target month without triggering loads
                  // for all intermediate months during the animation.
                  pendingJumpTargetIndexState.value = targetPage;

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
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutQuart,
            left: 32,
            right: 32,
            bottom:
                hasChanges ? (PlatformInfo.isIOS26OrHigher() ? 100 : 32) : -100,
            child: IgnorePointer(
              ignoring: !hasChanges,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: hasChanges ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AdaptiveButton.child(
                                onPressed: isResettingChanges.value ||
                                        isSavingChanges.value
                                    ? null
                                    : () async {
                                        if (isResettingChanges.value) return;
                                        isResettingChanges.value = true;
                                        try {
                                          currentPocketsNotifier
                                              .revertChanges();
                                          if (context.mounted) {
                                            AppToast.info(
                                              context,
                                              context.l10n.budgetUpdated,
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            AppToast.error(
                                              context,
                                              ErrorHandler
                                                  .getUserFriendlyMessage(e),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            isResettingChanges.value = false;
                                          }
                                        }
                                      },
                                style: AdaptiveButtonStyle.plain,
                                child: isResettingChanges.value
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            colorScheme.error,
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.refresh_rounded,
                                            size: 18,
                                            color: colorScheme.error,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            context.l10n.reset,
                                            style: TextStyle(
                                              color: colorScheme.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: PrimaryAdaptiveButton(
                                onPressed: isSavingChanges.value ||
                                        isResettingChanges.value
                                    ? null
                                    : () async {
                                        if (isSavingChanges.value) return;
                                        isSavingChanges.value = true;
                                        try {
                                          if (isPreviewMode) {
                                            if (context.mounted) {
                                              AppToast.info(
                                                context,
                                                context.l10n
                                                    .previewMockUpdatesApplied,
                                              );
                                            }
                                            return;
                                          }
                                          await currentPocketsNotifier
                                              .saveChanges();
                                          if (context.mounted) {
                                            AppToast.success(
                                              context,
                                              context.l10n
                                                  .budgetUpdatedSuccessfully,
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            AppToast.error(
                                              context,
                                              ErrorHandler
                                                  .getUserFriendlyMessage(e),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            isSavingChanges.value = false;
                                          }
                                        }
                                      },
                                prefixIcon: isSavingChanges.value
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            colorScheme.primaryForeground,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                      ),
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
    ));
  }
}

class _PocketsMonthView extends HookConsumerWidget {
  const _PocketsMonthView({
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
    required this.isActiveMonth,
    required this.showSwipeHint,
    this.onDateSelected,
  });

  final PocketsScopeParams scopeParams;
  final ColorScheme colorScheme;
  final bool isPersonalMode;
  final bool isActiveMonth;
  final bool showSwipeHint;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pocketsState = ref.watch(pocketsProvider(scopeParams));
    final pocketsNotifier = ref.read(pocketsProvider(scopeParams).notifier);

    Future<void> refresh() async {
      // Invalidate and reload pockets data only - analytics is managed by app_initialization_provider.
      // Invalidation recreates the notifier; we then explicitly call load() to force an immediate refresh.
      ref.invalidate(pocketsProvider(scopeParams));
      await ref
          .read(pocketsProvider(scopeParams).notifier)
          .load(bypassCache: true);
    }

    // When a new month starts, users often have zero budget and no pockets yet.
    // If there are no pockets and no budget amount set, show an onboarding CTA.
    // Priority: copy previous month pockets (if any) > create from template.
    final shouldShowEmptyMonthCta = !pocketsState.isLoading &&
        pocketsState.editing.isEmpty &&
        pocketsState.totalBudget == 0;
    final showCopyPocketsFromPreviousMonth =
        shouldShowEmptyMonthCta && pocketsState.hasPreviousMonthPockets;
    final showCreateFromTemplate =
        shouldShowEmptyMonthCta && !pocketsState.hasPreviousMonthPockets;

    final isCopyingPockets = useState(false);

    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showCopyPocketsFromPreviousMonth)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _CopyBudgetBanner(
                  previousBudget: pocketsState.previousBudget,
                  onCopy: () async {
                    try {
                      pocketsNotifier
                          .reusePreviousBudget(pocketsState.previousBudget);
                      if (context.mounted) {
                        AppToast.success(
                          context,
                          context.l10n.budgetUpdated,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.error(
                          context,
                          ErrorHandler.getUserFriendlyMessage(e),
                        );
                      }
                    }
                  },
                  onCopyPockets: () async {
                    if (isCopyingPockets.value) return;

                    final result = await MonekoAlertDialog.show(
                      context: context,
                      title: context.l10n.pocketsCopyDialogTitle,
                      description: context.l10n.pocketsCopyDialogDesc,
                      confirmLabel: context.l10n.pocketsCopyConfirm,
                      cancelLabel: context.l10n.cancel,
                    );
                    final confirmed = result?.confirmed ?? false;

                    if (confirmed != true || !context.mounted) return;

                    isCopyingPockets.value = true;
                    try {
                      final now = scopeParams.periodMonth ?? DateTime.now();
                      final previousMonth =
                          DateTime(now.year, now.month - 1, 1);
                      await pocketsNotifier.copyPocketsFromMonth(previousMonth);
                      if (context.mounted) {
                        AppToast.success(
                          context,
                          context.l10n.budgetCreatedSuccessfully,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.error(
                          context,
                          ErrorHandler.getUserFriendlyMessage(e),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        isCopyingPockets.value = false;
                      }
                    }
                  },
                  isCopying: isCopyingPockets.value,
                  colorScheme: colorScheme,
                ),
              ),
            ),
          if (showCreateFromTemplate)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _CreateFromTemplateBanner(
                  colorScheme: colorScheme,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: false,
                      enableDrag: false,
                      backgroundColor:
                          Colors.transparent, // Sheet handles its own styling
                      builder: (context) => CreateBudgetFromTemplateSheet(
                        scopeParams: scopeParams,
                      ),
                    );
                  },
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
                isActiveMonth: isActiveMonth,
                showSwipeHint: showSwipeHint,
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

class _PocketsMonthPlaceholder extends StatelessWidget {
  const _PocketsMonthPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: colorScheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _pocketsMonthSwipeHintDismissedKey(String userId) {
  return 'pockets_month_swipe_hint_dismissed:$userId';
}

class _CopyBudgetBanner extends StatelessWidget {
  const _CopyBudgetBanner({
    required this.previousBudget,
    required this.onCopy,
    required this.onCopyPockets,
    required this.isCopying,
    required this.colorScheme,
  });

  final double previousBudget;
  final VoidCallback onCopy;
  final VoidCallback onCopyPockets;
  final bool isCopying;
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
            context.l10n.pocketsNewMonthBannerTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.pocketsNewMonthBannerSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryAdaptiveButton(
              onPressed: isCopying ? null : onCopyPockets,
              child: Text(
                isCopying
                    ? context.l10n.pocketsCopyingAction
                    : context.l10n.pocketsCopyLastMonthAction,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (previousBudget > 0)
            SizedBox(
              width: double.infinity,
              child: PlainAdaptiveButton(
                onPressed: onCopy,
                child: Text(
                  context.l10n.pocketsUseLastMonthBudgetAction(formattedAmount),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateFromTemplateBanner extends StatelessWidget {
  const _CreateFromTemplateBanner({
    required this.colorScheme,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              context.l10n.createFromTemplateDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PrimaryAdaptiveButton(
                onPressed: onTap,
                child: Text(context.l10n.createFromTemplate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
