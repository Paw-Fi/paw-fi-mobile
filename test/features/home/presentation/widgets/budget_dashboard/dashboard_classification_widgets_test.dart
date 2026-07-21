import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_category_list.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_transactions_list.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_trend_chart.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

void main() {
  testWidgets('refund detail row is not rendered as income', (tester) async {
    final refund = _transaction(
      id: 'refund',
      category: 'shopping',
      type: 'income',
      spendingMultiplier: -1,
      countsTowardIncome: false,
    );

    await tester.pumpWidget(_app(
      DashboardTransactionsList(
        transactions: [refund],
        amountResolver: (_) => -20,
        currency: 'USD',
      ),
    ));

    final tile = tester.widget<TransactionListTile>(
      find.byType(TransactionListTile),
    );
    expect(tile.isIncome, isFalse);
  });

  testWidgets('category list omits refund-only negative categories',
      (tester) async {
    final purchase = _transaction(
      id: 'purchase',
      category: 'food',
      spendingMultiplier: 1,
    );
    final refund = _transaction(
      id: 'refund',
      category: 'shopping',
      type: 'income',
      spendingMultiplier: -1,
      countsTowardIncome: false,
    );

    await tester.pumpWidget(_app(
      DashboardCategoryList(
        transactions: [purchase, refund],
        amountResolver: (tx) => tx.entry.id == 'purchase' ? 100 : -20,
        currencyCode: 'USD',
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Food'), findsOneWidget);
    expect(find.textContaining('Shopping'), findsNothing);
  });

  testWidgets('trend chart includes negative net-spending months',
      (tester) async {
    final purchase = _transaction(
      id: 'purchase',
      category: 'food',
      spendingMultiplier: 1,
    );
    final refund = _transaction(
      id: 'refund',
      category: 'shopping',
      type: 'income',
      spendingMultiplier: -1,
      countsTowardIncome: false,
    );

    await tester.pumpWidget(_app(
      DashboardTrendChart(
        transactions: [purchase, refund],
        amountResolver: (tx) => tx.entry.id == 'purchase' ? 100 : -120,
        currencyCode: 'USD',
      ),
    ));

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minY, lessThan(0));
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProviderScope(child: Scaffold(body: child)),
  );
}

ConsolidatedTransaction _transaction({
  required String id,
  required String category,
  String type = 'expense',
  required int spendingMultiplier,
  bool countsTowardIncome = false,
}) {
  final now = DateTime(2026, 4, 28);
  return ConsolidatedTransaction(
    entry: ExpenseEntry(
      id: id,
      date: now,
      amountCents: 10000,
      category: category,
      type: type,
      createdAt: now,
      analyticsClass:
          spendingMultiplier < 0 ? 'refund_or_reversal' : 'consumer_spend',
      analyticsSpendingMultiplier: spendingMultiplier,
      analyticsCountsTowardIncome: countsTowardIncome,
    ),
    spaceLabel: 'Personal',
  );
}
