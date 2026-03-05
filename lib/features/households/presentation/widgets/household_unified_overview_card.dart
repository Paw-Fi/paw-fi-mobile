import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/theme/app_theme.dart';

String _formatLocalizedCurrency(
  BuildContext context,
  double amount,
  String currency,
) {
  final normalized = double.parse(formatAmount(amount));
  final symbol = resolveCurrencySymbol(currency);
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}

/// Unified overview card that combines household total spent, budget info, and member spending
Widget buildHouseholdUnifiedOverviewCard(
  BuildContext context,
  ColorScheme colorScheme,
  HouseholdSummary? summary, {
  List<HouseholdMember>? members,
  VoidCallback? onTap,
}) {
  final totalExpensesCents = summary?.totals.totalExpensesCents ?? 0;
  final currency = (summary?.currency ?? 'USD').toUpperCase();
  final totalSpentAmount = totalExpensesCents / 100.0;
  final formattedTotalSpent =
      _formatLocalizedCurrency(context, totalSpentAmount, currency);
  final transactionCount = summary?.totals.transactionCount ?? 0;

  // Budget data
  final budgetStatuses = summary?.budgets ?? [];
  final hasBudget = budgetStatuses.isNotEmpty;

  int totalBudgetCents = 0;
  int totalBudgetSpentCents = 0;
  int totalBudgetRemainingCents = 0;
  bool isOverBudget = false;

  if (hasBudget) {
    for (final budget in budgetStatuses) {
      totalBudgetCents += budget.amountCents;
      totalBudgetSpentCents += budget.spentCents;
      totalBudgetRemainingCents += budget.remainingCents;
      if (budget.isOverBudget) isOverBudget = true;
    }
  }

  // final budgetAmount = totalBudgetCents / 100.0; // currently unused
  final budgetSpentAmount = totalBudgetSpentCents / 100.0;
  final budgetRemainingAmount = totalBudgetRemainingCents / 100.0;
  final budgetPercentage = totalBudgetCents > 0
      ? (totalBudgetSpentCents / totalBudgetCents * 100).clamp(0, 100)
      : 0.0;

  // Member data
  final memberContributions = summary?.memberContributions ?? [];
  final sortedMembers = List<MemberContribution>.from(memberContributions)
    ..sort((a, b) => b.totalSpentCents.compareTo(a.totalSpentCents));
  final totalMemberSpent =
      memberContributions.fold<int>(0, (sum, m) => sum + m.totalSpentCents);

  final card = Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: colorScheme.border.withValues(alpha: 0.4),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Total Spent + Info Icon
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.l10n.spentByHousehold,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.mutedForeground,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Builder(
                        builder: (context) {
                          return GestureDetector(
                            onTap: () =>
                                _showTotalSpentInfoDialog(context, colorScheme),
                            child: Icon(
                              Icons.help_outline,
                              size: 16,
                              color: colorScheme.mutedForeground
                                  .withValues(alpha: 0.7),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedTotalSpent,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                      letterSpacing: -1.0,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$transactionCount ${transactionCount == 1 ? 'transaction' : 'transactions'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.8),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Divider
        const SizedBox(height: 24),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.border.withValues(alpha: 0.0),
                colorScheme.border.withValues(alpha: 0.3),
                colorScheme.border.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Budget Section
        if (hasBudget) ...[
          Row(
            children: [
              Text(
                context.l10n.budget,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Budget Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: budgetPercentage / 100,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOverBudget
                            ? [
                                colorScheme.destructive,
                                colorScheme.destructive.withValues(alpha: 0.8),
                              ]
                            : budgetPercentage > 80
                                ? [
                                    colorScheme.warning,
                                    colorScheme.warning.withValues(alpha: 0.8),
                                  ]
                                : [
                                    colorScheme.primary,
                                    colorScheme.primary.withValues(alpha: 0.8),
                                  ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Budget Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Spent
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatLocalizedCurrency(
                          context, budgetSpentAmount, currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Remaining
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      budgetRemainingAmount >= 0 ? 'Remaining' : 'Over Budget',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatLocalizedCurrency(
                          context, budgetRemainingAmount.abs(), currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: budgetRemainingAmount >= 0
                            ? colorScheme.success
                            : colorScheme.destructive,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.border.withValues(alpha: 0.0),
                  colorScheme.border.withValues(alpha: 0.3),
                  colorScheme.border.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Member Spending Section
        Text(
          context.l10n.memberSpending,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),

        if (sortedMembers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: colorScheme.mutedForeground.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.noSpendingYet,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedMembers.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            final percentage = totalMemberSpent > 0
                ? (member.totalSpentCents / totalMemberSpent) * 100
                : 0.0;
            final amount = member.totalSpentCents / 100.0;
            final formatted =
                _formatLocalizedCurrency(context, amount, currency);

            // Get member data from the members list to ensure we have the correct name
            final memberData = members?.firstWhere(
              (m) => m.userId == member.userId,
              orElse: () => HouseholdMember(
                id: '',
                householdId: '',
                userId: member.userId,
                role: HouseholdRole.member,
                joinedAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                userEmail: member.userEmail,
                userName: member.userName,
              ),
            );

            // Use same name logic as in settings page (household_settings_page.dart:634-638)
            final name = memberData?.userName?.trim();
            final displayName = (name != null && name.isNotEmpty)
                ? name
                : (memberData?.userEmail ?? member.userEmail ?? 'Unknown');

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < sortedMembers.length - 1 ? 16 : 0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      FutureBuilder<String?>(
                        future: _getUserAvatarUrl(member.userId),
                        builder: (context, snapshot) {
                          final avatarUrl = snapshot.data;
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.muted,
                              border: Border.all(
                                color:
                                    colorScheme.border.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.person,
                                      size: 18,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 18,
                                    color: colorScheme.mutedForeground,
                                  ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),

                      // Name
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                            letterSpacing: -0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Amount
                      Text(
                        formatted,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: colorScheme.muted.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage / 100,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primary.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
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
  return GestureDetector(
    onTap: onTap,
    child: card,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.l10n.spentByHousehold,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        content: Text(
          context.l10n.spentByHouseholdTooltip,
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.foreground.withValues(alpha: 0.9),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Got it',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    },
  );
}
