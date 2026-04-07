import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transaction_binding.dart';

class WalletSnapshot {
  const WalletSnapshot({
    required this.totalIncomeCents,
    required this.totalSpentCents,
    required this.netWorthCents,
    required this.walletBalances,
  });

  final int totalIncomeCents;
  final int totalSpentCents;
  final int netWorthCents;
  final Map<String, int> walletBalances;
}

List<DateTime> buildWalletAvailableMonths({
  required DateTime now,
  required List<ExpenseEntry> transactions,
}) {
  final currentMonth = DateTime(now.year, now.month);
  if (transactions.isEmpty) {
    return <DateTime>[currentMonth];
  }

  var earliest = currentMonth;
  for (final tx in transactions) {
    final txMonth = DateTime(tx.date.year, tx.date.month);
    if (txMonth.isBefore(earliest)) {
      earliest = txMonth;
    }
  }

  final months = <DateTime>[];
  var cursor = currentMonth;
  while (!cursor.isBefore(earliest)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month - 1);
  }
  return months;
}

List<ExpenseEntry> filterWalletTransactions({
  required List<ExpenseEntry> allExpenses,
  required HouseholdScope scope,
  required String selectedCurrency,
}) {
  return allExpenses.where((expense) {
    return _isInActiveScope(expense, scope) &&
        !expense.isRecurring &&
        _isInSelectedCurrency(expense, selectedCurrency);
  }).toList(growable: false);
}

WalletSnapshot buildWalletSnapshot({
  required List<WalletEntity> wallets,
  required List<ExpenseEntry> transactions,
  required DateTime endExclusive,
}) {
  final filteredTransactions = transactions.where((expense) {
    return expense.date.isBefore(endExclusive);
  }).toList(growable: false);

  var totalIncomeCents = 0;
  var totalSpentCents = 0;
  for (final expense in filteredTransactions) {
    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    if (isIncome) {
      totalIncomeCents += expense.amountCents.abs();
    } else {
      totalSpentCents += expense.amountCents.abs();
    }
  }

  final walletBalances = <String, int>{
    for (final wallet in wallets) wallet.id: wallet.openingBalanceCents,
  };

  for (final tx in filteredTransactions) {
    final resolvedWalletId = resolveTransactionWalletId(
      transaction: tx,
      wallets: wallets,
    );
    if (resolvedWalletId == null ||
        !walletBalances.containsKey(resolvedWalletId)) {
      continue;
    }

    final amountCents = tx.amountCents.abs();
    final isIncome = (tx.type ?? 'expense').toLowerCase() == 'income';
    final current = walletBalances[resolvedWalletId] ?? 0;
    walletBalances[resolvedWalletId] =
        isIncome ? current + amountCents : current - amountCents;
  }

  var netWorthCents = 0;
  for (final value in walletBalances.values) {
    netWorthCents += value;
  }

  return WalletSnapshot(
    totalIncomeCents: totalIncomeCents,
    totalSpentCents: totalSpentCents,
    netWorthCents: netWorthCents,
    walletBalances: walletBalances,
  );
}

bool _isInSelectedCurrency(ExpenseEntry expense, String currencyCode) {
  final normalized = expense.currency?.trim().toUpperCase();
  return normalized == currencyCode;
}

bool _isInActiveScope(ExpenseEntry expense, HouseholdScope scope) {
  final householdId = expense.householdId;
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return householdId == null || householdId.isEmpty;
    case ActiveWalletType.portfolio:
      final selected = scope.activeAccountHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
    case ActiveWalletType.household:
      final selected = scope.selectedHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
  }
}
