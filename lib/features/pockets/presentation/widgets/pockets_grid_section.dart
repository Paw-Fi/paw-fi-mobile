import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/pages/pocket_details_page.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/add_envelope_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/add_envelope_list_tile.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_list_tile.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/simple_spending_list.dart';
import 'package:moneko/features/pockets/presentation/widgets/uncategorized_banner.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketsGridSection extends HookConsumerWidget {
  const PocketsGridSection({
    super.key,
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
    this.uncategorizedExpenses = const {},
  });

  final PocketsScopeParams scopeParams;
  final ColorScheme colorScheme;
  final bool isPersonalMode;
  final Map<String, List<Map<String, dynamic>>> uncategorizedExpenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);
    final filter = ref.watch(homeFilterProvider);
    final selectedCurrency = filter.selectedCurrency ?? 'USD';

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

    void markHelpAsSeen() {
      hasSeenEnvelopeModeHelp.value = true;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('has_seen_envelope_mode_help', true);
      });
    }

    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (uncategorized.isNotEmpty) ...[
          UncategorizedBanner(
            colorScheme: colorScheme,
            currency: selectedCurrency,
            uncategorized: uncategorized,
            uncategorizedExpenses: uncategorizedExpenses,
          ),
          const SizedBox(height: 16),
        ],
        PocketsHeaderCard(
          totalBudget: totalBudget,
          totalAllocated: state.editing
              .fold(0.0, (sum, e) => sum + e.getLimit(totalBudget)),
          totalSpent: totalSpent,
          periodMonth: state.periodMonth,
          previousBudget: state.previousBudget,
          onReusePrevious: state.previousBudget > 0
              ? () => notifier.reusePreviousBudget(state.previousBudget)
              : null,
          colorScheme: colorScheme,
          onTotalChanged: notifier.updateTotalBudget,
          envelopeMode: envelopeMode.value,
          onEnvelopeModeChanged: (value) => envelopeMode.value = value,
          currency: selectedCurrency,
          hasSeenHelp: hasSeenEnvelopeModeHelp.value,
          onHelpSeen: markHelpAsSeen,
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
              const Spacer(),
              // View Toggle
              SizedBox(
                width: 90,
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
              itemCount: sortedPockets.length + 1,
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
                final isAddTile = index == sortedPockets.length;
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

                final pocket = sortedPockets[index];
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
                mainAxisSpacing: 16,
              ),
              itemCount: sortedPockets.length + 1,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex == sortedPockets.length) return;
                if (newIndex > sortedPockets.length) {
                  newIndex = sortedPockets.length;
                }
                onReorder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final isAddTile = index == sortedPockets.length;
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

                final pocket = sortedPockets[index];
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
            pockets: state.editing,
            totalSpent: totalSpent,
            colorScheme: colorScheme,
            currency: selectedCurrency,
          ),
        ],
      ],
    );
  }
}
