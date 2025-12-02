import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/constants/deep_links.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/settings/presentation/widgets/whatsapp_verification_modal.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/household_invitation_sheet.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';

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
        _handleDeepLink(initialLink, ref);
      }
    } catch (e) {
      debugPrint('❌ Error getting initial link: $e');
    }

    // Subscribe to further deep link events
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('🔗 Deep link received: $uri');
        _handleDeepLink(uri, ref);
      },
      onError: (err) {
        debugPrint('❌ Deep link error: $err');
      },
    );
  }

  /// Handle deep link navigation (public for FCM integration)
  void handleDeepLinkUri(Uri uri, WidgetRef ref) {
    _handleDeepLink(uri, ref);
  }

  /// Handle deep link navigation
  void _handleDeepLink(Uri uri, WidgetRef ref) {
    debugPrint('🔗 Handling deep link: ${uri.scheme}://${uri.host}${uri.path}');
    debugPrint('🔗 Query parameters: ${uri.queryParameters}');

    // Handle Supabase OAuth callback: io.supabase.moneko://login-callback
    if (DeepLinks.isOAuthCallback(uri)) {
      debugPrint('🔐 Supabase OAuth callback received');
      debugPrint('🔐 Access token: ${uri.fragment.contains('access_token') ? 'Present' : 'Missing'}');
      
      // Supabase auth tokens are in the URL fragment (#access_token=...)
      // Navigate to auth callback screen which will process the session
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx?.mounted ?? false) {
        // For new users, redirect to avatar customizer
        // For existing users, redirect to dashboard
        // The AuthCallbackScreen will determine this
        navCtx!.go('/auth/callback');
      }
      return;
    }
    
    // Legacy OAuth callback support: moneko://auth/callback (kept for backward compatibility)
    if (DeepLinks.isLegacyOAuthCallback(uri)) {
      debugPrint('🔐 Legacy OAuth callback received');
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx?.mounted ?? false) {
        navCtx!.go('/auth/callback');
      }
      return;
    }

    if (DeepLinks.isPlaidCallback(uri)) {
      final params = uri.queryParameters;
      debugPrint('🏦 Plaid deep link received with params: $params');

      final linkToken = params['link_token'];
      final oauthStateId = params['oauth_state_id'];
      final status = params['status'];
      final errorCode = params['error_code'];
      final errorMessage = params['error_message'];

      debugPrint('🏦 Plaid link_token: $linkToken');
      debugPrint('🏦 Plaid oauth_state_id: $oauthStateId');
      debugPrint('🏦 Plaid status: $status');
      debugPrint('🏦 Plaid error_code: $errorCode');
      debugPrint('🏦 Plaid error_message: $errorMessage');

      return;
    }

    // Widget quick actions: moneko://text and moneko://camera
    if (DeepLinks.isWidgetTextLink(uri)) {
      debugPrint('🧭 Widget deep link: text');
      ref.read(widgetLaunchProvider.notifier).state = WidgetLaunchAction.textInput;
      return;
    }
    if (DeepLinks.isWidgetCameraLink(uri)) {
      debugPrint('🧭 Widget deep link: camera');
      ref.read(widgetLaunchProvider.notifier).state = WidgetLaunchAction.cameraInput;
      return;
    }

    // Handle payment callback: moneko://payment?status=success/failed/canceled
    if (DeepLinks.isPaymentCallback(uri)) {
      final status = uri.queryParameters['status'];
      debugPrint('💳 Payment callback received with status: $status');

      // Refresh subscription status from database
      ref.read(subscriptionNotifierProvider.notifier).refresh();

      // Show appropriate message based on status
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        final ctx = navCtx;
        if (status == 'success') {
          AppToast.success(ctx,ctx.l10n.paymentSuccessfulCheckingSubscription);
          // Navigate to dashboard after a short delay to let subscription load
          Future.delayed(const Duration(seconds: 2), () {
            final delayed = rootNavigatorKey.currentContext;
            if (delayed != null && delayed.mounted) {
              // ignore: use_build_context_synchronously
              delayed.go('/dashboard');
            }
          });
        } else if (status == 'failed') {
          final error = uri.queryParameters['error'] ?? ctx.l10n.paymentFailed;
          AppToast.error(ctx,error);
        } else if (status == 'canceled') {
          AppToast.info(ctx,ctx.l10n.paymentCanceled);
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
          if (retryContext != null && retryContext.mounted) {
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
        if (delayedContext == null || !delayedContext.mounted) {
          debugPrint('⚠️ Context lost after delay');
          return;
        }

        debugPrint('📱 Showing verification modal...');
        _showVerificationModal(delayedContext, otp, ref);
      });
      return;
    }

    // Handle household invitation
    // Supports both formats:
    // - Deep link: moneko://households/join?token=abc123
    // - Universal link: https://moneko.io/invites/abc123
    if (DeepLinks.isHouseholdInvitation(uri)) {
      String? token;

      // Extract token based on URL format
      if (uri.scheme == 'moneko') {
        // Deep link format: moneko://households/join?token=abc123
        token = uri.queryParameters['token'];
      } else if (uri.scheme == 'https' || uri.scheme == 'http') {
        // Universal link format: https://moneko.io/invites/abc123
        // Token is the second path segment after 'invites'
        if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'invites') {
          token = uri.pathSegments[1];
        }
      }

      debugPrint('🏠 Household invitation link received!');
      debugPrint('🏠 URI: $uri');
      debugPrint('🏠 Token: $token');

      if (token == null || token.isEmpty) {
        debugPrint('❌ No invitation token provided');
        return;
      }

      // Capture token in a final variable for the closure
      final inviteToken = token;

      // Wait a bit to ensure app is fully loaded and context is ready
      // NOTE: This uses a fixed delay which is pragmatic but not ideal for all devices.
      // Future improvement: Use a provider/state manager to signal when navigation is ready.
      // This would be more reliable on slower devices or under heavy load.
      Future.delayed(const Duration(milliseconds: 500), () {
        final navigatorContext = rootNavigatorKey.currentContext;
        if (navigatorContext == null) {
          debugPrint('⚠️ Navigator context is null for household invitation');
          return;
        }

        // Show invitation as a bottom sheet (like WhatsApp verification)
        // This allows users to dismiss it and continue using the app
        if (navigatorContext.mounted) {
          debugPrint('🏠 Showing household invitation bottom sheet');
          showHouseholdInvitationSheet(navigatorContext, token: inviteToken);
        }
      });
      return;
    }

    // Handle expense deep link: moneko://expense/{expense_id}
    if (DeepLinks.isExpenseLink(uri)) {
      final expenseId = uri.pathSegments.first;
      debugPrint('💸 Expense deep link received: $expenseId');
      
      _handleExpenseDeepLink(expenseId, ref);
      return;
    }

    // Handle household deep link: moneko://household/{household_id}
    if (DeepLinks.isHouseholdLink(uri)) {
      final householdId = uri.pathSegments.first;
      final subRoute = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      debugPrint('🏠 Household deep link received: $householdId (sub: $subRoute)');
      
      _handleHouseholdDeepLink(householdId, ref, subRoute: subRoute);
      return;
    }

    // Handle budget deep link: moneko://budget/{budget_id}
    if (DeepLinks.isBudgetLink(uri)) {
      final budgetId = uri.pathSegments.first;
      debugPrint('💰 Budget deep link received: $budgetId');
      // TODO: Implement budget navigation when budget detail page is ready
      return;
    }

    // Handle split deep link: moneko://split/{split_id}
    if (DeepLinks.isSplitLink(uri)) {
      final splitId = uri.pathSegments.first;
      debugPrint('🧮 Split deep link received: $splitId');
      // TODO: Implement split navigation when split detail page is ready
      return;
    }

    // Handle home deep link: moneko://home
    if (DeepLinks.isHomeLink(uri)) {
      debugPrint('🏠 Home deep link received');
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx?.mounted ?? false) {
        navCtx!.go('/dashboard');
      }
      return;
    }
  }

  /// Handle expense deep link - show expense detail sheet
  void _handleExpenseDeepLink(String expenseId, WidgetRef ref) async {
    // Wait a bit to ensure app is fully loaded
    await Future.delayed(const Duration(milliseconds: 300));
    
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      debugPrint('⚠️ Navigator context is null for expense deep link');
      return;
    }

    try {
      // Fetch the expense from analytics provider
      final user = ref.read(authProvider);
      await ref.read(analyticsProvider.notifier).loadData(user.uid);
      
      final analytics = ref.read(analyticsProvider);
      final expense = analytics.allExpenses.cast<dynamic>().firstWhere(
        (e) => e.id == expenseId,
        orElse: () => null,
      );
      
      if (expense == null) {
        debugPrint('⚠️ Expense not found: $expenseId');
        if (navigatorContext.mounted) {
          AppToast.info(navigatorContext, navigatorContext.l10n.expenseNotFoundOrDeleted);
        }
        return;
      }
      
      debugPrint('✅ Found expense, showing detail sheet');
      
      // Show expense detail sheet
      if (navigatorContext.mounted) {
        showUnifiedTransactionSheet(
          navigatorContext,
          existingExpense: expense,
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling expense deep link: $e');
    }
  }

  /// Handle household deep link - switch to household mode and select household
  void _handleHouseholdDeepLink(
    String householdId,
    WidgetRef ref,
    {String? subRoute}
  ) async {
    debugPrint('🏠 Switching to household mode for: $householdId');
    
    // Wait a bit to ensure app is fully loaded
    await Future.delayed(const Duration(milliseconds: 300));
    
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      debugPrint('⚠️ Navigator context is null for household deep link');
      return;
    }

    try {
      // Switch to household view mode and set the household ID
      ref.read(viewModeProvider.notifier).setHouseholdMode(householdId);
      
      // Also update the selected household provider (needs user ID)
      final user = ref.read(authProvider);
      await ref.read(selectedHouseholdProvider.notifier).selectHousehold(householdId, user.uid);
      
      // Navigate to dashboard (which will show household content)
      if (navigatorContext.mounted) {
        navigatorContext.go('/dashboard');
      }
      
      debugPrint('✅ Switched to household: $householdId');
      
      // Handle sub-routes if any
      if (subRoute != null) {
        debugPrint('📍 Sub-route requested: $subRoute');
        // TODO: Handle sub-routes like /splits when implemented
      }
    } catch (e) {
      debugPrint('❌ Error handling household deep link: $e');
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
        AppToast.success(context, context.l10n.whatsappVerifiedSuccessfully);
      },
    );
  }

  /// Dispose the subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}
