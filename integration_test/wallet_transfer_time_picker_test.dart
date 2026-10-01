import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

import '../test/features/wallets/presentation/widgets/wallet_transfer_sheet_test.dart'
    show wallets;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(
    WidgetTester tester, {
    required bool use24Hours,
    required String? time,
    required ValueChanged<WalletTransferResult?> onResult,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appPreferredTimezoneProvider.overrideWithValue('Asia/Tokyo')],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(alwaysUse24HourFormat: use24Hours),
          child: child!,
        ),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () async =>
                          onResult(await showWalletTransferSheet(
                        context,
                        wallets: wallets,
                        initialTransfer: WalletTransfer(
                            id: 'test-transfer',
                            fromAccountId: 'from',
                            toAccountId: 'to',
                            amountCents: 1000,
                            currency: 'USD',
                            date: DateTime(2026, 10, 1),
                            time: time),
                      )),
                      child: const Text('Open'),
                    ))),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final timeField = find.byKey(const ValueKey('wallet-transfer-time'));
    await tester.ensureVisible(timeField);
    await tester.tap(timeField);
    await tester.pumpAndSettle();
  }

  for (final use24Hours in [false, true]) {
    testWidgets('iOS wheel saves wall time with use24Hours=$use24Hours',
        (tester) async {
      expect(Platform.isIOS, isTrue);
      WalletTransferResult? result;
      await open(tester,
          use24Hours: use24Hours,
          time: '09:30:00',
          onResult: (value) => result = value);
      final picker =
          tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      expect(picker.mode, CupertinoDatePickerMode.time);
      expect(picker.initialDateTime.hour, 9);
      expect(picker.initialDateTime.minute, 30);
      expect(picker.use24hFormat, use24Hours);
      final wheels = find.descendant(
          of: find.byType(CupertinoDatePicker),
          matching: find.byType(ListWheelScrollView));
      expect(wheels, findsNWidgets(use24Hours ? 2 : 3));
      await tester.timedDrag(
          wheels.at(1), const Offset(0, -64), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(result?.date, DateTime(2026, 10, 1));
      expect(result?.time, isNot('09:30:00'));
      expect(result?.time, startsWith('09:'));
    });
  }

  testWidgets('iOS cancelling picker preserves legacy unknown time',
      (tester) async {
    WalletTransferResult? result;
    await open(tester,
        use24Hours: true, time: null, onResult: (value) => result = value);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result?.time, isNull);
    expect(result?.date, DateTime(2026, 10, 1));
  });
}
