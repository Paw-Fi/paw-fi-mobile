import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

ExpenseEntry _entry({
  required String id,
  required int amountCents,
  required String currency,
  String? bankAccountId,
  bool analyticsIsFinal = true,
}) {
  final date = DateTime(2026, 5, 22);
  return ExpenseEntry(
    id: id,
    date: date,
    amountCents: amountCents,
    currency: currency,
    category: 'food',
    rawText: 'Lunch',
    bankAccountId: bankAccountId,
    analyticsIsFinal: analyticsIsFinal,
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
        ProviderScope(
          child: MaterialApp(
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
        ),
      );

      expect(find.text('-\$5'), findsWidgets);
      expect(find.text('-€20'), findsOneWidget);
    },
  );

  testWidgets('shows pending tag for non-final bank transactions',
      (tester) async {
    final pendingEntry = _entry(
      id: 'pending-tx',
      amountCents: 500,
      currency: 'USD',
      bankAccountId: 'bank-account-1',
      analyticsIsFinal: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GroupedTransactionsList(
              transactions: [pendingEntry],
              currency: 'USD',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('shows pending tag alongside a custom subtitle', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TransactionListTile(
              category: 'food',
              title: 'Food',
              amount: 5,
              currency: 'USD',
              isIncome: false,
              subtitleWidget: Text('Personal'),
              showPendingChip: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });
}
