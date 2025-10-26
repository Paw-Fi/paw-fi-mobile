import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';

Widget buildProfileHeader(BuildContext context, WidgetRef ref) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        context.l10n.profile,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: colorScheme.foreground,
          letterSpacing: -0.5,
        ),
      ),
      shadcnui.IconButton(
        variance: shadcnui.ButtonVariance.ghost,
        icon: Icon(Icons.settings_outlined, color: colorScheme.mutedForeground),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SettingsPage(),
            ),
          );
        },
      ),
    ],
  );
}
