import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import '../../../../core/config/storage_config.dart';

import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../widgets/create_household_form_content.dart';
import '../utils/household_ui_utils.dart';

/// Household Settings Page
/// Single page layout for managing household settings, members, and invitations.
class HouseholdSettingsPage extends ConsumerStatefulWidget {
  final String householdId;

  const HouseholdSettingsPage({
    super.key,
    required this.householdId,
  });

  @override
  ConsumerState<HouseholdSettingsPage> createState() =>
      _HouseholdSettingsPageState();
}

class _HouseholdSettingsPageState extends ConsumerState<HouseholdSettingsPage> {
  // General Settings State
  final _nameController = TextEditingController();
  String? _selectedImageUrl;
  File? _selectedImageFile;
  bool _isSavingSettings = false;
  bool _isDeletingHousehold = false;

  @override
  void initState() {
    super.initState();
    // Initial fetch of invites since they might not be loaded yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(householdInvitesProvider(widget.householdId).notifier).load();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(householdProvider(widget.householdId));
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final invitesAsync =
        ref.watch(householdInvitesProvider(widget.householdId));

    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.householdSettings,
      ),
      body: householdAsync.when(
        data: (household) {
          if (household == null) {
            return Center(
              child: Text(
                context.l10n.householdNotFound,
                style: TextStyle(color: colorScheme.destructive),
              ),
            );
          }

          final invites = invitesAsync.asData?.value ?? [];
          final pendingInvites =
              invites.where((invite) => invite.status == InviteStatus.pending).toList();
          final historyInvites =
              invites.where((invite) => invite.status != InviteStatus.pending).toList();

          // Permissions
          final currentUserMember = membersAsync.asData?.value.firstWhere(
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

          final currentUserRole =
              currentUserMember?.role ?? HouseholdRole.member;
          final isOwner = household.ownerId == currentUserId;
          final canEditSettings = currentUserRole == HouseholdRole.owner ||
              currentUserRole == HouseholdRole.admin;
          final canManageMembers = canEditSettings;

          // Initialize controller if this is the first load
          if (_nameController.text.isEmpty && !_isSavingSettings) {
            _nameController.text = household.name;
          }
          if (_selectedImageUrl == null &&
              _selectedImageFile == null &&
              !_isSavingSettings) {
            _selectedImageUrl = household.coverImageUrl;
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(householdProvider(widget.householdId));
              ref.invalidate(householdMembersProvider(widget.householdId));
              ref.invalidate(householdInvitesProvider(widget.householdId));
              // Small delay to ensure refresh indicator shows up smoothly
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: Padding(
              padding:  EdgeInsets.only(top: getSubPageTopPadding(context) ),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: getSubPageTopPadding(context),
                      bottom: 40,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. General Settings Section
                        _buildGeneralSettingsSection(
                          context,
                          canEditSettings,
                          household,
                        ),
              
                        // 2. Members Section
                        if (membersAsync.hasValue)
                          _buildMembersSection(
                            context,
                            membersAsync.value!,
                            pendingInvites,
                            canManageMembers,
                            currentUserRole,
                            currentUserId,
                          ),
              
                        // 3. Invitations Section
                        _buildInvitationsSection(
                          context,
                          historyInvites,
                        ),
              
                        // 4. Danger Zone (Delete)
                        if (isOwner) _buildDangerZone(context, household),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // --- Sections ---

  Widget _buildGeneralSettingsSection(
    BuildContext context,
    bool canEdit,
    Household household,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canEdit)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.onlyAdminsAndOwnersCanEditHouseholdSettings,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AbsorbPointer(
            absorbing: !canEdit,
            child: Opacity(
              opacity: canEdit ? 1.0 : 0.7,
              child: CreateHouseholdFormContent(
                nameController: _nameController,
                selectedImageUrl: _selectedImageUrl,
                selectedImageFile: _selectedImageFile,
                isLoading: _isSavingSettings,
                onImageSelected: (imageUrl, imageFile) {
                  setState(() {
                    _selectedImageUrl = imageUrl;
                    _selectedImageFile = imageFile;
                  });
                },
              ),
            ),
          ),
        ),
        if (canEdit) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PrimaryAdaptiveButton(
              onPressed:
                  _isSavingSettings ? null : () => _saveSettings(household),
              child: _isSavingSettings
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.saveChanges),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMembersSection(
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

          // Don't let users remove/edit themselves here (usually handled in profile or leave flow)
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
                  style:  TextStyle(
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
          final isExpired = invite.expiresAt != null &&
              invite.expiresAt!.isBefore(DateTime.now());

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
              invite.invitedEmail ?? context.l10n.anyoneWithLink,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatExpiryDate(invite.expiresAt, context)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExpired
                      ? context.l10n.expired
                      : context.l10n.pending,
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
        // "Invite New Member" Tile
        if (canManage)
          _buildSettingsTile(
            context: context,
            leading: _buildIconBadge(
              context,
              icon: CupertinoIcons.person_add,
              iconColor: colorScheme.mutedForeground,
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            title: Text(
              context.l10n.inviteNewMember,
              style: TextStyle(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: colorScheme.mutedForeground.withValues(alpha: 0.5),
            ),
            onTap: () => _showCreateInviteDialog(context),
          ),
      ],
    );
  }

  Widget _buildInvitationsSection(
    BuildContext context,
    List<HouseholdInvite> historyInvites,
  ) {
    if (historyInvites.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _buildSettingsSection(
          context,
          title: context.l10n.invitationHistory,
          children: historyInvites.map((invite) {
            final colorScheme = Theme.of(context).colorScheme;

            return _buildSettingsTile(
              context: context,
              title: Text(
                invite.invitedEmail ?? context.l10n.anyoneWithLink,
                style: TextStyle(color: colorScheme.mutedForeground),
              ),
              trailing: Text(
                _inviteStatusLabel(context, invite.status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context, Household household) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildSettingsSection(
      context,
      title: context.l10n.dangerZone,
      children: [
        _buildSettingsTile(
          context: context,
          title: Text(
            context.l10n.deleteHousehold,
            style: TextStyle(
              color: colorScheme.destructive,
            ),
          ),
          trailing: _isDeletingHousehold
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  CupertinoIcons.trash,
                  size: 20,
                  color: colorScheme.destructive,
                ),
          onTap: _isDeletingHousehold
              ? null
              : () => _confirmDeleteHousehold(household),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: colorScheme.mutedForeground,
            ),
          ),
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
              crossAxisAlignment:
                  hasSubtitle ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        hasSubtitle ? MainAxisAlignment.start : MainAxisAlignment.center,
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

  String _inviteStatusLabel(BuildContext context, InviteStatus status) {
    switch (status) {
      case InviteStatus.accepted:
        return context.l10n.accepted;
      case InviteStatus.revoked:
        return context.l10n.revoked;
      case InviteStatus.expired:
        return context.l10n.expired;
      case InviteStatus.pending:
        return context.l10n.pending;
    }
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

  // --- Logic & Actions ---

  Future<void> _saveSettings(Household household) async {
    if (_nameController.text.trim().isEmpty) {
      AppToast.error(context, context.l10n.pleaseEnterHouseholdName);
      return;
    }

    setState(() => _isSavingSettings = true);

    try {
      String? imageUrl = _selectedImageUrl;
      if (_selectedImageFile != null) {
        imageUrl = await _uploadImage(_selectedImageFile!);
      }

      await ref.read(householdRepositoryProvider).updateHousehold(
            householdId: widget.householdId,
            name: _nameController.text.trim(),
            coverImageUrl: imageUrl,
          );

      ref.invalidate(householdProvider(widget.householdId));
      // Also refresh the user households list globally
      ref.invalidate(userHouseholdsProvider(ref.read(authProvider).uid));
      // Refresh selected household config
      await ref.read(selectedHouseholdProvider.notifier).refresh();

      if (mounted) {
        // ignore: use_build_context_synchronously
        AppToast.success(context, context.l10n.householdUpdatedSuccessfully);
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        AppToast.error(context, '${context.l10n.failedToUpdateHousehold}: $e');
      }
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    final supabase = Supabase.instance.client;
    final user = ref.read(authProvider);
    final ext = imageFile.path.contains('.')
        ? '.${imageFile.path.split('.').last.toLowerCase()}'
        : '';
    final fileName =
        '${StorageConfig.householdCoversPath}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}$ext';

    await supabase.storage
        .from(StorageConfig.publicBucket)
        .upload(fileName, imageFile);

    return supabase.storage
        .from(StorageConfig.publicBucket)
        .getPublicUrl(fileName);
  }

  Future<void> _confirmDeleteHousehold(Household household) async {
    final confirmed = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.delete,
      description: context
          .l10n.confirmDeleteBudget, // Should ideally be confirmDeleteHousehold
      confirmLabel: context.l10n.delete,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );

    if (confirmed?.confirmed == true) {
      setState(() => _isDeletingHousehold = true);
      try {
        await ref
            .read(householdRepositoryProvider)
            .deleteHousehold(widget.householdId);

        // Refresh global state
        final userId = ref.read(authProvider).uid;
        await ref.read(userHouseholdsProvider(userId).notifier).load();
        await ref.read(selectedHouseholdProvider.notifier).initialize();

        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.success(context, 'Space deleted successfully');
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.error(context, 'Failed to delete: $e');
          setState(() => _isDeletingHousehold = false);
        }
      }
    }
  }

  // --- Member Actions ---

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
        AppToast.error(context, 'Failed to update role: $e');
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
          AppToast.success(context, 'Member removed');
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.error(context, 'Failed to remove member: $e');
        }
      }
    }
  }

  // --- Invite Actions ---

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

      // Get names for better invite context
      final user = ref.read(authProvider);
      final inviterName =
          (user.displayName?.isNotEmpty == true ? user.displayName : user.email)
              ?.trim();
      final household = ref.read(householdProvider(widget.householdId)).value;

      try {
        final token = await ref
            .read(householdInvitesProvider(widget.householdId).notifier)
            .createInvite(
              invitedEmail: (email != null && email.isNotEmpty) ? email : null,
              personalMessage:
                  (message != null && message.isNotEmpty) ? message : null,
              expiresInDays: expiresInDays,
              inviterName: inviterName,
              householdName: household?.name,
            );

        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.success(context, context.l10n.invitationCreatedSuccessfully);
          final inviteUrl = 'https://moneko.io/invites/$token';
          Clipboard.setData(ClipboardData(text: inviteUrl));
          // ignore: use_build_context_synchronously
          AppToast.success(context, context.l10n.inviteLinkCopiedToClipboard);
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.error(context, '${context.l10n.errorCreatingInvite}: $e');
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
              final inviteUrl = 'https://moneko.io/invites/${invite.token}';
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

  String _formatExpiryDate(DateTime? date, BuildContext context) {
    if (date == null) return context.l10n.noExpiry;
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

// Helpers

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

    // Android Fallback
    return DropdownButtonFormField<int>(
// ignore: deprecated_member_use
      value: selectedDays,
      decoration: InputDecoration(labelText: context.l10n.expiresIn),
      items: [
        DropdownMenuItem(value: 1, child: Text(context.l10n.oneDay)),
        DropdownMenuItem(value: 3, child: Text(context.l10n.threeDays)),
        DropdownMenuItem(value: 7, child: Text(context.l10n.sevenDays)),
        DropdownMenuItem(value: 14, child: Text(context.l10n.fourteenDays)),
        DropdownMenuItem(value: 30, child: Text(context.l10n.thirtyDays)),
        DropdownMenuItem(value: 0, child: Text(context.l10n.unlimited)),
      ],
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
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
}
