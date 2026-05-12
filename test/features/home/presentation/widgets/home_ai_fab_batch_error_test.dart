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

  test('shouldQueueAiInputForRetry returns true for network failures', () {
    expect(
      shouldQueueAiInputForRetry(Exception('Failed host lookup')),
      isTrue,
    );
  });

  test('shouldQueueAiInputForRetry returns true for structured 503 payloads',
      () {
    expect(
      shouldQueueAiInputForRetry({
        'success': false,
        'status': 503,
        'code': 'SUPABASE_EDGE_RUNTIME_ERROR',
      }),
      isTrue,
    );
  });

  test('shouldQueueAiInputForRetry returns false for validation failures', () {
    expect(
      shouldQueueAiInputForRetry(Exception('Invalid receipt image')),
      isFalse,
    );
  });

  test('buildQueuedAiInputPayload stores media paths without inline bytes', () {
    final payload = buildQueuedAiInputPayload(
      userId: 'user_1',
      householdId: 'household_1',
      isPortfolio: false,
      accountId: 'account_1',
      analysisBody: {
        'userId': 'user_1',
        'date': '2026-05-12',
        'text': 'coffee 5',
        'image': {'data': 'base64-image', 'contentType': 'image/jpeg'},
        'audio': {'data': 'base64-audio', 'contentType': 'audio/aac'},
      },
      localImagePath: '/local/receipt.jpg',
      imageContentType: 'image/jpeg',
      localAudioPath: '/local/voice.aac',
      audioContentType: 'audio/aac',
    );

    expect(payload['userId'], 'user_1');
    expect(payload['householdId'], 'household_1');
    expect(payload['accountId'], 'account_1');
    expect(payload['localImagePath'], '/local/receipt.jpg');
    expect(payload['localAudioPath'], '/local/voice.aac');

    final body = payload['body'] as Map<String, dynamic>;
    expect(body['text'], 'coffee 5');
    expect(body.containsKey('image'), isFalse);
    expect(body.containsKey('audio'), isFalse);
  });
}
