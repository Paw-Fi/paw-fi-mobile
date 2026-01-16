import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/create_household_form_content.dart';
import 'package:moneko/features/households/presentation/pages/invite_members_page.dart';
import 'package:moneko/features/households/presentation/utils/household_creation_utils.dart';
import 'package:moneko/features/households/presentation/widgets/spaces_explanation_modal.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/user_avatar.dart';

/// Single unified page to create either a Private Space or a Group Space (Household).
/// Refactored for a premium, Apple-like feel with distinct usage modes.
class CreateSpacePage extends ConsumerStatefulWidget {
  const CreateSpacePage({
    super.key,
    this.initialName,
    this.fromOnboarding = false,
    this.initialIsSharedSpace,
  });

  final String? initialName;
  final bool fromOnboarding;

  /// When null, defaults to shared space (true).
  final bool? initialIsSharedSpace;

  @override
  ConsumerState<CreateSpacePage> createState() => _CreateSpacePageState();
}

class _CreateSpacePageState extends ConsumerState<CreateSpacePage> {
  // Mode Selection: true = Shared Space, false = Private Space
  bool _isSharedSpace = true;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  // State Variables
  String? _selectedCurrency;
  String? _selectedImageUrl;
  File? _selectedImageFile;
  bool _isCreating = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);

    _isSharedSpace = widget.initialIsSharedSpace ?? true;

    if (widget.fromOnboarding &&
        widget.initialName != null &&
        widget.initialName!.isNotEmpty) {
      _isSharedSpace = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    // 1. Load cover images
    final coverImagesAsync = ref.read(coverImagesProvider);
    coverImagesAsync.whenData((images) {
      if (images.isNotEmpty && mounted) {
        setState(() {
          _selectedImageUrl = images[0];
        });
      }
    });

    // 2. Set currency silently
    final homeFilter = ref.read(homeFilterProvider);
    final selectedFromHome = homeFilter.selectedCurrency?.toUpperCase();
    if (selectedFromHome != null && isSupportedCurrencyCode(selectedFromHome)) {
      setState(() => _selectedCurrency = selectedFromHome);
    } else {
      final analytics = ref.read(analyticsProvider);
      final preferred = analytics.preferredCurrency?.toUpperCase();
      if (preferred != null && isSupportedCurrencyCode(preferred)) {
        setState(() => _selectedCurrency = preferred);
      } else {
        setState(() => _selectedCurrency = 'USD');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _selectedImageFile?.delete().catchError((e) {
      debugPrint('Failed to delete temporary image file: $e');
      return _selectedImageFile!;
    });
    super.dispose();
  }

  void _showSpacesInfo() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const SpacesExplanationModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = _isCreating || _isUploadingImage;
    final currentUser = ref.watch(authProvider);

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(
        title: "Create Space", // TODO: Localize
      ),
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: getSubPageTopPadding(context),
                    left: 16,
                    right: 16,
                    bottom: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormCard(colorScheme, isLoading),

                        const SizedBox(height: 20),

                        _buildMembersSection(colorScheme, currentUser),

                        // Helper text for better UX/Clarity
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 12, left: 16, right: 16),
                          child: Column(
                            children: [
                              Text(
                                _isSharedSpace
                                    ? "Shared spaces allow you to track expenses, manage budgets, and achieve goals with others."
                                    : "Private spaces are encrypted and visible only to you. Perfect for personal portfolios.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.mutedForeground,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _showSpacesInfo,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.help_outline_rounded,
                                        size: 14,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "How do spaces work?", // TODO: Localize
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBar(colorScheme, isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(ColorScheme colorScheme, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(20),
        // subtle border for "crisp" feel rather than just shadow
        border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.04), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CreateHouseholdFormContent(
        nameController: _nameController,
        selectedImageUrl: _selectedImageUrl,
        selectedImageFile: _selectedImageFile,
        isLoading: isLoading,
        onImageSelected: (imageUrl, imageFile) {
          if (!mounted) return;
          setState(() {
            _selectedImageUrl = imageUrl;
            _selectedImageFile = imageFile;
          });
        },
      ),
    );
  }

  Widget _buildMembersSection(ColorScheme colorScheme, AppUser currentUser) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.04), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // "Settings-like" Switch Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isSharedSpace
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : colorScheme.muted.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSharedSpace
                        ? Icons.group_rounded
                        : Icons.lock_outline_rounded,
                    size: 20,
                    color: _isSharedSpace
                        ? colorScheme.primary
                        : colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSharedSpace ? "Shared Space" : "Private Space",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isSharedSpace
                            ? "Invite members"
                            : "Only you", // Keep it short/clean
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                AdaptiveSwitch(
                  value: _isSharedSpace,
                  onChanged: (value) => setState(() => _isSharedSpace = value),
                  activeColor: colorScheme.primary,
                ),
              ],
            ),
          ),

          // Divider inserted only if we have list content (which we always do)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Divider(
              height: 1,
              color: colorScheme.border.withValues(alpha: 0.08),
            ),
          ),

          // Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: _isSharedSpace
                  ? _buildSharedMembersList(colorScheme, currentUser)
                  : _buildPrivateMembersList(colorScheme, currentUser),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedMembersList(ColorScheme colorScheme, AppUser currentUser) {
    return Column(
      key: const ValueKey('shared'),
      children: [
        _buildMemberRow(
          colorScheme,
          currentUser.displayName ?? "You", // TODO: Localize
          "Owner", // TODO: Localize
          currentUser.photoUrl,
          userId: currentUser.uid,
          isMe: true,
        ),
        const SizedBox(height: 16),
        _buildInvitePlaceholderRow(colorScheme),
      ],
    );
  }

  Widget _buildPrivateMembersList(
      ColorScheme colorScheme, AppUser currentUser) {
    return Column(
      key: const ValueKey('private'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMemberRow(
          colorScheme,
          currentUser.displayName ?? "You", // TODO: Localize
          "Owner (Private)", // TODO: Localize
          currentUser.photoUrl,
          userId: currentUser.uid,
          isMe: true,
        ),
      ],
    );
  }

  Widget _buildMemberRow(
    ColorScheme colorScheme,
    String name,
    String role,
    String? fallbackAvatarUrl, {
    String? userId,
    bool isMe = false,
  }) {
    // Resolve avatar Logic consistent with home_header_sliver
    Widget avatarWidget;

    if (isMe && userId != null) {
      avatarWidget = FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client
            .from('users')
            .select('avatar_url')
            .eq('id', userId)
            .maybeSingle(),
        builder: (context, snapshot) {
          final dbAvatarUrl = snapshot.data != null
              ? snapshot.data!['avatar_url'] as String?
              : null;

          String? validatedAvatarUrl;
          if (dbAvatarUrl != null &&
              dbAvatarUrl.isNotEmpty &&
              dbAvatarUrl != 'SKIPPED' &&
              (dbAvatarUrl.startsWith('http://') ||
                  dbAvatarUrl.startsWith('https://'))) {
            validatedAvatarUrl = dbAvatarUrl;
          }

          final avatarUrl = validatedAvatarUrl ??
              (fallbackAvatarUrl != null && fallbackAvatarUrl.isNotEmpty
                  ? fallbackAvatarUrl
                  : null);

          return UserAvatar(
            avatarUrl: avatarUrl,
            name: name,
            userId: userId,
            size: 40, // Slightly smaller for dense premium feel
            borderWidth: 1.5, // Thicker border for "sticker" look
            borderColor: colorScheme.surface, // Blend with background or white
          );
        },
      );
    } else {
      avatarWidget = UserAvatar(
        avatarUrl: fallbackAvatarUrl,
        name: name,
        userId: userId ?? 'unknown',
        size: 40,
        borderWidth: 1.5,
        borderColor: colorScheme.surface,
      );
    }

    return Row(
      children: [
        // Avatar with subtle shadow
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: avatarWidget,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                role,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvitePlaceholderRow(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.link_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Invite Link", // TODO: Localize
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  "Generated in next step", // TODO: Localize
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme, bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.8), // Glass effect base
        border: Border(
          top: BorderSide(color: colorScheme.border.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: PrimaryAdaptiveButton(
            onPressed: isLoading ? null : _handleCreation,
            child: isLoading
                ? const CircularProgressIndicator.adaptive()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSharedSpace
                            ? "Continue" // Cleaner "Continue" vs "Next"
                            : "Create Private Space", // TODO: Localize
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (_isSharedSpace) ...[
                        const SizedBox(width: 8),
                        // More subtle arrow
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreation() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.error(context, "Please enter a valid space name");
      return;
    }
    if (_selectedCurrency == null ||
        !isSupportedCurrencyCode(_selectedCurrency)) {
      AppToast.error(context, context.l10n.pleaseSelectValidCurrency);
      return;
    }

    if (!mounted) return;
    setState(() => _isCreating = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final name = _nameController.text.trim();
      String? imageUrl = _selectedImageUrl;

      if (_selectedImageFile != null) {
        if (!mounted) return;
        setState(() => _isUploadingImage = true);

        imageUrl = await HouseholdCreationUtils.uploadImageWithRetry(
            _selectedImageFile!, userId);

        if (!mounted) return;
        setState(() => _isUploadingImage = false);
      }

      final createdHousehold =
          await ref.read(householdRepositoryProvider).createHousehold(
                name: name,
                currency: _selectedCurrency!,
                coverImageUrl: imageUrl,
                isPortfolio: !_isSharedSpace,
              );

      ref.invalidate(userHouseholdsProvider(userId));

      if (!_isSharedSpace) {
        // --- Private Space Flow ---
        if (!mounted) return;
        setState(() => _isCreating = false);
        Navigator.of(context).pop(); // Close create page
        await ref
            .read(selectedHouseholdProvider.notifier)
            .selectHousehold(createdHousehold.id);
        ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
      } else {
        // --- Group Space Flow ---
        // Switch context first
        await ref
            .read(selectedHouseholdProvider.notifier)
            .selectHousehold(createdHousehold.id);
        ref.read(viewModeProvider.notifier).setMode(ViewMode.household);

        // Generate Invite & Go to Next Page
        await _generateInvitationAndNavigate(
            createdHousehold.id, createdHousehold.name);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SPACE CREATION ERROR: $e');
      debugPrint(stackTrace.toString());

      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _isUploadingImage = false;
      });
      AppToast.error(context, ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> _generateInvitationAndNavigate(
      String householdId, String householdName) async {
    // Navigate to the InviteMembersPage directly
    // The invite link will be generated there based on user configuration
    if (!mounted) return;
    setState(() => _isCreating = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => InviteMembersPage(
          householdId: householdId, // Pass ID instead of pre-generated URL
          householdName: householdName,
          onDone: () {
            if (widget.fromOnboarding) {
              final uid = ref.read(authProvider).uid;
              try {
                final prefs = ref.read(sharedPreferencesProvider);
                // Not waiting for this
                prefs.setBool('onboarding_completed:$uid', true);
              } catch (_) {}
              ref.read(mainShellTabIndexProvider.notifier).state = 0;
              context.go('/dashboard');
            } else {
              Navigator.of(context)
                  .pop(); // Invite page replaces create page, so pop goes back to list
            }
          },
        ),
      ),
    );
  }
}
