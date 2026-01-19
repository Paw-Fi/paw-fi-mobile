import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/destructive_adaptive_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// removed shared budgets UI from settings; budgets are managed elsewhere
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../widgets/household_image_picker.dart';
import '../utils/household_ui_utils.dart';
import '../../../../core/config/storage_config.dart';
import 'invite_members_page.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

/// Household Settings Page
/// Manage budgets, privacy preferences, and household settings
class HouseholdSettingsPage extends ConsumerStatefulWidget {
  final String householdId;
  final int? initialTab;

  const HouseholdSettingsPage({
    super.key,
    required this.householdId,
    this.initialTab,
  });

  @override
  ConsumerState<HouseholdSettingsPage> createState() =>
      _HouseholdSettingsPageState();
}

class _HouseholdSettingsPageState extends ConsumerState<HouseholdSettingsPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(householdProvider(widget.householdId));
    final shouldShowAllTabs = householdAsync.asData?.value?.isPortfolio != true;
    final desiredTabCount = shouldShowAllTabs ? 3 : 1;

    if (_tabController == null || _tabController!.length != desiredTabCount) {
      _tabController?.dispose();
      // Use initialTab if provided and valid, otherwise default to 0
      final initialIndex = (widget.initialTab != null &&
              widget.initialTab! >= 0 &&
              widget.initialTab! < desiredTabCount)
          ? widget.initialTab!
          : 0;
      _tabController = TabController(
        length: desiredTabCount,
        vsync: this,
        initialIndex: initialIndex,
      );
      _tabController!.addListener(() {
        if (mounted) setState(() {});
      });
    }

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
                  if (shouldShowAllTabs)
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
                          selectedIndex: _tabController!.index,
                          onValueChanged: (index) =>
                              _tabController!.animateTo(index),
                        ),
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: shouldShowAllTabs
                          ? null
                          : const NeverScrollableScrollPhysics(),
                      children: shouldShowAllTabs
                          ? [
                              _GeneralTab(householdId: widget.householdId),
                              _MembersTab(householdId: widget.householdId),
                              HouseholdInvitesTab(
                                  householdId: widget.householdId),
                            ]
                          : [
                              _GeneralTab(householdId: widget.householdId),
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
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.surfaceBorder,
                        ),
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
                            color: colorScheme.mutedForeground
                                .withValues(alpha: 0.6),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.foreground,
                          fontWeight: FontWeight.w400,
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
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: canEdit
                          ? () => _showImagePicker(context, household)
                          : null,
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: colorScheme.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.surfaceBorder,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image preview
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
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
                                            color: colorScheme.muted,
                                            child: Icon(
                                              Icons.home_filled,
                                              size: 64,
                                              color: colorScheme.mutedForeground
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: colorScheme.muted,
                                          child: Icon(
                                            Icons.home_filled,
                                            size: 64,
                                            color: colorScheme.mutedForeground
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                            ),
                            // Overlay button
                            if (canEdit) ...[
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    size: 20,
                                    color: Colors.black87,
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
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primaryForeground),
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
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primaryForeground,
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

    final result = await MonekoAlertDialog.show(
      context: pageContext,
      title: l10n.delete,
      description: l10n.confirmDeleteBudget,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      barrierDismissible: false,
      isDestructive: true,
    );

    if (result?.confirmed == true) {
      if (pageContext.mounted) {
        await _deleteHousehold(pageContext);
      }
    }
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
      await ref.read(selectedHouseholdProvider.notifier).initialize();

      if (!pageContext.mounted) return;

      if (Navigator.of(pageContext).canPop()) {
        Navigator.of(pageContext).pop();
      }
    } catch (e) {
      if (pageContext.mounted) {
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
        // final user = ref.read(authProvider); // Available if needed
        await ref.read(selectedHouseholdProvider.notifier).refresh();
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

  Future<void> _confirmRemoveMember(
      BuildContext context, WidgetRef ref, HouseholdMember member) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.removeMember,
      description:
          '${context.l10n.confirmRemoveMember} ${member.userName ?? member.userEmail}?',
      confirmLabel: context.l10n.remove,
      cancelLabel: context.l10n.cancel,
      barrierDismissible: true,
    );

    if (result?.confirmed == true) {
      await ref
          .read(householdMembersProvider(householdId).notifier)
          .removeMember(member.id);
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.surfaceBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canManageThisMember ? () => _showOptions(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                MemberAvatar(
                  role: member.role,
                  avatarUrl: member.avatarUrl,
                  name: member.userName,
                  email: member.userEmail,
                  radius: 20,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          RoleBadge(role: member.role),
                          if (member.userEmail != null &&
                              member.userName != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '•',
                              style: TextStyle(
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                    Icons.more_horiz_rounded,
                    color: colorScheme.mutedForeground.withValues(alpha: 0.7),
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
    final colorScheme = Theme.of(context).colorScheme;
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
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
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
              textColor: colorScheme.destructive,
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

class _PermissionNotice extends StatelessWidget {
  final String? message;

  const _PermissionNotice({this.message});

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
              message ?? context.l10n.onlyAdminsAndOwnersCanCreateInvitations,
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
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
        ],
      ),
    );
  }
}
