import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/pages/settlement_history_page.dart';
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Settlement suggestions card with toggle for express netting mode
class SettlementSuggestionsCard extends StatefulWidget {
  final HouseholdSummary summary;
  final List<ExpenseEntry>? transactions;
  final List<ExpenseSplitGroup>? splits;
  final String? currency;
  final List<HouseholdMember>? members;
  final String? currentUserId;

  const SettlementSuggestionsCard({
    super.key,
    required this.summary,
    this.transactions,
    this.splits,
    this.currency,
    this.members,
    this.currentUserId,
  });

  @override
  State<SettlementSuggestionsCard> createState() =>
      _SettlementSuggestionsCardState();
}

class _SettlementPayment {
  final String payerUserId;
  final String participantUserId;
  final int amountCents;
  const _SettlementPayment({
    required this.payerUserId,
    required this.participantUserId,
    required this.amountCents,
  });
}

String _settlementDataSignature({
  required List<ExpenseEntry>? transactions,
  required List<ExpenseSplitGroup>? splits,
}) {
  final txs = transactions ?? const <ExpenseEntry>[];
  final spl = splits;

  ExpenseEntry? latestTx;
  if (txs.isNotEmpty) {
    var latest = txs.first;
    for (final e in txs.skip(1)) {
      if (e.createdAt.isAfter(latest.createdAt)) latest = e;
    }
    latestTx = latest;
  }

  ExpenseSplitGroup? latestSplit;
  if (spl != null && spl.isNotEmpty) {
    var latest = spl.first;
    for (final g in spl.skip(1)) {
      if (g.updatedAt.isAfter(latest.updatedAt)) latest = g;
    }
    latestSplit = latest;
  }

  final txSig = latestTx == null
      ? 'tx:0'
      : 'tx:${txs.length}:${latestTx.id}:${latestTx.createdAt.millisecondsSinceEpoch}:${latestTx.amountCents}';
  final splitSig = spl == null
      ? 'sp:null'
      : latestSplit == null
          ? 'sp:0'
          : 'sp:${spl.length}:${latestSplit.id}:${latestSplit.updatedAt.millisecondsSinceEpoch}:${latestSplit.totalAmountCents}';

  return '$txSig|$splitSig';
}

class _SettlementSuggestionsCardState extends State<SettlementSuggestionsCard> {
  Future<List<_SettlementPayment>>? _settlementPaymentsFuture;
  String? _settlementPaymentsFutureKey;

  @override
  void didUpdateWidget(covariant SettlementSuggestionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.householdId != widget.summary.householdId ||
        oldWidget.currency != widget.currency ||
        oldWidget.currentUserId != widget.currentUserId) {
      _settlementPaymentsFuture = null;
      _settlementPaymentsFutureKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = widget.currentUserId;

    if (currentUserId == null || currentUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    final currencyCode = (widget.currency ?? '').trim().toUpperCase();
    final dataSignature = _settlementDataSignature(
      transactions: widget.transactions,
      splits: widget.splits,
    );
    final settlementKey =
        '${widget.summary.householdId}|$currentUserId|$currencyCode|$dataSignature';
    if (_settlementPaymentsFuture == null ||
        _settlementPaymentsFutureKey != settlementKey) {
      _settlementPaymentsFutureKey = settlementKey;
      _settlementPaymentsFuture = _fetchSettlementPayments(
        householdId: widget.summary.householdId,
        currentUserId: currentUserId,
        currencyCode: currencyCode,
      );
    }

    return FutureBuilder<List<_SettlementPayment>>(
      future: _settlementPaymentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingCard(context, colorScheme);
        }

        final settlementPayments = snapshot.data ?? const <_SettlementPayment>[];

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
          if (fromMembers?.userName != null &&
              fromMembers!.userName!.isNotEmpty) {
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

        final mySuggestions = _buildNetSuggestions(
          widget.splits,
          widget.currency,
          currentUserId,
          nameFor,
          settlementPayments: settlementPayments,
        );

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

        return Material(
          color: colorScheme.surface.withValues(alpha: 0.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettlementHistoryPage(
                    householdId: widget.summary.householdId,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.homeCardSurface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.homeCardShadow,
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
                            _HistoryButton(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SettlementHistoryPage(
                                      householdId: widget.summary.householdId,
                                    ),
                                  ),
                                );
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
                              color: colorScheme.destructive, // Apple Red
                              currency: widget.currency,
                              onTap: youOweTotal > 0
                                  ? () => _openSettleUpSheet(
                                        context,
                                        householdId: widget.summary.householdId,
                                        isExpress: true,
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
                              color: colorScheme.success, // Apple Green
                              currency: widget.currency,
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.suggestedNetTransfers,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.mutedForeground,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: mySuggestions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final s = mySuggestions[index];
                          final isPayer = s.fromUserId == currentUserId;
                          return _SuggestionRow(
                            suggestion: s,
                            isPayer: isPayer,
                            scheme: colorScheme,
                            currency: widget.currency,
                            onTap: () => _openSettleUpSheet(
                              context,
                              householdId: widget.summary.householdId,
                              isExpress: true,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Future<List<_SettlementPayment>> _fetchSettlementPayments({
    required String householdId,
    required String currentUserId,
    required String currencyCode,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      var query = supabase
          .from('household_settlement_events')
          .select('payer_user_id, participant_user_id, amount_cents, currency')
          .eq('household_id', householdId)
          .or('payer_user_id.eq.$currentUserId,participant_user_id.eq.$currentUserId');

      if (currencyCode.isNotEmpty) {
        query = query.eq('currency', currencyCode);
      }

      final response = await query;
      final rows = (response as List).cast<Map<String, dynamic>>();
      final out = <_SettlementPayment>[];
      for (final row in rows) {
        final payer = row['payer_user_id'] as String?;
        final participant = row['participant_user_id'] as String?;
        if (payer == null || payer.isEmpty) continue;
        if (participant == null || participant.isEmpty) continue;
        if (payer == participant) continue;
        final amount = (row['amount_cents'] as int? ?? 0).abs();
        if (amount <= 0) continue;
        out.add(_SettlementPayment(
          payerUserId: payer,
          participantUserId: participant,
          amountCents: amount,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('Error loading settlement events for suggestions: $e');
      return const <_SettlementPayment>[];
    }
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

  List<_Suggestion> _buildNetSuggestions(
    List<ExpenseSplitGroup>? splits,
    String? currency,
    String currentUserId,
    String Function(String) nameFor,
    {
    List<_SettlementPayment> settlementPayments = const <_SettlementPayment>[],
  }
  ) {
    if (splits == null || splits.isEmpty) return const <_Suggestion>[];

    final splitTo = <String, int>{};
    final splitFrom = <String, int>{};

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

        if (line.userId == currentUserId && payer != currentUserId) {
          // You owe the payer.
          splitTo[payer] = (splitTo[payer] ?? 0) + amount;
        } else if (payer == currentUserId && line.userId != currentUserId) {
          // The participant owes you.
          splitFrom[line.userId] = (splitFrom[line.userId] ?? 0) + amount;
        }
      }
    }

    final paidTo = <String, int>{};
    final paidFrom = <String, int>{};
    for (final p in settlementPayments) {
      if (p.participantUserId == currentUserId) {
        paidTo[p.payerUserId] = (paidTo[p.payerUserId] ?? 0) + p.amountCents;
      } else if (p.payerUserId == currentUserId) {
        paidFrom[p.participantUserId] =
            (paidFrom[p.participantUserId] ?? 0) + p.amountCents;
      }
    }

    final out = <_Suggestion>[];
    final otherUsers = <String>{
      ...splitTo.keys,
      ...splitFrom.keys,
      ...paidTo.keys,
      ...paidFrom.keys,
    };
    for (final otherUserId in otherUsers) {
      if (otherUserId.isEmpty || otherUserId == currentUserId) continue;
      final netAmount = (splitTo[otherUserId] ?? 0) -
          (splitFrom[otherUserId] ?? 0) -
          ((paidTo[otherUserId] ?? 0) - (paidFrom[otherUserId] ?? 0));
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
    }

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
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.history_rounded,
          size: 18,
          color: colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int amountCents;
  final Color color;
  final String? currency;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.amountCents,
    required this.color,
    this.onTap,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isZero = amountCents == 0;
    final amountValue = amountCents / 100.0;
    final String amountText;
    if (currency != null && currency!.isNotEmpty) {
      final symbol = resolveCurrencySymbol(currency);
      final normalized = double.parse(formatAmount(amountValue));
      final localized = formatLocalizedNumber(context, normalized);
      amountText = '$symbol$localized';
    } else {
      amountText = formatLocalizedNumber(context, amountValue);
    }
    final labelColor = isZero
        ? Theme.of(context).colorScheme.mutedForeground
        : color.withValues(alpha: 0.8);
    final valueColor =
        isZero ? Theme.of(context).colorScheme.mutedForeground : color;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor,
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
  final String? currency;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.suggestion,
    required this.isPayer,
    required this.scheme,
    required this.onTap,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = isPayer ? suggestion.toName : suggestion.fromName;
    final amountValue = suggestion.amountCents / 100.0;
    final String amountText;
    if (currency != null && currency!.isNotEmpty) {
      final symbol = resolveCurrencySymbol(currency);
      final normalized = double.parse(formatAmount(amountValue));
      final localized = formatLocalizedNumber(context, normalized);
      amountText = '$symbol$localized';
    } else {
      amountText = formatLocalizedNumber(context, amountValue);
    }
    final color = isPayer ? scheme.destructive : scheme.success;

    // Left text: "Alice owes you" or "You owe Bob"
    final label = isPayer
        ? '${context.l10n.youOweOthers} $otherName'
        : '$otherName ${context.l10n.owesYou}';

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: scheme.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.mutedForeground,
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
  bool settleTheyOweYou = false,
}) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor:
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
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
          settleTheyOweYou: settleTheyOweYou,
        ),
      );
    },
  );
}
