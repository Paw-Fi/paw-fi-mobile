import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'household_members_section.dart';

class HouseholdMembersPanel extends ConsumerWidget {
  const HouseholdMembersPanel({
    super.key,
    required this.householdId,
    required this.householdName,
    this.onDone,
  });

  final String householdId;
  final String householdName;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        HouseholdMembersSection(
          householdId: householdId,
          householdName: householdName,
        ),
        if (onDone != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: PrimaryAdaptiveButton(
              onPressed: onDone,
              child: Text(context.l10n.done),
            ),
          ),
      ],
    );
  }
}
