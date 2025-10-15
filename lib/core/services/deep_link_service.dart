import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/constants/deep_links.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/settings/presentation/widgets/whatsapp_verification_modal.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:go_router/go_router.dart';

/// Deep link service that handles app links
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialize the deep link listener
  Future<void> initialize(WidgetRef ref, BuildContext context) async {
    debugPrint('🔗 Initializing deep link service...');

    // Handle the initial link if the app was opened from a deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        debugPrint('🔗 Initial deep link received: $initialLink');
        _handleDeepLink(initialLink, ref, context);
      }
    } catch (e) {
      debugPrint('❌ Error getting initial link: $e');
    }

    // Subscribe to further deep link events
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('🔗 Deep link received: $uri');
        _handleDeepLink(uri, ref, context);
      },
      onError: (err) {
        debugPrint('❌ Deep link error: $err');
      },
    );
  }

  /// Handle deep link navigation
  void _handleDeepLink(Uri uri, WidgetRef ref, BuildContext context) {
    debugPrint('🔗 Handling deep link: ${uri.scheme}://${uri.host}${uri.path}');
    debugPrint('🔗 Query parameters: ${uri.queryParameters}');

    // Handle Supabase OAuth callback: io.supabase.moneko://login-callback
    if (DeepLinks.isOAuthCallback(uri)) {
      debugPrint('🔐 Supabase OAuth callback received');
      debugPrint('🔐 Access token: ${uri.fragment.contains('access_token') ? 'Present' : 'Missing'}');
      
      // Supabase auth tokens are in the URL fragment (#access_token=...)
      // Navigate to auth callback screen which will process the session
      if (context.mounted) {
        // For new users, redirect to avatar customizer
        // For existing users, redirect to dashboard
        // The AuthCallbackScreen will determine this
        context.go('/auth/callback');
      }
      return;
    }
    
    // Legacy OAuth callback support: moneko://auth/callback (kept for backward compatibility)
    if (DeepLinks.isLegacyOAuthCallback(uri)) {
      debugPrint('🔐 Legacy OAuth callback received');
      if (context.mounted) {
        context.go('/auth/callback');
      }
      return;
    }

    // Handle payment callback: moneko://payment?status=success/failed/canceled
    if (DeepLinks.isPaymentCallback(uri)) {
      final status = uri.queryParameters['status'];
      debugPrint('💳 Payment callback received with status: $status');

      // Refresh subscription status from database
      ref.read(subscriptionNotifierProvider.notifier).refresh();

      // Show appropriate message based on status
      if (context.mounted) {
        if (status == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment successful! Checking subscription...'),
              duration: Duration(seconds: 3),
            ),
          );
          // Navigate to dashboard after a short delay to let subscription load
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              context.go('/dashboard');
            }
          });
        } else if (status == 'failed') {
          final error = uri.queryParameters['error'] ?? 'Payment failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $error'),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red,
            ),
          );
        } else if (status == 'canceled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ Payment canceled'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      return;
    }

    // Handle WhatsApp verification: moneko://verify-whatsapp?otp=123456
    if (DeepLinks.isWhatsAppVerification(uri)) {
      final otp = uri.queryParameters['otp'];
      debugPrint('📱 WhatsApp verification callback received!');
      debugPrint('📱 OTP: $otp');

      // Use global navigator key to get a valid context
      // This ensures the modal can be shown even when app comes from background
      final navigatorContext = rootNavigatorKey.currentContext;
      
      if (navigatorContext == null) {
        debugPrint('⚠️ Navigator context is null, waiting...');
        // Wait a bit longer and try again
        Future.delayed(const Duration(milliseconds: 1000), () {
          final retryContext = rootNavigatorKey.currentContext;
          if (retryContext != null) {
            debugPrint('📱 Got context on retry, showing modal...');
            _showVerificationModal(retryContext, otp, ref);
          } else {
            debugPrint('❌ Still no context after retry');
          }
        });
        return;
      }

      // Add small delay to ensure app UI is ready when coming from background
      Future.delayed(const Duration(milliseconds: 500), () {
        final delayedContext = rootNavigatorKey.currentContext;
        if (delayedContext == null) {
          debugPrint('⚠️ Context lost after delay');
          return;
        }

        debugPrint('📱 Showing verification modal...');
        _showVerificationModal(delayedContext, otp, ref);
      });
      return;
    }
  }

  /// Show WhatsApp verification modal
  void _showVerificationModal(BuildContext context, String? otp, WidgetRef ref) {
    showWhatsAppVerificationModal(
      context,
      otpFromUrl: otp,
      onVerificationSuccess: () {
        debugPrint('✅ Verification success callback triggered');
        
        // Update WhatsApp binding status immediately without fetching from DB
        ref.read(whatsAppBindingProvider.notifier).setVerified();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ WhatsApp verified successfully!'),
            duration: Duration(seconds: 3),
          ),
        );
      },
    );
  }

  /// Dispose the subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}
