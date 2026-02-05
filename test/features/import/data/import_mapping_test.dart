import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/import/data/import_mapping.dart';
import 'package:moneko/features/import/domain/import_models.dart';

void main() {
  test('autoMapFields matches common headers', () {
    final headers = ['Transaction Date', 'Amount', 'Category', 'Memo'];
    final mapping = autoMapFields(headers);

    expect(mapping.fieldToColumnIndex[ImportField.date], 0);
    expect(mapping.fieldToColumnIndex[ImportField.amount], 1);
    expect(mapping.fieldToColumnIndex[ImportField.category], 2);
    expect(mapping.fieldToColumnIndex[ImportField.description], 3);
  });
}
