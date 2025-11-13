import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settlement suggestions card with toggle for net vs detailed transfers
class SettlementSuggestionsCard extends StatefulWidget {
  final HouseholdSummary summary;
  final List<ExpenseEntry>? transactions; // For date/currency filter and mapping
  final List<ExpenseSplitGroup>? splits;  // For detailed (non-netted) view
  final DateTime? from;
  final DateTime? to;
  final String? currency;
  final List<HouseholdMember>? members;
  const SettlementSuggestionsCard({super.key, required this.summary, this.transactions, this.splits, this.from, this.to, this.currency, this.members});

  @override
  State<SettlementSuggestionsCard> createState() => _SettlementSuggestionsCardState();
}


class _SettlementSuggestionsCardState extends State<SettlementSuggestionsCard> {
  static const String _prefsKey = 'moneko_settlement_express_netting';
  bool _netTransfers = true; // On by default

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
    } catch (_) {
      // ignore errors; keep default
    }
  }

  Future<void> _saveNettingPreference(bool value) async {
    setState(() => _netTransfers = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // ignore persistence errors
    }
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (kDebugMode) {
      debugPrint('🧮 Settlement: net=$_netTransfers currentUser=$currentUserId');
    }
    // Use backend-calculated balances to suggest minimal transfers to settle
    // balances: userId -> positive (they should receive), negative (they should pay)
    final balances = widget.summary.balances;
    if (balances.isEmpty) return const SizedBox.shrink();

    // Header with toggle
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Settlement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.mutedForeground)),
          Row(
            children: [
              Text('Express Netting', style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _netTransfers,
                onChanged: (v) => _saveNettingPreference(v),
              ),
            ],
          ),
        ],
      ),
    );

    String _nameFor(String userId) {
      final fromMembers = widget.members?.firstWhere(
        (m) => m.userId == userId,
        orElse: () => HouseholdMember(
          id: '', householdId: '', userId: userId, role: HouseholdRole.member,
          joinedAt: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now(),
          userEmail: null, userName: null,
        ),
      );
      if (fromMembers?.userName != null && fromMembers!.userName!.isNotEmpty) return fromMembers.userName!;
      final fromSummary = widget.summary.memberContributions.firstWhere(
        (mc) => mc.userId == userId,
        orElse: () => const MemberContribution(userId: '', totalSpentCents: 0, transactionCount: 0, splitCount: 0, balanceCents: 0),
      );
      return fromSummary.userName ?? fromMembers?.userEmail ?? 'Member';
    }

    // Compute detailed pairs once for stats and non-net list
    final detailedPairs = _buildDetailedPairs(
      widget.splits,
      widget.transactions,
      widget.from,
      widget.to,
      widget.currency,
      _nameFor,
    );
    if (kDebugMode) {
      debugPrint('🔗 Detailed pairs (${detailedPairs.length}):');
      for (final s in detailedPairs) {
        debugPrint('   ${s.fromName}(${s.fromUserId}) -> ${s.toName}(${s.toUserId}): ${s.amountCents}');
      }
    }

    // Gross flows for current user (non-net, pairwise)
    final grossOutForYou = (currentUserId == null)
        ? 0
        : detailedPairs
            .where((s) => s.fromUserId == currentUserId)
            .fold<int>(0, (acc, s) => acc + s.amountCents);
    final grossInForYou = (currentUserId == null)
        ? 0
        : detailedPairs
            .where((s) => s.toUserId == currentUserId)
            .fold<int>(0, (acc, s) => acc + s.amountCents);
    if (kDebugMode) {
      debugPrint('📊 Gross for current user: out=$grossOutForYou in=$grossInForYou');
    }

    // Net values come from backend summary balances (authoritative)
    final netBalances = balances;
    final totalOutstandingNet = netBalances.values
        .where((v) => v > 0)
        .fold<int>(0, (acc, v) => acc + v);
    final youNetBalance = (currentUserId != null) ? (netBalances[currentUserId] ?? 0) : 0;
    final youOweNet = youNetBalance < 0 ? -youNetBalance : 0;
    final youAreOwedNet = youNetBalance > 0 ? youNetBalance : 0;
    if (kDebugMode) {
      debugPrint('🧾 Net balances (summary): ${balances.map((k, v) => MapEntry(k, v))}');
      debugPrint('➡️ totalOutstandingNet=$totalOutstandingNet youNetBalance=$youNetBalance oweNet=$youOweNet owedNet=$youAreOwedNet');
    }

    // Choose which numbers to show per toggle
    final totalOutstandingCents = _netTransfers
        ? totalOutstandingNet // household net outstanding
        : (currentUserId != null ? grossOutForYou : totalOutstandingNet);
    final youOweCents = _netTransfers ? youOweNet : grossOutForYou;
    final youAreOwedCents = _netTransfers ? youAreOwedNet : grossInForYou;
    if (kDebugMode) {
      debugPrint('🧮 Display values (mode=${_netTransfers ? 'NET' : 'GROSS'}): outstanding=$totalOutstandingCents owe=$youOweCents owed=$youAreOwedCents');
    }
    final impactedCounterparties = () {
      if (currentUserId == null) return 0;
      final set = <String>{};
      for (final s in detailedPairs) {
        if (s.fromUserId == currentUserId) set.add(s.toUserId);
        if (s.toUserId == currentUserId) set.add(s.fromUserId);
      }
      if (set.isNotEmpty) return set.length;
      // Fallback to balance signs when no split data
      final mySign = youNetBalance.sign;
      return balances.entries.where((e) => e.key != currentUserId && e.value.sign == -mySign).length;
      return balances.entries.where((e) => e.key != currentUserId && e.value.sign == -mySign).length;
    }();

    List<_Suggestion> suggestions;
    if (_netTransfers) {
      final over = <_Balance>[]; // receivers
      final under = <_Balance>[]; // payers
      netBalances.forEach((userId, amountCents) {
        if (amountCents > 0) {
          over.add(_Balance(userId: userId, userName: _nameFor(userId), amount: amountCents.toDouble()));
        } else if (amountCents < 0) {
          under.add(_Balance(userId: userId, userName: _nameFor(userId), amount: (-amountCents).toDouble()));
        }
      });
      over.sort((a,b)=>b.amount.compareTo(a.amount));
      under.sort((a,b)=>b.amount.compareTo(a.amount));

      final out = <_Suggestion>[];
      int i = 0, j = 0;
      while (i < under.length && j < over.length) {
        final pay = under[i];
        final recv = over[j];
        final amt = pay.amount < recv.amount ? pay.amount : recv.amount;
        out.add(_Suggestion(
          fromUserId: pay.userId,
          fromName: pay.userName,
          toUserId: recv.userId,
          toName: recv.userName,
          amountCents: amt.toInt(),
        ));
        pay.amount -= amt;
        recv.amount -= amt;
        if (pay.amount <= 1) i++;
        if (recv.amount <= 1) j++;
      }
      suggestions = out;
      if (kDebugMode) {
        debugPrint('✅ Net suggestions (${suggestions.length}):');
        for (final s in suggestions) {
          debugPrint('   ${s.fromName} -> ${s.toName}: ${s.amountCents}');
        }
      }
    } else {
      suggestions = _buildDetailedPairs(
        widget.splits,
        widget.transactions,
        widget.from,
        widget.to,
        widget.currency,
        _nameFor,
      );
      if (kDebugMode) {
        debugPrint('✅ Detailed suggestions (${suggestions.length})');
      }
    }

    if (suggestions.isEmpty && detailedPairs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 6),
          // Stat tiles
          _StatsRow(
            scheme: colorScheme,
            outstandingCents: totalOutstandingCents,
            youOweCents: youOweCents,
            youAreOwedCents: youAreOwedCents,
            impactedCount: impactedCounterparties,
            onTapOwed: (currentUserId != null && youAreOwedCents > 0)
                ? () => _showOwedDetails(context, colorScheme, currentUserId!, detailedPairs)
                : null,
            onTapOwe: (currentUserId != null && youOweCents > 0)
                ? () => _openSettleUpSheet(
                      context,
                      householdId: widget.summary.householdId,
                      isExpress: _netTransfers,
                      amountHintCents: youOweCents,
                      splits: widget.splits,
                    )
                : null,
            onTapOutstanding: () => _openSettleUpSheet(
              context,
              householdId: widget.summary.householdId,
              isExpress: _netTransfers,
              amountHintCents: null,
              splits: widget.splits,
            ),
          ),
          const SizedBox(height: 6),
          if (suggestions.isNotEmpty) _SectionLabel(title: _netTransfers ? 'Suggested net transfers' : 'Detailed pairwise dues', scheme: colorScheme),
          if (suggestions.isNotEmpty) const SizedBox(height: 4),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
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
                            householdId: widget.summary.householdId,
                            specificMemberId: s.toUserId, // settle with receiver (payer of expenses)
                            amount: s.amountCents / 100.0,
                            isExpressNetting: _netTransfers,
                            splits: widget.splits,
                          ),
                        );
                      },
                    );
                  },
                  child: _SuggestionTile(s: s, scheme: colorScheme),
                ),
              )),
        ],
      ),
    );
  }

  List<_Suggestion> _buildDetailedPairs(
    List<ExpenseSplitGroup>? splits,
    List<ExpenseEntry>? _ignoredTransactions,
    DateTime? _ignoredFrom,
    DateTime? _ignoredTo,
    String? _ignoredCurrency,
    String Function(String) nameFor,
  ) {
    if (splits == null || splits.isEmpty) return const <_Suggestion>[];

    // Aggregate UNSETTLED pairwise debts across all split groups, no netting, no filtering
    final pairMap = <String, int>{}; // key: from->to, value: cents

    if (kDebugMode) {
      debugPrint('🧩 Building detailed pairs from ${splits.length} split groups');
    }
    for (final g in splits) {
      final payer = g.payerUserId;
      final lines = g.splitLines ?? const <ExpenseSplitLine>[];
      if (kDebugMode) {
        debugPrint('  • Group ${g.id} payer=$payer lines=${lines.length}');
      }
      for (final line in lines) {
        if (kDebugMode) {
          debugPrint('     - line user=${line.userId} amount=${line.amountCents} settled=${line.isSettled}');
        }
        if (line.isSettled) continue;
        if (line.userId == payer) continue; // payer doesn't owe themselves
        final amount = (line.amountCents ?? 0).abs();
        if (amount <= 0) continue;
        final key = '${line.userId}->${payer}';
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

    out.sort((a,b) => b.amountCents.compareTo(a.amountCents));
    return out;
  }
}

Future<void> _openSettleUpSheet(
  BuildContext context, {
  required String householdId,
  required bool isExpress,
  int? amountHintCents,
  List<ExpenseSplitGroup>? splits,
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
          specificMemberId: null,
          amount: amountHintCents != null ? (amountHintCents / 100.0) : null,
          isExpressNetting: isExpress,
          splits: splits,
        ),
      );
    },
  );
}

class _Balance {
  final String userId;
  final String userName;
  double amount;
  _Balance({required this.userId, required this.userName, required this.amount});
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

class _StatsRow extends StatelessWidget {
  final shadcnui.ColorScheme scheme;
  final int outstandingCents;
  final int youOweCents;
  final int youAreOwedCents;
  final int impactedCount;
  final VoidCallback? onTapOwed;
  final VoidCallback? onTapOutstanding;
  final VoidCallback? onTapOwe;
  const _StatsRow({
    required this.scheme,
    required this.outstandingCents,
    required this.youOweCents,
    required this.youAreOwedCents,
    required this.impactedCount,
    this.onTapOwed,
    this.onTapOutstanding,
    this.onTapOwe,
  });

  String _fmt(int cents) => (cents / 100).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(
          label: 'Outstanding',
          value: _fmt(outstandingCents),
          scheme: scheme,
          tone: _TileTone.neutral,
          onTap: onTapOutstanding,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(
          label: 'You owe',
          value: _fmt(youOweCents),
          scheme: scheme,
          tone: _TileTone.warn,
          onTap: onTapOwe,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(
          label: "You're owed",
          value: _fmt(youAreOwedCents),
          scheme: scheme,
          tone: _TileTone.ok,
          onTap: onTapOwed,
          badge: impactedCount > 0 ? impactedCount.toString() : null,
        )),
      ],
    );
  }
}

enum _TileTone { neutral, ok, warn }

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final shadcnui.ColorScheme scheme;
  final _TileTone tone;
  final String? badge;
  final VoidCallback? onTap;
  const _StatTile({
    required this.label,
    required this.value,
    required this.scheme,
    this.tone = _TileTone.neutral,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = switch (tone) {
      _TileTone.ok => scheme.primary,
      _TileTone.warn => scheme.destructive,
      _ => scheme.mutedForeground,
    };
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            badge != null ? '$label ($badge)' : label,
            style: TextStyle(fontSize: 12, color: scheme.mutedForeground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg == scheme.mutedForeground ? scheme.foreground : fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, child: child));
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final shadcnui.ColorScheme scheme;
  const _SectionLabel({required this.title, required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(title, style: TextStyle(fontSize: 12, color: scheme.mutedForeground)),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final _Suggestion s;
  final shadcnui.ColorScheme scheme;
  const _SuggestionTile({required this.s, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${s.fromName} → ${s.toName}',
              style: TextStyle(color: scheme.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            (s.amountCents/100).toStringAsFixed(2),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

void _showOwedDetails(BuildContext context, shadcnui.ColorScheme scheme, String currentUserId, List<_Suggestion> pairs) {
  final owedToYou = pairs.where((s) => s.toUserId == currentUserId).toList()
    ..sort((a,b)=>b.amountCents.compareTo(a.amountCents));
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.muted.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text("You're owed by", style: TextStyle(fontSize: 14, color: scheme.mutedForeground)),
              const SizedBox(height: 8),
              if (owedToYou.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No outstanding amounts', style: TextStyle(color: scheme.mutedForeground))),
                )
              else
                ...owedToYou.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.fromName, style: TextStyle(color: scheme.foreground))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text((s.amountCents/100).toStringAsFixed(2), style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Map<String, int> _balancesFromPairs(List<_Suggestion> pairs) {
  final b = <String, int>{};
  for (final s in pairs) {
    b[s.fromUserId] = (b[s.fromUserId] ?? 0) - s.amountCents;
    b[s.toUserId] = (b[s.toUserId] ?? 0) + s.amountCents;
  }
  return b;
}
