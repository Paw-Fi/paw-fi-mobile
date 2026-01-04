import 'package:flutter/material.dart';

import '../../domain/entities/household.dart';
import 'package:moneko/core/theme/app_theme.dart';

class MemberAvatars extends StatelessWidget {
  final List<HouseholdMember> members;

  const MemberAvatars({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: members.map((member) {
        return Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _getRoleColor(member.role, colorScheme),
              child: Text(
                _getInitials(member.userEmail ?? member.userId),
                style: TextStyle(
                  color: colorScheme.primaryForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getRoleLabel(member.role),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _getInitials(String text) {
    final parts = text.split('@');
    final name = parts.first;
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Color _getRoleColor(HouseholdRole role, ColorScheme scheme) {
    switch (role) {
      case HouseholdRole.owner:
        return scheme.householdOwner;
      case HouseholdRole.admin:
        return scheme.householdAdmin;
      case HouseholdRole.member:
        return scheme.householdMember;
    }
  }

  String _getRoleLabel(HouseholdRole role) {
    switch (role) {
      case HouseholdRole.owner:
        return 'Owner';
      case HouseholdRole.admin:
        return 'Admin';
      case HouseholdRole.member:
        return 'Member';
    }
  }
}
