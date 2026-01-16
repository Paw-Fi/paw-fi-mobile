// Shared UI utilities for household features
// Prevents code duplication across household widgets

import 'package:flutter/material.dart';
import '../../domain/entities/household.dart';
import '../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Gets the color associated with a household role
Color getRoleColor(HouseholdRole role, ColorScheme scheme) {
  switch (role) {
    case HouseholdRole.owner:
      return scheme.householdOwner;
    case HouseholdRole.admin:
      return scheme.householdAdmin;
    case HouseholdRole.member:
      return scheme.householdMember;
  }
}

/// Extracts initials from a name or email
String getInitials(String? name, {String fallback = 'U'}) {
  if (name == null || name.isEmpty) {
    return fallback;
  }
  
  // If it's an email, use the part before @
  if (name.contains('@')) {
    name = name.split('@').first;
  }
  
  // Split by whitespace or special characters
  final parts = name.split(RegExp(r'[\s._-]+'));
  
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  
  return name[0].toUpperCase();
}

/// Role Badge Widget - Modern pill design
class RoleBadge extends StatelessWidget {
  final HouseholdRole role;

  const RoleBadge({
    super.key, 
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final color = getRoleColor(role, Theme.of(context).colorScheme);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        _getLocalizedRole(context, role),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _getLocalizedRole(BuildContext context, HouseholdRole role) {
    switch (role) {
      case HouseholdRole.owner:
        return context.l10n.owner;
      case HouseholdRole.admin:
        return context.l10n.admin;
      case HouseholdRole.member:
        return context.l10n.member;
    }
  }
}

/// Member Avatar Widget - Clean, simple avatar
class MemberAvatar extends StatelessWidget {
  final HouseholdRole role;
  final String? avatarUrl;
  final String? name;
  final String? email;
  final double radius;

  const MemberAvatar({
    super.key,
    required this.role,
    this.avatarUrl,
    this.name,
    this.email,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final color = getRoleColor(role, Theme.of(context).colorScheme);
    final initials = getInitials(name ?? email);
    
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primaryForeground,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
