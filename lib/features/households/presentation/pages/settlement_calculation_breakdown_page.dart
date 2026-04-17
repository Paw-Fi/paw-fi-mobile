import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/utils/settlement_breakdown_calculator.dart';
import 'package:moneko/features/households/presentation/utils/settlement_breakdown_display.dart';
import 'package:moneko/features/utils/currency.dart';
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
    final legacyTransactionsAsync = transactions.isNotEmpty
        ? AsyncValue.data(transactions)
        : ref.watch(cachedHouseholdExpensesProvider(
            HouseholdExpensesParams(householdId: householdId),
          ));
    final legacySplitsAsync = splits.isNotEmpty
        ? AsyncValue.data(splits)
        : ref.watch(cachedHouseholdSplitsProvider(
            HouseholdSplitsParams(householdId: householdId),
          ));
    final legacyPaymentsAsync = ref.watch(
      householdSettlementPaymentsProvider(householdId),
    );
    final breakdownAsync = ref.watch(
      householdSettlementBreakdownV2Provider(
        SettlementBreakdownV2Params(
          householdId: householdId,
          memberUserId: memberUserId,
          currency: currencyCode,
        ),
      ),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _SummaryCard(
            currentUserId: currentUserId,
            memberUserId: memberUserId,
            memberDisplayName: memberDisplayName,
            netCents: netCents,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: 18),
          breakdownAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) {
              final legacyRows = _buildLegacyRows(
                transactions: legacyTransactionsAsync.valueOrNull,
                splits: legacySplitsAsync.valueOrNull,
                paidToCents: legacyPaymentsAsync.valueOrNull
                        ?.where((payment) =>
                            (payment.currency?.trim().toUpperCase() ?? '') ==
                                currencyCode.trim().toUpperCase() &&
                            payment.payerUserId == memberUserId &&
                            payment.participantUserId == currentUserId)
                        .fold<int>(
                            0, (sum, payment) => sum + payment.amountCents) ??
                    paidToCents,
                paidFromCents: legacyPaymentsAsync.valueOrNull
                        ?.where((payment) =>
                            (payment.currency?.trim().toUpperCase() ?? '') ==
                                currencyCode.trim().toUpperCase() &&
                            payment.payerUserId == currentUserId &&
                            payment.participantUserId == memberUserId)
                        .fold<int>(
                            0, (sum, payment) => sum + payment.amountCents) ??
                    paidFromCents,
              );
              if (legacyRows != null) {
                return _buildBreakdownSections(
                  context,
                  scheme,
                  legacyRows,
                );
              }

              if (legacyTransactionsAsync.isLoading ||
                  legacySplitsAsync.isLoading ||
                  legacyPaymentsAsync.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l10n.errorLoadingData,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.mutedForeground,
                  ),
                ),
              );
            },
            data: (rows) {
              if (kDebugMode) {
                final youOweRows = rows
                    .where((row) => row.direction == _Direction.youOwe)
                    .toList();
                final theyOweRows = rows
                    .where((row) => row.direction == _Direction.theyOweYou)
                    .toList();
                final breakdownNet = youOweRows.fold<int>(
                      0,
                      (sum, row) => sum + row.remainingAmountCents,
                    ) -
                    theyOweRows.fold<int>(
                      0,
                      (sum, row) => sum + row.remainingAmountCents,
                    );
                if (breakdownNet != netCents) {
                  debugPrint(
                    '[SettlementBreakdownPage] household=$householdId member=$memberUserId canonicalNet=$netCents breakdownNet=$breakdownNet rows=${rows.length}',
                  );
                }
              }

              return _buildBreakdownSections(
                context,
                scheme,
                rows,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSections(
    BuildContext context,
    ColorScheme scheme,
    List<_BreakdownRowData> rows,
  ) {
    final youOweRows =
        rows.where((row) => row.direction == _Direction.youOwe).toList();
    final theyOweRows =
        rows.where((row) => row.direction == _Direction.theyOweYou).toList();
    final adjustmentCents = calculateSettlementBreakdownAdjustmentCents(
      fallbackNetCents: netCents,
      rows: rows,
    );
    final hasPositiveAdjustment = adjustmentCents > 0;
    final hasNegativeAdjustment = adjustmentCents < 0;

    return Column(
      children: [
        if (youOweRows.isNotEmpty)
          _BreakdownSection(
            title: '${context.l10n.youOwe} $memberDisplayName',
            currencyCode: currencyCode,
            rows: youOweRows,
            emptyLabel: context.l10n.noSplitTransactionsFound,
          ),
        if (youOweRows.isNotEmpty && theyOweRows.isNotEmpty)
          const SizedBox(height: 16),
        if (theyOweRows.isNotEmpty)
          _BreakdownSection(
            title: '$memberDisplayName ${context.l10n.owesYou}',
            currencyCode: currencyCode,
            rows: theyOweRows,
            emptyLabel: context.l10n.noSplitTransactionsFound,
          ),
        if ((youOweRows.isNotEmpty || theyOweRows.isNotEmpty) &&
            (hasPositiveAdjustment || hasNegativeAdjustment))
          const SizedBox(height: 16),
        if (hasPositiveAdjustment)
          _AdjustmentSection(
            title: '${context.l10n.youOwe} ${context.l10n.adjustment}',
            currencyCode: currencyCode,
            amountCents: adjustmentCents,
            description: context.l10n.settlement,
          ),
        if (hasNegativeAdjustment)
          _AdjustmentSection(
            title: '${context.l10n.adjustment} ${context.l10n.owesYou}',
            currencyCode: currencyCode,
            amountCents: adjustmentCents.abs(),
            description: context.l10n.settlement,
          ),
        if (youOweRows.isEmpty && theyOweRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              context.l10n.noSplitTransactionsFound,
              style: TextStyle(
                fontSize: 13,
                color: scheme.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }

  List<_BreakdownRowData>? _buildLegacyRows({
    required List<ExpenseEntry>? transactions,
    required List<ExpenseSplitGroup>? splits,
    required int paidToCents,
    required int paidFromCents,
  }) {
    if ((transactions == null || transactions.isEmpty) &&
        (splits == null || splits.isEmpty)) {
      return null;
    }

    final legacy = computeSettlementBreakdownData(
      currentUserId: currentUserId,
      memberUserId: memberUserId,
      currencyCode: currencyCode,
      transactions: transactions ?? const <ExpenseEntry>[],
      splits: splits ?? const <ExpenseSplitGroup>[],
      paidToCents: paidToCents,
      paidFromCents: paidFromCents,
    );

    return legacy.rows
        .map(
          (row) => SettlementBreakdownRowV2(
            direction: row.direction == SettlementBreakdownDirection.youOwe
                ? SettlementBreakdownDirectionV2.youOwe
                : SettlementBreakdownDirectionV2.theyOweYou,
            expenseId: row.transaction.id,
            splitGroupId: row.transaction.splitGroupId ?? '',
            splitLineId: row.transaction.id,
            expenseDate: row.transaction.date,
            expenseDescription: row.transaction.rawText,
            expenseCategory: row.transaction.category,
            expenseRawText: row.transaction.rawText,
            expenseType: row.transaction.type,
            totalAmountCents: row.transaction.amountCents.abs(),
            remainingAmountCents: row.splitAmountCents,
          ),
        )
        .toList();
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
    final netAmount = formatCurrency(netCents.abs() / 100.0, currencyCode);
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

class _BreakdownSection extends StatelessWidget {
  final String title;
  final String currencyCode;
  final List<_BreakdownRowData> rows;
  final String emptyLabel;

  const _BreakdownSection({
    required this.title,
    required this.currencyCode,
    required this.rows,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalCents =
        rows.fold<int>(0, (sum, row) => sum + row.remainingAmountCents);

    return Container(
      decoration: BoxDecoration(
        color: scheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.homeCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                  formatCurrency(totalCents / 100.0, currencyCode),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                emptyLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.mutedForeground,
                ),
              ),
            )
          else
            ...rows.map((row) {
              final isIncome =
                  (row.expenseType ?? 'expense').toLowerCase() == 'income';
              final isAdjustment = row.isAdjustment;
              final totalAmount = formatCurrency(
                row.totalAmountCents.abs() / 100.0,
                currencyCode,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  isIncome: isIncome,
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
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AdjustmentSection extends StatelessWidget {
  final String title;
  final String currencyCode;
  final int amountCents;
  final String description;

  const _AdjustmentSection({
    required this.title,
    required this.currencyCode,
    required this.amountCents,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                  formatCurrency(amountCents / 100.0, currencyCode),
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
