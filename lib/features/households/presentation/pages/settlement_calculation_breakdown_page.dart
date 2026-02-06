import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

class SettlementCalculationBreakdownPage extends StatelessWidget {
  final String currentUserId;
  final String memberUserId;
  final String memberDisplayName;
  final String currencyCode;
  final List<ExpenseEntry> transactions;
  final List<ExpenseSplitGroup> splits;
  final int paidToCents;
  final int paidFromCents;
  final int finalSettleAmountCents;

  const SettlementCalculationBreakdownPage({
    super.key,
    required this.currentUserId,
    required this.memberUserId,
    required this.memberDisplayName,
    required this.currencyCode,
    required this.transactions,
    required this.splits,
    required this.paidToCents,
    required this.paidFromCents,
    required this.finalSettleAmountCents,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transactionById = {for (final t in transactions) t.id: t};
    final rows = _buildRows(transactionById);

    final youOweRows = rows
        .where((row) => row.direction == _Direction.youOwe)
        .toList()
      ..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
    final theyOweRows = rows
        .where((row) => row.direction == _Direction.theyOweYou)
        .toList()
      ..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));

    final youOweTotal =
        youOweRows.fold<int>(0, (sum, row) => sum + row.splitAmountCents);
    final theyOweTotal =
        theyOweRows.fold<int>(0, (sum, row) => sum + row.splitAmountCents);

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
            memberDisplayName: memberDisplayName,
            youOweTotal: youOweTotal,
            theyOweTotal: theyOweTotal,
            paidToCents: paidToCents,
            paidFromCents: paidFromCents,
            finalSettleAmountCents: finalSettleAmountCents,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: 18),
          _BreakdownSection(
            title: '${context.l10n.youOwe} $memberDisplayName',
            currencyCode: currencyCode,
            rows: youOweRows,
            emptyLabel: context.l10n.noSplitTransactionsFound,
          ),
          const SizedBox(height: 16),
          _BreakdownSection(
            title: '$memberDisplayName ${context.l10n.owesYou}',
            currencyCode: currencyCode,
            rows: theyOweRows,
            emptyLabel: context.l10n.noSplitTransactionsFound,
          ),
          const SizedBox(height: 16),
          _BreakdownSection(
            title: '$memberDisplayName ${context.l10n.owesYou}',
            currencyCode: currencyCode,
            rows: theyOweRows,
            emptyLabel: context.l10n.noSplitTransactionsFound,
          ),
        ],
      ),
    );
  }

  List<_BreakdownRowData> _buildRows(
      Map<String, ExpenseEntry> transactionById) {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final output = <_BreakdownRowData>[];

    for (final group in splits) {
      if (group.currency.trim().toUpperCase() != normalizedCurrency) continue;
      final lines = group.splitLines ?? const <ExpenseSplitLine>[];
      if (lines.isEmpty) continue;

      final transaction = transactionById[group.expenseId];
      if (transaction == null) continue;
      if ((transaction.type ?? 'expense').toLowerCase() == 'income') continue;

      for (final line in lines) {
        if (line.isSettled) continue;
        final splitAmountCents = (line.amountCents ?? 0).abs();
        if (splitAmountCents <= 0) continue;

        if (group.payerUserId == memberUserId && line.userId == currentUserId) {
          output.add(_BreakdownRowData(
            direction: _Direction.youOwe,
            splitAmountCents: splitAmountCents,
            transaction: transaction,
          ));
        }

        if (group.payerUserId == currentUserId && line.userId == memberUserId) {
          output.add(_BreakdownRowData(
            direction: _Direction.theyOweYou,
            splitAmountCents: splitAmountCents,
            transaction: transaction,
          ));
        }
      }
    }

    return output;
  }
}

enum _Direction { youOwe, theyOweYou }

class _BreakdownRowData {
  final _Direction direction;
  final int splitAmountCents;
  final ExpenseEntry transaction;

  const _BreakdownRowData({
    required this.direction,
    required this.splitAmountCents,
    required this.transaction,
  });
}

class _SummaryCard extends StatelessWidget {
  final String memberDisplayName;
  final int youOweTotal;
  final int theyOweTotal;
  final int paidToCents;
  final int paidFromCents;
  final int finalSettleAmountCents;
  final String currencyCode;

  const _SummaryCard({
    required this.memberDisplayName,
    required this.youOweTotal,
    required this.theyOweTotal,
    required this.paidToCents,
    required this.paidFromCents,
    required this.finalSettleAmountCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final netBeforeSettlements = youOweTotal - theyOweTotal;
    final settlementAdjustment = paidFromCents - paidToCents;
    final netAfterSettlements = netBeforeSettlements + settlementAdjustment;
    final netAmount =
        formatCurrency(netAfterSettlements.abs() / 100.0, currencyCode);
    final settlementSign = settlementAdjustment >= 0 ? '+' : '-';
    final netLabel = netAfterSettlements > 0
        ? '${context.l10n.youOwe} $memberDisplayName'
        : netAfterSettlements < 0
            ? '$memberDisplayName ${context.l10n.owesYou}'
            : context.l10n.nothingToSettle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.homeCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.netSplitPosition,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            netAmount,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: scheme.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            netLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.howThisIsCalculated,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatCurrency(youOweTotal / 100.0, currencyCode)} - ${formatCurrency(theyOweTotal / 100.0, currencyCode)} $settlementSign ${formatCurrency(settlementAdjustment.abs() / 100.0, currencyCode)} ${context.l10n.settlements} = ${formatCurrency(finalSettleAmountCents / 100.0, currencyCode)}',
            style: TextStyle(
              fontSize: 12,
              color: scheme.mutedForeground,
            ),
          ),
        ],
      ),
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
        rows.fold<int>(0, (sum, row) => sum + row.splitAmountCents);

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
              final transaction = row.transaction;
              final totalAmount = formatCurrency(
                transaction.amountCents.abs() / 100.0,
                transaction.currency ?? currencyCode,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TransactionListTile(
                  category: transaction.category ?? context.l10n.other,
                  title: transaction.rawText ??
                      transaction.category ??
                      context.l10n.expense,
                  description: transaction.rawText,
                  date: transaction.date,
                  amount: row.splitAmountCents / 100.0,
                  currency: currencyCode,
                  isIncome: false,
                  onTap: () => showUnifiedTransactionSheet(
                    context,
                    existingExpense: transaction,
                  ),
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
