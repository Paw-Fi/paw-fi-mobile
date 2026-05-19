import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/households/presentation/pages/settlement_history_page.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Settlement suggestions card with toggle for express netting mode
class SettlementSuggestionsCard extends ConsumerStatefulWidget {
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
  ConsumerState<SettlementSuggestionsCard> createState() =>
      _SettlementSuggestionsCardState();
}

class _SettlementSuggestionsCardState
    extends ConsumerState<SettlementSuggestionsCard> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = widget.currentUserId;

    if (currentUserId == null || currentUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    final balancesAsync = ref.watch(
      householdPairwiseSettlementBalancesV2Provider(
        PairwiseSettlementBalancesParams(
          householdId: widget.summary.householdId,
          currency: widget.currency,
        ),
      ),
    );
    final overviewAsync = ref.watch(
      settlementOverviewProvider(widget.summary.householdId),
    );
    final optimisticPayments = ref.watch(
      optimisticSettlementPaymentsProvider.select(
        (state) =>
            state[widget.summary.householdId] ??
            const <SettlementPaymentRecord>[],
      ),
    );
    final optimisticSplits = ref.watch(
      householdOptimisticSplitsProvider.select(
        (state) =>
            state[widget.summary.householdId] ?? const <ExpenseSplitGroup>[],
      ),
    );

    if (optimisticSplits.isEmpty &&
        balancesAsync.isLoading &&
        overviewAsync.isLoading) {
      return _buildLoadingCard(context, colorScheme);
    }

    if (optimisticSplits.isEmpty &&
        balancesAsync.hasError &&
        !overviewAsync.hasValue) {
      return _buildLoadingCard(context, colorScheme);
    }

    final balances = balancesAsync.valueOrNull;
    final overview = overviewAsync.valueOrNull;

    if (optimisticSplits.isEmpty && balances == null && overview == null) {
      return _buildLoadingCard(context, colorScheme);
    }

    return Builder(
      builder: (context) {
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

        final mySuggestions = balances != null &&
                optimisticPayments.isEmpty &&
                optimisticSplits.isEmpty
            ? _buildSuggestionsFromBalances(
                balances,
                currentUserId,
                nameFor,
              )
            : _buildLegacySuggestions(
                optimisticSplits.isNotEmpty
                    ? mergeHouseholdSplits(
                        overview?.splits ?? const <ExpenseSplitGroup>[],
                        optimisticSplits,
                      )
                    : overview?.splits ?? widget.splits,
                widget.currency,
                currentUserId,
                nameFor,
                settlementPayments:
                    overview?.payments ?? const <SettlementPaymentRecord>[],
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
                              color: colorScheme.destructive,
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
                              color: colorScheme.success,
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
              context.l10n.allSettledUp,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.noPendingSettlements,
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

  List<_Suggestion> _buildSuggestionsFromBalances(
    List<SettlementPairwiseBalance> balances,
    String currentUserId,
    String Function(String) nameFor,
  ) {
    final out = <_Suggestion>[];
    for (final balance in balances) {
      if (balance.netCents > 0) {
        out.add(_Suggestion(
          fromUserId: currentUserId,
          toUserId: balance.otherUserId,
          fromName: nameFor(currentUserId),
          toName: nameFor(balance.otherUserId),
          amountCents: balance.netCents,
        ));
      } else if (balance.netCents < 0) {
        out.add(_Suggestion(
          fromUserId: balance.otherUserId,
          toUserId: currentUserId,
          fromName: nameFor(balance.otherUserId),
          toName: nameFor(currentUserId),
          amountCents: balance.netCents.abs(),
        ));
      }
    }

    out.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return out;
  }

  List<_Suggestion> _buildLegacySuggestions(
    List<ExpenseSplitGroup>? splits,
    String? currency,
    String currentUserId,
    String Function(String) nameFor, {
    List<SettlementPaymentRecord> settlementPayments =
        const <SettlementPaymentRecord>[],
  }) {
    if (splits == null || splits.isEmpty) return const <_Suggestion>[];

    final nets = computeSettlementNets(
      splits: splits,
      currentUserId: currentUserId,
      currencyFilter: currency,
      settlementPayments: settlementPayments,
    );

    final out = <_Suggestion>[];
    for (final entry in nets.entries) {
      final otherUserId = entry.key;
      final result = entry.value;
      if (result.netCents > 0) {
        out.add(_Suggestion(
          fromUserId: currentUserId,
          toUserId: otherUserId,
          fromName: nameFor(currentUserId),
          toName: nameFor(otherUserId),
          amountCents: result.netCents,
        ));
      } else if (result.netCents < 0) {
        out.add(_Suggestion(
          fromUserId: otherUserId,
          toUserId: currentUserId,
          fromName: nameFor(otherUserId),
          toName: nameFor(currentUserId),
          amountCents: result.netCents.abs(),
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
    useSafeArea: true,
    backgroundColor:
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.maybeOf(sheetContext);
      final bottomInset = mediaQuery?.viewInsets.bottom ?? 0.0;
      return Padding(
        padding: EdgeInsets.only(
          bottom: bottomInset,
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
