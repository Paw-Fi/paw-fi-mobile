import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/utils/invite_link_utils.dart';
import 'package:moneko/features/households/presentation/utils/household_ui_utils.dart';
import 'household_invite_composer.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class HouseholdMembersSection extends ConsumerStatefulWidget {
  final String householdId;
  final String? householdName;

  const HouseholdMembersSection({
    super.key,
    required this.householdId,
    this.householdName,
  });

  @override
  ConsumerState<HouseholdMembersSection> createState() =>
      _HouseholdMembersSectionState();
}

class _HouseholdMembersSectionState
    extends ConsumerState<HouseholdMembersSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(householdInvitesProvider(widget.householdId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final invitesAsync =
        ref.watch(householdInvitesProvider(widget.householdId));

    final currentUserId = ref.watch(currentUserIdProvider);

    if (membersAsync.isLoading && !membersAsync.hasValue) {
      return _buildSkeleton(context);
    }

    // We handle errors gracefully or just show empty/loading
    if (!membersAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final invites = invitesAsync.valueOrNull ?? [];
    final pendingInvites = invites
        .where((invite) =>
            !invite.isReusable &&
            (invite.status == InviteStatus.pending ||
                invite.status == InviteStatus.expired))
        .toList();
    // Permissions
    final currentUserMember = membersAsync.value!.firstWhere(
      (m) => m.userId == currentUserId,
      orElse: () => HouseholdMember(
        id: '',
        householdId: '',
        userId: currentUserId ?? '',
        role: HouseholdRole.member,
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final currentUserRole = currentUserMember.role;
    final canManageMembers = currentUserRole == HouseholdRole.owner ||
        currentUserRole == HouseholdRole.admin;

    return Column(
      children: [
        _buildMembersList(
          context,
          membersAsync.value!,
          pendingInvites,
          canManageMembers,
          currentUserRole,
          currentUserId,
        ),
        if (canManageMembers) _buildInviteMembersSection(context),
      ],
    );
  }

  Widget _buildInviteMembersSection(BuildContext context,
      {bool enabled = true}) {
    final scheme = Theme.of(context).colorScheme;
    return _buildSettingsSection(
      context,
      title: context.l10n.inviteMembers,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.inviteMembersDescription,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.mutedForeground, height: 1.5)),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PrimaryAdaptiveButton(
                        onPressed: enabled
                            ? () => showHouseholdInviteComposer(context,
                                householdId: widget.householdId)
                            : null,
                        child: Text(context.l10n.shareGroupLink,
                            maxLines: 10,
                            overflow: TextOverflow.visible,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: scheme.copyWith(
                            primary: scheme.primary.withValues(alpha: 0.12),
                            onPrimary: scheme.primary,
                          ),
                        ),
                        child: PrimaryAdaptiveButton(
                          onPressed: enabled
                              ? () => showHouseholdInviteComposer(context,
                                  householdId: widget.householdId,
                                  isReusable: false)
                              : null,
                          child: Text(context.l10n.inviteByEmail,
                              maxLines: 10,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList(
    BuildContext context,
    List<HouseholdMember> members,
    List<HouseholdInvite> pendingInvites,
    bool canManage,
    HouseholdRole currentUserRole,
    String? currentUserId,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildSettingsSection(
      context,
      title: context.l10n.members,
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
            MaterialLocalizations.of(context).formatDecimal(members.length),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.mutedForeground,
                fontWeight: FontWeight.w600)),
      ),
      children: [
        // Member List
        ...members.map((member) {
          final isMe = member.userId == currentUserId;
          // Permission check logic
          final isTargetOwner = member.role == HouseholdRole.owner;
          final canModifyThisUser = canManage &&
              ((currentUserRole == HouseholdRole.owner && !isTargetOwner) ||
                  (currentUserRole == HouseholdRole.admin &&
                      member.role == HouseholdRole.member));

          final isActionable = canModifyThisUser && !isMe;

          return _buildSettingsTile(
            context: context,
            leading: MemberAvatar(
              role: member.role,
              avatarUrl: member.avatarUrl,
              name: member.userName,
              email: member.userEmail,
              radius: 20,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    (member.userName?.isNotEmpty == true
                            ? member.userName!
                            : member.userEmail) ??
                        context.l10n.unknown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  _buildInlinePill(
                    context,
                    label: context.l10n.you,
                  ),
                ],
              ],
            ),
            subtitle: member.userName?.isNotEmpty == true
                ? Text(member.userEmail ?? '')
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _memberRoleLabel(context, member.role),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                if (isActionable) ...[
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
            onTap: isActionable ? () => _showMemberActionSheet(member) : null,
          );
        }),
        ...pendingInvites.map((invite) {
          final isExpired = invite.status == InviteStatus.expired ||
              (invite.expiresAt != null &&
                  !invite.expiresAt!.isAfter(DateTime.now()));

          return _buildSettingsTile(
            context: context,
            leading: _buildIconBadge(
              context,
              icon: CupertinoIcons.mail,
              iconColor: colorScheme.mutedForeground,
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            title: Text(
              invite.isReusable
                  ? context.l10n.groupInviteLink
                  : invite.invitedEmail ?? context.l10n.anyoneWithLink,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${_memberRoleLabel(context, invite.invitedRole)} · '
                '${invite.expiresAt == null ? context.l10n.inviteNeverExpires : _formatExpiryDate(invite.expiresAt, context)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExpired ? context.l10n.expired : context.l10n.pending,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
            onTap: canManage ? () => _showInviteActionSheet(invite) : null,
          );
        }),
      ],
    );
  }

  // Helpers & Logic

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Skeletonizer(
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: Column(children: [
        _buildSettingsSection(
          context,
          title: context.l10n.members,
          headerTrailing: const Bone(width: 32, height: 24),
          children: [
            _buildSettingsTile(
              context: context,
              leading: const Bone.circle(size: 40),
              title: const Bone.text(words: 2, fontSize: 15),
              subtitle: const Bone.text(words: 3, fontSize: 13),
              trailing: Text(
                context.l10n.owner,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
            _buildSettingsTile(
              context: context,
              leading: const Bone.circle(size: 40),
              title: const Bone.text(words: 2, fontSize: 15),
              subtitle: const Bone.text(words: 3, fontSize: 13),
              trailing: Text(
                context.l10n.member,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        _buildInviteMembersSection(context, enabled: false),
      ]),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    Widget? headerTrailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: colorScheme.mutedForeground,
              ),
            )),
            if (headerTrailing != null) ...[
              const SizedBox(width: 12),
              headerTrailing,
            ],
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.cardSurface,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: _withSectionDividers(context, children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required Widget title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSubtitle = subtitle != null;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: hasSubtitle ? 58 : 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              crossAxisAlignment: hasSubtitle
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: hasSubtitle
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.foreground,
                        ),
                        child: title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.mutedForeground,
                          ),
                          child: subtitle,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _withSectionDividers(
    BuildContext context,
    List<Widget> children,
  ) {
    if (children.isEmpty) return [];
    final colorScheme = Theme.of(context).colorScheme;

    return List<Widget>.generate(children.length * 2 - 1, (index) {
      if (index.isEven) {
        return children[index ~/ 2];
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: colorScheme.border.withValues(alpha: 0.22),
        ),
      );
    });
  }

  Widget _buildIconBadge(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }

  String _memberRoleLabel(BuildContext context, HouseholdRole role) {
    switch (role) {
      case HouseholdRole.owner:
        return context.l10n.owner;
      case HouseholdRole.admin:
        return context.l10n.admin;
      case HouseholdRole.member:
        return context.l10n.member;
    }
  }

  Widget _buildInlinePill(
    BuildContext context, {
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colorScheme.mutedForeground,
        ),
      ),
    );
  }

  String _formatExpiryDate(DateTime? date, BuildContext context) {
    if (date == null) return context.l10n.noExpiry;
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return context.l10n.expiresInDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return context.l10n.expiresInHours(difference.inHours);
    } else if (difference.inDays < 0) {
      return context.l10n.expiredDaysAgo(difference.inDays.abs());
    }
    return context.l10n.expiresSoon;
  }

  // --- Actions ---

  void _showMemberActionSheet(HouseholdMember member) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('${member.userName ?? member.userEmail}'),
        actions: [
          if (member.role != HouseholdRole.admin)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _updateMemberRole(member, HouseholdRole.admin);
              },
              child: Text(context.l10n.makeAdmin),
            ),
          if (member.role != HouseholdRole.member)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _updateMemberRole(member, HouseholdRole.member);
              },
              child: Text(context.l10n.makeMember),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmRemoveMember(member);
            },
            child: Text(context.l10n.remove),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _updateMemberRole(
      HouseholdMember member, HouseholdRole role) async {
    try {
      await ref
          .read(householdMembersProvider(widget.householdId).notifier)
          .updateRole(member.id, role);
      if (mounted) {
        // ignore: use_build_context_synchronously
        AppToast.success(context, context.l10n.saved);
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        AppToast.error(context, '${context.l10n.failedToUpdateRole}: $e');
      }
    }
  }

  Future<void> _confirmRemoveMember(HouseholdMember member) async {
    final confirmed = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.removeMember,
      description:
          '${context.l10n.confirmRemoveMember} ${member.userName ?? member.userEmail}?',
      confirmLabel: context.l10n.remove,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );

    if (confirmed?.confirmed == true) {
      try {
        await ref
            .read(householdMembersProvider(widget.householdId).notifier)
            .removeMember(member.id);
        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.success(context, context.l10n.memberRemoved);
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.error(context, '${context.l10n.failedToRemoveMember}: $e');
        }
      }
    }
  }

  void _showInviteActionSheet(HouseholdInvite invite) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(invite.invitedEmail ?? context.l10n.anyoneWithLink),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              final inviteUrl = buildInviteLink(invite.token);
              Clipboard.setData(ClipboardData(text: inviteUrl));
              AppToast.success(
                  context, context.l10n.inviteLinkCopiedToClipboard);
            },
            child: Text(context.l10n.copyLink),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(householdInvitesProvider(widget.householdId).notifier)
                    .revokeInvite(inviteId: invite.id);
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  AppToast.success(context, context.l10n.invitationRevoked);
                }
              } catch (e) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  AppToast.error(
                      context, '${context.l10n.errorRevokingInvite}: $e');
                }
              }
            },
            child: Text(context.l10n.revokeInvitation),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }
}
