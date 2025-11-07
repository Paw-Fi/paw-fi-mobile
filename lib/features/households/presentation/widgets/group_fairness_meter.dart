import 'package:flutter/material.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

class GroupFairnessMeter extends StatelessWidget {
  final HouseholdSummary summary;
  const GroupFairnessMeter({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final members = summary.memberContributions;
    if (members.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.border, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: const Text('No member data yet'),
      );
    }
    final total = members.fold<int>(0, (s, m) => s + m.totalSpentCents);
    if (total == 0) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.border, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: const Text('No spending yet'),
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
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Group fairness', style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground)),
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
                      fairness > 0.7 ? const Color(0xFF10B981) : (fairness > 0.4 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(fairness * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 8),
          Text('Even share: ${(evenShare / 100).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
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

