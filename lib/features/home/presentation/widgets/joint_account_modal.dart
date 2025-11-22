import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../state/analytics_provider.dart';
import '../../../utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

/// Navigate to household screen (either overview or onboarding)
void navigateToHousehold(BuildContext context, WidgetRef ref) async {
  // Get current user ID
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    AppToast.info(context, context.l10n.userNotLoggedIn);
    return;
  }

  // Get user's households
  final householdsAsync = ref.read(userHouseholdsProvider(userId));

  householdsAsync.when(
    data: (households) {
      if (households.isNotEmpty) {
        // User has household(s), close modal
        // Navigation is handled by the home screen
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // No household, show onboarding modal
        showHouseholdOnboardingModal(context, ref, userId);
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
      AppToast.error(context, context.l10n.errorLoadingHouseholds);
    },
  );
}

/// Show household onboarding modal (create or join)
void showHouseholdOnboardingModal(BuildContext context, WidgetRef ref, String userId) {
  final colorScheme = Theme.of(context).colorScheme;

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
          color: colorScheme.appBackground,
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
                    context.l10n.welcomeToHouseholds,
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
              context.l10n.householdsDescription,
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
              child: PrimaryAdaptiveButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showCreateHouseholdDialog(context, ref, userId);
                },
                child: Text(
                  context.l10n.createHousehold,
                  style: const TextStyle(
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
              child: AdaptiveButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  AppToast.info(context, context.l10n.pleaseUseInvitationLink);
                },
                style: AdaptiveButtonStyle.bordered,
                label: context.l10n.joinWithInvite,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Show create household dialog
void _showCreateHouseholdDialog(BuildContext context, WidgetRef ref, String userId) {
  final colorScheme = Theme.of(context).colorScheme;
  final nameController = TextEditingController();

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
          color: colorScheme.appBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.createHousehold,
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
              decoration: InputDecoration(
                labelText: context.l10n.householdName,
                hintText: context.l10n.householdNameHint,
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: AdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AdaptiveButtonStyle.plain,
                    label: context.l10n.cancel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdaptiveButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        AppToast.info(context, context.l10n.pleaseEnterHouseholdName);
                        return;
                      }

                      try {
                        // Determine currency: default to user's preferred or USD
                        final analytics = ref.read(analyticsProvider);
                        final preferred = analytics.preferredCurrency?.toUpperCase();
                        final currency = isSupportedCurrencyCode(preferred) ? preferred! : 'USD';
                        // Create household
                        await ref
                            .read(userHouseholdsProvider(userId).notifier)
                            .createHousehold(
                              name: nameController.text,
                              currency: currency,
                            );

                        // Get the created household from the state
                        final householdsAsync = ref.read(userHouseholdsProvider(userId));
                        final households = householdsAsync.value ?? [];

                        if (context.mounted && households.isNotEmpty) {
                          // Close the modal, navigation is handled by the home screen
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppToast.error(context, context.l10n.errorCreatingHousehold);
                        }
                      }
                    },
                    label: context.l10n.create,
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
void showJointAccountModal(BuildContext context, ColorScheme colorScheme) {
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
          color: colorScheme.appBackground,
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
                    context.l10n.householdsFeature,
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
              context.l10n.householdsFeatureDescription,
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
              child: AdaptiveButton(
                onPressed: () => Navigator.of(context).pop(),
                label: context.l10n.gotIt,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
