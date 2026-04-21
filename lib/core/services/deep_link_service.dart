import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/constants/deep_links.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/notifications/notification_dispatcher.dart';
import 'package:moneko/core/notifications/notification_intent_parser.dart';
import 'package:moneko/core/plaid/models/bank_sync_review_session.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_review_page.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/settings/presentation/widgets/whatsapp_verification_modal.dart';
import 'package:moneko/features/settings/presentation/widgets/telegram_verification_modal.dart';
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_sync_result_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

/// Deep link service that handles app links
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  final NotificationIntentParser _intentParser = NotificationIntentParser();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialize the deep link listener
  Future<void> initialize(WidgetRef ref, BuildContext context) async {
    _debugPrint('Initializing deep link service...');

    // Handle the initial link if the app was opened from a deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _debugPrint('🔗 Initial deep link received');
        // ignore: unawaited_futures
        _handleDeepLink(initialLink, ref);
      }
    } catch (e) {
      _debugPrint('❌ Error getting initial link');
    }

    // Subscribe to further deep link events
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _debugPrint('🔗 Deep link received');
        // ignore: unawaited_futures
        _handleDeepLink(uri, ref);
      },
      onError: (err) {
        _debugPrint('❌ Deep link error');
      },
    );
  }

  /// Handle deep link navigation (public for FCM integration)
  void handleDeepLinkUri(Uri uri, WidgetRef ref) {
    // ignore: unawaited_futures
    _handleDeepLink(uri, ref);
  }

  /// Handle deep link navigation
  Future<void> _handleDeepLink(Uri uri, WidgetRef ref) async {
    // Only log deep link type, not sensitive parameters
    _debugPrint('🔗 Handling deep link');
    if (kDebugMode) {
      _debugPrint(
          '🔗 Query parameters present: ${uri.queryParameters.isNotEmpty}');
    }

    // Handle Supabase OAuth callback: io.supabase.moneko://login-callback
    if (DeepLinks.isOAuthCallback(uri)) {
      _debugPrint('🔐 Supabase OAuth callback received');
      // Don't log token presence - could leak info about auth state

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
      _debugPrint('🔐 Legacy OAuth callback received');
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx?.mounted ?? false) {
        navCtx!.go('/auth/callback');
      }
      return;
    }

    if (DeepLinks.isPlaidCallback(uri)) {
      _debugPrint('🏦 Plaid deep link received');

      final params = uri.queryParameters;
      final errorCode = params['error_code'];
      final errorMessage = params['error_message'];

      // Only log non-sensitive status info
      _debugPrint('🏦 Plaid callback status received');
      if (errorCode != null) {
        _debugPrint('🏦 Plaid callback contains error details');
      }

      ref.invalidate(bankConnectionsProvider);

      final navCtx = rootNavigatorKey.currentContext;
      if ((navCtx?.mounted ?? false) && errorCode != null) {
        AppToast.error(
          navCtx!,
          errorMessage?.isNotEmpty == true
              ? errorMessage!
              : 'Bank reconnect was not completed. Please try again.',
        );
      }

      return;
    }

    // Tink callback: moneko://tink?credentialsId=xxx&credentials_id=yyy&state=zzz
    // Note: Tink Link returns credentialsId (not code) after successful connection
    if (DeepLinks.isTinkCallback(uri)) {
      _debugPrint('🏦 Tink deep link received');

      final params = uri.queryParameters;
      // Tink returns both 'credentialsId' (camelCase) and 'credentials_id' (snake_case)
      final credentialsId = params['credentialsId'] ?? params['credentials_id'];
      final state = params['state'];
      final error = params['error'];

      if (error != null && error.isNotEmpty) {
        _debugPrint('❌ Tink callback error');
        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx?.mounted ?? false) {
          AppToast.error(navCtx!, 'Bank connection failed: $error');
        }
        return;
      }

      if (credentialsId == null || credentialsId.isEmpty) {
        _debugPrint('❌ Tink callback missing credentials identifier');
        return;
      }

      if (state == null || state.isEmpty) {
        _debugPrint('❌ Tink callback missing security state');
        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx?.mounted ?? false) {
          AppToast.error(
              navCtx!, 'Bank connection failed: missing security state');
        }
        return;
      }

      // Don't log sensitive credentials - only log that we received them
      _debugPrint('🏦 Tink credentials and state received');

      // Handle the Tink callback - sync transactions using credentialsId
      _handleTinkCallback(credentialsId, state, ref);
      return;
    }

    // Widget quick actions: moneko://text, moneko://camera, moneko://pockets
    if (DeepLinks.isWidgetTextLink(uri)) {
      _debugPrint('🧭 Widget deep link: text');
      ref.read(widgetLaunchProvider.notifier).state =
          const WidgetLaunchEvent(type: WidgetLaunchActionType.textInput);
      return;
    }
    if (DeepLinks.isWidgetCameraLink(uri)) {
      _debugPrint('🧭 Widget deep link: camera');
      ref.read(widgetLaunchProvider.notifier).state =
          const WidgetLaunchEvent(type: WidgetLaunchActionType.cameraInput);
      return;
    }
    if (DeepLinks.isWidgetPocketsLink(uri)) {
      _debugPrint('🧭 Widget deep link: pockets');
      ref.read(widgetLaunchProvider.notifier).state =
          const WidgetLaunchEvent(type: WidgetLaunchActionType.openPockets);
      return;
    }
    if (DeepLinks.isWidgetConfigureLink(uri)) {
      _debugPrint('🧭 Widget deep link: configure');
      final widgetId = uri.queryParameters['widgetId'];
      if (widgetId != null) {
        ref.read(widgetLaunchProvider.notifier).state = WidgetLaunchEvent(
          type: WidgetLaunchActionType.configure,
          params: {'widgetId': widgetId},
        );
      }
      return;
    }

    final intent = _intentParser.fromUri(uri);
    if (intent != null) {
      await ref
          .read(notificationDispatcherProvider)
          .enqueueIntent(intent, source: 'deep_link');
      return;
    }

    // Handle payment callback: moneko://payment?status=success/failed/canceled
    if (DeepLinks.isPaymentCallback(uri)) {
      final status = uri.queryParameters['status'];
      _debugPrint('💳 Payment callback received');

      final sessionId = uri.queryParameters['session_id'];

      // Show appropriate message based on status
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        final ctx = navCtx;

        if (status == 'success') {
          AppToast.success(ctx, ctx.l10n.paymentSuccessfulCheckingSubscription);

          // Ensure DB is updated before we rely on subscription table.
          // (Best-effort; web also verifies via verify-payment route.)
          final verificationNonce = uri.queryParameters['v'];
          if (sessionId != null && sessionId.isNotEmpty) {
            try {
              await supabase.functions.invoke(
                'verify-payment',
                body: {
                  'sessionId': sessionId,
                  if (verificationNonce != null && verificationNonce.isNotEmpty)
                    'v': verificationNonce,
                },
              );
            } catch (e) {
              _debugPrint('⚠️ verify-payment failed (best-effort)');
            }
          }

          // Poll because webhook + DB write can lag behind the redirect.
          // Use a short backoff to handle slow webhook delivery.
          for (var attempt = 0; attempt < 12; attempt++) {
            await ref.read(subscriptionNotifierProvider.notifier).refresh();

            final hasSubscription = ref.read(hasActiveSubscriptionProvider);
            if (hasSubscription) {
              if (rootNavigatorKey.currentContext?.mounted ?? false) {
                // ignore: use_build_context_synchronously
                rootNavigatorKey.currentContext!.go('/dashboard');
              }
              return;
            }

            final delaySeconds = attempt < 3
                ? 1
                : attempt < 7
                    ? 2
                    : 3;
            await Future.delayed(Duration(seconds: delaySeconds));
          }

          // If still not active, keep user on paywall.
          // Router will enforce this anyway for non-subscribed users.
        } else if (status == 'failed') {
          final error = uri.queryParameters['error'] ?? ctx.l10n.paymentFailed;
          AppToast.error(ctx, error);
        } else if (status == 'canceled') {
          AppToast.info(ctx, ctx.l10n.paymentCanceled);
        }
      }
      return;
    }

    // Handle WhatsApp verification: moneko://verify-whatsapp?otp=123456
    if (DeepLinks.isWhatsAppVerification(uri)) {
      final otp = uri.queryParameters['otp'];
      // Don't log OTP - it's a secret
      _debugPrint('📱 WhatsApp verification callback received');

      // Use global navigator key to get a valid context
      // This ensures the modal can be shown even when app comes from background
      final navigatorContext = rootNavigatorKey.currentContext;

      if (navigatorContext == null) {
        _debugPrint('⚠️ Navigator context is null, waiting...');
        // Wait a bit longer and try again
        Future.delayed(const Duration(milliseconds: 1000), () {
          final retryContext = rootNavigatorKey.currentContext;
          if (retryContext != null && retryContext.mounted) {
            _debugPrint('📱 Got context on retry, showing modal...');
            _showVerificationModal(retryContext, otp, ref);
          } else {
            _debugPrint('❌ Still no context after retry');
          }
        });
        return;
      }

      // Add small delay to ensure app UI is ready when coming from background
      Future.delayed(const Duration(milliseconds: 500), () {
        final delayedContext = rootNavigatorKey.currentContext;
        if (delayedContext == null || !delayedContext.mounted) {
          _debugPrint('⚠️ Context lost after delay');
          return;
        }

        _debugPrint('📱 Showing verification modal...');
        _showVerificationModal(delayedContext, otp, ref);
      });
      return;
    }

    // Handle Telegram verification: moneko://verify-telegram?otp=123456
    if (DeepLinks.isTelegramVerification(uri)) {
      final otp = uri.queryParameters['otp'];
      debugPrint('📱 Telegram verification callback received');

      final navigatorContext = rootNavigatorKey.currentContext;

      if (navigatorContext == null) {
        debugPrint('⚠️ Navigator context is null, waiting...');
        Future.delayed(const Duration(milliseconds: 1000), () {
          final retryContext = rootNavigatorKey.currentContext;
          if (retryContext != null && retryContext.mounted) {
            debugPrint('📱 Got context on retry, showing Telegram modal...');
            _showTelegramVerificationModal(retryContext, otp, ref);
          } else {
            debugPrint('❌ Still no context after retry');
          }
        });
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        final delayedContext = rootNavigatorKey.currentContext;
        if (delayedContext == null || !delayedContext.mounted) {
          debugPrint('⚠️ Context lost after delay');
          return;
        }

        debugPrint('📱 Showing Telegram verification modal...');
        _showTelegramVerificationModal(delayedContext, otp, ref);
      });
      return;
    }
  }

  /// Handle Tink callback - sync transactions using credentialsId
  Future<void> _handleTinkCallback(
      String credentialsId, String state, WidgetRef ref) async {
    _debugPrint('🏦 Handling Tink callback...');

    // Wait a bit to ensure app is fully loaded
    await Future.delayed(const Duration(milliseconds: 300));

    var dialogShown = false;

    try {
      final user = ref.read(authProvider);
      if (user.uid.isEmpty) {
        _debugPrint('❌ User not authenticated for Tink callback');
        return;
      }

      final pendingState = ref.read(pendingBankLinkStateProvider);

      final loadingContext = rootNavigatorKey.currentContext;
      if (loadingContext != null && loadingContext.mounted) {
        showBlockingProcessingDialog(
          context: loadingContext,
          message: 'Syncing your bank data...',
        );
        dialogShown = true;
      }

      final prepareResponse = await supabase.functions.invoke(
        'tink-sync-transactions',
        body: {
          'credentialsId': credentialsId,
          'state': state,
          'prepareOnly': true,
          if (pendingState?.targetHouseholdId != null)
            'targetHouseholdId': pendingState!.targetHouseholdId,
        },
      );

      if (prepareResponse.status >= 400) {
        throw Exception('Failed to prepare Tink bank connection');
      }

      final data = prepareResponse.data as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Missing Tink connection payload');
      }

      final session = BankSyncReviewSession.fromResponse(
        data: data,
        provider: 'tink',
        targetHouseholdId: pendingState?.targetHouseholdId,
      );
      if (!session.hasAccounts) {
        throw Exception('No supported bank accounts were returned');
      }

      ref.read(pendingBankLinkStateProvider.notifier).state = null;

      final currentContext = rootNavigatorKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        final navigator =
            Navigator.maybeOf(currentContext, rootNavigator: true);
        if (dialogShown && (navigator?.canPop() ?? false)) {
          navigator!.pop();
          dialogShown = false;
        }

        await Navigator.of(currentContext, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaidSyncReviewPage(session: session),
          ),
        );
      }
    } catch (e) {
      _debugPrint('❌ Error handling Tink callback');
      final errorContext = rootNavigatorKey.currentContext;
      if (errorContext != null && errorContext.mounted) {
        AppToast.error(errorContext, 'Failed to connect bank: ${e.toString()}');
      }
    } finally {
      ref.read(pendingBankLinkStateProvider.notifier).state = null;
      if (dialogShown) {
        final navigator = rootNavigatorKey.currentState;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
        }
      }
    }
  }

  /// Show WhatsApp verification modal
  void _showVerificationModal(
      BuildContext context, String? otp, WidgetRef ref) {
    showWhatsAppVerificationModal(
      context,
      otpFromUrl: otp,
      onVerificationSuccess: () {
        _debugPrint('✅ Verification success callback triggered');

        // Update WhatsApp binding status immediately without fetching from DB
        ref.read(whatsAppBindingProvider.notifier).setVerified();

        // Show success message
        AppToast.success(context, context.l10n.whatsappVerifiedSuccessfully);
      },
    );
  }

  void _showTelegramVerificationModal(
      BuildContext context, String? otp, WidgetRef ref) {
    showTelegramVerificationModal(
      context,
      otpFromUrl: otp,
      onVerificationSuccess: () {
        debugPrint('✅ Telegram verification success callback triggered');
        ref.read(telegramBindingProvider.notifier).setVerified();
        AppToast.success(context, context.l10n.telegramVerifiedSuccessfully);
      },
    );
  }

  /// Dispose the subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}
