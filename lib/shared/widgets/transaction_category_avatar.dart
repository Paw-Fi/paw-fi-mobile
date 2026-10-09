import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';

/// Shared leading avatar for transaction and recurring transaction rows.
class TransactionCategoryAvatar extends StatelessWidget {
  const TransactionCategoryAvatar({
    super.key,
    required this.category,
    this.merchantId,
    this.merchantDomain,
    this.merchantLogoUrl,
    this.merchantStructuredName,
    this.merchantName,
    this.useCustomCategoryStyleOverrides = false,
    this.size = 36,
    this.imageSize = 20,
  });

  final String category;
  final String? merchantId;
  final String? merchantDomain;
  final String? merchantLogoUrl;
  final String? merchantStructuredName;
  final String? merchantName;
  final bool useCustomCategoryStyleOverrides;
  final double size;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    final hasMerchantLogo = buildMerchantLogoUrl(
          logoUrl: merchantLogoUrl,
          merchantId: merchantId,
          domain: merchantDomain,
          merchantStructuredName: merchantStructuredName,
          merchantName: merchantName,
        ) !=
        null;
    final merchantLogo = MerchantLogo(
      merchantId: merchantId,
      domain: merchantDomain,
      logoUrl: merchantLogoUrl,
      merchantStructuredName: merchantStructuredName,
      merchantName: merchantName,
      fallback: buildCategoryIcon(
        category,
        size: imageSize,
        useCustomStyleOverrides: useCustomCategoryStyleOverrides,
      ),
    );

    if (hasMerchantLogo) {
      return ClipOval(
        child: SizedBox.square(dimension: size, child: merchantLogo),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.04),
          shape: BoxShape.circle,
        ),
        child: merchantLogo,
      ),
    );
  }
}
