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
  final summaryEntries = entries
      .where((entry) => !_isWalletTransferFeedEntry(entry))
      .toList(growable: false);
  if (summaryEntries.isEmpty) return const TransactionsFeedSummary.empty();

  final normalizedTarget = targetCurrency.trim().toUpperCase();
  final currencies = <String>{};
  final categoryTotals = <String, TransactionsFeedCategorySummary>{};
  final yearlyTotals = <DateTime, double>{};
  final periodTotals = <DateTime, double>{};
  var expenseTotal = 0.0;
  var incomeTotal = 0.0;

  for (final entry in summaryEntries) {
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
    transactionCount: summaryEntries.length,
    expenseTotal: expenseTotal,
    incomeTotal: incomeTotal,
    hasMultipleCurrencies: currencies.length > 1,
    categorySummaries: categoryTotals.values.toList()
      ..sort((left, right) => right.amount.compareTo(left.amount)),
    yearlyPeriodTotals: yearlyTotals,
    periodTotals: periodTotals,
  );
}

bool _isWalletTransferFeedEntry(ExpenseEntry entry) =>
    entry.id.startsWith('transfer:');

TransactionsFeedSummary? summarizeTransactionRollupsInCurrency(
  TransactionsFeedSummary summary, {
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  if (summary.currencyTypeTotals.isEmpty) {
    return null;
  }

  final normalizedTarget = targetCurrency.trim().toUpperCase();
  final categoryTotals = <String, TransactionsFeedCategorySummary>{};
  final yearlyTotals = <DateTime, double>{};
  final periodTotals = <DateTime, double>{};
  var expenseTotal = 0.0;
  var incomeTotal = 0.0;

  for (final total in summary.currencyTypeTotals) {
    expenseTotal += rates.convert(
      total.expenseTotal,
      total.currency,
      normalizedTarget,
    );
    incomeTotal += rates.convert(
      total.incomeTotal,
      total.currency,
      normalizedTarget,
    );
  }

  for (final category in summary.currencyCategorySummaries) {
    final converted = rates.convert(
      category.amount,
      category.currency,
      normalizedTarget,
    );
    final current = categoryTotals[category.category] ??
        TransactionsFeedCategorySummary(
          category: category.category,
          amount: 0,
          transactionCount: 0,
        );
    categoryTotals[category.category] = current.copyWith(
      amount: current.amount + converted,
      transactionCount: current.transactionCount + category.transactionCount,
    );
  }

  for (final bucket in summary.currencyYearlyPeriodTotals) {
    yearlyTotals[bucket.bucketStart] = (yearlyTotals[bucket.bucketStart] ?? 0) +
        rates.convert(
          bucket.amount,
          bucket.currency,
          normalizedTarget,
        );
  }

  final sourcePeriodTotals = summary.currencyPeriodTotals.isEmpty
      ? summary.currencyYearlyPeriodTotals
      : summary.currencyPeriodTotals;
  for (final bucket in sourcePeriodTotals) {
    periodTotals[bucket.bucketStart] = (periodTotals[bucket.bucketStart] ?? 0) +
        rates.convert(
          bucket.amount,
          bucket.currency,
          normalizedTarget,
        );
  }

  return TransactionsFeedSummary(
    transactionCount: summary.transactionCount,
    expenseTotal: expenseTotal,
    incomeTotal: incomeTotal,
    hasMultipleCurrencies: summary.hasMultipleCurrencies,
    categorySummaries: categoryTotals.values.toList(growable: false)
      ..sort((left, right) => right.amount.compareTo(left.amount)),
    yearlyPeriodTotals: yearlyTotals,
    periodTotals: periodTotals,
    currencyCategorySummaries: summary.currencyCategorySummaries,
    currencyYearlyPeriodTotals: summary.currencyYearlyPeriodTotals,
    currencyPeriodTotals: summary.currencyPeriodTotals,
    currencyTypeTotals: summary.currencyTypeTotals,
  );
}

TransactionsFeedSummary addConvertedExpensesToSummary(
  TransactionsFeedSummary summary,
  List<ExpenseEntry> entries, {
  required String targetCurrency,
  required CurrencyRateTable rates,
  String intervalGranularity = 'yearly',
}) {
  if (entries.isEmpty) {
    return summary;
  }

  return combineTransactionSummaries(
    summary,
    summarizeTransactionsInCurrency(
      entries,
      targetCurrency: targetCurrency,
      rates: rates,
      intervalGranularity: intervalGranularity,
    ),
  );
}

TransactionsFeedSummary combineTransactionSummaries(
  TransactionsFeedSummary base,
  TransactionsFeedSummary extra,
) {
  if (extra.transactionCount == 0) {
    return base;
  }
  if (base.transactionCount == 0 &&
      base.expenseTotal == 0 &&
      base.incomeTotal == 0 &&
      base.categorySummaries.isEmpty &&
      base.yearlyPeriodTotals.isEmpty &&
      base.periodTotals.isEmpty) {
    return extra;
  }

  final categoryTotals = <String, TransactionsFeedCategorySummary>{};
  for (final summary in [
    ...base.categorySummaries,
    ...extra.categorySummaries
  ]) {
    final category = canonicalizeCategoryKey(summary.category);
    final current = categoryTotals[category] ??
        TransactionsFeedCategorySummary(
          category: category,
          amount: 0,
          transactionCount: 0,
        );
    categoryTotals[category] = current.copyWith(
      amount: current.amount + summary.amount,
      transactionCount: current.transactionCount + summary.transactionCount,
    );
  }

  return TransactionsFeedSummary(
    transactionCount: base.transactionCount + extra.transactionCount,
    expenseTotal: base.expenseTotal + extra.expenseTotal,
    incomeTotal: base.incomeTotal + extra.incomeTotal,
    hasMultipleCurrencies:
        base.hasMultipleCurrencies || extra.hasMultipleCurrencies,
    categorySummaries: categoryTotals.values.toList(growable: false)
      ..sort((left, right) => right.amount.compareTo(left.amount)),
    yearlyPeriodTotals: _combinePeriodTotals(
      base.yearlyPeriodTotals,
      extra.yearlyPeriodTotals,
    ),
    periodTotals: _combinePeriodTotals(
      base.periodTotals,
      extra.periodTotals,
    ),
    currencyCategorySummaries: base.currencyCategorySummaries,
    currencyYearlyPeriodTotals: base.currencyYearlyPeriodTotals,
    currencyPeriodTotals: base.currencyPeriodTotals,
    currencyTypeTotals: base.currencyTypeTotals,
  );
}

Map<DateTime, double> _combinePeriodTotals(
  Map<DateTime, double> base,
  Map<DateTime, double> extra,
) {
  final combined = Map<DateTime, double>.from(base);
  for (final entry in extra.entries) {
    combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
  }
  return combined;
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
