import 'package:flutter/material.dart';

import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Member spending breakdown card with modern, Apple-inspired design
Widget buildHouseholdMemberSpendingCard(
  BuildContext context,
  ColorScheme colorScheme,
  HouseholdSummary? summary, {
  List<HouseholdMember>? members,
  String? householdId,
  List<ExpenseEntry>? transactions,
  List<ExpenseSplitGroup>? splits,
  DateTime? from,
  DateTime? to,
  String? selectedCurrency,
  VoidCallback? onTap,
}) {
  final currency =
      ((selectedCurrency ?? summary?.currency) ?? 'USD').toUpperCase();
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════════════════
  // SPLIT-AWARE MEMBER SPENDING CALCULATION
  // ═══════════════════════════════════════════════════════════════
  // Calculate how much each member actually owes/spent, considering:
  // 1. Full amount for expenses they created WITHOUT splits
  // 2. Their allocated portion for expenses WITH splits
  //
  // Example:
  //   - User A creates $100 expense, splits equally with User B
  //   - Result: User A owes $50, User B owes $50 (not A=$100, B=$0)
  // ═══════════════════════════════════════════════════════════════
  Map<String, int> totalsByUser = {};
  Map<String, int> countsByUser = {};

  if (transactions != null && from != null && to != null) {
    // Create lookup map for split groups
    final byGroupId = splits != null
        ? {for (final g in splits) g.id: g}
        : <String, ExpenseSplitGroup>{};

    for (final t in transactions) {
      final tdate = DateTime(t.date.year, t.date.month, t.date.day);
      final code = (t.currency ?? '').trim().toUpperCase();
      final currencyOk =
          selectedCurrency == null || code.isEmpty || code == selectedCurrency;
      final isSpend = (t.type ?? 'expense').toLowerCase() != 'income';

      if (!isSpend) continue;
      if (!currencyOk) continue;
      if (tdate.isBefore(from) || tdate.isAfter(to)) continue;

      final splitGroupId = t.splitGroupId;

      // CASE 1: No split - attribute full amount to creator
      if (splitGroupId == null) {
        if (t.userId != null) {
          totalsByUser[t.userId!] =
              (totalsByUser[t.userId!] ?? 0) + t.amountCents.abs();
          countsByUser[t.userId!] = (countsByUser[t.userId!] ?? 0) + 1;
        }
        continue;
      }

      // CASE 2: Has split - distribute according to split lines
      final group = byGroupId[splitGroupId];
      if (group == null || group.splitLines == null) {
        // Split group not found, fallback to creator
        if (t.userId != null) {
          totalsByUser[t.userId!] =
              (totalsByUser[t.userId!] ?? 0) + t.amountCents.abs();
          countsByUser[t.userId!] = (countsByUser[t.userId!] ?? 0) + 1;
        }
        continue;
      }

      // Distribute amounts according to each member's split line
      for (final line in group.splitLines!) {
        final memberUserId = line.userId;
        final memberAmount = (line.amountCents ?? 0).abs();

        if (memberAmount > 0) {
          totalsByUser[memberUserId] =
              (totalsByUser[memberUserId] ?? 0) + memberAmount;
          // Count transaction for each member who has a share
          countsByUser[memberUserId] = (countsByUser[memberUserId] ?? 0) + 1;
        }
      }
    }
  }

  // Member data - prefer computed totals; otherwise fall back to backend summary
  final memberContributions = (totalsByUser.isNotEmpty && members != null)
      ? members.map((member) {
          final cents = totalsByUser[member.userId] ?? 0;
          final count = countsByUser[member.userId] ?? 0;
          return MemberContribution(
            userId: member.userId,
            totalSpentCents: cents,
            transactionCount: count,
            splitCount: 0,
            balanceCents: 0,
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
        balanceCents: 0,
      ),
    );
    return contribution;
  }).toList();

  // Sort by spending amount (highest first)
  final sortedMembers = List<MemberContribution>.from(allMembers)
    ..sort((a, b) => b.totalSpentCents.compareTo(a.totalSpentCents));

  final isDark = Theme.of(context).brightness == Brightness.dark;

  final card = Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: colorScheme.outline.withValues(alpha: 0.05),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
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
          // Divider
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
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    ),
  );

  if (onTap == null) return card;
  return GestureDetector(
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
) {
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

  final name = memberData?.userName?.trim();
  final displayName = (name != null && name.isNotEmpty)
      ? name
      : (memberData?.userEmail ?? member.userEmail ?? 'Unknown');

  final isCurrentUser = currentUserId != null && member.userId == currentUserId;
  final canRemind = currentUserId != null &&
      member.userId != currentUserId &&
      householdId != null;

  return Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Member info row
        Row(
          children: [
            // Avatar with online indicator style
            Stack(
              children: [
                FutureBuilder<String?>(
                  future: _getUserAvatarUrl(member.userId),
                  builder: (context, snapshot) {
                    final avatarUrl = snapshot.data;
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.muted.withValues(alpha: 0.5),
                        border: Border.all(
                          color: colorScheme.border.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Icon(
                                  Icons.person_rounded,
                                  size: 22,
                                  color: colorScheme.mutedForeground
                                      .withValues(alpha: 0.6),
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: 22,
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.6),
                              ),
                      ),
                    );
                  },
                ),
              ],
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
                            color: colorScheme.primary.withValues(alpha: 0.12),
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
                      if (canRemind) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showReminderModal(
                            context,
                            colorScheme,
                            member.userId,
                            displayName,
                            householdId,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child:  Text(
                            context.l10n.nudge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          ),
                        ),
                      ],
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
                      color: colorScheme.mutedForeground.withValues(alpha: 0.5),
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

/// Check if user can send reminder (24-hour cooldown)
Future<bool> _canSendReminder(String householdId, String targetUserId) async {
  try {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) return false;

    // Check for existing reminder in last 24 hours
    final twentyFourHoursAgo =
        DateTime.now().subtract(const Duration(hours: 24));

    final response = await supabase
        .from('notification_events')
        .select('created_at')
        .eq('household_id', householdId)
        .eq('user_id', targetUserId)
        .eq('event_type', 'member_reminded')
        .gte('created_at', twentyFourHoursAgo.toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response == null; // Can send if no recent reminder found
  } catch (e) {
    debugPrint('Error in _canSendReminder: $e');
    return true; // Allow on error
  }
}

/// Show reminder modal to send a nudge to a household member
void _showReminderModal(
  BuildContext context,
  ColorScheme colorScheme,
  String targetUserId,
  String targetUserName,
  String householdId,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return _ReminderModalContent(
        colorScheme: colorScheme,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        householdId: householdId,
        parentContext: context,
      );
    },
  );
}

/// Stateful widget for reminder modal content with loading state
class _ReminderModalContent extends StatefulWidget {
  final ColorScheme colorScheme;
  final String targetUserId;
  final String targetUserName;
  final String householdId;
  final BuildContext parentContext;

  const _ReminderModalContent({
    required this.colorScheme,
    required this.targetUserId,
    required this.targetUserName,
    required this.householdId,
    required this.parentContext,
  });

  @override
  State<_ReminderModalContent> createState() => _ReminderModalContentState();
}

class _ReminderModalContentState extends State<_ReminderModalContent> {
  final TextEditingController messageController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _sendReminder() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final supabase = Supabase.instance.client;

    try {
      // Check cooldown
      final canSend =
          await _canSendReminder(widget.householdId, widget.targetUserId);

      if (!canSend) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        if (widget.parentContext.mounted) {
          AppToast.warning(
              widget.parentContext,
              widget.parentContext.l10n
                  .pleaseWait24HoursBeforeSendingAnotherReminder(
                      widget.targetUserName));
        }
        return;
      }

      // Send reminder
      final response = await supabase.functions.invoke(
        'households-remind-member',
        body: {
          'household_id': widget.householdId,
          'target_user_id': widget.targetUserId,
          'message': messageController.text.trim(),
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
      if (response.status == 200) {
        if (widget.parentContext.mounted) {
          AppToast.success(
              widget.parentContext,
              widget.parentContext.l10n
                  .reminderSentToName(widget.targetUserName));
        }
      } else {
        throw Exception('Failed to send reminder');
      }
    } catch (e) {
      debugPrint('Error sending reminder: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (widget.parentContext.mounted) {
        AppToast.error(widget.parentContext,
            widget.parentContext.l10n.failedToSendReminderTryAgain);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: widget.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.remindUser(widget.targetUserName),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.sendFriendlySpendingReminder,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Text(context.l10n.addMessageOptional,
                  style: TextStyle(
                      fontSize: 14, color: widget.colorScheme.mutedForeground)),
              const SizedBox(height: 6),

              // Message input
              TextField(
                controller: messageController,
                enabled: !isLoading,
                maxLines: 3,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: context.l10n.messageHintExample,
                  hintStyle: TextStyle(
                    color: widget.colorScheme.mutedForeground
                        .withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: widget.colorScheme.muted.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.colorScheme.foreground,
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: widget.colorScheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.l10n.cancel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.colorScheme.foreground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _sendReminder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: widget.colorScheme.primary,
                        disabledBackgroundColor: widget.colorScheme.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              context.l10n.sendReminder,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
