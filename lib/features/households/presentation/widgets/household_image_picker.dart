// Reusable household image picker component
// Used in both create and edit flows

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../../../core/utils/error_handler.dart';
import '../../../../core/config/storage_config.dart';
import '../providers/household_providers.dart';

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
                        'Select Cover Image',
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
                    loading: () {
                      print('🔄 ImagePicker: Loading state');
                      return const Center(child: CircularProgressIndicator());
                    },
                    error: (error, stack) {
                      print('❌ ImagePicker: Error state - $error');
                      print('❌ Stack trace: $stack');
                      return Center(
                        child: Text(
                          'Failed to load images: $error',
                          style: TextStyle(color: colorScheme.destructive),
                        ),
                      );
                    },
                    data: (coverImages) {
                      print('✅ ImagePicker: Data state - ${coverImages.length} images');
                      print('✅ Grid item count: ${coverImages.length + 2}');
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
                          print('🎯 Building grid item at index $index');

                          // Camera option
                          if (index == 0) {
                            print('📷 Building camera tile');
                            return _buildActionTile(
                              colorScheme: colorScheme,
                              icon: Icons.camera_alt_rounded,
                              label: 'Take Photo',
                              gradientColors: [
                                colorScheme.primary.withOpacity(0.8),
                                colorScheme.primary,
                              ],
                              onTap: () async {
                                Navigator.pop(context);
                                final result = await _pickImage(
                                  context,
                                  imagePicker,
                                  ImageSource.camera,
                                );
                                if (result != null) {
                                  onImageSelected(null, result);
                                }
                              },
                            );
                          }

                          // Gallery option
                          if (index == 1) {
                            print('🖼️ Building gallery tile');
                            return _buildActionTile(
                              colorScheme: colorScheme,
                              icon: Icons.photo_library_rounded,
                              label: 'Choose from Gallery',
                              gradientColors: [
                                colorScheme.primary.withOpacity(0.6),
                                colorScheme.primary.withOpacity(0.8),
                              ],
                              onTap: () async {
                                Navigator.pop(context);
                                final result = await _pickImage(
                                  context,
                                  imagePicker,
                                  ImageSource.gallery,
                                );
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
                          print('🎨 Building preset tile $imageIndex: $imageUrl (selected: $isSelected)');

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
              color: colorScheme.primary.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.2),
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
                : colorScheme.border.withOpacity(0.12),
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
                    print('✅ Image loaded successfully: $imageUrl');
                    return child;
                  }
                  print('⏳ Loading image: $imageUrl (${progress.cumulativeBytesLoaded}/${progress.expectedTotalBytes ?? "unknown"} bytes)');
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
                  print('❌ Failed to load image: $imageUrl');
                  print('❌ Error: $error');
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
                          'Failed to load',
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
            'Image too large (${StorageConfig.getFileSizeString(fileSize)}). Max is ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
          );
        }
        return null;
      }

      if (!StorageConfig.isAllowedFormat(image.path)) {
        if (context.mounted) {
          _showError(
            context,
            'Unsupported file format. Please use JPG, PNG, or WebP.',
          );
        }
        return null;
      }

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
            toolbarTitle: 'Crop Cover Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Cover Image',
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
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(sourceFile.path)}';
      final permanentPath =
          path.join(appDir.path, 'household_images', fileName);

      final dir = Directory(path.dirname(permanentPath));
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
