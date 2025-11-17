import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/currency_dropdown_button.dart';
import 'package:moneko/features/home/presentation/widgets/date_range_filter_modal.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/household_selector.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';

final householdSelectorExpandedProvider = StateProvider<bool>((ref) => false);

/// Header for pages that includes:
/// - Title
/// - Personal/Household switch
/// - Currency selector
/// - Date range filter
///
class HomeHeaderSliver extends ConsumerWidget {
  const HomeHeaderSliver({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final filterState = ref.watch(homeFilterProvider);

    return Column(
      children: [
        // Title and account type switch
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -1,
                ),
              ),
              _AccountTypeSwitch(
                viewMode: viewMode,
                colorScheme: colorScheme,
                onPersonalSelected: () => _setPersonalMode(ref),
                onHouseholdSelected: () => _switchToHouseholdMode(context, ref),
              ),
            ],
          ),
        ),

        // Period selector and currency button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: currency selector
              const CurrencyDropdownButton(),
              // Right: date filter
              GestureDetector(
                onTap: () => _showDateRangeFilter(context),
                child: Row(
                  children: [
                    Text(
                      filterState.dateRangeFilter.getLabel(context),
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (viewMode.mode == ViewMode.household)
          const _HouseholdSelectorDropdown(),

        const SizedBox(height: 16),
      ],
    );
  }

  static void _setPersonalMode(WidgetRef ref) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    ref.read(viewModeProvider.notifier).setPersonalMode();
  }

  static void _switchToHouseholdMode(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    // Switch to household mode and invalidate households so data is refreshed.
    final user = ref.read(authProvider);
    debugPrint('🔄 Switching to household mode - invalidating userHouseholdsProvider');
    ref.invalidate(userHouseholdsProvider(user.uid));
    ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
  }

  static void _showDateRangeFilter(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    showDateRangeFilter(
      context,
      colorScheme,
      height: 480,
    );
  }
}

class _HouseholdSelectorDropdown extends ConsumerWidget {
  const _HouseholdSelectorDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final user = ref.watch(authProvider);
    if (user.isEmpty) {
      return const SizedBox.shrink();
    }

    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedState = ref.watch(selectedHouseholdProvider);
    final isExpanded = ref.watch(householdSelectorExpandedProvider);

    return householdsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (households) {
        if (households.isEmpty) {
          return const SizedBox.shrink();
        }

        final household = selectedState.household ?? households.first;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: GestureDetector(
            onTap: () {
              final notifier = ref.read(householdSelectorExpandedProvider.notifier);
              notifier.state = !notifier.state;
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        width: isExpanded ? 0 : 48,
                        height: 48,
                        margin: EdgeInsets.only(right: isExpanded ? 0 : 12),
                        child: AnimatedOpacity(
                          opacity: isExpanded ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: OverflowBox(
                            maxWidth: 48,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colorScheme.border.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: household.coverImageUrl != null
                                  ? Image.network(
                                      household.coverImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) => Container(
                                        color: colorScheme.muted.withValues(alpha: 0.5),
                                        child: Icon(
                                          Icons.home_rounded,
                                          size: 24,
                                          color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: colorScheme.muted.withValues(alpha: 0.5),
                                      child: Icon(
                                        Icons.home_rounded,
                                        size: 24,
                                        color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          household.name,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: colorScheme.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.muted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HouseholdSettingsPage(householdId: household.id),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.settings_outlined,
                              size: 20,
                              color: colorScheme.foreground.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: colorScheme.mutedForeground,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  child: isExpanded
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 8),
                            HouseholdSelector(),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccountTypeSwitch extends StatelessWidget {
  const _AccountTypeSwitch({
    required this.viewMode,
    required this.colorScheme,
    required this.onPersonalSelected,
    required this.onHouseholdSelected,
  });

  final ViewModeState viewMode;
  final shadcnui.ColorScheme colorScheme;
  final VoidCallback onPersonalSelected;
  final VoidCallback onHouseholdSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.muted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Personal
          GestureDetector(
            onTap: viewMode.mode == ViewMode.personal ? null : onPersonalSelected,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: viewMode.mode == ViewMode.personal
                    ? colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.l10n.forMe,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: viewMode.mode == ViewMode.personal ? FontWeight.w600 : FontWeight.w500,
                  color: viewMode.mode == ViewMode.personal
                      ? colorScheme.primaryForeground
                      : colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
          // Household
          GestureDetector(
            onTap: viewMode.mode == ViewMode.household ? null : onHouseholdSelected,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: viewMode.mode == ViewMode.household
                    ? colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.l10n.forUs,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: viewMode.mode == ViewMode.household ? FontWeight.w600 : FontWeight.w500,
                  color: viewMode.mode == ViewMode.household
                      ? colorScheme.primaryForeground
                      : colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
