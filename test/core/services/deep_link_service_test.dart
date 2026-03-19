import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/core/constants/deep_links.dart';

void main() {
  late DeepLinkService service;

  setUp(() {
    service = DeepLinkService();
  });

  tearDown(() {
    service.dispose();
  });

  group('DeepLinkService - Household Invitation Deep Links', () {
    test('detects deep link household invitation format', () {
      final uri = Uri.parse('moneko://households/join?token=abc123xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('detects universal link household invitation format', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('detects universal link with www subdomain', () {
      final uri = Uri.parse('https://www.moneko.io/invites/abc123xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('detects http universal link', () {
      final uri = Uri.parse('http://moneko.io/invites/abc123xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('rejects invitation with wrong path', () {
      final uri = Uri.parse('moneko://households/create');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });

    test('rejects invitation with wrong domain', () {
      final uri = Uri.parse('https://example.com/invites/abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });
  });

  group('DeepLinkService - OAuth Callback Detection', () {
    test('detects Supabase OAuth callback', () {
      final uri = Uri.parse('io.supabase.moneko://login-callback');
      expect(DeepLinks.isOAuthCallback(uri), true);
    });

    test('detects legacy OAuth callback', () {
      final uri = Uri.parse('moneko://auth/callback');
      expect(DeepLinks.isLegacyOAuthCallback(uri), true);
    });

    test('rejects OAuth callback with wrong scheme', () {
      final uri = Uri.parse('moneko://login-callback');
      expect(DeepLinks.isOAuthCallback(uri), false);
    });
  });

  group('DeepLinkService - Payment Callback Detection', () {
    test('detects payment callback', () {
      final uri = Uri.parse('moneko://payment?status=success');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });

    test('detects payment callback without parameters', () {
      final uri = Uri.parse('moneko://payment');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });

    test('rejects payment callback with wrong scheme', () {
      final uri = Uri.parse('https://payment');
      expect(DeepLinks.isPaymentCallback(uri), false);
    });
  });

  group('DeepLinkService - WhatsApp Verification Detection', () {
    test('detects WhatsApp verification link', () {
      final uri = Uri.parse('moneko://verify-whatsapp?otp=123456');
      expect(DeepLinks.isWhatsAppVerification(uri), true);
    });

    test('detects WhatsApp verification without OTP', () {
      final uri = Uri.parse('moneko://verify-whatsapp');
      expect(DeepLinks.isWhatsAppVerification(uri), true);
    });

    test('rejects WhatsApp verification with wrong host', () {
      final uri = Uri.parse('moneko://verify-phone');
      expect(DeepLinks.isWhatsAppVerification(uri), false);
    });
  });

  group('DeepLinkService - Widget Quick Actions', () {
    test('detects widget text link', () {
      final uri = Uri.parse('moneko://text');
      expect(DeepLinks.isWidgetTextLink(uri), true);
    });

    test('detects widget camera link', () {
      final uri = Uri.parse('moneko://camera');
      expect(DeepLinks.isWidgetCameraLink(uri), true);
    });

    test('detects widget pockets link', () {
      final uri = Uri.parse('moneko://pockets');
      expect(DeepLinks.isWidgetPocketsLink(uri), true);
    });

    test('detects widget configure link', () {
      final uri = Uri.parse('moneko://configure_widget?widgetId=123');
      expect(DeepLinks.isWidgetConfigureLink(uri), true);
    });
  });

  group('DeepLinkService - Expense Link Detection', () {
    test('detects expense link', () {
      final uri = Uri.parse('moneko://expense/exp_123');
      expect(DeepLinks.isExpenseLink(uri), true);
    });

    test('rejects expense link without ID', () {
      final uri = Uri.parse('moneko://expense');
      expect(DeepLinks.isExpenseLink(uri), false);
    });
  });

  group('DeepLinkService - Household Link Detection', () {
    test('detects household link', () {
      final uri = Uri.parse('moneko://household/hh_123');
      expect(DeepLinks.isHouseholdLink(uri), true);
    });

    test('detects household link with sub-route', () {
      final uri = Uri.parse('moneko://household/hh_123/splits');
      expect(DeepLinks.isHouseholdLink(uri), true);
    });

    test('rejects household link without ID', () {
      final uri = Uri.parse('moneko://household');
      expect(DeepLinks.isHouseholdLink(uri), false);
    });
  });

  group('DeepLinkService - Home Link Detection', () {
    test('detects home link', () {
      final uri = Uri.parse('moneko://home');
      expect(DeepLinks.isHomeLink(uri), true);
    });

    test('rejects home link with wrong host', () {
      final uri = Uri.parse('moneko://dashboard');
      expect(DeepLinks.isHomeLink(uri), false);
    });

    test('detects insights link', () {
      final uri = Uri.parse('moneko://insights');
      expect(DeepLinks.isInsightsLink(uri), true);
    });

    test('detects recurring page link without id', () {
      final uri = Uri.parse('moneko://recurring');
      expect(DeepLinks.isRecurringPageLink(uri), true);
    });
  });

  group('DeepLinkService - Plaid Callback Detection', () {
    test('detects plaid callback', () {
      final uri = Uri.parse('moneko://plaid?link_token=token123');
      expect(DeepLinks.isPlaidCallback(uri), true);
    });

    test('detects plaid callback without parameters', () {
      final uri = Uri.parse('moneko://plaid');
      expect(DeepLinks.isPlaidCallback(uri), true);
    });
  });

  group('DeepLinkService - Edge Cases', () {
    test('handles empty URI gracefully', () {
      final uri = Uri.parse('');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
      expect(DeepLinks.isOAuthCallback(uri), false);
      expect(DeepLinks.isPaymentCallback(uri), false);
    });

    test('handles malformed URI', () {
      final uri = Uri.parse('not-a-valid-uri');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });

    test('handles URI with special characters in token', () {
      final uri = Uri.parse('moneko://households/join?token=abc-123_xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles URI with fragment', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123#section');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles URI with multiple query parameters', () {
      final uri =
          Uri.parse('moneko://households/join?token=abc123&source=email');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles URL encoding in parameters', () {
      final uri = Uri.parse('moneko://payment?error=Card%20declined');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });
  });

  group('DeepLinkService - Token Extraction from Universal Links', () {
    test('extracts token from standard universal link', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
      // Token would be extracted as second path segment
      expect(uri.pathSegments.length, 2);
      expect(uri.pathSegments[0], 'invites');
      expect(uri.pathSegments[1], 'abc123xyz');
    });

    test('extracts token from universal link with trailing slash', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123xyz/');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
      // Trailing slash creates 3 segments: ['invites', 'abc123xyz', '']
      expect(uri.pathSegments.length, 3);
      expect(uri.pathSegments[1], 'abc123xyz');
    });

    test('extracts token from universal link with query parameters', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123xyz?source=email');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
      expect(uri.pathSegments[1], 'abc123xyz');
      expect(uri.queryParameters['source'], 'email');
    });

    test('extracts token from deep link format', () {
      final uri = Uri.parse('moneko://households/join?token=abc123xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
      expect(uri.queryParameters['token'], 'abc123xyz');
    });
  });

  group('DeepLinkService - Multiple Deep Link Types', () {
    test('distinguishes between different deep link types', () {
      final householdUri = Uri.parse('moneko://households/join?token=abc');
      final expenseUri = Uri.parse('moneko://expense/exp_123');
      final budgetUri = Uri.parse('moneko://budget/bud_123');
      final homeUri = Uri.parse('moneko://home');

      expect(DeepLinks.isHouseholdInvitation(householdUri), true);
      expect(DeepLinks.isExpenseLink(householdUri), false);
      expect(DeepLinks.isBudgetLink(householdUri), false);
      expect(DeepLinks.isHomeLink(householdUri), false);

      expect(DeepLinks.isExpenseLink(expenseUri), true);
      expect(DeepLinks.isHouseholdInvitation(expenseUri), false);

      expect(DeepLinks.isBudgetLink(budgetUri), true);
      expect(DeepLinks.isExpenseLink(budgetUri), false);

      expect(DeepLinks.isHomeLink(homeUri), true);
      expect(DeepLinks.isHouseholdInvitation(homeUri), false);
    });
  });

  group('DeepLinkService - Service Lifecycle', () {
    test('service can be disposed', () {
      final testService = DeepLinkService();
      testService.dispose();
      // Test passes if no exceptions thrown
    });

    test('service can be disposed multiple times', () {
      final testService = DeepLinkService();
      testService.dispose();
      testService.dispose();
      // Test passes if no exceptions thrown
    });
  });

  group('DeepLinkService - Payment URL Generation', () {
    test('generates valid payment success URL', () {
      final url = DeepLinks.paymentSuccess();
      final uri = Uri.parse(url);

      expect(uri.scheme, 'moneko');
      expect(uri.host, 'payment');
      expect(uri.queryParameters['status'], 'success');
    });

    test('generates payment success URL with session ID', () {
      final url = DeepLinks.paymentSuccess(sessionId: 'sess_123');
      final uri = Uri.parse(url);

      expect(uri.queryParameters['status'], 'success');
      expect(uri.queryParameters['session_id'], 'sess_123');
    });

    test('generates valid payment failed URL', () {
      final url = DeepLinks.paymentFailed('Card declined');
      final uri = Uri.parse(url);

      expect(uri.queryParameters['status'], 'failed');
      expect(uri.queryParameters['error'], 'Card declined');
    });

    test('generates valid payment canceled URL', () {
      final url = DeepLinks.paymentCanceled();
      final uri = Uri.parse(url);

      expect(uri.queryParameters['status'], 'canceled');
    });
  });

  group('DeepLinkService - Complex Scenarios', () {
    test('handles household invitation with long token', () {
      final longToken = 'a' * 100;
      final uri = Uri.parse('moneko://households/join?token=$longToken');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
      expect(uri.queryParameters['token'], longToken);
    });

    test('handles universal link with complex token', () {
      const complexToken = 'abc-123_XYZ.456';
      final uri = Uri.parse('https://moneko.io/invites/$complexToken');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
      expect(uri.pathSegments[1], complexToken);
    });

    test('handles payment callback with URL-encoded error', () {
      const error = 'Payment failed: Insufficient funds';
      final url = DeepLinks.paymentFailed(error);
      final uri = Uri.parse(url);

      expect(uri.queryParameters['error'], error);
    });

    test('handles OAuth callback with fragment parameters', () {
      final uri = Uri.parse(
          'io.supabase.moneko://login-callback#access_token=abc123&refresh_token=xyz789');
      expect(DeepLinks.isOAuthCallback(uri), true);
      expect(uri.fragment, contains('access_token'));
      expect(uri.fragment, contains('refresh_token'));
    });
  });

  group('DeepLinkService - URL Validation', () {
    test('validates household invitation deep link structure', () {
      final uri = Uri.parse('moneko://households/join?token=abc123');

      expect(uri.scheme, 'moneko');
      expect(uri.host, 'households');
      expect(uri.path, '/join');
      expect(uri.queryParameters.containsKey('token'), true);
    });

    test('validates household invitation universal link structure', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123');

      expect(uri.scheme, 'https');
      expect(uri.host, 'moneko.io');
      expect(uri.pathSegments[0], 'invites');
      expect(uri.pathSegments.length, 2);
    });

    test('validates OAuth callback structure', () {
      final uri = Uri.parse('io.supabase.moneko://login-callback');

      expect(uri.scheme, 'io.supabase.moneko');
      expect(uri.host, 'login-callback');
    });

    test('validates payment callback structure', () {
      final uri = Uri.parse('moneko://payment?status=success');

      expect(uri.scheme, 'moneko');
      expect(uri.host, 'payment');
      expect(uri.queryParameters.containsKey('status'), true);
    });
  });
}
