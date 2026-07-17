import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/financial_period.dart';
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

int retargetWalletBalanceForOpeningChange({
  required int previousOpeningBalanceCents,
  required int nextOpeningBalanceCents,
  required int currentBalanceCents,
}) {
  final transactionDeltaCents =
      currentBalanceCents - previousOpeningBalanceCents;
  return nextOpeningBalanceCents + transactionDeltaCents;
}

List<DateTime> buildWalletAvailableMonths({
  required DateTime now,
  required List<ExpenseEntry> transactions,
  int financialMonthStartDay = 1,
}) {
  final currentMonth = financialCycleStartForDate(
    now,
    startDay: financialMonthStartDay,
  );
  if (transactions.isEmpty) {
    return <DateTime>[currentMonth];
  }

  var earliest = currentMonth;
  for (final tx in transactions) {
    final txMonth = financialCycleStartForDate(
      tx.date,
      startDay: financialMonthStartDay,
    );
    if (txMonth.isBefore(earliest)) {
      earliest = txMonth;
    }
  }

  final months = <DateTime>[];
  var cursor = currentMonth;
  while (!cursor.isBefore(earliest)) {
    months.add(cursor);
    cursor = previousFinancialCycleStart(
      cursor,
      startDay: financialMonthStartDay,
    );
  }
  return months;
}

List<ExpenseEntry> filterWalletTransactions({
  required List<ExpenseEntry> allExpenses,
  required HouseholdScope scope,
  required String selectedCurrency,
  List<String>? selectedCurrencies,
}) {
  final currencySet = selectedCurrencies
      ?.map((currency) => currency.trim().toUpperCase())
      .where((currency) => currency.isNotEmpty)
      .toSet();
  return allExpenses.where((expense) {
    return _isInActiveScope(expense, scope) &&
        !expense.isRecurring &&
        (currencySet != null && currencySet.isNotEmpty
            ? _isInSelectedCurrencies(expense, currencySet)
            : _isInSelectedCurrency(expense, selectedCurrency));
  }).toList(growable: false);
}

WalletSnapshot buildWalletSnapshot({
  required List<WalletEntity> wallets,
  required List<ExpenseEntry> transactions,
  required DateTime endExclusive,
  DateTime? periodStart,
  DateTime? periodEndExclusive,
  String? targetCurrency,
  CurrencyRateTable? rates,
}) {
  final normalizedTargetCurrency = targetCurrency?.trim().toUpperCase();
  final rateTable = rates;
  final shouldConvert = normalizedTargetCurrency != null &&
      normalizedTargetCurrency.isNotEmpty &&
      rateTable != null;
  int convertCents(int amountCents, String? fromCurrency) {
    if (!shouldConvert) {
      return amountCents;
    }
    final normalizedFromCurrency = fromCurrency?.trim().toUpperCase();
    if (normalizedFromCurrency == null || normalizedFromCurrency.isEmpty) {
      return amountCents;
    }
    final sign = amountCents < 0 ? -1 : 1;
    final converted = rateTable.convert(
      amountCents.abs() / 100.0,
      normalizedFromCurrency,
      normalizedTargetCurrency,
    );
    return (converted * 100).round() * sign;
  }

  final balanceTransactions = transactions.where((expense) {
    return expense.date.isBefore(endExclusive);
  }).toList(growable: false);
  final totalPeriodStart = periodStart;
  final totalPeriodEndExclusive = periodEndExclusive ?? endExclusive;
  final periodTransactions = balanceTransactions.where((expense) {
    if (expense.category?.trim().toLowerCase() == 'transfers') {
      return false;
    }
    if (totalPeriodStart != null && expense.date.isBefore(totalPeriodStart)) {
      return false;
    }
    return expense.date.isBefore(totalPeriodEndExclusive);
  }).toList(growable: false);
  final walletsById = <String, WalletEntity>{
    for (final wallet in wallets) wallet.id: wallet,
  };

  var totalIncomeCents = 0;
  var totalSpentCents = 0;
  for (final expense in periodTransactions) {
    final resolvedWalletId = resolveTransactionWalletId(
      transaction: expense,
      wallets: wallets,
    );
    final sourceCurrency =
        expense.currency ?? walletsById[resolvedWalletId]?.currency;
    final convertedAmountCents = convertCents(
      expense.amountCents.abs(),
      sourceCurrency,
    );
    if (expense.countsTowardIncome) {
      totalIncomeCents += convertedAmountCents;
    } else if (expense.effectiveSpendingMultiplier != 0) {
      totalSpentCents +=
          convertedAmountCents * expense.effectiveSpendingMultiplier;
    }
  }

  final walletBalances = <String, int>{
    for (final wallet in wallets)
      wallet.id: convertCents(wallet.openingBalanceCents, wallet.currency),
  };

  for (final tx in balanceTransactions) {
    final resolvedWalletId = resolveTransactionWalletId(
      transaction: tx,
      wallets: wallets,
    );
    if (resolvedWalletId == null ||
        !walletBalances.containsKey(resolvedWalletId)) {
      continue;
    }

    final sourceCurrency =
        tx.currency ?? walletsById[resolvedWalletId]?.currency;
    final amountCents = convertCents(tx.amountCents.abs(), sourceCurrency);
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

bool _isInSelectedCurrencies(ExpenseEntry expense, Set<String> currencies) {
  final normalized = expense.currency?.trim().toUpperCase();
  return normalized == null ||
      normalized.isEmpty ||
      currencies.contains(normalized);
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
