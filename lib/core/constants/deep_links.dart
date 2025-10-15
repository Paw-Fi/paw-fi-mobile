/// Deep link URL constants for the Moneko app
/// 
/// These URLs are used for:
/// - OAuth authentication callbacks (Google Sign-In)
/// - Payment redirects (Stripe checkout)
/// - Other deep linking scenarios
class DeepLinks {
  DeepLinks._();

  /// Base app scheme for custom deep links
  static const String appScheme = 'moneko';

  /// Supabase OAuth scheme (following Supabase's recommended pattern)
  static const String supabaseScheme = 'io.supabase.moneko';

  // ==================== OAuth Deep Links ====================

  /// OAuth callback URL for Google Sign-In
  /// Format: io.supabase.moneko://login-callback
  /// 
  /// This follows Supabase's recommended pattern for mobile OAuth.
  /// Must be whitelisted in Supabase Dashboard → Authentication → URL Configuration
  static const String oauthCallback = '$supabaseScheme://login-callback';

  // ==================== Payment Deep Links ====================

  /// Payment callback base URL
  /// Format: moneko://payment
  /// 
  /// The checkout page will append status query parameters:
  /// - moneko://payment?status=success
  /// - moneko://payment?status=failed&error=...
  /// - moneko://payment?status=canceled
  static const String paymentCallback = '$appScheme://payment';

  // ==================== WhatsApp Verification Deep Links ====================

  /// WhatsApp verification callback URL
  /// Format: moneko://verify-whatsapp?otp=123456
  /// 
  /// Users receive this link via WhatsApp when they start verification.
  /// The OTP parameter contains the 6-digit verification code.
  static const String whatsappVerification = '$appScheme://verify-whatsapp';

  /// Payment success callback with status parameter
  static String paymentSuccess({String? sessionId}) {
    final params = <String, String>{'status': 'success'};
    if (sessionId != null) params['session_id'] = sessionId;
    return Uri.parse(paymentCallback).replace(queryParameters: params).toString();
  }

  /// Payment failed callback with status and error parameters
  static String paymentFailed(String error) {
    return Uri.parse(paymentCallback)
        .replace(queryParameters: {'status': 'failed', 'error': error})
        .toString();
  }

  /// Payment canceled callback with status parameter
  static String paymentCanceled() {
    return Uri.parse(paymentCallback)
        .replace(queryParameters: {'status': 'canceled'})
        .toString();
  }

  // ==================== Helper Methods ====================

  /// Check if a URI is an OAuth callback
  static bool isOAuthCallback(Uri uri) {
    return uri.scheme == supabaseScheme && uri.host == 'login-callback';
  }

  /// Check if a URI is a payment callback
  static bool isPaymentCallback(Uri uri) {
    return uri.scheme == appScheme && uri.host == 'payment';
  }

  /// Check if a URI is a WhatsApp verification callback
  static bool isWhatsAppVerification(Uri uri) {
    return uri.scheme == appScheme && uri.host == 'verify-whatsapp';
  }

  /// Legacy OAuth callback (kept for backward compatibility)
  /// Format: moneko://auth/callback
  @Deprecated('Use oauthCallback instead. This is kept for backward compatibility.')
  static const String legacyOAuthCallback = '$appScheme://auth/callback';

  /// Check if a URI is a legacy OAuth callback
  static bool isLegacyOAuthCallback(Uri uri) {
    return uri.scheme == appScheme && uri.host == 'auth' && uri.path == '/callback';
  }
}
