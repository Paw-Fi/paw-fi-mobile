import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/util/constants.dart';

String? buildLogoDevMerchantUrl(String? merchantId, String? domain) {
  final normalizedDomain = domain?.trim().toLowerCase();
  if (normalizedDomain == null || normalizedDomain.isEmpty) {
    return null;
  }
  String token;
  try {
    token = Constants.logoDevPublishableKey.trim();
  } catch (_) {
    return null;
  }
  if (token.isEmpty) return null;
  return Uri.https('img.logo.dev', normalizedDomain, {
    'token': token,
    'size': '72',
    'format': 'png',
    'fallback': '404',
  }).toString();
}

String? buildLogoDevMerchantNameUrl(String? merchantName) {
  final name = merchantName?.trim();
  if (name == null || name.isEmpty) return null;

  String token;
  try {
    token = Constants.logoDevPublishableKey.trim();
  } catch (_) {
    return null;
  }
  if (token.isEmpty) return null;

  return Uri(
    scheme: 'https',
    host: 'img.logo.dev',
    pathSegments: ['name', name],
    queryParameters: {
      'token': token,
      'size': '72',
      'format': 'png',
      'fallback': '404',
    },
  ).toString();
}

String? sanitizePlaidMerchantLogoUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null || uri.scheme != 'https') return null;
  if (uri.host != 'plaid-merchant-logos.plaid.com' &&
      uri.host != 'plaid-counterparty-logos.plaid.com') {
    return null;
  }
  return uri.toString();
}

String? buildMerchantLogoUrl({
  required String? logoUrl,
  required String? merchantId,
  required String? domain,
  String? merchantStructuredName,
  String? merchantName,
}) {
  final structuredName = merchantStructuredName?.trim();
  return sanitizePlaidMerchantLogoUrl(logoUrl) ??
      buildLogoDevMerchantUrl(merchantId, domain) ??
      buildLogoDevMerchantNameUrl(structuredName);
}

class MerchantLogo extends StatelessWidget {
  const MerchantLogo({
    super.key,
    required this.merchantId,
    required this.domain,
    this.merchantStructuredName,
    this.merchantName,
    this.logoUrl,
    required this.fallback,
  });

  final String? merchantId;
  final String? domain;
  final String? merchantStructuredName;
  final String? merchantName;
  final String? logoUrl;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final url = buildMerchantLogoUrl(
      logoUrl: logoUrl,
      merchantId: merchantId,
      domain: domain,
      merchantStructuredName: merchantStructuredName,
      merchantName: merchantName,
    );
    if (url == null) return fallback;

    return Semantics(
      label: 'Merchant logo',
      image: true,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          memCacheWidth: 72,
          cacheKey: url,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class MerchantCandidateLogo extends StatelessWidget {
  const MerchantCandidateLogo({
    super.key,
    required this.domain,
    required this.fallback,
  });

  final String domain;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => MerchantLogo(
        merchantId: 'candidate',
        domain: domain,
        fallback: fallback,
      );
}
