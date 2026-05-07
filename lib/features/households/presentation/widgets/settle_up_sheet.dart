import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/households/presentation/pages/settlement_calculation_breakdown_page.dart';
import '../providers/household_providers.dart';
import '../providers/cached_providers.dart';
import '../providers/household_derived_providers.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/user_avatar.dart';

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
  int _paidToCents = 0;
  int _paidFromCents = 0;
  final TextEditingController _noteController = TextEditingController();
  int _maxSettleCents = 0;
  String _settlementCurrencyCode = 'USD';

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.specificMemberId;
    if (widget.settlementNote != null && widget.settlementNote!.isNotEmpty) {
      _noteController.text = widget.settlementNote!;
    }
    if (_selectedMemberId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _recomputeFromSplits());
    }
  }

  Future<void> _recomputeFromSplits() async {
    if (!mounted) return;

    final memberId = _selectedMemberId;
    if (memberId == null) return;

    final homeFilter = ref.read(homeFilterProvider);
    final currencyCode =
        (widget.currency ?? (homeFilter.selectedCurrency ?? 'USD'))
            .trim()
            .toUpperCase();

    final balancesFuture = ref.read(
      householdPairwiseSettlementBalancesV2Provider(
        PairwiseSettlementBalancesParams(
          householdId: widget.householdId,
          currency: currencyCode,
        ),
      ).future,
    );

    late final List<SettlementPairwiseBalance> balances;
    try {
      balances = await balancesFuture;
    } on StateError {
      return;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[SettleUpSheet] v2 recompute failed; falling back to legacy calculator: $error\n$stackTrace',
        );
      }
      if (!mounted) return;
      await _recomputeFromLegacyData(
        memberId: memberId,
        currencyCode: currencyCode,
      );
      return;
    }

    if (!mounted) return;

    final balance = balances.firstWhere(
      (entry) => entry.otherUserId == memberId,
      orElse: () => SettlementPairwiseBalance(
        otherUserId: memberId,
        currency: currencyCode,
        splitToCents: 0,
        splitFromCents: 0,
        paidToCents: 0,
        paidFromCents: 0,
        netCents: 0,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        '[SettleUpSheet] recompute v2 household=${widget.householdId} member=$memberId currency=$currencyCode net=${balance.netCents} splitTo=${balance.splitToCents} splitFrom=${balance.splitFromCents} paidTo=${balance.paidToCents} paidFrom=${balance.paidFromCents}',
      );
    }
    final netYouOwe = balance.youOweCents;
    final netYouAreOwed = balance.youAreOwedCents;

    final maxSettleCents = widget.isExpressNetting
        ? (netYouOwe - netYouAreOwed).abs()
        : widget.settleTheyOweYou
            ? netYouAreOwed
            : netYouOwe;

    if (kDebugMode) {
      debugPrint(
        '[SettleUpSheet] paidTo=${balance.paidToCents} paidFrom=${balance.paidFromCents} net=${balance.netCents} netYouOwe=$netYouOwe netYouAreOwed=$netYouAreOwed maxSettle=$maxSettleCents',
      );
    }

    if (!mounted) return;
    setState(() {
      _youOweCents = netYouOwe;
      _youAreOwedCents = netYouAreOwed;
      _paidToCents = balance.paidToCents;
      _paidFromCents = balance.paidFromCents;
      _maxSettleCents = maxSettleCents;
      _settlementCurrencyCode = currencyCode;
    });
  }

  Future<void> _recomputeFromLegacyData({
    required String memberId,
    required String currencyCode,
  }) async {
    if (!mounted) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final splitsFuture = ref.read(
      cachedHouseholdSplitsProvider(
        HouseholdSplitsParams(householdId: widget.householdId),
      ).future,
    );
    final paymentsFuture = ref.read(
      householdSettlementPaymentsProvider(widget.householdId).future,
    );

    late final List<ExpenseSplitGroup> providerSplits;
    late final List<SettlementPaymentRecord> allPayments;
    try {
      providerSplits = await splitsFuture;
      if (!mounted) return;
      allPayments = await paymentsFuture;
    } on StateError {
      return;
    }

    if (!mounted) return;

    final groups = providerSplits.isNotEmpty
        ? providerSplits
        : (widget.splits ?? const <ExpenseSplitGroup>[]);
    final settlementPayments = allPayments.where((payment) {
      return (payment.payerUserId == memberId &&
              payment.participantUserId == currentUserId) ||
          (payment.payerUserId == currentUserId &&
              payment.participantUserId == memberId);
    }).toList();

    final result = computePairwiseNet(
      splits: groups,
      currentUserId: currentUserId,
      otherUserId: memberId,
      currencyFilter: currencyCode,
      settlementPayments: settlementPayments,
    );
    final maxSettleCents = widget.isExpressNetting
        ? (result.youOweCents - result.youAreOwedCents).abs()
        : widget.settleTheyOweYou
            ? result.youAreOwedCents
            : result.youOweCents;

    if (!mounted) return;
    setState(() {
      _youOweCents = result.youOweCents;
      _youAreOwedCents = result.youAreOwedCents;
      _paidToCents = result.paidToCents;
      _paidFromCents = result.paidFromCents;
      _maxSettleCents = maxSettleCents;
      _settlementCurrencyCode = currencyCode;
    });
  }

  void _openCalculationBreakdownPage(
    BuildContext context, {
    required String householdId,
    required String currentUserId,
    required HouseholdMember member,
    required List<ExpenseSplitGroup> splits,
    required List<ExpenseEntry> transactions,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettlementCalculationBreakdownPage(
          householdId: householdId,
          currentUserId: currentUserId,
          memberUserId: member.userId,
          memberDisplayName: (member.userName?.trim().isNotEmpty ?? false)
              ? member.userName!.trim()
              : (member.userEmail ?? context.l10n.member),
          currencyCode: _settlementCurrencyCode,
          transactions: transactions,
          splits: splits,
          paidToCents: _paidToCents,
          paidFromCents: _paidFromCents,
          netCents: _youOweCents - _youAreOwedCents,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final homeFilter = ref.watch(homeFilterProvider);
    final currency =
        widget.currency ?? (homeFilter.selectedCurrency ?? 'USD').toUpperCase();
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final expensesAsync = ref.watch(cachedHouseholdExpensesProvider(
      HouseholdExpensesParams(householdId: widget.householdId),
    ));
    final splitsAsync = ref.watch(cachedHouseholdSplitsProvider(
      HouseholdSplitsParams(householdId: widget.householdId),
    ));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final transactions = expensesAsync.valueOrNull ?? const <ExpenseEntry>[];
    final effectiveSplits =
        splitsAsync.valueOrNull ?? widget.splits ?? const <ExpenseSplitGroup>[];

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

    // Helpers for the visual connection
    final effectiveMemberId = widget.specificMemberId ?? _selectedMemberId;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.appleGroupedBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Content Scrollable Area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    // Title
                    Text(
                      context.l10n.settleUp,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Visualization: Connection Row (You <--> Them)
                    membersAsync.when(
                      data: (members) {
                        final me = members.firstWhere(
                          (m) => m.userId == userId,
                          orElse: () => HouseholdMember(
                              id: 'me',
                              householdId: '',
                              userId: userId ?? '',
                              role: HouseholdRole.member,
                              joinedAt: DateTime.now(),
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now()),
                        );

                        final them = effectiveMemberId != null
                            ? members.firstWhere(
                                (m) => m.userId == effectiveMemberId,
                                orElse: () => HouseholdMember(
                                    id: 'them',
                                    householdId: '',
                                    userId: '',
                                    role: HouseholdRole.member,
                                    joinedAt: DateTime.now(),
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now()),
                              )
                            : null;

                        return _SettlementConnectionVisual(
                          me: me,
                          them: them,
                          isExpressNetting: widget.isExpressNetting,
                          isNetPayer: isNetPayer,
                          amountToShow: amountToShow,
                          nothingToSettle: nothingToSettle,
                          scheme: colorScheme,
                        );
                      },
                      loading: () => const SizedBox(height: 80),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 32),

                    // Member Selector (Only if not pre-selected)
                    if (widget.specificMemberId == null)
                      membersAsync.when(
                        data: (members) {
                          final filtered =
                              members.where((m) => m.userId != userId).toList();

                          // Auto-select logic logic remains separate in the build block above or init
                          // but visually we assume logic is handled
                          if (filtered.length == 1 &&
                              _selectedMemberId == null) {
                            // This side-effect in build is tricky but modifying state during build is bad.
                            // The original code had it in a post frame callback.
                            // We preserve the logic location, just rendering here.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _selectedMemberId == null) {
                                setState(() {
                                  _selectedMemberId = filtered.first.userId;
                                });
                                _recomputeFromSplits();
                              }
                            });
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.selectMember,
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.mutedForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ModernMemberSelector(
                                members: filtered,
                                selectedId: _selectedMemberId,
                                onSelect: (id) {
                                  setState(() {
                                    _selectedMemberId = id;
                                    _youOweCents = 0;
                                    _youAreOwedCents = 0;
                                    _paidToCents = 0;
                                    _paidFromCents = 0;
                                    _maxSettleCents = 0;
                                    _pendingAmountText = null;
                                  });
                                  _recomputeFromSplits();
                                },
                                scheme: colorScheme,
                              ),
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                    const SizedBox(height: 24),

                    // Amount Card
                    _AmountDisplayCard(
                      nothingToSettle: nothingToSettle,
                      hasSelectedMember: hasSelectedMember,
                      amountToShow: amountToShow,
                      maxSettleCents: _maxSettleCents,
                      settlementCurrencyCode: _settlementCurrencyCode,
                      currency: currency,
                      isExpressNetting: widget.isExpressNetting,
                      isNetPayer: isNetPayer,
                      settleTheyOweYou: widget.settleTheyOweYou,
                      scheme: colorScheme,
                      l10n: context.l10n,
                      onShowBreakdown: hasSelectedMember && userId != null
                          ? () {
                              final targetMemberId =
                                  widget.specificMemberId ?? _selectedMemberId;
                              if (targetMemberId == null) return;

                              final members = membersAsync.valueOrNull ??
                                  const <HouseholdMember>[];
                              final member = members.firstWhere(
                                (m) => m.userId == targetMemberId,
                                orElse: () => HouseholdMember(
                                  id: 'member',
                                  householdId: widget.householdId,
                                  userId: targetMemberId,
                                  role: HouseholdRole.member,
                                  joinedAt: DateTime.now(),
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              );

                              _openCalculationBreakdownPage(
                                context,
                                householdId: widget.householdId,
                                currentUserId: userId,
                                member: member,
                                splits: effectiveSplits,
                                transactions: transactions,
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),

            // Actions Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.l10n.cancel,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isProcessing ? null : _confirmAndSettle,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              context.l10n.settle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (keep existing methods: _showConfirm, _confirmAndSettle, _parseAmountCents, _clampAmountCents)
  Future<bool> _showConfirm() async {
    final maxCents = _maxSettleCents;
    if (maxCents <= 0) {
      if (mounted) {
        AppToast.info(context, context.l10n.nothingToSettle);
      }
      return false;
    }

    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.confirmSettlement,
      description: context.l10n.confirmSettlementMessage,
      confirmLabel: context.l10n.settle,
      cancelLabel: context.l10n.cancel,
      barrierDismissible: true,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: formatAmount(maxCents / 100.0),
        placeholder: context.l10n.amountPlaceholder,
        isRequired: false,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      secondaryInputConfig: MonekoAlertDialogInputConfig(
        initialValue: _noteController.text,
        placeholder: context.l10n.noteOptional,
        isRequired: false,
        keyboardType: TextInputType.text,
      ),
    );

    if (result == null || !result.confirmed) return false;
    _pendingAmountText = result.text;
    _noteController.text = (result.secondaryText ?? '').trim();
    return true;
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

      final maxCents = _maxSettleCents;
      if (maxCents <= 0) {
        if (mounted) {
          AppToast.info(context, context.l10n.nothingToSettle);
        }
        return;
      }

      final requestedCents = _parseAmountCents(_pendingAmountText);
      final amountCents = _clampAmountCents(
        requestedCents: requestedCents,
        maxCents: maxCents,
      );
      if (requestedCents != null && requestedCents > maxCents && mounted) {
        AppToast.info(
          context,
          'Max ${formatCurrency(maxCents / 100.0, _settlementCurrencyCode)}',
        );
      }
      if (amountCents == null || amountCents <= 0) {
        if (mounted) {
          AppToast.info(context, context.l10n.nothingToSettle);
        }
        return;
      }

      final mode = widget.isExpressNetting
          ? 'both'
          : widget.settleTheyOweYou
              ? 'from_member'
              : 'to_member';
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      SettlementPaymentRecord? optimisticPayment;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final currentUserPays = widget.isExpressNetting
            ? _youOweCents >= _youAreOwedCents
            : !widget.settleTheyOweYou;
        optimisticPayment = SettlementPaymentRecord(
          payerUserId: currentUserPays ? currentUserId : memberId,
          participantUserId: currentUserPays ? memberId : currentUserId,
          amountCents: amountCents,
          currency: _settlementCurrencyCode,
        );
        ref
            .read(optimisticSettlementPaymentsProvider.notifier)
            .addPayment(widget.householdId, optimisticPayment);
      }

      final count = await service.settleAmountAndNotify(
        householdId: widget.householdId,
        memberUserId: memberId,
        mode: mode,
        amountCents: amountCents,
        currency: _settlementCurrencyCode,
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
        final periodSelection = ref.read(periodFilterProvider);
        final range = resolvePeriodDateRange(periodSelection);
        ref.invalidate(householdExpensesProvider(
          HouseholdExpensesParams(
            householdId: widget.householdId,
            limit: 10000,
            startDate: range.start,
            endDate: range.end,
          ),
        ));
        ref.invalidate(householdSplitsProvider(
          HouseholdSplitsParams(householdId: widget.householdId),
        ));
        final currency = (homeFilter.selectedCurrency ?? 'USD').toUpperCase();
        ref.invalidate(householdDerivedSummaryProvider(
          HouseholdSummaryParams(
            householdId: widget.householdId,
            currency: currency,
            startDate: range.start.toIso8601String(),
            endDate: range.end.toIso8601String(),
          ),
        ));
        ref.invalidate(householdBudgetsProvider(widget.householdId));
        ref.invalidate(householdMembersProvider(widget.householdId));
        ref.invalidate(householdSettlementHistoryProvider(
            SettlementHistoryParams(householdId: widget.householdId)));
        ref.invalidate(householdSettlementPaymentsProvider(widget.householdId));
        ref.invalidate(householdPairwiseSettlementBalancesV2Provider(
          PairwiseSettlementBalancesParams(
            householdId: widget.householdId,
            currency: _settlementCurrencyCode,
          ),
        ));
      } catch (_) {}
      if (optimisticPayment != null) {
        ref
            .read(optimisticSettlementPaymentsProvider.notifier)
            .removePayment(widget.householdId, optimisticPayment);
      }

      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(
            context,
            count > 0
                ? context.l10n.settlementCompleted
                : context.l10n.nothingToSettle);
      }
    } catch (e) {
      try {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final memberId = _selectedMemberId ?? widget.specificMemberId;
        if (currentUserId != null && memberId != null) {
          final currentUserPays = widget.isExpressNetting
              ? _youOweCents >= _youAreOwedCents
              : !widget.settleTheyOweYou;
          ref.read(optimisticSettlementPaymentsProvider.notifier).removePayment(
                widget.householdId,
                SettlementPaymentRecord(
                  payerUserId: currentUserPays ? currentUserId : memberId,
                  participantUserId: currentUserPays ? memberId : currentUserId,
                  amountCents: _clampAmountCents(
                        requestedCents: _parseAmountCents(_pendingAmountText),
                        maxCents: _maxSettleCents,
                      ) ??
                      0,
                  currency: _settlementCurrencyCode,
                ),
              );
        }
      } catch (_) {}
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

  int? _parseAmountCents(String? raw) {
    final input = (raw ?? '').trim();
    if (input.isEmpty) return null;

    final cleaned = input.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (cleaned.isEmpty) return null;

    final String normalized;
    if (!cleaned.contains('.') && cleaned.contains(',')) {
      normalized = cleaned.replaceAll(',', '.');
    } else {
      normalized = cleaned.replaceAll(',', '');
    }

    final value = double.tryParse(normalized);
    if (value == null || value.isNaN || value.isInfinite) return null;
    final cents = (value * 100).round();
    if (cents <= 0) return null;
    return cents;
  }

  int? _clampAmountCents({
    required int? requestedCents,
    required int maxCents,
  }) {
    if (maxCents <= 0) return null;
    final requested = requestedCents ?? maxCents;
    if (requested <= 0) return null;
    return math.min(requested, maxCents);
  }

  String? _pendingAmountText;
}

/// A modern, scrollable selector using rounded "chips" with avatars.
class _ModernMemberSelector extends StatelessWidget {
  final List<HouseholdMember> members;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ColorScheme scheme;

  const _ModernMemberSelector({
    required this.members,
    required this.selectedId,
    required this.onSelect,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = members[index];
          final isSelected = m.userId == selectedId;
          final rawName = (m.userName ?? m.userEmail ?? '').trim();
          final name = rawName.isEmpty ? context.l10n.memberName : rawName;
          final initial = name.characters.first.toUpperCase();

          return GestureDetector(
            onTap: () => onSelect(m.userId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 72,
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.surfaceBorder,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Visualization of the money flow
class _SettlementConnectionVisual extends StatelessWidget {
  final HouseholdMember me;
  final HouseholdMember? them;
  final bool isExpressNetting;
  final bool isNetPayer;
  final double? amountToShow;
  final bool nothingToSettle;
  final ColorScheme scheme;

  const _SettlementConnectionVisual({
    required this.me,
    required this.them,
    required this.isExpressNetting,
    required this.isNetPayer,
    required this.amountToShow,
    required this.nothingToSettle,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    // If no specific person selected yet, just show Me waiting
    if (them == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AvatarNode(member: me, scheme: scheme, isMe: true),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 2,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          _AvatarNodePlaceholder(scheme: scheme),
        ],
      );
    }

    // Logic:
    // If isNetPayer (Me -> Them)
    // If !isNetPayer (Them -> Me)
    // If Nothing to settle, just a line.

    final flowRight = isNetPayer; // Me is left, Them is right.

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AvatarNode(member: me, scheme: scheme, isMe: true),

        // Arrow / Connection
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: nothingToSettle
                ? Container(height: 2, color: scheme.outlineVariant)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                          height: 2,
                          color: scheme.primary.withValues(alpha: 0.3)),
                      if (amountToShow != null && amountToShow! > 0)
                        Icon(
                          flowRight ? Icons.arrow_forward : Icons.arrow_back,
                          color: scheme.primary,
                          size: 20,
                        ),
                    ],
                  ),
          ),
        ),

        _AvatarNode(member: them!, scheme: scheme, isMe: false),
      ],
    );
  }
}

class _AvatarNode extends StatelessWidget {
  final HouseholdMember member;
  final ColorScheme scheme;
  final bool isMe;

  const _AvatarNode(
      {required this.member, required this.scheme, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final label = isMe
        ? context.l10n.you
        : (member.userName ?? member.userEmail ?? context.l10n.unknownLabel);
    final fallbackName = member.userName ??
        member.userEmail ??
        (isMe ? context.l10n.you : context.l10n.unknownLabel);

    return Column(
      children: [
        UserAvatar(
          avatarUrl: member.avatarUrl,
          name: fallbackName,
          userId: member.userId,
          size: 56,
          borderWidth: 2,
          borderColor:
              isMe ? scheme.tertiaryContainer : scheme.secondaryContainer,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _AvatarNodePlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  const _AvatarNodePlaceholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor:
              scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Icon(Icons.person_outline, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.selectEllipsis,
          style: TextStyle(
            fontSize: 12,
            color: scheme.outline,
          ),
        ),
      ],
    );
  }
}

class _AmountDisplayCard extends StatelessWidget {
  final bool nothingToSettle;
  final bool hasSelectedMember;
  final double? amountToShow;
  final int maxSettleCents;
  final String settlementCurrencyCode;
  final String currency;
  final bool isExpressNetting;
  final bool isNetPayer;
  final bool settleTheyOweYou;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final VoidCallback? onShowBreakdown;

  const _AmountDisplayCard({
    required this.nothingToSettle,
    required this.hasSelectedMember,
    required this.amountToShow,
    required this.maxSettleCents,
    required this.settlementCurrencyCode,
    required this.currency,
    required this.isExpressNetting,
    required this.isNetPayer,
    required this.settleTheyOweYou,
    required this.scheme,
    required this.l10n,
    this.onShowBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.sheetBackground, // M3 distinctive surface
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            l10n.amountToSettle.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: scheme.mutedForeground,
            ),
          ),
          if (onShowBreakdown != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: onShowBreakdown,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.howItSCalculated,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: scheme.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (!hasSelectedMember)
            Text(
              l10n.pleaseSelectMember,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.outline,
              ),
              textAlign: TextAlign.center,
            )
          else if (nothingToSettle)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.nothingToSettle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Text(
                  formatCurrency(
                    maxSettleCents / 100.0,
                    settlementCurrencyCode,
                  ),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: scheme.foreground,
                    height: 1.0,
                    letterSpacing: -1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpressNetting
                        ? (isNetPayer ? l10n.youOwe : l10n.theyOweYou)
                        : (settleTheyOweYou ? l10n.theyOweYou : l10n.youOwe),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }
}
