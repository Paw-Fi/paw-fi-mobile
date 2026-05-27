import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';

void main() {
  testWidgets(
      'SpendingCard does not count up again when remounted with same amount',
      (tester) async {
    final now = DateTime(2026, 5, 10);
    final expense = ExpenseEntry(
      id: 'expense-current-month',
      date: DateTime(2026, 5, 10),
      amountCents: 12345,
      currency: 'USD',
      type: 'expense',
      createdAt: now,
    );

    Widget buildCard(Key key) {
      return MaterialApp(
        home: Scaffold(
          body: SpendingCard(
            key: key,
            colorScheme: ThemeData.light().colorScheme,
            expenses: [expense],
            contact: null,
            dateFilter: DateRangeFilter.thisMonth,
            referenceNow: now,
            selectedCurrency: 'USD',
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCard(const ValueKey('first')));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(r'$123.45'), findsOneWidget);

    await tester.pumpWidget(buildCard(const ValueKey('reconciled')));

    expect(find.text(r'$123.45'), findsOneWidget);
    expect(find.text(r'$0'), findsNothing);
  });

  testWidgets('SpendingCard still animates real amount changes',
      (tester) async {
    final now = DateTime(2026, 5, 10);

    Widget buildCard(int amountCents) {
      return MaterialApp(
        home: Scaffold(
          body: SpendingCard(
            key: const ValueKey('stable-spending-card'),
            colorScheme: ThemeData.light().colorScheme,
            expenses: [
              ExpenseEntry(
                id: 'expense-current-month',
                date: DateTime(2026, 5, 10),
                amountCents: amountCents,
                currency: 'USD',
                type: 'expense',
                createdAt: now,
              ),
            ],
            contact: null,
            dateFilter: DateRangeFilter.thisMonth,
            referenceNow: now,
            selectedCurrency: 'USD',
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCard(10000));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(r'$100'), findsOneWidget);

    await tester.pumpWidget(buildCard(20000));

    expect(find.text(r'$100'), findsOneWidget);
    expect(find.text(r'$200'), findsNothing);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(r'$200'), findsOneWidget);
  });

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
