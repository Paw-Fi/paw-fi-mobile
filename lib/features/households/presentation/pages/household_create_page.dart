import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/config/storage_config.dart';
import '../../core/household_constants.dart';
import '../providers/household_providers.dart';
import '../widgets/invitation_share_sheet.dart';
import '../widgets/household_image_picker.dart';
import '../../../home/presentation/state/analytics_provider.dart';
import '../../../home/presentation/state/home_filter_provider.dart';
import '../../../utils/currency.dart';
import '../../../../core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

/// Modern page for creating a new household with image upload
class HouseholdCreatePage extends ConsumerStatefulWidget {
  const HouseholdCreatePage({super.key});

  @override
  ConsumerState<HouseholdCreatePage> createState() =>
      _HouseholdCreatePageState();
}

class _HouseholdCreatePageState extends ConsumerState<HouseholdCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  String? _selectedCurrency;

  String? _selectedImageUrl;
  File? _selectedImageFile;
  bool _isCreating = false;
  bool _isGeneratingInvite = false;
  bool _isUploadingImage = false;
  int _selectedExpirationDays = HouseholdConstants.defaultInviteExpirationDays;

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
    _messageController.dispose();
    // Clean up temporary image file if it exists
    _selectedImageFile?.delete().catchError((e) {
      debugPrint('Failed to delete temporary image file: $e');
      return _selectedImageFile!; // Return the file even if delete fails
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = _isCreating || _isGeneratingInvite || _isUploadingImage;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: (context.l10n.createHousehold),
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
                            _buildCoverImageSection(colorScheme, isLoading),
                            const SizedBox(height: 40),
                            _buildNameInput(colorScheme, isLoading),
                            const SizedBox(height: 24),
                            // Currency selector removed — currency is taken from Home filter silently
                            _buildInviteMessageInput(colorScheme, isLoading),
                            const SizedBox(height: 24),
                            _buildExpirationSelector(colorScheme, isLoading),
                            const SizedBox(height: 32),
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

  Widget _buildInviteMessageInput(ColorScheme colorScheme, bool isLoading) {
    return Semantics(
      label: context.l10n.invitationPersonalMessageInput,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.personalMessageOptional,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _messageController,
            enabled: !isLoading,
            maxLines: 3,
            maxLength: 200,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.foreground,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.personalMessageHint,
              hintStyle: TextStyle(
                color: colorScheme.mutedForeground.withValues(alpha: 0.5),
              ),
              counterText: '',
              filled: true,
              fillColor: colorScheme.muted.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.border.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Currency selector removed intentionally — currency is resolved from providers

  
  Widget _buildCoverImageSection(ColorScheme colorScheme, bool isLoading) {
    return Semantics(
      label: HouseholdConstants.coverImageSemanticLabel,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.12),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: _selectedImageFile != null
                      ? Image.file(
                          _selectedImageFile!,
                          fit: BoxFit.cover,
                        )
                      : _selectedImageUrl != null
                          ? Image.network(
                              _selectedImageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: colorScheme.muted,
                                  child: Center(
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: progress.expectedTotalBytes !=
                                                null
                                            ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stack) {
                                return Container(
                                  color: colorScheme.muted,
                                  child:
                                      const Icon(Icons.home_rounded, size: 48),
                                );
                              },
                            )
                          : Container(
                              color: colorScheme.muted,
                              child: const Icon(Icons.home_rounded, size: 48),
                            ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Semantics(
                  label: HouseholdConstants.editCoverButtonLabel,
                  button: true,
                  child: Material(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: isLoading ? null : _showImagePicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.appBackground,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 18,
                          color: colorScheme.primaryForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.tapToChangeCover,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput(ColorScheme colorScheme, bool isLoading) {
    return Semantics(
      label: context.l10n.householdNameInput,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.householdName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            enabled: !isLoading,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.foreground,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.householdNameHint,
              hintStyle: TextStyle(
                color: colorScheme.mutedForeground.withValues(alpha: 0.4),
                fontWeight: FontWeight.normal,
              ),
              filled: true,
              fillColor: colorScheme.muted.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.border.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.border.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.destructive,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.destructive,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.pleaseEnterHouseholdName;
              }
              if (value.trim().length < HouseholdConstants.minNameLength) {
                return context.l10n
                    .nameMinLength(HouseholdConstants.minNameLength);
              }
              if (value.trim().length > HouseholdConstants.maxNameLength) {
                return context.l10n
                    .nameMaxLength(HouseholdConstants.maxNameLength);
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationSelector(ColorScheme colorScheme, bool isLoading) {
    return Semantics(
      label: context.l10n.invitationExpirationSelector,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.invitationExpiresIn,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HouseholdConstants.inviteExpirationOptions.map((days) {
              final isSelected = days == _selectedExpirationDays;
              return Semantics(
                label: days == 0
                    ? context.l10n.unlimitedExpiration
                    : context.l10n.daysExpiration(days),
                button: true,
                selected: isSelected,
                child: InkWell(
                  onTap: isLoading
                      ? null
                      : () {
                          if (!mounted) return;
                          setState(() => _selectedExpirationDays = days);
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.border.withValues(alpha: 0.12),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      days == 0
                          ? context.l10n.unlimited
                          : context.l10n.daysCount(days),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colorScheme.primaryForeground
                            : colorScheme.foreground,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Semantics(
      label: context.l10n.householdInformation,
      readOnly: true,
      child: Container(
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
                context.l10n.createHouseholdDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.foreground.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
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
      child: Semantics(
        label: isLoading
            ? context.l10n.creatingHousehold
            : context.l10n.createHouseholdButton,
        button: true,
        enabled: !isLoading,
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
                            colorScheme.primaryForeground
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isUploadingImage
                            ? context.l10n.uploadingImage
                            : _isCreating
                                ? context.l10n.creating
                                : context.l10n.generatingInvite,
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
                  onPressed: _createHousehold,
                  child: Text(
                    context.l10n.createHousehold,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _showImagePicker() {
    HouseholdImagePicker.showImageSourceModal(
      context: context,
      ref: ref,
      currentImageUrl: _selectedImageUrl,
      onImageSelected: (imageUrl, imageFile) {
        if (!mounted) return;
        setState(() {
          _selectedImageUrl = imageUrl;
          _selectedImageFile = imageFile;
        });
      },
    );
  }

  Future<void> _createHousehold() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCurrency == null ||
        !isSupportedCurrencyCode(_selectedCurrency)) {
      _showErrorSnackbar(context.l10n.pleaseSelectValidCurrency);
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

        imageUrl = await _uploadImageWithRetry(_selectedImageFile!, userId);

        if (!mounted) return;
        setState(() => _isUploadingImage = false);
      }

      final createdHousehold =
          await ref.read(householdRepositoryProvider).createHousehold(
                name: name,
                currency: _selectedCurrency!,
                coverImageUrl: imageUrl,
              );

      // ✅ CRITICAL: Invalidate households provider so home page updates
      debugPrint('✅ Household created successfully: ${createdHousehold.id}');
      debugPrint('🔄 Invalidating userHouseholdsProvider for user: $userId');
      ref.invalidate(userHouseholdsProvider(userId));

      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _isGeneratingInvite = true;
      });

      await _generateInvitation(createdHousehold.id, createdHousehold.name);
    } catch (e, stackTrace) {
      // Debug logging
      debugPrint('❌ HOUSEHOLD CREATION ERROR:');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _isUploadingImage = false;
      });
      _showErrorSnackbar(
          '${ErrorHandler.getUserFriendlyMessage(e)}\n\nDetails: $e');
    }
  }

  Future<String> _uploadImageWithRetry(File imageFile, String userId) async {
    int attempts = 0;
    dynamic lastError;

    while (attempts < HouseholdConstants.maxRetryAttempts) {
      try {
        return await _uploadImage(imageFile, userId);
      } catch (e) {
        lastError = e;
        if (!ErrorHandler.isRetryable(e)) rethrow;
        attempts++;
        if (attempts < HouseholdConstants.maxRetryAttempts) {
          await Future.delayed(
            Duration(milliseconds: HouseholdConstants.retryDelayMs * attempts),
          );
        }
      }
    }

    throw lastError ??
        Exception(
            'Upload failed after ${HouseholdConstants.maxRetryAttempts} attempts');
  }

  Future<String> _uploadImage(File imageFile, String userId) async {
    try {
      debugPrint('📤 Uploading image:');
      debugPrint('  - Path: ${imageFile.path}');
      debugPrint('  - Exists: ${await imageFile.exists()}');

      if (!await imageFile.exists()) {
        throw Exception('File not found at path: ${imageFile.path}');
      }

      final bytes = await imageFile.readAsBytes();
      debugPrint('  - Size: ${bytes.length} bytes');

      if (!StorageConfig.isValidFileSize(bytes.length)) {
        throw Exception(
          'File too large (${StorageConfig.getFileSizeString(bytes.length)}). Max is ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
        );
      }

      final fileExt = imageFile.path.contains('.')
          ? '.${imageFile.path.split('.').last.toLowerCase()}'
          : '';
      if (!StorageConfig.isAllowedFormat(fileExt)) {
        throw Exception('Unsupported file format: $fileExt');
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$userId$fileExt';
      final filePath = '${StorageConfig.householdCoversPath}/$fileName';

      debugPrint('📤 Uploading to Supabase Storage:');
      debugPrint('  - Bucket: ${StorageConfig.publicBucket}');
      debugPrint('  - Path: $filePath');
      debugPrint('  - Content-Type: ${_getContentType(fileExt)}');

      try {
        await Supabase.instance.client.storage
            .from(StorageConfig.publicBucket)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: _getContentType(fileExt),
              ),
            );

        final publicUrl = Supabase.instance.client.storage
            .from(StorageConfig.publicBucket)
            .getPublicUrl(filePath);

        debugPrint('✅ Upload successful! URL: $publicUrl');
        return publicUrl;
      } catch (storageError) {
        debugPrint('❌ Supabase Storage Error:');
        debugPrint('  - Type: ${storageError.runtimeType}');
        debugPrint('  - Message: $storageError');
        rethrow;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Upload failed:');
      debugPrint('  - Error: $e');
      debugPrint('  - Stack: $stackTrace');
      throw Exception('Failed to upload image: $e');
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _generateInvitation(
      String householdId, String householdName) async {
    try {
      debugPrint('📧 Generating invitation for household: $householdId');
      final repository = ref.read(householdRepositoryProvider);
      final inviteUrl = await repository.createInvite(
        householdId: householdId,
        personalMessage: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        expiresInDays: _selectedExpirationDays,
      );
      debugPrint('✅ Invitation generated: $inviteUrl');

      if (!mounted) return;
      setState(() => _isGeneratingInvite = false);

      InvitationShareSheet.show(
        context: context,
        inviteUrl: inviteUrl,
        householdName: householdName,
        onClose: () {
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ INVITATION GENERATION ERROR:');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() => _isGeneratingInvite = false);

      _showErrorSnackbar(
          '${ErrorHandler.getUserFriendlyMessage(e)}\n\nDetails: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    // Prefer AppToast over SnackBar so message is visible above bottom sheet
    AppToast.error(context, message, duration: const Duration(seconds: 4));
  }
}
