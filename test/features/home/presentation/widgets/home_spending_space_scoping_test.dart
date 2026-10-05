import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/budget_companion_card.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/dashboard_lazy_widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/household_dashboard_lazy_widgets.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'u1', email: 'test@example.com');
}

class _Store extends HomePeriodSelectionStore {
  @override
  Future<HomePeriodSelectionState?> load(String userId) async => null;
}

class _Recurring extends RecurringTransactionsNotifier {
  _Recurring(super.ref, super.householdId) {
    state = RecurringTransactionsState(
        data: const AsyncData([]), hasLoadedOnce: true);
  }
}

void main() {
  const privateId = '00000000-0000-0000-0000-000000000001';
  const sharedId = '00000000-0000-0000-0000-000000000002';
  const otherId = '00000000-0000-0000-0000-000000000003';
  HouseholdScope scope(String? id) => HouseholdScope(
      viewMode: id == null ? ViewMode.personal : ViewMode.household,
      selected: SelectedHouseholdState(householdId: id),
      portfolioHouseholdIds: {privateId});
  ExpenseEntry row(String id, String? space, String user, int cents, int month,
          String category) =>
      ExpenseEntry(
          id: id,
          householdId: space,
          userId: user,
          amountCents: cents,
          category: category,
          date: DateTime(2026, month, 10),
          createdAt: DateTime(2026, month, 10),
          currency: 'EUR');
  final current = [
    row('personal', null, 'u1', 84000, 5, 'shopping'),
    row('private', privateId, 'u1', 21000, 5, 'rent'),
    row('shared-own', sharedId, 'u1', 30000, 5, 'food'),
    row('shared-member', sharedId, 'u2', 12000, 5, 'food'),
    row('other-space', otherId, 'u3', 999999, 5, 'travel'),
    row('other-actor', null, 'u9', 999999, 5, 'travel'),
  ];
  final previous = [
    row('personal-prior', null, 'u1', 91200, 4, 'shopping'),
    row('private-prior', privateId, 'u1', 30000, 4, 'rent'),
    row('shared-prior', sharedId, 'u2', 45600, 4, 'food'),
  ];

  testWidgets(
      'companion and daily chart remain isolated while switching Personal Private Shared and pending scopes',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = StateProvider<HouseholdScope>((ref) => scope(null));
    final loads = <DashboardScopeQuery, int>{};
    final budgetReads = <PocketsScopeParams>[];
    final privateRead = Completer<List<ExpenseEntry>>();
    var delayPrivate = false;
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      currentUserIdProvider.overrideWithValue('u1'),
      householdScopeProvider.overrideWith((ref) => ref.watch(selected)),
      homeFilterProvider.overrideWith(
          (ref) => HomeFilterNotifier()..setSelectedCurrency('EUR')),
      selectedHomeCurrencyCodeProvider.overrideWithValue('EUR'),
      homePeriodSelectionStoreProvider.overrideWithValue(_Store()),
      homePeriodClockProvider.overrideWithValue(() => DateTime(2026, 5, 10)),
      homePeriodFinancialMonthStartDayProvider.overrideWithValue(1),
      includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => false),
      recurringTransactionsProvider
          .overrideWith((ref, id) => _Recurring(ref, id)),
      dashboardLocalOverlayTransactionsProvider.overrideWith((ref, q) => []),
      recurringOccurrenceProjectionResolutionProvider.overrideWith(
          (ref, q) => const RecurringOccurrenceProjectionResolution()),
      dashboardCalendarTransactionsProvider.overrideWith((ref, q) {
        expect(q.userId, 'u1');
        expect(q.normalizedCurrency, 'EUR');
        loads.update(q, (count) => count + 1, ifAbsent: () => 1);
        if (delayPrivate &&
            q.householdId == privateId &&
            q.startDate!.month == 5) {
          return privateRead.future;
        }
        return Future.value(q.startDate!.month == 5 ? current : previous);
      }),
      budgetCompanionMonthlySummaryProvider.overrideWith((ref, params) {
        budgetReads.add(params);
        expect(params.currency, 'EUR');
        expect(params.normalizedPeriodMonth, DateTime(2026, 5));
        final (spent, budget) = switch (params.scope) {
          PocketsScopeType.personal => (840.0, 3000.0),
          PocketsScopeType.portfolio => (210.0, 2000.0),
          PocketsScopeType.household => (420.0, 1000.0),
        };
        expect(
            params.householdId,
            params.scope == PocketsScopeType.personal
                ? null
                : params.scope == PocketsScopeType.portfolio
                    ? privateId
                    : sharedId);
        return AsyncData(BudgetCompanionSummary(spent: spent, budget: budget));
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: Scaffold(body: Consumer(builder: (context, ref, _) {
            final active = ref.watch(householdScopeProvider);
            final shared = Household(
                id: sharedId,
                name: 'Shared',
                ownerId: 'u1',
                currency: 'EUR',
                createdAt: DateTime(2026, 1),
                updatedAt: DateTime(2026, 1));
            return CustomScrollView(slivers: [
              const SliverToBoxAdapter(
                  child: LazyDashboardBudgetCompanionCard()),
              SliverToBoxAdapter(
                  child: active.isHouseholdView
                      ? LazyHouseholdSpentByYouCard(
                          household: shared,
                          config: const DashboardWidgetConfig(
                              id: 'daily',
                              type: DashboardWidgetType.householdSpentByYou,
                              order: 0),
                          selectedCurrency: 'EUR',
                          referenceNow: DateTime(2026, 5, 10))
                      : LazyDashboardSpendingSummaryCard(
                          config: const DashboardWidgetConfig(
                              id: 'daily',
                              type: DashboardWidgetType.spendingSummary,
                              order: 0),
                          colorScheme: Theme.of(context).colorScheme,
                          contact: null,
                          userNow: DateTime(2026, 5, 10))),
            ]);
          })),
        )));
    Future<void> settleData() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settleData();
    expect(find.text('€840'), findsWidgets);
    expect(find.text('€84/day'), findsOneWidget);
    expect(find.text('spent of €3,000'), findsOneWidget);
    expect(find.text('8% from last month'), findsOneWidget);

    container.read(selected.notifier).state = scope(privateId);
    await settleData();
    expect(find.text('€210'), findsWidgets);
    expect(find.text('€21/day'), findsOneWidget);
    expect(find.text('spent of €2,000'), findsOneWidget);
    expect(find.text('30% from last month'), findsOneWidget);
    expect(find.text('€840'), findsNothing);

    container.read(selected.notifier).state = scope(sharedId);
    await settleData();
    expect(find.text('€420'), findsWidgets);
    expect(find.text('€42/day'), findsOneWidget);
    expect(find.text('spent of €1,000'), findsOneWidget);
    expect(find.text('8% from last month'), findsOneWidget);
    expect(find.text('€210'), findsNothing);
    expect(loads.values.every((count) => count == 1), isTrue,
        reason: 'companion and average must share each calendar-family read');
    expect(budgetReads.length, 3,
        reason: 'companion must not read a previous-month budget');

    container.read(selected.notifier).state = const HouseholdScope(
        viewMode: ViewMode.household,
        selected: SelectedHouseholdState(isLoading: true),
        portfolioHouseholdIds: {privateId});
    await settleData();
    expect(find.byType(BudgetCompanionSkeleton), findsOneWidget);
    expect(find.text('€840'), findsNothing);
    expect(find.text('€42/day'), findsNothing);
    expect(budgetReads.length, 3);

    delayPrivate = true;
    container.invalidate(dashboardCalendarTransactionsProvider(loads.keys
        .firstWhere(
            (q) => q.householdId == privateId && q.startDate!.month == 5)));
    container.read(selected.notifier).state = scope(privateId);
    await settleData();
    container.read(selected.notifier).state = scope(sharedId);
    await settleData();
    privateRead.complete(current);
    await settleData();
    expect(find.text('€42/day'), findsOneWidget);
    expect(find.text('€21/day'), findsNothing,
        reason: 'late Private response cannot replace Shared metrics');
    expect(tester.takeException(), isNull);
  });
}
