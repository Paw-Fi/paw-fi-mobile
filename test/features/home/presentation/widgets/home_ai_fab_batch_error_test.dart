import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';

void main() {
  test('shouldFallbackForBatchError returns true for bad file descriptor', () {
    expect(
      shouldFallbackForBatchError(Exception('Bad file descriptor')),
      isTrue,
    );
  });

  test('shouldFallbackForBatchError returns true for 404 responses', () {
    expect(
      shouldFallbackForBatchError(Exception('404 NOT_FOUND')),
      isTrue,
    );
  });

  test('shouldFallbackForBatchError returns false for other errors', () {
    expect(
      shouldFallbackForBatchError(Exception('Unexpected error')),
      isFalse,
    );
  });
}
