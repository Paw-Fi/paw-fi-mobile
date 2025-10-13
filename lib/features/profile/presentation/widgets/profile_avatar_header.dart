import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

Widget buildProfileAvatarHeader(BuildContext context, user) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  return Column(
    children: [
      SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                (user.displayName?.substring(0, 2).toUpperCase() ?? user.email.substring(0, 2).toUpperCase()),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryForeground,
                ),
              ),
            ),
            if (user.photoUrl != null)
              ClipOval(
                child: Image.network(
                  user.photoUrl!,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
          ],
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
