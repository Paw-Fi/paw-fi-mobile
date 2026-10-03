import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/profile/data/email_import_settings_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const settingsErrors = [
    (
      401,
      'UNAUTHORIZED',
      'Your session has expired. Please sign in again to manage email import.'
    ),
    (
      403,
      'UNAUTHORIZED',
      'You no longer have access to this space. Please choose another destination.'
    ),
    (400, 'INVALID_EMAIL', 'Please enter a valid email address.'),
    (
      400,
      'DEFAULT_EMAIL_IMMUTABLE',
      "Your Moneko account email is always an allowed sender and can't be removed here."
    ),
    (
      409,
      'EMAIL_ALREADY_CLAIMED',
      'This email is already linked to another Moneko account. If both accounts are yours, contact support for help adding this sender.'
    ),
    (
      500,
      'SERVER_ERROR',
      "We couldn't check your Plus access. Please try again."
    ),
  ];

  for (final (status, code, message) in settingsErrors) {
    test('email settings preserves backend $status $code copy', () {
      expect(
        ErrorHandler.getUserFriendlyMessage(
          FunctionException(
              status: status, details: {'code': code, 'error': message}),
          context: BackendErrorContext.emailImportSettings,
        ),
        message,
      );
    });
  }

  test('Plus denial remains recognizable for the highlighted lock sheet', () {
    const error = FunctionException(status: 403, details: {
      'code': 'SUBSCRIPTION_REQUIRED',
      'error': 'Email File Import requires Moneko Plus.',
    });
    expect(ErrorHandler.isPlusFeatureLimitError(error), isTrue);
    expect(
        ErrorHandler.getUserFriendlyMessage(error,
            context: BackendErrorContext.emailImportSettings),
        'Email File Import requires Moneko Plus.');
  });

  test('logical backend failure preserves its structured message and code',
      () async {
    final client = SupabaseClient(
      'https://example.test',
      'anon-key',
      httpClient: MockClient((_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': 'Please enter a valid email address.',
            'code': 'INVALID_EMAIL',
          }),
          200,
          headers: {'content-type': 'application/json'})),
    );
    addTearDown(client.dispose);
    await expectLater(
      EmailImportSettingsService(client: client)
          .addWhitelistEmail('sender@example.com'),
      throwsA(isA<FunctionException>().having(
        (error) => ErrorHandler.getUserFriendlyMessage(error,
            context: BackendErrorContext.emailImportSettings),
        'friendly backend message',
        'Please enter a valid email address.',
      )),
    );
  });

  test(
      'unexpected payload uses an email-settings message instead of file errors',
      () async {
    final client = SupabaseClient(
      'https://example.test',
      'anon-key',
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    addTearDown(client.dispose);
    try {
      await EmailImportSettingsService(client: client).getSettings();
      fail('Expected invalid settings data to be rejected');
    } catch (error) {
      expect(
        ErrorHandler.getUserFriendlyMessage(error,
            context: BackendErrorContext.emailImportSettings),
        "We couldn't read your email import settings. Please try again.",
      );
    }
  });

  test('email settings preserves non-English backend copy', () {
    const error = FunctionException(status: 403, details: {
      'code': 'UNAUTHORIZED',
      'error': '您已無法存取這個空間。請選擇其他空間。',
    });
    expect(
      ErrorHandler.getUserFriendlyMessage(error,
          context: BackendErrorContext.emailImportSettings),
      '您已無法存取這個空間。請選擇其他空間。',
    );
  });

  const messages = {
    'DEFAULT_EMAIL_ALREADY_INCLUDED':
        'Your Moneko account email is already an allowed sender. No need to add it again.',
    'EMAIL_ALREADY_CLAIMED':
        'This email is linked to another Moneko account. Please use a different email address.',
  };

  for (final entry in messages.entries) {
    test('add sender displays the backend message for ${entry.key}', () async {
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'action': 'add_whitelist',
            'email': 'sender@example.com',
            'senderVerificationVersion': 1,
          });
          return http.Response(
            jsonEncode({
              'success': false,
              'error': entry.value,
              'code': entry.key,
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);

      try {
        await EmailImportSettingsService(client: client)
            .addWhitelistEmail('sender@example.com');
        fail('Expected the backend rejection');
      } on FunctionException catch (error) {
        expect(ErrorHandler.getUserFriendlyMessage(error), entry.value);
      }
    });
  }

  test('unrelated conflicts retain the refresh message', () {
    expect(
      ErrorHandler.getUserFriendlyMessage(const FunctionException(
        status: 409,
        details: {'code': 'CONFLICT', 'error': 'Revision mismatch'},
      )),
      'This item changed recently. Please refresh and try again.',
    );
  });

  test('email conflict without safe backend copy retains a safe fallback', () {
    expect(
      ErrorHandler.getUserFriendlyMessage(const FunctionException(
        status: 409,
        details: {
          'code': 'EMAIL_ALREADY_CLAIMED',
          'error': 'Stack details: {internal database information}',
        },
      )),
      'This item changed recently. Please refresh and try again.',
    );
  });
}
