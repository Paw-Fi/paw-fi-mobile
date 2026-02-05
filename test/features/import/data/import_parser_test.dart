import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';

void main() {
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
    final mapping = ImportMapping(
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
}
