import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/theme/app_theme.dart';

enum _MonekoAvatarMode {
  network,
  supabaseUser,
  placeholder,
}

class MonekoAvatar extends StatelessWidget {
  const MonekoAvatar._({
    super.key,
    required this.size,
    required this.fallbackIcon,
    required _MonekoAvatarMode mode,
    this.imageUrl,
    this.userId,
    this.borderWidth,
    this.borderColor,
  }) : _mode = mode;

  factory MonekoAvatar.network({
    Key? key,
    required double size,
    required IconData fallbackIcon,
    String? imageUrl,
    double? borderWidth,
    Color? borderColor,
  }) {
    return MonekoAvatar._(
      key: key,
      size: size,
      fallbackIcon: fallbackIcon,
      mode: _MonekoAvatarMode.network,
      imageUrl: imageUrl,
      borderWidth: borderWidth,
      borderColor: borderColor,
    );
  }

  factory MonekoAvatar.supabaseUser({
    Key? key,
    required double size,
    required String userId,
    String? fallbackImageUrl,
    double? borderWidth,
    Color? borderColor,
  }) {
    return MonekoAvatar._(
      key: key,
      size: size,
      fallbackIcon: Icons.person_rounded,
      mode: _MonekoAvatarMode.supabaseUser,
      userId: userId,
      imageUrl: fallbackImageUrl,
      borderWidth: borderWidth,
      borderColor: borderColor,
    );
  }

  factory MonekoAvatar.placeholder({
    Key? key,
    required double size,
    double? borderWidth,
    Color? borderColor,
  }) {
    return MonekoAvatar._(
      key: key,
      size: size,
      fallbackIcon: Icons.person_rounded,
      mode: _MonekoAvatarMode.placeholder,
      borderWidth: borderWidth,
      borderColor: borderColor,
    );
  }

  final double size;
  final IconData fallbackIcon;
  final _MonekoAvatarMode _mode;
  final String? imageUrl;
  final String? userId;
  final double? borderWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = switch (_mode) {
      _MonekoAvatarMode.placeholder => _buildPlaceholder(colorScheme),
      _MonekoAvatarMode.network => _buildNetworkAvatar(colorScheme),
      _MonekoAvatarMode.supabaseUser => _buildSupabaseUserAvatar(colorScheme),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderWidth != null
              ? Border.all(
                  color: borderColor ?? colorScheme.border,
                  width: borderWidth!,
                )
              : null,
        ),
        child: ClipOval(
          child: content,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.muted.withValues(alpha: 0.3),
    );
  }

  Widget _buildNetworkAvatar(ColorScheme colorScheme) {
    final validatedUrl = _validateImageUrl(imageUrl);
    if (validatedUrl == null) {
      return _fallback(colorScheme);
    }

    return CachedNetworkImage(
      imageUrl: validatedUrl,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => _fallback(colorScheme),
    );
  }

  Widget _buildSupabaseUserAvatar(ColorScheme colorScheme) {
    final id = userId;
    if (id == null || id.isEmpty) {
      return _fallback(colorScheme);
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('users')
          .select('avatar_url')
          .eq('id', id)
          .maybeSingle(),
      builder: (context, snapshot) {
        final dbAvatarUrl = snapshot.data != null
            ? snapshot.data!['avatar_url'] as String?
            : null;

        final validatedDbUrl = _validateImageUrl(dbAvatarUrl);
        final validatedFallbackUrl = _validateImageUrl(imageUrl);

        final resolvedUrl = validatedDbUrl ?? validatedFallbackUrl;
        if (resolvedUrl == null) {
          return _fallback(colorScheme);
        }

        return CachedNetworkImage(
          imageUrl: resolvedUrl,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _fallback(colorScheme),
        );
      },
    );
  }

  String? _validateImageUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed == 'SKIPPED') return null;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    return trimmed;
  }

  Widget _fallback(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.muted.withValues(alpha: 0.5),
      child: Icon(
        fallbackIcon,
        color: colorScheme.mutedForeground.withValues(alpha: 0.7),
      ),
    );
  }
}
