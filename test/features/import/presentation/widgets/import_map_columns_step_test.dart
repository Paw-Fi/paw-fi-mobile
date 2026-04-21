import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/widgets/import_map_columns_step.dart';

void main() {
  test('single debit-column mappings can proceed without forcing amount', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 1,
        ImportField.debit: 2,
      },
    );

    final layout = resolveImportFieldLayout(mapping);

    expect(layout.requiredFields, [ImportField.date, ImportField.debit]);
    expect(layout.optionalFields, contains(ImportField.amount));
    expect(layout.optionalFields, contains(ImportField.credit));
    expect(layout.optionalFields, contains(ImportField.merchant));
    expect(layout.canProceed, isTrue);
  });

  test('split debit-credit mode still requires both directional columns', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 1,
        ImportField.debit: 2,
      },
      hasSplitDebitCredit: true,
    );

    final layout = resolveImportFieldLayout(mapping);

    expect(
      layout.requiredFields,
      [ImportField.date, ImportField.debit, ImportField.credit],
    );
    expect(layout.canProceed, isFalse);
  });
}
