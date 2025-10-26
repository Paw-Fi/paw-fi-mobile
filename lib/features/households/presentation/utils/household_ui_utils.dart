// Shared UI utilities for household features
// Prevents code duplication across household widgets

import 'package:flutter/material.dart';
import '../../domain/entities/household.dart';
import '../../../../core/l10n/l10n.dart';

/// Gets the color associated with a household role
Color getRoleColor(HouseholdRole role) {
  switch (role) {
    case HouseholdRole.owner:
      return Colors.purple;
    case HouseholdRole.admin:
      return Colors.blue;
    case HouseholdRole.member:
      return Colors.green;
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

/// Role Badge Widget - Reusable role indicator
class RoleBadge extends StatelessWidget {
  final HouseholdRole role;

  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final color = getRoleColor(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        _getLocalizedRole(context, role),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
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

/// Member Avatar Widget - Reusable avatar with fallback to initials
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
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final color = getRoleColor(role);
    final initials = getInitials(name ?? email);
    
    // Use network image if available
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {
          // Fallback to initials on error
        },
        child: null,
      );
    }
    
    // Fallback to initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
