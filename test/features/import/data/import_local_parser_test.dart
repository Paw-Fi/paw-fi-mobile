import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/import/data/import_local_parser.dart';

void main() {
  test('parseLocalImportTable parses csv bytes off main flow', () async {
    final csvBytes = Uint8List.fromList(
      utf8.encode('date,amount,category\n2026-02-01,19.99,Food'),
    );

    final table = await parseLocalImportTable(
      LocalImportParseRequest(bytes: csvBytes, extension: 'csv'),
    );

    expect(table.headers, ['date', 'amount', 'category']);
    expect(table.rows, [
      ['2026-02-01', '19.99', 'Food'],
    ]);
  });

  test('parseLocalImportTable parses txt bytes', () async {
    final txtBytes = Uint8List.fromList(
      utf8.encode('date,amount,category\n2026-02-02,35.00,Transport'),
    );

    final table = await parseLocalImportTable(
      LocalImportParseRequest(bytes: txtBytes, extension: 'txt'),
    );

    expect(table.headers, ['date', 'amount', 'category']);
    expect(table.rows, [
      ['2026-02-02', '35.00', 'Transport'],
    ]);
  });

  test(
      'parseLocalImportTable preserves rows for quoted CSV with trailing spaces',
      () async {
    final csvBytes = Uint8List.fromList(
      utf8.encode(
        '"TIME","TYPE","AMOUNT","CATEGORY","ACCOUNT","NOTES" \n'
        '"Feb 05, 2025 7:08 AM","(-) Expense","200.00","Food","Cash","chanay aur dahi" \n'
        '"Apr 14, 2025 1:10 PM","(*) Transfer","5000.00","  -  ","Cash->Meezan","mama withdraw" \n'
        '"Apr 14, 2025 6:03 PM","(+) Income","222407.00","Direct","Meezan","Andre" ',
      ),
    );

    final table = await parseLocalImportTable(
      LocalImportParseRequest(bytes: csvBytes, extension: 'csv'),
    );

    expect(table.headers,
        ['TIME', 'TYPE', 'AMOUNT', 'CATEGORY', 'ACCOUNT', 'NOTES']);
    expect(table.rows.length, 3);
    expect(table.rows.first.first, 'Feb 05, 2025 7:08 AM');
    expect(table.rows[1][5], 'mama withdraw');
  });

  test('parseLocalImportTable parses xlsx bytes', () async {
    final xlsxBytes = _buildWorkbookBytes();

    final table = await parseLocalImportTable(
      LocalImportParseRequest(bytes: xlsxBytes, extension: 'xlsx'),
    );

    expect(table.headers, ['date', 'amount', 'category']);
    expect(table.rows, [
      ['2026-02-03', '12.99', 'Coffee'],
    ]);
  });

  test('parseLocalImportTable supports xls extension', () async {
    final xlsxBytes = _buildWorkbookBytes();

    final table = await parseLocalImportTable(
      LocalImportParseRequest(bytes: xlsxBytes, extension: 'xls'),
    );

    expect(table.headers, ['date', 'amount', 'category']);
    expect(table.rows, [
      ['2026-02-03', '12.99', 'Coffee'],
    ]);
  });

  test('parseLocalImportTable throws for invalid spreadsheet bytes', () async {
    final malformed = Uint8List.fromList(utf8.encode('not-an-excel-file'));

    expect(
      () => parseLocalImportTable(
        LocalImportParseRequest(bytes: malformed, extension: 'xlsx'),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}

Uint8List _buildWorkbookBytes() {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet == null) {
    throw StateError('Failed to create default worksheet');
  }

  final sheet = excel[defaultSheet];
  sheet.appendRow([
    TextCellValue('date'),
    TextCellValue('amount'),
    TextCellValue('category'),
  ]);
  sheet.appendRow([
    TextCellValue('2026-02-03'),
    TextCellValue('12.99'),
    TextCellValue('Coffee'),
  ]);

  final encoded = excel.encode();
  if (encoded == null) {
    throw StateError('Failed to encode workbook');
  }
  return Uint8List.fromList(encoded);
}
