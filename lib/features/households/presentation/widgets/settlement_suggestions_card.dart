import 'package:flutter/material.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

/// Suggest simple settlements to equalize member spend to an even share
class SettlementSuggestionsCard extends StatelessWidget {
  final HouseholdSummary summary;
  const SettlementSuggestionsCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final members = summary.memberContributions;
    if (members.isEmpty) return const SizedBox.shrink();

    final total = members.fold<int>(0, (s, m) => s + m.totalSpentCents);
    if (total == 0) return const SizedBox.shrink();
    final even = total / members.length;

    // Positive = overpaid (should receive), Negative = underpaid (should pay)
    final over = <_Balance>[];
    final under = <_Balance>[];
    for (final m in members) {
      final diff = m.totalSpentCents - even;
      final b = _Balance(userName: m.userName ?? 'Member', amount: diff.toDouble());
      if (diff > 0) over.add(b); else if (diff < 0) under.add(_Balance(userName: m.userName ?? 'Member', amount: -diff.toDouble()));
    }
    over.sort((a,b)=>b.amount.compareTo(a.amount));
    under.sort((a,b)=>b.amount.compareTo(a.amount));

    final suggestions = <String>[];
    int i = 0, j = 0;
    while (i < under.length && j < over.length) {
      final pay = under[i];
      final recv = over[j];
      final amt = pay.amount < recv.amount ? pay.amount : recv.amount;
      suggestions.add('${pay.userName} → ${recv.userName}: ${(amt/100).toStringAsFixed(2)}');
      pay.amount -= amt;
      recv.amount -= amt;
      if (pay.amount <= 1) i++;
      if (recv.amount <= 1) j++;
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

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
          Text('Settlement suggestions', style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground)),
          const SizedBox(height: 8),
          ...suggestions.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(s, style: TextStyle(color: colorScheme.foreground))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _Balance {
  final String userName;
  double amount;
  _Balance({required this.userName, required this.amount});
}

