import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/wallets/presentation/pages/bank_connections_page.dart';
import 'package:moneko/l10n/app_localizations.dart';

Widget _testApp(List<BankConnection> connections) => ProviderScope(
      overrides: [
        bankConnectionsProvider.overrideWith((ref) async => connections),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BankConnectionsPage(),
      ),
    );

void main() {
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
    expect(find.text('Disconnect'), findsOneWidget);
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
}
