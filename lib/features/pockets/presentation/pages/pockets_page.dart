import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/home_header_sliver.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_grid_section.dart';

class PocketsPage extends ConsumerWidget {
  const PocketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);

    final pocketsScopeParams = viewMode.mode == ViewMode.personal
        ? const PocketsScopeParams(scope: PocketsScopeType.personal)
        : PocketsScopeParams(
            scope: PocketsScopeType.household,
            householdId: selectedHouseholdState.householdId,
          );

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

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: HomeHeaderSliver()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PocketsGridSection(
                        scopeParams: pocketsScopeParams,
                        colorScheme: colorScheme,
                        isPersonalMode: viewMode.mode == ViewMode.personal,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
