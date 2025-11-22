import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/outlined-adaptive-button.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import '../providers/household_providers.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Bottom sheet for settling up balances
class SettleUpSheet extends ConsumerStatefulWidget {
  final String householdId;
  final String? specificMemberId; // If settling with specific member
  final double? amount; // Specific amount to settle
  final bool isExpressNetting; // Whether opened from net suggestions
  final List<ExpenseSplitGroup>? splits; // Reuse already-fetched splits

  const SettleUpSheet({
    super.key,
    required this.householdId,
    this.specificMemberId,
    this.amount,
    this.isExpressNetting = false,
    this.splits,
  });

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  String? _selectedMemberId;
  bool _isProcessing = false;
  int _youOweCents = 0;      // Sum where payer = member, line user = current
  int _youAreOwedCents = 0;  // Sum where payer = current, line user = member
  List<_LineItem> _lineItems = const []; // you owe
  List<_LineItem> _theyOweItems = const []; // they owe you

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.specificMemberId;
    // Initial load of unsettled amount if member preselected
    if (_selectedMemberId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _recomputeFromSplits();
      });
    }
  }

  void _recomputeFromSplits() {
    final memberId = _selectedMemberId;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (memberId == null || currentUserId == null) return;
    final groups = widget.splits ?? const <ExpenseSplitGroup>[];

    int youOwe = 0;
    int youAreOwed = 0;
    final items = <_LineItem>[];
    final theyOwe = <_LineItem>[];

    for (final g in groups) {
      final lines = g.splitLines ?? const <ExpenseSplitLine>[];
      for (final l in lines) {
        if (l.isSettled) continue;
        final amount = (l.amountCents ?? 0).abs();
        if (amount <= 0) continue;
        // You owe: payer = member, your line
        if (g.payerUserId == memberId && l.userId == currentUserId) {
          youOwe += amount;
          items.add(_LineItem(
            groupId: g.id,
            expenseId: g.expenseId,
            description: g.description,
            createdAt: g.createdAt,
            amountCents: amount,
          ));
        }
        // You are owed: payer = you, member's line
        if (g.payerUserId == currentUserId && l.userId == memberId) {
          youAreOwed += amount;
          theyOwe.add(_LineItem(
            groupId: g.id,
            expenseId: g.expenseId,
            description: g.description,
            createdAt: g.createdAt,
            amountCents: amount,
          ));
        }
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    theyOwe.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _youOweCents = youOwe;
      _youAreOwedCents = youAreOwed;
      _lineItems = items;
      _theyOweItems = theyOwe;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final membersAsync = ref.watch(householdMembersProvider(widget.householdId));
    final userId = Supabase.instance.client.auth.currentUser?.id;

    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.appBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            context.l10n.settleUp,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.markExpensesAsSettled,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),

          // Member selector (accordion; always visible for consistency)
          membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                child: Text(context.l10n.errorLoadingMembers, style: TextStyle(color: colorScheme.destructive)),
              ),
              data: (members) {
                final items = members
                    .where((m) => m.userId != userId)
                    .map((m) => DropdownMenuItem<String>(
                          value: m.userId,
                          child: Text(m.userName ?? m.userEmail ?? context.l10n.member),
                        ))
                    .toList();

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: colorScheme.border),
                  child: ExpansionTile(
                    initiallyExpanded: widget.specificMemberId == null,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0.0),
                    childrenPadding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    title: Text(
                      context.l10n.whoAreYouSettlingWith,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMemberId ?? widget.specificMemberId,
                        decoration: InputDecoration(
                          labelText: context.l10n.selectMember,
                          border: const OutlineInputBorder(),
                        ),
                        items: items,
                        onChanged: (value) async {
                          setState(() {
                            _selectedMemberId = value;
                            _youOweCents = 0;
                            _youAreOwedCents = 0;
                            _lineItems = const [];
                          });
                          _recomputeFromSplits();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),

          // Detailed breakdown (accordion)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: colorScheme.border),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 0.0),
              childrenPadding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              title: Text(context.l10n.breakdown, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.foreground)),
              children: [
                Builder(builder: (_) {
                  final bothEmpty = _lineItems.isEmpty && _theyOweItems.isEmpty;
                  if (bothEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(context.l10n.noOutstandingItems, style: TextStyle(color: colorScheme.mutedForeground)),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_lineItems.isNotEmpty) ...[
                        Text(context.l10n.youOwe, style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
                        const SizedBox(height: 6),
                        ...List.generate(_lineItems.length, (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _LineTile(item: _lineItems[i], scheme: colorScheme, tone: _AmountTone.warn),
                            )),
                        Divider(height: 12, color: colorScheme.border),
                      ],
                      if (widget.isExpressNetting && _theyOweItems.isNotEmpty) ...[
                        Text(context.l10n.theyOweYou, style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
                        const SizedBox(height: 6),
                        ...List.generate(_theyOweItems.length, (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _LineTile(item: _theyOweItems[i], scheme: colorScheme, tone: _AmountTone.ok),
                            )),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),

          // Mode and amount display (moved to bottom for better UX)
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final netCents = (_youOweCents - _youAreOwedCents);
            final displayCents = widget.isExpressNetting
                ? (netCents > 0 ? netCents : 0)
                : _youOweCents;
            final amountToShow = displayCents > 0
                ? (displayCents / 100.0)
                : widget.amount;
            if (amountToShow == null) return const SizedBox.shrink();
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.isExpressNetting)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(context.l10n.expressNetting, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.muted.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(context.l10n.detailedSettlement, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.mutedForeground)),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.amountToSettle,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${amountToShow.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.foreground,
                              ),
                            ),
                            if (widget.isExpressNetting)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  context.l10n.expressNettingHint,
                                  style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
          const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedAdaptiveButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryAdaptiveButton(
                  onPressed: _isProcessing ? null : _confirmAndSettle,
                  child: Text(context.l10n.settle),
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

  Future<bool> _showConfirm() async {
    final title = context.l10n.confirmSettlement;
    final msg = context.l10n.confirmSettlementMessage;
    final isCupertino = Theme.of(context).platform == TargetPlatform.iOS;
    if (isCupertino) {
      final res = await showCupertinoDialog<bool>(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(msg),
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.cancel)),
            CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.settle)),
          ],
        ),
      );
      return res ?? false;
    } else {
      final res = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(context.l10n.confirmSettlement),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.settle)),
          ],
        ),
      );
      return res ?? false;
    }
  }

  Future<void> _confirmAndSettle() async {
    if (!await _showConfirm()) return;
    if (_selectedMemberId == null && widget.specificMemberId == null) {
      // Show error
      if (mounted) {
        AppToast.info(context, context.l10n.pleaseSelectMember);
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final memberId = _selectedMemberId ?? widget.specificMemberId!;
      final service = ref.read(householdServiceProvider);
      final count = widget.isExpressNetting
          ? await service.settleAllDebtsBetweenUsersAndNotify(
              householdId: widget.householdId,
              memberUserId: memberId,
              youOweCentsBefore: _youOweCents,
              youAreOwedCentsBefore: _youAreOwedCents,
            )
          : await service.settleAllDebtsToMemberAndNotify(
              householdId: widget.householdId,
              memberUserId: memberId,
              youOweCentsBefore: _youOweCents,
            );
      // Invalidate Riverpod providers so parent views refresh immediately
      try {
        final homeFilter = ref.read(homeFilterProvider);
        final range = getDateRangeFromFilter(
          homeFilter.dateRangeFilter,
          homeFilter.customStartDate,
          homeFilter.customEndDate,
        );
        // Expenses
        ref.invalidate(householdExpensesProvider(
          HouseholdExpensesParams(
            householdId: widget.householdId,
            limit: 10000,
            startDate: range['from'],
            endDate: range['to'],
          ),
        ));
        // Splits
        ref.invalidate(householdSplitsProvider(
          HouseholdSplitsParams(householdId: widget.householdId),
        ));
        // Summary
        final currency = (homeFilter.selectedCurrency ?? 'USD').toUpperCase();
        ref.invalidate(householdSummaryProvider(
          HouseholdSummaryParams(
            householdId: widget.householdId,
            currency: currency,
            startDate: range['from']!.toIso8601String(),
            endDate: range['to']!.toIso8601String(),
          ),
        ));
        // Budgets (not strictly needed for settlement suggestions, but keep UI consistent)
        ref.invalidate(householdBudgetsProvider(widget.householdId));
        // Members (balances/labels might be displayed elsewhere)
        ref.invalidate(householdMembersProvider(widget.householdId));
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(context, count > 0 ? context.l10n.settlementCompleted : context.l10n.nothingToSettle);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '${context.l10n.error}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        // Refresh from passed-in splits without extra fetches
        _recomputeFromSplits();
      }
    }
  }
}

class _LineItem {
  final String groupId;
  final String expenseId;
  final String? description;
  final DateTime createdAt;
  final int amountCents;
  const _LineItem({required this.groupId, required this.expenseId, required this.description, required this.createdAt, required this.amountCents});
}

enum _AmountTone { neutral, ok, warn }

class _LineTile extends StatelessWidget {
  final _LineItem item;
  final ColorScheme scheme;
  final _AmountTone tone;
  const _LineTile({required this.item, required this.scheme, this.tone = _AmountTone.neutral});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description?.isNotEmpty == true ? item.description! : context.l10n.expense,
                style: TextStyle(fontSize: 14, color: scheme.foreground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _fmtDate(item.createdAt),
                style: TextStyle(fontSize: 12, color: scheme.mutedForeground),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          (item.amountCents / 100).toStringAsFixed(2),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: switch (tone) {
              _AmountTone.ok => scheme.primary,
              _AmountTone.warn => scheme.destructive,
              _ => scheme.foreground,
            },
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
