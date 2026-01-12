import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_repository.dart';
import 'package:moneko/features/home/presentation/widgets/spending_breakdown_chart.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/widgets/where_the_money_went_widget.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';
import 'package:moneko/features/households/presentation/widgets/group_fairness_meter.dart';
import 'package:moneko/features/households/presentation/widgets/household_home_content.dart';
import 'package:moneko/features/households/presentation/widgets/settlement_suggestions_card.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

class _TestHouseholdsNotifier
    extends StateNotifier<AsyncValue<List<Household>>> {
  _TestHouseholdsNotifier(List<Household> households)
      : super(AsyncValue.data(households));
}

class _TestMembersNotifier
    extends StateNotifier<AsyncValue<List<HouseholdMember>>> {
  _TestMembersNotifier(List<HouseholdMember> members)
      : super(AsyncValue.data(members));
}

class _TestDashboardNotifier
    extends StateNotifier<AsyncValue<List<DashboardWidgetConfig>>> {
  _TestDashboardNotifier(List<DashboardWidgetConfig> configs)
      : super(AsyncValue.data(configs));
}

class _TestRecurringNotifier extends StateNotifier<RecurringTransactionsState> {
  _TestRecurringNotifier()
      : super(
          RecurringTransactionsState(
            data: const AsyncValue.data(<RecurringTransaction>[]),
            hasLoadedOnce: true,
          ),
        );
}

class _TestAnalyticsNotifier extends StateNotifier<AnalyticsData> {
  _TestAnalyticsNotifier(AnalyticsData data) : super(data);
}

class _TestSelectedHouseholdNotifier
    extends StateNotifier<SelectedHouseholdState> {
  _TestSelectedHouseholdNotifier(Household household)
      : super(SelectedHouseholdState(
          householdId: household.id,
          household: household,
          isLoading: false,
        ));
}

ExpenseEntry _expense({
  required String id,
  required String userId,
  required String householdId,
  required DateTime date,
  required int amountCents,
  required String category,
  required String rawText,
  required DateTime createdAt,
}) {
  return ExpenseEntry(
    id: id,
    userId: userId,
    householdId: householdId,
    date: date,
    amountCents: amountCents,
    currency: 'USD',
    category: category,
    rawText: rawText,
    createdAt: createdAt,
    type: 'expense',
  );
}

ExpenseSplitLine _splitLine({
  required String id,
  required String splitGroupId,
  required String userId,
  required int amountCents,
  required DateTime now,
  String? userName,
  String? userEmail,
}) {
  return ExpenseSplitLine(
    id: id,
    splitGroupId: splitGroupId,
    userId: userId,
    amountCents: amountCents,
    isSettled: false,
    createdAt: now,
    updatedAt: now,
    userName: userName,
    userEmail: userEmail,
  );
}

ExpenseSplitGroup _splitGroup({
  required String id,
  required String householdId,
  required String expenseId,
  required String payerUserId,
  required int totalAmountCents,
  required DateTime now,
  required List<ExpenseSplitLine> lines,
}) {
  return ExpenseSplitGroup(
    id: id,
    householdId: householdId,
    expenseId: expenseId,
    payerUserId: payerUserId,
    splitType: SplitType.equal,
    currency: 'USD',
    totalAmountCents: totalAmountCents,
    createdAt: now,
    updatedAt: now,
    splitLines: lines,
  );
}

HouseholdSummary _summary({
  required String householdId,
  required int totalExpensesCents,
  required int transactionCount,
  required List<MemberContribution> contributions,
  required Map<String, int> balances,
}) {
  return HouseholdSummary(
    householdId: householdId,
    currency: 'USD',
    period: const DatePeriod(startDate: '2024-01-01', endDate: '2024-01-31'),
    totals: Totals(
      totalExpensesCents: totalExpensesCents,
      totalIncomeCents: 0,
      netCents: -totalExpensesCents,
      transactionCount: transactionCount,
      splitCount: transactionCount,
    ),
    memberContributions: contributions,
    categoryBreakdown: const [],
    budgets: const [],
    balances: balances,
  );
}

void main() {
  testWidgets(
      'household home content refreshes all cards when a new household expense is added',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const userId = 'u1';
    const otherUserId = 'u2';
    const householdId = 'h1';

    final household = Household(
      id: householdId,
      name: 'Test Household',
      ownerId: userId,
      currency: 'USD',
      createdAt: today,
      updatedAt: today,
    );

    final members = [
      HouseholdMember(
        id: 'm1',
        householdId: householdId,
        userId: userId,
        role: HouseholdRole.owner,
        joinedAt: today,
        createdAt: today,
        updatedAt: today,
        userName: 'Alex',
        userEmail: 'alex@example.com',
      ),
      HouseholdMember(
        id: 'm2',
        householdId: householdId,
        userId: otherUserId,
        role: HouseholdRole.member,
        joinedAt: today,
        createdAt: today,
        updatedAt: today,
        userName: 'Jordan',
        userEmail: 'jordan@example.com',
      ),
    ];

    final expense1 = _expense(
      id: 'e1',
      userId: userId,
      householdId: householdId,
      date: today,
      amountCents: 1234,
      category: 'food',
      rawText: 'Lunch A',
      createdAt: today.add(const Duration(hours: 9)),
    );

    final splitGroup1 = _splitGroup(
      id: 's1',
      householdId: householdId,
      expenseId: 'e1',
      payerUserId: userId,
      totalAmountCents: 1234,
      now: today,
      lines: [
        _splitLine(
          id: 'l1',
          splitGroupId: 's1',
          userId: userId,
          amountCents: 700,
          now: today,
          userName: 'Alex',
          userEmail: 'alex@example.com',
        ),
        _splitLine(
          id: 'l2',
          splitGroupId: 's1',
          userId: otherUserId,
          amountCents: 534,
          now: today,
          userName: 'Jordan',
          userEmail: 'jordan@example.com',
        ),
      ],
    );

    final initialSummary = _summary(
      householdId: householdId,
      totalExpensesCents: 1234,
      transactionCount: 1,
      contributions: const [
        MemberContribution(
          userId: userId,
          totalSpentCents: 700,
          transactionCount: 1,
          splitCount: 1,
          balanceCents: 534,
          userName: 'Alex',
        ),
        MemberContribution(
          userId: otherUserId,
          totalSpentCents: 534,
          transactionCount: 1,
          splitCount: 1,
          balanceCents: -534,
          userName: 'Jordan',
        ),
      ],
      balances: const {
        userId: 534,
        otherUserId: -534,
      },
    );

    final expense2 = _expense(
      id: 'e2',
      userId: otherUserId,
      householdId: householdId,
      date: today,
      amountCents: 777,
      category: 'transport',
      rawText: 'Taxi B',
      createdAt: today.add(const Duration(hours: 11)),
    );

    final splitGroup2 = _splitGroup(
      id: 's2',
      householdId: householdId,
      expenseId: 'e2',
      payerUserId: otherUserId,
      totalAmountCents: 777,
      now: today,
      lines: [
        _splitLine(
          id: 'l3',
          splitGroupId: 's2',
          userId: userId,
          amountCents: 277,
          now: today,
          userName: 'Alex',
          userEmail: 'alex@example.com',
        ),
        _splitLine(
          id: 'l4',
          splitGroupId: 's2',
          userId: otherUserId,
          amountCents: 500,
          now: today,
          userName: 'Jordan',
          userEmail: 'jordan@example.com',
        ),
      ],
    );

    final updatedSummary = _summary(
      householdId: householdId,
      totalExpensesCents: 2011,
      transactionCount: 2,
      contributions: const [
        MemberContribution(
          userId: userId,
          totalSpentCents: 977,
          transactionCount: 2,
          splitCount: 2,
          balanceCents: 257,
          userName: 'Alex',
        ),
        MemberContribution(
          userId: otherUserId,
          totalSpentCents: 1034,
          transactionCount: 2,
          splitCount: 2,
          balanceCents: -257,
          userName: 'Jordan',
        ),
      ],
      balances: const {
        userId: 257,
        otherUserId: -257,
      },
    );

    final expensesStateProvider =
        StateProvider<List<ExpenseEntry>>((ref) => [expense1]);
    final splitsStateProvider =
        StateProvider<List<ExpenseSplitGroup>>((ref) => [splitGroup1]);
    final summaryStateProvider =
        StateProvider<HouseholdSummary>((ref) => initialSummary);

    final householdsNotifier = _TestHouseholdsNotifier([household]);
    final membersNotifier = _TestMembersNotifier(members);
    final dashboardNotifier = _TestDashboardNotifier([
      const DashboardWidgetConfig(
        id: 'spent_by_you',
        type: DashboardWidgetType.householdSpentByYou,
        order: 0,
      ),
      const DashboardWidgetConfig(
        id: 'calendar',
        type: DashboardWidgetType.householdFinancialCalendar,
        order: 1,
      ),
      const DashboardWidgetConfig(
        id: 'budget',
        type: DashboardWidgetType.householdBudgetOverview,
        order: 2,
      ),
      const DashboardWidgetConfig(
        id: 'fairness',
        type: DashboardWidgetType.householdFairness,
        order: 3,
      ),
      const DashboardWidgetConfig(
        id: 'settlement',
        type: DashboardWidgetType.householdSettlement,
        order: 4,
      ),
      const DashboardWidgetConfig(
        id: 'member_spending',
        type: DashboardWidgetType.householdMemberSpending,
        order: 5,
      ),
      const DashboardWidgetConfig(
        id: 'recent',
        type: DashboardWidgetType.householdRecentTransactions,
        order: 6,
      ),
      const DashboardWidgetConfig(
        id: 'breakdown',
        type: DashboardWidgetType.householdSpendingBreakdownChart,
        order: 7,
      ),
      const DashboardWidgetConfig(
        id: 'where_money',
        type: DashboardWidgetType.householdWhereTheMoneyWent,
        order: 8,
      ),
    ]);
    final recurringNotifier = _TestRecurringNotifier();
    final analyticsNotifier = _TestAnalyticsNotifier(
      AnalyticsData(
        preferredCurrency: 'USD',
      ),
    );
    final selectedHouseholdNotifier =
        _TestSelectedHouseholdNotifier(household);

    final dashboardRepository = DashboardRepository(
      prefs,
      SupabaseClient('http://localhost', 'anon'),
    );

    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        analyticsProvider.overrideWith((ref) => analyticsNotifier),
        userHouseholdsProvider.overrideWith((ref, _) => householdsNotifier),
        householdMembersProvider.overrideWith((ref, _) => membersNotifier),
        selectedHouseholdProvider
            .overrideWith((ref) => selectedHouseholdNotifier),
        dashboardRepositoryFutureProvider
            .overrideWith((ref) async => dashboardRepository),
        householdDashboardProvider.overrideWith((ref, _) => dashboardNotifier),
        householdSummaryProvider.overrideWith((ref, _) async {
          return ref.watch(summaryStateProvider);
        }),
        householdExpensesProvider.overrideWith((ref, params) async {
          final base = ref.watch(expensesStateProvider);
          final optimistic = ref.watch(
            householdOptimisticExpensesProvider
                .select((state) => state[params.householdId] ?? const []),
          );
          return mergeHouseholdExpenses(base, optimistic);
        }),
        cachedHouseholdExpensesProvider.overrideWith((ref, params) async {
          final base = ref.watch(expensesStateProvider);
          final optimistic = ref.watch(
            householdOptimisticExpensesProvider
                .select((state) => state[params.householdId] ?? const []),
          );
          return mergeHouseholdExpenses(base, optimistic);
        }),
        householdSplitsProvider.overrideWith((ref, params) async {
          final base = ref.watch(splitsStateProvider);
          final optimistic = ref.watch(
            householdOptimisticSplitsProvider
                .select((state) => state[params.householdId] ?? const []),
          );
          return mergeHouseholdSplits(base, optimistic);
        }),
        cachedHouseholdSplitsProvider.overrideWith((ref, params) async {
          final base = ref.watch(splitsStateProvider);
          final optimistic = ref.watch(
            householdOptimisticSplitsProvider
                .select((state) => state[params.householdId] ?? const []),
          );
          return mergeHouseholdSplits(base, optimistic);
        }),
        recurringTransactionsProvider
            .overrideWith((ref, _) => recurringNotifier),
        upcomingRecurringTransactionProvider.overrideWith((ref, _) => null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [HouseholdHomeContent()],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final initialSpending =
        tester.widget<SpendingCard>(find.byType(SpendingCard));
    expect(initialSpending.expenses.single.amountCents, 700);

    final initialCalendar = tester
        .widget<FinancialCalendarWidget>(find.byType(FinancialCalendarWidget));
    expect(initialCalendar.transactions.length, 1);

    final initialFairness =
        tester.widget<GroupFairnessMeter>(find.byType(GroupFairnessMeter));
    expect(initialFairness.summary.totals.totalExpensesCents, 1234);

    final initialSettlement = tester
        .widget<SettlementSuggestionsCard>(find.byType(SettlementSuggestionsCard));
    expect(initialSettlement.splits?.length, 1);

    final initialBreakdown = tester
        .widget<SpendingBreakdownChart>(find.byType(SpendingBreakdownChart));
    expect(initialBreakdown.expenses.length, 1);

    final initialWhereMoney = tester
        .widget<WhereTheMoneyWentWidget>(find.byType(WhereTheMoneyWentWidget));
    expect(initialWhereMoney.expenses.length, 1);

    expect(find.text('Taxi B'), findsNothing);
    expect(find.text(r'$20.11'), findsNothing);
    expect(find.text(r'$10.34'), findsNothing);

    container.read(summaryStateProvider.notifier).state = updatedSummary;
    container
        .read(householdOptimisticExpensesProvider.notifier)
        .addExpense(householdId, expense2);
    container
        .read(householdOptimisticSplitsProvider.notifier)
        .addSplitGroup(householdId, splitGroup2);

    await tester.pumpAndSettle();

    final updatedSpending =
        tester.widget<SpendingCard>(find.byType(SpendingCard));
    expect(updatedSpending.expenses.single.amountCents, 977);

    final updatedCalendar = tester
        .widget<FinancialCalendarWidget>(find.byType(FinancialCalendarWidget));
    expect(updatedCalendar.transactions.length, 2);

    final updatedFairness =
        tester.widget<GroupFairnessMeter>(find.byType(GroupFairnessMeter));
    expect(updatedFairness.summary.totals.totalExpensesCents, 2011);

    final updatedSettlement = tester
        .widget<SettlementSuggestionsCard>(find.byType(SettlementSuggestionsCard));
    expect(updatedSettlement.splits?.length, 2);

    final updatedBreakdown = tester
        .widget<SpendingBreakdownChart>(find.byType(SpendingBreakdownChart));
    expect(updatedBreakdown.expenses.length, 2);

    final updatedWhereMoney = tester
        .widget<WhereTheMoneyWentWidget>(find.byType(WhereTheMoneyWentWidget));
    expect(updatedWhereMoney.expenses.length, 2);

    expect(find.text('Taxi B'), findsOneWidget);
    expect(find.text(r'$20.11'), findsOneWidget);
    expect(find.text(r'$10.34'), findsOneWidget);
  });
}
