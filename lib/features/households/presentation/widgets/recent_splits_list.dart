import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../providers/household_providers.dart';

class RecentSplitsList extends ConsumerWidget {
  final String householdId;

  const RecentSplitsList({super.key, required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
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
                    'No splits yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start splitting expenses with your household',
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
                  split.description ?? 'Split',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                subtitle: Text(
                  '${_formatSplitType(split.splitType)} • ${split.currency} ${(split.totalAmountCents / 100).toStringAsFixed(2)}',
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
                trailing: Text(
                  _formatDate(split.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error loading splits', style: TextStyle(color: colorScheme.destructive)),
        ),
      ),
    );
  }

  String _formatSplitType(dynamic splitType) {
    final typeStr = splitType.toString().split('.').last;
    return typeStr[0].toUpperCase() + typeStr.substring(1);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}
