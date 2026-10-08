import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/spending_daily_overview_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/home_period_selector.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

class _Recurring extends RecurringTransactionsNotifier {
  _Recurring(super.ref, super.householdId, List<RecurringTransaction> entries) {
    state = RecurringTransactionsState(
        data: AsyncData(entries), hasLoadedOnce: true);
  }
}

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'test@example.com');
}

class _Store extends HomePeriodSelectionStore {
  @override
  Future<HomePeriodSelectionState?> load(String userId) async => null;
}

ExpenseEntry _entry(String id, String category, int cents,
        {String currency = 'USD',
        int? multiplier,
        bool finality = true,
        String type = 'expense',
        String? household,
        DateTime? date}) =>
    ExpenseEntry(
      id: id,
      date: date ?? DateTime(2026, 4, 20),
      createdAt: DateTime(2026, 4, 20),
      amountCents: cents,
      category: category,
      currency: currency,
      userId: 'user-1',
      analyticsSpendingMultiplier: multiplier,
      analyticsIsFinal: finality,
      type: type,
      householdId: household,
    );

void main() {
  test('retained categories never cross into an unresolved Space', () async {
    final query = DashboardScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        startDate: DateTime(2026, 4),
        endDate: DateTime(2026, 4, 30));
    BudgetCompanionRequest request(DashboardScopeQuery query) =>
        BudgetCompanionRequest(
            query: query,
            currency: 'USD',
            mode: HomePeriodMode.daily,
            pocketsScope: PocketsScopeParams(
                scope: PocketsScopeType.personal,
                periodMonth: DateTime(2026, 4),
                currency: 'USD'));
    final selection = StateProvider((ref) => request(query));
    final pending = Completer<List<ExpenseEntry>>();
    final container = ProviderContainer(overrides: [
      budgetCompanionRequestProvider
          .overrideWith((ref) => ref.watch(selection)),
      includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => false),
      selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
      dashboardCalendarTransactionsProvider.overrideWith((ref, q) => q == query
          ? Future.value([_entry('one', 'food', 1000)])
          : pending.future),
      dashboardLocalOverlayTransactionsProvider.overrideWith((ref, q) => []),
      recurringOccurrenceProjectionResolutionProvider.overrideWith(
          (ref, q) => const RecurringOccurrenceProjectionResolution()),
    ]);
    addTearDown(container.dispose);
    container.listen(budgetCompanionDataProvider, (_, __) {});
    await container.read(dashboardCalendarTransactionsProvider(query).future);
    await container.pump();
    expect(container.read(budgetCompanionDataProvider).categories.hasValue,
        isTrue);
    container.read(selection.notifier).state =
        request(query.copyWith(householdId: 'other-space'));
    final changed = container.read(budgetCompanionDataProvider);
    expect(changed.categories.hasValue, isFalse);
    expect(changed.summary.hasValue, isFalse);
    pending.complete([_entry('other', 'rent', 2500, household: 'other-space')]);
    await container.pump();
    expect(
        container
            .read(budgetCompanionDataProvider)
            .categories
            .requireValue
            .single
            .amount,
        25);
  });

  test('repeated dependency reloads retain categories and share calendar reads',
      () async {
    final query = DashboardScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        startDate: DateTime(2026, 4, 20),
        endDate: DateTime(2026, 4, 20));
    final request = BudgetCompanionRequest(
        query: query,
        currency: 'USD',
        mode: HomePeriodMode.daily,
        pocketsScope: PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: DateTime(2026, 4),
            currency: 'USD'));
    final revision = StateProvider((ref) => 0);
    var pending = Completer<List<ExpenseEntry>>();
    var loads = 0;
    final container = ProviderContainer(overrides: [
      budgetCompanionRequestProvider.overrideWithValue(request),
      includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => false),
      selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
      dashboardCalendarTransactionsProvider.overrideWith((ref, q) {
        ref.watch(revision);
        loads++;
        return pending.future;
      }),
      dashboardLocalOverlayTransactionsProvider.overrideWith((ref, q) => []),
      recurringOccurrenceProjectionResolutionProvider.overrideWith(
          (ref, q) => const RecurringOccurrenceProjectionResolution()),
    ]);
    addTearDown(container.dispose);
    container.listen(dashboardCalendarTransactionsProvider(query), (_, __) {});
    container.listen(budgetCompanionDataProvider, (_, __) {});
    expect(container.read(budgetCompanionDataProvider).categories.hasValue,
        isFalse);
    pending.complete([_entry('one', 'food', 1000)]);
    await container.read(dashboardCalendarTransactionsProvider(query).future);
    await container.pump();
    for (var index = 0; index < 10; index++) {
      pending = Completer<List<ExpenseEntry>>();
      container.read(revision.notifier).state++;
      await container.pump();
      final source =
          container.read(dashboardCalendarTransactionsProvider(query));
      expect(source.isReloading, isTrue);
      expect(source.hasValue, isTrue);
      expect(
          container
              .read(spendingScopedActualTransactionsProvider(query))
              .hasValue,
          isTrue);
      final data = container.read(budgetCompanionDataProvider);
      expect(data.categories.hasValue, isTrue,
          reason: 'reload $index must not replace the chart with a skeleton');
      expect(data.categories.requireValue.single.amount, 10 + index);
      expect(data.summary.requireValue.spent, 10 + index);
      expect(data.isRefreshing, isTrue);
      expect(loads, index + 2);
      pending.complete([_entry('one', 'food', 1100 + index * 100)]);
      await container.read(dashboardCalendarTransactionsProvider(query).future);
      await container.pump();
      expect(container.read(budgetCompanionDataProvider).isRefreshing, isFalse);
    }
    expect(loads, 11);
  });

  for (final mode in HomePeriodMode.values) {
    test('cached period reload retains mapped card values in ${mode.name}', () {
      final query = DashboardScopeQuery(
          userId: 'user-1',
          householdId: null,
          selectedCurrency: 'USD',
          startDate: DateTime(2026, 4),
          endDate: DateTime(2026, 4, 30));
      final request = BudgetCompanionRequest(
          query: query,
          currency: 'USD',
          mode: mode,
          pocketsScope: PocketsScopeParams(
              scope: PocketsScopeType.personal,
              periodMonth: DateTime(2026, 4),
              currency: 'USD'));
      final loaded = AsyncData(summarizeTransactionsInCurrency(
          [_entry('one', 'food', 1000)],
          targetCurrency: 'USD',
          rates: const CurrencyRateTable(
              baseCurrency: 'USD', rates: {'USD': 1}, isStale: false)));
      final period =
          StateProvider<AsyncValue<TransactionsFeedSummary>>((ref) => loaded);
      final container = ProviderContainer(overrides: [
        budgetCompanionRequestProvider.overrideWithValue(request),
        budgetCompanionPeriodSummaryProvider
            .overrideWith((ref, q) => ref.watch(period)),
        budgetCompanionMonthlySummaryProvider.overrideWith((ref, p) =>
            const AsyncData(BudgetCompanionSummary(spent: 10, budget: 100))),
      ]);
      addTearDown(container.dispose);
      container.listen(budgetCompanionDataProvider, (_, __) {});
      container.read(period.notifier).state =
          const AsyncLoading<TransactionsFeedSummary>()
              .copyWithPrevious(loaded, isRefresh: false);
      final data = container.read(budgetCompanionDataProvider);
      expect(data.categories.hasValue, isTrue);
      expect(data.categories.requireValue.single.amount, 10);
      expect(data.summary.requireValue.spent, 10);
      expect(data.isRefreshing, isTrue);
      expect(data.isSummaryRefreshing, mode == HomePeriodMode.daily);
    });
  }

  BudgetCompanionSummary summary(double spent, {double? budget = 100}) =>
      BudgetCompanionSummary(spent: spent, budget: budget);

  test('normal spending retains the unclamped percentage and remaining', () {
    final value = summary(1842, budget: 3000);
    expect(value.progress, closeTo(.614, .0001));
    expect(value.remaining, 1158);
    expect(value.reaction, BudgetCompanionReaction.encouraging);
  });

  for (final sample in [
    (0.0, BudgetCompanionReaction.happy),
    (59.0, BudgetCompanionReaction.happy),
    (60.0, BudgetCompanionReaction.encouraging),
    (79.0, BudgetCompanionReaction.encouraging),
    (80.0, BudgetCompanionReaction.concerned),
    (100.0, BudgetCompanionReaction.concerned),
    (108.0, BudgetCompanionReaction.overBudget),
  ]) {
    test('budget reaction at ${sample.$1} percent', () {
      expect(summary(sample.$1).reaction, sample.$2);
    });
  }

  test('over budget caps only the visible bar', () {
    final value = summary(108);
    expect(value.progress, 1.08);
    expect(value.barProgress, 1);
    expect(value.remaining, -8);
  });

  test('missing and zero budgets never invent progress', () {
    for (final budget in [null, 0.0, -1.0, double.infinity, double.nan]) {
      final value = summary(20, budget: budget);
      expect(value.progress, isNull);
      expect(value.remaining, isNull);
      expect(value.reaction, BudgetCompanionReaction.planning);
    }
  });

  test('refund-adjusted spending remains signed but bar is nonnegative', () {
    final value = summary(-20);
    expect(value.spent, -20);
    expect(value.remaining, 120);
    expect(value.barProgress, 0);
  });

  test('categories are sorted, finite, positive and scale safely', () {
    final categories = budgetCompanionCategories({
      'small': .01,
      'refund': -10,
      'zero': 0,
      'shopping': 180,
      'food': 249,
      'invalid': double.nan,
    });
    expect(
        categories.map((item) => item.category), ['food', 'shopping', 'small']);
    expect(categories.first.heightFactor, 1);
    expect(categories[1].heightFactor, closeTo(180 / 249, .0001));
    expect(categories.last.heightFactor, .08);
    expect(budgetCompanionCategories({}), isEmpty);
  });

  test('large amounts and exact budget remain finite', () {
    expect(summary(1e12, budget: 1e12).remaining, 0);
    expect(summary(1e12, budget: 1e12).progress, 1);
  });

  test('Pockets loading, cached refresh, offline errors and RPC-only totals',
      () {
    final initial = PocketsState.initial();
    expect(budgetCompanionPocketsSummary(initial).isLoading, isTrue);
    expect(budgetCompanionPocketsSummary(initial).hasValue, isFalse);
    expect(
        budgetCompanionPocketsSummary(initial.copyWith(error: 'offline'))
            .hasError,
        isTrue);
    final loaded = initial.copyWith(
        isLoading: false,
        periodMonth: DateTime(2026, 4),
        totalBudget: 3000,
        aggregateTotalSpent: 1842);
    final projected = budgetCompanionPocketsSummary(loaded);
    expect(projected.requireValue.spent, 1842);
    expect(projected.requireValue.budget, 3000);
    final refreshing =
        budgetCompanionPocketsSummary(loaded.copyWith(isLoading: true));
    expect(refreshing.hasValue, isTrue);
    expect(refreshing.isLoading, isTrue);
    expect(refreshing.requireValue.spent, 1842);
    expect(
        budgetCompanionPocketsSummary(loaded.copyWith(error: 'offline'))
            .requireValue
            .spent,
        1842);
  });

  for (final scope in PocketsScopeType.values) {
    test('request matches Home ring key for ${scope.name} and custom cycle',
        () async {
      final scopeFixture = HouseholdScope(
        viewMode: scope == PocketsScopeType.personal
            ? ViewMode.personal
            : ViewMode.household,
        selected: SelectedHouseholdState(
            householdId: scope == PocketsScopeType.personal ? null : 'space-1'),
        portfolioHouseholdIds:
            scope == PocketsScopeType.portfolio ? {'space-1'} : {},
      );
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        householdScopeProvider.overrideWithValue(scopeFixture),
        selectedHomeCurrencyCodeProvider.overrideWithValue('EUR'),
        homePeriodFinancialMonthStartDayProvider.overrideWithValue(17),
        financialMonthStartDayStateProvider
            .overrideWithValue(const AsyncData(17)),
        homePeriodClockProvider.overrideWithValue(() => DateTime(2026, 4, 20)),
        homePeriodSelectionStoreProvider.overrideWithValue(_Store()),
      ]);
      addTearDown(container.dispose);
      container.read(homeFilterProvider.notifier).setSelectedCurrency('EUR');
      container
          .read(homeFilterProvider.notifier)
          .setSelectedCurrencies(['EUR', 'USD']);
      await container.pump();
      final request = container.read(budgetCompanionRequestProvider)!;
      final ringKey = buildHomePeriodPocketsScopeParams(
          scopeType: scope,
          householdId: scope == PocketsScopeType.personal ? null : 'space-1',
          period: DateTime(2026, 4, 17),
          currency: 'EUR',
          selectedCurrencies: ['USD', 'EUR'],
          financialMonthStartDay: 17,
          includeUpcomingRecurring: true,
          isBootstrapCurrency: false);
      expect(request.pocketsScope, ringKey);
      expect(request.query.startDate, DateTime(2026, 4, 17));
      expect(request.query.endDate, DateTime(2026, 5, 16));
    });
  }

  test(
      'derived spending reuses a mounted calendar read, overlays refunds and converts categories',
      () async {
    final query = DashboardScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        selectedCurrencies: ['USD', 'EUR'],
        startDate: DateTime(2026, 4),
        endDate: DateTime(2026, 4, 30));
    final pending = StateProvider<List<ExpenseEntry>>((ref) => []);
    var loads = 0;
    final container = ProviderContainer(overrides: [
      includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => false),
      selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
      currencyRateTableProvider.overrideWith((ref) async =>
          const CurrencyRateTable(
              baseCurrency: 'USD',
              rates: {'USD': 1, 'EUR': .5},
              isStale: false)),
      dashboardCalendarTransactionsProvider.overrideWith((ref, q) async {
        loads++;
        return [
          _entry('food', 'food', 10000),
          _entry('foreign', 'shopping', 1000, currency: 'EUR'),
          _entry('refund', 'food', 2000, multiplier: -1),
          _entry('pending-bank', 'food', 99999, finality: false),
          _entry('income', 'salary', 99999, type: 'income'),
          _entry('transfer:one', 'transfer', 99999, multiplier: 0),
          _entry('other-space', 'food', 99999, household: 'other'),
        ];
      }),
      dashboardLocalOverlayTransactionsProvider
          .overrideWith((ref, q) => ref.watch(pending)),
      recurringOccurrenceProjectionResolutionProvider.overrideWith(
          (ref, q) => const RecurringOccurrenceProjectionResolution()),
    ]);
    addTearDown(container.dispose);
    container.listen(dashboardCalendarTransactionsProvider(query), (_, __) {});
    container.listen(budgetCompanionPeriodSummaryProvider(query), (_, __) {});
    await container.read(currencyRateTableProvider.future);
    await container.read(dashboardCalendarTransactionsProvider(query).future);
    final value = container
        .read(budgetCompanionPeriodSummaryProvider(query))
        .requireValue;
    expect(value.expenseTotal, 100);
    expect(value.categorySummaries.map((item) => item.category),
        ['food & drinks', 'shopping']);
    container.read(pending.notifier).state = [
      _entry('optimistic_new', 'food', 500)
    ];
    final updated = container
        .read(budgetCompanionPeriodSummaryProvider(query))
        .requireValue;
    expect(updated.expenseTotal, 105);
    expect(loads, 1);
    container.read(pending.notifier).state = [_entry('food', 'food', 12000)];
    expect(
        container
            .read(budgetCompanionPeriodSummaryProvider(query))
            .requireValue
            .expenseTotal,
        120);
    container.read(pending.notifier).state = [];
    expect(
        container
            .read(budgetCompanionPeriodSummaryProvider(query))
            .requireValue
            .expenseTotal,
        100);
    await container.pump();
    expect(loads, 1, reason: 'derived reads must not trigger refresh loops');
  });

  test('uncached daily read is unknown until its shared feed resolves',
      () async {
    final day = DateTime(2026, 4, 20);
    final query = DashboardScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        startDate: day,
        endDate: day);
    final request = BudgetCompanionRequest(
        query: query,
        currency: 'USD',
        mode: HomePeriodMode.daily,
        pocketsScope: PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: day,
            currency: 'USD'));
    final read = Completer<List<ExpenseEntry>>();
    final container = ProviderContainer(overrides: [
      budgetCompanionRequestProvider.overrideWithValue(request),
      includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => false),
      selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
      dashboardCalendarTransactionsProvider
          .overrideWith((ref, q) => read.future),
      dashboardLocalOverlayTransactionsProvider.overrideWith((ref, q) => []),
      recurringOccurrenceProjectionResolutionProvider.overrideWith(
          (ref, q) => const RecurringOccurrenceProjectionResolution()),
    ]);
    addTearDown(container.dispose);
    container.listen(budgetCompanionDataProvider, (_, __) {});
    expect(
        container.read(budgetCompanionDataProvider).summary.hasValue, isFalse);
    read.complete([_entry('one', 'food', 1000)]);
    await container.read(dashboardCalendarTransactionsProvider(query).future);
    await container.pump();
    expect(
        container.read(budgetCompanionDataProvider).summary.requireValue.spent,
        10);
    expect(
        container.read(budgetCompanionDataProvider).summary.requireValue.budget,
        isNull);
  });

  test(
      'recurring category math follows canonical Pocket projection eligibility',
      () async {
    final start = DateTime(2026, 4);
    final query = DashboardScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        startDate: start,
        endDate: DateTime(2026, 4, 30));
    final series = RecurringTransaction.fromJson({
      'id': 'rent-series',
      'user_id': 'user-1',
      'date': '2026-04-01',
      'created_at': '2026-04-01',
      'amount_cents': 10000,
      'category': 'rent',
      'currency': 'USD',
      'type': 'expense',
      'recurrence_rule': {'frequency': 'monthly', 'anchor_date': '2026-04-01'},
    });
    final actual = _entry('actual', 'rent', 12000).copyWith(
        parentRecurringId: 'rent-series', scheduledOccurrenceDate: start);
    final projection = await loadProjectedPocketMonthExpenses(
        userId: 'user-1',
        scope: PocketsScopeType.personal,
        householdId: null,
        monthStart: start,
        selectedCurrency: 'USD',
        includeUpcomingRecurring: true,
        actualExpenses: [actual],
        scopedRecurringTransactions: [series]);
    final container = ProviderContainer(overrides: [
      includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => true),
      selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
      recurringTransactionsProvider
          .overrideWith((ref, id) => _Recurring(ref, id, [series])),
      dashboardCalendarTransactionsProvider
          .overrideWith((ref, q) async => [actual]),
      dashboardLocalOverlayTransactionsProvider.overrideWith((ref, q) => []),
      recurringOccurrenceProjectionResolutionProvider.overrideWith((ref, q) =>
          RecurringOccurrenceProjectionResolution(
              suppressionEntries: [actual])),
    ]);
    addTearDown(container.dispose);
    container.listen(budgetCompanionPeriodSummaryProvider(query), (_, __) {});
    await container.read(dashboardCalendarTransactionsProvider(query).future);
    expect(
        container
            .read(budgetCompanionPeriodSummaryProvider(query))
            .requireValue
            .expenseTotal,
        actual.spendingEffect +
            projection.fold<double>(0, (sum, row) => sum + row.spendingEffect));
  });

  test(
      'monthly RPC summary survives empty categories without reading a comparison',
      () {
    final params = PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 4),
        currency: 'USD');
    final request = BudgetCompanionRequest(
        query: DashboardScopeQuery(
            userId: 'user-1',
            householdId: null,
            selectedCurrency: 'USD',
            startDate: DateTime(2026, 4),
            endDate: DateTime(2026, 4, 30)),
        pocketsScope: params,
        mode: HomePeriodMode.monthly,
        currency: 'USD');
    final state = StateProvider<PocketsState>((ref) => PocketsState.initial()
        .copyWith(
            isLoading: false,
            periodMonth: DateTime(2026, 4),
            totalBudget: 3000,
            aggregateTotalSpent: 1842));
    final container = ProviderContainer(overrides: [
      budgetCompanionRequestProvider.overrideWithValue(request),
      budgetCompanionPeriodSummaryProvider.overrideWith(
          (ref, q) => const AsyncData(TransactionsFeedSummary.empty())),
      budgetCompanionMonthlySummaryProvider.overrideWith((ref, p) => p == params
          ? budgetCompanionPocketsSummary(ref.watch(state))
          : AsyncError(StateError('offline'), StackTrace.current)),
    ]);
    addTearDown(container.dispose);
    container.listen(budgetCompanionDataProvider, (_, __) {});
    final data = container.read(budgetCompanionDataProvider);
    expect(data.summary.requireValue.spent, 1842);
    expect(data.categories.requireValue, isEmpty);
    container.read(state.notifier).state = container
        .read(state)
        .copyWith(isLoading: true, aggregateTotalSpent: 1852);
    expect(
        container.read(budgetCompanionDataProvider).summary.requireValue.spent,
        1852);
    expect(container.read(budgetCompanionDataProvider).isRefreshing, isTrue);
  });
}
