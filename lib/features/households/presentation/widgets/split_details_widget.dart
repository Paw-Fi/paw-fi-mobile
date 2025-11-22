import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Widget to display split details in transaction detail sheets
class SplitDetailsWidget extends ConsumerWidget {
  final String splitGroupId;
  final String householdId;

  const SplitDetailsWidget({
    super.key,
    required this.splitGroupId,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // In real app, fetch split group data from provider
    // For now, show placeholder UI
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.call_split,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.splitDetails,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Split type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                context.l10n.equalSplit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Split lines (placeholder - replace with actual data)
            _SplitLine(
              userName: 'You',
              amount: '\$25.00',
              isSettled: false,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
            _SplitLine(
              userName: 'John Doe',
              amount: '\$25.00',
              isSettled: true,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
            _SplitLine(
              userName: 'Jane Smith',
              amount: '\$25.00',
              isSettled: false,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),

            // Settle up button
            PrimaryAdaptiveButton(
              onPressed: () {
                // Implement settle up flow
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(context.l10n.markAsSettled),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitLine extends StatelessWidget {
  final String userName;
  final String amount;
  final bool isSettled;
  final dynamic colorScheme;

  const _SplitLine({
    required this.userName,
    required this.amount,
    required this.isSettled,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            userName,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.foreground,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(width: 12),
        if (isSettled)
          Icon(
            Icons.check_circle,
            color: colorScheme.primary,
            size: 20,
          )
        else
          Icon(
            Icons.pending,
            color: colorScheme.destructive,
            size: 20,
          ),
      ],
    );
  }
}
