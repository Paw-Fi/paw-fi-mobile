import 'package:flutter/material.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

/// Suggest simple settlements to equalize member spend to an even share
class SettlementSuggestionsCard extends StatelessWidget {
  final HouseholdSummary summary;
  final List<ExpenseEntry>? transactions;
  final DateTime? from;
  final DateTime? to;
  final String? currency;
  final List<HouseholdMember>? members;
  const SettlementSuggestionsCard({super.key, required this.summary, this.transactions, this.from, this.to, this.currency, this.members});

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    // Build per-member expense-only totals if transactions provided
    List<MemberContribution> memberTotals;
    if (transactions != null && from != null && to != null) {
      final totals = <String, int>{};
      for (final t in transactions!) {
        final isSpend = (t.type ?? 'expense').toLowerCase() != 'income';
        if (!isSpend) continue;
        if (t.userId == null) continue;
        final date = DateTime(t.date.year, t.date.month, t.date.day);
        final code = (t.currency ?? '').trim().toUpperCase();
        final currencyOk = currency == null || code.isEmpty || code == currency;
        if (!currencyOk) continue;
        if (date.isBefore(from!) || date.isAfter(to!)) continue;
        totals[t.userId!] = (totals[t.userId!] ?? 0) + t.amountCents.abs();
      }
      memberTotals = totals.entries
          .map((e) => MemberContribution(
                userId: e.key,
                totalSpentCents: e.value,
                transactionCount: 0,
                splitCount: 0,
                balanceCents: 0,
              ))
          .toList();
    } else {
      memberTotals = summary.memberContributions;
    }
    if (memberTotals.isEmpty) return const SizedBox.shrink();

    final total = memberTotals.fold<int>(0, (s, m) => s + m.totalSpentCents);
    if (total == 0) return const SizedBox.shrink();
    final even = total / memberTotals.length;

    // Positive = overpaid (should receive), Negative = underpaid (should pay)
    final over = <_Balance>[];
    final under = <_Balance>[];
    for (final m in memberTotals) {
      // Map name via provided members list if available
      final name = (this.members?.firstWhere(
                    (mm) => mm.userId == m.userId,
                    orElse: () => HouseholdMember(
                      id: '', householdId: '', userId: m.userId, role: HouseholdRole.member,
                      joinedAt: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now(),
                      userEmail: m.userEmail, userName: m.userName,
                    ),
                  ).userName) ?? m.userName ?? 'Member';
      final diff = m.totalSpentCents - even;
      if (diff > 0) {
        over.add(_Balance(userName: name, amount: diff.toDouble()));
      } else if (diff < 0) {
        under.add(_Balance(userName: name, amount: -diff.toDouble()));
      }
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

