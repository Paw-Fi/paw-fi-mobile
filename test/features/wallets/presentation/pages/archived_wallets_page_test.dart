import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/pages/archived_wallets_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets('archived debt wallet displays a negative balance',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        archivedScopedAccountsProvider.overrideWith((ref) async => const [
              WalletEntity(
                id: 'debt',
                userId: 'user',
                householdId: null,
                name: 'Mortgage',
                icon: 'mortgage',
                color: '#6B7280',
                openingBalanceCents: -10000,
                goalAmountCents: null,
                isDefault: false,
                isSystem: false,
                isArchived: true,
                currentBalanceCents: -7500,
              ),
            ]),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: ArchivedWalletsPage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('-\$75'), findsOneWidget);
  });
}
