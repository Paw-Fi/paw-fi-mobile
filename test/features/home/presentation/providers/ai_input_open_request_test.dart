import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/providers/ai_input_capture_provider.dart';

void main() {
  const capture = 'ai_input_0123456789abcdef0123456789abcdef';
  final uri = Uri(scheme: 'moneko', host: 'ai-analysis', queryParameters: {
    'userId': 'owner',
    'captureId': capture,
    'executionId': '$capture:123:1',
  });

  test('native attention URL retains its exact actor, capture and attempt', () {
    final target = AiInputOpenRequest.fromUri(uri)!;
    expect(target.userId, 'owner');
    expect(target.captureId, capture);
    expect(target.executionId, '$capture:123:1');
  });

  test(
      'attention links reject malformed, repeated and cross-capture identities',
      () {
    for (final invalid in [
      uri.replace(scheme: 'https'),
      uri.replace(host: 'other'),
      uri.replace(path: '/extra'),
      uri.replace(fragment: 'extra'),
      uri.replace(userInfo: 'external'),
      uri.replace(port: 123),
      uri.replace(query: '${uri.query}&userId=other'),
      uri.replace(query: '${uri.query}&extra=1'),
      uri.replace(queryParameters: {
        ...uri.queryParameters,
        'captureId': 'not-a-capture'
      }),
      uri.replace(queryParameters: {
        ...uri.queryParameters,
        'executionId': 'other:123:1'
      }),
    ]) {
      expect(AiInputOpenRequest.fromUri(invalid), isNull, reason: '$invalid');
    }
  });
}
