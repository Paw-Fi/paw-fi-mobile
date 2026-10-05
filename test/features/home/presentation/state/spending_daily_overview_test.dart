import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/spending_daily_overview_provider.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

ExpenseEntry _expense(int cents, DateTime date,
        {String currency = 'EUR',
        int? multiplier,
        String type = 'expense',
        bool isFinal = true,
        bool recurring = false}) =>
    ExpenseEntry(
      id: '$date:$cents',
      date: date,
      createdAt: date,
      amountCents: cents,
      currency: currency,
      type: type,
      analyticsSpendingMultiplier: multiplier,
      analyticsIsFinal: isFinal,
      isRecurring: recurring,
    );

void main() {
  test(
      'ledger provenance enriches a legacy row without overwriting its latest local amount',
      () async {
    final legacy = _expense(84000, DateTime(2026, 5, 10));
    final occurrence = ExpenseEntry(
        id: legacy.id,
        date: legacy.date,
        createdAt: legacy.createdAt,
        amountCents: 42000,
        currency: 'EUR',
        parentRecurringId: 'series',
        scheduledOccurrenceDate: DateTime(2026, 5, 5));
    final query = DashboardScopeQuery(
        userId: 'u1',
        householdId: null,
        selectedCurrency: 'EUR',
        startDate: DateTime(2026, 5),
        endDate: DateTime(2026, 5, 31));
    final request =
        SpendingDailyOverviewQuery(query: query, now: DateTime(2026, 5, 7));
    final container = ProviderContainer(overrides: [
      dashboardCalendarTransactionsProvider
          .overrideWith((ref, q) async => [legacy]),
      dashboardLocalOverlayTransactionsProvider.overrideWith((ref, q) => []),
      recurringOccurrenceProjectionResolutionProvider.overrideWith((ref, q) =>
          RecurringOccurrenceProjectionResolution(
              suppressionEntries: [occurrence])),
    ]);
    addTearDown(container.dispose);
    container.listen(spendingDailyOverviewProvider(request), (_, __) {});
    await container.read(dashboardCalendarTransactionsProvider(query).future);
    await container.pump();
    final result =
        container.read(spendingDailyOverviewProvider(request)).requireValue;
    expect(result.dailyAverage, 120);
    expect(result.transactions.single.amountCents, 84000);
    expect(result.transactions.single.parentRecurringId, 'series');
    expect(result.transactions.single.date, legacy.date);
  });
  test(
      'unknown reads cached refresh and independent comparison failures preserve honest values',
      () {
    final current = StateProvider<AsyncValue<List<ExpenseEntry>>>(
        (ref) => const AsyncLoading());
    final previous = StateProvider<AsyncValue<List<ExpenseEntry>>>(
        (ref) => const AsyncLoading());
    final request = SpendingDailyOverviewQuery(
        query: DashboardScopeQuery(
            userId: 'u1',
            householdId: null,
            selectedCurrency: 'EUR',
            startDate: DateTime(2026, 5),
            endDate: DateTime(2026, 5, 31)),
        now: DateTime(2026, 5, 10));
    final container = ProviderContainer(overrides: [
      spendingScopedActualTransactionsProvider.overrideWith(
          (ref, q) => ref.watch(q.startDate!.month == 5 ? current : previous)),
    ]);
    addTearDown(container.dispose);
    container.listen(spendingDailyOverviewProvider(request), (_, __) {});
    expect(container.read(spendingDailyOverviewProvider(request)).hasValue,
        isFalse);
    final rows = AsyncData([_expense(42000, DateTime(2026, 5, 10))]);
    container.read(current.notifier).state = rows;
    var result = container.read(spendingDailyOverviewProvider(request));
    expect(result.requireValue.dailyAverage, 42);
    expect(result.requireValue.changePercent, isNull);
    container.read(previous.notifier).state =
        AsyncData([_expense(45600, DateTime(2026, 4, 10))]);
    expect(
        container
            .read(spendingDailyOverviewProvider(request))
            .requireValue
            .changePercent!
            .round(),
        -8);
    container.read(current.notifier).state =
        const AsyncLoading<List<ExpenseEntry>>().copyWithPrevious(rows);
    result = container.read(spendingDailyOverviewProvider(request));
    expect(result.isLoading, isTrue);
    expect(result.requireValue.dailyAverage, 42);
    container.read(previous.notifier).state =
        AsyncError(StateError('offline'), StackTrace.current);
    expect(
        container
            .read(spendingDailyOverviewProvider(request))
            .requireValue
            .dailyAverage,
        42);
    expect(
        container
            .read(spendingDailyOverviewProvider(request))
            .requireValue
            .changePercent,
        isNull);
    container.read(current.notifier).state =
        AsyncError(StateError('no cache'), StackTrace.current);
    expect(container.read(spendingDailyOverviewProvider(request)).hasValue,
        isFalse);
    expect(container.read(spendingDailyOverviewProvider(request)).hasError,
        isTrue);
  });
  test('current average includes elapsed calendar days without spending', () {
    expect(
        calculateDailySpendingAverage([_expense(42000, DateTime(2026, 5, 10))],
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 5, 10)),
        42);
  });
  test('future recorded rows do not inflate the current daily average', () {
    expect(
        calculateDailySpendingAverage([
          _expense(42000, DateTime(2026, 5, 10)),
          _expense(99999, DateTime(2026, 5, 20)),
        ],
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 5, 10)),
        42);
  });
  test('completed months use every calendar day', () {
    expect(
        calculateDailySpendingAverage([_expense(130200, DateTime(2026, 5, 10))],
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 7)),
        42);
  });
  test(
      'refunds are signed and income transfers non-final rows and templates are excluded',
      () {
    expect(
        calculateDailySpendingAverage([
          _expense(44000, DateTime(2026, 5, 10)),
          _expense(2000, DateTime(2026, 5, 10), multiplier: -1),
          _expense(99999, DateTime(2026, 5, 10), type: 'income'),
          _expense(99999, DateTime(2026, 5, 10), multiplier: 0),
          _expense(99999, DateTime(2026, 5, 10), isFinal: false),
          _expense(99999, DateTime(2026, 5, 10), recurring: true),
        ],
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 5, 10)),
        42);
  });
  test(
      'reporting dates keep a late-paid recurring actual in its scheduled period',
      () {
    final actual = _expense(42000, DateTime(2026, 6, 2)).copyWith(
        parentRecurringId: 'series',
        scheduledOccurrenceDate: DateTime(2026, 5, 10));
    expect(
        calculateDailySpendingAverage([actual],
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 5, 10)),
        42);
  });
  test(
      'selected currencies convert and round using the existing aggregate helper',
      () {
    final entries = [
      _expense(10000, DateTime(2026, 5, 10)),
      _expense(10000, DateTime(2026, 5, 10), currency: 'USD')
    ];
    expect(
        calculateDailySpendingAverage(entries,
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 5, 10),
            currency: 'EUR',
            rates: const CurrencyRateTable(
                baseCurrency: 'USD',
                rates: {'USD': 1, 'EUR': .5},
                isStale: false)),
        15);
    expect(entries.last.currency, 'USD');
    expect(entries.last.amountCents, 10000);
  });
  test('empty and refund-only periods remain finite', () {
    expect(
        calculateDailySpendingAverage([],
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 5, 10)),
        0);
    expect(
        calculateDailySpendingAverage(
            [_expense(20000, DateTime(2026, 5, 10), multiplier: -1)],
            start: DateTime(2026, 5),
            end: DateTime(2026, 5, 31),
            now: DateTime(2026, 5, 10)),
        -20);
  });
  test('comparison matches elapsed days within custom financial cycles', () {
    final request = SpendingDailyOverviewQuery(
        query: DashboardScopeQuery(
            userId: 'u1',
            householdId: 'private',
            selectedCurrency: 'EUR',
            startDate: DateTime(2026, 5, 17),
            endDate: DateTime(2026, 6, 16)),
        now: DateTime(2026, 6, 5),
        financialMonthStartDay: 17);
    expect(request.previousQuery.startDate, DateTime(2026, 4, 17));
    expect(request.previousQuery.endDate, DateTime(2026, 5, 16));
    expect(request.previousStart, DateTime(2026, 4, 17));
    expect(request.previousEnd, DateTime(2026, 5, 6));
    expect(request.previousQuery.householdId, 'private');
  });
  test('completed periods compare against the full previous cycle', () {
    final request = SpendingDailyOverviewQuery(
        query: DashboardScopeQuery(
            userId: 'u1',
            householdId: null,
            selectedCurrency: 'EUR',
            startDate: DateTime(2026, 5),
            endDate: DateTime(2026, 5, 31)),
        now: DateTime(2026, 7));
    expect(request.previousEnd, DateTime(2026, 4, 30));
  });
  test('daily selection compares with the equivalent day in the previous cycle',
      () {
    final request = SpendingDailyOverviewQuery(
        query: DashboardScopeQuery(
            userId: 'u1',
            householdId: 'shared',
            selectedCurrency: 'EUR',
            startDate: DateTime(2026, 5, 10),
            endDate: DateTime(2026, 5, 10)),
        now: DateTime(2026, 5, 20));
    expect(request.previousStart, DateTime(2026, 4, 10));
    expect(request.previousEnd, DateTime(2026, 4, 10));
  });
}
