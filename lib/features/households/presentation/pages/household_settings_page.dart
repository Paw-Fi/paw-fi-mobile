import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
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
import 'package:path/path.dart' as path;

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          context.l10n.householdSettings,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.mutedForeground,
          indicatorColor: colorScheme.primary,
          tabs: [
            Tab(text: context.l10n.settings),
            Tab(text: context.l10n.members),
            Tab(text: context.l10n.invitations),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralTab(householdId: widget.householdId),
          _MembersTab(householdId: widget.householdId),
          _InvitesTab(householdId: widget.householdId),
        ],
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(householdProvider(widget.householdId));
    final membersAsync = ref.watch(householdMembersProvider(widget.householdId));
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
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

        // Get current user's role
        final currentUserMember = membersAsync.asData?.value.firstWhere(
          (m) => m.userId == currentUserId,
          orElse: () => throw Exception('Current user not found in household'),
        );
        
        final currentUserRole = currentUserMember?.role ?? HouseholdRole.member;
        final canEdit = currentUserRole == HouseholdRole.owner || currentUserRole == HouseholdRole.admin;

        // Initialize controller with current name if not already set
        if (_nameController.text.isEmpty) {
          _nameController.text = household.name;
        }
        if (_selectedImageUrl == null && _selectedImageFile == null) {
          _selectedImageUrl = household.coverImageUrl;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Permission notice for members
            if (!canEdit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Only admins and owners can edit household settings',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Household Name
            Text(
              context.l10n.householdName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: canEdit,
              decoration: InputDecoration(
                hintText: context.l10n.pleaseEnterHouseholdName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: canEdit ? colorScheme.card : colorScheme.muted.withValues(alpha: 0.3),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 24),

            // Cover Photo
            Text(
              context.l10n.coverPhoto,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: canEdit ? () => _showImagePicker(context, household) : null,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.12),
                  ),
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
                                  errorBuilder: (context, error, stack) =>
                                      Container(
                                    color: colorScheme.muted.withValues(alpha: 1.0),
                                    child: Icon(
                                      Icons.home_rounded,
                                      size: 48,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: colorScheme.muted.withValues(alpha: 1.0),
                                  child: const Icon(
                                    Icons.home_rounded,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                    ),
                    // Overlay button
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
                            color: Colors.white.withValues(alpha: 0.9),
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
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            if (canEdit)
              shadcnui.PrimaryButton(
                onPressed: _isSaving ? null : () => _saveChanges(household),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(context.l10n.saveChanges),
              ),
          ],
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

  Future<void> _saveChanges(Household household) async {
    if (_nameController.text.trim().isEmpty) {
      _showError(context.l10n.pleaseEnterHouseholdName);
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
        final currentColorScheme = shadcnui.Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.householdUpdatedSuccessfully),
            backgroundColor: currentColorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('${context.l10n.failedToUpdateHousehold}: $e');
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
      final fileName = '${StorageConfig.householdCoversPath}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

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

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: shadcnui.Theme.of(context).colorScheme.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  shadcnui.ColorScheme get colorScheme => shadcnui.Theme.of(context).colorScheme;
}

/// Members Tab
class _MembersTab extends ConsumerWidget {
  final String householdId;

  const _MembersTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(householdMembersProvider(householdId));
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return membersAsync.when(
      data: (members) {
        // Get current user's role
        final currentUserMember = members.firstWhere(
          (m) => m.userId == currentUserId,
          orElse: () => throw Exception('Current user not found in household'),
        );
        final currentUserRole = currentUserMember.role;
        final canManageMembers = currentUserRole == HouseholdRole.owner || currentUserRole == HouseholdRole.admin;

        return RefreshIndicator(
          onRefresh: () => ref.read(householdMembersProvider(householdId).notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _MemberCard(
                member: member,
                householdId: householdId,
                currentUserRole: currentUserRole,
                canManageMembers: canManageMembers,
                onRemove: () => _confirmRemoveMember(context, ref, member),
                onUpdateRole: (role) => _updateMemberRole(context, ref, member, role),
              );
            },
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
              style: TextStyle(color: colorScheme.destructive),
            ),
            const SizedBox(height: 8),
            shadcnui.OutlineButton(
              onPressed: () => ref.read(householdMembersProvider(householdId).notifier).load(),
              child: Text(context.l10n.retry),
            ),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.updatedMemberRole} ${member.userName ?? member.userEmail} to ${role.toJson()}')),
      );
    }
  }
}

/// Member Card Widget
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
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final isOwner = member.role == HouseholdRole.owner;
    
    // Determine if current user can manage this specific member
    // Owner can manage everyone except themselves
    // Admin can manage members but not owners or admins (except themselves to leave)
    final canManageThisMember = canManageMembers && (
      // Owner can manage everyone
      (currentUserRole == HouseholdRole.owner && !isOwner) ||
      // Admin can only manage regular members
      (currentUserRole == HouseholdRole.admin && member.role == HouseholdRole.member)
    );

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

            // Actions - only show if user has permission to manage this member
            if (canManageThisMember)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.errorLoadingInvites}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final membersAsync = ref.watch(householdMembersProvider(widget.householdId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Get current user's role
    final currentUserMember = membersAsync.asData?.value.firstWhere(
      (m) => m.userId == currentUserId,
      orElse: () => throw Exception('Current user not found in household'),
    );
    final currentUserRole = currentUserMember?.role ?? HouseholdRole.member;
    final canCreateInvites = currentUserRole == HouseholdRole.owner || currentUserRole == HouseholdRole.admin;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadInvites,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Permission notice for members
                if (!canCreateInvites) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Only admins and owners can create invitations',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Create Invite Button
                if (canCreateInvites)
                  shadcnui.PrimaryButton(
                    onPressed: () => _showCreateInviteDialog(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add),
                        const SizedBox(width: 8),
                        Text(context.l10n.createInvitation),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Pending Invites
                Text(
                  context.l10n.pendingInvitations,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 12),

                if (_invites.where((i) => i.status == InviteStatus.pending).isEmpty)
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
                            onCopy: canCreateInvites ? () => _copyInviteLink(invite) : null,
                            onRevoke: canCreateInvites ? () => _revokeInvite(invite) : null,
                          )),

                const SizedBox(height: 24),

                // History
                Text(
                  context.l10n.invitationHistory,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 12),

                if (_invites.where((i) => i.status != InviteStatus.pending).isEmpty)
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
          );
  }

  void _showCreateInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    int expiresInDays = 7;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.createInvitation),
          content: SingleChildScrollView(
            child: Column(
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
                  value: expiresInDays,
                  decoration: InputDecoration(labelText: context.l10n.expiresIn),
                  items: [
                    DropdownMenuItem(value: 1, child: Text(context.l10n.oneDay)),
                    DropdownMenuItem(value: 3, child: Text(context.l10n.threeDays)),
                    DropdownMenuItem(value: 7, child: Text(context.l10n.sevenDays)),
                    DropdownMenuItem(value: 14, child: Text(context.l10n.fourteenDays)),
                    DropdownMenuItem(value: 30, child: Text(context.l10n.thirtyDays)),
                    DropdownMenuItem(value: 0, child: Text(context.l10n.unlimited)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        expiresInDays = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                await _createInvite(
                  email: emailController.text.isNotEmpty ? emailController.text : null,
                  message: messageController.text.isNotEmpty ? messageController.text : null,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.invitationCreatedSuccessfully)),
        );

        // Auto-copy invite link
        final inviteUrl = 'https://moneko.app/invites/$token';
        Clipboard.setData(ClipboardData(text: inviteUrl));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.errorCreatingInvite}: $e')),
        );
      }
    }
  }

  void _copyInviteLink(HouseholdInvite invite) {
    final inviteUrl = 'https://moneko.app/invites/${invite.token}';
    Clipboard.setData(ClipboardData(text: inviteUrl));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _revokeInvite(HouseholdInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.revokeInvitation),
        content: Text(context.l10n.confirmRevokeInvitation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.revoke),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(householdRepositoryProvider);
        await repository.revokeInvite(inviteId: invite.id);
        await _loadInvites();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.invitationRevoked)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.l10n.errorRevokingInvite}: $e')),
          );
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
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final isExpired = invite.expiresAt != null && invite.expiresAt!.isBefore(DateTime.now());
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
                    invite.invitedEmail ?? context.l10n.anyoneWithLink,
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
                Icon(Icons.schedule, size: 14, color: colorScheme.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  invite.expiresAt == null
                      ? context.l10n.noExpiry
                      : (isExpired
                          ? '${context.l10n.expired} ${_formatDate(invite.expiresAt!)}'
                          : '${context.l10n.expires} ${_formatDate(invite.expiresAt!)}'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.red : colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            if (isPending && !isExpired && (onCopy != null || onRevoke != null)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onCopy != null)
                    Expanded(
                      child: shadcnui.OutlineButton(
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
                  if (onCopy != null && onRevoke != null) const SizedBox(width: 8),
                  if (onRevoke != null)
                    Expanded(
                      child: shadcnui.DestructiveButton(
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
    final color = _getStatusColor();
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

  Color _getStatusColor() {
    if (isExpired) return Colors.red;

    return switch (status) {
      InviteStatus.pending => Colors.orange,
      InviteStatus.accepted => Colors.green,
      InviteStatus.revoked => Colors.red,
      InviteStatus.expired => Colors.grey,
    };
  }

  String _getLocalizedStatus(BuildContext context, bool isExpired, InviteStatus status) {
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
