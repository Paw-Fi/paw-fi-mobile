import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_grid_section.dart';

class PocketsPage extends ConsumerWidget {
  const PocketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);

    final pocketsScopeParams = viewMode.mode == ViewMode.personal
        ? const PocketsScopeParams(scope: PocketsScopeType.personal)
        : PocketsScopeParams(
            scope: PocketsScopeType.household,
            householdId: selectedHouseholdState.householdId,
          );

    final pocketsState = ref.watch(pocketsProvider(pocketsScopeParams));
    final pocketsNotifier =
        ref.read(pocketsProvider(pocketsScopeParams).notifier);

    final hasChanges = pocketsState.hasChanges;
    final totalBudget = pocketsState.totalBudget;
    final totalPercentage = pocketsState.totalPercentage;
    final remaining = 100.0 - totalPercentage; // Remaining percentage

    Future<void> refresh() async {
      final user = ref.read(authProvider);
      final filter = ref.read(homeFilterProvider);
      final range = getDateRangeFromFilter(
        filter.dateRangeFilter,
        filter.customStartDate,
        filter.customEndDate,
      );

      await ref.read(analyticsProvider.notifier).loadData(
            user.uid,
            startDate: range['from'],
            endDate: range['to'],
          );

      final selectedHousehold = ref.read(selectedHouseholdProvider).householdId;

      // Invalidate pockets provider so envelopes are reloaded
      final viewModeValue = ref.read(viewModeProvider);
      final scope = viewModeValue.mode == ViewMode.personal
          ? const PocketsScopeParams(scope: PocketsScopeType.personal)
          : PocketsScopeParams(
              scope: PocketsScopeType.household,
              householdId: selectedHousehold,
            );

      ref.invalidate(pocketsProvider(scope));
    }

    return AdaptiveScaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                    child: PocketsGridSection(
                      scopeParams: pocketsScopeParams,
                      colorScheme: colorScheme,
                      isPersonalMode: viewMode.mode == ViewMode.personal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            left: 24,
            right: 24,
            bottom: hasChanges ? 32 : -100,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: hasChanges ? 1.0 : 0.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Unsaved Changes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  remaining >= 0
                                      ? '${remaining.toStringAsFixed(0)} remaining'
                                      : '${remaining.abs().toStringAsFixed(0)} over',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: remaining >= 0
                                        ? colorScheme.mutedForeground
                                        : colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AdaptiveButton(
                          onPressed: pocketsNotifier.revertChanges,
                          style: AdaptiveButtonStyle.plain,
                          label: 'Revert',
                        ),
                        const SizedBox(width: 8),
                        AdaptiveButton(
                          onPressed: pocketsNotifier.saveChanges,
                          style: AdaptiveButtonStyle.filled,
                          label: 'Save',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PocketsGlowCircle extends StatelessWidget {
  const _PocketsGlowCircle({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.28),
            blurRadius: 80,
            spreadRadius: 40,
          ),
        ],
      ),
    );
  }
}
