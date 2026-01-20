import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      backgroundColor: Theme.of(context).colorScheme.sheetBackground,
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
                      child: AdaptiveButton(
                        onPressed: _copyLink,
                        label: context.l10n.copyLink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryAdaptiveButton(
                        onPressed: _shareLink,
                        child: Text(context.l10n.share),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AdaptiveButton(
            onPressed: onInviteAnother,
            label: context.l10n.inviteNewMember,
          ),
          const SizedBox(height: 12),
          AdaptiveButton(
            style: AdaptiveButtonStyle.plain,
            onPressed: onDone,
            label: context.l10n.done,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.inviteMembers,
      ),
      body: HouseholdInvitesTab(
        householdId: widget.householdId,
        householdName: widget.householdName,
        onDone: widget.onDone,
        onInviteCreated: _handleInviteCreated,
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

  Future<void> _createInvite({
    String? email,
    String? message,
    required int expiresInDays,
  }) async {
    try {
      final user = ref.read(authProvider);
      final inviterName = (user.displayName?.trim().isNotEmpty == true
              ? user.displayName
              : user.email)
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
        final repository = ref.read(householdRepositoryProvider);
        await repository.revokeInvite(inviteId: invite.id);
        await _loadInvites();
        if (mounted) AppToast.success(context, context.l10n.invitationRevoked);
      } catch (e) {
        if (mounted) {
          AppToast.error(context, '${context.l10n.errorRevokingInvite}: $e');
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final currentUserMember = membersAsync.asData?.value.firstWhere(
      (m) => m.userId == currentUserId,
      orElse: () => throw Exception('Current user not found'),
    );
    final currentUserRole = currentUserMember?.role ?? HouseholdRole.member;
    final canCreateInvites = currentUserRole == HouseholdRole.owner ||
        currentUserRole == HouseholdRole.admin;

    final pendingInvites =
        _invites.where((i) => i.status == InviteStatus.pending).toList();
    final historyInvites =
        _invites.where((i) => i.status != InviteStatus.pending).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(
            top: getSubPageTopPadding(context),
            bottom: 32,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (canCreateInvites)
                AdaptiveFormSection(
                  children: [
                    AdaptiveListTile(
                      title: Text(context.l10n.inviteNewMember),
                      leading: const Icon(CupertinoIcons.person_add),
                      onTap: () => _showCreateInviteDialog(context),
                    ),
                  ],
                ),
              if (pendingInvites.isNotEmpty)
                AdaptiveFormSection(
                  header: Text(context.l10n.pendingInvitations.toUpperCase()),
                  children: pendingInvites.map((invite) {
                    return AdaptiveListTile(
                      title: Text(
                          invite.invitedEmail ?? context.l10n.anyoneWithLink),
                      subtitle: Text(_formatDate(invite.expiresAt!, context)),
                      trailing:
                          const Icon(CupertinoIcons.chevron_right, size: 16),
                      onTap: () => _showInviteActionSheet(invite),
                    );
                  }).toList(),
                ),
              if (historyInvites.isNotEmpty)
                AdaptiveFormSection(
                  header: Text(context.l10n.invitationHistory.toUpperCase()),
                  children: historyInvites.map((invite) {
                    return AdaptiveListTile(
                      title: Text(
                          invite.invitedEmail ?? context.l10n.anyoneWithLink),
                      subtitle: Text(invite.status.toString().split('.').last),
                      trailing: _StatusBadge(status: invite.status),
                    );
                  }).toList(),
                ),
              if (widget.onDone != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: PrimaryAdaptiveButton(
                    onPressed: widget.onDone!,
                    child: Text(context.l10n.done),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  void _showInviteActionSheet(HouseholdInvite invite) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(invite.invitedEmail ?? context.l10n.anyoneWithLink),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _copyInviteLink(invite);
            },
            child: Text(context.l10n.copyLink),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _revokeInvite(invite);
            },
            child: Text(context.l10n.revokeInvitation),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return 'Expires in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Expires in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 0) {
      return 'Expired ${difference.inDays.abs()} day${difference.inDays.abs() > 1 ? 's' : ''} ago';
    }
    return 'Expires soon';
  }
}

class _StatusBadge extends StatelessWidget {
  final InviteStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case InviteStatus.pending:
        color = Colors.orange;
        icon = CupertinoIcons.clock;
        break;
      case InviteStatus.accepted:
        color = Colors.green;
        icon = CupertinoIcons.check_mark;
        break;
      case InviteStatus.revoked:
        color = Colors.red;
        icon = CupertinoIcons.xmark;
        break;
      case InviteStatus.expired:
        color = Colors.grey;
        icon = CupertinoIcons.hourglass;
        break;
    }

    return Icon(icon, color: color, size: 20);
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
