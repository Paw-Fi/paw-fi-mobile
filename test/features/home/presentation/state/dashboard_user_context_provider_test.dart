import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/daily_budget_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_user_context_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

void main() {
  test('private portfolio dashboard does not reuse personal-account budgets',
      () async {
    var personalBudgetsProviderWasRead = false;
    final container = ProviderContainer(
      overrides: [
        householdScopeProvider.overrideWithValue(
          const HouseholdScope(
            viewMode: ViewMode.household,
            selected: SelectedHouseholdState(householdId: 'private-space'),
            portfolioHouseholdIds: {'private-space'},
          ),
        ),
        dashboardPersonalBudgetsProvider.overrideWith((ref) async {
          personalBudgetsProviderWasRead = true;
          return <DailyBudgetEntry>[
            DailyBudgetEntry(
              id: 'budget-1',
              date: DateTime(2026, 7, 1),
              amountCents: 2500,
              currency: 'USD',
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);

    final budgets = await container.read(
      dashboardActiveScopeBudgetsProvider.future,
    );

    expect(budgets, isEmpty);
    expect(personalBudgetsProviderWasRead, isFalse);
  });
}
