import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/spending_daily_overview_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/dashboard_lazy_widgets.dart';
import 'package:moneko/features/home/presentation/widgets/budget_companion_card.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GuestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: '', email: '');
}

void main() {
  for (final householdId in [null, 'preview-house-1', 'preview-card']) {
    for (final mode in HomePeriodMode.values) {
      test('preview $householdId $mode resolves without live reads', () {
        final now = DateTime.now();
        final query = DashboardScopeQuery(
          userId: PreviewMockData.contact.userId!,
          householdId: householdId,
          selectedCurrency: 'USD',
          selectedCurrencies: const ['USD', 'EUR'],
          startDate: mode == HomePeriodMode.daily
              ? DateTime(now.year, now.month, now.day)
              : DateTime(now.year, now.month),
          endDate: mode == HomePeriodMode.daily
              ? DateTime(now.year, now.month, now.day, 23, 59, 59)
              : DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        var databaseReads = 0;
        var rateReads = 0;
        final container = ProviderContainer(overrides: [
          authProvider.overrideWith(_GuestAuth.new),
          previewModeProvider.overrideWith(
              (ref) => PreviewModeNotifier(initiallyActive: true)),
          localDatabaseProvider.overrideWith((ref) {
            databaseReads++;
            return Completer<MonekoDatabase>().future;
          }),
          currencyRateTableProvider.overrideWith((ref) {
            rateReads++;
            throw StateError('Preview must use mock exchange rates');
          }),
          selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
          includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => true),
          budgetCompanionRequestProvider.overrideWithValue(
            BudgetCompanionRequest(
              query: query,
              mode: mode,
              currency: 'USD',
              pocketsScope: PocketsScopeParams(
                scope: householdId == null
                    ? PocketsScopeType.personal
                    : householdId == 'preview-card'
                        ? PocketsScopeType.portfolio
                        : PocketsScopeType.household,
                householdId: householdId,
                currency: 'USD',
                periodMonth: query.startDate,
              ),
            ),
          ),
        ]);
        addTearDown(container.dispose);
        container.listen(budgetCompanionDataProvider, (_, __) {});
        final overviewRequest =
            SpendingDailyOverviewQuery(query: query, now: now);
        container.listen(
            spendingDailyOverviewProvider(overviewRequest), (_, __) {});

        final companion = container.read(budgetCompanionDataProvider);
        expect(companion.summary.hasValue, isTrue);
        expect(companion.categories.hasValue, isTrue);
        expect(companion.isRefreshing, isFalse);
        if (mode == HomePeriodMode.monthly) {
          expect(
              companion.summary.requireValue.budget,
              PreviewMockData.pockets.fold<double>(
                  0, (sum, pocket) => sum + pocket.budgetAmountCents / 100));
          expect(
              companion.summary.requireValue.spent,
              PreviewMockData.pockets
                  .fold<double>(0, (sum, pocket) => sum + pocket.spent));
        }

        final overview =
            container.read(spendingDailyOverviewProvider(overviewRequest));
        expect(overview.hasValue, isTrue);
        expect(overview.requireValue.previousAverage.hasValue, isTrue);
        expect(
            overview.requireValue.transactions.every((row) =>
                row.householdId == householdId &&
                query.allowsCurrency(row.currency)),
            isTrue);
        expect(databaseReads, 0);
        expect(rateReads, 0);
      });
    }
  }

  testWidgets(
      'guest preview resolves default household mode and renders both cards',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final theme = AppTheme.lightTheme();
    final now = DateTime.now();
    var databaseReads = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_GuestAuth.new),
        previewModeProvider
            .overrideWith((ref) => PreviewModeNotifier(initiallyActive: true)),
        localDatabaseProvider.overrideWith((ref) {
          databaseReads++;
          return Completer<MonekoDatabase>().future;
        }),
        selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
        homePeriodClockProvider.overrideWithValue(() => now),
        homePeriodFinancialMonthStartDayProvider.overrideWithValue(1),
        sharedPreferencesProvider.overrideWithValue(prefs),
        includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => true),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [
                const LazyDashboardBudgetHeader(),
                const LazyDashboardBudgetCompanionCard(),
                LazyDashboardSpendingSummaryCard(
                  config: const DashboardWidgetConfig(
                      id: 'preview-spending',
                      type: DashboardWidgetType.spendingSummary,
                      order: 0),
                  colorScheme: theme.colorScheme,
                  contact: PreviewMockData.contact,
                  userNow: now,
                ),
              ]),
            ),
          ),
        ),
      ),
    ));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(LazyDashboardBudgetCompanionCard)));
    expect(container.read(viewModeProvider).mode, ViewMode.household);
    expect(container.read(selectedHouseholdProvider).householdId, isNull);
    expect(container.read(householdScopeProvider).viewMode, ViewMode.personal);
    expect(container.read(budgetCompanionRequestProvider), isNotNull);
    expect(find.byType(BudgetCompanionCard), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    final spending = tester.widget<SpendingCard>(find.byType(SpendingCard));
    expect(spending.overview, isNotNull);
    expect(spending.overview!.previousAverage.hasValue, isTrue);
    expect(find.byType(Skeletonizer), findsNothing);
    expect(
        find.byKey(const ValueKey('budget-companion-content')), findsOneWidget);
    expect(databaseReads, 0);
    expect(tester.takeException(), isNull);
  });
}
