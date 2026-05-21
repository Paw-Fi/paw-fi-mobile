import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/household_providers.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/utils/currency.dart';

class RecentSplitsList extends ConsumerWidget {
  final String householdId;

  const RecentSplitsList({super.key, required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final splitsAsync = ref.watch(householdSplitsProvider(
      HouseholdSplitsParams(householdId: householdId),
    ));

    return splitsAsync.when(
      data: (splits) {
        if (splits.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.call_split, size: 48, color: colorScheme.muted),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.noSplitsYet,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.startSplittingExpensesWithYourHousehold,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.mutedForeground),
                  ),
                ],
              ),
            ),
          );
        }

        final recentSplits = splits.take(5).toList();

        return Column(
          children: recentSplits.map((split) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.muted,
                  child: const Icon(Icons.call_split, size: 20),
                ),
                title: Text(
                  split.description ?? context.l10n.split,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                subtitle: Text(
                  '${_formatSplitType(split.splitType)} • ${split.currency} ${formatAmount(split.totalAmountCents / 100)}',
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
                trailing: Text(
                  _formatDate(context, split.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TransactionsPage(householdId: householdId),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l10n.errorLoadingSplits,
              style: TextStyle(color: colorScheme.destructive)),
        ),
      ),
    );
  }

  String _formatSplitType(dynamic splitType) {
    final typeStr = splitType.toString().split('.').last;
    return typeStr[0].toUpperCase() + typeStr.substring(1);
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return context.l10n.minutesAgoShort(difference.inMinutes);
      }
      return context.l10n.hoursAgoShort(difference.inHours);
    } else if (difference.inDays < 7) {
      return context.l10n.daysAgoShort(difference.inDays);
    } else {
      return context.l10n.weeksAgoShort((difference.inDays / 7).floor());
    }
  }
}
