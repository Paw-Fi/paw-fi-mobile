import 'package:flutter/material.dart';

import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/theme/app_theme.dart';
Widget buildHouseholdBudgetCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<SharedBudget> budgets, {
  required String currencyCode,
  List<BudgetStatus>? budgetStatuses,
  VoidCallback? onTap,
}) {
  final filtered = budgets.where((b) => b.currency.toUpperCase() == currencyCode.toUpperCase()).toList();
  final totalAmount = filtered.fold<double>(0.0, (sum, b) => sum + (b.amountCents / 100.0));

  double? remainingAmount;
  if (budgetStatuses != null && budgetStatuses.isNotEmpty) {
    final remainingCents = budgetStatuses.fold<int>(0, (sum, s) => sum + (s.remainingCents));
    remainingAmount = remainingCents / 100.0;
  }

  final card = Container(
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colorScheme.border.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            remainingAmount != null ? context.l10n.remaining : context.l10n.sharedBudgets,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          formatCurrency((remainingAmount ?? totalAmount), currencyCode.toUpperCase()),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${filtered.length} ${filtered.length == 1 ? context.l10n.budget : context.l10n.budgets}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.mutedForeground,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  if (onTap == null) return card;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    ),
  );
}

Widget buildHouseholdNetPositionCard(
  BuildContext context,
  ColorScheme colorScheme,
  HouseholdSummary? summary, {
  VoidCallback? onTap,
}) {
  final netCents = summary?.totals.netCents ?? 0;
  final isNegative = netCents < 0;
  final currency = (summary?.currency ?? 'USD').toUpperCase();
  final amount = (netCents.abs()) / 100.0;
  final formatted = formatCurrency(amount, currency);
  final displayText = isNegative ? '-$formatted' : formatted;

  final statusColor = isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981);

  final card = Container(
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colorScheme.border.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            context.l10n.netPosition,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayText,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isNegative ? context.l10n.negative : context.l10n.positive,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  if (onTap == null) return card;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    ),
  );
}

/// Total household spending card
Widget buildHouseholdTotalSpentCard(
  BuildContext context,
  ColorScheme colorScheme,
  HouseholdSummary? summary, {
  VoidCallback? onTap,
}) {
  final totalExpensesCents = summary?.totals.totalExpensesCents ?? 0;
  final currency = (summary?.currency ?? 'USD').toUpperCase();
  final amount = totalExpensesCents / 100.0;
  final formatted = formatCurrency(amount, currency);
  final transactionCount = summary?.totals.transactionCount ?? 0;

  final card = IntrinsicWidth(
    child: Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.spentByHousehold,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: 0.3,
              ),
            ),
            Builder(
              builder: (context) {
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: colorScheme.mutedForeground,
                  ),
                  onPressed: () => _showTotalSpentInfoDialog(context, colorScheme),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          formatted,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$transactionCount ${transactionCount == 1 ? 'transaction' : 'transactions'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.mutedForeground,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ],
      ),
    ),
  );

  if (onTap == null) return card;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    ),
  );
}

/// Member spending breakdown card with horizontal bar chart
Widget buildMemberSpendingCard(
  BuildContext context,
  ColorScheme colorScheme,
  HouseholdSummary? summary, {
  VoidCallback? onTap,
}) {
  final memberContributions = summary?.memberContributions ?? [];
  final currency = (summary?.currency ?? 'USD').toUpperCase();
  final totalSpent = memberContributions.fold<int>(0, (sum, m) => sum + m.totalSpentCents);

  // Sort members by spending (highest first)
  final sortedMembers = List<MemberContribution>.from(memberContributions)
    ..sort((a, b) => b.totalSpentCents.compareTo(a.totalSpentCents));

  final card = Container(
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colorScheme.border.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.memberSpending,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.mutedForeground,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),

        // Member spending bars
        if (sortedMembers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                context.l10n.noSpendingYet,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
          )
        else
          ...sortedMembers.map((member) {
            final percentage = totalSpent > 0
                ? (member.totalSpentCents / totalSpent) * 100
                : 0.0;
            final amount = member.totalSpentCents / 100.0;
            final formatted = formatCurrency(amount, currency);
            final displayName = member.userName ?? member.userEmail?.split('@').first ?? 'Unknown';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // Avatar
                            FutureBuilder<String?>(
                              future: _getUserAvatarUrl(member.userId),
                              builder: (context, snapshot) {
                                final avatarUrl = snapshot.data;
                                return Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.muted,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: avatarUrl != null
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stack) => Icon(
                                            Icons.person,
                                            size: 14,
                                            color: colorScheme.mutedForeground,
                                          ),
                                        )
                                      : Icon(
                                          Icons.person,
                                          size: 14,
                                          color: colorScheme.mutedForeground,
                                        ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.foreground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatted,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Horizontal bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.muted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage / 100,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    ),
  );

  if (onTap == null) return card;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    ),
  );
}

/// Helper function to get user avatar URL from Supabase
Future<String?> _getUserAvatarUrl(String userId) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('users')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();

    return response?['avatar_url'] as String?;
  } catch (e) {
    debugPrint('Error fetching user avatar: $e');
    return null;
  }
}

/// Show total spent info dialog
void _showTotalSpentInfoDialog(BuildContext context, ColorScheme colorScheme) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colorScheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.spentByHousehold,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        content: Text(
          context.l10n.spentByHouseholdTooltip,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.foreground,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Got it',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}
