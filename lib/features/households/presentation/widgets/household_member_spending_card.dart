import 'package:flutter/material.dart';

import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/households/presentation/pages/household_member_details_page.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/households/presentation/utils/member_spending_attribution.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_avatar.dart';

/// Member spending breakdown card with modern, Apple-inspired design
Widget buildHouseholdMemberSpendingCard(
  BuildContext context,
  ColorScheme colorScheme,
  HouseholdSummary? summary, {
  Key? key,
  List<HouseholdMember>? members,
  String? householdId,
  List<ExpenseEntry>? transactions,
  List<ExpenseSplitGroup>? splits,
  DateTime? from,
  DateTime? to,
  String? selectedCurrency,
  CurrencyRateTable? currencyRates,
  DateRangeFilter? dateRangeFilter,
  String? currentUserId,
  VoidCallback? onTap,
}) {
  final currency =
      ((selectedCurrency ?? summary?.currency) ?? 'USD').toUpperCase();
  final rangeLabel =
      (dateRangeFilter ?? DateRangeFilter.thisMonth).getLabel(context);

  final memberTotals = (transactions != null && from != null && to != null)
      ? computeSplitAwareMemberSpendingTotals(
          transactions: transactions,
          from: from,
          to: to,
          splits: splits ?? const <ExpenseSplitGroup>[],
          selectedCurrency: selectedCurrency,
          currencyRates: currencyRates,
        )
      : const HouseholdMemberSpendingTotals(
          totalSpentByUserCents: <String, int>{},
          transactionCountByUser: <String, int>{},
        );
  final totalsByUser = memberTotals.totalSpentByUserCents;
  final countsByUser = memberTotals.transactionCountByUser;

  // Member data - prefer computed totals; otherwise fall back to backend summary
  final balanceByUserId = <String, int>{
    ...?summary?.balances,
  };
  if (summary != null) {
    for (final c in summary.memberContributions) {
      balanceByUserId[c.userId] = c.balanceCents;
    }
  }

  final hasComputedMemberData =
      transactions != null && from != null && to != null && members != null;

  final memberContributions = hasComputedMemberData
      ? members.map((member) {
          final cents = totalsByUser[member.userId] ?? 0;
          final count = countsByUser[member.userId] ?? 0;
          return MemberContribution(
            userId: member.userId,
            totalSpentCents: cents,
            transactionCount: count,
            splitCount: 0,
            balanceCents: balanceByUserId[member.userId] ?? 0,
            userEmail: member.userEmail,
            userName: member.userName,
          );
        }).toList()
      : (summary?.memberContributions ?? []);

  final totalMemberSpent =
      memberContributions.fold<int>(0, (sum, m) => sum + m.totalSpentCents);

  // Create a list of all members with their spending (0 if not in contributions)
  final allMembers = (members ?? []).map((member) {
    final contribution = memberContributions.firstWhere(
      (c) => c.userId == member.userId,
      orElse: () => MemberContribution(
        userId: member.userId,
        userName: member.userName,
        userEmail: member.userEmail,
        totalSpentCents: 0,
        transactionCount: 0,
        splitCount: 0,
        balanceCents: balanceByUserId[member.userId] ?? 0,
      ),
    );
    return contribution;
  }).toList();

  // Sort by spending amount (highest first)
  final sortedMembers = List<MemberContribution>.from(allMembers)
    ..sort((a, b) => b.totalSpentCents.compareTo(a.totalSpentCents));

  final card = Container(
    width: double.infinity,
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
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              '${context.l10n.spent} • $rangeLabel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: -0.1,
              ),
            ),
          ),
          Container(
            height: 0.5,
            color: colorScheme.border.withValues(alpha: 0.1),
          ),

          // Member list section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: sortedMembers.isEmpty
                ? _buildEmptyState(context, colorScheme)
                : Column(
                    children: sortedMembers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final member = entry.value;
                      final isLast = index == sortedMembers.length - 1;
                      return _buildMemberRow(
                        context,
                        colorScheme,
                        member,
                        members,
                        currency,
                        totalMemberSpent,
                        currentUserId,
                        householdId,
                        isLast,
                        transactions ?? [],
                        splits,
                        currencyRates,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    ),
  );

  if (onTap == null) {
    return Container(
      key: key,
      decoration: card.decoration,
      child: card.child,
    );
  }
  return GestureDetector(
    key: key,
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: card,
  );
}

/// Build empty state when no members have spending
Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: colorScheme.mutedForeground.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noSpendingYet,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.mutedForeground.withValues(alpha: 0.7),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Expenses will appear here',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground.withValues(alpha: 0.5),
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Build individual member row with modern design
Widget _buildMemberRow(
  BuildContext context,
  ColorScheme colorScheme,
  MemberContribution member,
  List<HouseholdMember>? members,
  String currency,
  int totalMemberSpent,
  String? currentUserId,
  String? householdId,
  bool isLast,
  List<ExpenseEntry> transactions,
  List<ExpenseSplitGroup>? splits,
  CurrencyRateTable? currencyRates,
) {
  final percentage = totalMemberSpent > 0
      ? (member.totalSpentCents / totalMemberSpent) * 100
      : 0.0;
  final amount = member.totalSpentCents / 100.0;
  final normalized = double.parse(formatAmount(amount));
  final symbol = resolveCurrencySymbol(currency);
  final localized = formatLocalizedNumber(context, normalized);
  final formatted = '$symbol$localized';

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

  final name = memberData?.userName?.trim();
  final displayName = (name != null && name.isNotEmpty)
      ? name
      : (memberData?.userEmail ?? member.userEmail ?? 'Unknown');

  final isCurrentUser = currentUserId != null && member.userId == currentUserId;

  return GestureDetector(
    onTap: () {
      if (memberData != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => HouseholdMemberDetailsPage(
              member: memberData,
              transactions: transactions,
              splits: splits,
              currency: currency,
              currencyRates: currencyRates,
              householdId: householdId,
            ),
          ),
        );
      }
    },
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member info row
          Row(
            children: [
              // Avatar with online indicator style
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: MonekoAvatar.supabaseUser(
                  size: 44,
                  userId: member.userId,
                  fallbackImageUrl: memberData?.avatarUrl,
                  borderWidth: 1,
                  borderColor: colorScheme.border.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 14),

              // Name and stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                              letterSpacing: -0.3,
                              height: 1.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.l10n.you,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                        // Nudge button removed here, moved to details page
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${member.transactionCount} ${context.l10n.transactions}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.mutedForeground
                                .withValues(alpha: 0.6),
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Amount with percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                      letterSpacing: -0.4,
                      height: 1.3,
                    ),
                  ),
                  if (totalMemberSpent > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.5),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Modern progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.muted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  if (percentage > 0)
                    FractionallySizedBox(
                      widthFactor: percentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
