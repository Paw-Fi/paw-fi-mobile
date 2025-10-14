import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
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

    // Handle payment callback: moneko://payment?status=success/failed/canceled
    if (uri.host == 'payment') {
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
    }
  }

  /// Dispose the subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}
