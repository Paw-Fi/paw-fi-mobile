import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

enum ManageMembershipChoice { viewStatus, cancelPlan }

class ManageMembershipChoiceSheet extends StatelessWidget {
  const ManageMembershipChoiceSheet({super.key});

  static Future<ManageMembershipChoice?> show(BuildContext context) {
    return MonekoBottomSheet.show<ManageMembershipChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ManageMembershipChoiceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.manageMembershipTitle,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _ManageMembershipOptionTile(
              icon: Icon(
                Icons.visibility_outlined,
                color: colorScheme.primary,
              ),
              title: l10n.manageMembershipViewStatus,
              description: l10n.manageMembershipViewStatusDescription,
              onTap: () => Navigator.of(context).pop(
                ManageMembershipChoice.viewStatus,
              ),
            ),
            const SizedBox(height: 12),
            _ManageMembershipOptionTile(
              icon: Icon(
                Icons.cancel_outlined,
                color: colorScheme.primary,
              ),
              title: l10n.manageMembershipCancelPlan,
              description: l10n.manageMembershipCancelPlanDescription,
              onTap: () => Navigator.of(context).pop(
                ManageMembershipChoice.cancelPlan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageMembershipOptionTile extends StatelessWidget {
  const _ManageMembershipOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
