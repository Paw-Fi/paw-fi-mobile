import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/services/sse_service.dart';

void main() {
  test('stream HTTP errors retain backend details without resending', () async {
    var requests = 0;
    const failure = {
      'success': false,
      'code': 'AI_CLARIFICATION_FAILED',
      'error': "We couldn't check the transaction details. Please try again.",
    };
    final events = await http.runWithClient(
      () => SSEService.streamRequest(
        url: Uri.parse('https://example.invalid/analyze-expense?stream=true'),
        body: {'text': '買い物５０円'},
      ).toList(),
      () => MockClient((request) async {
        requests++;
        return http.Response(jsonEncode(failure), 503,
            headers: {'content-type': 'application/json'});
      }),
    );
    expect(requests, 1);
    expect(events, hasLength(1));
    expect(events.single.event, 'error');
    expect(events.single.data, {...failure, 'status': 503});
  });

  test('non-JSON stream HTTP errors do not expose response bodies', () async {
    final events = await http.runWithClient(
      () => SSEService.streamRequest(
        url: Uri.parse('https://example.invalid/analyze-expense?stream=true'),
        body: {'text': '買い物５０円'},
      ).toList(),
      () => MockClient(
          (_) async => http.Response('<html>internal error</html>', 502)),
    );
    expect(events.single.event, 'error');
    expect(events.single.data, {'status': 502});
  });

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
