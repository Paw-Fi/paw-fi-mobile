// Household selector widget
// Horizontal scrollable list of households with + button to create new
// Shows cover images as circular/rounded tiles

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../pages/create_space_page.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Household selector component
/// Horizontal scrollable list displaying all households
class HouseholdSelector extends ConsumerWidget {
  const HouseholdSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedState = ref.watch(selectedHouseholdProvider);

    return householdsAsync.when(
      data: (households) {
        if (households.isEmpty) {
          return const SizedBox.shrink();
        }

        return _HouseholdSelectorContent(
          households: households,
          selectedHouseholdId: selectedState.householdId,
          colorScheme: colorScheme,
        );
      },
      loading: () => _LoadingSkeleton(colorScheme: colorScheme),
      error: (error, stack) => _ErrorState(
        colorScheme: colorScheme,
        error: error.toString(),
      ),
    );
  }
}

/// Household selector content - horizontal scrollable list
class _HouseholdSelectorContent extends ConsumerWidget {
  final List<Household> households;
  final String? selectedHouseholdId;
  final ColorScheme colorScheme;

  const _HouseholdSelectorContent({
    required this.households,
    required this.selectedHouseholdId,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: households.length + 1,
        itemBuilder: (context, index) {
          if (index == households.length) {
            return _AddHouseholdTile(colorScheme: colorScheme);
          }

          final household = households[index];
          final isSelected = household.id == selectedHouseholdId;

          return _HouseholdTile(
            household: household,
            isSelected: isSelected,
            colorScheme: colorScheme,
            onTap: () async {
              HapticFeedback.lightImpact();
              debugPrint(
                  '🏠 [DEEP LINK TEST] Household selected: ${household.id}');
              debugPrint(
                  '🔗 [DEEP LINK TEST] Test with: moneko://household/${household.id}');
              await ref
                  .read(selectedHouseholdProvider.notifier)
                  .selectHousehold(household.id);
            },
          );
        },
      ),
    );
  }
}

/// Individual household tile
class _HouseholdTile extends StatelessWidget {
  final Household household;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _HouseholdTile({
    required this.household,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSelected
        ? MediaQuery.sizeOf(context).width * 0.27
        : MediaQuery.sizeOf(context).width * 0.2;
    final radius = isSelected ? 24.0 : 20.0;
    final iconSize = isSelected ? 42.0 : 36.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: size,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.6)
                        : colorScheme.border.withValues(alpha: 0.4),
                    width: isSelected ? 2.5 : 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: household.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: household.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.muted.withValues(alpha: 0.5),
                          child: Icon(
                            Icons.home_rounded,
                            size: iconSize,
                            color: colorScheme.mutedForeground
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : Container(
                        color: colorScheme.muted.withValues(alpha: 0.5),
                        child: Icon(
                          Icons.home_rounded,
                          size: iconSize,
                          color: colorScheme.mutedForeground
                              .withValues(alpha: 0.7),
                        ),
                      ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 6),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Add new household tile
class _AddHouseholdTile extends StatelessWidget {
  final ColorScheme colorScheme;

  const _AddHouseholdTile({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;

    // Match inactive tile layout: fixed width 'size' and inner square of size x size
    final size = MediaQuery.sizeOf(context).width * 0.2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateSpacePage(),
            ),
          );
        },
        child: SizedBox(
          width: size,
          child: Column(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colorScheme.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 25,
                  color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton
class _LoadingSkeleton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _LoadingSkeleton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Error state
class _ErrorState extends StatelessWidget {
  final ColorScheme colorScheme;
  final String error;

  const _ErrorState({required this.colorScheme, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.destructive.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: colorScheme.destructive, size: 24),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              context.l10n.errorLoadingHouseholds,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.destructive,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
