import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');
}

void main() {
  ExpenseEntry expense({
    required String id,
    required DateTime date,
    required int amountCents,
    String currency = 'USD',
    String type = 'expense',
    String category = 'food',
    String? rawText,
    bool isRecurring = false,
    String? splitGroupId,
  }) {
    return ExpenseEntry(
      id: id,
      userId: 'user-1',
      date: date,
      amountCents: amountCents,
      currency: currency,
      category: category,
      rawText: rawText,
      createdAt: date,
      type: type,
      isRecurring: isRecurring,
      splitGroupId: splitGroupId,
    );
  }

  test('uses the same three custom financial cycles and native currency filter',
      () {
    final totals = calculateMomTrend(
      actualTransactions: <ExpenseEntry>[
        expense(
          id: 'current',
          date: DateTime(2026, 7, 16),
          amountCents: 1000,
        ),
        expense(
          id: 'previous',
          date: DateTime(2026, 7, 14),
          amountCents: 2000,
        ),
        expense(
          id: 'oldest',
          date: DateTime(2026, 6, 14),
          amountCents: 3000,
        ),
        expense(
          id: 'foreign',
          date: DateTime(2026, 7, 17),
          amountCents: 4000,
          currency: 'EUR',
        ),
        expense(
          id: 'income',
          date: DateTime(2026, 7, 18),
          amountCents: 5000,
          type: 'income',
        ),
        expense(
          id: 'household-split',
          date: DateTime(2026, 7, 18),
          amountCents: 6000,
          splitGroupId: '00000000-0000-0000-0000-000000000001',
        ),
      ],
      recurringTransactions: const <RecurringTransaction>[],
      now: DateTime(2026, 7, 20),
      financialMonthStartDay: 15,
      selectedCurrency: 'USD',
    );

    expect(totals, <String, double>{
      '2026-07-15': 10,
      '2026-06-15': 20,
      '2026-05-15': 30,
    });
  });

  test('keeps recurring projection and actual-occurrence deduplication exact',
      () {
    final recurring = RecurringTransaction(
      id: 'netflix-recurring',
      userId: 'user-1',
      date: DateTime(2026, 5, 1),
      category: 'subscriptions',
      description: 'netflix',
      amount: 10,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 5, 1),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 5, 1),
    );
    final actualJulyOccurrence = expense(
      id: 'saved-july-occurrence',
      date: DateTime(2026, 7, 1),
      amountCents: 1000,
      category: 'subscriptions',
      rawText: 'netflix',
    );

    final totals = calculateMomTrend(
      actualTransactions: <ExpenseEntry>[actualJulyOccurrence],
      recurringTransactions: <RecurringTransaction>[recurring],
      now: DateTime(2026, 7, 20),
      financialMonthStartDay: 1,
      selectedCurrency: 'USD',
    );

    expect(totals, <String, double>{
      '2026-07-01': 10,
      '2026-06-01': 10,
      '2026-05-01': 10,
    });
  });

  test('does not count recurring schedule templates as posted expenses', () {
    final totals = calculateMomTrend(
      actualTransactions: <ExpenseEntry>[
        expense(
          id: 'schedule-template',
          date: DateTime(2026, 7, 1),
          amountCents: 2500,
          isRecurring: true,
        ),
        expense(
          id: 'posted-expense',
          date: DateTime(2026, 7, 2),
          amountCents: 1000,
        ),
      ],
      recurringTransactions: const <RecurringTransaction>[],
      now: DateTime(2026, 7, 20),
      financialMonthStartDay: 1,
      selectedCurrency: 'USD',
    );

    expect(totals['2026-07-01'], 10);
  });

  test('month-over-month card keeps a private portfolio space scope', () async {
    DashboardScopeQuery? capturedQuery;
    String? capturedRecurringHouseholdId;
    var recurringProviderWasRead = false;
    const scope = HouseholdScope(
      viewMode: ViewMode.household,
      selected: SelectedHouseholdState(householdId: 'private-space'),
      portfolioHouseholdIds: {'private-space'},
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_TestAuth.new),
        householdScopeProvider.overrideWithValue(scope),
        dashboardOwnedRangeTransactionsProvider.overrideWith(
          (ref, query) async {
            capturedQuery = query;
            return const <ExpenseEntry>[];
          },
        ),
        recurringExpensesProvider.overrideWith(
          (ref, householdId) {
            recurringProviderWasRead = true;
            capturedRecurringHouseholdId = householdId;
            return const AsyncValue.data(<RecurringTransaction>[]);
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    container.listen(momTrendProvider, (_, __) {}, fireImmediately: true);
    await Future<void>.delayed(Duration.zero);

    expect(capturedQuery?.householdId, 'private-space');
    expect(recurringProviderWasRead, isTrue);
    expect(capturedRecurringHouseholdId, 'private-space');
  });
}
