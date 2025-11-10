import 'package:flutter/material.dart' hide Card;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/auth/data/services/impersonation_service.dart';
import 'package:moneko/features/auth/presentation/widgets/impersonation_dialog.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';

/// Card for admin users to access impersonation functionality
Widget buildImpersonationCard(BuildContext context, WidgetRef ref) {
  final user = ref.watch(authProvider);
  final userProfile = ref.watch(userProfileProvider(user.uid));

  return userProfile.when(
    data: (profile) {
      if (profile == null || !profile.isCreator) {
        return const SizedBox.shrink();
      }

      final colorScheme = shadcnui.Theme.of(context).colorScheme;
      final impersonation = ref.watch(impersonationProvider);

      return shadcnui.Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const shadcnui.Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Tools',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const shadcnui.Gap(4),
                        Text(
                          'Impersonate users for debugging',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const shadcnui.Gap(16),
              if (impersonation.isImpersonating) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                      const shadcnui.Gap(8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Currently viewing as:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              impersonation.impersonatedEmail ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const shadcnui.Gap(12),
                shadcnui.OutlineButton(
                  onPressed: () {
                    ref.read(impersonationProvider.notifier).stopImpersonation();
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 18),
                      shadcnui.Gap(8),
                      Text('Exit Impersonation'),
                    ],
                  ),
                ),
              ] else ...[
                shadcnui.PrimaryButton(
                  onPressed: () {
                    ImpersonationDialog.show(context);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_search, size: 18),
                      shadcnui.Gap(8),
                      Text('Impersonate User'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
    loading: () => const SizedBox.shrink(),
    error: (_, __) => const SizedBox.shrink(),
  );
}
