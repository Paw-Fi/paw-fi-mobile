import 'dart:async';

import 'package:app_links/app_links.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/constants/deep_links.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/notifications/notification_dispatcher.dart';
import 'package:moneko/core/notifications/notification_intent_parser.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/settings/presentation/widgets/whatsapp_verification_modal.dart';
import 'package:moneko/features/settings/presentation/widgets/telegram_verification_modal.dart';
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/profile/domain/email_import_settings.dart';
import 'package:moneko/features/profile/presentation/providers/email_import_settings_provider.dart';

/// Deep link service that handles app links
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  final NotificationIntentParser _intentParser = NotificationIntentParser();
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _pendingImportReview;
  bool _isImportReviewConsumptionScheduled = false;
  bool _isDisposed = false;
  final Set<String> _pendingSenderTokens = {};
  String? _activeSenderToken;
  bool _isSenderVerificationRunning = false;
  String? _pendingSenderEmail;
  bool _isSenderAddScheduled = false;
  GoRouter? _senderAddRouter;
  VoidCallback? _senderAddRouteListener;
  final List<ProviderSubscription<dynamic>> _senderAddSubscriptions = [];

  /// Initialize the deep link listener
  Future<void> initialize(WidgetRef ref, BuildContext context) async {
    // Handle the initial link if the app was opened from a deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        // ignore: unawaited_futures
        _handleDeepLink(initialLink, ref);
      }
    } catch (e) {}

    // Subscribe to further deep link events
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        // ignore: unawaited_futures
        _handleDeepLink(uri, ref);
      },
      onError: (err) {},
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

    final senderEmail = DeepLinks.emailSenderToAdd(uri);
    if (senderEmail != null && !_isDisposed) {
      _pendingSenderEmail = senderEmail;
      if (_senderAddRouter == null) {
        _senderAddRouter = ref.read(routerProvider);
        _senderAddRouteListener = () => _scheduleSenderAdd(ref);
        _senderAddRouter!.routeInformationProvider
            .addListener(_senderAddRouteListener!);
        _senderAddSubscriptions.add(
            ref.listenManual(authProvider, (_, __) => _scheduleSenderAdd(ref)));
        _senderAddSubscriptions.add(ref.listenManual(
            appLockControllerProvider, (_, __) => _scheduleSenderAdd(ref)));
      }
      _scheduleSenderAdd(ref);
      return;
    }
    final senderToken = DeepLinks.emailSenderVerificationToken(uri);
    if (senderToken != null) {
      if (senderToken != _activeSenderToken) {
        _pendingSenderTokens.add(senderToken);
      }
      _consumeSenderVerification(ref);
      return;
    }

    // Handle Supabase OAuth callback: io.supabase.moneko://login-callback
    if (DeepLinks.isOAuthCallback(uri)) {
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
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx?.mounted ?? false) {
        navCtx!.go('/auth/callback');
      }
      return;
    }

    if (DeepLinks.isImportReview(uri)) {
      _queueImportReview(uri);
      return;
    }

    if (DeepLinks.isPlaidCallback(uri)) {
      final params = uri.queryParameters;
      final errorCode = params['error_code'];
      final errorMessage = params['error_message'];

      // Only log non-sensitive status info

      ref.invalidate(bankConnectionsProvider);

      final navCtx = rootNavigatorKey.currentContext;
      if ((navCtx?.mounted ?? false) && errorCode != null) {
        AppToast.error(
          navCtx!,
          errorMessage?.isNotEmpty == true
              ? errorMessage!
              : navCtx.l10n.bankReconnectNotCompletedTryAgain,
        );
      }

      return;
    }

    // Widget quick actions: moneko://text, moneko://camera, moneko://pockets
    if (DeepLinks.isWidgetTextLink(uri)) {
      ref.read(widgetLaunchProvider.notifier).state =
          const WidgetLaunchEvent(type: WidgetLaunchActionType.textInput);
      return;
    }
    if (DeepLinks.isWidgetCameraLink(uri)) {
      ref.read(widgetLaunchProvider.notifier).state =
          const WidgetLaunchEvent(type: WidgetLaunchActionType.cameraInput);
      return;
    }
    if (DeepLinks.isWidgetPocketsLink(uri)) {
      ref.read(widgetLaunchProvider.notifier).state =
          const WidgetLaunchEvent(type: WidgetLaunchActionType.openPockets);
      return;
    }
    if (DeepLinks.isWidgetConfigureLink(uri)) {
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
            } catch (e) {}
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

      // Use global navigator key to get a valid context
      // This ensures the modal can be shown even when app comes from background
      final navigatorContext = rootNavigatorKey.currentContext;

      if (navigatorContext == null) {
        // Wait a bit longer and try again
        Future.delayed(const Duration(milliseconds: 1000), () {
          final retryContext = rootNavigatorKey.currentContext;
          if (retryContext != null && retryContext.mounted) {
            _showVerificationModal(retryContext, otp, ref);
          }
        });
        return;
      }

      // Add small delay to ensure app UI is ready when coming from background
      Future.delayed(const Duration(milliseconds: 500), () {
        final delayedContext = rootNavigatorKey.currentContext;
        if (delayedContext == null || !delayedContext.mounted) {
          return;
        }

        _showVerificationModal(delayedContext, otp, ref);
      });
      return;
    }

    // Handle Telegram verification: moneko://verify-telegram?otp=123456
    if (DeepLinks.isTelegramVerification(uri)) {
      final otp = uri.queryParameters['otp'];

      final navigatorContext = rootNavigatorKey.currentContext;

      if (navigatorContext == null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          final retryContext = rootNavigatorKey.currentContext;
          if (retryContext != null && retryContext.mounted) {
            _showTelegramVerificationModal(retryContext, otp, ref);
          }
        });
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        final delayedContext = rootNavigatorKey.currentContext;
        if (delayedContext == null || !delayedContext.mounted) {
          return;
        }

        _showTelegramVerificationModal(delayedContext, otp, ref);
      });
      return;
    }
  }

  void _scheduleSenderAdd(WidgetRef ref) {
    if (_isDisposed || _pendingSenderEmail == null || _isSenderAddScheduled) {
      return;
    }
    _isSenderAddScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isSenderAddScheduled = false;
      if (_isDisposed || _pendingSenderEmail == null) return;
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) {
        _scheduleSenderAdd(ref);
        return;
      }
      final router = _senderAddRouter!;
      final path = router.routeInformationProvider.value.uri.path;
      if (ref.read(authProvider).isEmpty) {
        if (path != '/login' &&
            path != '/register' &&
            !path.startsWith('/auth/')) {
          router.go('/login');
        }
        return;
      }
      if (ref.read(appLockControllerProvider).shouldBlockApp ||
          path == '/splash' ||
          path == '/error' ||
          path == '/onboarding' ||
          path == '/avatar' ||
          path == '/login' ||
          path == '/register' ||
          path.startsWith('/auth/') ||
          path == '/app-lock') {
        return;
      }
      final location = Uri(path: '/email-import-settings', queryParameters: {
        'email': _pendingSenderEmail!,
      }).toString();
      _pendingSenderEmail = null;
      router.push(location);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _consumeSenderVerification(WidgetRef ref) async {
    if (_isDisposed ||
        _isSenderVerificationRunning ||
        _pendingSenderTokens.isEmpty) {
      return;
    }
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _consumeSenderVerification(ref));
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    final token = _pendingSenderTokens.first;
    _pendingSenderTokens.remove(token);
    _activeSenderToken = token;
    _isSenderVerificationRunning = true;
    try {
      final result = await ref
          .read(emailImportSettingsServiceProvider)
          .verifySender(token);
      if (_isDisposed) return;
      final userId = result['userId'];
      final sender = result['sender'];
      if (userId is! String ||
          sender is! Map<String, dynamic> ||
          sender['verified'] != true) {
        throw const FormatException('Invalid sender verification response');
      }
      final currentContext = rootNavigatorKey.currentContext;
      if (currentContext == null || !currentContext.mounted) return;
      if (ref.read(authProvider).uid == userId) {
        ref
            .read(emailImportSettingsProvider(userId).notifier)
            .acceptVerifiedSender(
              EmailImportWhitelistEntry.fromJson(sender),
            );
        if (GoRouter.of(currentContext)
                .routeInformationProvider
                .value
                .uri
                .path !=
            '/email-import-settings') {
          currentContext.push('/email-import-settings');
        }
        AppToast.success(currentContext,
            currentContext.l10n.emailSenderVerificationComplete);
      } else {
        AppToast.info(currentContext,
            currentContext.l10n.emailSenderVerifiedOtherAccount);
      }
    } catch (error) {
      final currentContext = rootNavigatorKey.currentContext;
      if (!_isDisposed && currentContext != null && currentContext.mounted) {
        AppToast.error(
            currentContext,
            ErrorHandler.getUserFriendlyMessage(error,
                context: BackendErrorContext.emailImportSettings));
      }
    } finally {
      _isSenderVerificationRunning = false;
      _activeSenderToken = null;
      if (!_isDisposed && _pendingSenderTokens.isNotEmpty) {
        _consumeSenderVerification(ref);
      }
    }
  }

  void _queueImportReview(Uri uri) {
    final reviewId = DeepLinks.importReviewId(uri);
    final secret = DeepLinks.importReviewSecret(uri);
    if (reviewId == null || secret == null) return;
    _pendingImportReview = uri;
    _scheduleImportReviewConsumption();
  }

  void _scheduleImportReviewConsumption() {
    if (_isDisposed ||
        _pendingImportReview == null ||
        _isImportReviewConsumptionScheduled) {
      return;
    }
    _isImportReviewConsumptionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isImportReviewConsumptionScheduled = false;
      if (!_consumeImportReview()) _scheduleImportReviewConsumption();
    });
  }

  bool _consumeImportReview() {
    final pending = _pendingImportReview;
    if (pending == null) return true;
    final reviewId = DeepLinks.importReviewId(pending);
    final secret = DeepLinks.importReviewSecret(pending);
    final context = rootNavigatorKey.currentContext;
    if (reviewId == null ||
        secret == null ||
        context == null ||
        !context.mounted) {
      return false;
    }
    _pendingImportReview = null;

    context.push('/import-review/$reviewId', extra: secret);
    return true;
  }

  /// Show WhatsApp verification modal
  void _showVerificationModal(
      BuildContext context, String? otp, WidgetRef ref) {
    showWhatsAppVerificationModal(
      context,
      otpFromUrl: otp,
      onVerificationSuccess: () {
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
        ref.read(telegramBindingProvider.notifier).setVerified();
        AppToast.success(context, context.l10n.telegramVerifiedSuccessfully);
      },
    );
  }

  /// Dispose the subscription
  void dispose() {
    _isDisposed = true;
    _pendingImportReview = null;
    _pendingSenderTokens.clear();
    _pendingSenderEmail = null;
    if (_senderAddRouteListener != null) {
      _senderAddRouter?.routeInformationProvider
          .removeListener(_senderAddRouteListener!);
    }
    for (final subscription in _senderAddSubscriptions) {
      subscription.close();
    }
    _senderAddSubscriptions.clear();
    _linkSubscription?.cancel();
  }
}
