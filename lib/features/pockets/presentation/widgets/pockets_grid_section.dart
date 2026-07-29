import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/pages/pocket_details_page.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/add_envelope_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/add_envelope_list_tile.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/features/pockets/presentation/widgets/envelope_mode_settings_modal.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_list_tile.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/simple_spending_list.dart';
import 'package:moneko/features/pockets/presentation/widgets/uncategorized_banner.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';

class PocketsGridSection extends HookConsumerWidget {
  const PocketsGridSection({
    super.key,
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
    required this.isActiveMonth,
    required this.showSwipeHint,
    this.uncategorizedExpenses = const {},
    this.onDateSelected,
  });

  final PocketsScopeParams scopeParams;
  final ColorScheme colorScheme;
  final bool isPersonalMode;
  final bool isActiveMonth;
  final bool showSwipeHint;
  final Map<String, List<Map<String, dynamic>>> uncategorizedExpenses;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);
    final effectiveCurrency = state.currency.trim().isNotEmpty
        ? state.currency.trim()
        : (scopeParams.currency?.trim().isNotEmpty == true
            ? scopeParams.currency!.trim()
            : 'USD');
    final isMultiCurrencySelection =
        scopeParams.normalizedSelectedCurrencies != null;
    final includeUpcomingRecurring =
        ref.watch(includeUpcomingRecurringInPocketsProvider);

    // Local state for Envelope Mode
    final envelopeMode = useState(true);
    final hasSeenEnvelopeModeHelp = useState(false);
    final savingCurrencyBudget = useState<String?>(null);

    // View Mode & Ordering State
    final viewMode = useState('grid');
    final orderedIds = useState<List<String>>([]);

    useEffect(() {
      SharedPreferences.getInstance().then((prefs) {
        if (context.mounted) {
          hasSeenEnvelopeModeHelp.value =
              prefs.getBool('has_seen_envelope_mode_help') ?? false;
          viewMode.value = prefs.getString('pockets_view_mode') ?? 'grid';
          orderedIds.value = prefs.getStringList('pockets_order') ?? [];
        }
      });
      return null;
    }, []);

    final currentTabIndex = ref.watch(mainShellTabIndexProvider);

    // Key for the budget amount column inside the header card; we
    // anchor the spotlight here so only the label+amount are
    // highlighted while the whole card remains tappable.
    final amountSpotlightKey = useMemoized(() => GlobalKey(), []);

    final pocketsBudgetTourController = useMemoized(
      () => SpotlightTourController(
        tourId: 'pockets_budget_header_v1',
        steps: [
          SpotlightStep(
            id: 'pockets_budget_header',
            targetKey: amountSpotlightKey,
            title: context.l10n.pocketsBudgetTourTitle,
            description: context.l10n.pocketsBudgetTourDescription,
            placement: SpotlightPlacement.bottom,
            padding: 12,
            borderRadius: 24,
          ),
        ],
      ),
      [],
    );

    useEffect(() {
      if (state.isLoading || state.error != null) return null;
      if (!isActiveMonth) return null;
      // Only run the pockets header tour when the Pockets tab is the
      // active tab (index 2 in MainShell).
      if (currentTabIndex != 2) return null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        pocketsBudgetTourController.start(context);
      });

      return null;
    }, [
      state.isLoading,
      state.error,
      currentTabIndex,
      pocketsBudgetTourController,
    ]);

    void markHelpAsSeen() {
      hasSeenEnvelopeModeHelp.value = true;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('has_seen_envelope_mode_help', true);
      });
    }

    if (state.error != null && !state.hasDisplayData) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.destructive,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final isLoading = state.isLoading && !state.hasDisplayData;
    final totalBudget = state.totalBudget;
    final totalSpent = state.totalSpent;
    final uncategorized = state.uncategorized;

    // Sort pockets based on orderedIds
    final sortedPockets = useMemoized(() {
      if (orderedIds.value.isEmpty) return state.editing;

      final pocketsMap = {for (var p in state.editing) p.id: p};
      final result = <PocketEnvelope>[];

      // Add existing pockets in order
      for (var id in orderedIds.value) {
        if (pocketsMap.containsKey(id)) {
          result.add(pocketsMap[id]!);
          pocketsMap.remove(id);
        }
      }

      // Add remaining new pockets
      result.addAll(pocketsMap.values);

      return result;
    }, [state.editing, orderedIds.value]);

    void onReorder(int oldIndex, int newIndex) {
      if (state.isLoading) {
        return;
      }
      if (oldIndex >= sortedPockets.length || newIndex > sortedPockets.length) {
        return;
      }

      final newSorted = List<PocketEnvelope>.from(sortedPockets);

      // Adjust index for list view quirk if needed
      // ReorderableListView passes newIndex as if the item was removed.
      // However, we are manually manipulating the list.
      // If oldIndex < newIndex, it means we are moving down.
      // The newIndex is the index *after* the item is removed.
      // So we need to subtract 1 to get the insertion index.
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = newSorted.removeAt(oldIndex);
      newSorted.insert(newIndex, item);

      orderedIds.value = newSorted.map((e) => e.id).toList();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList('pockets_order', orderedIds.value);
      });
    }

    final pocketsForDisplay = isLoading && sortedPockets.isEmpty
        ? _buildFakePockets(context, effectiveCurrency)
        : sortedPockets;
    final rolloverSummaryPockets = isMultiCurrencySelection
        ? const <PocketEnvelope>[]
        : pocketsForDisplay
            .where((pocket) => pocket.hasRolloverBreakdown)
            .toList(growable: false);

    final totalAllocated = pocketsForDisplay.fold<double>(
      0.0,
      (sum, e) => sum + e.getLimit(totalBudget),
    );
    final unallocatedBudget = totalBudget - totalAllocated;
    final selectedCurrencyBudgets = <String, double>{
      for (final currency
          in scopeParams.normalizedSelectedCurrencies ?? const <String>[])
        currency: state.nativeBudgetByCurrency[currency] ?? 0,
    };

    void openAddPocketSheet() {
      if (isMultiCurrencySelection) {
        AppToast.info(context, context.l10n.selectCurrencyFirst);
        return;
      }
      if (totalBudget <= 0) {
        AppToast.info(context, context.l10n.pleaseSetMonthlyBudgetFirst);
        return;
      }
      EditPocketEnvelopeSheet.show(
        context: context,
        scopeParams: scopeParams,
        budgetId: state.budgetId,
        totalBudget: totalBudget,
        unallocatedBudget: unallocatedBudget,
        allPockets: state.editing,
      );
    }

    Future<void> updateNativeCurrencyBudget(
      String currency,
      double amount,
    ) async {
      final normalizedCurrency = currency.trim().toUpperCase();
      if (normalizedCurrency.isEmpty || savingCurrencyBudget.value != null) {
        return;
      }
      if (ref.read(previewModeProvider).isActive) {
        AppToast.info(context, context.l10n.previewMockUpdatesApplied);
        return;
      }

      savingCurrencyBudget.value = normalizedCurrency;
      try {
        final nativeParams = PocketsScopeParams(
          scope: scopeParams.scope,
          householdId: scopeParams.householdId,
          periodMonth: state.periodMonth,
          currency: normalizedCurrency,
          selectedCurrencies: null,
          financialMonthStartDay: scopeParams.normalizedFinancialMonthStartDay,
          isBootstrapCurrency: false,
          includeUpcomingRecurring: scopeParams.includeUpcomingRecurring,
        );
        final nativeProvider = pocketsProvider(nativeParams);
        final nativeNotifier = ref.read(nativeProvider.notifier);
        await nativeNotifier.load();
        final loadedNativeState = ref.read(nativeProvider);
        if (loadedNativeState.error != null &&
            !loadedNativeState.hasDisplayData) {
          throw Exception(loadedNativeState.error);
        }

        nativeNotifier.updateTotalBudget(amount);
        await nativeNotifier.saveChanges();
        final savedNativeState = ref.read(nativeProvider);
        if (savedNativeState.error != null) {
          throw Exception(savedNativeState.error);
        }

        await notifier.applyNativeBudgetProjection(
          normalizedCurrency,
          amount,
        );
        if (context.mounted) {
          AppToast.success(
            context,
            context.l10n.budgetUpdatedSuccessfully,
          );
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(
            context,
            ErrorHandler.getUserFriendlyMessage(error),
          );
        }
      } finally {
        if (context.mounted) {
          savingCurrencyBudget.value = null;
        }
      }
    }

    return Skeletonizer(
      enabled: isLoading,
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: uncategorized.isNotEmpty
                  ? Padding(
                      key: const ValueKey('uncategorized_banner'),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: UncategorizedBanner(
                        colorScheme: colorScheme,
                        currency: effectiveCurrency,
                        uncategorized: uncategorized,
                        uncategorizedExpenses: uncategorizedExpenses,
                        availablePockets: pocketsForDisplay,
                        onAssignCategory: notifier.assignCategoryToPocket,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          PocketsHeaderCard(
            totalBudget: totalBudget,
            periodMonth: state.periodMonth,
            financialMonthStartDay: state.financialMonthStartDay,
            colorScheme: colorScheme,
            onTotalChanged:
                isMultiCurrencySelection ? null : notifier.updateTotalBudget,
            onBudgetEditBlocked: isMultiCurrencySelection
                ? () => AppToast.info(
                      context,
                      context.l10n.selectCurrencyFirst,
                    )
                : null,
            currencyBudgets:
                isMultiCurrencySelection ? selectedCurrencyBudgets : const {},
            onCurrencyBudgetChanged:
                isMultiCurrencySelection ? updateNativeCurrencyBudget : null,
            savingCurrency: savingCurrencyBudget.value,
            onSave: () async {
              if (isMultiCurrencySelection) {
                AppToast.info(
                  context,
                  context.l10n.selectCurrencyFirst,
                );
                return;
              }
              if (ref.read(previewModeProvider).isActive) {
                AppToast.info(
                  context,
                  context.l10n.previewMockUpdatesApplied,
                );
                return;
              }

              await notifier.saveChanges();
            },
            currency: effectiveCurrency,
            onDateSelected: onDateSelected,
            isSkeleton: isLoading,
            amountSpotlightKey: amountSpotlightKey,
            showSwipeHint: showSwipeHint,
          ),
          if (!isLoading && rolloverSummaryPockets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RolloverSummaryCard(
              pockets: rolloverSummaryPockets,
              currency: effectiveCurrency,
              colorScheme: colorScheme,
              onPocketTap: (pocket) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PocketDetailsPage(
                      pocketId: pocket.id,
                      scopeParams: scopeParams,
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),

          // Mode-Specific Content
          if (envelopeMode.value) ...[
            Row(
              children: [
                Text(
                  context.l10n.yourPockets,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    showEnvelopeModeSettingsModal(
                      context,
                      colorScheme,
                      envelopeMode.value,
                      (value) => envelopeMode.value = value,
                      includeUpcomingRecurring,
                      (value) async {
                        ref
                            .read(
                              includeUpcomingRecurringInPocketsProvider
                                  .notifier,
                            )
                            .state = value;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(
                          includeUpcomingRecurringInPocketsPreferenceKey,
                          value,
                        );
                      },
                    );
                    markHelpAsSeen();
                  },
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const Spacer(),
                if (!isLoading)
                  // View Toggle
                  SizedBox(
                    width: PlatformInfo.isIOS ? 90 : 150,
                    height: 40,
                    child: MonekoSegmentedControl(
                      labels: const [],
                      icons: [
                        PlatformInfo.isIOS
                            ? CupertinoIcons.square_grid_2x2_fill
                            : Icons.dashboard,
                        PlatformInfo.isIOS
                            ? CupertinoIcons.list_bullet
                            : Icons.list,
                      ],
                      selectedIndex: viewMode.value == 'grid' ? 0 : 1,
                      onValueChanged: (index) {
                        viewMode.value = index == 0 ? 'grid' : 'list';
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setString('pockets_view_mode', viewMode.value);
                        });
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale:
                        Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: viewMode.value == 'grid'
                  ? ReorderableGridView.builder(
                      key: const ValueKey('grid_view'),
                      padding: const EdgeInsets.only(bottom: 100),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: pocketsForDisplay.length + 1,
                      onReorder: (oldIndex, newIndex) {
                        // If moving the "Add" button (last item), cancel
                        if (oldIndex == sortedPockets.length) return;
                        // If moving to the "Add" button position, move to before it
                        if (newIndex > sortedPockets.length) {
                          newIndex = sortedPockets.length;
                        }

                        onReorder(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final isAddTile = index == pocketsForDisplay.length;
                        if (isAddTile) {
                          return KeyedSubtree(
                            key: const ValueKey('add_button'),
                            child: AddEnvelopeCard(
                              colorScheme: colorScheme,
                              onTap: openAddPocketSheet,
                            ),
                          );
                        }

                        final pocket = pocketsForDisplay[index];
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(pocket.id),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: child,
                              ),
                            );
                          },
                          child: PocketCard(
                            pocket: pocket,
                            currency: pocket.currency,
                            colorScheme: colorScheme,
                            totalBudget: totalBudget,
                            envelopeMode: true,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PocketDetailsPage(
                                    pocketId: pocket.id,
                                    scopeParams: scopeParams,
                                  ),
                                ),
                              );
                            },
                            isSkeleton: isLoading,
                          ),
                        );
                      },
                    )
                  : ReorderableGridView.builder(
                      key: const ValueKey('list_view'),
                      padding: const EdgeInsets.only(bottom: 100),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        childAspectRatio: 4.0,
                        crossAxisSpacing: 0,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: pocketsForDisplay.length + 1,
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex == sortedPockets.length) return;
                        if (newIndex > sortedPockets.length) {
                          newIndex = sortedPockets.length;
                        }
                        onReorder(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final isAddTile = index == pocketsForDisplay.length;
                        if (isAddTile) {
                          return Padding(
                            key: const ValueKey('add_button'),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AddEnvelopeListTile(
                              colorScheme: colorScheme,
                              onTap: openAddPocketSheet,
                            ),
                          );
                        }

                        final pocket = pocketsForDisplay[index];
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(pocket.id),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.scale(
                                scale: 0.98 + (0.02 * value),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PocketListTile(
                              pocket: pocket,
                              currency: pocket.currency,
                              colorScheme: colorScheme,
                              totalBudget: totalBudget,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PocketDetailsPage(
                                      pocketId: pocket.id,
                                      scopeParams: scopeParams,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ] else ...[
            // Simple Mode: Spending Breakdown List
            Row(
              children: [
                Text(
                  context.l10n.spendingBreakdown,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.foreground,
                  ),
                ),
                const Spacer(),
                Text(
                  context.l10n.byCategory,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SimpleSpendingList(
              pockets: pocketsForDisplay,
              totalSpent: totalSpent,
              aggregateSpentByPocketId: state.aggregateSpentByEnvelopeId,
              colorScheme: colorScheme,
            ),
          ],
        ],
      ),
    );
  }
}

class _RolloverSummaryCard extends StatelessWidget {
  const _RolloverSummaryCard({
    required this.pockets,
    required this.currency,
    required this.colorScheme,
    required this.onPocketTap,
  });

  final List<PocketEnvelope> pockets;
  final String currency;
  final ColorScheme colorScheme;
  final ValueChanged<PocketEnvelope> onPocketTap;

  @override
  Widget build(BuildContext context) {
    final totalCarryCents = pockets.fold<int>(
      0,
      (sum, pocket) =>
          sum + pocket.rolloverFromPreviousCents + pocket.openingRolloverCents,
    );

    if (totalCarryCents == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: colorScheme.surface,
              builder: (context) => _RolloverSummarySheet(
                pockets: pockets,
                currency: currency,
                colorScheme: colorScheme,
                onPocketTap: (pocket) {
                  Navigator.of(context).pop();
                  onPocketTap(pocket);
                },
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.pocketRolloverSummaryTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Text(
                  _formatSignedCurrencyCents(
                    context,
                    totalCarryCents,
                    currency,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: totalCarryCents < 0
                        ? colorScheme.error
                        : colorScheme.success,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RolloverSummarySheet extends StatelessWidget {
  const _RolloverSummarySheet({
    required this.pockets,
    required this.currency,
    required this.colorScheme,
    required this.onPocketTap,
  });

  final List<PocketEnvelope> pockets;
  final String currency;
  final ColorScheme colorScheme;
  final ValueChanged<PocketEnvelope> onPocketTap;

  @override
  Widget build(BuildContext context) {
    final totalCarryCents = pockets.fold<int>(
      0,
      (sum, pocket) =>
          sum + pocket.rolloverFromPreviousCents + pocket.openingRolloverCents,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.pocketRolloverSummaryTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.pocketRolloverSummaryDescription,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  Text(
                    _formatSignedCurrencyCents(
                      context,
                      totalCarryCents,
                      currency,
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: totalCarryCents < 0
                          ? colorScheme.error
                          : colorScheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colorScheme.border),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: pockets.length,
                  itemBuilder: (context, index) {
                    final pocket = pockets[index];
                    return _RolloverSummaryRow(
                      pocket: pocket,
                      currency: currency,
                      colorScheme: colorScheme,
                      onTap: () => onPocketTap(pocket),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RolloverSummaryRow extends StatelessWidget {
  const _RolloverSummaryRow({
    required this.pocket,
    required this.currency,
    required this.colorScheme,
    required this.onTap,
  });

  final PocketEnvelope pocket;
  final String currency;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final carryCents =
        pocket.rolloverFromPreviousCents + pocket.openingRolloverCents;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  pocket.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatSignedCurrencyCents(context, carryCents, currency),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color:
                      carryCents < 0 ? colorScheme.error : colorScheme.success,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSignedCurrencyCents(
  BuildContext context,
  int cents,
  String currency,
) {
  final sign = cents < 0 ? '-' : '+';
  final amount = double.parse(formatAmount(cents.abs() / 100.0));
  final localized = formatLocalizedNumber(context, amount);
  return '$sign${resolveCurrencySymbol(currency)}$localized';
}

List<PocketEnvelope> _buildFakePockets(BuildContext context, String currency) {
  final now = DateTime.now();
  return [
    PocketEnvelope(
      id: 'fake-1',
      name: context.l10n.groceries,
      budgetAmountCents: 50000,
      spent: 350,
      currency: currency,
      icon: 'shopping_bag',
      color: null,
      budgetId: null,
      householdId: null,
      lastUpdated: now,
    ),
    PocketEnvelope(
      id: 'fake-2',
      name: context.l10n.bills,
      budgetAmountCents: 70000,
      spent: 420,
      currency: currency,
      icon: 'receipt_long',
      color: null,
      budgetId: null,
      householdId: null,
      lastUpdated: now,
    ),
    PocketEnvelope(
      id: 'fake-3',
      name: context.l10n.diningOut,
      budgetAmountCents: 30000,
      spent: 120,
      currency: currency,
      icon: 'restaurant',
      color: null,
      budgetId: null,
      householdId: null,
      lastUpdated: now,
    ),
    PocketEnvelope(
      id: 'fake-4',
      name: context.l10n.fun,
      budgetAmountCents: 20000,
      spent: 80,
      currency: currency,
      icon: 'celebration',
      color: null,
      budgetId: null,
      householdId: null,
      lastUpdated: now,
    ),
  ];
}
