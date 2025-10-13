import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

Widget buildSectionTitle(BuildContext context, String title) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  return Text(
    title,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: colorScheme.foreground,
      letterSpacing: -0.2,
    ),
  );
}

Widget buildBenefitIcon(BuildContext context, IconData icon, String label) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  return Column(
    children: [
      Icon(
        icon,
        color: const Color(0xFF25D366),
        size: 24,
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.mutedForeground,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
