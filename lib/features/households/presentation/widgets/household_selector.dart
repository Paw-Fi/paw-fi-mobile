// Household selector widget
// Horizontal scrollable list of households with + button to create new
// Shows cover images as circular/rounded tiles

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../pages/household_create_page.dart';
import 'package:moneko/features/auth/auth.dart';

/// Household selector component
/// Horizontal scrollable list displaying all households
class HouseholdSelector extends ConsumerWidget {
  const HouseholdSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
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
  final shadcnui.ColorScheme colorScheme;

  const _HouseholdSelectorContent({
    required this.households,
    required this.selectedHouseholdId,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: households.length + 1, // +1 for add button
        itemBuilder: (context, index) {
          // Add new household button
          if (index == households.length) {
            return _AddHouseholdTile(colorScheme: colorScheme);
          }

          // Household tile
          final household = households[index];
          final isSelected = household.id == selectedHouseholdId;

          return _HouseholdTile(
            household: household,
            isSelected: isSelected,
            colorScheme: colorScheme,
            onTap: () async {
              // Trigger light haptic feedback
              HapticFeedback.lightImpact();
              
              final user = ref.read(authProvider);
              await ref
                  .read(selectedHouseholdProvider.notifier)
                  .selectHousehold(household.id, user.uid);
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
  final shadcnui.ColorScheme colorScheme;
  final VoidCallback onTap;

  const _HouseholdTile({
    required this.household,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected household is larger (100x100), others are smaller (70x70)
    final size = isSelected ? 95.0 : 65.0;
    final borderRadius = isSelected ? 18.0 : 14.0;
    final iconSize = isSelected ? 40.0 : 28.0;
    
    return Align(
      alignment: Alignment.topLeft, // Top-align all tiles
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          width: size,
          height: size,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
           
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: household.coverImageUrl != null
                ? Image.network(
                    household.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: colorScheme.muted,
                      child: Icon(
                        Icons.home_rounded,
                        size: iconSize,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  )
                : Container(
                    color: colorScheme.muted,
                    child: Icon(
                      Icons.home_rounded,
                      size: iconSize,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Add new household tile
class _AddHouseholdTile extends StatelessWidget {
  final shadcnui.ColorScheme colorScheme;

  const _AddHouseholdTile({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft, // Top-align with other tiles
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HouseholdCreatePage(),
            ),
          );
        },
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            size: 32,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton
class _LoadingSkeleton extends StatelessWidget {
  final shadcnui.ColorScheme colorScheme;

  const _LoadingSkeleton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: colorScheme.muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
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
  final shadcnui.ColorScheme colorScheme;
  final String error;

  const _ErrorState({required this.colorScheme, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 8, bottom: 16, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.destructive.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.destructive.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              color: colorScheme.destructive, size: 24),
          const SizedBox(width: 12),
          Text(
            'Error loading households',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.destructive,
            ),
          ),
        ],
      ),
    );
  }
}
