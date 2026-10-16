import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/confirm_recurring_occurrence_sheet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';

void main() {
  for (final isEditing in [false, true]) {
    for (final failsFirst in [false, true]) {
      testWidgets(
          'preserves ${isEditing ? 'actual' : 'template'} wallet through '
          '${failsFirst ? 'failed read and retry' : 'initial loading and refresh'}',
          (tester) async {
        const query = WalletsCurrencyQuery(householdId: null, currency: 'USD');
        var request = Completer<List<WalletEntity>>();
        final container = ProviderContainer(overrides: [
          walletsByCurrencyProvider(query)
              .overrideWith((ref) => request.future),
        ]);
        addTearDown(container.dispose);
        final date = DateTime(2026, 10, 14);
        final transaction = RecurringTransaction(
          id: 'recurring-id',
          date: date,
          category: 'housing',
          amount: 253.24,
          currency: 'USD',
          ownerType: 'me',
          privacyScope: 'full',
          type: 'expense',
          attachments: const [],
          createdAt: date,
          accountId: 'bank-wallet',
        );
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
                builder: (context) => Scaffold(
                      body: FilledButton(
                        onPressed: () => showConfirmRecurringOccurrenceSheet(
                          context: context,
                          recurringTransaction: transaction,
                          scheduledOccurrenceDate: date,
                          existingOccurrence: isEditing
                              ? RecurringOccurrenceTimelineItem(
                                  scheduledOccurrenceDate: date,
                                  status: 'confirmed',
                                  amountCents: 25324,
                                  actualTransaction: ExpenseEntry(
                                    id: 'actual-id',
                                    date: date,
                                    amountCents: 25324,
                                    currency: 'USD',
                                    createdAt: date,
                                    walletId: 'actual-wallet',
                                  ),
                                )
                              : null,
                        ),
                        child: const Text('Open'),
                      ),
                    )),
          ),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Spending'), findsNothing);
        if (failsFirst) {
          request.completeError(StateError('Wallet read failed'));
          await tester.pumpAndSettle();
          request = Completer<List<WalletEntity>>();
          container.invalidate(walletsByCurrencyProvider(query));
          await tester.pumpAndSettle();
        }
        final wallets = [
          _wallet('spending', 'Spending'),
          _wallet('bank-wallet', 'Linked bank'),
          _wallet('actual-wallet', 'Actual payment wallet'),
        ];
        request.complete(wallets);
        await tester.pumpAndSettle();
        final selectedName =
            isEditing ? 'Actual payment wallet' : 'Linked bank';
        expect(find.text(selectedName), findsOneWidget);
        expect(find.text('Spending'), findsNothing);

        request = Completer<List<WalletEntity>>();
        container.invalidate(walletsByCurrencyProvider(query));
        await tester.pumpAndSettle();
        expect(find.text(selectedName), findsOneWidget);
        request.complete(wallets.reversed.toList());
        await tester.pumpAndSettle();
        expect(find.text(selectedName), findsOneWidget);
      });
    }
  }

  testWidgets('shows a disabled No wallet row when no wallet exists',
      (tester) async {
    const walletQuery =
        WalletsCurrencyQuery(householdId: null, currency: 'USD');
    final recurringTransaction = RecurringTransaction(
      id: 'recurring-id',
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletsByCurrencyProvider(walletQuery).overrideWith(
            (ref) async => [],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showConfirmRecurringOccurrenceSheet(
                  context: context,
                  recurringTransaction: recurringTransaction,
                  scheduledOccurrenceDate: DateTime(2026, 7, 1),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final walletRow = find.ancestor(
      of: find.text('No wallet'),
      matching: find.byType(MonekoDisclosureRow),
    );
    expect(walletRow, findsOneWidget);
    expect(
      find.descendant(
          of: walletRow, matching: find.byIcon(Icons.chevron_right)),
      findsNothing,
    );
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: walletRow, matching: find.byType(InkWell)),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('locks the amount for a confirmed shared occurrence',
      (tester) async {
    const walletQuery =
        WalletsCurrencyQuery(householdId: 'household-id', currency: 'USD');
    final recurringTransaction = RecurringTransaction(
      id: 'recurring-id',
      date: DateTime(2026, 7, 1),
      category: 'housing',
      amount: 100,
      currency: 'USD',
      ownerType: 'household',
      privacyScope: 'full',
      householdId: 'household-id',
      splitGroupId: 'split-group-id',
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 7, 1),
    );
    final occurrence = RecurringOccurrenceTimelineItem(
      scheduledOccurrenceDate: DateTime(2026, 7, 1),
      status: 'confirmed',
      amountCents: 10000,
      actualTransaction: ExpenseEntry(
        id: 'actual-id',
        date: DateTime(2026, 7, 1),
        amountCents: 10000,
        currency: 'USD',
        createdAt: DateTime(2026, 7, 1),
        splitGroupId: 'split-group-id',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletsByCurrencyProvider(walletQuery).overrideWith(
            (ref) async => [],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showConfirmRecurringOccurrenceSheet(
                  context: context,
                  recurringTransaction: recurringTransaction,
                  scheduledOccurrenceDate: DateTime(2026, 7, 1),
                  existingOccurrence: occurrence,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Actual amount'), findsOneWidget);
    expect(find.text('Tap to edit amount'), findsNothing);
    final amountTapTarget = find.ancestor(
      of: find.text('Actual amount'),
      matching: find.byType(GestureDetector),
    );
    expect(amountTapTarget, findsOneWidget);
    expect(tester.widget<GestureDetector>(amountTapTarget).onTap, isNull);
  });

  testWidgets('preconfirmation defaults paid date to the scheduled date',
      (tester) async {
    const walletQuery =
        WalletsCurrencyQuery(householdId: null, currency: 'USD');
    final scheduledDate = DateTime.now().add(const Duration(days: 30));
    final recurringTransaction = RecurringTransaction(
      id: 'recurring-id',
      date: scheduledDate,
      category: 'housing',
      amount: 100,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      type: 'expense',
      attachments: const [],
      createdAt: DateTime.now(),
      serverNextOccurrenceDate: scheduledDate,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletsByCurrencyProvider(walletQuery).overrideWith(
            (ref) async => [],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showConfirmRecurringOccurrenceSheet(
                  context: context,
                  recurringTransaction: recurringTransaction,
                  scheduledOccurrenceDate: scheduledDate,
                  allowNextPreconfirmation: true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final paidDateRow = tester
        .widgetList<MonekoDisclosureRow>(find.byType(MonekoDisclosureRow))
        .firstWhere((row) => row.label == 'Date paid');
    expect(
      paidDateRow.value,
      formatLocalizedDate(
          tester.element(find.text('Date paid')), scheduledDate),
    );

    paidDateRow.onTap!();
    await tester.pumpAndSettle();
    expect(
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
        DateTime(2100, 12, 31));
  });
}

WalletEntity _wallet(String id, String name) => WalletEntity(
      id: id,
      userId: 'user-id',
      householdId: null,
      name: name,
      icon: 'wallet',
      color: '#6B7280',
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: id == 'spending',
      isSystem: id == 'spending',
      isArchived: false,
      currentBalanceCents: 0,
    );
