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
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_grid_section.dart';
import 'package:moneko/features/pockets/presentation/widgets/create_budget_from_template_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

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

    // Track save/reset operations
    final isSavingChanges = useState(false);
    final isResettingChanges = useState(false);

    // Use householdScopeProvider to properly handle personal vs portfolio vs household.
    final householdScope = ref.watch(householdScopeProvider);

    final resolvedHouseholdId =
        householdScope.activeAccountType == ActiveAccountType.household
            ? householdScope.selectedHouseholdId
            : null;

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
      if (householdScope.activeAccountType != ActiveAccountType.household) {
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

    if (householdScope.activeAccountType == ActiveAccountType.household) {
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

    // Determine parameters for the currently viewed month (for the bottom bar).
    final currentScopeParams = switch (householdScope.activeAccountType) {
      ActiveAccountType.personal => PocketsScopeParams(
          scope: PocketsScopeType.personal,
          periodMonth: currentMonthState.value,
        ),
      ActiveAccountType.portfolio =>
        householdScope.activeAccountHouseholdId == null
            ? PocketsScopeParams(
                scope: PocketsScopeType.personal,
                periodMonth: currentMonthState.value,
              )
            : PocketsScopeParams(
                scope: PocketsScopeType.portfolio,
                householdId: householdScope.activeAccountHouseholdId,
                periodMonth: currentMonthState.value,
              ),
      ActiveAccountType.household => PocketsScopeParams(
          scope: PocketsScopeType.household,
          householdId: resolvedHouseholdId,
          periodMonth: currentMonthState.value,
        ),
    };

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

              final scopeParams = switch (householdScope.activeAccountType) {
                ActiveAccountType.personal => PocketsScopeParams(
                    scope: PocketsScopeType.personal,
                    periodMonth: month,
                  ),
                ActiveAccountType.portfolio =>
                  householdScope.activeAccountHouseholdId == null
                      ? PocketsScopeParams(
                          scope: PocketsScopeType.personal,
                          periodMonth: month,
                        )
                      : PocketsScopeParams(
                          scope: PocketsScopeType.portfolio,
                          householdId: householdScope.activeAccountHouseholdId,
                          periodMonth: month,
                        ),
                ActiveAccountType.household => PocketsScopeParams(
                    scope: PocketsScopeType.household,
                    householdId: resolvedHouseholdId,
                    periodMonth: month,
                  ),
              };

              return _PocketsMonthView(
                scopeParams: scopeParams,
                colorScheme: colorScheme,
                isPersonalMode: householdScope.activeAccountType !=
                    ActiveAccountType.household,
                isActiveMonth: scopeParams == currentScopeParams,
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
    );
  }
}

class _PocketsMonthView extends HookConsumerWidget {
  const _PocketsMonthView({
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
    required this.isActiveMonth,
    this.onDateSelected,
  });

  final PocketsScopeParams scopeParams;
  final ColorScheme colorScheme;
  final bool isPersonalMode;
  final bool isActiveMonth;
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
                      title: 'Copy last month\'s pockets?',
                      description: 'This will create pockets for this month using the same names, icons, colors, and budgeted amounts as last month. You can edit everything afterwards.',
                      confirmLabel: 'Copy pockets',
                      cancelLabel: 'Cancel',
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
            'New month, fresh budget',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Looks like you haven\'t set up pockets for this month yet. Want to start from last month?',
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
                isCopying ? 'Copying…' : 'Copy last month\'s pockets',
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
                  'Just use last month\'s budget ($formattedAmount)',
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
          color: colorScheme.surface,
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
