import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/widgets/household_dashboard_lazy_widgets.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _EmptyHomePeriodSelectionStore extends HomePeriodSelectionStore {
  @override
  Future<HomePeriodSelectionState?> load(String userId) async => null;

  @override
  Future<void> save(String userId, HomePeriodSelectionState state) async {}
}

void main() {
  const householdId = '00000000-0000-0000-0000-000000000001';
  final household = Household(
    id: householdId,
    name: 'Home',
    ownerId: 'u1',
    currency: 'USD',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  testWidgets(
    'household recent transactions requests only the selected financial period',
    (tester) async {
      DashboardRecentTransactionsRequest? capturedRequest;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('u1'),
            homePeriodSelectionStoreProvider
                .overrideWithValue(_EmptyHomePeriodSelectionStore()),
            homePeriodClockProvider.overrideWithValue(
              () => DateTime(2026, 4, 20),
            ),
            homePeriodFinancialMonthStartDayProvider.overrideWithValue(1),
            dashboardRecentTransactionsProvider.overrideWith((ref, request) {
              capturedRequest = request;
              return Future.value(const <ExpenseEntry>[]);
            }),
            upcomingRecurringTransactionProvider(
              const UpcomingRecurringScope(
                householdId: householdId,
                currency: 'USD',
              ),
            ).overrideWithValue(null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LazyHouseholdRecentTransactionsCard(
                household: household,
                selectedCurrency: 'USD',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.query.startDate, DateTime(2026, 4, 1));
      expect(capturedRequest!.query.endDate, DateTime(2026, 4, 30));
      expect(find.text('No transactions found'), findsOneWidget);
    },
  );
}
