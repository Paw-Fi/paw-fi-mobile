import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/moneko_selector_button.dart';

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

/// Single unified page to create either a Private Space or a Group Space (Household).
/// Refactored for a premium, Apple iOS 26-like feel with card-based layout.
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
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierColor: colorScheme.scrim.withValues(alpha: 0.5),
      builder: (context) => const SpacesExplanationModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = _isCreating || _isUploadingImage;

    // Use the theme background for an airy, unified surface.
    final backgroundColor = colorScheme.appBackground;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.createSpace,
      ),
      body: Container(
        color: backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: getSubPageTopPadding(context),
                    left: 24,
                    right: 24,
                    bottom: 120, // Space for bottom bar
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Form Card
                        CreateHouseholdFormContent(
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

                        const SizedBox(height: 36),

                        // Shared/Members Card
                        _buildMembersCard(colorScheme),
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

  Widget _buildMembersCard(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who can see and add expense?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          AdaptivePopupMenuButton.widget<bool>(
            items: [
              AdaptivePopupMenuItem(
                label: 'All group members',
                value: true,
                icon: PlatformInfo.isIOS26OrHigher()
                    ? 'person.2'
                    : Icons.group_outlined,
              ),
              AdaptivePopupMenuItem(
                label: 'Just myself',
                value: false,
                icon: PlatformInfo.isIOS26OrHigher()
                    ? 'person'
                    : Icons.person_outline,
              ),
            ],
            onSelected: (index, item) {
              if (item.value != null && mounted) {
                setState(() {
                  _isSharedSpace = item.value!;
                });
              }
            },
            child: IgnorePointer(
              child: MonekoSelectorButton(
                label: _isSharedSpace ? 'All group members' : 'Just myself',
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: _isSharedSpace
                      ? 'Everyone in this space can view and add transactions. You’ll be able to invite members next. '
                      : 'Only you can see and add transactions in this space. ',
                ),
                TextSpan(
                  text: 'How it works',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = _showSpacesInfo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme, bool isLoading) {
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        // Floating effect via gradient fade or just subtle background
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scaffoldBackgroundColor.withValues(alpha: 0.0),
            scaffoldBackgroundColor.withValues(alpha: 0.8),
            scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56, // Slightly taller button
          child: PrimaryAdaptiveButton(
            onPressed: isLoading ? null : _handleCreation,
            child: isLoading
                ? const CircularProgressIndicator.adaptive()
                : Text(
                    _isSharedSpace ? 'Continue' : 'Create Private Space',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreation() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.error(context, context.l10n.pleaseEnterValidSpaceName);
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
        if (widget.fromOnboarding) {
          Navigator.of(context).pop(true); // Return to onboarding finish step
        } else {
          Navigator.of(context).pop(); // Close create page
        }
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
    if (!mounted) return;
    setState(() => _isCreating = false);

    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => InviteMembersPage(
          householdId: householdId,
          householdName: householdName,
          onDone: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (!mounted) return;
    if (done == true) {
      if (widget.fromOnboarding) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pop();
      }
    }
  }
}
