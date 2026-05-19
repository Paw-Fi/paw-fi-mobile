import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';

TransactionsFeedSummary summarizeTransactionsInCurrency(
  List<ExpenseEntry> entries, {
  required String targetCurrency,
  required CurrencyRateTable rates,
  String intervalGranularity = 'yearly',
}) {
  if (entries.isEmpty) return const TransactionsFeedSummary.empty();

  final normalizedTarget = targetCurrency.trim().toUpperCase();
  final currencies = <String>{};
  final categoryTotals = <String, TransactionsFeedCategorySummary>{};
  final yearlyTotals = <DateTime, double>{};
  final periodTotals = <DateTime, double>{};
  var expenseTotal = 0.0;
  var incomeTotal = 0.0;

  for (final entry in entries) {
    final sourceCurrency =
        (entry.currency?.trim().toUpperCase().isNotEmpty == true)
            ? entry.currency!.trim().toUpperCase()
            : normalizedTarget;
    currencies.add(sourceCurrency);

    final converted = rates.convert(
      entry.amount.abs(),
      sourceCurrency,
      normalizedTarget,
    );
    final isIncome = (entry.type ?? 'expense').toLowerCase() == 'income';
    if (isIncome) {
      incomeTotal += converted;
      continue;
    }

    expenseTotal += converted;
    final category = canonicalizeCategoryKey(entry.category);
    final current = categoryTotals[category] ??
        TransactionsFeedCategorySummary(
          category: category,
          amount: 0,
          transactionCount: 0,
        );
    categoryTotals[category] = current.copyWith(
      amount: current.amount + converted,
      transactionCount: current.transactionCount + 1,
    );

    final yearlyBucket = DateTime(entry.date.year);
    yearlyTotals[yearlyBucket] = (yearlyTotals[yearlyBucket] ?? 0) + converted;
    final periodBucket = _periodBucket(entry.date, intervalGranularity);
    periodTotals[periodBucket] = (periodTotals[periodBucket] ?? 0) + converted;
  }

  return TransactionsFeedSummary(
    transactionCount: entries.length,
    expenseTotal: expenseTotal,
    incomeTotal: incomeTotal,
    hasMultipleCurrencies: currencies.length > 1,
    categorySummaries: categoryTotals.values.toList()
      ..sort((left, right) => right.amount.compareTo(left.amount)),
    yearlyPeriodTotals: yearlyTotals,
    periodTotals: periodTotals,
  );
}

List<ExpenseEntry> convertTransactionsToCurrency(
  List<ExpenseEntry> entries, {
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final normalizedTarget = targetCurrency.trim().toUpperCase();
  return entries.map((entry) {
    final sourceCurrency =
        (entry.currency?.trim().toUpperCase().isNotEmpty == true)
            ? entry.currency!.trim().toUpperCase()
            : normalizedTarget;
    return entry.copyWith(
      amountCents: convertAmountCentsToCurrency(
        entry.amountCents,
        fromCurrency: sourceCurrency,
        targetCurrency: normalizedTarget,
        rates: rates,
      ),
      currency: normalizedTarget,
    );
  }).toList(growable: false);
}

int convertAmountCentsToCurrency(
  int amountCents, {
  required String fromCurrency,
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final sign = amountCents < 0 ? -1 : 1;
  final converted = rates.convert(
    amountCents.abs() / 100.0,
    fromCurrency,
    targetCurrency,
  );
  return (converted * 100).round() * sign;
}

DateTime _periodBucket(DateTime date, String intervalGranularity) {
  switch (intervalGranularity.trim().toLowerCase()) {
    case 'daily':
      return DateTime(date.year, date.month, date.day);
    case 'weekly':
      return DateTime(date.year, date.month, date.day).subtract(Duration(
          days: DateTime(date.year, date.month, date.day).weekday - 1));
    case 'monthly':
      return DateTime(date.year, date.month);
    case 'yearly':
    default:
      return DateTime(date.year);
  }
}
