import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/household_dashboard_lazy_widgets.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _EmptyHomePeriodSelectionStore extends HomePeriodSelectionStore {
  @override
  Future<HomePeriodSelectionState?> load(String userId) async => null;
  @override
  Future<void> save(String userId, HomePeriodSelectionState state) async {}
}

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'u1', email: 'test@example.com');
}

class _Recurring extends RecurringTransactionsNotifier {
  _Recurring(super.ref, super.householdId) {
    state = RecurringTransactionsState(
        data: const AsyncData([]), hasLoadedOnce: true);
  }
}

void main() {
  const householdId = '00000000-0000-0000-0000-000000000001';
  final household = Household(
      id: householdId,
      name: 'Home',
      ownerId: 'u1',
      currency: 'EUR',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1));

  for (final loading in [false, true]) {
    testWidgets(
        'shared Space daily spending ${loading ? 'loads without fake values' : 'includes all members and comparison'}',
        (tester) async {
      final pending = Completer<List<ExpenseEntry>>();
      ExpenseEntry row(String id, String user, int cents, DateTime date) =>
          ExpenseEntry(
              id: id,
              userId: user,
              householdId: householdId,
              date: date,
              createdAt: date,
              amountCents: cents,
              currency: 'EUR');
      await tester.pumpWidget(ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            currentUserIdProvider.overrideWithValue('u1'),
            householdScopeProvider.overrideWithValue(const HouseholdScope(
                viewMode: ViewMode.household,
                selected: SelectedHouseholdState(householdId: householdId),
                portfolioHouseholdIds: {})),
            homeFilterProvider.overrideWith(
                (ref) => HomeFilterNotifier()..setSelectedCurrency('EUR')),
            selectedHomeCurrencyCodeProvider.overrideWithValue('EUR'),
            homePeriodSelectionStoreProvider
                .overrideWithValue(_EmptyHomePeriodSelectionStore()),
            homePeriodClockProvider
                .overrideWithValue(() => DateTime(2026, 5, 10)),
            homePeriodFinancialMonthStartDayProvider.overrideWithValue(1),
            recurringTransactionsProvider
                .overrideWith((ref, id) => _Recurring(ref, id)),
            dashboardLocalOverlayTransactionsProvider
                .overrideWith((ref, q) => []),
            recurringOccurrenceProjectionResolutionProvider.overrideWith(
                (ref, q) => const RecurringOccurrenceProjectionResolution()),
            dashboardCalendarTransactionsProvider.overrideWith((ref, q) {
              expect(q.householdId, householdId);
              if (loading) return pending.future;
              return Future.value(q.startDate!.month == 5
                  ? [
                      row('own', 'u1', 30000, DateTime(2026, 5, 10)),
                      row('member', 'u2', 12000, DateTime(2026, 5, 10))
                    ]
                  : [row('previous', 'u2', 45600, DateTime(2026, 4, 10))]);
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: LazyHouseholdSpentByYouCard(
                    household: household,
                    config: const DashboardWidgetConfig(
                        id: 'spending',
                        type: DashboardWidgetType.householdSpentByYou,
                        order: 0),
                    selectedCurrency: 'EUR',
                    referenceNow: DateTime(2026, 5, 10))),
          )));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('AVERAGE DAILY SPEND'), findsOneWidget);
      if (loading) {
        expect(find.byKey(const ValueKey('spending_skeleton')), findsOneWidget);
        expect(find.text('€42/day'), findsNothing);
      } else {
        expect(find.text('€42/day'), findsOneWidget);
        expect(find.text('8% from last month'), findsOneWidget);
        expect(find.text('€30/day'), findsNothing,
            reason: 'must not substitute the current member share');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'household recent transactions requests only the selected financial period',
      (tester) async {
    DashboardRecentTransactionsRequest? capturedRequest;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          homePeriodSelectionStoreProvider
              .overrideWithValue(_EmptyHomePeriodSelectionStore()),
          homePeriodClockProvider
              .overrideWithValue(() => DateTime(2026, 4, 20)),
          homePeriodFinancialMonthStartDayProvider.overrideWithValue(1),
          dashboardRecentTransactionsProvider.overrideWith((ref, request) {
            capturedRequest = request;
            return Future.value(const <ExpenseEntry>[]);
          }),
          upcomingRecurringTransactionProvider(const UpcomingRecurringScope(
                  householdId: householdId, currency: 'USD'))
              .overrideWithValue(null),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: LazyHouseholdRecentTransactionsCard(
                    household: household, selectedCurrency: 'USD')))));
    await tester.pumpAndSettle();
    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.query.startDate, DateTime(2026, 4, 1));
    expect(capturedRequest!.query.endDate, DateTime(2026, 4, 30));
    expect(find.text('No transactions found'), findsOneWidget);
  });
}
