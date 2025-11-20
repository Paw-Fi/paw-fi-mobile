import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_grid_section.dart';
import 'package:moneko/features/utils/main_page_top_padding.dart';
import 'package:moneko/shared/widgets/plain-adaptive-button.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

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
            child: Padding(
              padding:EdgeInsets.only(top:getTopPadding(context),bottom: getBottomPadding()),
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
                    uncategorizedExpenses:
                        pocketsState.uncategorizedExpenses,
                  ),
                ),
              ),
            ],
          ),
            ),
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
                          Flexible(
                            child: PlainAdaptiveButton(
                              onPressed: pocketsNotifier.revertChanges,
                              child: Text('Revert',
                                  style: TextStyle(color: colorScheme.error)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: PrimaryAdaptiveButton(
                              onPressed: pocketsNotifier.saveChanges,
                              child: const Text('Save'),
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
    );
  }
}
