import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

enum SettlementBreakdownDirection { youOwe, theyOweYou }

class SettlementBreakdownRow {
  final SettlementBreakdownDirection direction;
  final int splitAmountCents;
  final ExpenseEntry transaction;

  const SettlementBreakdownRow({
    required this.direction,
    required this.splitAmountCents,
    required this.transaction,
  });
}

class SettlementBreakdownData {
  final List<SettlementBreakdownRow> rows;
  final int rawYouOweTotalCents;
  final int rawTheyOweTotalCents;
  final int paidToCents;
  final int paidFromCents;
  final int missingTransactionCount;

  const SettlementBreakdownData({
    required this.rows,
    required this.rawYouOweTotalCents,
    required this.rawTheyOweTotalCents,
    required this.paidToCents,
    required this.paidFromCents,
    required this.missingTransactionCount,
  });

  int get remainingYouOweTotalCents {
    return rows
        .where((row) => row.direction == SettlementBreakdownDirection.youOwe)
        .fold<int>(0, (sum, row) => sum + row.splitAmountCents);
  }

  int get remainingTheyOweTotalCents {
    return rows
        .where(
          (row) => row.direction == SettlementBreakdownDirection.theyOweYou,
        )
        .fold<int>(0, (sum, row) => sum + row.splitAmountCents);
  }

  int get netCents {
    return (rawYouOweTotalCents - rawTheyOweTotalCents) -
        (paidToCents - paidFromCents);
  }
}

List<SettlementBreakdownRow> computeSettlementBreakdownRows({
  required String currentUserId,
  required String memberUserId,
  required String currencyCode,
  required List<ExpenseEntry> transactions,
  required List<ExpenseSplitGroup> splits,
  required int paidToCents,
  required int paidFromCents,
}) {
  return computeSettlementBreakdownData(
    currentUserId: currentUserId,
    memberUserId: memberUserId,
    currencyCode: currencyCode,
    transactions: transactions,
    splits: splits,
    paidToCents: paidToCents,
    paidFromCents: paidFromCents,
  ).rows;
}

SettlementBreakdownData computeSettlementBreakdownData({
  required String currentUserId,
  required String memberUserId,
  required String currencyCode,
  required List<ExpenseEntry> transactions,
  required List<ExpenseSplitGroup> splits,
  required int paidToCents,
  required int paidFromCents,
}) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  final transactionById = {
    for (final transaction in transactions) transaction.id: transaction,
  };
  final youOweRows = <_PendingBreakdownRow>[];
  final theyOweRows = <_PendingBreakdownRow>[];
  var missingTransactionCount = 0;

  for (final group in splits) {
    if (group.currency.trim().toUpperCase() != normalizedCurrency) {
      continue;
    }

    final transaction = transactionById[group.expenseId] ??
        _buildFallbackTransaction(group, normalizedCurrency);
    if (!transactionById.containsKey(group.expenseId)) {
      missingTransactionCount += 1;
      if (kDebugMode) {
        debugPrint(
          '[SettlementBreakdown] Missing expense metadata for split group ${group.id} expense=${group.expenseId}',
        );
      }
    }

    final lines = group.splitLines ?? const <ExpenseSplitLine>[];
    for (final line in lines) {
      if (line.isSettled) {
        continue;
      }

      final splitAmountCents = (line.amountCents ?? 0).abs();
      if (splitAmountCents <= 0) {
        continue;
      }

      if (group.payerUserId == memberUserId && line.userId == currentUserId) {
        youOweRows.add(
          _PendingBreakdownRow(
            splitAmountCents: splitAmountCents,
            transaction: transaction,
          ),
        );
      }

      if (group.payerUserId == currentUserId && line.userId == memberUserId) {
        theyOweRows.add(
          _PendingBreakdownRow(
            splitAmountCents: splitAmountCents,
            transaction: transaction,
          ),
        );
      }
    }
  }

  final normalizedPaidToCents = paidToCents.abs();
  final normalizedPaidFromCents = paidFromCents.abs();
  final rawYouOweTotalCents =
      youOweRows.fold<int>(0, (sum, row) => sum + row.splitAmountCents);
  final rawTheyOweTotalCents =
      theyOweRows.fold<int>(0, (sum, row) => sum + row.splitAmountCents);

  final remainingRows = <SettlementBreakdownRow>[
    ..._applySettlements(
      rows: youOweRows,
      settledCents: normalizedPaidToCents,
      direction: SettlementBreakdownDirection.youOwe,
    ),
    ..._applySettlements(
      rows: theyOweRows,
      settledCents: normalizedPaidFromCents,
      direction: SettlementBreakdownDirection.theyOweYou,
    ),
  ];

  remainingRows.sort(_compareVisibleRows);

  return SettlementBreakdownData(
    rows: remainingRows,
    rawYouOweTotalCents: rawYouOweTotalCents,
    rawTheyOweTotalCents: rawTheyOweTotalCents,
    paidToCents: normalizedPaidToCents,
    paidFromCents: normalizedPaidFromCents,
    missingTransactionCount: missingTransactionCount,
  );
}

ExpenseEntry _buildFallbackTransaction(
  ExpenseSplitGroup group,
  String normalizedCurrency,
) {
  return ExpenseEntry(
    id: group.expenseId,
    householdId: group.householdId,
    date: group.createdAt,
    amountCents: group.totalAmountCents.abs(),
    currency: normalizedCurrency,
    createdAt: group.createdAt,
    updatedAt: group.updatedAt,
    rawText: group.description,
    splitGroupId: group.id,
    type: null,
  );
}

List<SettlementBreakdownRow> _applySettlements({
  required List<_PendingBreakdownRow> rows,
  required int settledCents,
  required SettlementBreakdownDirection direction,
}) {
  final orderedRows = [...rows]..sort(_comparePendingRows);
  var remainingSettledCents = settledCents.abs();
  final output = <SettlementBreakdownRow>[];

  for (final row in orderedRows) {
    final settledAgainstRow =
        math.min(row.splitAmountCents, remainingSettledCents);
    remainingSettledCents -= settledAgainstRow;

    final remainingAmountCents = row.splitAmountCents - settledAgainstRow;
    if (remainingAmountCents <= 0) {
      continue;
    }

    output.add(
      SettlementBreakdownRow(
        direction: direction,
        splitAmountCents: remainingAmountCents,
        transaction: row.transaction,
      ),
    );
  }

  return output;
}

int _comparePendingRows(_PendingBreakdownRow a, _PendingBreakdownRow b) {
  final dateComparison = a.transaction.date.compareTo(b.transaction.date);
  if (dateComparison != 0) {
    return dateComparison;
  }

  final createdAtComparison =
      a.transaction.createdAt.compareTo(b.transaction.createdAt);
  if (createdAtComparison != 0) {
    return createdAtComparison;
  }

  return a.transaction.id.compareTo(b.transaction.id);
}

int _compareVisibleRows(SettlementBreakdownRow a, SettlementBreakdownRow b) {
  final dateComparison = b.transaction.date.compareTo(a.transaction.date);
  if (dateComparison != 0) {
    return dateComparison;
  }

  final createdAtComparison =
      b.transaction.createdAt.compareTo(a.transaction.createdAt);
  if (createdAtComparison != 0) {
    return createdAtComparison;
  }

  return b.transaction.id.compareTo(a.transaction.id);
}

class _PendingBreakdownRow {
  final int splitAmountCents;
  final ExpenseEntry transaction;

  const _PendingBreakdownRow({
    required this.splitAmountCents,
    required this.transaction,
  });
}
