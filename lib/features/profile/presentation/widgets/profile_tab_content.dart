import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/profile/presentation/widgets/profile_helpers.dart';
import 'package:moneko/features/profile/presentation/widgets/profile_action_buttons.dart';

Widget buildOverviewTab(BuildContext context, user, WidgetRef ref) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildSectionTitle(context, 'Account Information'),
      const shadcnui.Gap(16),
      buildInfoCard(context, user),
      const shadcnui.Gap(32),
      buildProfileActionButtons(ref),
    ],
  );
}

Widget buildInfoCard(BuildContext context, user) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colorScheme.border, width: 1),
    ),
    child: Column(
      children: [
        buildInfoRow(context, 'User ID', user.uid.substring(0, 16) + '...'),
        const shadcnui.Gap(20),
        buildInfoRow(context, 'Email', user.email),
      ],
    ),
  );
}

Widget buildInfoRow(BuildContext context, String label, String value, {Widget? trailing}) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.mutedForeground,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing ?? Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

Widget buildActivityTab(BuildContext context) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildSectionTitle(context, 'Recent Activity'),
      const shadcnui.Gap(16),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    ],
  );
}
