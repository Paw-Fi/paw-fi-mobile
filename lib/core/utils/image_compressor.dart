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
  /// Returns compressed bytes, or the original bytes if compression fails
  /// or the compressed result is larger than the original.
  static Future<Uint8List> compressFile(
    File file, {
    ImageCompressConfig config = ImageCompressConfig.receipt,
  }) async {
    try {
      final originalBytes = await file.readAsBytes();
      final format = _formatForPath(file.path, config.preferredFormat);

      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: config.quality,
        minWidth: config.maxDimension,
        minHeight: config.maxDimension,
        format: format,
        keepExif: false,
      );

      if (result == null || result.isEmpty) {
        debugPrint('⚠️ ImageCompressor: compression returned null, '
            'using original (${originalBytes.length} bytes)');
        return originalBytes;
      }

      // Only use compressed if actually smaller
      if (result.length >= originalBytes.length) {
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
      // Fallback: return original bytes so upload still works
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
        debugPrint('⚠️ ImageCompressor: compressWithList returned empty, '
            'using original (${bytes.length} bytes)');
        return bytes;
      }

      if (result.length >= bytes.length) {
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
      return bytes;
    }
  }

  /// Infer the best compress format from file extension.
  static CompressFormat _formatForPath(
    String path,
    CompressFormat fallback,
  ) {
    final ext =
        path.contains('.') ? path.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'png':
        return CompressFormat.png;
      case 'webp':
        return CompressFormat.webp;
      case 'heic':
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

  const ImageCompressConfig({
    required this.quality,
    required this.maxDimension,
    required this.preferredFormat,
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
  );

  /// Household cover images: JPEG at 800px.
  /// The image_cropper already limits to 800x800 quality 90,
  /// but this handles bypasses and adds a safety net.
  static const householdCover = ImageCompressConfig(
    quality: 85,
    maxDimension: 800,
    preferredFormat: CompressFormat.jpeg,
  );
}
