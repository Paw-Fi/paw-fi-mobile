import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_conversion_fields.dart';
import 'package:moneko/l10n/app_localizations.dart';

const wallets = [
  WalletEntity(
      id: 'from',
      userId: 'user',
      householdId: null,
      name: 'Checking',
      icon: 'wallet',
      color: '#112233',
      currency: 'USD',
      openingBalanceCents: 10000,
      goalAmountCents: null,
      isDefault: true,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 10000),
  WalletEntity(
      id: 'to',
      userId: 'user',
      householdId: null,
      name: 'Savings',
      icon: 'wallet',
      color: '#112233',
      currency: 'USD',
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 0),
];

Future<void> openSheet(
  WidgetTester tester, {
  String? time,
  TargetPlatform platform = TargetPlatform.android,
  bool use24Hours = false,
  ValueChanged<WalletTransferResult?>? onResult,
  List<WalletEntity> sheetWallets = wallets,
  WalletTransfer? initialTransfer,
  Locale locale = const Locale('en'),
  bool creating = false,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appPreferredTimezoneProvider.overrideWithValue('Asia/Tokyo'),
      currencyRateTableProvider
          .overrideWith((ref) async => const CurrencyRateTable(
                baseCurrency: 'USD',
                rates: {'USD': 1, 'EUR': 0.91},
                fetchedAt: null,
                source: 'test',
                isStale: false,
              )),
    ],
    child: MaterialApp(
      locale: locale,
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data:
            MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24Hours),
        child: child!,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () async =>
                        onResult?.call(await showWalletTransferSheet(
                      context,
                      wallets: sheetWallets,
                      initialTransfer: creating
                          ? null
                          : initialTransfer ??
                              WalletTransfer.fromJson({
                                'id': 'transfer',
                                'from_account_id': 'from',
                                'to_account_id': 'to',
                                'amount_cents': 1000,
                                'currency': 'USD',
                                'date': '2026-09-15',
                                'time': time,
                              }),
                    )),
                    child: const Text('Open'),
                  ))),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  test(
      'rate input follows locale separators and numeric scripts without truncating precision',
      () {
    expect(parseTransferRateInput('0,923456789123456789', 'de'),
        '0.923456789123456789');
    expect(parseTransferRateInput('٠٫٩٢٣٤', 'ar'), '0.9234');
    expect(parseTransferRateInput('۰.۹۲۳۴', 'ur'), '0.9234');
    expect(parseTransferRateInput('NaN', 'en'), isNull);
    expect(parseTransferRateInput('-1', 'en'), isNull);
    expect(parseTransferRateInput('text 0.9', 'en'), isNull);
    expect(parseTransferRateInput('0.9', 'de'), isNull);
  });

  testWidgets(
      'new cross-currency transfer accepts actual received amount and source fee',
      (tester) async {
    WalletTransferResult? result;
    await openSheet(tester,
        creating: true,
        sheetWallets: [wallets.first, wallets.last.copyWith(currency: 'EUR')],
        onResult: (value) => result = value);
    Future<void> enterAmount(Finder field, String digits) async {
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      for (final digit in digits.split('')) {
        await tester.tap(find.text(digit).last);
        await tester.pump();
      }
      await tester.tap(find.byIcon(Icons.check).last);
      await tester.pumpAndSettle();
    }

    await enterAmount(
        find.byKey(const ValueKey('wallet-transfer-source')), '100');
    expect(find.text('EUR 91'), findsOneWidget);
    await enterAmount(
        find.byKey(const ValueKey('wallet-transfer-received')), '90');
    expect(find.textContaining('0.9 EUR'), findsOneWidget);
    await enterAmount(find.byKey(const ValueKey('wallet-transfer-fee')), '2');
    expect(find.text('USD 102'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.amountCents, 10000);
    expect(result?.toAmountCents, 9000);
    expect(result?.exchangeRate, '0.9');
    expect(result?.feeAmountCents, 200);
  });

  testWidgets(
      'cross-currency editor preserves received amount, fee and saved rate',
      (tester) async {
    WalletTransferResult? result;
    await openSheet(
      tester,
      sheetWallets: [wallets.first, wallets.last.copyWith(currency: 'EUR')],
      initialTransfer: WalletTransfer(
        id: 'transfer',
        fromAccountId: 'from',
        toAccountId: 'to',
        amountCents: 10000,
        currency: 'USD',
        toAmountCents: 9000,
        toCurrency: 'EUR',
        exchangeRate: '0.9',
        feeAmountCents: 200,
        transferContractVersion: 2,
        date: DateTime(2026, 9, 15),
      ),
      onResult: (value) => result = value,
    );
    expect(find.text('Received amount'), findsOneWidget);
    expect(find.textContaining('0.9 EUR'), findsOneWidget);
    final fee = find.byKey(const ValueKey('wallet-transfer-fee'));
    await tester.ensureVisible(fee);
    expect(find.textContaining('102'), findsWidgets);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.amountCents, 10000);
    expect(result?.toAmountCents, 9000);
    expect(result?.toCurrency, 'EUR');
    expect(result?.exchangeRate, '0.9');
    expect(result?.feeAmountCents, 200);
  });

  testWidgets(
      'manual rate recalculates received principal, not source plus fee',
      (tester) async {
    WalletTransferResult? result;
    await openSheet(
      tester,
      sheetWallets: [wallets.first, wallets.last.copyWith(currency: 'EUR')],
      initialTransfer: WalletTransfer(
        id: 'transfer',
        fromAccountId: 'from',
        toAccountId: 'to',
        amountCents: 10000,
        currency: 'USD',
        toAmountCents: 9000,
        toCurrency: 'EUR',
        exchangeRate: '0.9',
        feeAmountCents: 200,
        date: DateTime(2026, 9, 15),
      ),
      onResult: (value) => result = value,
    );
    final rate = find.byKey(const ValueKey('wallet-transfer-rate'));
    await tester.ensureVisible(rate);
    await tester.tap(rate);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('transfer-rate-input')), '0.925');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.amountCents, 10000);
    expect(result?.toAmountCents, 9250);
    expect(result?.feeAmountCents, 200);
  });

  for (final use24Hours in [false, true]) {
    testWidgets(
        'Cupertino picker saves entered time with use24Hours=$use24Hours',
        (tester) async {
      WalletTransferResult? result;
      await openSheet(tester,
          time: '09:30:00',
          platform: TargetPlatform.iOS,
          use24Hours: use24Hours,
          onResult: (value) => result = value);
      final timeField = find.byKey(const ValueKey('wallet-transfer-time'));
      await tester.ensureVisible(timeField);
      await tester.tap(timeField);
      await tester.pumpAndSettle();
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
      expect(result?.date, DateTime(2026, 9, 15));
      expect(result?.time, '09:31:00');
    });
  }

  testWidgets('Cupertino cancel leaves historical time unset', (tester) async {
    WalletTransferResult? result;
    await openSheet(tester,
        platform: TargetPlatform.iOS, onResult: (value) => result = value);
    final timeField = find.byKey(const ValueKey('wallet-transfer-time'));
    await tester.ensureVisible(timeField);
    await tester.tap(timeField);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.time, isNull);
  });

  testWidgets('legacy transfer keeps time unset when saved', (tester) async {
    WalletTransferResult? result;
    await openSheet(tester, onResult: (value) => result = value);
    await tester.ensureVisible(find.text('Not set'));
    expect(find.text('Time'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.date, DateTime(2026, 9, 15));
    expect(result?.time, isNull);
  });

  testWidgets('native time picker preserves date and detects time-only edits',
      (tester) async {
    WalletTransferResult? result;
    await openSheet(tester,
        time: '09:30:00', onResult: (value) => result = value);
    final timeField = find.byKey(const ValueKey('wallet-transfer-time'));
    await tester.ensureVisible(timeField);
    await tester.tap(timeField);
    await tester.pumpAndSettle();
    final picker =
        tester.widget<TimePickerDialog>(find.byType(TimePickerDialog));
    expect(picker.initialTime, const TimeOfDay(hour: 9, minute: 30));
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    final pickerFields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextFormField));
    await tester.enterText(pickerFields.first, '02');
    await tester.enterText(pickerFields.last, '45');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.date, DateTime(2026, 9, 15));
    expect(result?.time, '14:45:00');
  });

  testWidgets('cancelling picker retains existing time', (tester) async {
    WalletTransferResult? result;
    await openSheet(tester,
        time: '00:00:00', onResult: (value) => result = value);
    final timeField = find.byKey(const ValueKey('wallet-transfer-time'));
    await tester.ensureVisible(timeField);
    await tester.tap(timeField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.time, '00:00:00');
  });

  testWidgets('changing calendar date preserves entered time', (tester) async {
    WalletTransferResult? result;
    await openSheet(tester,
        time: '23:45:00', onResult: (value) => result = value);
    await tester.ensureVisible(find.text('Sep 15, 2026'));
    await tester.tap(find.text('Sep 15, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(result?.date, DateTime(2026, 9, 14));
    expect(result?.time, '23:45:00');
  });
}
