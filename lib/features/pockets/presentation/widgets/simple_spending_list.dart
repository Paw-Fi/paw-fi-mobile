import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/utils/currency.dart';

class SimpleSpendingList extends StatelessWidget {
  const SimpleSpendingList({
    super.key,
    required this.pockets,
    required this.totalSpent,
    required this.aggregateSpentByPocketId,
    required this.colorScheme,
  });

  final List<PocketEnvelope> pockets;
  final double totalSpent;
  final Map<String, double> aggregateSpentByPocketId;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (pockets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.noSpendingData,
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
        ),
      );
    }

    final hasCompleteAggregateSpend = pockets.isNotEmpty &&
        pockets
            .every((pocket) => aggregateSpentByPocketId.containsKey(pocket.id));
    final shareDenominator = !hasCompleteAggregateSpend
        ? pockets.fold<double>(0, (sum, pocket) => sum + pocket.spent)
        : totalSpent;

    // Sort by aggregate spend when available so mixed-currency rows are comparable.
    final sortedPockets = [...pockets]..sort(
        (a, b) => _spentForShare(b, hasCompleteAggregateSpend)
            .compareTo(_spentForShare(a, hasCompleteAggregateSpend)),
      );

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedPockets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pocket = sortedPockets[index];
        final aggregateSpent =
            _spentForShare(pocket, hasCompleteAggregateSpend);
        final shareOfTotal =
            shareDenominator > 0 ? (aggregateSpent / shareDenominator) : 0.0;

        final iconData = getPocketIconData(pocket.icon);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.pocketCardSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.pocketCardBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconData,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pocket.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.percentageOfSpending(
                              (shareOfTotal * 100).toStringAsFixed(1)),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrency(pocket.spent, pocket.currency),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Visual Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: colorScheme.pocketProgressTrack,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: shareOfTotal.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _spentForShare(PocketEnvelope pocket, bool hasCompleteAggregateSpend) {
    if (!hasCompleteAggregateSpend) return pocket.spent;
    return aggregateSpentByPocketId[pocket.id] ?? 0;
  }
}
