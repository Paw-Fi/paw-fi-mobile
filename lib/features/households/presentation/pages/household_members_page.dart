import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../utils/household_ui_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
/// Household Members Management Page
/// View members, update roles, remove members
class HouseholdMembersPage extends ConsumerWidget {
  final String householdId;

  const HouseholdMembersPage({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(householdMembersProvider(householdId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        backgroundColor: colorScheme.appBackground,
        elevation: 0,
        title: Text(
          context.l10n.members,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: colorScheme.primary),
            onPressed: () {
              // Navigate to invites page
              context.push('/households/$householdId/invites');
            },
            tooltip: context.l10n.inviteMember,
          ),
        ],
      ),
      body: membersAsync.when(
        data: (members) => RefreshIndicator(
          onRefresh: () => ref.read(householdMembersProvider(householdId).notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _MemberCard(
                member: member,
                householdId: householdId,
                onRemove: () => _confirmRemoveMember(context, ref, member),
                onUpdateRole: (role) => _updateMemberRole(context, ref, member, role),
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.destructive),
              const SizedBox(height: 16),
              Text(
                context.l10n.errorLoadingMembers,
                style: TextStyle(color: colorScheme.destructive),
              ),
              const SizedBox(height: 8),
              AdaptiveButton(
                onPressed: () => ref.read(householdMembersProvider(householdId).notifier).load(),
                style: AdaptiveButtonStyle.bordered,
                label: context.l10n.retry,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, WidgetRef ref, HouseholdMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.removeMember),
        content: Text('${context.l10n.confirmRemoveMember} ${member.userName ?? member.userEmail}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(householdMembersProvider(householdId).notifier).removeMember(member.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMemberRole(BuildContext context, WidgetRef ref, HouseholdMember member, HouseholdRole role) async {
    await ref.read(householdMembersProvider(householdId).notifier).updateRole(member.id, role);
    if (context.mounted) {
      AppToast.success(context, '${context.l10n.updatedMemberRole} ${member.userName ?? member.userEmail} to ${role.toJson()}');
    }
  }
}

/// Member Card Widget
class _MemberCard extends StatelessWidget {
  final HouseholdMember member;
  final String householdId;
  final VoidCallback onRemove;
  final Function(HouseholdRole) onUpdateRole;

  const _MemberCard({
    required this.member,
    required this.householdId,
    required this.onRemove,
    required this.onUpdateRole,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOwner = member.role == HouseholdRole.owner;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            MemberAvatar(
              role: member.role,
              avatarUrl: member.avatarUrl,
              name: member.userName,
              email: member.userEmail,
              radius: 24,
            ),
            const SizedBox(width: 16),

            // Member Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.userName ?? member.userEmail ?? context.l10n.unknown,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RoleBadge(role: member.role),
                      if (member.userEmail != null && member.userName != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          member.userEmail!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (!isOwner)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove') {
                    onRemove();
                  } else if (value == 'make_admin') {
                    onUpdateRole(HouseholdRole.admin);
                  } else if (value == 'make_member') {
                    onUpdateRole(HouseholdRole.member);
                  }
                },
                itemBuilder: (context) => [
                  if (member.role != HouseholdRole.admin)
                    PopupMenuItem(
                      value: 'make_admin',
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings),
                          const SizedBox(width: 8),
                          Text(context.l10n.makeAdmin),
                        ],
                      ),
                    ),
                  if (member.role != HouseholdRole.member)
                    PopupMenuItem(
                      value: 'make_member',
                      child: Row(
                        children: [
                          const Icon(Icons.person),
                          const SizedBox(width: 8),
                          Text(context.l10n.makeMember),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(Icons.remove_circle_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(context.l10n.remove, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
