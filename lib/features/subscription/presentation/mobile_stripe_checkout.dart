import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentCanceledException implements Exception {
  const PaymentCanceledException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A checkout sheet cannot be presented until the server has returned its
/// Stripe Checkout URL. Keep this bounded: a stalled Edge Function request
/// must not leave the plan action permanently processing.
const mobileStripeCheckoutSessionRequestTimeout = Duration(seconds: 30);

Future<T> awaitMobileStripeCheckoutSession<T>(
  Future<T> request, {
  Duration timeout = mobileStripeCheckoutSessionRequestTimeout,
}) {
  return request.timeout(timeout);
}

Future<MobileStripeCheckoutResult> startMobileStripeCheckout({
  required BuildContext context,
  required SupabaseClient supabaseClient,
  required String plan,
  required String noSessionError,
  required String startCheckoutError,
  required String noCheckoutUrlError,
  String? billingInterval,
  String? countryCode,
  String? currencyCode,
}) async {
  final session = supabaseClient.auth.currentSession;
  if (session == null) {
    throw Exception(noSessionError);
  }

  final successBase = Uri.https(Constants.checkoutBaseUrl, '/checkout', {
    'status': 'success',
    'source': 'mobile',
    'redirectUrl': DeepLinks.paymentCallback,
    'plan': plan,
    if (billingInterval != null) 'billing': billingInterval,
  }).toString();

  final cancelBase = Uri.https(Constants.checkoutBaseUrl, '/checkout', {
    'status': 'canceled',
    'source': 'mobile',
    'redirectUrl': DeepLinks.paymentCallback,
    'plan': plan,
    if (billingInterval != null) 'billing': billingInterval,
  }).toString();

  late final FunctionResponse response;
  try {
    response = await awaitMobileStripeCheckoutSession(
      supabaseClient.functions.invoke(
        'create-checkout-session',
        body: {
          'plan': plan,
          if (plan != 'lifetime') 'billingInterval': billingInterval,
          if (countryCode != null) 'country': countryCode,
          if (currencyCode != null) 'currency': currencyCode,
          'successUrl': '$successBase&session_id={CHECKOUT_SESSION_ID}',
          'cancelUrl': '$cancelBase&session_id={CHECKOUT_SESSION_ID}',
        },
      ),
    );
  } on TimeoutException {
    throw Exception(startCheckoutError);
  }

  if (response.status >= 400) {
    final data = response.data;
    final code = data is Map ? data['code'] : null;
    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : startCheckoutError;
    throw Exception(
      code is String && code.isNotEmpty ? '$code: $message' : message,
    );
  }

  final data = response.data;
  if (data == null || data['checkoutUrl'] == null) {
    throw Exception(noCheckoutUrlError);
  }

  if (!context.mounted) {
    throw Exception(startCheckoutError);
  }

  return showMobileStripeCheckoutSheet(
    context: context,
    checkoutUrl: data['checkoutUrl'] as String,
  );
}

Future<MobileStripeCheckoutResult> showMobileStripeCheckoutSheet({
  required BuildContext context,
  required String checkoutUrl,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showModalBottomSheet<MobileStripeCheckoutResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: scheme.surface.withValues(alpha: 0.0),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.96,
      child: _MobileStripeCheckoutSheet(
        checkoutUrl: checkoutUrl,
      ),
    ),
  );

  return result ?? const MobileStripeCheckoutResult.canceled();
}

MobileStripeCheckoutResult? mobileStripeCheckoutResultForNavigationUri(
  Uri uri, {
  String? checkoutBaseUrl,
}) {
  if (DeepLinks.isPaymentCallback(uri)) {
    return MobileStripeCheckoutResult.fromCallbackUri(uri);
  }

  final configuredValue = (checkoutBaseUrl ?? Constants.checkoutBaseUrl).trim();
  final configuredUri = Uri.tryParse(
    configuredValue.contains('://')
        ? configuredValue
        : 'https://$configuredValue',
  );
  if (configuredUri == null ||
      uri.host.toLowerCase() != configuredUri.host.toLowerCase() ||
      (configuredUri.hasPort && uri.port != configuredUri.port) ||
      uri.path != '/checkout' ||
      uri.queryParameters['source'] != 'mobile' ||
      uri.queryParameters['redirectUrl'] != DeepLinks.paymentCallback) {
    return null;
  }

  final status = uri.queryParameters['status'];
  if (status != 'success' && status != 'failed' && status != 'canceled') {
    return null;
  }
  return MobileStripeCheckoutResult.fromCallbackUri(uri);
}

Future<bool> waitForMobileStripeSubscriptionActivation({
  required Future<void> Function() refreshSubscription,
  required bool Function() hasActiveSubscription,
  Future<void> Function(Duration duration)? wait,
}) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    await refreshSubscription();
    if (hasActiveSubscription()) {
      return true;
    }

    final delaySeconds = attempt < 3
        ? 1
        : attempt < 7
            ? 2
            : 3;
    final delay = Duration(seconds: delaySeconds);
    if (wait != null) {
      await wait(delay);
    } else {
      await Future.delayed(delay);
    }
  }

  return false;
}

class _MobileStripeCheckoutSheet extends StatefulWidget {
  const _MobileStripeCheckoutSheet({
    required this.checkoutUrl,
  });

  final String checkoutUrl;

  @override
  State<_MobileStripeCheckoutSheet> createState() =>
      _MobileStripeCheckoutSheetState();
}

class _MobileStripeCheckoutSheetState
    extends State<_MobileStripeCheckoutSheet> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _hasLoadError = false;
  bool _didComplete = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  bool _completeFromNavigationUri(Uri? uri) {
    if (_didComplete || uri == null) return _didComplete;
    final result = mobileStripeCheckoutResultForNavigationUri(uri);
    if (result == null) return false;

    _didComplete = true;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
    return true;
  }

  Future<void> _reloadCheckout() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(widget.checkoutUrl),
        ),
      );
    } on MissingPluginException catch (_) {
      if (!mounted) return;
      await launchUrl(
        Uri.parse(widget.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      Navigator.of(context).pop(const MobileStripeCheckoutResult.canceled());
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _hasLoadError = true;
        _errorMessage = error.message ?? error.code;
        _progress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: scheme.sheetBorder.withValues(alpha: 0.32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.sheetBorder.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        const MobileStripeCheckoutResult.canceled(),
                      );
                    },
                    icon: Icon(
                      Icons.close,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 2,
                backgroundColor: scheme.muted.withValues(alpha: 0.3),
              )
            else
              Divider(
                height: 1,
                color: scheme.sheetBorder.withValues(alpha: 0.24),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: _hasLoadError
                    ? _CheckoutLoadErrorView(
                        errorMessage: _errorMessage,
                        onRetry: () {
                          setState(() {
                            _hasLoadError = false;
                            _errorMessage = null;
                          });
                          _reloadCheckout();
                        },
                      )
                    : InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(widget.checkoutUrl),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          javaScriptCanOpenWindowsAutomatically: true,
                          allowsInlineMediaPlayback: true,
                          allowsBackForwardNavigationGestures: true,
                          disableVerticalScroll: false,
                          alwaysBounceVertical: true,
                          isDirectionalLockEnabled: true,
                          useHybridComposition: true,
                          mediaPlaybackRequiresUserGesture: false,
                          supportZoom: false,
                          transparentBackground: true,
                          thirdPartyCookiesEnabled: true,
                          sharedCookiesEnabled: true,
                          useShouldOverrideUrlLoading: true,
                        ),
                        onWebViewCreated: (controller) {
                          if (!mounted) return;
                          _controller = controller;
                        },
                        onLoadStart: (_, url) {
                          _completeFromNavigationUri(
                            url == null ? null : Uri.tryParse(url.toString()),
                          );
                        },
                        onUpdateVisitedHistory: (_, url, __) {
                          _completeFromNavigationUri(
                            url == null ? null : Uri.tryParse(url.toString()),
                          );
                        },
                        onProgressChanged: (_, progress) {
                          if (!mounted || _didComplete) return;
                          setState(() {
                            _progress = progress / 100;
                          });
                        },
                        shouldOverrideUrlLoading:
                            (controller, navigationAction) async {
                          final rawUrl =
                              navigationAction.request.url?.toString();
                          final uri =
                              rawUrl == null ? null : Uri.tryParse(rawUrl);

                          if (uri == null) {
                            return NavigationActionPolicy.ALLOW;
                          }

                          if (_completeFromNavigationUri(uri)) {
                            return NavigationActionPolicy.CANCEL;
                          }

                          if (_shouldLaunchExternally(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            return NavigationActionPolicy.CANCEL;
                          }

                          return NavigationActionPolicy.ALLOW;
                        },
                        onReceivedError: (_, request, error) {
                          final uri = Uri.tryParse(request.url.toString());
                          if (_completeFromNavigationUri(uri) ||
                              !mounted ||
                              _didComplete ||
                              request.isForMainFrame == false) {
                            return;
                          }
                          setState(() {
                            _hasLoadError = true;
                            _errorMessage = error.description;
                            _progress = 0;
                          });
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldLaunchExternally(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme.isNotEmpty &&
        scheme != 'http' &&
        scheme != 'https' &&
        scheme != 'about' &&
        scheme != 'data' &&
        scheme != DeepLinks.appScheme;
  }
}

class _CheckoutLoadErrorView extends StatelessWidget {
  const _CheckoutLoadErrorView({
    required this.errorMessage,
    required this.onRetry,
  });

  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.sheetBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: scheme.warning,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.paywallErrorStartCheckout,
                style: TextStyle(
                  color: scheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? context.l10n.paywallErrorStartCheckout,
                style: TextStyle(
                  color: scheme.mutedForeground,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum MobileStripeCheckoutStatus {
  success,
  canceled,
  failed,
}

class MobileStripeCheckoutResult {
  const MobileStripeCheckoutResult({
    required this.status,
    this.sessionId,
    this.verificationNonce,
    this.errorMessage,
  });

  const MobileStripeCheckoutResult.canceled()
      : status = MobileStripeCheckoutStatus.canceled,
        sessionId = null,
        verificationNonce = null,
        errorMessage = null;

  factory MobileStripeCheckoutResult.fromCallbackUri(Uri uri) {
    final status = uri.queryParameters['status'];
    if (status == 'success') {
      return MobileStripeCheckoutResult(
        status: MobileStripeCheckoutStatus.success,
        sessionId: uri.queryParameters['session_id'],
        verificationNonce: uri.queryParameters['v'],
      );
    }

    if (status == 'failed') {
      return MobileStripeCheckoutResult(
        status: MobileStripeCheckoutStatus.failed,
        errorMessage: uri.queryParameters['error'],
      );
    }

    return const MobileStripeCheckoutResult.canceled();
  }

  final MobileStripeCheckoutStatus status;
  final String? sessionId;
  final String? verificationNonce;
  final String? errorMessage;

  bool get isSuccess => status == MobileStripeCheckoutStatus.success;
  bool get isCanceled => status == MobileStripeCheckoutStatus.canceled;
  bool get isFailed => status == MobileStripeCheckoutStatus.failed;
}
