import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moneko/shared/widgets/wallet_pocket_icon.dart';

export 'package:moneko/shared/widgets/wallet_pocket_icon.dart';

Color parseWalletColor(String? colorHex, Color fallback) {
  final raw = (colorHex ?? '').trim();
  if (!raw.startsWith('#') || raw.length < 7) return fallback;
  final hex = raw.substring(1, 7);
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return fallback;
  return Color(0xFF000000 | parsed);
}

class WalletLogoAvatar extends StatelessWidget {
  const WalletLogoAvatar({
    super.key,
    required this.logoUrl,
    required this.iconName,
    required this.baseColor,
    required this.size,
    required this.iconSize,
  });

  final String? logoUrl;
  final String? iconName;
  final Color baseColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final trimmedLogoUrl = logoUrl?.trim();
    final cacheSize = (size * MediaQuery.of(context).devicePixelRatio).round();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: trimmedLogoUrl == null || trimmedLogoUrl.isEmpty
            ? _WalletFallbackIcon(
                iconName: iconName,
                iconSize: iconSize,
              )
            : CachedNetworkImage(
                imageUrl: trimmedLogoUrl,
                fit: BoxFit.contain,
                memCacheWidth: cacheSize,
                memCacheHeight: cacheSize,
                cacheKey: trimmedLogoUrl,
                placeholder: (_, __) {
                  return _WalletFallbackIcon(
                    iconName: iconName,
                    iconSize: iconSize,
                  );
                },
                errorWidget: (_, __, ___) => _WalletFallbackIcon(
                  iconName: iconName,
                  iconSize: iconSize,
                ),
              ),
      ),
    );
  }
}

class _WalletFallbackIcon extends StatelessWidget {
  const _WalletFallbackIcon({
    required this.iconName,
    required this.iconSize,
  });

  final String? iconName;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: buildWalletPocketIcon(iconName, size: iconSize),
    );
  }
}
