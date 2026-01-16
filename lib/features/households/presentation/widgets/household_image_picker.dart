// Reusable household image picker component
// Used in both create and edit flows

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final imagePicker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final coverImagesAsync = ref.watch(coverImagesProvider);

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            decoration: BoxDecoration(
              color: colorScheme.appBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.selectCoverImage,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.muted.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 18, color: colorScheme.mutedForeground),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

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
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.surfaceBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.last.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
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
    required ColorScheme colorScheme,
    required String imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceBorder,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return Container(
                    color: colorScheme.muted.withValues(alpha: 0.3),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colorScheme.muted.withValues(alpha: 0.3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (isSelected) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
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
      final colorScheme = Theme.of(context).colorScheme;
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
            toolbarColor: colorScheme.appBackground,
            toolbarWidgetColor: colorScheme.foreground,
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
    AppToast.error(context, message);
  }
}
