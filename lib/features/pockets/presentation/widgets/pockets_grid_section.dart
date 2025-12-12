import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
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
import 'package:skeletonizer/skeletonizer.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';

class PocketsGridSection extends HookConsumerWidget {
  const PocketsGridSection({
    super.key,
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
    this.uncategorizedExpenses = const {},
    this.onDateSelected,
  });

  final PocketsScopeParams scopeParams;
  final ColorScheme colorScheme;
  final bool isPersonalMode;
  final Map<String, List<Map<String, dynamic>>> uncategorizedExpenses;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);
    final filter = ref.watch(homeFilterProvider);
    final analytics = ref.watch(analyticsProvider);
    final rawCurrency =
        (filter.selectedCurrency?.trim().isNotEmpty == true
                ? filter.selectedCurrency!.trim()
                : (analytics.preferredCurrency?.trim().isNotEmpty == true
                    ? analytics.preferredCurrency!.trim()
                    : 'USD'))
            .toUpperCase();
    final selectedCurrency = rawCurrency;

    // Local state for Envelope Mode
    final envelopeMode = useState(true);
    final hasSeenEnvelopeModeHelp = useState(false);

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

    // Key attached to the budget amount row inside PocketsHeaderCard;
    // we use this as the spotlight anchor so only the amount is
    // highlighted, not the entire header card.
    final headerAmountKey = useMemoized(() => GlobalKey(), []);

    final pocketsBudgetTourController = useMemoized(
      () => SpotlightTourController(
        tourId: 'pockets_budget_header_v1',
        steps: [
          SpotlightStep(
            id: 'pockets_budget_header',
            targetKey: headerAmountKey,
            title: context.l10n.pocketsBudgetTourTitle,
            description: context.l10n.pocketsBudgetTourDescription,
            placement: SpotlightPlacement.bottom,
            padding: 6,
            borderRadius: 24,
          ),
        ],
      ),
      [],
    );

    useEffect(() {
      if (state.isLoading || state.error != null) return null;
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

    if (state.error != null) {
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

    final isLoading = state.isLoading;
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
        ? _buildFakePockets(selectedCurrency)
        : sortedPockets;

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
          if (uncategorized.isNotEmpty) ...[
            UncategorizedBanner(
              colorScheme: colorScheme,
              currency: selectedCurrency,
              uncategorized: uncategorized,
              uncategorizedExpenses: uncategorizedExpenses,
              availablePockets: pocketsForDisplay,
              onAssignCategory: notifier.assignCategoryToPocket,
            ),
            const SizedBox(height: 16),
          ],
          PocketsHeaderCard(
            totalBudget: totalBudget,
            totalAllocated: pocketsForDisplay
                .fold(0.0, (sum, e) => sum + e.getLimit(totalBudget)),
            totalSpent: totalSpent,
            periodMonth: state.periodMonth,
            previousBudget: state.previousBudget,
            onReusePrevious: state.previousBudget > 0
                ? () => notifier.reusePreviousBudget(state.previousBudget)
                : null,
            colorScheme: colorScheme,
            onTotalChanged: notifier.updateTotalBudget,
            onSave: notifier.saveChanges,
            currency: selectedCurrency,
            onDateSelected: onDateSelected,
            amountSpotlightKey: headerAmountKey,
            isSkeleton: isLoading,
          ),
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
                    child: AdaptiveSegmentedControl(
                      labels: const [],
                      // Platform-specific icons for grid view
                      sfSymbols: [
                        PlatformInfo.isIOS26OrHigher()
                            ? 'square.grid.2x2.fill'
                            : PlatformInfo.isIOS
                                ? CupertinoIcons.square_grid_2x2_fill
                                : Icons.dashboard,
                        PlatformInfo.isIOS26OrHigher()
                            ? 'list.bullet'
                            : PlatformInfo.isIOS
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
            if (viewMode.value == 'grid')
              ReorderableGridView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        onTap: () {
                          if (totalBudget <= 0) {
                            AppToast.info(context,
                                context.l10n.pleaseSetMonthlyBudgetFirst);
                            return;
                          }
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (sheetContext) {
                              return EditPocketEnvelopeSheet(
                                scopeParams: scopeParams,
                                budgetId: state.budgetId,
                                totalBudget: totalBudget,
                                unallocatedBudget: state.unallocatedSpend,
                                allPockets: state.editing,
                              );
                            },
                          );
                        },
                      ),
                    );
                  }

                  final pocket = pocketsForDisplay[index];
                  return KeyedSubtree(
                    key: ValueKey(pocket.id),
                    child: PocketCard(
                      pocket: pocket,
                      colorScheme: colorScheme,
                      totalBudget: totalBudget,
                      envelopeMode: true,
                      onPercentageChanged: (value) =>
                          notifier.updatePocketPercentage(pocket.id, value),
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
            else
              ReorderableGridView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        onTap: () {
                          if (totalBudget <= 0) {
                            AppToast.info(context,
                                context.l10n.pleaseSetMonthlyBudgetFirst);
                            return;
                          }
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (sheetContext) {
                              return EditPocketEnvelopeSheet(
                                scopeParams: scopeParams,
                                budgetId: state.budgetId,
                                totalBudget: totalBudget,
                                unallocatedBudget: state.unallocatedSpend,
                                allPockets: state.editing,
                              );
                            },
                          );
                        },
                      ),
                    );
                  }

                  final pocket = pocketsForDisplay[index];
                  return Padding(
                    key: ValueKey(pocket.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PocketListTile(
                      pocket: pocket,
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
                  );
                },
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
              colorScheme: colorScheme,
              currency: selectedCurrency,
            ),
          ],
        ],
      ),
    );
  }
}

List<PocketEnvelope> _buildFakePockets(String currency) {
  final now = DateTime.now();
  return [
    PocketEnvelope(
      id: 'fake-1',
      name: 'Groceries',
      percentage: 25,
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
      name: 'Bills',
      percentage: 30,
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
      name: 'Dining Out',
      percentage: 15,
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
      name: 'Fun',
      percentage: 10,
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
