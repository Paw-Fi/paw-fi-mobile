import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/widgets/bulk_confirm_past_occurrences_sheet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets('close dismisses bulk confirmation after caller is disposed',
      (tester) async {
    const walletQuery =
        WalletsCurrencyQuery(householdId: null, currency: 'USD');
    final showCaller = ValueNotifier(true);
    bool? result;
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
          home: ValueListenableBuilder<bool>(
            valueListenable: showCaller,
            builder: (context, isVisible, child) => Scaffold(
              body: isVisible
                  ? Builder(
                      builder: (callerContext) => FilledButton(
                        onPressed: () async {
                          result = await showBulkConfirmPastOccurrencesSheet(
                            context: callerContext,
                            recurringTransaction: recurringTransaction,
                            occurrences: [DateTime(2026, 7, 1)],
                          );
                        },
                        child: const Text('Open'),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    showCaller.value = false;
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isFalse);
    showCaller.dispose();
  });
}
