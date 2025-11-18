import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/profile/presentation/widgets/profile_helpers.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

Widget buildOverviewTab(BuildContext context, user, WidgetRef ref) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildSectionTitle(context, context.l10n.accountInformation),
      const shadcnui.Gap(16),
      buildInfoCard(context, user),
    ],
  );
}

Widget buildInfoCard(BuildContext context, user) {
  final colorScheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colorScheme.border, width: 1),
    ),
    child: Column(
      children: [
        buildInfoRow(context, context.l10n.userId, user.uid.substring(0, 16) + '...'),
        const shadcnui.Gap(20),
        buildInfoRow(context, context.l10n.email, user.email),
      ],
    ),
  );
}

Widget buildInfoRow(BuildContext context, String label, String value, {Widget? trailing}) {
  final colorScheme = Theme.of(context).colorScheme;
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
  final colorScheme = Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildSectionTitle(context, context.l10n.recentActivity),
      const shadcnui.Gap(16),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.noActivityYet,
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
