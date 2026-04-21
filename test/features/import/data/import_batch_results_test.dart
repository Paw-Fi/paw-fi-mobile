import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/import/data/import_batch_results.dart';

void main() {
  test('does not count duplicate results as failed imports', () {
    final result = countImportBatchResults(
      data: {
        'results': [
          {'index': 0, 'success': true},
          {'index': 1, 'success': false, 'duplicate': true},
          {'index': 2, 'success': false, 'error': 'validation failed'},
        ],
      },
      expectedCount: 3,
    );

    expect(result.succeeded, 1);
    expect(result.failed, 1);
    expect(result.skipped, 1);
    expect(result.errorMessage, isNotNull);
  });
}
