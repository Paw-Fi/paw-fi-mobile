import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/presentation/widgets/add_wallet_option_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

Widget _testApp({required bool showBankConnectionOption}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showAddWalletOptionSheet(
              context,
              showBankConnectionOption: showBankConnectionOption,
            ),
            child: const Text('New wallet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'does not show bank connection management in the add wallet sheet',
      (tester) async {
    await tester.pumpWidget(_testApp(showBankConnectionOption: true));
    await tester.tap(find.text('New wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Bank connections'), findsNothing);
    expect(find.text('Connect Bank'), findsOneWidget);
  });

  testWidgets('still hides bank linking when it is unavailable',
      (tester) async {
    await tester.pumpWidget(_testApp(showBankConnectionOption: false));
    await tester.tap(find.text('New wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Connect Bank'), findsNothing);
    expect(find.text('Bank connections'), findsNothing);
  });
}
