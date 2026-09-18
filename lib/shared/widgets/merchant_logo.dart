import 'package:flutter/material.dart';
import 'package:moneko/core/util/constants.dart';

String? buildLogoDevMerchantUrl(String? merchantId, String? domain) {
  final normalizedDomain = domain?.trim().toLowerCase();
  if (merchantId?.trim().isEmpty ?? true) return null;
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
}) {
  if (merchantId?.trim().isEmpty ?? true) return null;
  return sanitizePlaidMerchantLogoUrl(logoUrl) ??
      buildLogoDevMerchantUrl(merchantId, domain);
}

class MerchantLogo extends StatelessWidget {
  const MerchantLogo({
    super.key,
    required this.merchantId,
    required this.domain,
    this.logoUrl,
    required this.fallback,
  });

  final String? merchantId;
  final String? domain;
  final String? logoUrl;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final url = buildMerchantLogoUrl(
      logoUrl: logoUrl,
      merchantId: merchantId,
      domain: domain,
    );
    if (url == null) return fallback;

    return Semantics(
      label: 'Merchant logo',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          cacheWidth: 72,
          errorBuilder: (_, __, ___) => fallback,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: child,
            );
          },
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
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
