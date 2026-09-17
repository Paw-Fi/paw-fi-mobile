import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/recent_transactions_card.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';

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

  testWidgets('recent transactions card does not show upcoming recurring items',
      (
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

    expect(find.text(l10n.upcomingBills), findsNothing);
    expect(find.text('Insurance renewal'), findsNothing);
    expect(find.text(l10n.inDays(2)), findsNothing);
    expect(find.text(l10n.noTransactionsFound), findsOneWidget);
  });

  testWidgets('canonical merchant-only updates reach the mounted recent row',
      (tester) async {
    final transactionDate = DateTime(2026, 9, 9);
    var expense = ExpenseEntry(
      id: 'ebd30e06-b46d-4dc5-88e3-fd4c174fd65b',
      date: transactionDate,
      amountCents: 5000,
      currency: 'USD',
      category: 'petrol',
      rawText: 'dinner',
      createdAt: transactionDate,
    );
    late StateSetter updateCard;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              updateCard = setState;
              return Scaffold(
                body: buildRecentTransactionsCard(
                  context,
                  Theme.of(context).colorScheme,
                  [expense],
                  null,
                  selectedCurrency: 'USD',
                  onViewAll: () {},
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(tester.widget<MerchantLogo>(find.byType(MerchantLogo)).merchantId,
        isNull);

    updateCard(() {
      expense = expense.copyWith(
        merchantId: '4d055fac-88b0-4750-b606-92f37c008975',
        merchantDomain: 'tesco.com',
        merchantStructuredName: 'Tesco',
      );
    });
    await tester.pump();

    final logo = tester.widget<MerchantLogo>(find.byType(MerchantLogo));
    expect(logo.merchantId, '4d055fac-88b0-4750-b606-92f37c008975');
    expect(logo.domain, 'tesco.com');
  });

  testWidgets('legacy merchant text keeps the category-logo fallback',
      (tester) async {
    final transactionDate = DateTime(2026, 9, 8);
    final expense = ExpenseEntry(
      id: 'legacy_merchant',
      date: transactionDate,
      amountCents: 1200,
      currency: 'USD',
      category: 'shopping',
      rawText: 'card purchase',
      merchant: 'Corner Shop',
      createdAt: transactionDate,
    );

    await tester.pumpWidget(
      ProviderScope(
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
                onViewAll: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Corner Shop'), findsOneWidget);
    final logo = tester.widget<MerchantLogo>(find.byType(MerchantLogo));
    expect(logo.merchantId, isNull);
    expect(logo.domain, isNull);
  });
}
