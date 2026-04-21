import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';

void main() {
  testWidgets('SpendingCard uses referenceNow for thisMonth boundaries',
      (tester) async {
    final now = DateTime.now();
    final previousMonthReference = DateTime(now.year, now.month - 1, 15);
    final expenseInCurrentMonth = ExpenseEntry(
      id: 'expense-current-month',
      date: DateTime(now.year, now.month, 10),
      amountCents: 12345,
      currency: 'USD',
      type: 'expense',
      createdAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpendingCard(
            colorScheme: ThemeData.light().colorScheme,
            expenses: [expenseInCurrentMonth],
            contact: null,
            dateFilter: DateRangeFilter.thisMonth,
            referenceNow: previousMonthReference,
            selectedCurrency: 'USD',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.textContaining(r'$0'), findsOneWidget);
  });
}
