import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:moneko/core/utils/image_compressor.dart';

import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../widgets/create_household_form_content.dart';
import '../widgets/household_members_panel.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

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
  String? _initialName;
  String? _initialImageUrl;
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
    _nameController.addListener(() {
      if (mounted) {
        setState(() {});
      }
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

    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
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

          // Initialize controller if this is the first load
          if (_nameController.text.isEmpty && !_isSavingSettings) {
            _nameController.text = household.name;
          }
          if (_initialName == null && !_isSavingSettings) {
            _initialName = household.name;
          }
          if (_selectedImageUrl == null &&
              _selectedImageFile == null &&
              !_isSavingSettings) {
            _selectedImageUrl = household.coverImageUrl;
          }
          if (_initialImageUrl == null && !_isSavingSettings) {
            _initialImageUrl = household.coverImageUrl;
          }

          final normalizedInitialName = (_initialName ?? household.name).trim();
          final normalizedCurrentName = _nameController.text.trim();
          final hasNameChanged = normalizedCurrentName != normalizedInitialName;
          final normalizedInitialImage = _initialImageUrl ?? '';
          final normalizedCurrentImage = _selectedImageUrl ?? '';
          final hasImageChanged = _selectedImageFile != null ||
              normalizedCurrentImage != normalizedInitialImage;
          final hasUnsavedChanges = hasNameChanged || hasImageChanged;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(householdProvider(widget.householdId));
              ref.invalidate(householdMembersProvider(widget.householdId));
              ref.invalidate(householdInvitesProvider(widget.householdId));
              // Small delay to ensure refresh indicator shows up smoothly
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: Padding(
              padding: EdgeInsets.only(top: getSubPageTopPadding(context)),
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
                          hasUnsavedChanges,
                          household,
                        ),

                        // 2. Members & Invites Section
                        HouseholdMembersPanel(
                          householdId: widget.householdId,
                          householdName: household.name,
                        ),

                        // 3. Danger Zone (Delete)
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
        error: (e, s) => Center(child: Text('${context.l10n.error}: $e')),
      ),
    ));
  }

  // --- Sections ---

  Widget _buildGeneralSettingsSection(
    BuildContext context,
    bool canEdit,
    bool hasUnsavedChanges,
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
        if (canEdit && hasUnsavedChanges) ...[
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
        setState(() {
          _initialName = _nameController.text.trim();
          _initialImageUrl = imageUrl;
          _selectedImageUrl = imageUrl;
          _selectedImageFile = null;
        });
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

    // Compress before upload to reduce egress
    final compressedBytes = await ImageCompressor.compressFile(
      imageFile,
      config: ImageCompressConfig.householdCover,
    );

    await supabase.storage.from(StorageConfig.publicBucket).uploadBinary(
        fileName, compressedBytes,
        fileOptions: const FileOptions(cacheControl: '31536000'));

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
          AppToast.success(context, context.l10n.spaceDeletedSuccessfully);
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          AppToast.error(context, '${context.l10n.failedToDelete}: $e');
          setState(() => _isDeletingHousehold = false);
        }
      }
    }
  }
}
