import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import '../widgets/household_members_panel.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class InviteMembersPage extends ConsumerWidget {
  const InviteMembersPage({
    super.key,
    required this.householdId,
    required this.householdName,
    required this.onDone,
  });

  final String householdId;
  final String householdName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.inviteMembers,
      ),
      body: Padding(
        padding: EdgeInsets.only(top: getSubPageTopPadding(context)),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: getSubPageTopPadding(context),
                bottom: 32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  HouseholdMembersPanel(
                    householdId: householdId,
                    householdName: householdName,
                    onDone: onDone,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
