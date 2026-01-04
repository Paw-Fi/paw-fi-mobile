import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/util/logger.dart';

class SavingsRateTile extends ConsumerWidget {
  const SavingsRateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final rate = ref.watch(savingsRateProvider);
    appLog('widget_viewed: savings_rate_tile');

    final pct = (rate * 100).clamp(-999, 999).toStringAsFixed(0);
    final positive = rate >= 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with value on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.savingsRate,
                  style: TextStyle(
                      fontSize: 13, color: colorScheme.mutedForeground)),
              Text('$pct%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.foreground)),
            ],
          ),
          const SizedBox(height: 8),
          // Small sentiment chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (positive ? colorScheme.success : colorScheme.destructive)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(positive ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: positive
                        ? colorScheme.success
                        : colorScheme.destructive),
                const SizedBox(width: 6),
                Text(
                  positive ? context.l10n.positive : context.l10n.negative,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: positive
                        ? colorScheme.success
                        : colorScheme.destructive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
