import 'dart:async';
import 'dart:convert';
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
import 'package:moneko/features/home/presentation/widgets/custom_split_config_codec.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';

import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../widgets/auto_split_toggle_tile.dart';
import '../widgets/create_household_form_content.dart';
import '../widgets/household_members_panel.dart';
import '../widgets/space_visibility_selector_card.dart';

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
  static const bool _debugAutoSplitLogs =
      bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

  // General Settings State
  final _nameController = TextEditingController();
  String? _initialName;
  String? _initialImageUrl;
  String? _selectedImageUrl;
  File? _selectedImageFile;
  bool? _initialAutoSplitEnabled;
  bool? _autoSplitEnabled;
  Map<String, dynamic>? _initialAutoSplitConfig;
  Map<String, dynamic>? _autoSplitConfig;
  bool? _initialIsSharedSpace;
  bool? _isSharedSpace;
  bool _isSavingSettings = false;
  bool _isDeletingHousehold = false;
  bool _isNameInitialized = false;

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

  void _debugAutoSplit(String message) {
    if (!_debugAutoSplitLogs) return;
    debugPrint('[HouseholdSettings][AutoSplit] $message');
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(householdProvider(widget.householdId));
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));
    final loadedHousehold = householdAsync.valueOrNull;
    final hasUnsavedChanges =
        loadedHousehold != null ? _hasUnsavedChanges(loadedHousehold) : false;

    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !hasUnsavedChanges) return;
        unawaited(_handleUnsavedBackNavigation());
      },
      child: StatusBarOverlayRegion(
        child: AdaptiveScaffold(
          appBar: AdaptiveAppBar(
            title: context.l10n.householdSettings,
            leading: IconButton(
              onPressed: () {
                if (hasUnsavedChanges) {
                  unawaited(_handleUnsavedBackNavigation());
                  return;
                }
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
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
              if (!_isNameInitialized && !_isSavingSettings) {
                _nameController.text = household.name;
                _isNameInitialized = true;
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
              if (_autoSplitEnabled == null && !_isSavingSettings) {
                _autoSplitEnabled = household.autoSplitEnabled;
              }
              if (_initialAutoSplitEnabled == null && !_isSavingSettings) {
                _initialAutoSplitEnabled = household.autoSplitEnabled;
              }
              if (_autoSplitConfig == null && !_isSavingSettings) {
                _autoSplitConfig = household.autoSplitConfig == null
                    ? null
                    : Map<String, dynamic>.from(household.autoSplitConfig!);
              }
              if (_initialAutoSplitConfig == null && !_isSavingSettings) {
                _initialAutoSplitConfig = household.autoSplitConfig == null
                    ? null
                    : Map<String, dynamic>.from(household.autoSplitConfig!);
              }
              if (_isSharedSpace == null && !_isSavingSettings) {
                _isSharedSpace = !household.isPortfolio;
              }
              if (_initialIsSharedSpace == null && !_isSavingSettings) {
                _initialIsSharedSpace = !household.isPortfolio;
              }

              final hasUnsavedChanges = _hasUnsavedChanges(household);

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

                            if (household.isPortfolio)
                              _buildSpaceVisibilitySection(
                                context,
                                canEditSettings,
                              ),

                            if (!household.isPortfolio)
                              _buildAutoSplitSection(
                                context,
                                canEditSettings,
                                membersAsync.valueOrNull ??
                                    const <HouseholdMember>[],
                              ),

                            // 2. Members & Invites Section
                            if (!household.isPortfolio)
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
        ),
      ),
    );
  }

  // --- Sections ---

  Widget _buildSpaceVisibilitySection(
    BuildContext context,
    bool canEdit,
  ) {
    return _buildSettingsSection(
      context,
      title: context.l10n.privateSpace,
      children: [
        SpaceVisibilitySelectorCard(
          isSharedSpace: _isSharedSpace ?? false,
          enabled: canEdit,
          onChanged: canEdit
              ? (value) {
                  if (!mounted) return;
                  setState(() => _isSharedSpace = value);
                }
              : null,
        ),
      ],
    );
  }

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

  Widget _buildAutoSplitSection(
    BuildContext context,
    bool canEdit,
    List<HouseholdMember> members,
  ) {
    final isEnabled = _autoSplitEnabled ?? true;
    final initialConfig = _autoSplitConfig;
    final templateTotal = members.isEmpty ? 1.0 : members.length.toDouble();

    return _buildSettingsSection(
      context,
      title: context.l10n.autoSplit,
      children: [
        AutoSplitToggleTile(
          value: isEnabled,
          enabled: canEdit,
          onChanged: _handleAutoSplitToggle,
        ),
        if (isEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: AbsorbPointer(
              absorbing: !canEdit || members.isEmpty,
              child: Opacity(
                opacity: canEdit && members.isNotEmpty ? 1.0 : 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomSplitEditor(
                      members: members,
                      totalAmount: templateTotal,
                      currencySymbol: '',
                      initialSplitType: resolveStoredSplitType(
                        initialConfig,
                        fallback: SplitType.equal,
                      ),
                      initialSplits: deserializeStoredSplitConfig(
                        members: members,
                        totalAmount: templateTotal,
                        config: initialConfig,
                      ),
                      showEqualOption: true,
                      availableSplitTypes: const <SplitType>[
                        SplitType.equal,
                        SplitType.percentage,
                        SplitType.shares,
                      ],
                      notifyDebounceDuration: Duration.zero,
                      onChanged: (splitType, splits) {
                        if (!mounted) return;
                        if (members.isEmpty || splits.isEmpty) {
                          _debugAutoSplit(
                            'Ignoring split change (members=${members.length}, splits=${splits.length}, type=${splitType.name})',
                          );
                          return;
                        }
                        final nextConfig = splitType == SplitType.equal ||
                                _isEffectivelyEqualSplit(splitType, splits)
                            ? null
                            : serializeStoredSplitConfig(
                                splitType: splitType,
                                splits: splits,
                              );
                        final currentEncoded =
                            _encodeSplitConfigForComparison(_autoSplitConfig);
                        final nextEncoded =
                            _encodeSplitConfigForComparison(nextConfig);
                        if (currentEncoded == nextEncoded) {
                          _debugAutoSplit(
                            'Ignoring no-op split change (type=${splitType.name})',
                          );
                          return;
                        }
                        _debugAutoSplit(
                          'Applying split change type=${splitType.name} current=$currentEncoded next=$nextEncoded',
                        );
                        setState(() {
                          _autoSplitEnabled = true;
                          _autoSplitConfig = nextConfig;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
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

  bool _hasUnsavedChanges(Household household) {
    // Don't report unsaved changes until initial values are loaded
    if (_initialName == null) {
      return false;
    }

    final normalizedInitialName = _initialName!.trim();
    final normalizedCurrentName = _nameController.text.trim();
    final hasNameChanged = normalizedCurrentName != normalizedInitialName;
    final normalizedInitialImage = _initialImageUrl ?? '';
    final normalizedCurrentImage = _selectedImageUrl ?? '';
    final hasImageChanged = _selectedImageFile != null ||
        normalizedCurrentImage != normalizedInitialImage;
    final encodedCurrentSplitConfig =
        _encodeSplitConfigForComparison(_autoSplitConfig);
    final encodedInitialSplitConfig =
        _encodeSplitConfigForComparison(_initialAutoSplitConfig);
    final hasAutoSplitChanged =
        (_autoSplitEnabled ?? household.autoSplitEnabled) !=
                (_initialAutoSplitEnabled ?? household.autoSplitEnabled) ||
            encodedCurrentSplitConfig != encodedInitialSplitConfig;
    final hasSpaceVisibilityChanged =
        (_isSharedSpace ?? !household.isPortfolio) !=
            (_initialIsSharedSpace ?? !household.isPortfolio);

    if (_debugAutoSplitLogs &&
        (hasNameChanged ||
            hasImageChanged ||
            hasAutoSplitChanged ||
            hasSpaceVisibilityChanged)) {
      _debugAutoSplit(
        'Dirty state name=$hasNameChanged image=$hasImageChanged autoSplit=$hasAutoSplitChanged visibility=$hasSpaceVisibilityChanged '
        'enabledCurrent=${_autoSplitEnabled ?? household.autoSplitEnabled} enabledInitial=${_initialAutoSplitEnabled ?? household.autoSplitEnabled} '
        'splitCurrent=$encodedCurrentSplitConfig splitInitial=$encodedInitialSplitConfig',
      );
    }

    return hasNameChanged ||
        hasImageChanged ||
        hasAutoSplitChanged ||
        hasSpaceVisibilityChanged;
  }

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

      final convertPortfolioToShared =
          household.isPortfolio && (_isSharedSpace ?? false);

      await ref.read(householdRepositoryProvider).updateHousehold(
            householdId: widget.householdId,
            name: _nameController.text.trim(),
            coverImageUrl: imageUrl,
            isPortfolio: convertPortfolioToShared ? false : null,
            autoSplitEnabled: household.isPortfolio ? null : _autoSplitEnabled,
            autoSplitConfig: household.isPortfolio ? null : _autoSplitConfig,
            updateAutoSplitConfig: !household.isPortfolio,
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
          _initialAutoSplitEnabled = _autoSplitEnabled;
          _initialAutoSplitConfig = _autoSplitConfig == null
              ? null
              : Map<String, dynamic>.from(_autoSplitConfig!);
          _initialIsSharedSpace = _isSharedSpace;
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

  void _handleAutoSplitToggle(bool value) {
    if (!mounted) return;

    setState(() {
      _autoSplitEnabled = value;
    });
  }

  bool _isEffectivelyEqualSplit(
    SplitType splitType,
    List<MemberSplit> splits,
  ) {
    if (splits.isEmpty) return true;

    bool closeTo(double actual, double expected) =>
        (actual - expected).abs() <= 0.01;

    switch (splitType) {
      case SplitType.equal:
        return true;
      case SplitType.percentage:
        final expected = 100 / splits.length;
        return splits.every(
          (split) =>
              split.includedInPercentage &&
              closeTo(split.percentage ?? 0, expected),
        );
      case SplitType.shares:
        return splits.every((split) => (split.shares ?? 0) == 1);
      case SplitType.amount:
        final expected = 1 / splits.length;
        return splits.every(
          (split) =>
              split.includedInAmount && closeTo(split.amount ?? 0, expected),
        );
    }
  }

  Future<void> _handleUnsavedBackNavigation() async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: 'Unsaved changes',
      description: 'Leave without saving your changes?',
      confirmLabel: 'Leave',
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );

    if (result?.confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  String? _encodeSplitConfigForComparison(Map<String, dynamic>? config) {
    if (config == null) return null;

    final splitTypeRaw = config['splitType']?.toString().trim().toLowerCase();
    if (splitTypeRaw == null ||
        splitTypeRaw.isEmpty ||
        splitTypeRaw == SplitType.equal.name) {
      return null;
    }

    final rawMemberSplits = config['memberSplits'];
    final normalizedSplits = <Map<String, dynamic>>[];
    if (rawMemberSplits is List) {
      for (final item in rawMemberSplits) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final userId = map['userId']?.toString().trim();
        if (userId == null || userId.isEmpty) continue;

        num? normalizeNum(dynamic value) {
          if (value is! num) return null;
          final asDouble = value.toDouble();
          if (asDouble.isNaN || asDouble.isInfinite) return null;
          return asDouble == asDouble.truncateToDouble()
              ? asDouble.toInt()
              : asDouble;
        }

        bool normalizeBool(dynamic value, {required bool fallback}) {
          if (value is bool) return value;
          return fallback;
        }

        final amount = normalizeNum(map['amount']);
        final percentage = normalizeNum(map['percentage']);
        final sharesRaw = normalizeNum(map['shares']);
        final shares = sharesRaw is int
            ? (sharesRaw > 0 ? sharesRaw : null)
            : (sharesRaw is num && sharesRaw > 0 ? sharesRaw.round() : null);

        normalizedSplits.add({
          'userId': userId,
          'amount': amount,
          'percentage': percentage,
          'shares': shares,
          'includedInAmount': normalizeBool(
            map['includedInAmount'],
            fallback: (amount ?? 0) != 0,
          ),
          'includedInPercentage': normalizeBool(
            map['includedInPercentage'],
            fallback: (percentage ?? 0) != 0,
          ),
        });
      }
    }

    if (normalizedSplits.isEmpty) {
      return null;
    }

    normalizedSplits.sort(
      (a, b) => (a['userId'] as String).compareTo(b['userId'] as String),
    );

    num? normalizeRootNum(dynamic value) {
      if (value is! num) return null;
      final asDouble = value.toDouble();
      if (asDouble.isNaN || asDouble.isInfinite) return null;
      return asDouble == asDouble.truncateToDouble()
          ? asDouble.toInt()
          : asDouble;
    }

    final normalized = <String, dynamic>{
      'splitType': splitTypeRaw,
      'templateTotalAmount': normalizeRootNum(config['templateTotalAmount']),
      'memberSplits': normalizedSplits,
    };

    return jsonEncode(normalized);
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
