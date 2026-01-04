import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildSectionTitle(BuildContext context, String titleKey) {
  final colorScheme = Theme.of(context).colorScheme;
  return Text(
    titleKey,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: colorScheme.foreground,
      letterSpacing: -0.2,
    ),
  );
}

Widget buildBenefitIcon(BuildContext context, IconData icon, String label) {
  final colorScheme = Theme.of(context).colorScheme;
  return Column(
    children: [
      Icon(
        icon,
        color: AppTheme.whatsappGreen,
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
