import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';

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
