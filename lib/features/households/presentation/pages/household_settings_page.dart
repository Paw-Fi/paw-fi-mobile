import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';
import 'package:moneko/shared/widgets/destructive-adaptive-button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// removed shared budgets UI from settings; budgets are managed elsewhere
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../widgets/household_image_picker.dart';
import '../utils/household_ui_utils.dart';
import '../../../../core/config/storage_config.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

/// Household Settings Page
/// Manage budgets, privacy preferences, and household settings
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

class _HouseholdSettingsPageState extends ConsumerState<HouseholdSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.householdSettings,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: getSubPageTopPadding(context)),
          child: Material(
            child: Container(
              color: Theme.of(context).colorScheme.appBackground,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: AdaptiveSegmentedControl(
                        labels: [
                          context.l10n.settings,
                          context.l10n.members,
                          context.l10n.invitations,
                        ],
                        selectedIndex: _tabController.index,
                        onValueChanged: (index) =>
                            _tabController.animateTo(index),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _GeneralTab(householdId: widget.householdId),
                        _MembersTab(householdId: widget.householdId),
                        _InvitesTab(householdId: widget.householdId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// General Tab
class _GeneralTab extends ConsumerStatefulWidget {
  final String householdId;

  const _GeneralTab({required this.householdId});

  @override
  ConsumerState<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends ConsumerState<_GeneralTab> {
  final _nameController = TextEditingController();
  String? _selectedImageUrl;
  File? _selectedImageFile;
  bool _isSaving = false;
   bool _isDeleting = false;

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
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return householdAsync.when(
      data: (household) {
        if (household == null) {
          return Center(
            child: Text(
              context.l10n.householdNotFound,
              style: TextStyle(color: colorScheme.destructive),
            ),
          );
        }

        final isOwner = household.ownerId == currentUserId;

        // Get current user's role
        final currentUserMember = membersAsync.asData?.value.firstWhere(
          (m) => m.userId == currentUserId,
          orElse: () => throw Exception('Current user not found in household'),
        );

        final currentUserRole = currentUserMember?.role ?? HouseholdRole.member;
        final canEdit = currentUserRole == HouseholdRole.owner ||
            currentUserRole == HouseholdRole.admin;

        // Initialize controller with current name if not already set
        if (_nameController.text.isEmpty) {
          _nameController.text = household.name;
        }
        if (_selectedImageUrl == null && _selectedImageFile == null) {
          _selectedImageUrl = household.coverImageUrl;
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(householdProvider(widget.householdId));
            ref.invalidate(householdMembersProvider(widget.householdId));
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Permission notice for members
                    if (!canEdit) ...[
                      _PermissionNotice(
                        message: context
                            .l10n.onlyAdminsAndOwnersCanEditHouseholdSettings,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Household Name Section
                    _SectionHeader(
                      title: context.l10n.householdName,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.border.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _nameController,
                        enabled: canEdit,
                        decoration: InputDecoration(
                          hintText: context.l10n.pleaseEnterHouseholdName,
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.foreground,
                        ),
                        maxLength: 50,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Cover Photo Section
                    _SectionHeader(
                      title: context.l10n.coverPhoto,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: canEdit
                          ? () => _showImagePicker(context, household)
                          : null,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.border.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image preview
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: _selectedImageFile != null
                                  ? Image.file(
                                      _selectedImageFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : _selectedImageUrl != null
                                      ? Image.network(
                                          _selectedImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stack) =>
                                                  Container(
                                            color: colorScheme.muted
                                                .withValues(alpha: 1.0),
                                            child: Icon(
                                              Icons.home_rounded,
                                              size: 48,
                                              color:
                                                  colorScheme.mutedForeground,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: colorScheme.muted
                                              .withValues(alpha: 1.0),
                                          child: Icon(
                                            Icons.home_rounded,
                                            size: 48,
                                            color: colorScheme.mutedForeground,
                                          ),
                                        ),
                            ),
                            // Overlay button
                            if (canEdit) ...[
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.5),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          context.l10n.changeCoverPhoto,
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
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    if (canEdit)
                      PrimaryAdaptiveButton(
                        onPressed:
                            _isSaving ? null : () => _saveChanges(household),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(context.l10n.saveChanges),
                      ),
                    if (isOwner) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: DestructiveAdaptiveButton(
                          onPressed: _isDeleting
                              ? null
                              : () => _confirmDeleteHousehold(household),
                          child: _isDeleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(context.l10n.delete),
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          '${context.l10n.errorLoadingHousehold}: $error',
          style: TextStyle(color: colorScheme.destructive),
        ),
      ),
    );
  }

  void _showImagePicker(BuildContext context, Household household) {
    HouseholdImagePicker.showImageSourceModal(
      context: context,
      ref: ref,
      currentImageUrl: _selectedImageUrl,
      onImageSelected: (imageUrl, imageFile) {
        setState(() {
          _selectedImageUrl = imageUrl;
          _selectedImageFile = imageFile;
        });
      },
    );
  }

  Future<void> _confirmDeleteHousehold(Household household) async {
    final pageContext = context;
    final l10n = pageContext.l10n;

    AdaptiveAlertDialog.show(
      context: pageContext,
      title: l10n.delete,
      message: l10n.confirmDeleteBudget,
      icon: 'trash.fill',
      actions: [
        AlertAction(
          title: l10n.cancel,
          onPressed: () {
            Navigator.of(pageContext).pop(false);
          },
        ),
        AlertAction(
          title: l10n.delete,
          style: AlertActionStyle.destructive,
          onPressed: () async {
            Navigator.of(pageContext).pop(true);
            await _deleteHousehold(pageContext);
          },
        ),
      ],
    );
  }

  Future<void> _deleteHousehold(BuildContext pageContext) async {
    if (!mounted || _isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final repository = ref.read(householdRepositoryProvider);
      await repository.deleteHousehold(widget.householdId);

      final user = ref.read(authProvider);
      final userId = user.uid;

      await ref.read(userHouseholdsProvider(userId).notifier).load();
      await ref.read(selectedHouseholdProvider.notifier).initialize(userId);

      if (!mounted) return;

      if (Navigator.of(pageContext).canPop()) {
        Navigator.of(pageContext).pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          pageContext,
          'Failed to delete household: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _saveChanges(Household household) async {
    if (_nameController.text.trim().isEmpty) {
      AppToast.error(context, context.l10n.pleaseEnterHouseholdName);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? imageUrl = _selectedImageUrl;

      // Upload image if file was selected
      if (_selectedImageFile != null) {
        imageUrl = await _uploadImage(_selectedImageFile!);
      }

      // Update household via repository
      final repository = ref.read(householdRepositoryProvider);
      await repository.updateHousehold(
        householdId: widget.householdId,
        name: _nameController.text.trim(),
        coverImageUrl: imageUrl,
      );

      // Invalidate providers to refresh UI
      ref.invalidate(householdProvider(widget.householdId));
      ref.invalidate(userHouseholdsProvider(ref.read(authProvider).uid));

      // Refresh selected household if this is the selected one
      final selectedState = ref.read(selectedHouseholdProvider);
      if (selectedState.householdId == widget.householdId) {
        final user = ref.read(authProvider);
        await ref.read(selectedHouseholdProvider.notifier).refresh(user.uid);
      }

      if (mounted) {
        AppToast.success(context, context.l10n.householdUpdatedSuccessfully);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '${context.l10n.failedToUpdateHousehold}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
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

      final publicUrl = supabase.storage
          .from(StorageConfig.publicBucket)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  ColorScheme get colorScheme => Theme.of(context).colorScheme;
}

/// Members Tab - Clean, minimal design
class _MembersTab extends ConsumerWidget {
  final String householdId;

  const _MembersTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(householdMembersProvider(householdId));
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return membersAsync.when(
      data: (members) {
        final currentUserMember = members.firstWhere(
          (m) => m.userId == currentUserId,
          orElse: () => throw Exception('Current user not found in household'),
        );
        final currentUserRole = currentUserMember.role;
        final canManageMembers = currentUserRole == HouseholdRole.owner ||
            currentUserRole == HouseholdRole.admin;

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(householdMembersProvider(householdId).notifier).load(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final member = members[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MemberCard(
                          member: member,
                          householdId: householdId,
                          currentUserRole: currentUserRole,
                          canManageMembers: canManageMembers,
                          onRemove: () =>
                              _confirmRemoveMember(context, ref, member),
                          onUpdateRole: (role) =>
                              _updateMemberRole(context, ref, member, role),
                        ),
                      );
                    },
                    childCount: members.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.destructive),
            const SizedBox(height: 16),
            Text(
              context.l10n.errorLoadingMembers,
              style: TextStyle(color: colorScheme.foreground),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref
                  .read(householdMembersProvider(householdId).notifier)
                  .load(),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(
      BuildContext context, WidgetRef ref, HouseholdMember member) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.removeMember),
          content: Text(
              '${context.l10n.confirmRemoveMember} ${member.userName ?? member.userEmail}?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                await ref
                    .read(householdMembersProvider(householdId).notifier)
                    .removeMember(member.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(context.l10n.remove),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.removeMember),
          content: Text(
              '${context.l10n.confirmRemoveMember} ${member.userName ?? member.userEmail}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(householdMembersProvider(householdId).notifier)
                    .removeMember(member.id);
                if (context.mounted) Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.l10n.remove),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _updateMemberRole(BuildContext context, WidgetRef ref,
      HouseholdMember member, HouseholdRole role) async {
    await ref
        .read(householdMembersProvider(householdId).notifier)
        .updateRole(member.id, role);
    if (context.mounted) {
      AppToast.success(context,
          '${context.l10n.updatedMemberRole} ${member.userName ?? member.userEmail}');
    }
  }
}

/// Member Card Widget - Clean list item
class _MemberCard extends StatelessWidget {
  final HouseholdMember member;
  final String householdId;
  final HouseholdRole currentUserRole;
  final bool canManageMembers;
  final VoidCallback onRemove;
  final Function(HouseholdRole) onUpdateRole;

  const _MemberCard({
    required this.member,
    required this.householdId,
    required this.currentUserRole,
    required this.canManageMembers,
    required this.onRemove,
    required this.onUpdateRole,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOwner = member.role == HouseholdRole.owner;

    final canManageThisMember = canManageMembers &&
        ((currentUserRole == HouseholdRole.owner && !isOwner) ||
            (currentUserRole == HouseholdRole.admin &&
                member.role == HouseholdRole.member));

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canManageThisMember ? () => _showOptions(context) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                MemberAvatar(
                  role: member.role,
                  avatarUrl: member.avatarUrl,
                  name: member.userName,
                  email: member.userEmail,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (() {
                          final name = member.userName?.trim();
                          if (name != null && name.isNotEmpty) return name;
                          return member.userEmail ?? context.l10n.unknown;
                        })(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RoleBadge(role: member.role),
                          if (member.userEmail != null &&
                              member.userName != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                member.userEmail!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.mutedForeground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (canManageThisMember)
                  Icon(
                    Icons.more_vert_rounded,
                    color: colorScheme.mutedForeground,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: [
            if (member.role != HouseholdRole.admin)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  onUpdateRole(HouseholdRole.admin);
                },
                child: Text(context.l10n.makeAdmin),
              ),
            if (member.role != HouseholdRole.member)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  onUpdateRole(HouseholdRole.member);
                },
                child: Text(context.l10n.makeMember),
              ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                onRemove();
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
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.role != HouseholdRole.admin)
              ListTile(
                title: Text(context.l10n.makeAdmin),
                onTap: () {
                  Navigator.pop(context);
                  onUpdateRole(HouseholdRole.admin);
                },
              ),
            if (member.role != HouseholdRole.member)
              ListTile(
                title: Text(context.l10n.makeMember),
                onTap: () {
                  Navigator.pop(context);
                  onUpdateRole(HouseholdRole.member);
                },
              ),
            const Divider(),
            ListTile(
              title: Text(context.l10n.remove),
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      );
    }
  }
}

/// Invites Tab
class _InvitesTab extends ConsumerStatefulWidget {
  final String householdId;

  const _InvitesTab({required this.householdId});

  @override
  ConsumerState<_InvitesTab> createState() => _InvitesTabState();
}

class _InvitesTabState extends ConsumerState<_InvitesTab> {
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
                  _PermissionNotice(),
                  const SizedBox(height: 32),
                ],
                _SectionHeader(
                  title: context.l10n.pendingInvitations,
                  count: pendingInvites.length,
                ),
                const SizedBox(height: 12),
                if (pendingInvites.isEmpty)
                  _EmptyState(
                    icon: Icons.mark_email_read_rounded,
                    message: context.l10n.noPendingInvitations,
                    subMessage: 'All caught up! No pending invites.',
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
                _SectionHeader(
                  title: context.l10n.invitationHistory,
                  count: historyInvites.length,
                ),
                const SizedBox(height: 12),
                if (historyInvites.isEmpty)
                  _EmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    message: context.l10n.noInvitationHistory,
                    subMessage: 'Past invitations will appear here.',
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
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    int expiresInDays = 7;

    String expiryLabel(int days) {
      if (days == 1) return context.l10n.oneDay;
      if (days == 3) return context.l10n.threeDays;
      if (days == 7) return context.l10n.sevenDays;
      if (days == 14) return context.l10n.fourteenDays;
      if (days == 30) return context.l10n.thirtyDays;
      return context.l10n.unlimited;
    }

    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => CupertinoAlertDialog(
            title: Text(context.l10n.createInvitation),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: emailController,
                  placeholder: context.l10n.emailOptional,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: messageController,
                  placeholder: context.l10n.personalMessageOptional,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final selected = await showCupertinoModalPopup<int>(
                        context: context,
                        builder: (ctx) => CupertinoActionSheet(
                          title: Text(context.l10n.expiresIn),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(ctx, 1),
                              child: Text(context.l10n.oneDay),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(ctx, 3),
                              child: Text(context.l10n.threeDays),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(ctx, 7),
                              child: Text(context.l10n.sevenDays),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(ctx, 14),
                              child: Text(context.l10n.fourteenDays),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(ctx, 30),
                              child: Text(context.l10n.thirtyDays),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(ctx, 0),
                              child: Text(context.l10n.unlimited),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(context.l10n.cancel),
                          ),
                        ),
                      );
                      if (selected != null) {
                        setState(() => expiresInDays = selected);
                      }
                    },
                    child: Text(
                        '${context.l10n.expiresIn}: ${expiryLabel(expiresInDays)}'),
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              CupertinoDialogAction(
                onPressed: () async {
                  await _createInvite(
                    email: emailController.text.isNotEmpty
                        ? emailController.text
                        : null,
                    message: messageController.text.isNotEmpty
                        ? messageController.text
                        : null,
                    expiresInDays: expiresInDays,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(context.l10n.create),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.createInvitation),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: context.l10n.emailOptional,
                    hintText: context.l10n.friendEmailExample,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: context.l10n.personalMessageOptional,
                    hintText: context.l10n.joinHouseholdBudget,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: expiresInDays,
                  decoration:
                      InputDecoration(labelText: context.l10n.expiresIn),
                  items: [
                    DropdownMenuItem(
                        value: 1, child: Text(context.l10n.oneDay)),
                    DropdownMenuItem(
                        value: 3, child: Text(context.l10n.threeDays)),
                    DropdownMenuItem(
                        value: 7, child: Text(context.l10n.sevenDays)),
                    DropdownMenuItem(
                        value: 14, child: Text(context.l10n.fourteenDays)),
                    DropdownMenuItem(
                        value: 30, child: Text(context.l10n.thirtyDays)),
                    DropdownMenuItem(
                        value: 0, child: Text(context.l10n.unlimited)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => expiresInDays = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  await _createInvite(
                    email: emailController.text.isNotEmpty
                        ? emailController.text
                        : null,
                    message: messageController.text.isNotEmpty
                        ? messageController.text
                        : null,
                    expiresInDays: expiresInDays,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(context.l10n.create),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _createInvite({
    String? email,
    String? message,
    required int expiresInDays,
  }) async {
    try {
      final repository = ref.read(householdRepositoryProvider);
      final token = await repository.createInvite(
        householdId: widget.householdId,
        invitedEmail: email,
        personalMessage: message,
        expiresInDays: expiresInDays,
      );

      await _loadInvites();

      if (mounted) {
        AppToast.success(context, context.l10n.invitationCreatedSuccessfully);

        // Auto-copy invite link
        final inviteUrl = 'https://moneko.io/invites/$token';
        Clipboard.setData(ClipboardData(text: inviteUrl));

        AppToast.success(context, context.l10n.inviteLinkCopiedToClipboard);
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
    bool? confirmed;
    if (Platform.isIOS) {
      confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.revokeInvitation),
          content: Text(context.l10n.confirmRevokeInvitation),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.revoke),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.revokeInvitation),
          content: Text(context.l10n.confirmRevokeInvitation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.l10n.revoke),
            ),
          ],
        ),
      );
    }

    if (confirmed == true) {
      try {
        // Show blocking loader using a fresh, global context
        final navStartCtx = rootNavigatorKey.currentContext;
        if (navStartCtx != null && navStartCtx.mounted) {
          _showBlockingLoader(navStartCtx, message: l10n.loading);
        }
        final repository = ref.read(householdRepositoryProvider);
        await repository.revokeInvite(inviteId: invite.id);
        await _loadInvites();

        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted) {
          _hideBlockingLoader(navCtx);
          AppToast.success(context, context.l10n.invitationRevoked);
        }
      } catch (e) {
        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted) {
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
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite New Member',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Send a link to join your household',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
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

class _PermissionNotice extends StatelessWidget {
  final String? message;

  const _PermissionNotice({this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? 'Only admins and owners can create invitations.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionHeader({
    required this.title,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
            letterSpacing: 1.0,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: colorScheme.mutedForeground.withValues(alpha: 0.5),
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

/// Invite Card Widget - Clean list item
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.link,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.invitedEmail ?? context.l10n.anyoneWithLink,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatusBadge(
                              status: invite.status, isExpired: isExpired),
                          const SizedBox(width: 8),
                          Text('•',
                              style: TextStyle(
                                  color: colorScheme.mutedForeground)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              invite.expiresAt == null
                                  ? context.l10n.noExpiry
                                  : (isExpired
                                      ? context.l10n.expired
                                      : '${context.l10n.expires} ${_formatDate(invite.expiresAt!)}'),
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.muted.withValues(alpha: 0.3),
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
            Divider(height: 1, thickness: 0.5, color: colorScheme.border),
            Row(
              children: [
                if (onCopy != null)
                  Expanded(
                    child: InkWell(
                      onTap: onCopy,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
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
                    height: 44,
                    color: colorScheme.border,
                  ),
                if (onRevoke != null)
                  Expanded(
                    child: InkWell(
                      onTap: onRevoke,
                      borderRadius: BorderRadius.only(
                        bottomRight: const Radius.circular(16),
                        bottomLeft: onCopy == null
                            ? const Radius.circular(16)
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

  // ignore: unused_element
  IconData _getInviteIcon(String? email) {
    if (email == null || email.isEmpty) {
      return Icons.link_rounded;
    }
    return Icons.mail_rounded;
  }

  // ignore: unused_element
  Color _getStatusColor(InviteStatus status, bool isExpired) {
    if (isExpired) return Colors.red;

    return switch (status) {
      InviteStatus.pending => Colors.orange,
      InviteStatus.accepted => Colors.green,
      InviteStatus.revoked => Colors.red,
      InviteStatus.expired => Colors.grey,
    };
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

/// Status Badge Widget - Clean, minimal text
class _StatusBadge extends StatelessWidget {
  final InviteStatus status;
  final bool isExpired;

  const _StatusBadge({
    required this.status,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final text = _getLocalizedStatus(context, isExpired, status);

    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  Color _getStatusColor() {
    if (isExpired) return Colors.red;

    return switch (status) {
      InviteStatus.pending => Colors.orange,
      InviteStatus.accepted => Colors.green,
      InviteStatus.revoked => Colors.red,
      InviteStatus.expired => Colors.grey,
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
