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

  // ==================== Household Invitation Deep Links ====================

  /// Household invitation callback URL
  /// Format: moneko://households/join?token=abc123
  ///
  /// Users receive this link via web after accepting an invitation.
  /// The token parameter is used to complete the invitation process.
  static const String householdInvitation = '$appScheme://households/join';

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

  /// Check if a URI is a household invitation callback
  /// Handles both:
  /// - Deep link: moneko://households/join?token=abc123
  /// - Universal link: https://moneko.io/invites/abc123
  static bool isHouseholdInvitation(Uri uri) {
    // Deep link format: moneko://households/join?token=abc123
    if (uri.scheme == appScheme &&
        uri.host == 'households' &&
        uri.path == '/join') {
      return true;
    }

    // Universal link format: https://moneko.io/invites/{token}
    // Also handles: https://www.moneko.io/invites/{token}
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.host == 'moneko.io' || uri.host == 'www.moneko.io') &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == 'invites') {
      return true;
    }

    return false;
  }

  /// Check if a URI is an expense deep link
  /// Format: moneko://expense/{expense_id}
  static bool isExpenseLink(Uri uri) {
    return uri.scheme == appScheme &&
           uri.host == 'expense' &&
           uri.pathSegments.isNotEmpty;
  }

  /// Check if a URI is a household deep link
  /// Format: moneko://household/{household_id}
  static bool isHouseholdLink(Uri uri) {
    return uri.scheme == appScheme &&
           uri.host == 'household' &&
           uri.pathSegments.isNotEmpty;
  }

  /// Check if a URI is a budget deep link
  /// Format: moneko://budget/{budget_id}
  static bool isBudgetLink(Uri uri) {
    return uri.scheme == appScheme &&
           uri.host == 'budget' &&
           uri.pathSegments.isNotEmpty;
  }

  /// Check if a URI is a split deep link
  /// Format: moneko://split/{split_id}
  static bool isSplitLink(Uri uri) {
    return uri.scheme == appScheme &&
           uri.host == 'split' &&
           uri.pathSegments.isNotEmpty;
  }

  /// Check if a URI is a home deep link
  /// Format: moneko://home
  static bool isHomeLink(Uri uri) {
    return uri.scheme == appScheme && uri.host == 'home';
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
