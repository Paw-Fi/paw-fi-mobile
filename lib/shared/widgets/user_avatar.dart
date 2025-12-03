import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User avatar widget with fallback to initials
///
/// Displays user's avatar image if available, otherwise shows initials
/// Supports both fixed sizes and flexible sizing
class UserAvatar extends StatelessWidget {
  /// User's avatar URL (optional)
  final String? avatarUrl;

  /// User's display name for fallback initials
  final String? name;

  /// User's ID for fetching avatar (optional)
  final String? userId;

  /// Size of the avatar
  /// Can be a preset ('small', 'medium', 'large') or a custom double value
  final dynamic size;

  /// Border width (optional)
  final double? borderWidth;

  /// Border color (optional)
  final Color? borderColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.userId,
    this.size = 'medium',
    this.borderWidth,
    this.borderColor,
  });

  /// Get numeric size from preset or custom value
  double _getSize() {
    if (size is double || size is int) {
      return (size as num).toDouble();
    }

    switch (size as String) {
      case 'tiny':
        return 16;
      case 'small':
        return 24;
      case 'medium':
        return 40;
      case 'large':
        return 64;
      case 'xlarge':
        return 96;
      default:
        return 40;
    }
  }

  /// Get font size based on avatar size
  double _getFontSize(double avatarSize) {
    if (avatarSize <= 16) return 8;
    if (avatarSize <= 24) return 11;
    if (avatarSize <= 40) return 16;
    if (avatarSize <= 64) return 24;
    return 32;
  }

  /// Extract initials from name
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      // Single word: take first character
      return parts[0][0].toUpperCase();
    } else {
      // Multiple words: take first character of first two words
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
  }

  /// Fetch avatar URL from Supabase
  Future<String?> _fetchAvatarUrl() async {
    if (userId == null) return null;
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('avatar_url')
          .eq('id', userId!)
          .maybeSingle();

      return response?['avatar_url'] as String?;
    } catch (e) {
      debugPrint('Error fetching user avatar: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarSize = _getSize();
    final fontSize = _getFontSize(avatarSize);
    final initials = _getInitials(name);

    // If we have a direct URL, use it
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return _buildAvatarContainer(
        context,
        colorScheme,
        avatarSize,
        _buildImage(colorScheme, avatarUrl!, avatarSize, initials, fontSize),
      );
    }

    // If we have a userId, fetch the URL
    if (userId != null) {
      return FutureBuilder<String?>(
        future: _fetchAvatarUrl(),
        builder: (context, snapshot) {
          final fetchedUrl = snapshot.data;
          if (fetchedUrl != null && fetchedUrl.isNotEmpty) {
            return _buildAvatarContainer(
              context,
              colorScheme,
              avatarSize,
              _buildImage(
                  colorScheme, fetchedUrl, avatarSize, initials, fontSize),
            );
          }
          // Fallback to initials while loading or if no URL
          return _buildAvatarContainer(
            context,
            colorScheme,
            avatarSize,
            _buildInitials(colorScheme, initials, fontSize),
          );
        },
      );
    }

    // Fallback to initials
    return _buildAvatarContainer(
      context,
      colorScheme,
      avatarSize,
      _buildInitials(colorScheme, initials, fontSize),
    );
  }

  Widget _buildAvatarContainer(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    Widget child,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.1),
        border: borderWidth != null
            ? Border.all(
                color: borderColor ?? colorScheme.border,
                width: borderWidth!,
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildImage(
    ColorScheme colorScheme,
    String url,
    double size,
    String initials,
    double fontSize,
  ) {
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitials(colorScheme, initials, fontSize);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.5,
              height: size * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitials(
      ColorScheme colorScheme, String initials, double fontSize) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
          height: 1.0,
        ),
      ),
    );
  }
}

/// User info model for avatar
class UserInfo {
  final String? id;
  final String? name;
  final String? email;
  final String? avatarUrl;

  UserInfo({
    this.id,
    this.name,
    this.email,
    this.avatarUrl,
  });

  /// Get display name with fallback to email username
  String? get displayName {
    if (name != null && name!.isNotEmpty) {
      return name;
    }
    if (email != null && email!.isNotEmpty) {
      return email!.split('@').first;
    }
    return null;
  }
}
