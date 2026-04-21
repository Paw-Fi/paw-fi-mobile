import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/home/presentation/utils/transactions_page_derived_data.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

ExpenseEntry _entry({
  required String id,
  required DateTime date,
  required int amountCents,
  String? householdId,
  String? currency,
  String? category,
  String? rawText,
  String? type,
  bool isRecurring = false,
}) {
  return ExpenseEntry(
    id: id,
    householdId: householdId,
    date: date,
    amountCents: amountCents,
    currency: currency,
    category: category,
    rawText: rawText,
    type: type,
    isRecurring: isRecurring,
    createdAt: date,
  );
}

void main() {
  group('deriveTransactionsPageData', () {
    test('filters, merges projected recurring items, and sorts newest first',
        () {
      final result = deriveTransactionsPageData(
        TransactionsPageFilterInput(
          baseExpenses: [
            _entry(
              id: 'personal-expense',
              date: DateTime(2026, 4, 4),
              amountCents: 1200,
              currency: 'usd',
              category: 'Food',
              rawText: 'Lunch bowl',
            ),
            _entry(
              id: 'personal-income',
              date: DateTime(2026, 4, 3),
              amountCents: 500000,
              currency: 'USD',
              category: 'Salary',
              type: 'income',
            ),
            _entry(
              id: 'household-expense',
              date: DateTime(2026, 4, 2),
              amountCents: 7000,
              householdId: 'house-1',
              currency: 'USD',
              category: 'Rent',
            ),
            _entry(
              id: 'template-recurring',
              date: DateTime(2026, 4, 1),
              amountCents: 900,
              currency: 'USD',
              category: 'Bills',
              isRecurring: true,
            ),
          ],
          projectedRecurringExpenses: [
            _entry(
              id: 'projected-household',
              date: DateTime(2026, 4, 5),
              amountCents: 1500,
              householdId: 'house-1',
              currency: 'USD',
              category: 'Bills',
            ),
          ],
          searchQuery: '',
          selectedCategory: 'all',
          selectedType: 'all',
          selectedCurrency: 'USD',
          selectedDateFilter: DateRangeFilter.allTime,
          customStart: null,
          customEnd: null,
          now: DateTime(2026, 4, 5),
          pinnedHouseholdId: null,
          activeAccountType: ActiveWalletType.household,
          activeAccountHouseholdId: 'house-1',
          selectedHouseholdId: 'house-1',
        ),
      );

      expect(
        result.filteredExpenses.map((expense) => expense.id).toList(),
        ['projected-household', 'household-expense'],
      );
      expect(result.categories, ['all', 'food', 'rent', 'salary']);
      expect(result.monthGroups, hasLength(1));
    });

    test('applies search, type, and custom date range together', () {
      final result = deriveTransactionsPageData(
        TransactionsPageFilterInput(
          baseExpenses: [
            _entry(
              id: 'match',
              date: DateTime(2026, 4, 10),
              amountCents: 2500,
              currency: 'USD',
              category: 'Food',
              rawText: 'Team lunch',
            ),
            _entry(
              id: 'wrong-type',
              date: DateTime(2026, 4, 10),
              amountCents: 200000,
              currency: 'USD',
              category: 'Food',
              rawText: 'Salary lunch stipend',
              type: 'income',
            ),
            _entry(
              id: 'outside-range',
              date: DateTime(2026, 3, 31),
              amountCents: 1800,
              currency: 'USD',
              category: 'Food',
              rawText: 'Lunch outside range',
            ),
          ],
          projectedRecurringExpenses: const [],
          searchQuery: 'lunch',
          selectedCategory: 'food',
          selectedType: 'expense',
          selectedCurrency: 'USD',
          selectedDateFilter: DateRangeFilter.custom,
          customStart: DateTime(2026, 4, 1),
          customEnd: DateTime(2026, 4, 30),
          now: DateTime(2026, 4, 30),
          pinnedHouseholdId: null,
          activeAccountType: ActiveWalletType.personal,
          activeAccountHouseholdId: null,
          selectedHouseholdId: null,
        ),
      );

      expect(result.filteredExpenses.map((expense) => expense.id).toList(),
          ['match']);
    });
  });

  group('buildVisibleTransactionRenderItems', () {
    test(
        'keeps entire day together when the requested visible count lands mid-day',
        () {
      final monthGroups = groupTransactionsByMonth([
        _entry(id: 'a', date: DateTime(2026, 4, 10), amountCents: 100),
        _entry(id: 'b', date: DateTime(2026, 4, 10), amountCents: 200),
        _entry(id: 'c', date: DateTime(2026, 4, 9), amountCents: 300),
      ]);

      final items = buildVisibleTransactionRenderItems(
        monthGroups: monthGroups,
        visibleExpenseCount: 1,
      );

      expect(items.where((item) => item.isMonthHeader), hasLength(1));
      expect(items.where((item) => item.isDayHeader), hasLength(1));
      expect(
        items
            .where((item) => item.expense != null)
            .map((item) => item.expense!.id)
            .toList(),
        ['a', 'b'],
      );
      expect(items.last.isLast, isTrue);
    });

    test('continues into following day without duplicating headers', () {
      final monthGroups = groupTransactionsByMonth([
        _entry(id: 'a', date: DateTime(2026, 4, 10), amountCents: 100),
        _entry(id: 'b', date: DateTime(2026, 4, 9), amountCents: 200),
        _entry(id: 'c', date: DateTime(2026, 4, 8), amountCents: 300),
      ]);

      final items = buildVisibleTransactionRenderItems(
        monthGroups: monthGroups,
        visibleExpenseCount: 2,
      );

      expect(items.where((item) => item.isMonthHeader), hasLength(1));
      expect(items.where((item) => item.isDayHeader), hasLength(2));
      expect(
        items
            .where((item) => item.expense != null)
            .map((item) => item.expense!.id)
            .toList(),
        ['a', 'b'],
      );
    });
  });
}
