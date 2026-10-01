import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/transaction_exporter.dart';

void main() {
  group('Excel financial report', () {
    test('serializes useful financial fields on every transaction sheet',
        () async {
      final workbook = await _workbook([
        _entry(
          id: 'internal-expense-id',
          householdId: 'household-1',
          amountCents: 123456,
          currency: 'VND',
          userName: 'Nguyễn An',
          accountName: 'Ví tiền mặt',
          rawText: 'Mua thực phẩm — ghi chú',
          merchant: 'original merchant evidence',
          merchantStructuredName: 'Cửa hàng Hà Nội',
          breakdown: ['Rau: 200', '米: 1,034.56'],
          receiptImageUrl: 'https://example.test/receipt.jpg',
          bankAccountId: 'private-bank-id',
          providerPending: false,
          analyticsClass: 'consumer_spend',
          parentRecurringId: 'private-recurring-id',
          scheduledOccurrenceDate: DateTime(2026, 7, 10),
        ),
      ]);

      for (final name in ['All Transactions', 'Family']) {
        final row = _transactionRows(workbook[name]).single;
        expect(row['Date'], '2026-07-13');
        expect(row['Time'], '17:30:15');
        expect(row['Space'], 'Family');
        expect(row['Recorded By'], 'Nguyễn An');
        expect(row['Wallet'], 'Ví tiền mặt');
        expect(row['Description / Notes'], 'Mua thực phẩm — ghi chú');
        expect(row['Merchant'], 'Cửa hàng Hà Nội');
        expect(row['Category'], 'groceries');
        expect(row['Amount'], '1234.56');
        expect(row['Currency'], 'VND');
        expect(row['Type'], 'expense');
        expect(row['Financial Activity'], 'Spending');
        expect(row['Bank Status'], 'Posted');
        expect(row['Item Breakdown'], 'Rau: 200\n米: 1,034.56');
        expect(row['Recurring'], 'Recorded payment');
        expect(row['Scheduled Date'], '2026-07-10');
        expect(row['Receipt Link'], 'https://example.test/receipt.jpg');
      }
      final cells = workbook.tables.values
          .expand((sheet) => sheet.rows)
          .expand((row) => row)
          .map((cell) => cell?.value.toString())
          .toSet();
      expect(cells, isNot(contains('internal-expense-id')));
      expect(cells, isNot(contains('private-bank-id')));
      expect(cells, isNot(contains('private-recurring-id')));
    });

    test('keeps legacy evidence and leaves unknown optional fields blank',
        () async {
      final workbook = await _workbook([
        _entry(
          merchant: 'متجر البقالة',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          receiptImageUrl: 'file:///private/local-receipt.png',
        ),
      ]);
      final row = _transactionRows(workbook['All Transactions']).single;
      expect(row['Merchant'], 'متجر البقالة');
      for (final column in [
        'Time',
        'Wallet',
        'Recorded By',
        'Bank Status',
        'Recurring',
        'Scheduled Date',
        'Receipt Link',
      ]) {
        expect(row[column], '', reason: column);
      }
    });

    test('keeps native currencies in the smaller export and its totals',
        () async {
      final workbook = await _workbook([
        _entry(id: 'eur', amountCents: 10000, currency: 'EUR'),
        _entry(id: 'usd', amountCents: 20000, currency: 'USD'),
      ], includeSpaceSheets: false);
      expect(workbook.tables.keys, ['Overview', 'Transactions']);
      final rows = _transactionRows(workbook['Transactions']);
      expect(rows.map((row) => row['Currency']), ['USD', 'EUR']);
      expect(rows.map((row) => num.parse(row['Amount']!)), [200, 100]);
      final summary = workbook['Overview'].rows.skip(4).toList();
      expect(summary.length, 2);
      expect(summary[0][1]?.value.toString(), 'EUR');
      expect(num.parse(summary[0][4]!.value.toString()), 100);
      expect(summary[1][1]?.value.toString(), 'USD');
      expect(num.parse(summary[1][4]!.value.toString()), 200);
    });

    test('uses selected dates without shifting calendar dates by timezone',
        () async {
      final workbook = await _workbook([
        _entry(createdAt: DateTime.parse('2026-07-13T23:30:00Z')),
      ],
          selectedDateRange: DateTimeRange(
            start: DateTime(2026, 7, 1),
            end: DateTime(2026, 7, 31),
          ));
      expect(workbook['Overview'].rows[1][1]?.value.toString(),
          '2026-07-01 to 2026-07-31');
      final row = _transactionRows(workbook['All Transactions']).single;
      expect(row['Date'], '2026-07-13');
      expect(row['Time'], '06:30:00');
      final summary = workbook['Overview'].rows[4];
      expect(summary[6]?.value.toString(), '31');
      expect(num.parse(summary[8]!.value.toString()), closeTo(100 / 31, 0.001));
      expect(summary[9]?.value.toString(), 'groceries');
      expect(num.parse(summary[10]!.value.toString()), 100);
    });

    test('labels scheduled and bank-detected recurrence separately', () async {
      final workbook = await _workbook([
        _entry(id: 'recurring_series_20260713', parentRecurringId: 'series'),
        _entry(id: 'bank-recurring', providerRecurring: true),
      ]);
      final rows = _transactionRows(workbook['All Transactions']);
      expect(rows[0]['Recurring'], 'Scheduled');
      expect(rows[0]['Time'], '');
      expect(rows[1]['Recurring'], 'Bank-detected recurring');
    });

    test('preserves a transfer wall time instead of its insertion timestamp',
        () async {
      final workbook = await _workbook([
        _TimedTransferEntry(),
      ]);
      final row = _transactionRows(workbook['All Transactions']).single;
      expect(row['Time'], '09:15:30');
      expect(row['Financial Activity'], 'Transfer out');
    });

    test('writes formula-like user input as text and disambiguates sheet names',
        () async {
      final workbook = await _workbook([
        _entry(id: 'first', householdId: 'household-1', rawText: '=1+1'),
        _entry(id: 'second', householdId: 'household-2'),
      ], householdNames: const {
        'household-1': 'Overview',
        'household-2': 'Overview',
      });
      expect(workbook.tables.keys,
          ['Overview', 'All Transactions', 'Overview (2)', 'Overview (3)']);
      expect(workbook['Overview'].rows.skip(4).length, 2);
      final sheet = workbook['Overview (2)'];
      final descriptionIndex = sheet.rows.first.indexWhere(
          (cell) => cell?.value.toString() == 'Description / Notes');
      expect(sheet.rows[1][descriptionIndex]?.value, isA<TextCellValue>());
      expect(sheet.rows[1][descriptionIndex]?.value.toString(), '=1+1');
    });
  });

  test('reads a supported receipt from the allowed directory', () async {
    final directory = await Directory.systemTemp.createTemp('moneko-export-');
    addTearDown(() => directory.delete(recursive: true));
    final receipt = File('${directory.path}/receipt.png');
    await receipt.writeAsBytes(_pngHeader);

    final bytes = await readLocalReceiptBytesForExport(
      receipt.path,
      allowedDirectories: [directory],
    );

    expect(bytes, _pngHeader);
  });

  test('rejects receipt paths outside the allowed directory', () async {
    final directory = await Directory.systemTemp.createTemp('moneko-export-');
    final outsideDirectory =
        await Directory.systemTemp.createTemp('moneko-export-outside-');
    addTearDown(() => directory.delete(recursive: true));
    addTearDown(() => outsideDirectory.delete(recursive: true));
    final receipt = File('${outsideDirectory.path}/receipt.png');
    await receipt.writeAsBytes(_pngHeader);

    final bytes = await readLocalReceiptBytesForExport(
      receipt.path,
      allowedDirectories: [directory],
    );

    expect(bytes, isNull);
  });

  test('rejects a non-image file with an image extension', () async {
    final directory = await Directory.systemTemp.createTemp('moneko-export-');
    addTearDown(() => directory.delete(recursive: true));
    final receipt = File('${directory.path}/receipt.png');
    await receipt.writeAsBytes([1, 2, 3]);

    final bytes = await readLocalReceiptBytesForExport(
      receipt.path,
      allowedDirectories: [directory],
    );

    expect(bytes, isNull);
  });
}

const _pngHeader = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

Future<Excel> _workbook(
  List<ExpenseEntry> expenses, {
  bool includeSpaceSheets = true,
  DateTimeRange? selectedDateRange,
  Map<String, String> householdNames = const {'household-1': 'Family'},
}) async =>
    Excel.decodeBytes((await buildTransactionExportWorkbook(
      expenses,
      householdNames: householdNames,
      preferredTimezone: 'UTC+07:00',
      includeSpaceSheets: includeSpaceSheets,
      selectedDateRange: selectedDateRange,
    ))!);

List<Map<String, String>> _transactionRows(Sheet sheet) {
  final headers =
      sheet.rows.first.map((cell) => cell!.value.toString()).toList();
  return sheet.rows
      .skip(1)
      .map((row) => {
            for (var index = 0; index < headers.length; index++)
              headers[index]: row[index]?.value?.toString() ?? '',
          })
      .toList();
}

ExpenseEntry _entry({
  String id = 'expense',
  String? householdId,
  int amountCents = 10000,
  String currency = 'EUR',
  String? userName,
  String? accountName,
  String? rawText,
  String? merchant,
  String? merchantStructuredName,
  List<String>? breakdown,
  String? receiptImageUrl,
  String? bankAccountId,
  bool? providerPending,
  bool providerRecurring = false,
  String? analyticsClass,
  bool analyticsIsFinal = true,
  int? analyticsSpendingMultiplier,
  bool? analyticsCountsTowardIncome,
  String? type,
  String? parentRecurringId,
  DateTime? scheduledOccurrenceDate,
  DateTime? createdAt,
}) =>
    ExpenseEntry(
      id: id,
      householdId: householdId,
      date: DateTime(2026, 7, 13),
      amountCents: amountCents,
      currency: currency,
      category: 'groceries',
      createdAt: createdAt ?? DateTime.parse('2026-07-13T10:30:15Z'),
      userName: userName,
      accountName: accountName,
      rawText: rawText,
      merchant: merchant,
      merchantStructuredName: merchantStructuredName,
      breakdown: breakdown,
      receiptImageUrl: receiptImageUrl,
      bankAccountId: bankAccountId,
      providerPending: providerPending,
      providerRecurring: providerRecurring,
      analyticsClass: analyticsClass,
      analyticsIsFinal: analyticsIsFinal,
      analyticsSpendingMultiplier: analyticsSpendingMultiplier,
      analyticsCountsTowardIncome: analyticsCountsTowardIncome,
      type: type,
      parentRecurringId: parentRecurringId,
      scheduledOccurrenceDate: scheduledOccurrenceDate,
    );

// A transfer producer may supply the optional serialized wall-time contract
// even when the base transaction model predates that field.
class _TimedTransferEntry extends ExpenseEntry {
  _TimedTransferEntry()
      : super(
          id: 'transfer:example:out',
          date: DateTime(2026, 7, 13),
          amountCents: 10000,
          createdAt: DateTime.parse('2026-07-13T10:30:15Z'),
          analyticsClass: 'transfer_out',
        );

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'transfer_time': '09:15:30',
      };
}
