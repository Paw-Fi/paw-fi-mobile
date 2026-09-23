import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/features/home/presentation/models/bank_account.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/home/presentation/state/bank_accounts_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/wallets/presentation/pages/bank_connections_page.dart';
import 'package:moneko/l10n/app_localizations.dart';

Widget _testApp(
  List<BankConnection> connections, {
  List<BankAccount> accounts = const [],
  String? preferredTimezone = 'America/New_York',
}) =>
    ProviderScope(
      overrides: [
        bankConnectionsProvider.overrideWith((ref) async => connections),
        allVisibleBankAccountsProvider.overrideWith((ref) async => accounts),
        appPreferredTimezoneProvider.overrideWithValue(preferredTimezone),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BankConnectionsPage(),
      ),
    );

void main() {
  testWidgets('supported region empty state routes to wallets add action',
      (tester) async {
    await tester.pumpWidget(_testApp(const []));
    await tester.pumpAndSettle();

    expect(find.text('Add Wallet'), findsOneWidget);
    expect(
      find.text(
        'Connect your bank to automatically import transactions into wallets instead of entering everything by hand.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('revoked unassigned connection offers reconnect', (tester) async {
    await tester.pumpWidget(_testApp(const [
      BankConnection(
        id: 'connection-1',
        institutionName: 'Recovery Bank',
        status: 'needs_reauth',
        itemStatus: 'pending_relink',
        relinkState: 'required',
        canReconnect: true,
        canDisconnect: true,
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Recovery Bank'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Finish setup'), findsNothing);
    expect(find.text('Disconnect Bank'), findsOneWidget);
  });

  testWidgets('regular household member sees guidance without actions',
      (tester) async {
    await tester.pumpWidget(_testApp(const [
      BankConnection(
        id: 'connection-2',
        householdId: 'household-1',
        institutionName: 'Household Bank',
        status: 'needs_reauth',
        itemStatus: 'pending_relink',
        relinkState: 'required',
        linkedWalletCount: 1,
        roleGuidance:
            'A household owner or admin must manage this bank connection.',
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Household Bank'), findsOneWidget);
    expect(
      find.text('A household owner or admin must manage this bank connection.'),
      findsOneWidget,
    );
    expect(find.text('Reconnect'), findsNothing);
    expect(find.text('Disconnect'), findsNothing);
  });

  testWidgets('shows accounts under the connection-level disconnect boundary',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        const [
          BankConnection(
            id: 'connection-3',
            institutionName: 'Accounts Bank',
            itemStatus: 'active',
            itemHealthState: 'healthy',
            linkedBankAccountCount: 2,
            canDisconnect: true,
          ),
        ],
        accounts: const [
          BankAccount(
            id: 'account-1',
            name: 'Current account',
            mask: '1234',
            bankConnectionId: 'connection-3',
            currency: 'GBP',
          ),
          BankAccount(
            id: 'account-2',
            name: 'Savings account',
            mask: '5678',
            bankConnectionId: 'connection-3',
            currency: 'GBP',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current account ••••1234'), findsOneWidget);
    expect(find.text('Savings account ••••5678'), findsOneWidget);
    expect(find.text('Sync Bank'), findsOneWidget);
    expect(find.text('Disconnect Bank'), findsOneWidget);
  });
}
