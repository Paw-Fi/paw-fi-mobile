import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import '../../domain/entities/household.dart';

class InviteMembersPage extends ConsumerStatefulWidget {
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
  ConsumerState<InviteMembersPage> createState() => _InviteMembersPageState();
}

class _InviteMembersPageState extends ConsumerState<InviteMembersPage> {
  String? _generatedInviteUrl;
  bool _emailSent = false;
  void _handleInviteCreated(String inviteUrl, bool emailSent) {
    if (!mounted) return;
    setState(() {
      _generatedInviteUrl = inviteUrl;
      _emailSent = emailSent;
    });
    _showInviteResultSheet();
  }

  void _copyLink() {
    if (_generatedInviteUrl == null) return;
    Clipboard.setData(ClipboardData(text: _generatedInviteUrl!));
    HapticFeedback.selectionClick();
    AppToast.success(context, context.l10n.linkCopiedToClipboard);
  }

  void _shareLink() {
    if (_generatedInviteUrl == null) return;
    Share.share(
      'Join my space "${widget.householdName}" on Moneko: $_generatedInviteUrl',
      subject: 'Join "${widget.householdName}" on Moneko',
    );
  }

  Future<void> _showInviteResultSheet() async {
    final inviteUrl = _generatedInviteUrl;
    if (inviteUrl == null || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: _buildResultContent(
            Theme.of(sheetContext).colorScheme,
            inviteUrl: inviteUrl,
            onInviteAnother: () => Navigator.of(sheetContext).pop(),
            onDone: () {
              Navigator.of(sheetContext).pop();
              widget.onDone();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.inviteMembers,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: getSubPageTopPadding(context)),
          child: Material(
            color: colorScheme.appBackground,
            child: HouseholdInvitesTab(
              householdId: widget.householdId,
              householdName: widget.householdName,
              onDone: widget.onDone,
              onInviteCreated: _handleInviteCreated,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildResultContent(
    ColorScheme colorScheme, {
    required String inviteUrl,
    required VoidCallback onInviteAnother,
    required VoidCallback onDone,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            _emailSent ? context.l10n.inviteSent : context.l10n.linkReady,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emailSent
                ? context.l10n.invitationEmailSent
                : context.l10n.shareLinkDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Link Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: colorScheme.border.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          inviteUrl,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.foreground,
                            fontFamily: 'Monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButtons(
                        label: context.l10n.copyLink,
                        icon: Icons.copy_rounded,
                        onPressed: _copyLink,
                        colorScheme: colorScheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButtons(
                        label: context.l10n.share,
                        icon: Icons.ios_share_rounded,
                        onPressed: _shareLink,
                        colorScheme: colorScheme,
                        isPrimary: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          PrimaryAdaptiveButton(
            onPressed: onInviteAnother,
            prefixIcon: const Icon(Icons.person_add_rounded, size: 18),
            child: Text(context.l10n.inviteNewMember),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onDone,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: colorScheme.foreground,
            ),
            child: Text(
              context.l10n.done,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isPrimary ? colorScheme.primary : colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(color: colorScheme.border.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : colorScheme.foreground,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HouseholdInvitesTab extends ConsumerStatefulWidget {
  const HouseholdInvitesTab({
    super.key,
    required this.householdId,
    this.householdName,
    this.onInviteCreated,
    this.onDone,
  });

  final String householdId;
  final String? householdName;
  final void Function(String inviteUrl, bool emailSent)? onInviteCreated;
  final VoidCallback? onDone;

  @override
  ConsumerState<HouseholdInvitesTab> createState() =>
      _HouseholdInvitesTabState();
}

class _HouseholdInvitesTabState extends ConsumerState<HouseholdInvitesTab> {
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
      if (mounted) {
        setState(() {
          _invites = invites;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(context, '${context.l10n.errorLoadingInvites}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final currentUserMember = membersAsync.asData?.value.firstWhere(
      (m) => m.userId == currentUserId,
      orElse: () => throw Exception('Current user not found in household'),
    );
    final currentUserRole = currentUserMember?.role ?? HouseholdRole.member;
    final canCreateInvites = currentUserRole == HouseholdRole.owner ||
        currentUserRole == HouseholdRole.admin;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingInvites =
        _invites.where((i) => i.status == InviteStatus.pending).toList();
    final historyInvites =
        _invites.where((i) => i.status != InviteStatus.pending).toList();

    return RefreshIndicator(
      onRefresh: _loadInvites,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (canCreateInvites) ...[
                  _CreateInviteCard(
                      onPressed: () => _showCreateInviteDialog(context)),
                  const SizedBox(height: 32),
                ] else ...[
                  const _InvitesPermissionNotice(),
                  const SizedBox(height: 32),
                ],
                _InvitesSectionHeader(
                  title: context.l10n.pendingInvitations,
                  count: pendingInvites.length,
                ),
                const SizedBox(height: 12),
                if (pendingInvites.isEmpty)
                  _InvitesEmptyState(
                    icon: Icons.mark_email_read_rounded,
                    message: context.l10n.noPendingInvitations,
                    subMessage: context.l10n.allCaughtUpNoPendingInvites,
                  )
                else
                  ...pendingInvites.map((invite) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InviteCard(
                          invite: invite,
                          onCopy: canCreateInvites
                              ? () => _copyInviteLink(invite)
                              : null,
                          onRevoke: canCreateInvites
                              ? () => _revokeInvite(invite)
                              : null,
                        ),
                      )),
                const SizedBox(height: 32),
                _InvitesSectionHeader(
                  title: context.l10n.invitationHistory,
                  count: historyInvites.length,
                ),
                const SizedBox(height: 12),
                if (historyInvites.isEmpty)
                  _InvitesEmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    message: context.l10n.noInvitationHistory,
                    subMessage: context.l10n.pastInvitationsWillAppearHere,
                  )
                else
                  ...historyInvites.map((invite) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InviteCard(
                          invite: invite,
                          onCopy: null,
                          onRevoke: null,
                        ),
                      )),
                if (widget.onDone != null) ...[
                  const SizedBox(height: 24),
                  PrimaryAdaptiveButton(
                    onPressed: widget.onDone,
                    prefixIcon: const Icon(Icons.check_rounded, size: 18),
                    child: Text(context.l10n.done),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: widget.onDone,
                      child: Text(
                        context.l10n.skipForNow,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateInviteDialog(BuildContext context) async {
    int expiresInDays = 7;
    final expiryNotifier = ValueNotifier<int>(expiresInDays);

    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.createInvitation,
      confirmLabel: context.l10n.create,
      cancelLabel: context.l10n.cancel,
      inputConfig: MonekoAlertDialogInputConfig(
        placeholder: context.l10n.emailOptional,
        keyboardType: TextInputType.emailAddress,
      ),
      secondaryInputConfig: MonekoAlertDialogInputConfig(
        placeholder: context.l10n.personalMessageOptional,
      ),
      content: ValueListenableBuilder<int>(
        valueListenable: expiryNotifier,
        builder: (context, value, _) {
          return _ExpirySelector(
            selectedDays: value,
            onChanged: (newValue) {
              expiresInDays = newValue;
              expiryNotifier.value = newValue;
            },
          );
        },
      ),
    );

    if (result?.confirmed == true) {
      final email = result!.text?.trim();
      final message = result.secondaryText?.trim();

      await _createInvite(
        email: (email != null && email.isNotEmpty) ? email : null,
        message: (message != null && message.isNotEmpty) ? message : null,
        expiresInDays: expiresInDays,
      );
    }
  }

  Future<void> _createInvite({
    String? email,
    String? message,
    required int expiresInDays,
  }) async {
    try {
      final user = ref.read(authProvider);
      final inviterName =
          (user.displayName?.trim().isNotEmpty == true ? user.displayName : user.email)
              ?.trim();
      final household = ref.read(householdProvider(widget.householdId)).value;
      final householdName = widget.householdName?.trim().isNotEmpty == true
          ? widget.householdName?.trim()
          : household?.name;
      final repository = ref.read(householdRepositoryProvider);
      final token = await repository.createInvite(
        householdId: widget.householdId,
        invitedEmail: email,
        personalMessage: message,
        inviterName: inviterName?.isNotEmpty == true ? inviterName : null,
        householdName: householdName?.trim().isNotEmpty == true
            ? householdName?.trim()
            : null,
        expiresInDays: expiresInDays,
      );

      await _loadInvites();

      if (mounted) {
        AppToast.success(context, context.l10n.invitationCreatedSuccessfully);

        final inviteUrl = 'https://moneko.io/invites/$token';
        Clipboard.setData(ClipboardData(text: inviteUrl));

        AppToast.success(context, context.l10n.inviteLinkCopiedToClipboard);

        widget.onInviteCreated?.call(inviteUrl, email?.isNotEmpty == true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '${context.l10n.errorCreatingInvite}: $e');
      }
    }
  }

  void _copyInviteLink(HouseholdInvite invite) {
    final inviteUrl = 'https://moneko.io/invites/${invite.token}';
    Clipboard.setData(ClipboardData(text: inviteUrl));

    AppToast.success(context, context.l10n.inviteLinkCopiedToClipboard);
  }

  Future<void> _revokeInvite(HouseholdInvite invite) async {
    final l10n = context.l10n;

    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.revokeInvitation,
      description: context.l10n.confirmRevokeInvitation,
      confirmLabel: context.l10n.revoke,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );

    if (result?.confirmed == true) {
      try {
        final navStartCtx = rootNavigatorKey.currentContext;
        if (navStartCtx != null && navStartCtx.mounted) {
          _showBlockingLoader(navStartCtx, message: l10n.loading);
        }
        final repository = ref.read(householdRepositoryProvider);
        await repository.revokeInvite(inviteId: invite.id);
        await _loadInvites();

        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted && context.mounted) {
          _hideBlockingLoader(navCtx);
          AppToast.success(context, context.l10n.invitationRevoked);
        }
      } catch (e) {
        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted && context.mounted) {
          _hideBlockingLoader(navCtx);
          AppToast.error(context, '${context.l10n.errorRevokingInvite}: $e');
        }
      }
    }
  }

  void _showBlockingLoader(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(message),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _hideBlockingLoader(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _CreateInviteCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateInviteCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.surfaceBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.inviteNewMember,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.sendLinkToJoinHousehold,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.mutedForeground,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvitesPermissionNotice extends StatelessWidget {
  const _InvitesPermissionNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.surfaceBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.mutedForeground.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.onlyAdminsAndOwnersCanCreateInvitations,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.mutedForeground,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitesSectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _InvitesSectionHeader({
    required this.title,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.mutedForeground,
              letterSpacing: 1.0,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.muted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvitesEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _InvitesEmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.surfaceBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: colorScheme.mutedForeground.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subMessage,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.invitedEmail ?? context.l10n.anyoneWithLink,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _InvitesStatusBadge(
                              status: invite.status, isExpired: isExpired),
                          const SizedBox(width: 6),
                          Text('•',
                              style: TextStyle(
                                  color: colorScheme.mutedForeground
                                      .withValues(alpha: 0.5))),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              invite.expiresAt == null
                                  ? context.l10n.noExpiry
                                  : (isExpired
                                      ? context.l10n.expired
                                      : context.l10n.expires),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              invite.expiresAt == null
                                  ? ''
                                  : (isExpired
                                      ? ''
                                      : _formatDate(invite.expiresAt!, context)),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (invite.personalMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.muted.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '"${invite.personalMessage}"',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isPending &&
              !isExpired &&
              (onCopy != null || onRevoke != null)) ...[
            Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.border.withValues(alpha: 0.3)),
            Row(
              children: [
                if (onCopy != null)
                  Expanded(
                    child: InkWell(
                      onTap: onCopy,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.copyLink,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (onCopy != null && onRevoke != null)
                  Container(
                    width: 1,
                    height: 24,
                    color: colorScheme.border.withValues(alpha: 0.5),
                  ),
                if (onRevoke != null)
                  Expanded(
                    child: InkWell(
                      onTap: onRevoke,
                      borderRadius: BorderRadius.only(
                        bottomRight: const Radius.circular(12),
                        bottomLeft: onCopy == null
                            ? const Radius.circular(12)
                            : Radius.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 16, color: colorScheme.destructive),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.revoke,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.destructive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date, BuildContext context) {
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

class _InvitesStatusBadge extends StatelessWidget {
  final InviteStatus status;
  final bool isExpired;

  const _InvitesStatusBadge({
    required this.status,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _getStatusColor(colorScheme);
    final text = _getLocalizedStatus(context, isExpired, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
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
    if (isExpired) return context.l10n.expired;

    switch (status) {
      case InviteStatus.pending:
        return context.l10n.pending;
      case InviteStatus.accepted:
        return context.l10n.accepted;
      case InviteStatus.revoked:
        return context.l10n.revoked;
      case InviteStatus.expired:
        return context.l10n.expired;
    }
  }
}

class _ExpirySelector extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onChanged;

  const _ExpirySelector({
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _getLabel(context, selectedDays);

    if (Platform.isIOS) {
      return GestureDetector(
        onTap: () => _showIOSPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.controlBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.expiresIn,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 15,
                ),
              ),
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_up_chevron_down,
                    size: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.controlBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedDays,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: colorScheme.mutedForeground),
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.foreground,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: colorScheme.card,
          items: [1, 3, 7, 14, 30, 0].map((days) {
            return DropdownMenuItem<int>(
              value: days,
              child: Text(_getLabel(context, days)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Future<void> _showIOSPicker(BuildContext context) async {
    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.expiresIn),
        actions: [
          _buildAction(ctx, 1),
          _buildAction(ctx, 3),
          _buildAction(ctx, 7),
          _buildAction(ctx, 14),
          _buildAction(ctx, 30),
          _buildAction(ctx, 0),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

  CupertinoActionSheetAction _buildAction(BuildContext context, int days) {
    return CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(context, days),
      child: Text(_getLabel(context, days)),
    );
  }

  String _getLabel(BuildContext context, int days) {
    if (days == 0) return context.l10n.unlimited;
    if (days == 1) return context.l10n.oneDay;
    if (days == 3) return context.l10n.threeDays;
    if (days == 7) return context.l10n.sevenDays;
    if (days == 14) return context.l10n.fourteenDays;
    if (days == 30) return context.l10n.thirtyDays;
    return '$days ${context.l10n.days}';
  }
}

