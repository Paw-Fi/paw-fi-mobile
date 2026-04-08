import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/sse_service.dart';

void main() {
  test('formatStreamingProgressMessage includes counts when present', () {
    expect(
      formatStreamingProgressMessage(
        'Saving transactions...',
        currentItem: 27,
        totalItems: 2356,
      ),
      'Saving transactions... (27/2356)',
    );
  });

  test('StreamingProgressEvent parses numeric fields and formats message', () {
    final event = StreamingProgressEvent.fromJson(const {
      'stage': 'saving_expense',
      'message': 'Saving transactions...',
      'currentItem': 500,
      'totalItems': 2356,
    });

    expect(event.stage, 'saving_expense');
    expect(event.currentItem, 500);
    expect(event.totalItems, 2356);
    expect(event.displayMessage, 'Saving transactions... (500/2356)');
  });
}
