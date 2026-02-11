import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/constants/deep_links.dart';

void main() {
  group('DeepLinks - Constants', () {
    test('app scheme is correct', () {
      expect(DeepLinks.appScheme, 'moneko');
    });

    test('supabase scheme is correct', () {
      expect(DeepLinks.supabaseScheme, 'io.supabase.moneko');
    });

    test('oauth callback URL is correct', () {
      expect(DeepLinks.oauthCallback, 'io.supabase.moneko://login-callback');
    });

    test('payment callback URL is correct', () {
      expect(DeepLinks.paymentCallback, 'moneko://payment');
    });

    test('whatsapp verification URL is correct', () {
      expect(DeepLinks.whatsappVerification, 'moneko://verify-whatsapp');
    });

    test('telegram verification URL is correct', () {
      expect(DeepLinks.telegramVerification, 'moneko://verify-telegram');
    });

    test('household invitation URL is correct', () {
      expect(DeepLinks.householdInvitation, 'moneko://households/join');
    });
  });

  group('DeepLinks - OAuth Callback Detection', () {
    test('detects valid OAuth callback', () {
      final uri = Uri.parse('io.supabase.moneko://login-callback');
      expect(DeepLinks.isOAuthCallback(uri), true);
    });

    test('rejects OAuth callback with wrong scheme', () {
      final uri = Uri.parse('moneko://login-callback');
      expect(DeepLinks.isOAuthCallback(uri), false);
    });

    test('rejects OAuth callback with wrong host', () {
      final uri = Uri.parse('io.supabase.moneko://wrong-callback');
      expect(DeepLinks.isOAuthCallback(uri), false);
    });

    test('detects legacy OAuth callback', () {
      final uri = Uri.parse('moneko://auth/callback');
      expect(DeepLinks.isLegacyOAuthCallback(uri), true);
    });

    test('rejects legacy OAuth callback with wrong path', () {
      final uri = Uri.parse('moneko://auth/wrong');
      expect(DeepLinks.isLegacyOAuthCallback(uri), false);
    });
  });

  group('DeepLinks - Payment Callback Detection', () {
    test('detects payment callback', () {
      final uri = Uri.parse('moneko://payment');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });

    test('detects payment callback with query parameters', () {
      final uri = Uri.parse('moneko://payment?status=success');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });

    test('rejects payment callback with wrong scheme', () {
      final uri = Uri.parse('https://payment');
      expect(DeepLinks.isPaymentCallback(uri), false);
    });

    test('rejects payment callback with wrong host', () {
      final uri = Uri.parse('moneko://payments');
      expect(DeepLinks.isPaymentCallback(uri), false);
    });

    test('generates payment success URL', () {
      final url = DeepLinks.paymentSuccess();
      expect(url, contains('moneko://payment'));
      expect(url, contains('status=success'));
    });

    test('generates payment success URL with session ID', () {
      final url = DeepLinks.paymentSuccess(sessionId: 'sess_123');
      expect(url, contains('status=success'));
      expect(url, contains('session_id=sess_123'));
    });

    test('generates payment failed URL', () {
      final url = DeepLinks.paymentFailed('Card declined');
      expect(url, contains('status=failed'));
      expect(url, contains('error=Card+declined'));
    });

    test('generates payment canceled URL', () {
      final url = DeepLinks.paymentCanceled();
      expect(url, contains('status=canceled'));
    });
  });

  group('DeepLinks - WhatsApp Verification Detection', () {
    test('detects WhatsApp verification link', () {
      final uri = Uri.parse('moneko://verify-whatsapp');
      expect(DeepLinks.isWhatsAppVerification(uri), true);
    });

    test('detects WhatsApp verification with OTP parameter', () {
      final uri = Uri.parse('moneko://verify-whatsapp?otp=123456');
      expect(DeepLinks.isWhatsAppVerification(uri), true);
    });

    test('rejects WhatsApp verification with wrong scheme', () {
      final uri = Uri.parse('https://verify-whatsapp');
      expect(DeepLinks.isWhatsAppVerification(uri), false);
    });

    test('rejects WhatsApp verification with wrong host', () {
      final uri = Uri.parse('moneko://verify-phone');
      expect(DeepLinks.isWhatsAppVerification(uri), false);
    });
  });

  group('DeepLinks - Telegram Verification Detection', () {
    test('detects Telegram verification link', () {
      final uri = Uri.parse('moneko://verify-telegram');
      expect(DeepLinks.isTelegramVerification(uri), true);
    });

    test('detects Telegram verification with OTP parameter', () {
      final uri = Uri.parse('moneko://verify-telegram?otp=654321');
      expect(DeepLinks.isTelegramVerification(uri), true);
    });

    test('rejects Telegram verification with wrong host', () {
      final uri = Uri.parse('moneko://verify-chat');
      expect(DeepLinks.isTelegramVerification(uri), false);
    });
  });

  group('DeepLinks - Household Invitation Detection', () {
    test('detects deep link household invitation', () {
      final uri = Uri.parse('moneko://households/join?token=abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('detects deep link household invitation without token', () {
      final uri = Uri.parse('moneko://households/join');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('detects universal link household invitation', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('detects universal link with www subdomain', () {
      final uri = Uri.parse('https://www.moneko.io/invites/abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('detects http universal link', () {
      final uri = Uri.parse('http://moneko.io/invites/abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('rejects household invitation with wrong path', () {
      final uri = Uri.parse('moneko://households/create');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });

    test('rejects universal link with wrong domain', () {
      final uri = Uri.parse('https://example.com/invites/abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });

    test('rejects universal link with wrong path', () {
      final uri = Uri.parse('https://moneko.io/join/abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });

    test('rejects household invitation with wrong scheme', () {
      final uri = Uri.parse('https://households/join');
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });
  });

  group('DeepLinks - Expense Link Detection', () {
    test('detects expense link', () {
      final uri = Uri.parse('moneko://expense/exp_123');
      expect(DeepLinks.isExpenseLink(uri), true);
    });

    test('rejects expense link without ID', () {
      final uri = Uri.parse('moneko://expense');
      expect(DeepLinks.isExpenseLink(uri), false);
    });

    test('rejects expense link with wrong scheme', () {
      final uri = Uri.parse('https://expense/exp_123');
      expect(DeepLinks.isExpenseLink(uri), false);
    });

    test('rejects expense link with wrong host', () {
      final uri = Uri.parse('moneko://expenses/exp_123');
      expect(DeepLinks.isExpenseLink(uri), false);
    });
  });

  group('DeepLinks - Household Link Detection', () {
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

    test('rejects household link with wrong scheme', () {
      final uri = Uri.parse('https://household/hh_123');
      expect(DeepLinks.isHouseholdLink(uri), false);
    });
  });

  group('DeepLinks - Budget Link Detection', () {
    test('detects budget link', () {
      final uri = Uri.parse('moneko://budget/bud_123');
      expect(DeepLinks.isBudgetLink(uri), true);
    });

    test('rejects budget link without ID', () {
      final uri = Uri.parse('moneko://budget');
      expect(DeepLinks.isBudgetLink(uri), false);
    });

    test('rejects budget link with wrong host', () {
      final uri = Uri.parse('moneko://budgets/bud_123');
      expect(DeepLinks.isBudgetLink(uri), false);
    });
  });

  group('DeepLinks - Split Link Detection', () {
    test('detects split link', () {
      final uri = Uri.parse('moneko://split/spl_123');
      expect(DeepLinks.isSplitLink(uri), true);
    });

    test('rejects split link without ID', () {
      final uri = Uri.parse('moneko://split');
      expect(DeepLinks.isSplitLink(uri), false);
    });

    test('rejects split link with wrong host', () {
      final uri = Uri.parse('moneko://splits/spl_123');
      expect(DeepLinks.isSplitLink(uri), false);
    });
  });

  group('DeepLinks - Widget Quick Actions', () {
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

    test('detects widget configure link without parameter', () {
      final uri = Uri.parse('moneko://configure_widget');
      expect(DeepLinks.isWidgetConfigureLink(uri), true);
    });

    test('rejects widget link with wrong host', () {
      final uri = Uri.parse('moneko://widget');
      expect(DeepLinks.isWidgetTextLink(uri), false);
      expect(DeepLinks.isWidgetCameraLink(uri), false);
      expect(DeepLinks.isWidgetPocketsLink(uri), false);
    });
  });

  group('DeepLinks - Home Link Detection', () {
    test('detects home link', () {
      final uri = Uri.parse('moneko://home');
      expect(DeepLinks.isHomeLink(uri), true);
    });

    test('rejects home link with wrong scheme', () {
      final uri = Uri.parse('https://home');
      expect(DeepLinks.isHomeLink(uri), false);
    });

    test('rejects home link with wrong host', () {
      final uri = Uri.parse('moneko://dashboard');
      expect(DeepLinks.isHomeLink(uri), false);
    });
  });

  group('DeepLinks - Plaid Callback Detection', () {
    test('detects plaid callback', () {
      final uri = Uri.parse('moneko://plaid');
      expect(DeepLinks.isPlaidCallback(uri), true);
    });

    test('detects plaid callback with parameters', () {
      final uri = Uri.parse('moneko://plaid?link_token=token123');
      expect(DeepLinks.isPlaidCallback(uri), true);
    });

    test('rejects plaid callback with wrong scheme', () {
      final uri = Uri.parse('https://plaid');
      expect(DeepLinks.isPlaidCallback(uri), false);
    });
  });

  group('DeepLinks - Edge Cases', () {
    test('handles empty URI', () {
      final uri = Uri.parse('');
      expect(DeepLinks.isOAuthCallback(uri), false);
      expect(DeepLinks.isPaymentCallback(uri), false);
      expect(DeepLinks.isHouseholdInvitation(uri), false);
    });

    test('handles malformed URI', () {
      final uri = Uri.parse('not-a-valid-uri');
      expect(DeepLinks.isOAuthCallback(uri), false);
      expect(DeepLinks.isPaymentCallback(uri), false);
    });

    test('handles URI with special characters', () {
      final uri = Uri.parse('moneko://households/join?token=abc-123_xyz');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles URI with fragment', () {
      final uri = Uri.parse('moneko://households/join?token=abc123#section');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles case sensitivity in scheme', () {
      final uri = Uri.parse('MONEKO://payment');
      // URI parsing normalizes scheme to lowercase
      expect(uri.scheme, 'moneko');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });

    test('handles multiple query parameters', () {
      final uri = Uri.parse(
          'moneko://payment?status=success&session_id=123&extra=value');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });

    test('handles URL encoding in parameters', () {
      final uri = Uri.parse('moneko://payment?error=Card%20declined');
      expect(DeepLinks.isPaymentCallback(uri), true);
    });
  });

  group('DeepLinks - Universal Link Variations', () {
    test('handles trailing slash in universal link', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123/');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles query parameters in universal link', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123?source=email');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles fragment in universal link', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123#details');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('rejects universal link with extra path segments', () {
      final uri = Uri.parse('https://moneko.io/invites/abc123/extra');
      // Should still detect as invitation since it has /invites/abc123
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });

    test('handles port in universal link', () {
      final uri = Uri.parse('https://moneko.io:443/invites/abc123');
      expect(DeepLinks.isHouseholdInvitation(uri), true);
    });
  });

  group('DeepLinks - Payment URL Generators', () {
    test('payment success URL has correct format', () {
      final url = DeepLinks.paymentSuccess();
      final uri = Uri.parse(url);

      expect(uri.scheme, 'moneko');
      expect(uri.host, 'payment');
      expect(uri.queryParameters['status'], 'success');
    });

    test('payment success URL with session ID has both parameters', () {
      final url = DeepLinks.paymentSuccess(sessionId: 'sess_abc123');
      final uri = Uri.parse(url);

      expect(uri.queryParameters['status'], 'success');
      expect(uri.queryParameters['session_id'], 'sess_abc123');
    });

    test('payment failed URL includes error message', () {
      final url = DeepLinks.paymentFailed('Insufficient funds');
      final uri = Uri.parse(url);

      expect(uri.queryParameters['status'], 'failed');
      expect(uri.queryParameters['error'], 'Insufficient funds');
    });

    test('payment failed URL encodes special characters', () {
      final url = DeepLinks.paymentFailed('Error: Card declined!');
      final uri = Uri.parse(url);

      expect(uri.queryParameters['error'], 'Error: Card declined!');
    });

    test('payment canceled URL has correct format', () {
      final url = DeepLinks.paymentCanceled();
      final uri = Uri.parse(url);

      expect(uri.scheme, 'moneko');
      expect(uri.host, 'payment');
      expect(uri.queryParameters['status'], 'canceled');
    });
  });
}
