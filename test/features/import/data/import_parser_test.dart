import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:intl/intl.dart';

void main() {
  test('decodeImportTextFromBytes supports UTF-8', () {
    final bytes = Uint8List.fromList(
      utf8.encode('date,description\n2026-02-01,Coffee shop'),
    );

    final decoded = decodeImportTextFromBytes(bytes);

    expect(decoded, contains('Coffee shop'));
  });

  test('decodeImportTextFromBytes falls back to latin1', () {
    final bytes = Uint8List.fromList(
      latin1.encode('date,description\n2026-02-01,Café'),
    );

    final decoded = decodeImportTextFromBytes(bytes);

    expect(decoded, contains('Café'));
  });

  test('decodeImportTextFromBytes handles UTF-16 LE BOM', () {
    const text = 'date,description\n2026-02-01,Salary';
    final codeUnits = text.codeUnits;
    final bytes = <int>[0xFF, 0xFE];
    for (final unit in codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }

    final decoded = decodeImportTextFromBytes(Uint8List.fromList(bytes));

    expect(decoded, contains('Salary'));
  });

  test('detectDelimiter prefers the most frequent delimiter', () {
    expect(detectDelimiter('date,amount,category'), ',');
    expect(detectDelimiter('date\tamount\tcategory'), '\t');
    expect(detectDelimiter('date;amount;category'), ';');
  });

  test('parseImportTable reads header and rows', () {
    const content = 'date,amount,category\n2026-02-01,12.5,Food';
    final table = parseImportTable(content);

    expect(table.headers, ['date', 'amount', 'category']);
    expect(table.rows.length, 1);
    expect(table.rows.first, ['2026-02-01', '12.5', 'Food']);
  });

  test('parseImportTable handles quoted CSV rows with trailing spaces', () {
    const content = '"TIME","TYPE","AMOUNT","CATEGORY","ACCOUNT","NOTES" \n'
        '"Feb 05, 2025 7:08 AM","(-) Expense","200.00","Food","Cash","chanay aur dahi" \n'
        '"Apr 14, 2025 1:10 PM","(*) Transfer","5000.00","  -  ","Cash->Meezan","mama withdraw" \n'
        '"Apr 14, 2025 6:03 PM","(+) Income","222407.00","Direct","Meezan","Andre" ';

    final table = parseImportTable(content);

    expect(
      table.headers,
      ['TIME', 'TYPE', 'AMOUNT', 'CATEGORY', 'ACCOUNT', 'NOTES'],
    );
    expect(table.rows.length, 3);
    expect(table.rows[0], [
      'Feb 05, 2025 7:08 AM',
      '(-) Expense',
      '200.00',
      'Food',
      'Cash',
      'chanay aur dahi',
    ]);
    expect(table.rows[1][5], 'mama withdraw');
    expect(table.rows[2][4], 'Meezan');
  });

  test('parseImportTable preserves embedded newlines inside quoted fields', () {
    const content = '"date","notes","amount"\n'
        '"2025-02-05","first line  \nsecond line","12.50"\n'
        '"2025-02-06","single line","9.00"';

    final table = parseImportTable(content);

    expect(table.rows.length, 2);
    expect(table.rows.first[1], 'first line  \nsecond line');
    expect(table.rows.last[1], 'single line');
  });

  test('parseRow maps required fields and validates', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.category: 2,
      },
    );
    final row = ['2026-02-01', '12.50', 'Food'];
    final parsed = parseRow(row, mapping);

    expect(parsed.errors, isEmpty);
    expect(parsed.date, DateTime(2026, 2, 1));
    expect(parsed.amountCents, 1250);
    expect(parsed.category, 'Food');
  });

  test('parseDateValue parses English month with 12-hour time', () {
    final parsed = parseDateValue('Feb 05, 2025 7:08 AM');

    expect(parsed, DateTime(2025, 2, 5));
  });

  test(
      'parseDateValue parses English month with 12-hour time on non-English locale',
      () {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'fr_FR';

    addTearDown(() {
      Intl.defaultLocale = previousLocale;
    });

    final parsed = parseDateValue('  "Apr 14, 2025 1:10 PM"  ');

    expect(parsed, DateTime(2025, 4, 14));
  });

  test(
      'parseDateValue parses English month with 24-hour time on non-English locale',
      () {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'fr_FR';

    addTearDown(() {
      Intl.defaultLocale = previousLocale;
    });

    final parsed = parseDateValue('Apr 14, 2025 13:10');

    expect(parsed, DateTime(2025, 4, 14));
  });

  test('parseRow validates exported app CSV rows with TIME and AMOUNT columns',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.type: 1,
        ImportField.amount: 2,
        ImportField.category: 3,
        ImportField.description: 5,
      },
    );

    final parsed = parseRow(
      [
        'Feb 05, 2025 7:08 AM',
        '(-) Expense',
        '200.00',
        'Food',
        'Cash',
        'chanay aur dahi',
      ],
      mapping,
    );

    expect(parsed.isValid, isTrue);
    expect(parsed.date, DateTime(2025, 2, 5));
    expect(parsed.amountCents, 20000);
    expect(parsed.type, 'expense');
    expect(parsed.description, 'chanay aur dahi');
  });

  test(
      'parseRow infers currency from amount text when no currency column exists',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
      },
    );

    final parsed = parseRow(
      ['2025-02-05', 'EUR 12.50'],
      mapping,
    );

    expect(parsed.currency, 'EUR');
    expect(parsed.amountCents, 1250);
  });

  test('parseRow does not use opaque reference ids as description fallback',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.reference: 2,
      },
    );
    final row = ['2026-02-01', '12.50', '9f3b5c2a-4b37-4c0d-9f7a-4f9c5c2b1e88'];
    final parsed = parseRow(row, mapping);

    expect(parsed.description, isNull);
  });

  test('parseRow uses meaningful reference text as description fallback', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.reference: 2,
      },
    );
    final row = ['2026-02-01', '12.50', 'Blue Bottle coffee beans'];
    final parsed = parseRow(row, mapping);

    expect(parsed.description, 'Blue Bottle coffee beans');
  });
}
