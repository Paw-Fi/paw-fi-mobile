import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moneko/core/config/storage_config.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoundedLogoPicker extends HookWidget {
  const RoundedLogoPicker({
    super.key,
    required this.logoUrl,
    required this.storagePathPrefix,
    required this.onChanged,
    required this.fallbackIcon,
    required this.accentColor,
    this.enabled = true,
  });

  final String? logoUrl;
  final String storagePathPrefix;
  final ValueChanged<String?> onChanged;
  final IconData fallbackIcon;
  final Color accentColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final picker = useMemoized(ImagePicker.new);
    final isUploading = useState(false);
    final hasLogo = logoUrl?.trim().isNotEmpty == true;

    Future<void> pickLogo() async {
      if (!enabled || isUploading.value) return;
      isUploading.value = true;
      try {
        final uploadedUrl = await _pickCropCompressAndUploadLogo(
          context: context,
          picker: picker,
          storagePathPrefix: storagePathPrefix,
        );
        if (uploadedUrl != null && context.mounted) {
          onChanged(uploadedUrl);
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      } finally {
        if (context.mounted) {
          isUploading.value = false;
        }
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: context.l10n.choosePhotoFromLibrary,
          child: GestureDetector(
            onTap: pickLogo,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasLogo
                    ? colorScheme.card
                    : accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasLogo ? accentColor : colorScheme.border,
                  width: hasLogo ? 2 : 1,
                ),
              ),
              child: ClipOval(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isUploading.value
                      ? Center(
                          key: const ValueKey('logo-uploading'),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(colorScheme.primary),
                            ),
                          ),
                        )
                      : hasLogo
                          ? Image.network(
                              logoUrl!,
                              key: ValueKey(logoUrl),
                              fit: BoxFit.cover,
                              cacheWidth:
                                  (44 * MediaQuery.of(context).devicePixelRatio)
                                      .round(),
                              cacheHeight:
                                  (44 * MediaQuery.of(context).devicePixelRatio)
                                      .round(),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _LogoFallbackIcon(
                                  icon: fallbackIcon,
                                  color: accentColor,
                                );
                              },
                              errorBuilder: (_, __, ___) => _LogoFallbackIcon(
                                icon: fallbackIcon,
                                color: accentColor,
                              ),
                            )
                          : _LogoFallbackIcon(
                              key: const ValueKey('logo-empty'),
                              icon: Icons.add_photo_alternate_rounded,
                              color: accentColor,
                            ),
                ),
              ),
            ),
          ),
        ),
        if (hasLogo && enabled)
          Positioned(
            right: -2,
            top: -1,
            child: GestureDetector(
              onTap: () => onChanged(null),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.destructive,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.sheetBackground),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: colorScheme.primaryForeground,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LogoFallbackIcon extends StatelessWidget {
  const _LogoFallbackIcon({
    super.key,
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }
}

Future<String?> _pickCropCompressAndUploadLogo({
  required BuildContext context,
  required ImagePicker picker,
  required String storagePathPrefix,
}) async {
  final image = await pickImageWithGuard(
    picker: picker,
    source: ImageSource.gallery,
    imageQuality: 95,
    maxWidth: 1024,
    maxHeight: 1024,
  );
  if (image == null) return null;

  final sourceName = image.name.trim().isNotEmpty ? image.name : image.path;
  if (!StorageConfig.isAllowedFormat(sourceName)) {
    if (context.mounted) {
      AppToast.error(context, context.l10n.unsupportedFileFormat);
    }
    return null;
  }

  if (!context.mounted) return null;
  final colorScheme = Theme.of(context).colorScheme;
  final croppedFile = await ImageCropper().cropImage(
    sourcePath: image.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressQuality: 85,
    maxWidth: 320,
    maxHeight: 320,
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
      WebUiSettings(
        context: context,
        presentStyle: WebPresentStyle.dialog,
        size: const CropperSize(width: 420, height: 420),
      ),
    ],
  );
  if (croppedFile == null) return null;

  final croppedBytes = await croppedFile.readAsBytes();
  if (croppedBytes.isEmpty) return null;

  final compressedBytes = await _compressLogoBytes(croppedBytes);
  if (!StorageConfig.isValidFileSize(compressedBytes.length)) {
    if (context.mounted) {
      AppToast.error(
        context,
        '${context.l10n.imageTooLarge} (${StorageConfig.getFileSizeString(compressedBytes.length)}). '
        '${context.l10n.maxIs} ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
      );
    }
    return null;
  }

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    if (context.mounted) {
      AppToast.info(context, context.l10n.userNotAuthenticated);
    }
    return null;
  }

  final contentHash =
      sha256.convert(compressedBytes).toString().substring(0, 8);
  final path =
      '${user.id}/$storagePathPrefix/${DateTime.now().microsecondsSinceEpoch}.jpg';
  await client.storage.from(StorageConfig.publicBucket).uploadBinary(
        path,
        compressedBytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
          cacheControl: '31536000',
        ),
      );

  final publicUrl =
      client.storage.from(StorageConfig.publicBucket).getPublicUrl(path);
  return '$publicUrl?v=$contentHash';
}

Future<Uint8List> _compressLogoBytes(Uint8List bytes) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 75,
      minWidth: 160,
      minHeight: 160,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    return result.isEmpty ? bytes : Uint8List.fromList(result);
  } catch (error, stackTrace) {
    debugPrint('Logo compression failed: $error\n$stackTrace');
    return bytes;
  }
}
