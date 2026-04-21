import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

void main() {
  test('projects every 6 month recurring transactions and preserves source id',
      () {
    final transaction = RecurringTransaction(
      id: 'rec_source',
      date: DateTime(2026, 1, 10),
      category: 'insurance',
      description: 'Insurance renewal',
      amount: 120.0,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 1, 10),
        interval: 6,
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    final projected = projectRecurringTransactionsAsExpenseEntries(
      recurringTransactions: [transaction],
      rangeStart: DateTime(2026, 7, 1),
      rangeEnd: DateTime(2026, 7, 31),
      selectedCurrency: 'USD',
    );

    expect(projected, hasLength(1));
    expect(projected.single.date, DateTime(2026, 7, 10));
    expect(
      extractRecurringTransactionIdFromProjectedExpenseId(projected.single.id),
      'rec_source',
    );
  });

  test('projects only upcoming recurring expense occurrences for current month',
      () {
    final recurringExpense = RecurringTransaction(
      id: 'rent',
      date: DateTime(2026, 3, 28),
      category: 'housing',
      description: 'Flat rent',
      amount: 950.0,
      currency: 'GBP',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 1, 28),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 1, 1),
    );
    final recurringIncome = RecurringTransaction(
      id: 'salary',
      date: DateTime(2026, 3, 25),
      category: 'income',
      description: 'Salary',
      amount: 2500.0,
      currency: 'GBP',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 1, 25),
      ),
      type: 'income',
      attachments: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    final projected = projectUpcomingRecurringTransactionsAsExpenseEntries(
      recurringTransactions: [recurringExpense, recurringIncome],
      monthStart: DateTime(2026, 3, 1),
      now: DateTime(2026, 3, 20),
      selectedCurrency: 'GBP',
    );

    expect(projected, hasLength(1));
    expect(projected.single.id,
        buildProjectedRecurringExpenseId('rent', DateTime(2026, 3, 28)));
    expect(projected.single.amountCents, 95000);
  });

  test('does not project future recurring spending for past months', () {
    final transaction = RecurringTransaction(
      id: 'rent',
      date: DateTime(2026, 2, 28),
      category: 'housing',
      description: 'Flat rent',
      amount: 950.0,
      currency: 'GBP',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 1, 28),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    final projected = projectUpcomingRecurringTransactionsAsExpenseEntries(
      recurringTransactions: [transaction],
      monthStart: DateTime(2026, 2, 1),
      now: DateTime(2026, 3, 20),
      selectedCurrency: 'GBP',
    );

    expect(projected, isEmpty);
  });

  test(
      'projects overdue current-month recurring occurrence when anchor day already passed',
      () {
    final transaction = RecurringTransaction(
      id: 'utilities',
      date: DateTime(2026, 4, 1),
      category: 'utilities',
      description: 'Monthly utilities',
      amount: 120.0,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 4, 1),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 4, 3),
    );

    final projected = projectUpcomingRecurringTransactionsAsExpenseEntries(
      recurringTransactions: [transaction],
      monthStart: DateTime(2026, 4, 1),
      now: DateTime(2026, 4, 3),
      selectedCurrency: 'USD',
    );

    expect(projected, hasLength(1));
    expect(projected.single.id,
        buildProjectedRecurringExpenseId('utilities', DateTime(2026, 4, 1)));
    expect(projected.single.amountCents, 12000);
  });

  test('dedupes projected recurring entries when actual expense already exists',
      () {
    final projected = ExpenseEntry(
      id: buildProjectedRecurringExpenseId('rent', DateTime(2026, 3, 28)),
      userId: 'user_1',
      date: DateTime(2026, 3, 28),
      amountCents: 95000,
      currency: 'GBP',
      category: 'housing',
      createdAt: DateTime(2026, 3, 20),
      rawText: 'Flat rent',
      type: 'expense',
    );
    final actual = ExpenseEntry(
      id: 'actual_rent_payment',
      userId: 'user_1',
      date: DateTime(2026, 3, 28),
      amountCents: 95000,
      currency: 'GBP',
      category: 'housing',
      createdAt: DateTime(2026, 3, 28),
      rawText: 'Flat rent',
      type: 'expense',
    );

    final deduped = dedupeProjectedRecurringExpenseEntries(
      projectedExpenses: [projected],
      actualExpenses: [actual],
    );

    expect(deduped, isEmpty);
  });

  test(
      'mergeActualExpensesWithProjectedRecurring counts only overdue occurrences when future entries are disabled',
      () {
    final overdue = RecurringTransaction(
      id: 'rent',
      date: DateTime(2026, 4, 10),
      category: 'housing',
      description: 'Rent',
      amount: 950.0,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 4, 10),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 4, 1),
    );
    final upcoming = RecurringTransaction(
      id: 'internet',
      date: DateTime(2026, 4, 25),
      category: 'bills',
      description: 'Internet',
      amount: 50.0,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 4, 25),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 4, 1),
    );

    final merged = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: const [],
      recurringTransactions: [overdue, upcoming],
      rangeStart: DateTime(2026, 4, 1),
      rangeEnd: DateTime(2026, 4, 30),
      selectedCurrency: 'USD',
      includeFutureOccurrences: false,
      now: DateTime(2026, 4, 15),
    );

    expect(merged, hasLength(1));
    expect(merged.single.id,
        buildProjectedRecurringExpenseId('rent', DateTime(2026, 4, 10)));
  });

  test(
      'mergeActualExpensesWithProjectedRecurring keeps actual recurring rows and dedupes matching projections',
      () {
    final recurring = RecurringTransaction(
      id: 'rent',
      userId: 'user_1',
      date: DateTime(2026, 4, 10),
      category: 'housing',
      description: 'Rent',
      amount: 950.0,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 4, 10),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 4, 1),
    );
    final actualRecurringExpense = ExpenseEntry(
      id: 'expense_1',
      userId: 'user_1',
      date: DateTime(2026, 4, 10),
      amountCents: 95000,
      currency: 'USD',
      category: 'housing',
      createdAt: DateTime(2026, 4, 10),
      rawText: 'Rent',
      type: 'expense',
      isRecurring: true,
    );

    final merged = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: [actualRecurringExpense],
      recurringTransactions: [recurring],
      rangeStart: DateTime(2026, 4, 1),
      rangeEnd: DateTime(2026, 4, 30),
      selectedCurrency: 'USD',
      includeFutureOccurrences: false,
      now: DateTime(2026, 4, 15),
    );

    expect(merged, hasLength(1));
    expect(merged.single.id, actualRecurringExpense.id);
    expect(merged.single.isRecurring, isTrue);
  });

  test(
      'mergeActualExpensesWithProjectedRecurring does not count future-dated actual recurring rows before they are due',
      () {
    final actualFutureRecurringExpense = ExpenseEntry(
      id: 'expense_future',
      userId: 'user_1',
      date: DateTime(2026, 4, 25),
      amountCents: 95000,
      currency: 'USD',
      category: 'housing',
      createdAt: DateTime(2026, 4, 1),
      rawText: 'Rent',
      type: 'expense',
      isRecurring: true,
    );

    final merged = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: [actualFutureRecurringExpense],
      recurringTransactions: const [],
      rangeStart: DateTime(2026, 4, 1),
      rangeEnd: DateTime(2026, 4, 30),
      selectedCurrency: 'USD',
      includeFutureOccurrences: false,
      now: DateTime(2026, 4, 15),
    );

    expect(merged, isEmpty);
  });

  test(
      'dedupes projected recurring income entries when actual income already exists',
      () {
    final projectedIncome = ExpenseEntry(
      id: buildProjectedRecurringExpenseId('salary', DateTime(2026, 4, 10)),
      userId: 'user_1',
      date: DateTime(2026, 4, 10),
      amountCents: 250000,
      currency: 'USD',
      category: 'income',
      createdAt: DateTime(2026, 4, 1),
      rawText: 'Salary',
      type: 'income',
    );
    final actualIncome = ExpenseEntry(
      id: 'income_1',
      userId: 'user_1',
      date: DateTime(2026, 4, 10),
      amountCents: 250000,
      currency: 'USD',
      category: 'income',
      createdAt: DateTime(2026, 4, 10),
      rawText: 'Salary',
      type: 'income',
      isRecurring: true,
    );

    final deduped = dedupeProjectedRecurringExpenseEntries(
      projectedExpenses: [projectedIncome],
      actualExpenses: [actualIncome],
    );

    expect(deduped, isEmpty);
  });

  test(
      'mergeActualExpensesWithProjectedRecurring includes personal monthly anchor-day occurrence through today',
      () {
    final recurring = RecurringTransaction(
      id: 'personal-rent',
      userId: 'user_1',
      date: DateTime(2026, 1, 12),
      category: 'rent',
      description: '',
      amount: 12000.0,
      currency: 'INR',
      ownerType: 'me',
      privacyScope: 'full',
      householdId: null,
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 1, 12),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 1, 12),
    );

    final merged = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: const [],
      recurringTransactions: [recurring],
      rangeStart: DateTime(2026, 4, 1),
      rangeEnd: DateTime(2026, 4, 30),
      selectedCurrency: 'INR',
      includeFutureOccurrences: false,
      now: DateTime(2026, 4, 15),
    );

    expect(merged, hasLength(1));
    expect(merged.single.date, DateTime(2026, 4, 12));
    expect(
      extractRecurringTransactionIdFromProjectedExpenseId(merged.single.id),
      'personal-rent',
    );
  });

  test(
      'mergeActualExpensesWithProjectedRecurring dedupes household monthly anchor-day projection when actual exists',
      () {
    final recurring = RecurringTransaction(
      id: 'household-rent',
      userId: 'user_1',
      date: DateTime(2026, 3, 10),
      category: 'rent',
      description: '',
      amount: 12000.0,
      currency: 'INR',
      ownerType: 'me',
      privacyScope: 'full',
      householdId: 'house-1',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 3, 10),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 3, 10),
    );
    final actual = ExpenseEntry(
      id: 'actual-house-rent',
      userId: 'user_1',
      householdId: 'house-1',
      date: DateTime(2026, 4, 10),
      amountCents: 1200000,
      currency: 'INR',
      category: 'rent',
      rawText: '',
      type: 'expense',
      createdAt: DateTime(2026, 4, 10),
      isRecurring: true,
    );

    final merged = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: [actual],
      recurringTransactions: [recurring],
      rangeStart: DateTime(2026, 4, 1),
      rangeEnd: DateTime(2026, 4, 30),
      selectedCurrency: 'INR',
      includeFutureOccurrences: false,
      now: DateTime(2026, 4, 15),
    );

    expect(merged, hasLength(1));
    expect(merged.single.id, 'actual-house-rent');
  });

  test(
      'does not collapse distinct recurring expenses that share date and amount',
      () {
    final projected = ExpenseEntry(
      id: buildProjectedRecurringExpenseId('internet', DateTime(2026, 3, 28)),
      userId: 'user_1',
      householdId: 'household_1',
      date: DateTime(2026, 3, 28),
      amountCents: 5000,
      currency: 'GBP',
      category: 'bills',
      createdAt: DateTime(2026, 3, 20),
      rawText: 'Internet',
      type: 'expense',
    );
    final actual = ExpenseEntry(
      id: 'actual_phone_bill',
      userId: 'user_1',
      householdId: 'household_1',
      date: DateTime(2026, 3, 28),
      amountCents: 5000,
      currency: 'GBP',
      category: 'bills',
      createdAt: DateTime(2026, 3, 28),
      rawText: 'Phone',
      type: 'expense',
    );

    final deduped = dedupeProjectedRecurringExpenseEntries(
      projectedExpenses: [projected],
      actualExpenses: [actual],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.id, projected.id);
  });
}
