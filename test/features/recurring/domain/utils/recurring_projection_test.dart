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
