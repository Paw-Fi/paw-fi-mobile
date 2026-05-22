import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';

ExpenseEntry _entry({
  required String id,
  required int amountCents,
  required String currency,
}) {
  final date = DateTime(2026, 5, 22);
  return ExpenseEntry(
    id: id,
    date: date,
    amountCents: amountCents,
    currency: currency,
    category: 'food',
    rawText: 'Lunch',
    createdAt: date,
  );
}

void main() {
  testWidgets(
    'keeps converted group totals while rows use source-currency entries',
    (tester) async {
      final convertedEntry = _entry(
        id: 'tx-1',
        amountCents: 500,
        currency: 'USD',
      );
      final originalEntry = _entry(
        id: 'tx-1',
        amountCents: 2000,
        currency: 'EUR',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GroupedTransactionsList(
              transactions: [convertedEntry],
              currency: 'USD',
              rowDisplayTransactionsById: {'tx-1': originalEntry},
            ),
          ),
        ),
      );

      expect(find.text('-\$5'), findsWidgets);
      expect(find.text('-€20'), findsOneWidget);
    },
  );
}
