import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';
// removed shared budgets UI from settings; budgets are managed elsewhere
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../widgets/household_image_picker.dart';
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

class _HouseholdSettingsPageState extends ConsumerState<HouseholdSettingsPage> {
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
      ),
      body: _GeneralTab(householdId: widget.householdId),
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
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

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
              decoration: InputDecoration(
                hintText: context.l10n.pleaseEnterHouseholdName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.card,
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
              onTap: () => _showImagePicker(context, household),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.border.withOpacity(0.12),
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
                                    color: colorScheme.muted,
                                    child: Icon(
                                      Icons.home_rounded,
                                      size: 48,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: colorScheme.muted,
                                  child: Icon(
                                    Icons.home_rounded,
                                    size: 48,
                                    color: colorScheme.mutedForeground,
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
                            Colors.black.withOpacity(0.5),
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
                            color: Colors.white.withOpacity(0.9),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.householdUpdatedSuccessfully),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('${context.l10n.failedToUpdateHousehold}: $e');
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

// Budgets tab removed per requirements
