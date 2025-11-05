// Reusable household image picker component
// Used in both create and edit flows

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/config/storage_config.dart';
import '../providers/household_providers.dart';
import 'package:moneko/core/l10n/l10n.dart';

class HouseholdImagePicker {

  static Future<void> showImageSourceModal({
    required BuildContext context,
    required WidgetRef ref,
    required Function(String? imageUrl, File? imageFile) onImageSelected,
    String? currentImageUrl,
  }) async {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final imagePicker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final coverImagesAsync = ref.watch(coverImagesProvider);

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            decoration: BoxDecoration(
              color: colorScheme.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.selectCoverImage,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Grid with camera, gallery, and presets
                Expanded(
                  child: coverImagesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) {
                      appLog(
                        'Failed to load household cover images',
                        name: 'HouseholdImagePicker',
                        error: error,
                        stackTrace: stack,
                      );
                      return Center(
                        child: Text(
                          '${context.l10n.failedToLoadImages}: $error',
                          style: TextStyle(color: colorScheme.destructive),
                        ),
                      );
                    },
                    data: (coverImages) {
                      return GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: coverImages.length + 2,
                        itemBuilder: (context, index) {
                          // Camera option
                          if (index == 0) {
                            return _buildActionTile(
                              colorScheme: colorScheme,
                              icon: Icons.camera_alt_rounded,
                              label: context.l10n.takePhoto,
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.8),
                                colorScheme.primary,
                              ],
                              onTap: () async {
                                final result = await _pickImage(
                                  context,
                                  imagePicker,
                                  ImageSource.camera,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                if (result != null) {
                                  onImageSelected(null, result);
                                }
                              },
                            );
                          }

                          // Gallery option
                          if (index == 1) {
                            return _buildActionTile(
                              colorScheme: colorScheme,
                              icon: Icons.photo_library_rounded,
                              label: context.l10n.chooseFromGallery,
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.6),
                                colorScheme.primary.withValues(alpha: 0.8),
                              ],
                              onTap: () async {
                                final result = await _pickImage(
                                  context,
                                  imagePicker,
                                  ImageSource.gallery,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                if (result != null) {
                                  onImageSelected(null, result);
                                }
                              },
                            );
                          }

                          // Preset images
                          final imageIndex = index - 2;
                          final imageUrl = coverImages[imageIndex];
                          final isSelected = imageUrl == currentImageUrl;

                          return _buildPresetTile(
                            colorScheme: colorScheme,
                            imageUrl: imageUrl,
                            isSelected: isSelected,
                            onTap: () {
                              onImageSelected(imageUrl, null);
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildActionTile({
    required shadcnui.ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildPresetTile({
    required shadcnui.ColorScheme colorScheme,
    required String imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.border.withValues(alpha: 0.12),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return Container(
                    color: colorScheme.muted,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  appLog(
                    'Failed to load household preset image',
                    name: 'HouseholdImagePicker',
                    error: error,
                    stackTrace: stackTrace,
                  );
                  return Container(
                    color: colorScheme.muted,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          color: colorScheme.mutedForeground,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.failedToLoad,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded,
                      color: colorScheme.primaryForeground, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<File?> _pickImage(
    BuildContext context,
    ImagePicker imagePicker,
    ImageSource source,
  ) async {
    try {
      final XFile? image = await imagePicker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image == null) return null;

      final file = File(image.path);
      final fileSize = await file.length();

      if (!StorageConfig.isValidFileSize(fileSize)) {
        if (context.mounted) {
          _showError(
            context,
            '${context.l10n.imageTooLarge} (${StorageConfig.getFileSizeString(fileSize)}). ${context.l10n.maxIs} ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
          );
        }
        return null;
      }

      if (!StorageConfig.isAllowedFormat(image.path)) {
        if (context.mounted) {
          _showError(
            context,
            context.l10n.unsupportedFileFormat,
          );
        }
        return null;
      }

      // Ensure context is still valid before showing crop UI
      if (!context.mounted) return null;
      final croppedFile = await _cropImage(context, image.path);
      if (croppedFile != null) {
        return await _copyToAppDirectory(File(croppedFile.path));
      }

      return null;
    } catch (e) {
      if (context.mounted) {
        _showError(context, ErrorHandler.getUserFriendlyMessage(e));
      }
      return null;
    }
  }

  static Future<CroppedFile?> _cropImage(
      BuildContext context, String imagePath) async {
    try {
      return await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        maxWidth: 800,
        maxHeight: 800,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: context.l10n.cropCoverImage,
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: context.l10n.cropCoverImage,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, ErrorHandler.getUserFriendlyMessage(e));
      }
      return null;
    }
  }

  static Future<File> _copyToAppDirectory(File sourceFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${(sourceFile.path.contains('.') ? '.${sourceFile.path.split('.').last}' : '')}';
      final permanentPath =
          '${appDir.path}/household_images/$fileName';

      final dir = Directory(permanentPath.substring(0, permanentPath.lastIndexOf('/')));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      return await sourceFile.copy(permanentPath);
    } catch (e) {
      return sourceFile;
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            shadcnui.Theme.of(context).colorScheme.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
