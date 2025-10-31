import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Member spending breakdown card with progress bars
Widget buildHouseholdMemberSpendingCard(
  BuildContext context,
  shadcnui.ColorScheme colorScheme,
  HouseholdSummary? summary, {
  List<HouseholdMember>? members,
  VoidCallback? onTap,
}) {
  final currency = (summary?.currency ?? 'USD').toUpperCase();

  // Member data
  final memberContributions = summary?.memberContributions ?? [];
  final sortedMembers = List<MemberContribution>.from(memberContributions)
    ..sort((a, b) => b.totalSpentCents.compareTo(a.totalSpentCents));
  final totalMemberSpent = memberContributions.fold<int>(0, (sum, m) => sum + m.totalSpentCents);

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
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Member Spending Section
        Text(
          context.l10n.memberSpending,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
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
                    'No spending yet',
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
            final formatted = formatCurrency(amount, currency);

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
                                color: colorScheme.border.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: avatarUrl != null
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) => Icon(
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
