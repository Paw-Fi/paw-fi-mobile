import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Map<String, dynamic> record(String id, {String owner = 'actor-1'}) => {
        'id': id,
        'userId': owner,
        'body':
            '{"notification":{"text":"คุณโอน ฿10.00"},"idempotencyKey":"$id"}',
      };

  test(
      'replay stops after account switch and does not send other actor records',
      () async {
    var currentActor = 'actor-1';
    final sent = <String>[];
    final completed = await replayPendingNotificationCaptures(
      userId: 'actor-1',
      records: [
        record('wrong', owner: 'actor-2'),
        record('first'),
        record('second')
      ],
      currentUserId: () => currentActor,
      invoke: (endpoint, body) async {
        expect(endpoint, 'classify-notification-capture');
        sent.add(body['idempotencyKey'] as String);
        currentActor = 'actor-2';
        return FunctionResponse(status: 200, data: {
          'success': true,
          'data': {'id': 'saved'}
        });
      },
    );
    expect(sent, ['first']);
    expect(completed, ['first']);
  });

  test('replay never starts after ownership changed while loading queue',
      () async {
    final completed = await replayPendingNotificationCaptures(
      userId: 'actor-1',
      records: [record('first')],
      currentUserId: () => 'actor-2',
      invoke: (_, __) async => throw StateError('Must not send'),
    );
    expect(completed, isEmpty);
  });

  test('replay retains malformed success and stops instead of draining queue',
      () async {
    for (final response in [
      null,
      '<html>proxy error</html>',
      {'success': true},
      {'success': false}
    ]) {
      var calls = 0;
      final completed = await replayPendingNotificationCaptures(
        userId: 'actor-1',
        records: [record('first'), record('second')],
        currentUserId: () => 'actor-1',
        invoke: (_, __) async {
          calls++;
          return FunctionResponse(status: 200, data: response);
        },
      );
      expect(completed, isEmpty);
      expect(calls, 1);
    }
  });

  test(
      'replay keeps in-progress and transient failures but removes terminal and ignored results',
      () async {
    for (final status in [401, 408, 425, 429, 500, 503, 409]) {
      final completed = await replayPendingNotificationCaptures(
        userId: 'actor-1',
        records: [record('first')],
        currentUserId: () => 'actor-1',
        invoke: (_, __) async => throw FunctionException(
            status: status, details: {'code': 'REQUEST_IN_PROGRESS'}),
      );
      expect(completed, isEmpty, reason: '$status');
    }
    final completed = await replayPendingNotificationCaptures(
      userId: 'actor-1',
      records: [record('terminal'), record('ignored'), record('saved')],
      currentUserId: () => 'actor-1',
      invoke: (_, body) async => body['idempotencyKey'] == 'terminal'
          ? throw const FunctionException(status: 422)
          : FunctionResponse(
              status: 200, data: {'success': true, 'ignored': true}),
    );
    expect(completed, ['terminal', 'ignored', 'saved']);
  });
  test('NotificationCaptureConfig maps account selection fields', () {
    final config = NotificationCaptureConfig.fromMap({
      'enabled': true,
      'scopeId': 'personal',
      'scopeName': 'Personal',
      'isPortfolio': false,
      'accountId': 'wallet-1',
      'accountName': 'Spending',
    });

    expect(config.accountId, 'wallet-1');
    expect(config.accountName, 'Spending');

    final copied = config.copyWith(
      accountId: 'wallet-2',
      accountName: 'Travel',
    );

    expect(copied.accountId, 'wallet-2');
    expect(copied.accountName, 'Travel');
  });

  test('NotificationCaptureConfig maps native auth expiry diagnostics', () {
    final config = NotificationCaptureConfig.fromMap({
      'expiresAt': 1893456000,
      'isAccessTokenExpired': true,
    });

    expect(config.expiresAt, 1893456000);
    expect(config.isAccessTokenExpired, isTrue);

    final copied = config.copyWith(
      expiresAt: 1893457000,
      isAccessTokenExpired: false,
    );

    expect(copied.expiresAt, 1893457000);
    expect(copied.isAccessTokenExpired, isFalse);
  });

  test('retryable in-progress captures remain pending', () {
    expect(
      shouldRemovePendingNotificationCapture(
        status: 409,
        responseBody: const {'code': 'REQUEST_IN_PROGRESS'},
      ),
      isFalse,
    );
  });

  test('string in-progress responses remain pending', () {
    expect(
      shouldRemovePendingNotificationCapture(
        status: 409,
        responseBody: '{"code":"REQUEST_IN_PROGRESS"}',
      ),
      isFalse,
    );
    expect(
      shouldRemovePendingNotificationCapture(
        status: 409,
        responseBody: 'REQUEST_IN_PROGRESS',
      ),
      isFalse,
    );
  });

  test('terminal pending captures are removed', () {
    expect(
      shouldRemovePendingNotificationCapture(
        status: 422,
        responseBody: const {'code': 'VALIDATION_ERROR'},
      ),
      isTrue,
    );
    expect(
      shouldRemovePendingNotificationCapture(
        status: 403,
        responseBody: const {'code': 'SUBSCRIPTION_REQUIRED'},
      ),
      isTrue,
    );
  });

  test('rate-limited captures remain pending for a later retry', () {
    expect(
      shouldRemovePendingNotificationCapture(
        status: 429,
        responseBody: const {'code': 'RATE_LIMITED'},
      ),
      isFalse,
    );
  });
}
