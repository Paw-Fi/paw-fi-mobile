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
    final totalSpent = pocketsState.totalSpent;
    final remaining = totalBudget - totalSpent;

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
          if (hasChanges)
            Positioned(
              left: 16,
              right: 16,
              top: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.card.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.border.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: AdaptiveButton(
                              onPressed: pocketsNotifier.revertChanges,
                              style: AdaptiveButtonStyle.plain,
                              label: 'Revert',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              remaining >= 0
                                  ? 'Remaining: ${remaining.toStringAsFixed(0)}'
                                  : 'Over budget: ${remaining.abs().toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: remaining >= 0
                                    ? colorScheme.mutedForeground
                                    : colorScheme.destructive,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            fit: FlexFit.loose,
                            child: AdaptiveButton(
                              onPressed: pocketsNotifier.saveChanges,
                              style: AdaptiveButtonStyle.filled,
                              label: 'Save',
                            ),
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
