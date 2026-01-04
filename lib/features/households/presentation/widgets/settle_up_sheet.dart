import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import '../providers/household_providers.dart';
import '../providers/cached_providers.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

class SettleUpSheet extends ConsumerStatefulWidget {
  final String householdId;
  final String? specificMemberId;
  final double? amount;
  final bool isExpressNetting;
  final List<ExpenseSplitGroup>? splits;
  final String? currency;
  final bool settleTheyOweYou;
  final String? settlementNote;

  const SettleUpSheet({
    super.key,
    required this.householdId,
    this.specificMemberId,
    this.amount,
    this.isExpressNetting = false,
    this.splits,
    this.currency,
    this.settleTheyOweYou = false,
    this.settlementNote,
  });

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  String? _selectedMemberId;
  bool _isProcessing = false;
  int _youOweCents = 0;
  int _youAreOwedCents = 0;
  List<_LineItem> _lineItems = const [];
  List<_LineItem> _theyOweItems = const [];
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.specificMemberId;
    if (_selectedMemberId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _recomputeFromSplits());
    }
  }

  Future<void> _recomputeFromSplits() async {
    final memberId = _selectedMemberId;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (memberId == null || currentUserId == null) return;
    final groups = widget.splits ?? const <ExpenseSplitGroup>[];

    int youOwe = 0;
    int youAreOwed = 0;
    final items = <_LineItem>[];
    final theyOwe = <_LineItem>[];

    for (final g in groups) {
      if (widget.currency != null && widget.currency!.isNotEmpty) {
        final groupCode = (g.currency).trim().toUpperCase();
        final selectedCode = widget.currency!.trim().toUpperCase();
        if (groupCode != selectedCode) continue;
      }

      final lines = g.splitLines ?? const <ExpenseSplitLine>[];
      for (final l in lines) {
        if (l.isSettled) continue;
        final amount = (l.amountCents ?? 0).abs();
        if (amount <= 0) continue;

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

    // Enrich line items with expense categories so icons/colors match the
    // main transaction list. We only fetch metadata for the small set of
    // expense IDs involved in this sheet.
    final expenseIds = <String>{
      ...items.map((i) => i.expenseId),
      ...theyOwe.map((i) => i.expenseId),
    }..removeWhere((id) => id.isEmpty);

    final Map<String, String?> expenseCategories = {};
    if (expenseIds.isNotEmpty) {
      try {
        final supabase = Supabase.instance.client;
        final expensesData = await supabase
            .from('expenses')
            .select('id, category')
            .inFilter('id', expenseIds.toList());
        for (final row in (expensesData as List).cast<Map<String, dynamic>>()) {
          final id = row['id'] as String?;
          if (id != null && id.isNotEmpty) {
            expenseCategories[id] = row['category'] as String?;
          }
        }
      } catch (e) {
        debugPrint('Error loading expense categories for SettleUpSheet: $e');
      }
    }

    final enrichedItems = items
        .map((item) => item.copyWith(
              category: expenseCategories[item.expenseId],
            ))
        .toList();
    final enrichedTheyOwe = theyOwe
        .map((item) => item.copyWith(
              category: expenseCategories[item.expenseId],
            ))
        .toList();

    enrichedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    enrichedTheyOwe.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _youOweCents = youOwe;
      _youAreOwedCents = youAreOwed;
      _lineItems = enrichedItems;
      _theyOweItems = enrichedTheyOwe;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final homeFilter = ref.watch(homeFilterProvider);
    final currency =
        widget.currency ?? (homeFilter.selectedCurrency ?? 'USD').toUpperCase();
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final userId = Supabase.instance.client.auth.currentUser?.id;

    final hasSelectedMember =
        _selectedMemberId != null || widget.specificMemberId != null;
    final hasOutstanding = _youOweCents > 0 || _youAreOwedCents > 0;

    // Determine when there is actually something the current user can mark as settled.
    // For express netting, any non-zero dues in either direction can be settled.
    // For detailed mode, we gate by the selected direction.
    final bool nothingToSettle;
    if (!hasSelectedMember) {
      nothingToSettle = true;
    } else if (widget.isExpressNetting) {
      nothingToSettle = !hasOutstanding;
    } else if (widget.settleTheyOweYou) {
      nothingToSettle = _youAreOwedCents <= 0;
    } else {
      nothingToSettle = _youOweCents <= 0;
    }

    double? amountToShow;
    if (nothingToSettle) {
      amountToShow = null;
    } else if (widget.isExpressNetting) {
      final netCents = (_youOweCents - _youAreOwedCents).abs();
      amountToShow = netCents / 100.0;
    } else if (widget.settleTheyOweYou) {
      amountToShow = _youAreOwedCents / 100.0;
    } else {
      amountToShow = _youOweCents / 100.0;
    }

    final isNetPayer = _youOweCents >= _youAreOwedCents;
    final mediaQuery = MediaQuery.of(context);
    final maxSheetHeight = math.max(
      0.0,
      mediaQuery.size.height - mediaQuery.viewPadding.vertical,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              Text(
                context.l10n.settleUp,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Member Selection
              if (widget.specificMemberId == null)
                membersAsync.when(
                  data: (members) {
                    final filtered =
                        members.where((m) => m.userId != userId).toList();

                    // Auto-select if there's only one other member
                    if (filtered.length == 1 && _selectedMemberId == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedMemberId = filtered.first.userId;
                          });
                          _recomputeFromSplits();
                        }
                      });
                    }

                    return _MemberSelector(
                      members: filtered,
                      selectedId: _selectedMemberId,
                      onSelect: (id) {
                        setState(() {
                          _selectedMemberId = id;
                          _youOweCents = 0;
                          _youAreOwedCents = 0;
                          _lineItems = const [];
                          _theyOweItems = const [];
                        });
                        _recomputeFromSplits();
                      },
                      scheme: colorScheme,
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                )
              else
                membersAsync.when(
                  data: (members) {
                    final m = members.firstWhere(
                        (m) => m.userId == widget.specificMemberId,
                        orElse: () => HouseholdMember(
                            id: '',
                            householdId: '',
                            userId: '',
                            role: HouseholdRole.member,
                            joinedAt: DateTime.now(),
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now()));
                    final name = m.userName ?? m.userEmail ?? 'Member';
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("${context.l10n.settlingWith} ",
                                style: TextStyle(
                                    color: colorScheme.mutedForeground)),
                            Text(name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.foreground)),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

              const SizedBox(height: 32),

              // Amount Display
              Column(
                children: [
                  Text(
                    context.l10n.amountToSettle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    !hasSelectedMember
                        ? context.l10n.pleaseSelectMember
                        : nothingToSettle
                            ? context.l10n.nothingToSettle
                            : formatCurrency(amountToShow ?? 0, currency),
                    style: TextStyle(
                      fontSize: !hasSelectedMember || !hasOutstanding ? 24 : 48,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (hasSelectedMember && !nothingToSettle)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.isExpressNetting
                            ? (isNetPayer
                                ? context.l10n.youOwe
                                : context.l10n.theyOweYou)
                            : (widget.settleTheyOweYou
                                ? context.l10n.theyOweYou
                                : context.l10n.youOwe),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (widget.isExpressNetting &&
                      hasSelectedMember &&
                      !nothingToSettle)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.l10n.expressNetting,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.expressNettingHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // Breakdown (Simplified)
              if (_lineItems.isNotEmpty || _theyOweItems.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.breakdown,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // In express netting mode we show both sides:
                        // - items you owe them
                        // - items they owe you (with an offset label).
                        // In detailed mode, we only show the direction being settled.
                        if (widget.isExpressNetting || !widget.settleTheyOweYou)
                          ..._lineItems.map(
                            (item) => buildExpenseTransactionTile(
                              context: context,
                              category: item.category,
                              rawText: item.description,
                              date: item.createdAt,
                              amount: item.amountCents / 100.0,
                              currency: currency,
                              isIncome: false,
                              trailingWidget: Text(
                                context.l10n.youOweOthers,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF453A),
                                ),
                              ),
                            ),
                          ),
                        if (widget.isExpressNetting &&
                            _theyOweItems.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.offsetByWhatTheyOweYou,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._theyOweItems.map(
                            (item) => buildExpenseTransactionTile(
                              context: context,
                              category: item.category,
                              rawText: item.description,
                              date: item.createdAt,
                              amount: item.amountCents / 100.0,
                              currency: currency,
                              isIncome: true,
                              trailingWidget: Text(
                                context.l10n.owesYou,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF30D158),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (!widget.isExpressNetting && widget.settleTheyOweYou)
                          ..._theyOweItems.map(
                            (item) => buildExpenseTransactionTile(
                              context: context,
                              category: item.category,
                              rawText: item.description,
                              date: item.createdAt,
                              amount: item.amountCents / 100.0,
                              currency: currency,
                              isIncome: true,
                              trailingWidget: Text(
                                context.l10n.owesYou,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF30D158),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(height: 24),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedAdaptiveButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryAdaptiveButton(
                      onPressed: _isProcessing ? null : _confirmAndSettle,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(context.l10n.settle),
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
    const noteLabel = 'Note (optional)';

    final result = await MonekoAlertDialog.show(
      context: context,
      title: title,
      description: msg,
      confirmLabel: context.l10n.settle,
      cancelLabel: context.l10n.cancel,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: _noteController.text,
        placeholder: noteLabel,
        isRequired: false,
        keyboardType: TextInputType.text,
      ),
    );

    if (result != null && result.confirmed) {
      final text = result.text?.trim() ?? '';
      _noteController.text = text;
      return true;
    }
    return false;
  }

  Future<void> _confirmAndSettle() async {
    if (!await _showConfirm()) return;
    if (_selectedMemberId == null && widget.specificMemberId == null) {
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
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();
      final count = widget.isExpressNetting
          ? await service.settleAllDebtsBetweenUsersAndNotify(
              householdId: widget.householdId,
              memberUserId: memberId,
              youOweCentsBefore: _youOweCents,
              youAreOwedCentsBefore: _youAreOwedCents,
              currency: widget.currency,
              settlementNote: note,
            )
          : widget.settleTheyOweYou
              ? await service.settleAllDebtsFromMemberAndNotify(
                  householdId: widget.householdId,
                  memberUserId: memberId,
                  theyOweYouCentsBefore: _youAreOwedCents,
                  currency: widget.currency,
                  settlementNote: note,
                )
              : await service.settleAllDebtsToMemberAndNotify(
                  householdId: widget.householdId,
                  memberUserId: memberId,
                  youOweCentsBefore: _youOweCents,
                  currency: widget.currency,
                  settlementNote: note,
                );

      // Force-refresh cached data so settlement changes show immediately
      ref
          .read(cacheInvalidatorProvider)
          .invalidateHouseholdData(widget.householdId);
      ref.invalidate(cachedHouseholdExpensesProvider(
        HouseholdExpensesParams(householdId: widget.householdId),
      ));
      ref.invalidate(cachedHouseholdSplitsProvider(
        HouseholdSplitsParams(householdId: widget.householdId),
      ));
      try {
        final homeFilter = ref.read(homeFilterProvider);
        final range = getDateRangeFromFilter(
          homeFilter.dateRangeFilter,
          homeFilter.customStartDate,
          homeFilter.customEndDate,
        );
        ref.invalidate(householdExpensesProvider(
          HouseholdExpensesParams(
            householdId: widget.householdId,
            limit: 10000,
            startDate: range['from'],
            endDate: range['to'],
          ),
        ));
        ref.invalidate(householdSplitsProvider(
          HouseholdSplitsParams(householdId: widget.householdId),
        ));
        final currency = (homeFilter.selectedCurrency ?? 'USD').toUpperCase();
        ref.invalidate(householdSummaryProvider(
          HouseholdSummaryParams(
            householdId: widget.householdId,
            currency: currency,
            startDate: range['from']!.toIso8601String(),
            endDate: range['to']!.toIso8601String(),
          ),
        ));
        ref.invalidate(householdBudgetsProvider(widget.householdId));
        ref.invalidate(householdMembersProvider(widget.householdId));
        ref.invalidate(householdSettlementHistoryProvider(
            SettlementHistoryParams(householdId: widget.householdId)));
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(
            context,
            count > 0
                ? context.l10n.settlementCompleted
                : context.l10n.nothingToSettle);
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
        _recomputeFromSplits();
      }
    }
  }
}

class _MemberSelector extends StatelessWidget {
  final List<HouseholdMember> members;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ColorScheme scheme;

  const _MemberSelector({
    required this.members,
    required this.selectedId,
    required this.onSelect,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = members[index];
          final isSelected = m.userId == selectedId;
          final name = m.userName ?? m.userEmail ?? 'Member';
          return GestureDetector(
            onTap: () => onSelect(m.userId),
            child: Column(
              children: [
                FutureBuilder<String?>(
                  future: _getUserAvatarUrl(m.userId),
                  builder: (context, snapshot) {
                    final avatarUrl = snapshot.data;
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _InitialAvatar(
                                  name: name,
                                  scheme: scheme,
                                  isSelected: isSelected),
                            )
                          : _InitialAvatar(
                              name: name,
                              scheme: scheme,
                              isSelected: isSelected),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? scheme.primary : scheme.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LineItem {
  final String groupId;
  final String expenseId;
  final String? description;
  final String? category;
  final DateTime createdAt;
  final int amountCents;

  const _LineItem({
    required this.groupId,
    required this.expenseId,
    required this.description,
    required this.createdAt,
    required this.amountCents,
    this.category,
  });

  _LineItem copyWith({String? category}) {
    return _LineItem(
      groupId: groupId,
      expenseId: expenseId,
      description: description,
      createdAt: createdAt,
      amountCents: amountCents,
      category: category ?? this.category,
    );
  }
}

/// Fetch user avatar URL from Supabase users table.
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

class _InitialAvatar extends StatelessWidget {
  final String name;
  final ColorScheme scheme;
  final bool isSelected;
  const _InitialAvatar(
      {required this.name, required this.scheme, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
    );
  }
}
