import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

/// User avatar widget with fallback to initials
/// 
/// Displays user's avatar image if available, otherwise shows initials
/// Supports both fixed sizes and flexible sizing
class UserAvatar extends StatelessWidget {
  /// User's avatar URL (optional)
  final String? avatarUrl;
  
  /// User's display name for fallback initials
  final String? name;
  
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final avatarSize = _getSize();
    final fontSize = _getFontSize(avatarSize);
    final initials = _getInitials(name);

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withOpacity(0.1),
        border: borderWidth != null
            ? Border.all(
                color: borderColor ?? colorScheme.border,
                width: borderWidth!,
              )
            : null,
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to initials on image load error
                  return _buildInitials(colorScheme, initials, fontSize);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  // Show loading indicator
                  return Center(
                    child: SizedBox(
                      width: avatarSize * 0.5,
                      height: avatarSize * 0.5,
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
            )
          : _buildInitials(colorScheme, initials, fontSize),
    );
  }

  Widget _buildInitials(shadcnui.ColorScheme colorScheme, String initials, double fontSize) {
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
