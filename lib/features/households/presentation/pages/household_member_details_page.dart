import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class HouseholdMemberDetailsPage extends HookConsumerWidget {
  final HouseholdMember member;
  final List<ExpenseEntry> transactions;
  final List<ExpenseSplitGroup>? splits;
  final DateTime from;
  final DateTime to;
  final String currency;
  final int totalSpentCents;
  final String? householdId;

  const HouseholdMemberDetailsPage({
    super.key,
    required this.member,
    required this.transactions,
    this.splits,
    required this.from,
    required this.to,
    required this.currency,
    required this.totalSpentCents,
    this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    
    // Filter transactions for this member within the date range
    final memberTransactions = _getMemberTransactions();
    final groupedTransactions = _groupTransactionsByDate(memberTransactions);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, colorScheme),
          SliverToBoxAdapter(
            child: _buildHeader(context, colorScheme),
          ),
          if (memberTransactions.isEmpty)
             SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, colorScheme),
            )
          else ...[
             SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  context.l10n.recentTransactions,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
             SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = groupedTransactions.keys.elementAt(index);
                    final expenses = groupedTransactions[date]!;
                    return _buildDaySection(context, colorScheme, date, expenses);
                  },
                  childCount: groupedTransactions.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    return SliverAppBar(
      backgroundColor: colorScheme.appBackground,
      surfaceTintColor: Colors.transparent,
      floating: true,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.foreground),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        member.userName ?? member.userEmail ?? context.l10n.unknownMember,
        style: TextStyle(
          color: colorScheme.foreground,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (householdId != null && member.userId != Supabase.instance.client.auth.currentUser?.id)
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: colorScheme.primary),
            onPressed: () => _showReminderModal(
              context,
              colorScheme,
              member.userId,
              member.userName ?? member.userEmail ?? 'Member',
              householdId!,
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final formattedTotal = formatLocalizedNumber(
      context, 
      totalSpentCents / 100.0,
    );
    final symbol = resolveCurrencySymbol(currency);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.muted.withValues(alpha: 0.5),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: FutureBuilder<String?>(
                future: _getUserAvatarUrl(member.userId),
                builder: (context, snapshot) {
                  final avatarUrl = snapshot.data;
                  if (avatarUrl != null) {
                    return Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                      ),
                    );
                  }
                  return Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Spending Amount
          Text(
            '$symbol$formattedTotal',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${context.l10n.totalSpent} · ${DateFormat('MMM d').format(from)} - ${DateFormat('MMM d').format(to)}',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          if (householdId != null && member.userId != Supabase.instance.client.auth.currentUser?.id) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReminderModal(
                  context,
                  colorScheme,
                  member.userId,
                  member.userName ?? member.userEmail ?? 'Member',
                  householdId!,
                ),
                icon: Icon(Icons.touch_app_outlined, size: 20, color: colorScheme.primaryForeground),
                label: Text(
                  context.l10n.nudge,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primaryForeground,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.primaryForeground,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySection(
    BuildContext context, 
    ColorScheme colorScheme, 
    DateTime date, 
    List<ExpenseEntry> expenses
  ) {
    final isToday = DateTime.now().difference(date).inDays == 0 && DateTime.now().day == date.day;
    final dateStr = isToday ? context.l10n.today : DateFormat.MMMEd().format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 12),
          child: Text(
            dateStr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground.withValues(alpha: 0.8),
              letterSpacing: 0.2,
              uppercase: true,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.cardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.homeCardBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.homeCardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            children: expenses.mapIndexed((index, expense) {
              final isLast = index == expenses.length - 1;
              return Column(
                children: [
                  _buildTransactionRow(context, colorScheme, expense),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 56,
                      color: colorScheme.border.withValues(alpha: 0.1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(BuildContext context, ColorScheme colorScheme, ExpenseEntry expense) {
    final amount = expense.amountCents / 100.0;
    final symbol = resolveCurrencySymbol(expense.currency ?? currency);
    final formatted = formatLocalizedNumber(context, amount);
    
    // Determine category icon
    final category = expense.category ?? 'general';
    // Simplified category icon logic - in a real app this would map categories to icons
    final IconData icon = _getCategoryIcon(category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.rawText ?? (expense.category ?? context.l10n.uncategorized),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (expense.sharedMemberIds != null && expense.sharedMemberIds!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      context.l10n.sharedWithMembers(expense.sharedMemberIds!.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$symbol$formatted',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: colorScheme.mutedForeground.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noTransactionsFound,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.noTransactionsForPeriod,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods

  IconData _getCategoryIcon(String category) {
    // Basic mapping, could be expanded
    switch (category.toLowerCase()) {
      case 'food':
      case 'groceries':
      case 'restaurant':
      case 'dining':
        return Icons.restaurant_rounded;
      case 'transport':
      case 'transportation':
      case 'uber':
      case 'taxi':
        return Icons.directions_car_rounded;
      case 'housing':
      case 'rent':
      case 'utilities':
        return Icons.home_rounded;
      case 'entertainment':
      case 'movies':
      case 'fun':
        return Icons.movie_rounded;
      case 'shopping':
      case 'clothing':
        return Icons.shopping_bag_rounded;
      case 'health':
      case 'medical':
        return Icons.medical_services_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  List<ExpenseEntry> _getMemberTransactions() {
    // Use similar logic to the spending card to attribute expenses
    final memberTransactions = <ExpenseEntry>[];
    
    // Convert date range to include full days
    final startDate = DateTime(from.year, from.month, from.day);
    final endDate = DateTime(to.year, to.month, to.day).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    // Lookup map for split groups
    final byGroupId = splits != null
        ? {for (final g in splits!) g.id: g}
        : <String, ExpenseSplitGroup>{};

    for (final t in transactions) {
      if (t.date.isBefore(startDate) || t.date.isAfter(endDate)) continue;
      
      final isSpend = (t.type ?? 'expense').toLowerCase() != 'income';
      if (!isSpend) continue;

      final tCurrency = (t.currency ?? '').trim().toUpperCase();
      if (tCurrency.isNotEmpty && tCurrency != currency) continue;

      final splitGroupId = t.splitGroupId;
      
      // CASE 1: No split - attribute full amount to creator
      if (splitGroupId == null) {
        if (t.userId == member.userId) {
          memberTransactions.add(t);
        }
        continue;
      }

      // CASE 2: Has split - check if member has a share > 0
      final group = byGroupId[splitGroupId];
      if (group == null || group.splitLines == null) {
        if (t.userId == member.userId) {
          memberTransactions.add(t);
        }
        continue;
      }

      // Check if member is part of this split and has amount > 0
      final memberLine = group.splitLines!.firstWhereOrNull((l) => l.userId == member.userId);
      if (memberLine != null && (memberLine.amountCents ?? 0).abs() > 0) {
        // We add the original transaction but maybe we should show the split amount?
        // For the list view, showing the original transaction is cleaner, 
        // but showing the split amount would be more accurate.
        // Let's create a copy with the adjusted amount for display purposes.
        memberTransactions.add(t.copyWith(
          amountCents: (memberLine.amountCents ?? 0).abs(),
        ));
      }
    }

    // Sort by date descending
    memberTransactions.sort((a, b) => b.date.compareTo(a.date));
    return memberTransactions;
  }

  Map<DateTime, List<ExpenseEntry>> _groupTransactionsByDate(List<ExpenseEntry> transactions) {
    final grouped = <DateTime, List<ExpenseEntry>>{};
    for (final t in transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(t);
    }
    return grouped;
  }

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

  // Nudge Functionality
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
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
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
}

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
      // Check cooldown (re-implemented check here to be safe)
      // Note: In a real app this should be in a service/repository
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
      final checkResponse = await supabase
          .from('notification_events')
          .select('created_at')
          .eq('household_id', widget.householdId)
          .eq('user_id', widget.targetUserId)
          .eq('event_type', 'member_reminded')
          .gte('created_at', twentyFourHoursAgo.toIso8601String())
          .limit(1)
          .maybeSingle();
      
      if (checkResponse != null) {
         if (mounted) Navigator.of(context).pop();
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

      if (mounted) Navigator.of(context).pop();
      
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
      if (mounted) Navigator.of(context).pop();
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
        color: widget.colorScheme.sheetBackground,
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
                          widget.parentContext.l10n.remindUser(widget.targetUserName),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.parentContext.l10n.sendFriendlySpendingReminder,
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
              Text(widget.parentContext.l10n.addMessageOptional,
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
                  hintText: widget.parentContext.l10n.messageHintExample,
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
                        widget.parentContext.l10n.cancel,
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.parentContext.l10n.sendReminder,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: widget.colorScheme.primaryForeground,
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
