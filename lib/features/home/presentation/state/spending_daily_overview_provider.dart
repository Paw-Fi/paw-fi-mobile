import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/utils/async_value_extensions.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';

import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// Recorded spend / elapsed calendar days, matching Pocket detail's daily
/// average convention. Historical periods use every day, including zero days.
double calculateDailySpendingAverage(
  List<ExpenseEntry> entries, {
  required DateTime start,
  required DateTime end,
  required DateTime now,
  String currency = 'USD',
  CurrencyRateTable? rates,
}) {
  final first = _day(start);
  final last = _day(now).isBefore(_day(end)) ? _day(now) : _day(end);
  if (last.isBefore(first)) return 0;
  final days = DateTime.utc(last.year, last.month, last.day)
          .difference(DateTime.utc(first.year, first.month, first.day))
          .inDays +
      1;
  final included = entries.where((entry) {
    final date = _day(recurringOccurrenceReportingDate(entry));
    return !entry.isRecurring &&
        !entry.id.startsWith('transfer:') &&
        !date.isBefore(first) &&
        !date.isAfter(last);
  }).toList(growable: false);
  final total = rates == null
      ? included.fold<double>(0, (sum, entry) => sum + entry.spendingEffect)
      : summarizeTransactionsInCurrency(included,
              targetCurrency: currency, rates: rates)
          .expenseTotal;
  if (!total.isFinite) throw StateError('Invalid spending total');
  return total / days;
}

class SpendingDailyOverviewQuery {
  SpendingDailyOverviewQuery(
      {required this.query,
      required DateTime now,
      int financialMonthStartDay = 1,
      String? currency})
      : now = _day(now),
        financialMonthStartDay =
            normalizeFinancialMonthStartDay(financialMonthStartDay),
        currency = currency ?? query.normalizedCurrency ?? 'USD';
  final DashboardScopeQuery query;
  final DateTime now;
  final int financialMonthStartDay;
  final String currency;

  FinancialPeriod get _previousCycle =>
      previousFinancialCycleForDate(query.startDate!,
          startDay: financialMonthStartDay);
  bool get _daily => _day(query.startDate!) == _day(query.endDate!);
  DateTime get previousStart => _daily
      ? matchingElapsedDateInPreviousFinancialCycle(query.startDate!,
          startDay: financialMonthStartDay)
      : _previousCycle.start;
  DateTime get previousEnd => _daily
      ? previousStart
      : now.isAfter(_day(query.endDate!))
          ? _previousCycle.end
          : matchingElapsedDateInPreviousFinancialCycle(now,
              startDay: financialMonthStartDay);
  DashboardScopeQuery get previousQuery => query.copyWith(
      startDate: _previousCycle.start, endDate: _previousCycle.end);

  @override
  bool operator ==(Object other) =>
      other is SpendingDailyOverviewQuery &&
      other.query == query &&
      other.now == now &&
      other.financialMonthStartDay == financialMonthStartDay &&
      other.currency == currency;
  @override
  int get hashCode => Object.hash(query, now, financialMonthStartDay, currency);
}

class SpendingDailyOverview {
  const SpendingDailyOverview(
      {required this.dailyAverage,
      required this.transactions,
      required this.previousAverage});
  final double dailyAverage;
  final List<ExpenseEntry> transactions;
  final AsyncValue<double> previousAverage;

  double? get changePercent {
    final previous = previousAverage.valueOrNull;
    if (previous == null || !previous.isFinite || previous <= 0) return null;
    final change = (dailyAverage - previous) / previous * 100;
    return change.isFinite ? change : null;
  }
}

/// Read-side adapter over the existing calendar and optimistic families. No
/// service calls: each Space/actor/currency/range keeps its original cache key.
final spendingScopedActualTransactionsProvider = Provider.autoDispose
    .family<AsyncValue<List<ExpenseEntry>>, DashboardScopeQuery>((ref, query) {
  if (ref.watch(previewModeProvider).isActive) {
    final rows =
        const PreviewDashboardDataService().calendarTransactions(query);

    return AsyncData(rows);
  }
  final source = ref.watch(dashboardCalendarTransactionsProvider(query));

  if (!source.hasValue) return source;
  final overlay = ref.watch(dashboardLocalOverlayTransactionsProvider(query));
  final resolution = ref.watch(recurringOccurrenceProjectionResolutionProvider(
    RecurringOccurrenceProjectionResolutionQuery(
        userId: query.userId,
        householdId: query.householdId,
        startDate: query.startDate!,
        endDate: query.endDate!),
  ));
  return source.whenDataWithPrevious((base) {
    final merged = mergeDashboardTransactionsWithLocalOverlay(
        base: base, localOverlay: overlay, query: query);
    final byId = <String, ExpenseEntry>{
      for (final entry in resolution.suppressionEntries)
        if (!entry.isRecurring &&
            (entry.householdId?.trim() ?? '') ==
                (query.householdId?.trim() ?? '') &&
            query.allowsCurrency(entry.currency))
          entry.id: entry,
    };
    for (final entry in merged) {
      final occurrence = byId[entry.id];
      // A legacy cached row must not erase known occurrence provenance. Keep
      // the feed/optimistic amount and currency authoritative for this ID.
      byId[entry.id] = occurrence == null
          ? entry
          : entry.copyWith(
              parentRecurringId:
                  entry.parentRecurringId ?? occurrence.parentRecurringId,
              scheduledOccurrenceDate: entry.scheduledOccurrenceDate ??
                  occurrence.scheduledOccurrenceDate,
            );
    }
    final scoped = byId.values
        .where((entry) =>
            query.householdId != null ||
            entry.userId == null ||
            entry.userId!.isEmpty ||
            entry.userId == query.userId)
        .toList();
    return List.unmodifiable(mergeActualExpensesWithProjectedRecurring(
      actualExpenses: scoped,
      recurringTransactions: const [],
      rangeStart: query.startDate!,
      rangeEnd: query.endDate!,
      selectedCurrency: query.selectedCurrency,
      selectedCurrencies: query.normalizedCurrencies,
    ));
  });
});

final spendingDailyOverviewProvider = Provider.autoDispose
    .family<AsyncValue<SpendingDailyOverview>, SpendingDailyOverviewQuery>(
        (ref, request) {
  final current =
      ref.watch(spendingScopedActualTransactionsProvider(request.query));

  if (!current.hasValue) {
    return current.hasError
        ? AsyncError(current.error!, current.stackTrace ?? StackTrace.current)
        : const AsyncLoading();
  }
  final previous = ref
      .watch(spendingScopedActualTransactionsProvider(request.previousQuery));

  final needsRates = [...current.valueOrNull!, ...?previous.valueOrNull].any(
      (entry) =>
          entry.currency?.trim().isNotEmpty == true &&
          entry.currency!.trim().toUpperCase() != request.currency);
  final rates = needsRates && !ref.watch(previewModeProvider).isActive
      ? ref.watch(currencyRateTableProvider).valueOrNull ??
          const CurrencyRateTable(
              baseCurrency: 'USD', rates: CurrencyRates.rates, isStale: true)
      : needsRates
          ? const CurrencyRateTable(
              baseCurrency: 'USD', rates: CurrencyRates.rates, isStale: true)
          : null;
  return current.whenDataWithPrevious((entries) => SpendingDailyOverview(
        dailyAverage: calculateDailySpendingAverage(entries,
            start: request.query.startDate!,
            end: request.query.endDate!,
            now: request.now,
            currency: request.currency,
            rates: rates),
        transactions: entries,
        previousAverage: previous.whenDataWithPrevious((entries) =>
            calculateDailySpendingAverage(entries,
                start: request.previousStart,
                end: request.previousEnd,
                now: request.previousEnd,
                currency: request.currency,
                rates: rates)),
      ));
});
