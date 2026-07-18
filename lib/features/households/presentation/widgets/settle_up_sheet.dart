import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/sync/household_settlement_outbox_dispatcher.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/features/households/presentation/pages/settlement_calculation_breakdown_page.dart';
import 'package:moneko/features/households/presentation/utils/settlement_input_utils.dart';
import '../providers/household_providers.dart';
import '../providers/cached_providers.dart';
import '../providers/household_derived_providers.dart';
import '../providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
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

enum _SettlementBalanceStatus { idle, loading, data, error }

class _ConfirmedSettlementContext {
  final int balanceRequestGeneration;
  final String memberId;
  final String currencyCode;
  final int maxCents;
  final bool currentUserOwes;
  final String snapshotToken;

  const _ConfirmedSettlementContext({
    required this.balanceRequestGeneration,
    required this.memberId,
    required this.currencyCode,
    required this.maxCents,
    required this.currentUserOwes,
    required this.snapshotToken,
  });
}

class _AuthoritativeSettlementSnapshot {
  final String memberId;
  final String currencyCode;
  final SettlementPairwiseBalance balance;
  final int maxCents;
  final bool currentUserOwes;
  final String snapshotToken;

  const _AuthoritativeSettlementSnapshot({
    required this.memberId,
    required this.currencyCode,
    required this.balance,
    required this.maxCents,
    required this.currentUserOwes,
    required this.snapshotToken,
  });

  bool matches(_ConfirmedSettlementContext confirmed) {
    return memberId == confirmed.memberId &&
        currencyCode == confirmed.currencyCode &&
        maxCents == confirmed.maxCents &&
        currentUserOwes == confirmed.currentUserOwes &&
        snapshotToken == confirmed.snapshotToken;
  }
}

class _PendingSettlementAttempt {
  const _PendingSettlementAttempt({
    required this.householdId,
    required this.memberUserId,
    required this.mode,
    required this.amountCents,
    required this.currency,
    required this.note,
    required this.expectedSnapshotToken,
    required this.clientMutationId,
  });

  final String householdId;
  final String memberUserId;
  final String mode;
  final int amountCents;
  final String currency;
  final String? note;
  final String expectedSnapshotToken;
  final String clientMutationId;
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
  String _settlementCurrencyCode = '';
  String? _snapshotToken;
  _SettlementBalanceStatus _balanceStatus = _SettlementBalanceStatus.idle;
  int _balanceRequestGeneration = 0;
  String? _requestedMemberId;
  String? _requestedCurrencyCode;
  bool _balanceRecomputeScheduled = false;
  _ConfirmedSettlementContext? _confirmedSettlementContext;
  _PendingSettlementAttempt? _pendingSettlementAttempt;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.specificMemberId;
    if (widget.settlementNote != null && widget.settlementNote!.isNotEmpty) {
      _noteController.text = widget.settlementNote!;
    }
    if (_selectedMemberId != null) {
      _scheduleBalanceRecompute();
    }
  }

  @override
  void didUpdateWidget(covariant SettleUpSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId == widget.householdId &&
        oldWidget.specificMemberId == widget.specificMemberId &&
        oldWidget.currency == widget.currency &&
        oldWidget.isExpressNetting == widget.isExpressNetting &&
        oldWidget.settleTheyOweYou == widget.settleTheyOweYou) {
      return;
    }

    _selectedMemberId = widget.specificMemberId;
    _pendingSettlementAttempt = null;
    _invalidateBalanceState();
    if (_selectedMemberId != null) {
      _scheduleBalanceRecompute();
    }
  }

  void _scheduleBalanceRecompute() {
    if (_balanceRecomputeScheduled) return;
    _balanceRecomputeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _balanceRecomputeScheduled = false;
      if (mounted) {
        _recomputeFromSplits();
      }
    });
  }

  String _currentCurrencyCode() {
    final homeFilter = ref.read(homeFilterProvider);
    final currencyCode =
        (widget.currency ?? (homeFilter.selectedCurrency ?? 'USD'))
            .trim()
            .toUpperCase();
    return currencyCode.isEmpty ? 'USD' : currencyCode;
  }

  void _invalidateBalanceState() {
    _balanceRequestGeneration += 1;
    _requestedMemberId = null;
    _requestedCurrencyCode = null;
    _balanceStatus = _SettlementBalanceStatus.idle;
    _youOweCents = 0;
    _youAreOwedCents = 0;
    _paidToCents = 0;
    _paidFromCents = 0;
    _maxSettleCents = 0;
    _settlementCurrencyCode = '';
    _snapshotToken = null;
    _pendingAmountText = null;
    _confirmedSettlementContext = null;
  }

  bool _isCurrentBalanceRequest({
    required int requestGeneration,
    required String memberId,
    required String currencyCode,
  }) {
    if (!mounted) return false;
    return isCurrentSettlementBalanceRequest(
      requestGeneration: requestGeneration,
      currentGeneration: _balanceRequestGeneration,
      requestedMemberId: memberId,
      currentMemberId: widget.specificMemberId ?? _selectedMemberId,
      requestedCurrencyCode: currencyCode,
      currentCurrencyCode: _currentCurrencyCode(),
    );
  }

  bool _isConfirmedSettlementContextCurrent(
    _ConfirmedSettlementContext confirmed,
  ) {
    return _balanceStatus == _SettlementBalanceStatus.data &&
        _maxSettleCents == confirmed.maxCents &&
        _snapshotToken == confirmed.snapshotToken &&
        _isCurrentBalanceRequest(
          requestGeneration: confirmed.balanceRequestGeneration,
          memberId: confirmed.memberId,
          currencyCode: confirmed.currencyCode,
        );
  }

  Future<void> _recomputeFromSplits() async {
    if (!mounted) return;

    final memberId = widget.specificMemberId ?? _selectedMemberId;
    if (memberId == null) {
      setState(_invalidateBalanceState);
      return;
    }

    final currencyCode = _currentCurrencyCode();
    final requestGeneration = ++_balanceRequestGeneration;
    setState(() {
      _requestedMemberId = memberId;
      _requestedCurrencyCode = currencyCode;
      _balanceStatus = _SettlementBalanceStatus.loading;
      _youOweCents = 0;
      _youAreOwedCents = 0;
      _paidToCents = 0;
      _paidFromCents = 0;
      _maxSettleCents = 0;
      _settlementCurrencyCode = currencyCode;
      _snapshotToken = null;
      _pendingAmountText = null;
    });

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
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[SettleUpSheet] authoritative v2 recompute failed: $error\n$stackTrace',
        );
      }
      if (!_isCurrentBalanceRequest(
        requestGeneration: requestGeneration,
        memberId: memberId,
        currencyCode: currencyCode,
      )) {
        return;
      }
      setState(() {
        _balanceStatus = _SettlementBalanceStatus.error;
        _youOweCents = 0;
        _youAreOwedCents = 0;
        _paidToCents = 0;
        _paidFromCents = 0;
        _maxSettleCents = 0;
      });
      return;
    }

    if (!_isCurrentBalanceRequest(
      requestGeneration: requestGeneration,
      memberId: memberId,
      currencyCode: currencyCode,
    )) {
      return;
    }

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

    setState(() {
      _youOweCents = netYouOwe;
      _youAreOwedCents = netYouAreOwed;
      _paidToCents = balance.paidToCents;
      _paidFromCents = balance.paidFromCents;
      _maxSettleCents = maxSettleCents;
      _settlementCurrencyCode = currencyCode;
      _snapshotToken = null;
      _balanceStatus = _SettlementBalanceStatus.data;
    });
  }

  void _openCalculationBreakdownPage(
    BuildContext context, {
    required String householdId,
    required String currentUserId,
    required HouseholdMember member,
    required String currencyCode,
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
          currencyCode: currencyCode,
          currentUserContact: ref.read(analyticsProvider).contact,
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
    final rawCurrency =
        (widget.currency ?? (homeFilter.selectedCurrency ?? 'USD'))
            .trim()
            .toUpperCase();
    final currency = rawCurrency.isEmpty ? 'USD' : rawCurrency;
    ref.listen<int>(
      householdRemoteMutationRefreshSignalProvider(widget.householdId),
      (previous, next) {
        if (previous != next &&
            !_isProcessing &&
            _pendingSettlementAttempt == null &&
            (widget.specificMemberId ?? _selectedMemberId) != null) {
          _scheduleBalanceRecompute();
        }
      },
    );
    ref.listen<int>(transactionsFeedRefreshSignalProvider, (previous, next) {
      if (previous != next &&
          !_isProcessing &&
          _pendingSettlementAttempt == null &&
          (widget.specificMemberId ?? _selectedMemberId) != null) {
        _scheduleBalanceRecompute();
      }
    });
    ref.listen<List<ExpenseSplitGroup>>(
      householdOptimisticSplitsProvider.select(
        (state) => state[widget.householdId] ?? const <ExpenseSplitGroup>[],
      ),
      (previous, next) {
        if (!identical(previous, next) &&
            !_isProcessing &&
            _pendingSettlementAttempt == null &&
            (widget.specificMemberId ?? _selectedMemberId) != null) {
          _scheduleBalanceRecompute();
        }
      },
    );
    ref.listen<Set<String>>(
      householdOptimisticDeletedExpenseIdsProvider.select(
        (state) => state[widget.householdId] ?? const <String>{},
      ),
      (previous, next) {
        if (!identical(previous, next) &&
            !_isProcessing &&
            _pendingSettlementAttempt == null &&
            (widget.specificMemberId ?? _selectedMemberId) != null) {
          _scheduleBalanceRecompute();
        }
      },
    );
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final expensesAsync = ref.watch(cachedHouseholdExpensesProvider(
      HouseholdExpensesParams(householdId: widget.householdId),
    ));
    final splitsAsync = ref.watch(cachedHouseholdSplitsProvider(
      HouseholdSplitsParams(householdId: widget.householdId),
    ));
    final optimisticSplits = ref.watch(
      householdOptimisticSplitsProvider.select(
        (state) => state[widget.householdId] ?? const <ExpenseSplitGroup>[],
      ),
    );
    final userId = ref.watch(authProvider.select((user) => user.uid));
    final transactions = expensesAsync.valueOrNull ?? const <ExpenseEntry>[];
    final effectiveSplits = mergeHouseholdSplits(
      splitsAsync.valueOrNull ?? widget.splits ?? const <ExpenseSplitGroup>[],
      optimisticSplits,
    );

    final hasSelectedMember =
        _selectedMemberId != null || widget.specificMemberId != null;
    final selectedMemberId = widget.specificMemberId ?? _selectedMemberId;
    if (selectedMemberId != null) {
      if (_requestedCurrencyCode != null &&
          _requestedCurrencyCode != currency &&
          !_isProcessing) {
        _scheduleBalanceRecompute();
      }
    }
    if (selectedMemberId != null &&
        (_requestedMemberId != selectedMemberId ||
            _requestedCurrencyCode != currency)) {
      _scheduleBalanceRecompute();
    }

    final hasResolvedBalance =
        _balanceStatus == _SettlementBalanceStatus.data &&
            _requestedMemberId == selectedMemberId &&
            _requestedCurrencyCode == currency;
    final hasOutstanding = _youOweCents > 0 || _youAreOwedCents > 0;

    // Determine when there is actually something the current user can mark as settled.
    // For express netting, any non-zero dues in either direction can be settled.
    // For detailed mode, we gate by the selected direction.
    final bool nothingToSettle;
    if (!hasSelectedMember || !hasResolvedBalance) {
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
    final canSettle = hasResolvedBalance &&
        hasSelectedMember &&
        !nothingToSettle &&
        _maxSettleCents > 0;
    final hasPendingSettlementAttempt = _pendingSettlementAttempt != null;
    final interactionLocked = _isProcessing || hasPendingSettlementAttempt;
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
                              userId: userId,
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
                              _selectedMemberId == null &&
                              !interactionLocked) {
                            // This side-effect in build is tricky but modifying state during build is bad.
                            // The original code had it in a post frame callback.
                            // We preserve the logic location, just rendering here.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  _selectedMemberId == null &&
                                  !_isProcessing &&
                                  _pendingSettlementAttempt == null) {
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
                                onSelect: interactionLocked
                                    ? null
                                    : (id) {
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
                      isBalanceLoading: hasSelectedMember &&
                          !hasResolvedBalance &&
                          !(_balanceStatus == _SettlementBalanceStatus.error &&
                              _requestedMemberId == selectedMemberId &&
                              _requestedCurrencyCode == currency),
                      hasBalanceError:
                          _balanceStatus == _SettlementBalanceStatus.error &&
                              _requestedMemberId == selectedMemberId &&
                              _requestedCurrencyCode == currency,
                      isExpressNetting: widget.isExpressNetting,
                      isNetPayer: isNetPayer,
                      settleTheyOweYou: widget.settleTheyOweYou,
                      scheme: colorScheme,
                      l10n: context.l10n,
                      onRetryBalance: hasSelectedMember && !interactionLocked
                          ? _scheduleBalanceRecompute
                          : null,
                      onShowBreakdown: hasSelectedMember &&
                              !interactionLocked &&
                              userId.isNotEmpty
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
                                currencyCode: currency,
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
                      onPressed:
                          _isProcessing ? null : () => Navigator.pop(context),
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
                      onPressed: _isProcessing ||
                              (!canSettle && !hasPendingSettlementAttempt)
                          ? null
                          : _confirmAndSettle,
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
                              hasPendingSettlementAttempt
                                  ? context.l10n.tryAgain
                                  : context.l10n.settle,
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

  Future<bool> _showConfirm() async {
    _pendingAmountText = null;
    _confirmedSettlementContext = null;
    final maxCents = _maxSettleCents;
    final memberId = widget.specificMemberId ?? _selectedMemberId;
    final currencyCode = _settlementCurrencyCode;
    final snapshotToken = _snapshotToken;
    final requestGeneration = _balanceRequestGeneration;
    if (_balanceStatus != _SettlementBalanceStatus.data ||
        memberId == null ||
        currencyCode.isEmpty ||
        snapshotToken == null ||
        maxCents <= 0) {
      if (mounted) {
        AppToast.info(context, context.l10n.tryAgain);
      }
      return false;
    }

    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.confirmSettlement,
      description:
          '${context.l10n.amountToSettle}: ${formatCurrency(maxCents / 100.0, currencyCode)}',
      confirmLabel: context.l10n.settle,
      cancelLabel: context.l10n.cancel,
      barrierDismissible: true,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: formatAmount(maxCents / 100.0),
        placeholder: context.l10n.amountPlaceholder,
        isRequired: true,
        validationMessage: context.l10n.invalidAmount,
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
    if (!_isCurrentBalanceRequest(
          requestGeneration: requestGeneration,
          memberId: memberId,
          currencyCode: currencyCode,
        ) ||
        _balanceStatus != _SettlementBalanceStatus.data ||
        _maxSettleCents != maxCents) {
      if (mounted) {
        AppToast.info(context, context.l10n.tryAgain);
      }
      return false;
    }
    final requestedCents = parseSettlementAmountCents(result.text);
    if (requestedCents == null) {
      if (mounted) {
        AppToast.info(context, context.l10n.invalidAmount);
      }
      return false;
    }
    if (requestedCents > maxCents) {
      if (mounted) {
        AppToast.info(
          context,
          '${context.l10n.maxIs} '
          '${formatCurrency(maxCents / 100.0, currencyCode)}',
        );
      }
      return false;
    }
    _pendingAmountText = result.text;
    _confirmedSettlementContext = _ConfirmedSettlementContext(
      balanceRequestGeneration: requestGeneration,
      memberId: memberId,
      currencyCode: currencyCode,
      maxCents: maxCents,
      currentUserOwes: widget.isExpressNetting
          ? _youOweCents >= _youAreOwedCents
          : !widget.settleTheyOweYou,
      snapshotToken: snapshotToken,
    );
    _noteController.text = (result.secondaryText ?? '').trim();
    return true;
  }

  Future<_AuthoritativeSettlementSnapshot?>
      _fetchAuthoritativeSettlementSnapshot() async {
    final memberId = widget.specificMemberId ?? _selectedMemberId;
    final currencyCode = _currentCurrencyCode();
    if (memberId == null || currencyCode.isEmpty) return null;

    try {
      await ref.read(mobileOutboxDrainerProvider).drain(maxMutations: 100);
      final coordinator = await ref.read(
        mobileOutboxSyncCoordinatorProvider.future,
      );
      if (!mounted) return null;

      // Fetch from the repository instead of a stale-while-revalidate cache so
      // successfully drained optimistic split rows can be proven present on
      // the server before any payment is recorded.
      final remoteSplits = await ref
          .read(householdRepositoryProvider)
          .getHouseholdSplits(householdId: widget.householdId);
      ref
          .read(householdOptimisticSplitsProvider.notifier)
          .pruneIfInServer(widget.householdId, remoteSplits);

      final hasPendingLocalMutation = await coordinator.database
          .hasPendingHouseholdTransactionMutations(widget.householdId);
      final hasPendingSettlement =
          await coordinator.database.hasPendingHouseholdSettlementMutations(
        householdId: widget.householdId,
        memberUserId: memberId,
        currency: currencyCode,
      );
      final hasUnconfirmedOptimisticSplit =
          (ref.read(householdOptimisticSplitsProvider)[widget.householdId] ??
                  const <ExpenseSplitGroup>[])
              .isNotEmpty;
      final optimisticDeletedExpenseIds = ref.read(
            householdOptimisticDeletedExpenseIdsProvider,
          )[widget.householdId] ??
          const <String>{};

      if (hasPendingLocalMutation ||
          hasPendingSettlement ||
          hasUnconfirmedOptimisticSplit) {
        if (mounted) {
          AppToast.info(context, context.l10n.tryAgain);
        }
        return null;
      }

      // The durable outbox/tombstone gate above is authoritative. Once it is
      // clear, any in-memory delete marker is stale (the delete either synced
      // or never became durable) and must not block settlement for the rest
      // of this process lifetime.
      if (optimisticDeletedExpenseIds.isNotEmpty) {
        ref
            .read(householdOptimisticDeletedExpenseIdsProvider.notifier)
            .restore(widget.householdId, optimisticDeletedExpenseIds);
      }

      // Confirmation must bypass the optimistic/cached provider. A retained
      // synced tombstone can intentionally keep that provider on its local
      // fallback path, which is useful for normal rendering but not safe for
      // recording an irreversible settlement payment.
      final response =
          await ref.read(householdServiceProvider).getSettlementCalculationV3(
                householdId: widget.householdId,
                memberUserId: memberId,
                currency: currencyCode,
              );
      if (!mounted ||
          memberId != (widget.specificMemberId ?? _selectedMemberId) ||
          currencyCode != _currentCurrencyCode()) {
        return null;
      }

      final calculation = SettlementCalculationV3.fromJson(response);
      if (!calculation.hasAuthoritativeSnapshotToken ||
          calculation.householdId != widget.householdId ||
          calculation.memberUserId != memberId ||
          calculation.currency != currencyCode) {
        throw const FormatException(
          'Settlement calculation did not include a matching server snapshot',
        );
      }
      final balance = SettlementPairwiseBalance(
        otherUserId: memberId,
        currency: currencyCode,
        splitToCents: calculation.splitToCents,
        splitFromCents: calculation.splitFromCents,
        paidToCents: calculation.paidToCents,
        paidFromCents: calculation.paidFromCents,
        netCents: calculation.netCents,
      );

      final maxCents = widget.isExpressNetting
          ? balance.netCents.abs()
          : widget.settleTheyOweYou
              ? balance.youAreOwedCents
              : balance.youOweCents;
      final currentUserOwes = widget.isExpressNetting
          ? balance.netCents >= 0
          : !widget.settleTheyOweYou;
      return _AuthoritativeSettlementSnapshot(
        memberId: memberId,
        currencyCode: currencyCode,
        balance: balance,
        maxCents: maxCents,
        currentUserOwes: currentUserOwes,
        snapshotToken: calculation.snapshotToken!,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[SettleUpSheet] settlement preflight failed: $error\n$stackTrace',
        );
      }
      if (mounted) {
        AppToast.info(context, context.l10n.tryAgain);
      }
      return null;
    }
  }

  bool _applyAuthoritativeSettlementSnapshot(
    _AuthoritativeSettlementSnapshot snapshot,
  ) {
    if (!mounted ||
        snapshot.memberId != (widget.specificMemberId ?? _selectedMemberId) ||
        snapshot.currencyCode != _currentCurrencyCode()) {
      return false;
    }

    _balanceRequestGeneration += 1;
    setState(() {
      _requestedMemberId = snapshot.memberId;
      _requestedCurrencyCode = snapshot.currencyCode;
      _youOweCents = snapshot.balance.youOweCents;
      _youAreOwedCents = snapshot.balance.youAreOwedCents;
      _paidToCents = snapshot.balance.paidToCents;
      _paidFromCents = snapshot.balance.paidFromCents;
      _maxSettleCents = snapshot.maxCents;
      _settlementCurrencyCode = snapshot.currencyCode;
      _snapshotToken = snapshot.snapshotToken;
      _balanceStatus = _SettlementBalanceStatus.data;
    });
    return true;
  }

  Future<bool> _prepareAuthoritativeSettlementBalance() async {
    final snapshot = await _fetchAuthoritativeSettlementSnapshot();
    return snapshot != null && _applyAuthoritativeSettlementSnapshot(snapshot);
  }

  Future<void> _confirmAndSettle() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    var attemptPersisted = _pendingSettlementAttempt != null;
    var closedSheet = false;

    try {
      var attempt = _pendingSettlementAttempt;
      if (attempt == null) {
        if (!await _prepareAuthoritativeSettlementBalance()) return;
        if (!await _showConfirm()) return;
        final confirmed = _confirmedSettlementContext;
        if (confirmed == null ||
            !_isConfirmedSettlementContextCurrent(confirmed)) {
          if (mounted) AppToast.info(context, context.l10n.tryAgain);
          return;
        }

        final requestedCents = parseSettlementAmountCents(_pendingAmountText);
        final amountCents = requestedCents == null
            ? null
            : clampSettlementAmountCents(
                requestedCents: requestedCents,
                maxCents: confirmed.maxCents,
              );
        if (amountCents == null || amountCents <= 0) {
          if (mounted) AppToast.info(context, context.l10n.invalidAmount);
          return;
        }

        // The token is an opaque hash of row identities, cycle boundary,
        // causal events, and allocations—not just aggregate totals. A second
        // read catches dialog-time changes; the RPC compares it once more
        // under the same household lock before writing.
        final revalidatedSnapshot =
            await _fetchAuthoritativeSettlementSnapshot();
        if (revalidatedSnapshot == null) return;
        if (!revalidatedSnapshot.matches(confirmed)) {
          _applyAuthoritativeSettlementSnapshot(revalidatedSnapshot);
          if (mounted) AppToast.info(context, context.l10n.tryAgain);
          return;
        }

        final note = _noteController.text.trim();
        attempt = _PendingSettlementAttempt(
          householdId: widget.householdId,
          memberUserId: confirmed.memberId,
          mode: widget.isExpressNetting
              ? 'both'
              : widget.settleTheyOweYou
                  ? 'from_member'
                  : 'to_member',
          amountCents: amountCents,
          currency: confirmed.currencyCode,
          note: note.isEmpty ? null : note,
          expectedSnapshotToken: confirmed.snapshotToken,
          clientMutationId: generateSettlementClientMutationId(),
        );

        final coordinator = await ref.read(
          mobileOutboxSyncCoordinatorProvider.future,
        );
        await coordinator.database.enqueueHouseholdSettlementMutation(
          householdId: attempt.householdId,
          memberUserId: attempt.memberUserId,
          mode: attempt.mode,
          amountCents: attempt.amountCents,
          currency: attempt.currency,
          note: attempt.note,
          expectedSnapshotToken: attempt.expectedSnapshotToken,
          clientMutationId: attempt.clientMutationId,
        );
        attemptPersisted = true;
        if (mounted) {
          setState(() => _pendingSettlementAttempt = attempt);
        } else {
          _pendingSettlementAttempt = attempt;
        }
      }

      final result = await _submitSettlementAttempt(attempt);
      if (!mounted) return;
      setState(() => _pendingSettlementAttempt = null);
      await _refreshSettlementData(attempt.currency);
      if (!mounted) return;

      switch (result.status) {
        case SettlementWriteStatusV2.applied:
          closedSheet = true;
          Navigator.pop(context, true);
          AppToast.success(context, context.l10n.settlementCompleted);
          break;
        case SettlementWriteStatusV2.snapshotConflict:
          await _prepareAuthoritativeSettlementBalance();
          if (!mounted) return;
          if (mounted) AppToast.info(context, context.l10n.tryAgain);
          break;
        case SettlementWriteStatusV2.nothingToSettle:
          await _prepareAuthoritativeSettlementBalance();
          if (!mounted) return;
          if (mounted) AppToast.info(context, context.l10n.nothingToSettle);
          break;
      }
    } catch (e) {
      if (!attemptPersisted) {
        _pendingSettlementAttempt = null;
      }
      if (mounted) {
        AppToast.error(context, '${context.l10n.error}: $e');
      }
    } finally {
      _confirmedSettlementContext = null;
      _pendingAmountText = null;
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        if (!closedSheet && _pendingSettlementAttempt == null) {
          _recomputeFromSplits();
        }
      }
    }
  }

  Future<SettlementWriteResultV2> _submitSettlementAttempt(
    _PendingSettlementAttempt attempt,
  ) async {
    final response =
        await ref.read(householdServiceProvider).settleAmountAndNotifyV2(
              householdId: attempt.householdId,
              memberUserId: attempt.memberUserId,
              mode: attempt.mode,
              amountCents: attempt.amountCents,
              currency: attempt.currency,
              expectedSnapshotToken: attempt.expectedSnapshotToken,
              clientMutationId: attempt.clientMutationId,
              settlementNote: attempt.note,
            );
    final result = parseHouseholdSettlementWriteResult(
      response,
      expectedClientMutationId: attempt.clientMutationId,
      expectedAmountCents: attempt.amountCents,
    );
    final coordinator = await ref.read(
      mobileOutboxSyncCoordinatorProvider.future,
    );
    await coordinator.database.markMutationSynced(attempt.clientMutationId);
    return result;
  }

  Future<void> _refreshSettlementData(String settlementCurrency) async {
    try {
      await clearHouseholdSettlementPaymentsPersistentCache(
        widget.householdId,
      );
    } catch (_) {}
    ref
        .read(householdRemoteMutationRefreshSignalProvider(
          widget.householdId,
        ).notifier)
        .state += 1;
    ref.read(cacheInvalidatorProvider).invalidateHouseholdData(
          widget.householdId,
        );
    ref.invalidate(cachedHouseholdExpensesProvider(
      HouseholdExpensesParams(householdId: widget.householdId),
    ));
    ref.invalidate(cachedHouseholdSplitsProvider(
      HouseholdSplitsParams(householdId: widget.householdId),
    ));
    try {
      final homeFilter = ref.read(homeFilterProvider);
      final periodSelection = ref.read(periodFilterProvider);
      final financialMonthStartDay = ref.read(financialMonthStartDayProvider);
      final range = resolvePeriodDateRange(
        periodSelection,
        financialMonthStartDay: financialMonthStartDay,
      );
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
        SettlementHistoryParams(householdId: widget.householdId),
      ));
      ref.invalidate(householdSettlementPaymentsProvider(widget.householdId));
      ref.invalidate(householdPairwiseSettlementBalancesV2Provider(
        PairwiseSettlementBalancesParams(
          householdId: widget.householdId,
          currency: settlementCurrency,
        ),
      ));
      ref.invalidate(householdSettlementBreakdownV2Provider);
    } catch (_) {}
  }

  String? _pendingAmountText;
}

/// A modern, scrollable selector using rounded "chips" with avatars.
class _ModernMemberSelector extends StatelessWidget {
  final List<HouseholdMember> members;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
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

          return Semantics(
            button: true,
            enabled: onSelect != null,
            selected: isSelected,
            label: name,
            child: Material(
              color: scheme.surface.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onSelect == null ? null : () => onSelect!(m.userId),
                borderRadius: BorderRadius.circular(20),
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
  final bool isBalanceLoading;
  final bool hasBalanceError;
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
  final VoidCallback? onRetryBalance;

  const _AmountDisplayCard({
    required this.nothingToSettle,
    required this.hasSelectedMember,
    required this.isBalanceLoading,
    required this.hasBalanceError,
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
    this.onRetryBalance,
  });

  @override
  Widget build(BuildContext context) {
    final directionLabel = isExpressNetting
        ? (isNetPayer ? l10n.youOwe : l10n.theyOweYou)
        : (settleTheyOweYou ? l10n.theyOweYou : l10n.youOwe);
    final semanticLabel = !hasSelectedMember
        ? l10n.pleaseSelectMember
        : isBalanceLoading
            ? l10n.loading
            : hasBalanceError
                ? l10n.errorLoadingData
                : nothingToSettle
                    ? l10n.nothingToSettle
                    : '${l10n.amountToSettle}: '
                        '${formatCurrency(maxSettleCents / 100.0, settlementCurrencyCode)}, '
                        '$directionLabel';

    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: scheme.sheetBackground, // M3 distinctive surface
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
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
                child: Semantics(
                  button: true,
                  label: context.l10n.howItSCalculated,
                  child: Material(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: InkWell(
                      onTap: onShowBreakdown,
                      borderRadius: BorderRadius.circular(22),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              const SizedBox(width: 4),
                              Icon(
                                Icons.help_outline_rounded,
                                size: 16,
                                color: scheme.mutedForeground,
                              ),
                            ],
                          ),
                        ),
                      ),
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
            else if (isBalanceLoading)
              Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.loading,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else if (hasBalanceError)
              Column(
                children: [
                  Icon(Icons.error_outline_rounded, color: scheme.error),
                  const SizedBox(height: 8),
                  Text(
                    l10n.errorLoadingData,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (onRetryBalance != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onRetryBalance,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(l10n.retry),
                    ),
                  ],
                ],
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
                      directionLabel,
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
      ),
    );
  }
}
