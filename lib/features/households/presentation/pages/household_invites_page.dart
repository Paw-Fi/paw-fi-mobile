import 'package:flutter/material.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/destructive_adaptive_button.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/auth/auth.dart';
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../widgets/household_invite_composer.dart';
import '../utils/invite_link_utils.dart';
import '../utils/household_member_permissions.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Household Invites Management Page
/// Create, view, copy, and revoke invitations
class HouseholdInvitesPage extends ConsumerStatefulWidget {
  final String householdId;

  const HouseholdInvitesPage({
    super.key,
    required this.householdId,
  });

  @override
  ConsumerState<HouseholdInvitesPage> createState() =>
      _HouseholdInvitesPageState();
}

class _HouseholdInvitesPageState extends ConsumerState<HouseholdInvitesPage> {
  List<HouseholdInvite> _invites = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(householdRepositoryProvider);
      final invites = await repository.getHouseholdInvites(widget.householdId);
      setState(() {
        _invites = invites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppToast.error(context, '${context.l10n.errorLoadingInvites}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = ref.watch(currentUserIdProvider);
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final currentUserMember = _currentUserMember(
      membersAsync.valueOrNull,
      currentUserId,
    );
    final canManageMembers = canManageHouseholdMembers(
      currentUserId: currentUserId,
      currentUserMember: currentUserMember,
    );

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        backgroundColor: colorScheme.appBackground,
        elevation: 0,
        title: Text(
          context.l10n.invitations,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
      ),
      body: _isLoading
          ? const AsyncDataSkeleton(rowCount: 4)
          : RefreshIndicator(
              onRefresh: _loadInvites,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (canManageMembers) ...[
                    PrimaryAdaptiveButton(
                      onPressed: () =>
                          _showCreateInviteDialog(context, isReusable: true),
                      prefixIcon: const Icon(Icons.link),
                      child: Text(context.l10n.shareGroupLink),
                    ),
                    const SizedBox(height: 12),
                    PrimaryAdaptiveButton(
                      onPressed: () => _showCreateInviteDialog(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add),
                          const SizedBox(width: 8),
                          Text(context.l10n.inviteIndividual),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Invites List
                  Text(
                    context.l10n.pendingInvitations,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_invites
                      .where((i) => i.status == InviteStatus.pending)
                      .isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          context.l10n.noPendingInvitations,
                          style: TextStyle(color: colorScheme.mutedForeground),
                        ),
                      ),
                    )
                  else
                    ..._invites
                        .where((i) => i.status == InviteStatus.pending)
                        .map((invite) => _InviteCard(
                              invite: invite,
                              onCopy: () => _copyInviteLink(invite),
                              onRevoke: canRevokeHouseholdInvite(
                                canManageMembers: canManageMembers,
                                invite: invite,
                                currentUserId: currentUserId,
                              )
                                  ? () => _revokeInvite(invite)
                                  : null,
                            )),

                  const SizedBox(height: 24),
                  Text(
                    context.l10n.invitationHistory,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_invites
                      .where((i) => i.status != InviteStatus.pending)
                      .isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          context.l10n.noInvitationHistory,
                          style: TextStyle(color: colorScheme.mutedForeground),
                        ),
                      ),
                    )
                  else
                    ..._invites
                        .where((i) => i.status != InviteStatus.pending)
                        .map((invite) => _InviteCard(
                              invite: invite,
                              onCopy: null,
                              onRevoke: null,
                            )),
                ],
              ),
            ),
    );
  }

  HouseholdMember? _currentUserMember(
    List<HouseholdMember>? members,
    String? currentUserId,
  ) {
    if (members == null || currentUserId == null) return null;
    for (final member in members) {
      if (member.userId == currentUserId) return member;
    }
    return null;
  }

  Future<void> _showCreateInviteDialog(BuildContext context,
      {bool isReusable = false}) async {
    await showHouseholdInviteComposer(context,
        householdId: widget.householdId, isReusable: isReusable);
    if (mounted) await _loadInvites();
  }

  void _copyInviteLink(HouseholdInvite invite) {
    final inviteUrl = buildInviteLink(invite.token);
    Clipboard.setData(ClipboardData(text: inviteUrl));

    AppToast.success(context, context.l10n.inviteLinkCopiedToClipboard);
  }

  Future<void> _revokeInvite(HouseholdInvite invite) async {
    final confirmed = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.revokeInvitation,
      description: context.l10n.confirmRevokeInvitation,
      confirmLabel: context.l10n.revoke,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );

    if (confirmed?.confirmed == true) {
      try {
        final repository = ref.read(householdRepositoryProvider);
        await repository.revokeInvite(inviteId: invite.id);
        await _loadInvites();

        if (mounted) {
          AppToast.success(context, context.l10n.invitationRevoked);
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, '${context.l10n.errorRevokingInvite}: $e');
        }
      }
    }
  }
}

/// Invite Card Widget
class _InviteCard extends StatelessWidget {
  final HouseholdInvite invite;
  final VoidCallback? onCopy;
  final VoidCallback? onRevoke;

  const _InviteCard({
    required this.invite,
    this.onCopy,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpired =
        invite.expiresAt != null && invite.expiresAt!.isBefore(DateTime.now());
    final isPending = invite.status == InviteStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    invite.isReusable
                        ? context.l10n.groupInviteLink
                        : invite.invitedEmail ?? context.l10n.anyoneWithLink,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusBadge(status: invite.status, isExpired: isExpired),
              ],
            ),
            if (invite.personalMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                invite.personalMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 14, color: colorScheme.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  invite.expiresAt == null
                      ? context.l10n.inviteNeverExpires
                      : (isExpired
                          ? '${context.l10n.expired} ${_formatDate(invite.expiresAt!)}'
                          : '${context.l10n.expires} ${_formatDate(invite.expiresAt!)}'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired
                        ? colorScheme.destructive
                        : colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            if (isPending &&
                !isExpired &&
                (onCopy != null || onRevoke != null)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onCopy != null)
                    Expanded(
                      child: OutlinedAdaptiveButton(
                        onPressed: onCopy,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy, size: 16),
                            const SizedBox(width: 8),
                            Text(context.l10n.copyLink),
                          ],
                        ),
                      ),
                    ),
                  if (onCopy != null && onRevoke != null)
                    const SizedBox(width: 8),
                  if (onRevoke != null)
                    Expanded(
                      child: DestructiveAdaptiveButton(
                        onPressed: onRevoke,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cancel, size: 16),
                            const SizedBox(width: 8),
                            Text(context.l10n.revoke),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 0) {
      return '${difference.inDays.abs()} day${difference.inDays.abs() > 1 ? 's' : ''} ago';
    }
    return 'soon';
  }
}

/// Status Badge Widget
class _StatusBadge extends StatelessWidget {
  final InviteStatus status;
  final bool isExpired;

  const _StatusBadge({
    required this.status,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(Theme.of(context).colorScheme);
    final text = _getLocalizedStatus(context, isExpired, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    if (isExpired) return colorScheme.destructive;

    return switch (status) {
      InviteStatus.pending => colorScheme.warning,
      InviteStatus.accepted => colorScheme.success,
      InviteStatus.revoked => colorScheme.destructive,
      InviteStatus.expired => colorScheme.mutedForeground,
    };
  }

  String _getLocalizedStatus(
      BuildContext context, bool isExpired, InviteStatus status) {
    if (isExpired) return context.l10n.expired.toUpperCase();

    switch (status) {
      case InviteStatus.pending:
        return context.l10n.pending.toUpperCase();
      case InviteStatus.accepted:
        return context.l10n.accepted.toUpperCase();
      case InviteStatus.revoked:
        return context.l10n.revoked.toUpperCase();
      case InviteStatus.expired:
        return context.l10n.expired.toUpperCase();
    }
  }
}
