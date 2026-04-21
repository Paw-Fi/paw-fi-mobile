import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/widgets/where_the_money_went_widget.dart';

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
}
