import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

import 'package:moneko/features/households/presentation/pages/settlement_history_page.dart';
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';
import 'package:moneko/shared/widgets/moneko-switch.dart';
import 'package:moneko/shared/widgets/user_avatar.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.settlement,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.foreground,
                  ),
                ),
                Row(
                  children: [
                    if (!isAllSettled) ...[
                      Text(
                        context.l10n.expressNetting,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 0.8,
                        child: MonekoSwitch(
                          value: _netTransfers,
                          onChanged: _saveNettingPreference,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    _HistoryButton(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettlementHistoryPage(
                                householdId: widget.summary.householdId)));
                      },
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isAllSettled)
            _buildAllSettledState(context, colorScheme)
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: context.l10n.youOwe,
                      amountCents: youOweTotal,
                      color: const Color(0xFFFF453A), // Apple Red
                      backgroundColor:
                          const Color(0xFFFF453A).withValues(alpha: 0.1),
                      icon: Icons.arrow_outward_rounded,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: context.l10n.youAreOwed,
                      amountCents: owedToYouTotal,
                      color: const Color(0xFF30D158), // Apple Green
                      backgroundColor:
                          const Color(0xFF30D158).withValues(alpha: 0.1),
                      icon: Icons.arrow_downward_rounded,
                      onTap: null,
                    ),
                  ),
                ],
              ),
            ),
            if (mySuggestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _netTransfers
                      ? context.l10n.suggestedNetTransfers
                      : context.l10n.detailedPairwiseDues,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: mySuggestions.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final s = mySuggestions[index];
                  final isPayer = s.fromUserId == currentUserId;
                  return _SuggestionRow(
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
            ] else
              const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildAllSettledState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'All settled up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No pending settlements',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
              ),
            ),
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

class _HistoryButton extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _HistoryButton({
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.history_rounded,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int amountCents;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.amountCents,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isZero = amountCents == 0;
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isZero
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3)
            : backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                size: 20,
                color: isZero
                    ? Theme.of(context).colorScheme.mutedForeground
                    : color,
              ),
              if (onTap != null && !isZero)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: color.withValues(alpha: 0.5),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isZero
                  ? Theme.of(context).colorScheme.mutedForeground
                  : color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (amountCents / 100).toStringAsFixed(2),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isZero
                  ? Theme.of(context).colorScheme.mutedForeground
                  : color,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );

    if (onTap != null && !isZero) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: content,
      );
    }
    return content;
  }
}

class _SuggestionRow extends StatelessWidget {
  final _Suggestion suggestion;
  final bool isPayer;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.suggestion,
    required this.isPayer,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = isPayer ? suggestion.toName : suggestion.fromName;
    final otherUserId = isPayer ? suggestion.toUserId : suggestion.fromUserId;
    final color = isPayer ? const Color(0xFFFF453A) : const Color(0xFF30D158);
    final amountText = (suggestion.amountCents / 100).toStringAsFixed(2);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            UserAvatar(
              name: otherName,
              userId: otherUserId,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.foreground,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPayer ? context.l10n.youOwe : context.l10n.owesYou,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isPayer)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Pay',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ),
              ],
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
