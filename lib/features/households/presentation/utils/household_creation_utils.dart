import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/config/storage_config.dart';
import '../../core/household_constants.dart';
import 'package:moneko/core/utils/error_handler.dart';

class HouseholdCreationUtils {
  static Future<String> uploadImageWithRetry(
      File imageFile, String userId) async {
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

  static Future<String> _uploadImage(File imageFile, String userId) async {
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

  static String _getContentType(String extension) {
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
}
