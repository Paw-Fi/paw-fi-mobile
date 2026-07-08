import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Centralized image compression utility for all upload paths.
///
/// Reduces egress by compressing images before uploading to Supabase Storage.
/// Each upload type has a tuned preset that balances quality vs file size.
class ImageCompressor {
  /// Compress an image file using the given config.
  ///
  /// Returns compressed bytes, or the original bytes if source-format
  /// preservation is enabled and compression fails.
  static Future<Uint8List> compressFile(
    File file, {
    ImageCompressConfig config = ImageCompressConfig.receipt,
    bool useOriginalWhenSmaller = true,
  }) async {
    try {
      final originalBytes = await file.readAsBytes();
      final format = config.preserveSourceFormat
          ? _formatForPath(file.path, config.preferredFormat)
          : config.preferredFormat;

      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: config.quality,
        minWidth: config.maxDimension,
        minHeight: config.maxDimension,
        format: format,
        keepExif: false,
      );

      if (result == null || result.isEmpty) {
        if (!config.preserveSourceFormat) {
          debugPrint('⚠️ ImageCompressor: compression returned null');
          throw StateError('Image compression failed');
        }
        debugPrint('⚠️ ImageCompressor: compression returned null, '
            'using original (${originalBytes.length} bytes)');
        return originalBytes;
      }

      // Only fall back to the original when preserving its format. Forced JPEG
      // presets must return JPEG bytes because upload paths use .jpg metadata.
      if (useOriginalWhenSmaller &&
          config.preserveSourceFormat &&
          result.length >= originalBytes.length) {
        debugPrint('ℹ️ ImageCompressor: compressed is not smaller '
            '(${result.length} >= ${originalBytes.length}), using original');
        return originalBytes;
      }

      final savings =
          ((1 - result.length / originalBytes.length) * 100).toStringAsFixed(0);
      debugPrint('✅ ImageCompressor: ${originalBytes.length} → '
          '${result.length} bytes ($savings% reduction)');
      return result;
    } catch (e, stack) {
      debugPrint('⚠️ ImageCompressor.compressFile failed: $e\n$stack');
      if (!config.preserveSourceFormat) {
        rethrow;
      }
      return file.readAsBytes();
    }
  }

  /// Compress raw image bytes using the given config.
  ///
  /// Useful for avatar uploads where we already have PNG bytes in memory.
  /// Returns compressed bytes, or the original if compression fails.
  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    ImageCompressConfig config = ImageCompressConfig.avatar,
    bool useOriginalWhenSmaller = true,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: config.quality,
        minWidth: config.maxDimension,
        minHeight: config.maxDimension,
        format: config.preferredFormat,
        keepExif: false,
      );

      if (result.isEmpty) {
        if (!config.preserveSourceFormat) {
          debugPrint('⚠️ ImageCompressor: compressWithList returned empty');
          throw StateError('Image compression failed');
        }
        debugPrint('⚠️ ImageCompressor: compressWithList returned empty, '
            'using original (${bytes.length} bytes)');
        return bytes;
      }

      if (useOriginalWhenSmaller &&
          config.preserveSourceFormat &&
          result.length >= bytes.length) {
        debugPrint('ℹ️ ImageCompressor: compressed is not smaller '
            '(${result.length} >= ${bytes.length}), using original');
        return bytes;
      }

      final savings =
          ((1 - result.length / bytes.length) * 100).toStringAsFixed(0);
      debugPrint('✅ ImageCompressor: ${bytes.length} → '
          '${result.length} bytes ($savings% reduction)');
      return Uint8List.fromList(result);
    } catch (e, stack) {
      debugPrint('⚠️ ImageCompressor.compressBytes failed: $e\n$stack');
      if (!config.preserveSourceFormat) {
        rethrow;
      }
      return bytes;
    }
  }

  /// Infer the best compress format from file extension.
  static CompressFormat _formatForPath(
    String path,
    CompressFormat fallback,
  ) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'png':
        return CompressFormat.png;
      case 'webp':
        return CompressFormat.webp;
      case 'heic':
      case 'heif':
        return CompressFormat.heic;
      default:
        return fallback;
    }
  }
}

/// Configuration presets for different image upload types.
class ImageCompressConfig {
  final int quality;
  final int maxDimension;
  final CompressFormat preferredFormat;
  final bool preserveSourceFormat;

  const ImageCompressConfig({
    required this.quality,
    required this.maxDimension,
    required this.preferredFormat,
    this.preserveSourceFormat = false,
  });

  /// Receipt photos: high quality JPEG, max 1920px.
  /// Typical savings: 60-80% on raw phone photos (3-6MB → 200-800KB).
  static const receipt = ImageCompressConfig(
    quality: 80,
    maxDimension: 1920,
    preferredFormat: CompressFormat.jpeg,
  );

  /// Avatar images: PNG at 600px (original captures at 1200px).
  /// Typical savings: 40-60%.
  static const avatar = ImageCompressConfig(
    quality: 85,
    maxDimension: 600,
    preferredFormat: CompressFormat.png,
    preserveSourceFormat: true,
  );

  /// Profile photos: displayed as small-to-medium circular avatars.
  static const profileAvatar = ImageCompressConfig(
    quality: 82,
    maxDimension: 512,
    preferredFormat: CompressFormat.jpeg,
  );

  /// Household cover images: JPEG at 800px.
  /// The image_cropper already limits to 800x800 quality 90,
  /// but this handles bypasses and adds a safety net.
  static const householdCover = ImageCompressConfig(
    quality: 85,
    maxDimension: 800,
    preferredFormat: CompressFormat.jpeg,
  );

  /// Wallet and pocket logos: tiny JPEG at 160px.
  /// These render as small circular thumbnails, so keep bytes aggressively low.
  static const logo = ImageCompressConfig(
    quality: 75,
    maxDimension: 160,
    preferredFormat: CompressFormat.jpeg,
  );
}
