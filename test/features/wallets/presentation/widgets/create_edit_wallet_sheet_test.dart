import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

Future<void> _tapConfirm(WidgetTester tester) async {
  final button = find.byType(MonekoSheetConfirmButton);
  expect(button, findsOneWidget);
  await tester.tap(button);
}

void main() {
  testWidgets('choosing a built-in wallet icon clears custom logoUrl',
      (tester) async {
    const wallet = WalletEntity(
      id: 'w1',
      userId: 'u1',
      householdId: null,
      name: 'Main Wallet',
      icon: 'wallet',
      color: '#6B7280',
      logoUrl: 'https://example.com/logo.jpg',
      openingBalanceCents: 100000,
      goalAmountCents: null,
      isDefault: true,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 98000,
    );
    CreateEditWalletResult? result;

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
                  onPressed: () async {
                    result = await showCreateEditWalletSheet(
                      context,
                      initial: wallet,
                    );
                  },
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

    await tester.tap(find.byIcon(Icons.groups_rounded));
    await tester.pumpAndSettle();

    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(result?.icon, 'joint');
    expect(result?.logoUrl, null);
  });

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

    await tester.scrollUntilVisible(
      find.text('1000'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('1000'), findsOneWidget);
  });

  testWidgets('edit wallet sheet explains and returns analytics exclusion',
      (tester) async {
    const wallet = WalletEntity(
      id: 'w1',
      userId: 'u1',
      householdId: null,
      name: 'Reserve',
      icon: 'savings',
      color: '#6B7280',
      openingBalanceCents: 100000,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 100000,
    );
    CreateEditWalletResult? result;

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
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCreateEditWalletSheet(
                    context,
                    initial: wallet,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Exclude from wallet analytics'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).last);
    expect(
      tooltip.message,
      contains('balance, wallet-linked income and spending'),
    );

    await tester.tap(find.text('Exclude from wallet analytics'));
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(result?.excludeFromAnalytics, isTrue);
  });
}
