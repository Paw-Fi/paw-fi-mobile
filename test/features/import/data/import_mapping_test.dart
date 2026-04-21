import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/import/data/import_mapping.dart';
import 'package:moneko/features/import/domain/import_models.dart';

void main() {
  test('autoMapFields matches common headers', () {
    final headers = [
      'Transaction Date',
      'Amount',
      'Category',
      'Memo',
      'Merchant',
    ];
    final mapping = autoMapFields(headers);

    expect(mapping.fieldToColumnIndex[ImportField.date], 0);
    expect(mapping.fieldToColumnIndex[ImportField.amount], 1);
    expect(mapping.fieldToColumnIndex[ImportField.category], 2);
    expect(mapping.fieldToColumnIndex[ImportField.description], 3);
    expect(mapping.fieldToColumnIndex[ImportField.merchant], 4);
  });

  test('autoMapFields keeps payee separate from notes', () {
    final mapping = autoMapFields(['Date', 'Amount', 'Payee', 'Notes']);

    expect(mapping.fieldToColumnIndex[ImportField.date], 0);
    expect(mapping.fieldToColumnIndex[ImportField.amount], 1);
    expect(mapping.fieldToColumnIndex[ImportField.merchant], 2);
    expect(mapping.fieldToColumnIndex[ImportField.description], 3);
  });

  test('autoMapFieldsWithConfidence detects single expenses columns as debit',
      () {
    final result = autoMapFieldsWithConfidence(
      ['Item', 'Date', 'Expenses'],
      sampleRows: const [
        ['Resend', '10/01/2025', r'$20'],
        ['Twilio (WhatsApp)', '20/10/2025', r'$20'],
      ],
    );

    expect(result.mapping.fieldToColumnIndex[ImportField.description], 0);
    expect(result.mapping.fieldToColumnIndex[ImportField.date], 1);
    expect(result.mapping.fieldToColumnIndex[ImportField.debit], 2);
    expect(result.mapping.fieldToColumnIndex.containsKey(ImportField.amount),
        isFalse);
  });
}
