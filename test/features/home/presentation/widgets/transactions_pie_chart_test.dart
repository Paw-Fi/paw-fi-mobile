import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/category_summary.dart';
import 'package:moneko/features/home/presentation/widgets/transactions_pie_chart.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

ExpenseEntry _entry({
  required String id,
  required String category,
  required int amountCents,
}) {
  final now = DateTime(2026, 4, 28);
  return ExpenseEntry(
    id: id,
    date: now,
    amountCents: amountCents,
    category: category,
    type: 'expense',
    createdAt: now,
  );
}

void main() {
  test('legend summaries keep real other and custom categories navigable', () {
    final summaries = buildTransactionsPieCategorySummaries([
      _entry(id: 'other-1', category: 'Other', amountCents: 1000),
      _entry(id: 'other-2', category: ' other ', amountCents: 2500),
      _entry(id: 'custom-1', category: 'อาหารแมว', amountCents: 3000),
      _entry(id: 'custom-2', category: 'อาหารแมว', amountCents: 4000),
    ]);

    expect(summaries.map((summary) => summary.category).toList(), [
      'อาหารแมว',
      'other',
    ]);
    expect(summaries.first.amount, 70);
    expect(summaries.first.transactionCount, 2);
    expect(summaries.last.amount, 35);
    expect(summaries.last.transactionCount, 2);
    expect(isTransactionsPieCategoryNavigable('other'), isTrue);
    expect(isTransactionsPieCategoryNavigable('อาหารแมว'), isTrue);
    expect(isTransactionsPieCategoryNavigable(null), isTrue);
    expect(isTransactionsPieCategoryNavigable(''), isTrue);
  });

  test('legend summaries do not synthesize overflow into a fake other category',
      () {
    final summaries = buildTransactionsPieCategorySummaries([
      for (var index = 0; index < 8; index++)
        _entry(
          id: 'category-$index',
          category: 'custom $index',
          amountCents: (index + 1) * 100,
        ),
    ]);

    expect(summaries, hasLength(8));
    expect(
      summaries.map((summary) => summary.category),
      isNot(contains('other')),
    );
  });

  test('legend summaries merge built-in separator variants by canonical key',
      () {
    final summaries = buildTransactionsPieCategorySummaries([
      _entry(
        id: 'slash',
        category: 'takeout/delivery',
        amountCents: 1100,
      ),
      _entry(
        id: 'spaced-slash',
        category: 'Takeout / Delivery',
        amountCents: 2200,
      ),
      _entry(
        id: 'canonical',
        category: 'takeout & delivery',
        amountCents: 3300,
      ),
      _entry(
        id: 'custom',
        category: 'cat insurance',
        amountCents: 4400,
      ),
    ]);

    expect(summaries.map((summary) => summary.category).toList(), [
      'takeout & delivery',
      'cat insurance',
    ]);
    expect(summaries.first.amount, 66);
    expect(summaries.first.transactionCount, 3);
    expect(summaries.last.amount, 44);
    expect(summaries.last.transactionCount, 1);
  });

  testWidgets('real other legend card opens category details', (tester) async {
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: Scaffold(
          body: TransactionsPieChart(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            expenses: const [],
            periodLabel: 'This month',
            categorySummariesOverride: [
              CategorySummary(
                category: 'other',
                amount: 35,
                transactionCount: 2,
                color: Colors.blue,
              ),
            ],
            totalSpentOverride: 35,
          ),
        ),
      ),
    );

    expect(observer.pushedRoutes, hasLength(1));

    await tester.tap(find.text('Other'));

    expect(observer.pushedRoutes, hasLength(2));
  });

  testWidgets('legend card surface from real expenses opens category details',
      (tester) async {
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: Scaffold(
          body: TransactionsPieChart(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            expenses: [
              _entry(id: 'other-1', category: ' Other ', amountCents: 3500),
            ],
            periodLabel: 'This month',
          ),
        ),
      ),
    );

    expect(observer.pushedRoutes, hasLength(1));

    await tester
        .tap(find.byKey(const ValueKey('transactions-pie-legend-other')));

    expect(observer.pushedRoutes, hasLength(2));
  });
}
