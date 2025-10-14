import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

Widget buildProfileAvatarHeader(BuildContext context, user) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  final initials =
      user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim().substring(0, 1).toUpperCase()
          : user.email.substring(0, 1).toUpperCase();
  final avatarUrl = user.photoUrl;

  return Column(
    children: [
      Container(
        width: 104,
        height: 104,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: avatarUrl != null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF7458FF), Color(0xFF836DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                )
              : Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7458FF), Color(0xFF836DFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
        ),
      ),
      const shadcnui.Gap(20),
      Text(
        user.displayName ?? 'User',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: colorScheme.foreground,
          letterSpacing: -0.3,
        ),
      ),
      const shadcnui.Gap(8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            user.email,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w400,
            ),
          ),
          const shadcnui.Gap(8),
          const shadcnui.PrimaryBadge(
            child: Text(
              'PRO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ],
  );
}
