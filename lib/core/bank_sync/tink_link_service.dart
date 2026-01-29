import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result from completing Tink Link flow.
class TinkLinkResult {
  TinkLinkResult({
    required this.code,
    this.credentialsId,
  });

  /// The authorization code returned by Tink after successful connection.
  final String code;

  /// The Tink credentials ID (if available).
  final String? credentialsId;
}

/// Opens Tink Link URL in the system browser.
///
/// The user will be redirected back to the app via deep link after
/// completing or cancelling the Tink Link flow.
///
/// Returns the Tink Link URL that was opened, for tracking purposes.
Future<bool> openTinkLink(String linkUrl) async {
  final uri = Uri.parse(linkUrl);

  if (!await canLaunchUrl(uri)) {
    debugPrint('[TinkLink] Cannot launch URL: $linkUrl');
    return false;
  }

  final result = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  debugPrint('[TinkLink] Launched Tink Link: $result');
  return result;
}

/// Parses a Tink callback URI to extract the authorization code.
///
/// Expected format: moneko://tink/callback?code=xxx&credentialsId=yyy
TinkLinkResult? parseTinkCallback(Uri uri) {
  if (uri.scheme != 'moneko' || uri.host != 'tink') {
    return null;
  }

  final code = uri.queryParameters['code'];
  if (code == null || code.isEmpty) {
    debugPrint('[TinkLink] Callback missing code parameter: $uri');
    return null;
  }

  return TinkLinkResult(
    code: code,
    credentialsId: uri.queryParameters['credentialsId'],
  );
}
