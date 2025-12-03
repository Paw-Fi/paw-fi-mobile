import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

import 'package:moneko/features/households/presentation/pages/settlement_history_page.dart';
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';
import 'package:moneko/shared/widgets/moneko-switch.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Settlement suggestions card with toggle for net vs detailed transfers
class SettlementSuggestionsCard extends StatefulWidget {
  final HouseholdSummary summary;
  final List<ExpenseEntry>? transactions;
  final List<ExpenseSplitGroup>? splits;
  final String? currency;
  final List<HouseholdMember>? members;

  const SettlementSuggestionsCard({
    super.key,
    required this.summary,
    this.transactions,
    this.splits,
    this.currency,
    this.members,
  });

  @override
  State<SettlementSuggestionsCard> createState() =>
      _SettlementSuggestionsCardState();
}

class _SettlementSuggestionsCardState extends State<SettlementSuggestionsCard> {
  static const String _prefsKey = 'moneko_settlement_express_netting';
  bool _netTransfers = true;

  @override
  void initState() {
    super.initState();
    _loadNettingPreference();
  }

  Future<void> _loadNettingPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsKey);
      if (stored != null && stored != _netTransfers && mounted) {
        setState(() => _netTransfers = stored);
      }
    } catch (_) {}
  }

  Future<void> _saveNettingPreference(bool value) async {
    setState(() => _netTransfers = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId == null) return const SizedBox.shrink();

    // 1. Calculate Data
    String nameFor(String userId) {
      final fromMembers = widget.members?.firstWhere(
        (m) => m.userId == userId,
        orElse: () => HouseholdMember(
          id: '',
          householdId: '',
          userId: userId,
          role: HouseholdRole.member,
          joinedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userEmail: null,
          userName: null,
        ),
      );
      if (fromMembers?.userName != null && fromMembers!.userName!.isNotEmpty) {
        return fromMembers.userName!;
      }
      final fromSummary = widget.summary.memberContributions.firstWhere(
        (mc) => mc.userId == userId,
        orElse: () => const MemberContribution(
            userId: '',
            totalSpentCents: 0,
            transactionCount: 0,
            splitCount: 0,
            balanceCents: 0),
      );
      return fromSummary.userName ??
          fromMembers?.userEmail ??
          context.l10n.member;
    }

    List<_Suggestion> mySuggestions;

    if (_netTransfers) {
      // Express Netting: Strictly Bilateral (User <-> Other)
      mySuggestions = _buildBilateralSuggestions(
        widget.splits,
        widget.currency,
        currentUserId,
        nameFor,
      );
    } else {
      // Detailed: Raw debts (User -> Other, Other -> User)
      final allDetailed = _buildDetailedPairs(
        widget.splits,
        widget.currency,
        nameFor,
      );
      // Filter for current user
      mySuggestions = allDetailed
          .where((s) =>
              s.fromUserId == currentUserId || s.toUserId == currentUserId)
          .toList();
    }

    // 4. Calculate Stats for Current User
    int youOweTotal = 0;
    int owedToYouTotal = 0;
    for (final s in mySuggestions) {
      if (s.fromUserId == currentUserId) {
        youOweTotal += s.amountCents;
      } else if (s.toUserId == currentUserId) {
        owedToYouTotal += s.amountCents;
      }
    }

    final isAllSettled =
        mySuggestions.isEmpty && youOweTotal == 0 && owedToYouTotal == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.settlement,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: colorScheme.foreground,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      context.l10n.expressNetting,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.82,
                      alignment: Alignment.centerRight,
                      child: MonekoSwitch(
                        value: _netTransfers,
                        onChanged: _saveNettingPreference,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 4),

            if (isAllSettled)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 32,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All settled up!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No pending settlements',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Stats Overview
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: context.l10n.youOwe,
                      amountCents: youOweTotal,
                      color: const Color(0xFFFF453A), // Apple Red
                      scheme: colorScheme,
                      onTap: youOweTotal > 0
                          ? () => _openSettleUpSheet(
                                context,
                                householdId: widget.summary.householdId,
                                isExpress: _netTransfers,
                                amountHintCents: youOweTotal,
                                splits: widget.splits,
                                targetUserId: null,
                                currency: widget.currency,
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: context.l10n.youAreOwed,
                      amountCents: owedToYouTotal,
                      color: const Color(0xFF30D158), // Apple Green
                      scheme: colorScheme,
                      onTap: null,
                    ),
                  ),
                ],
              ),

              if (mySuggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _netTransfers
                        ? context.l10n.suggestedNetTransfers
                        : context.l10n.detailedPairwiseDues,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.1,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SettlementHistoryPage(
                              householdId: widget.summary.householdId)));
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      context.l10n.viewHistory,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
                const SizedBox(height: 6),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: mySuggestions.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final s = mySuggestions[index];
                    final isPayer = s.fromUserId == currentUserId;
                    return _SuggestionCard(
                      suggestion: s,
                      isPayer: isPayer,
                      scheme: colorScheme,
                      onTap: () => _openSettleUpSheet(
                        context,
                        householdId: widget.summary.householdId,
                        isExpress: _netTransfers,
                        amountHintCents: s.amountCents,
                        splits: widget.splits,
                        targetUserId: isPayer ? s.toUserId : s.fromUserId,
                        currency: widget.currency,
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<_Suggestion> _buildDetailedPairs(
    List<ExpenseSplitGroup>? splits,
    String? currency,
    String Function(String) nameFor,
  ) {
    if (splits == null || splits.isEmpty) return const <_Suggestion>[];
    final pairMap = <String, int>{};

    for (final g in splits) {
      if (currency != null && currency.isNotEmpty) {
        final groupCode = (g.currency).trim().toUpperCase();
        final selectedCode = currency.trim().toUpperCase();
        if (groupCode != selectedCode) continue;
      }
      final payer = g.payerUserId;
      final lines = g.splitLines ?? const <ExpenseSplitLine>[];
      for (final line in lines) {
        if (line.isSettled) continue;
        if (line.userId == payer) continue;
        final amount = (line.amountCents ?? 0).abs();
        if (amount <= 0) continue;
        final key = '${line.userId}->$payer';
        pairMap[key] = (pairMap[key] ?? 0) + amount;
      }
    }

    final out = <_Suggestion>[];
    pairMap.forEach((key, cents) {
      final parts = key.split('->');
      if (parts.length != 2) return;
      final fromUser = parts[0];
      final toUser = parts[1];
      out.add(_Suggestion(
        fromUserId: fromUser,
        toUserId: toUser,
        fromName: nameFor(fromUser),
        toName: nameFor(toUser),
        amountCents: cents,
      ));
    });

    out.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return out;
  }

  List<_Suggestion> _buildBilateralSuggestions(
    List<ExpenseSplitGroup>? splits,
    String? currency,
    String currentUserId,
    String Function(String) nameFor,
  ) {
    if (splits == null || splits.isEmpty) return const <_Suggestion>[];

    // Map: OtherUserId -> NetAmount (Positive = You Owe Them, Negative = They Owe You)
    final netMap = <String, int>{};

    for (final g in splits) {
      if (currency != null && currency.isNotEmpty) {
        final groupCode = (g.currency).trim().toUpperCase();
        final selectedCode = currency.trim().toUpperCase();
        if (groupCode != selectedCode) continue;
      }

      final payer = g.payerUserId;
      final lines = g.splitLines ?? const <ExpenseSplitLine>[];

      for (final line in lines) {
        if (line.isSettled) continue;
        final amount = (line.amountCents ?? 0).abs();
        if (amount <= 0) continue;

        if (payer == currentUserId && line.userId != currentUserId) {
          // You paid, they owe you -> They Owe You (Negative in our map)
          netMap[line.userId] = (netMap[line.userId] ?? 0) - amount;
        } else if (line.userId == currentUserId && payer != currentUserId) {
          // They paid, you owe them -> You Owe Them (Positive in our map)
          netMap[payer] = (netMap[payer] ?? 0) + amount;
        }
      }
    }

    final out = <_Suggestion>[];
    netMap.forEach((otherUserId, netAmount) {
      if (netAmount > 0) {
        // You Owe Them
        out.add(_Suggestion(
          fromUserId: currentUserId,
          toUserId: otherUserId,
          fromName: nameFor(currentUserId),
          toName: nameFor(otherUserId),
          amountCents: netAmount,
        ));
      } else if (netAmount < 0) {
        // They Owe You
        out.add(_Suggestion(
          fromUserId: otherUserId,
          toUserId: currentUserId,
          fromName: nameFor(otherUserId),
          toName: nameFor(currentUserId),
          amountCents: netAmount.abs(),
        ));
      }
    });

    out.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return out;
  }
}

class _Suggestion {
  final String fromUserId;
  final String toUserId;
  final String fromName;
  final String toName;
  final int amountCents;
  _Suggestion({
    required this.fromUserId,
    required this.toUserId,
    required this.fromName,
    required this.toName,
    required this.amountCents,
  });
}

class _StatBox extends StatelessWidget {
  final String label;
  final int amountCents;
  final Color color;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  const _StatBox({
    required this.label,
    required this.amountCents,
    required this.color,
    required this.scheme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: scheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          (amountCents / 100).toStringAsFixed(2),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: amountCents > 0 ? color : scheme.mutedForeground,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

class _SuggestionCard extends StatelessWidget {
  final _Suggestion suggestion;
  final bool isPayer;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.suggestion,
    required this.isPayer,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = isPayer ? suggestion.toName : suggestion.fromName;
    final color = isPayer ? const Color(0xFFFF453A) : const Color(0xFF30D158);
    final amountText = (suggestion.amountCents / 100).toStringAsFixed(2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                isPayer
                    ? '${context.l10n.youOweOthers} $otherName'
                    : '$otherName ${context.l10n.othersOweYou}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openSettleUpSheet(
  BuildContext context, {
  required String householdId,
  required bool isExpress,
  int? amountHintCents,
  List<ExpenseSplitGroup>? splits,
  String? targetUserId,
  String? currency,
}) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SettleUpSheet(
          householdId: householdId,
          specificMemberId: targetUserId,
          amount: amountHintCents != null ? (amountHintCents / 100.0) : null,
          isExpressNetting: isExpress,
          splits: splits,
          currency: currency,
        ),
      );
    },
  );
}
