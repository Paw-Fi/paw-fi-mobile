import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets('edit wallet sheet seeds balance field from opening balance',
      (tester) async {
    const wallet = WalletEntity(
      id: 'w1',
      userId: 'u1',
      householdId: null,
      name: 'Main Wallet',
      icon: 'wallet',
      color: '#6B7280',
      openingBalanceCents: 100000,
      goalAmountCents: null,
      isDefault: true,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 98000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showCreateEditWalletSheet(
                    context,
                    initial: wallet,
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final balanceField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );

    expect(balanceField.controller?.text, '1000');
  });
}
