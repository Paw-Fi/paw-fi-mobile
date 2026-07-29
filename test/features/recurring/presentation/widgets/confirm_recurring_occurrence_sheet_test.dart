import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/widgets/confirm_recurring_occurrence_sheet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';

void main() {
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
}
