import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../../households/presentation/providers/household_providers.dart';
import '../../../households/presentation/pages/household_overview_page.dart';

/// Navigate to household screen (either overview or onboarding)
void navigateToHousehold(BuildContext context, WidgetRef ref) {
  // Get user's households
  final householdsAsync = ref.read(userHouseholdsProvider);

  householdsAsync.when(
    data: (households) {
      if (households.isNotEmpty) {
        // User has household(s), navigate to first one
        final household = households.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HouseholdOverviewPage(
              householdId: household.id,
            ),
          ),
        );
      } else {
        // No household, show onboarding modal
        showHouseholdOnboardingModal(context, ref);
      }
    },
    loading: () {
      // Show loading indicator
      showDialog(
        context: context,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    },
    error: (error, stack) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading households: $error')),
      );
    },
  );
}

/// Show household onboarding modal (create or join)
void showHouseholdOnboardingModal(BuildContext context, WidgetRef ref) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with emoji
            Row(
              children: [
                const Text('🏠', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Welcome to Households!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            Text(
              'Manage shared finances with your family, partner, or roommates. Track budgets, split expenses, and collaborate on money decisions.',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colorScheme.mutedForeground,
              ),
            ),

            const SizedBox(height: 24),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: shadcnui.PrimaryButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showCreateHouseholdDialog(context, ref);
                },
                child: const Text(
                  'Create Household',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Join button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: shadcnui.OutlineButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please use an invitation link to join a household')),
                  );
                },
                child: const Text(
                  'Join with Invite',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Show create household dialog
void _showCreateHouseholdDialog(BuildContext context, WidgetRef ref) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  final nameController = TextEditingController();
  final emojiController = TextEditingController(text: '🏠');

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Household',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 20),

            // Name field
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Household Name',
                hintText: 'e.g., The Smiths',
              ),
            ),

            const SizedBox(height: 16),

            // Emoji field
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji (optional)',
                hintText: '🏠',
              ),
              maxLength: 2,
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: shadcnui.OutlineButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: shadcnui.PrimaryButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a household name')),
                        );
                        return;
                      }

                      try {
                        final household = await ref
                            .read(userHouseholdsProvider.notifier)
                            .createHousehold(
                              name: nameController.text,
                              emoji: emojiController.text.isEmpty ? null : emojiController.text,
                            );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HouseholdOverviewPage(
                                householdId: household.id,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error creating household: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// Legacy function for backwards compatibility
void showJointAccountModal(BuildContext context, shadcnui.ColorScheme colorScheme) {
  // This is deprecated, but kept for backwards compatibility
  // It will be removed once all references are updated
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏠', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Households Feature',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'The Households feature is now available! Manage shared finances with family, partners, or roommates.',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: shadcnui.PrimaryButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
