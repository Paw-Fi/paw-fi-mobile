import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../domain/models/goal.dart';
import '../providers/goals_providers.dart';
import '../../../../core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/utils/currency.dart';

class GoalCard extends ConsumerWidget {
  final Goal goal;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: goal.isSavings
                          ? colorScheme.success.withValues(alpha: 0.1)
                          : colorScheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      goal.isSavings ? Icons.savings : Icons.trending_down,
                      color: goal.isSavings
                          ? colorScheme.success
                          : colorScheme.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (goal.privacyRedacted)
                              _buildPrivacyBadge(context),
                          ],
                        ),
                        Text(
                          goal.isSavings ? l10n.savings : l10n.paydown,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  if (goal.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.completed,
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (!goal.isOnTrack)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.offTrack,
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.destructive,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${goal.currency} ${formatAmount(goal.currentAmount)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${goal.currency} ${formatAmount(goal.targetAmount)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: goal.progressPercentage / 100,
                    minHeight: 8,
                    backgroundColor: colorScheme.muted,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isSavings
                          ? colorScheme.success
                          : colorScheme.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${goal.progressPercentage.toStringAsFixed(1)}% ${l10n.complete}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Target date and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: colorScheme.mutedForeground),
                      const SizedBox(width: 4),
                      Text(
                        goal.targetDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  // Acknowledgement button (for partner's goals)
                  if (!goal.isOwner && !goal.isAcknowledged)
                    OutlinedButton(
                      onPressed: () => _acknowledgeGoal(context, ref),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        l10n.acknowledge,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )
                  else if (!goal.isOwner && goal.isAcknowledged)
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: colorScheme.success),
                        const SizedBox(width: 4),
                        Text(
                          l10n.acknowledged,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.success,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyBadge(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off,
              size: 10, color: colorScheme.mutedForeground),
          const SizedBox(width: 4),
          Text(
            l10n.balancesOnly,
            style: TextStyle(
              fontSize: 9,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acknowledgeGoal(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;

    // Get current user ID (assuming from some auth provider)
    // TODO: Get actual user ID from auth provider
    const userId = 'current-user-id';

    await ref.read(acknowledgeGoalProvider.notifier).acknowledgeGoal(
          userId,
          goal.id,
          householdId: goal.householdId,
        );

    if (context.mounted) {
      AppToast.success(context, l10n.goalAcknowledged);
    }
  }
}
