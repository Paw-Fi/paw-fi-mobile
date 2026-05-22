import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/recent_transactions_card.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'recent transactions rows keep original source-currency amounts',
    (tester) async {
      final transactionDate = DateTime(2026, 5, 22);
      final expense = ExpenseEntry(
        id: 'tx_eur',
        date: transactionDate,
        amountCents: 2000,
        currency: 'EUR',
        category: 'food',
        rawText: 'Lunch',
        createdAt: transactionDate,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingRecurringTransactionProvider(
              const UpcomingRecurringScope(
                householdId: null,
                currency: 'USD',
                selectedCurrencies: ['USD', 'EUR'],
              ),
            ).overrideWithValue(null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: buildRecentTransactionsCard(
                  context,
                  Theme.of(context).colorScheme,
                  [expense],
                  null,
                  selectedCurrency: 'USD',
                  selectedCurrencies: const ['USD', 'EUR'],
                  onViewAll: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('-€20'), findsOneWidget);
      expect(find.text('-\$20'), findsNothing);
    },
  );

  testWidgets('recent transactions card shows upcoming recurring banner', (
    tester,
  ) async {
    final upcoming = UpcomingRecurringTransaction(
      transaction: RecurringTransaction(
        id: 'rec_1',
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
      ),
      nextOccurrence: DateTime(2026, 7, 10),
      daysUntil: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingRecurringTransactionProvider(
            const UpcomingRecurringScope(householdId: null, currency: 'USD'),
          ).overrideWithValue(upcoming),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: buildRecentTransactionsCard(
                context,
                Theme.of(context).colorScheme,
                const <ExpenseEntry>[],
                null,
                selectedCurrency: 'USD',
                onViewAll: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.upcomingBills), findsOneWidget);
    expect(find.text('Insurance renewal'), findsOneWidget);
    expect(find.text(l10n.inDays(2)), findsOneWidget);
    expect(find.text(l10n.noTransactionsFound), findsNothing);
  });
}
