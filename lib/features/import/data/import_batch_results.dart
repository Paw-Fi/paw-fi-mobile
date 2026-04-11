class ImportBatchResultCounts {
  const ImportBatchResultCounts({
    required this.succeeded,
    required this.failed,
    required this.skipped,
    this.errorMessage,
  });

  final int succeeded;
  final int failed;
  final int skipped;
  final String? errorMessage;
}

ImportBatchResultCounts countImportBatchResults({
  required dynamic data,
  required int expectedCount,
}) {
  if (data is! Map<String, dynamic>) {
    return ImportBatchResultCounts(
      succeeded: 0,
      failed: expectedCount,
      skipped: 0,
      errorMessage:
          'We received an unexpected response while importing your file. Please try again.',
    );
  }

  final resultsRaw = data['results'];
  if (resultsRaw is List) {
    final seenIndices = <int>{};
    var succeeded = 0;
    var failed = 0;
    var skipped = 0;

    for (final item in resultsRaw) {
      if (item is! Map) continue;
      final index = (item['index'] as num?)?.toInt();
      if (index == null || index < 0 || index >= expectedCount) continue;
      if (!seenIndices.add(index)) continue;

      if (item['success'] == true) {
        succeeded += 1;
        continue;
      }

      if (item['duplicate'] == true) {
        skipped += 1;
        continue;
      }

      failed += 1;
    }

    final unresolved = expectedCount - seenIndices.length;
    if (unresolved > 0) {
      failed += unresolved;
    }

    final errorMessage = (failed > 0)
        ? (unresolved > 0
            ? 'Some rows were not acknowledged by the server. Please retry import.'
            : 'Some rows could not be imported. Please review your file and try again.')
        : null;

    return ImportBatchResultCounts(
      succeeded: succeeded,
      failed: failed,
      skipped: skipped,
      errorMessage: errorMessage,
    );
  }

  final summary = data['summary'];
  if (summary is Map<String, dynamic>) {
    final summarySucceeded = (summary['succeeded'] as num?)?.toInt() ?? 0;
    final summaryFailed = (summary['failed'] as num?)?.toInt() ?? 0;
    final accounted = summarySucceeded + summaryFailed;
    if (accounted == expectedCount) {
      return ImportBatchResultCounts(
        succeeded: summarySucceeded,
        failed: summaryFailed,
        skipped: 0,
        errorMessage: summaryFailed > 0
            ? 'Some rows could not be imported. Please review your file and try again.'
            : null,
      );
    }
  }

  final backendSuccess = data['success'] == true;
  return ImportBatchResultCounts(
    succeeded: backendSuccess ? expectedCount : 0,
    failed: backendSuccess ? 0 : expectedCount,
    skipped: 0,
    errorMessage: backendSuccess
        ? null
        : 'Some rows could not be imported. Please review your file and try again.',
  );
}
