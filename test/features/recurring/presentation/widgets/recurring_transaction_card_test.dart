import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

void main() {
  RecurringTransaction transaction() => RecurringTransaction(
        id: 'recurring-usd',
        date: DateTime(2026, 7, 1),
        category: 'housing',
        amount: 100,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        type: 'expense',
        attachments: const [],
        createdAt: DateTime(2026, 7, 1),
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required bool showCurrencyFlag,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecurringTransactionCard(
            transaction: transaction(),
            nextOccurrenceDate: DateTime(2026, 8, 1),
            showCurrencyFlag: showCurrencyFlag,
          ),
        ),
      ),
    );
  }

  testWidgets('shows native currency flag for multi-currency lists',
      (tester) async {
    await pumpCard(tester, showCurrencyFlag: true);

    expect(find.byType(TransactionCurrencyFlagBadge), findsOneWidget);
    expect(
      tester
          .widget<TransactionCurrencyFlagBadge>(
            find.byType(TransactionCurrencyFlagBadge),
          )
          .currencyCode,
      'USD',
    );
  });

  testWidgets('hides currency flag for single-currency lists', (tester) async {
    await pumpCard(tester, showCurrencyFlag: false);

    expect(find.byType(TransactionCurrencyFlagBadge), findsNothing);
  });
}
