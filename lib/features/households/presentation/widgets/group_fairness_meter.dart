import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

class GroupFairnessMeter extends StatelessWidget {
  final HouseholdSummary summary;
  final List<ExpenseEntry>?
      transactions; // Kept for backward compatibility but unused
  final DateTime? from; // Kept for backward compatibility but unused
  final DateTime? to; // Kept for backward compatibility but unused
  final String? currency; // Kept for backward compatibility but unused
  final DateRangeFilter dateRange;

  const GroupFairnessMeter({
    super.key,
    required this.summary,
    this.transactions,
    this.from,
    this.to,
    this.currency,
    required this.dateRange,
  });

  void _showExplanation(BuildContext context, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.balance, color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.groupFairnessTitle)),
          ],
        ),
        content: Text(
          context.l10n.groupFairnessExplanation,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.gotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ═══════════════════════════════════════════════════════════════
    // CRITICAL: Use split-aware memberContributions directly
    // ═══════════════════════════════════════════════════════════════
    // This summary is derived from expenses + split lines, so each member's
    // total already reflects their actual share (not who created the entry).
    //
    // Example:
    //   - User A logs €100 expense, splits 50/50 with User B
    //   - Totals: A €50, B €50 (correct)
    // ═══════════════════════════════════════════════════════════════
    final members = summary.memberContributions;

    if (members.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.homeCardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.homeCardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.noMemberDataYet),
      );
    }
    final total = members.fold<int>(0, (s, m) => s + m.totalSpentCents);
    if (total == 0) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.homeCardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.homeCardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.noSpendingYet),
      );
    }
    final evenShare = total / members.length;
    // Compute fairness index (0 = evenly split, higher = imbalance)
    double squaredError = 0;
    for (final m in members) {
      final diff = (m.totalSpentCents - evenShare).toDouble();
      squaredError += (diff * diff);
    }
    final rmse = (squaredError / members.length).sqrt();
    final fairness = (1.0 - (rmse / (total == 0 ? 1 : total))).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.groupFairness,
                      style: TextStyle(
                          fontSize: 14, color: colorScheme.mutedForeground)),
                  const SizedBox(height: 4),
                  Text(
                    dateRange.getLabel(context),
                    style:
                        WidgetTextStyles.dateLabel(colorScheme.mutedForeground),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showExplanation(context, colorScheme),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: fairness,
                    minHeight: 10,
                    backgroundColor: colorScheme.muted.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      fairness > 0.7
                          ? colorScheme.success
                          : (fairness > 0.4
                              ? colorScheme.warning
                              : colorScheme.destructive),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(fairness * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.l10n.evenShare((evenShare / 100).toStringAsFixed(2)),
              style:
                  TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
        ],
      ),
    );
  }
}

extension _Sqrt on double {
  double sqrt() => Math.sqrt(this);
}

class Math {
  static double sqrt(double x) => x <= 0 ? 0 : _sqrtNewton(x);
  static double _sqrtNewton(double x) {
    double r = x;
    for (int i = 0; i < 12; i++) {
      r = 0.5 * (r + x / r);
    }
    return r;
  }
}
