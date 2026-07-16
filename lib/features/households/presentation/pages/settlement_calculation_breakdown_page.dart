import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/utils/settlement_breakdown_display.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/shared/widgets/user_avatar.dart';

class SettlementCalculationBreakdownPage extends ConsumerWidget {
  final String householdId;
  final String currentUserId;
  final String memberUserId;
  final String memberDisplayName;
  final String currencyCode;
  final List<ExpenseEntry> transactions;
  final List<ExpenseSplitGroup> splits;
  final int paidToCents;
  final int paidFromCents;
  final int netCents;

  const SettlementCalculationBreakdownPage({
    super.key,
    required this.householdId,
    required this.currentUserId,
    required this.memberUserId,
    required this.memberDisplayName,
    required this.currencyCode,
    this.transactions = const <ExpenseEntry>[],
    this.splits = const <ExpenseSplitGroup>[],
    this.paidToCents = 0,
    this.paidFromCents = 0,
    required this.netCents,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final params = SettlementBreakdownV2Params(
      householdId: householdId,
      memberUserId: memberUserId,
      currency: currencyCode,
    );
    final calculationAsync = ref.watch(
      householdSettlementCalculationV3Provider(params),
    );

    return Scaffold(
      backgroundColor: scheme.appBackground,
      appBar: AppBar(
        backgroundColor: scheme.appBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.l10n.breakdown,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: scheme.foreground,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: calculationAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => _buildPageBody(
            key: const ValueKey('settlement-breakdown-loading'),
            context: context,
            trailingContent: _LoadingState(label: context.l10n.loading),
          ),
          error: (_, __) {
            final previous = calculationAsync.valueOrNull;
            final retry = _ErrorState(
              message: context.l10n.errorLoadingData,
              retryLabel: context.l10n.retry,
              onRetry: () => ref.invalidate(
                householdSettlementCalculationV3Provider(params),
              ),
            );
            if (previous == null) {
              return _buildPageBody(
                key: const ValueKey('settlement-breakdown-error'),
                context: context,
                trailingContent: retry,
              );
            }

            return _buildPageBody(
              key: const ValueKey('settlement-breakdown-stale-data'),
              context: context,
              netCents: previous.netCents,
              rows: previous.rows,
              calculationNetCents: previous.netCents,
              trailingContent: retry,
            );
          },
          data: (calculation) {
            final rows = calculation.rows;
            if (kDebugMode) {
              final breakdownNet = calculateSettlementBreakdownRowsNetCents(
                rows: rows,
              );
              if (breakdownNet != calculation.netCents) {
                debugPrint(
                  '[SettlementBreakdownPage] household=$householdId member=$memberUserId canonicalNet=${calculation.netCents} breakdownNet=$breakdownNet rows=${rows.length}',
                );
              }
            }

            return _buildPageBody(
              key: const ValueKey('settlement-breakdown-data'),
              context: context,
              netCents: calculation.netCents,
              rows: rows,
              calculationNetCents: calculation.netCents,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageBody({
    required Key key,
    required BuildContext context,
    int? netCents,
    List<_BreakdownRowData>? rows,
    int? calculationNetCents,
    Widget? trailingContent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final slivers = <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
    if (netCents != null) {
      slivers.addAll([
        _withHorizontalPadding(
          SliverToBoxAdapter(
            child: _SummaryCard(
              currentUserId: currentUserId,
              memberUserId: memberUserId,
              memberDisplayName: memberDisplayName,
              netCents: netCents,
              currencyCode: currencyCode,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ]);
    }
    if (rows != null && calculationNetCents != null) {
      slivers.addAll(
        _buildBreakdownSlivers(
          context,
          scheme,
          rows,
          calculationNetCents: calculationNetCents,
        ),
      );
    }
    if (trailingContent != null) {
      if (rows != null) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
      }
      slivers.add(
        _withHorizontalPadding(
          SliverToBoxAdapter(child: trailingContent),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 28)));

    return CustomScrollView(
      key: key,
      slivers: slivers,
    );
  }

  Widget _withHorizontalPadding(Widget sliver) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: sliver,
    );
  }

  List<Widget> _buildBreakdownSlivers(
    BuildContext context,
    ColorScheme scheme,
    List<_BreakdownRowData> rows, {
    required int calculationNetCents,
  }) {
    final transactionRows = rows.where((row) => !row.isSynthetic).toList();
    final youOweRows = transactionRows
        .where((row) => row.direction == _Direction.youOwe)
        .toList();
    final theyOweRows = transactionRows
        .where((row) => row.direction == _Direction.theyOweYou)
        .toList();
    final carryoverRows = rows.where((row) => row.isLegacyCarryover).toList();
    final explicitAdjustmentRows =
        rows.where((row) => row.isAdjustment).toList();
    final adjustmentCents = calculateSettlementBreakdownAdjustmentCents(
      fallbackNetCents: calculationNetCents,
      rows: rows,
    );

    final slivers = <Widget>[];
    var hasSection = false;

    void addSectionGap() {
      if (hasSection) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
      }
    }

    void addExplanationRow({
      required _BreakdownRowData row,
      required String title,
      required String description,
      required bool showDirectionSign,
    }) {
      addSectionGap();
      slivers.add(
        _withHorizontalPadding(
          SliverToBoxAdapter(
            child: _BalanceExplanationSection(
              title: title,
              currencyCode: currencyCode,
              amountCents: row.remainingAmountCents,
              direction: row.direction,
              description: description,
              showDirectionSign: showDirectionSign,
            ),
          ),
        ),
      );
      hasSection = true;
    }

    for (final row in carryoverRows) {
      addExplanationRow(
        row: row,
        title: context.l10n.balanceCarriedForward,
        description: context.l10n.balanceCarriedForwardDescription,
        showDirectionSign: true,
      );
    }

    if (youOweRows.isNotEmpty) {
      addSectionGap();
      slivers.addAll(
        _buildTransactionSectionSlivers(
          title: '${context.l10n.youOwe} $memberDisplayName',
          currencyCode: currencyCode,
          rows: youOweRows,
        ),
      );
      hasSection = true;
    }
    if (theyOweRows.isNotEmpty) {
      addSectionGap();
      slivers.addAll(
        _buildTransactionSectionSlivers(
          title: '$memberDisplayName ${context.l10n.owesYou}',
          currencyCode: currencyCode,
          rows: theyOweRows,
        ),
      );
      hasSection = true;
    }

    for (final row in explicitAdjustmentRows) {
      addExplanationRow(
        row: row,
        title: row.direction == _Direction.youOwe
            ? '${context.l10n.youOwe} ${context.l10n.adjustment}'
            : '${context.l10n.adjustment} ${context.l10n.owesYou}',
        description: context.l10n.settlement,
        showDirectionSign: false,
      );
    }

    if (adjustmentCents != 0) {
      addSectionGap();
      final adjustmentDirection =
          adjustmentCents > 0 ? _Direction.youOwe : _Direction.theyOweYou;
      slivers.add(
        _withHorizontalPadding(
          SliverToBoxAdapter(
            child: _BalanceExplanationSection(
              title: adjustmentDirection == _Direction.youOwe
                  ? '${context.l10n.youOwe} ${context.l10n.adjustment}'
                  : '${context.l10n.adjustment} ${context.l10n.owesYou}',
              currencyCode: currencyCode,
              amountCents: adjustmentCents.abs(),
              direction: adjustmentDirection,
              description: context.l10n.settlement,
              showDirectionSign: false,
            ),
          ),
        ),
      );
      hasSection = true;
    }

    if (!hasSection) {
      slivers.add(
        _withHorizontalPadding(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.l10n.noSplitTransactionsFound,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  List<Widget> _buildTransactionSectionSlivers({
    required String title,
    required String currencyCode,
    required List<_BreakdownRowData> rows,
  }) {
    final totalCents =
        rows.fold<int>(0, (sum, row) => sum + row.remainingAmountCents);
    return [
      _withHorizontalPadding(
        SliverToBoxAdapter(
          child: _BreakdownSectionHeader(
            title: title,
            currencyCode: currencyCode,
            totalCents: totalCents,
          ),
        ),
      ),
      _withHorizontalPadding(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _BreakdownRowTile(
              row: rows[index],
              currencyCode: currencyCode,
            ),
            childCount: rows.length,
          ),
        ),
      ),
      _withHorizontalPadding(
        const SliverToBoxAdapter(child: _BreakdownSectionFooter()),
      ),
    ];
  }
}

typedef _Direction = SettlementBreakdownDirectionV2;
typedef _BreakdownRowData = SettlementBreakdownRowV2;

class _SummaryCard extends StatelessWidget {
  final String currentUserId;
  final String memberUserId;
  final String memberDisplayName;
  final int netCents;
  final String currencyCode;

  const _SummaryCard({
    required this.currentUserId,
    required this.memberUserId,
    required this.memberDisplayName,
    required this.netCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final netAmount = formatCurrency(
      netCents.abs() / 100.0,
      currencyCode,
      context: context,
    );
    final isNetPayer = netCents > 0;
    final nothingToSettle = netCents == 0;
    final netLabel = isNetPayer
        ? context.l10n.youOwe
        : netCents < 0
            ? context.l10n.theyOweYou
            : context.l10n.nothingToSettle;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AvatarNode(
                userId: currentUserId,
                label: context.l10n.you,
                scheme: scheme,
                borderColor: scheme.tertiaryContainer,
              ),
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
                              color: scheme.primary.withValues(alpha: 0.3),
                            ),
                            Icon(
                              isNetPayer
                                  ? Icons.arrow_forward
                                  : Icons.arrow_back,
                              color: scheme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
              _AvatarNode(
                userId: memberUserId,
                label: memberDisplayName,
                scheme: scheme,
                borderColor: scheme.secondaryContainer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: scheme.sheetBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                context.l10n.amountToSettle.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: scheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              if (nothingToSettle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.nothingToSettle,
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
                      netAmount,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        netLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarNode extends StatelessWidget {
  final String userId;
  final String label;
  final ColorScheme scheme;
  final Color borderColor;

  const _AvatarNode({
    required this.userId,
    required this.label,
    required this.scheme,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UserAvatar(
          name: label,
          userId: userId,
          size: 56,
          borderWidth: 2,
          borderColor: borderColor,
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

class _BreakdownSectionHeader extends StatelessWidget {
  final String title;
  final String currencyCode;
  final int totalCents;

  const _BreakdownSectionHeader({
    required this.title,
    required this.currencyCode,
    required this.totalCents,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: scheme.homeCardBorder),
          left: BorderSide(color: scheme.homeCardBorder),
          right: BorderSide(color: scheme.homeCardBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.foreground,
                ),
              ),
            ),
            Text(
              formatCurrency(
                totalCents / 100.0,
                currencyCode,
                context: context,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRowTile extends StatelessWidget {
  final _BreakdownRowData row;
  final String currencyCode;

  const _BreakdownRowTile({
    required this.row,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdjustment = row.isAdjustment;
    final totalAmount = formatCurrency(
      row.totalAmountCents.abs() / 100.0,
      currencyCode,
      context: context,
    );

    return Container(
      key: ValueKey(
        'settlement-breakdown-row-'
        '${row.splitLineId ?? row.expenseId ?? row.expenseDate.toIso8601String()}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.cardSurface,
        border: Border(
          left: BorderSide(color: scheme.homeCardBorder),
          right: BorderSide(color: scheme.homeCardBorder),
        ),
      ),
      child: TransactionListTile(
        category: isAdjustment
            ? context.l10n.adjustment
            : row.expenseCategory ?? context.l10n.other,
        title: isAdjustment
            ? context.l10n.adjustment
            : row.expenseRawText ??
                row.expenseDescription ??
                row.expenseCategory ??
                context.l10n.expense,
        description: isAdjustment
            ? context.l10n.settlement
            : row.expenseRawText ?? row.expenseDescription,
        date: row.expenseDate,
        amount: row.remainingAmountCents / 100.0,
        currency: currencyCode,
        isIncome: row.direction == _Direction.theyOweYou,
        onTap: null,
        trailingWidget: Text(
          context.l10n.ofTotalAmount(totalAmount),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: scheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _BreakdownSectionFooter extends StatelessWidget {
  const _BreakdownSectionFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: scheme.cardSurface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          left: BorderSide(color: scheme.homeCardBorder),
          right: BorderSide(color: scheme.homeCardBorder),
          bottom: BorderSide(color: scheme.homeCardBorder),
        ),
      ),
    );
  }
}

class _BalanceExplanationSection extends StatelessWidget {
  final String title;
  final String currencyCode;
  final int amountCents;
  final _Direction direction;
  final String description;
  final bool showDirectionSign;

  const _BalanceExplanationSection({
    required this.title,
    required this.currencyCode,
    required this.amountCents,
    required this.direction,
    required this.description,
    required this.showDirectionSign,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formattedAmount = formatCurrency(
      amountCents / 100.0,
      currencyCode,
      context: context,
    );
    final displayAmount = showDirectionSign
        ? direction == _Direction.youOwe
            ? '-$formattedAmount'
            : '+$formattedAmount'
        : formattedAmount;

    return Container(
      decoration: BoxDecoration(
        color: scheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.homeCardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.foreground,
                    ),
                  ),
                ),
                Text(
                  displayAmount,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: scheme.mutedForeground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.mutedForeground,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: scheme.destructive,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: OutlinedAdaptiveButton(
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
