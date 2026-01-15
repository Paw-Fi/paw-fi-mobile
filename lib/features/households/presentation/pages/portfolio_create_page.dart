import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import '../../../../core/utils/error_handler.dart';
import '../providers/household_providers.dart';
import '../../../utils/currency.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import '../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart'; // Added AppTheme
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/households/presentation/widgets/create_household_form_content.dart';
import 'package:moneko/features/households/presentation/utils/household_creation_utils.dart';

/// Page for creating a new portfolio (single-user group)
class PortfolioCreatePage extends ConsumerStatefulWidget {
  const PortfolioCreatePage({super.key});

  @override
  ConsumerState<PortfolioCreatePage> createState() =>
      _PortfolioCreatePageState();
}

class _PortfolioCreatePageState extends ConsumerState<PortfolioCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedCurrency;
  String? _selectedImageUrl;
  File? _selectedImageFile;
  bool _isCreating = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Load the first cover image from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coverImagesAsync = ref.read(coverImagesProvider);
      coverImagesAsync.whenData((images) {
        if (images.isNotEmpty && mounted) {
          setState(() {
            _selectedImageUrl = images[0];
          });
        }
      });

      // Set currency silently from Home filter (preferred), fallback to analytics preferred, else USD
      final homeFilter = ref.read(homeFilterProvider);
      final selectedFromHome = homeFilter.selectedCurrency?.toUpperCase();
      if (selectedFromHome != null &&
          isSupportedCurrencyCode(selectedFromHome)) {
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
    });
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = _isCreating || _isUploadingImage;

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(
        title: ('Create Portfolio'), // TODO: Localize
      ),
      body: SafeArea(
        child: Material(
          child: Padding(
            padding: EdgeInsets.only(top: getSubPageTopPadding(context)),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            const SizedBox(height: 32),
                            // Info card explaining portfolio
                            _buildInfoCard(colorScheme),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomActions(colorScheme, isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colorScheme.mutedForeground.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "A portfolio is a personal space for your own accounts (savings, trading, etc.). It behaves like a group with only you inside.", // TODO: Localize
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.foreground.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ColorScheme colorScheme, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.appBackground,
        border: Border(
          top: BorderSide(
            color: colorScheme.border.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: isLoading
            ? PrimaryAdaptiveButton(
                onPressed: null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primaryForeground.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isUploadingImage
                          ? context.l10n.uploadingImage
                          : context.l10n.creating,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              )
            : PrimaryAdaptiveButton(
                onPressed: _createPortfolio,
                child: const Text(
                  "Create Portfolio", // TODO: Localize
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _createPortfolio() async {
    if (!_formKey.currentState!.validate()) return;
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
                isPortfolio: true,
              );

      debugPrint('✅ Portfolio created successfully: ${createdHousehold.id}');
      ref.invalidate(userHouseholdsProvider(userId));

      if (!mounted) return;
      setState(() => _isCreating = false);

      // Navigate back
      // Since we pushed CreateSpacePage then PortfolioCreatePage
      // We should pop twice OR use GoRouter if we were going to dashboard for example.
      // But user likely wants to stay in "Settings" or "Groups" or just go back to home.
      // Popping twice returns to where the user clicked "Add".
      // But maybe we should go to the newly created portfolio?

      // Let's assume we want to go back to Home (dashboard).
      // But if we use Navigator.pop, we go back to CreateSpacePage.
      // We should pop CreateSpacePage as well.

      Navigator.of(context).pop(); // Pop creation
      Navigator.of(context).pop(); // Pop selection

      // Also switch to the new portfolio
      await ref
          .read(selectedHouseholdProvider.notifier)
          .selectHousehold(createdHousehold.id);
      ref.read(viewModeProvider.notifier).setMode(ViewMode.household);

      // If we are on home page, this will update content.
    } catch (e) {
      debugPrint('❌ PORTFOLIO CREATION ERROR: $e');
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _isUploadingImage = false;
      });
      AppToast.error(context, ErrorHandler.getUserFriendlyMessage(e));
    }
  }
}
