import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/pages/category_details_page.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/widgets/where_the_money_went_widget.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user_1', email: 'test@example.com');
}

void main() {
  testWidgets('WhereTheMoneyWentWidget excludes income entries',
      (tester) async {
    final now = DateTime.now();
    final expenses = <ExpenseEntry>[
      ExpenseEntry(
        id: 'expense-groceries',
        date: now,
        amountCents: 10000,
        currency: 'USD',
        type: 'expense',
        category: 'groceries',
        createdAt: now,
      ),
      ExpenseEntry(
        id: 'income-salary',
        date: now,
        amountCents: 50000,
        currency: 'USD',
        type: 'income',
        category: 'salary',
        createdAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WhereTheMoneyWentWidget(
            expenses: expenses,
            currency: 'USD',
            dateRange: DateRangeFilter.thisMonth,
          ),
        ),
      ),
    );

    expect(find.textContaining(r'$500'), findsNothing);
    expect(find.textContaining(r'$100'), findsOneWidget);
  });

  testWidgets('opens category details with the widget date range',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final date = DateTime(2025, 1, 10);
    final expenses = <ExpenseEntry>[
      ExpenseEntry(
        id: 'expense-groceries',
        date: date,
        amountCents: 10000,
        currency: 'USD',
        type: 'expense',
        category: 'groceries',
        createdAt: date,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_MockAuth.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
          householdScopeProvider.overrideWithValue(
            const HouseholdScope(
              viewMode: ViewMode.personal,
              selected: SelectedHouseholdState(),
              portfolioHouseholdIds: {},
            ),
          ),
          transactionsFeedServiceProvider.overrideWithValue(
            const EmptyTransactionsFeedService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WhereTheMoneyWentWidget(
              expenses: expenses,
              currency: 'USD',
              dateRange: DateRangeFilter.allTime,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    final page = tester.widget<CategoryDetailsPage>(
      find.byType(CategoryDetailsPage),
    );
    expect(page.categoryKey, 'groceries');
    expect(page.initialDateFilter, DateRangeFilter.allTime);
  });
}
