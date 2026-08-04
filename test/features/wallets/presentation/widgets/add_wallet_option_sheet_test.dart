import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/presentation/widgets/add_wallet_option_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

Widget _testApp({required bool showBankConnectionsOption}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showAddWalletOptionSheet(
              context,
              showBankConnectionOption: true,
              showBankConnectionsOption: showBankConnectionsOption,
            ),
            child: const Text('New wallet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('hides bank connection management without an active connection',
      (tester) async {
    await tester.pumpWidget(_testApp(showBankConnectionsOption: false));
    await tester.tap(find.text('New wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Bank connections'), findsNothing);
  });

  testWidgets('shows bank connection management with an active connection',
      (tester) async {
    await tester.pumpWidget(_testApp(showBankConnectionsOption: true));
    await tester.tap(find.text('New wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Bank connections'), findsOneWidget);
  });
}
