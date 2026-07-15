import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/notification_capture_service.dart';

void main() {
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
